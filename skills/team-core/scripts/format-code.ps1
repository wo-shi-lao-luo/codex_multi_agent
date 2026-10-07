# Plan reads bounded source and metadata; no execution. Trust is not an OS sandbox.
# Apply computes all candidates first, then writes only acknowledged literal files.
#requires -Version 7.0
[CmdletBinding()]
param(
  [ValidateSet('Plan', 'Check', 'Apply')][string]$Action = 'Plan',
  [Parameter(Mandatory)][string]$ProjectRoot,
  [Parameter(Mandatory)][string[]]$Files,
  [ValidateSet('Auto', 'Prettier', 'Ruff', 'PowerShell', 'Biome')][string]$Formatter = 'Auto',
  [string]$ToolPath,
  [switch]$TrustTooling,
  [switch]$AllowWrite,
  [ValidateRange(1, 120)][int]$TimeoutSeconds = 30,
  [ValidateRange(1, 1048576)][int]$MaxFileBytes = 1048576
)
$ErrorActionPreference = 'Stop'
$rows = [Collections.Generic.List[hashtable]]::new()
$contexts = [Collections.Generic.List[hashtable]]::new()
$snapshots = @{}
$root = $null
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
$prettierNames = @(
  '.prettierrc', '.prettierrc.json', '.prettierrc.yml', '.prettierrc.yaml',
  '.prettierrc.json5', '.prettierrc.toml', '.prettierrc.js', '.prettierrc.cjs',
  '.prettierrc.mjs', '.prettierrc.ts', '.prettierrc.cts', '.prettierrc.mts',
  'prettier.config.js', 'prettier.config.cjs', 'prettier.config.mjs',
  'prettier.config.ts', 'prettier.config.cts', 'prettier.config.mts'
)

# A linked path never confers permission, even if its final string is contained.
function Assert-Plain([string]$Path) {
  $cursor = $Path
  while ($cursor) {
    if (Test-Path -LiteralPath $cursor) {
      $attributes = (Get-Item -LiteralPath $cursor -Force).Attributes
      if ($attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'unsafe-path' }
    }
    $next = [IO.Path]::GetDirectoryName($cursor)
    if ($next -eq $cursor) { break }
    $cursor = $next
  }
}

# Literal relative files only; metadata, outputs and asserted representations stay untouched.
function Resolve-File([string]$Relative) {
  if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative)) { throw 'unsafe-path' }
  $relativePath = $Relative.Replace('\', '/')
  foreach ($part in ($relativePath -split '/')) {
    $invalidPart = $part -in @('', '.', '..') -or
      $part -match '[<>:"|?*\x00-\x1f]' -or $part -match '[ .]$' -or
      $part -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)'
    if ($invalidPart) { throw 'unsafe-path' }
    $protectedDirectories = @(
      '.git', '.codex', '.agents', '.aws', '.ssh', 'node_modules', 'vendor',
      '.venv', 'venv', '__pycache__', 'dist', 'build', 'out', 'coverage',
      '.next', 'generated', '__snapshots__', 'snapshots'
    )
    if ($part -in $protectedDirectories) { throw 'protected-file' }
  }
  $leaf = [IO.Path]::GetFileName($relativePath)
  $protectedLeaves = @(
    'AGENTS.md', 'AGENTS.override.md', 'SKILL.md', 'package.json', 'package-lock.json',
    'package.yaml', 'pyproject.toml', 'ruff.toml', '.ruff.toml', 'biome.json', 'biome.jsonc',
    'PSScriptAnalyzerSettings.psd1', '.editorconfig'
  )
  if ($leaf -in $protectedLeaves -or $leaf -in $prettierNames -or
      $leaf -match '\.(snap|lock)$' -or $leaf -match '^\.\w*ignore$' -or
      $relativePath -match '(^|/)fixtures?/.*\.(json|ya?ml|csv|txt)$') { throw 'protected-file' }
  $full = [IO.Path]::GetFullPath((Join-Path $root $relativePath))
  if (-not $full.StartsWith($root + [IO.Path]::DirectorySeparatorChar, $comparison)) { throw 'unsafe-path' }
  Assert-Plain $full
  if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw 'not-a-file' }
  if ((Get-Item -LiteralPath $full -Force).Length -gt $MaxFileBytes) { throw 'file-too-large' }
  return $full
}

# Metadata reads are fingerprinted; missing known config candidates matter to Apply too.
function Read-Metadata([string]$Path) {
  Assert-Plain $Path
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { $snapshots[$Path] = 'absent'; return $null }
  if ((Get-Item -LiteralPath $Path).Length -gt $MaxFileBytes) { throw 'config-too-large' }
  $snapshots[$Path] = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
  return [IO.File]::ReadAllText($Path, $utf8)
}

# Enumerate only ancestors inside the requested project, nearest first.
function Get-Ancestors([string]$File) {
  $directory = [IO.Path]::GetDirectoryName($File)
  while ($directory) {
    $directory
    if ($directory.Equals($root, $comparison)) { break }
    $directory = [IO.Path]::GetDirectoryName($directory)
  }
}

# External policy discovery is existence-only: never read or report parent contents/paths.
function Get-ParentDirectories {
  $directory = [IO.Path]::GetDirectoryName($root)
  while ($directory) {
    $directory
    $directory = [IO.Path]::GetDirectoryName($directory)
  }
}

# EditorConfig root is a global property. A section-local or ambiguous value must
# not grant permission to ignore inherited policy; the last global assignment wins.
function Test-EditorConfigTermination([string]$Text) {
  $terminated = $false
  foreach ($line in ($Text -split '\r?\n')) {
    if ($line -match '^\s*(?:[#;].*)?$') { continue }
    if ($line -match '^\s*\[') { break }
    if ($line -match '^\s*root\s*=\s*(.*?)\s*$') {
      $terminated = $Matches[1] -ieq 'true'
    }
  }
  return $terminated
}

# Selection is metadata evidence, not a general package-script or TOML interpreter.
function Find-Selection([hashtable]$Context) {
  $extension = [IO.Path]::GetExtension($Context.full).ToLowerInvariant()
  $supported = switch ($extension) {
    { $_ -in @('.py', '.pyi') } { @('Ruff', 'Black'); break }
    { $_ -in @('.ps1', '.psm1') } { @('PowerShell'); break }
    { $_ -in @('.js', '.jsx', '.ts', '.tsx', '.mjs', '.cjs', '.json', '.jsonc', '.css', '.html', '.graphql') } {
      @('Prettier', 'Biome'); break
    }
    { $_ -in @('.scss', '.less', '.vue', '.svelte', '.md', '.mdx', '.yaml', '.yml') } { @('Prettier'); break }
    default { throw 'unsupported-file-type' }
  }
  $selected = $null
  $config = $null
  $packageDirectory = $null
  $ignores = [Collections.Generic.List[string]]::new()
  foreach ($directory in $Context.ancestors) {
    $candidates = @{}
    foreach ($name in $prettierNames) {
      $path = Join-Path $directory $name
      if ($null -ne (Read-Metadata $path)) {
        if ($candidates.ContainsKey('Prettier') -and 'Prettier' -in $supported) { throw 'ambiguous-config' }
        $candidates.Prettier = $path
      }
    }
    foreach ($name in @('biome.json', 'biome.jsonc')) {
      $path = Join-Path $directory $name
      if ($null -ne (Read-Metadata $path)) {
        if ($candidates.ContainsKey('Biome') -and 'Biome' -in $supported) { throw 'ambiguous-config' }
        $candidates.Biome = $path
      }
    }
    foreach ($name in @('ruff.toml', '.ruff.toml')) {
      $path = Join-Path $directory $name
      if ($null -ne (Read-Metadata $path)) {
        if ($candidates.ContainsKey('Ruff') -and 'Ruff' -in $supported) { throw 'ambiguous-config' }
        $candidates.Ruff = $path
      }
    }
    $pyproject = Join-Path $directory 'pyproject.toml'
    $pythonText = Read-Metadata $pyproject
    if ($pythonText) {
      if ('Ruff' -in $supported -and $pythonText -match '(?m)^\s*\[[^\r\n]*["'']') {
        throw 'native-project-command-required'
      }
      if ($pythonText -match '(?m)^\s*\[tool\.ruff(?:\.[\w-]+)?\]\s*(?:#.*)?$') {
        if (-not $candidates.Ruff) { $candidates.Ruff = $pyproject }
      }
      if ($pythonText -match '(?im)\bblack\b') { $candidates.Black = $pyproject }
    }
    $settings = Join-Path $directory 'PSScriptAnalyzerSettings.psd1'
    if ($null -ne (Read-Metadata $settings)) { $candidates.PowerShell = $settings }
    $package = Join-Path $directory 'package.json'
    $packageText = Read-Metadata $package
    if ($packageText) {
      try { $manifest = ConvertFrom-Json -InputObject $packageText -AsHashtable }
      catch { throw 'invalid-package-metadata' }
      foreach ($section in @('dependencies', 'devDependencies')) {
        if ($manifest[$section] -is [Collections.IDictionary]) {
          if ($manifest[$section].Contains('prettier') -and -not $candidates.Prettier) { $candidates.Prettier = '' }
          if ($manifest[$section].Contains('@biomejs/biome') -and -not $candidates.Biome) { $candidates.Biome = '' }
        }
      }
      if ($manifest.Contains('prettier')) {
        if ($candidates.Prettier -and 'Prettier' -in $supported) { throw 'ambiguous-config' }
        $candidates.Prettier = $package
      }
    }
    $yamlPackage = Join-Path $directory 'package.yaml'
    if ($null -ne (Read-Metadata $yamlPackage)) {
      if ('Prettier' -in $supported) { $candidates.Prettier = $yamlPackage }
    }
    foreach ($name in @('.gitignore', '.prettierignore', '.ignore', '.editorconfig')) {
      $path = Join-Path $directory $name
      if ($null -ne (Read-Metadata $path)) { $ignores.Add($path) }
    }
    if (-not $selected) {
      $matches = @($candidates.Keys | Where-Object { $_ -in $supported })
      if ($Formatter -ne 'Auto') {
        if ($Formatter -notin $supported) { throw 'unsupported-file-type' }
        if ($matches.Count -and $Formatter -notin $matches) { throw 'formatter-authority-conflict' }
        if ($candidates.ContainsKey($Formatter)) { $selected = $Formatter; $config = $candidates[$Formatter] }
      } elseif ($matches.Count -gt 1) { throw 'ambiguous-formatter' }
      elseif ($matches.Count -eq 1) { $selected = $matches[0]; $config = $candidates[$selected] }
    }
    $installedManifest = Join-Path $directory 'node_modules/prettier/package.json'
    if (-not $packageDirectory -and (Test-Path -LiteralPath $installedManifest -PathType Leaf)) {
      $packageDirectory = $directory
    }
  }
  if (-not $selected -and $Formatter -ne 'Auto') { $selected = $Formatter }
  if (-not $selected) { throw 'needs-selection' }
  if ($selected -eq 'Black') { throw 'unsupported-formatter' }
  $Context.row.formatter = $selected
  $Context.config = $config
  $Context.ignores = @($ignores)
  $Context.packageDirectory = $packageDirectory
  $Context.row.configPaths = @(
    @($config) + @($ignores) | Where-Object { $_ } |
      ForEach-Object { [IO.Path]::GetRelativePath($root, $_).Replace('\', '/') }
  )
}

# A deliberately narrow policy profile avoids guessing native ignore/inheritance semantics.
function Assert-Config([hashtable]$Context) {
  $kind = $Context.row.formatter
  $config = $Context.config
  if ($kind -eq 'Prettier') {
    if ($config -and [IO.Path]::GetFileName($config) -in @('package.json', 'package.yaml')) {
      throw 'native-project-command-required'
    }
    $editorConfigs = @(
      $Context.ignores | Where-Object { [IO.Path]::GetFileName($_) -eq '.editorconfig' }
    )
    $terminates = $false
    foreach ($path in $editorConfigs) {
      if (Test-EditorConfigTermination (Read-Metadata $path)) { $terminates = $true }
    }
    $parentPolicy = $false
    foreach ($directory in $parentDirectories) {
      if (Test-Path -LiteralPath (Join-Path $directory '.editorconfig')) { $parentPolicy = $true; break }
    }
    if (($editorConfigs.Count -or $parentPolicy) -and -not $terminates) {
      throw 'native-project-command-required'
    }
  } elseif ($kind -eq 'Ruff') {
    $extraIgnores = @($Context.ignores | Where-Object { [IO.Path]::GetFileName($_) -eq '.ignore' })
    if ($extraIgnores.Count) { throw 'native-project-command-required' }
    if ($config) {
      $text = Read-Metadata $config
      $inside = ([IO.Path]::GetFileName($config) -ne 'pyproject.toml')
      foreach ($line in ($text -split '\r?\n')) {
        if ($line -match '^\s*(?:#.*)?$') { continue }
        if ($line -match '^\s*\[([\w.-]+)\]\s*(?:#.*)?$') {
          $section = $Matches[1]
          $inside = $section -in @('tool.ruff', 'tool.ruff.format', 'format')
          if ($section -match '^(tool\.)?ruff\.' -and -not $inside) { throw 'native-project-command-required' }
          continue
        }
        if ($line -match '^\s*\[') { throw 'native-project-command-required' }
        # The regex is an intentionally bounded literal profile, not a TOML parser.
        $scalarPattern = '^\s*(line-length|indent-width|target-version|preview|quote-style|indent-style|line-ending|skip-magic-trailing-comma|docstring-code-format|docstring-code-line-length)\s*=\s*(?:[0-9]+|true|false|"[^"\\]*"|''[^'']*'')\s*(?:#.*)?$'
        if ($inside -and $line -notmatch $scalarPattern) { throw 'native-project-command-required' }
      }
    }
  } elseif ($kind -eq 'Biome') {
    if (-not $config -or [IO.Path]::GetExtension($config) -eq '.jsonc') {
      throw 'native-project-command-required'
    }
    try { $data = ConvertFrom-Json -InputObject (Read-Metadata $config) -AsHashtable }
    catch { throw 'native-project-command-required' }
    Assert-BiomeKeys $data
  }
}
function Assert-BiomeKeys($Value) {
  # Recursive key inspection is only for strict JSON, never a JSONC/TOML approximation.
  if ($Value -is [Collections.IDictionary]) {
    foreach ($key in $Value.Keys) {
      if ($key -in @('extends', 'overrides', 'includes', 'ignore', 'files', 'vcs', 'plugins')) {
        throw 'native-project-command-required'
      }
      Assert-BiomeKeys $Value[$key]
    }
  } elseif ($Value -is [array]) { foreach ($item in $Value) { Assert-BiomeKeys $item } }
}

# Only native executables or a trusted Prettier JS entrypoint are accepted, never shell shims.
function Resolve-Tool([hashtable]$Context) {
  $kind = $Context.row.formatter
  $path = $ToolPath
  if (-not $path -and $kind -eq 'Prettier' -and $Context.packageDirectory) {
    $directory = Join-Path $Context.packageDirectory 'node_modules/prettier'
    $manifestPath = Join-Path $directory 'package.json'
    $manifest = ConvertFrom-Json -InputObject (Read-Metadata $manifestPath) -AsHashtable
    $bin = $null
    if ($manifest.bin -is [string]) { $bin = $manifest.bin }
    elseif ($manifest.bin -is [Collections.IDictionary]) { $bin = $manifest.bin.prettier }
    if ($bin -and -not [IO.Path]::IsPathRooted($bin)) {
      $path = [IO.Path]::GetFullPath((Join-Path $directory $bin))
      if (-not $path.StartsWith($directory + [IO.Path]::DirectorySeparatorChar, $comparison)) {
        throw 'unsafe-tool-path'
      }
    }
  }
  if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'missing-tool' }
  $path = (Resolve-Path -LiteralPath $path).Path
  Assert-Plain $path
  $extension = [IO.Path]::GetExtension($path).ToLowerInvariant()
  $Context.prefix = @()
  if ($kind -eq 'PowerShell') {
    if ($extension -ne '.psd1') { throw 'unsupported-tool-path' }
    $Context.executable = Join-Path $PSHOME $(if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' })
    $worker = Join-Path $PSScriptRoot 'format-code-powershell.ps1'
    $Context.prefix = @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', $worker)
    $Context.modulePath = $path
  } elseif ($kind -eq 'Prettier' -and $extension -in @('.js', '.cjs', '.mjs')) {
    $node = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $node) { throw 'missing-node-runtime' }
    $Context.executable = $node.Source
    $Context.prefix = @($path)
  } elseif (($IsWindows -and $extension -eq '.exe') -or (-not $IsWindows -and -not $extension)) {
    $Context.executable = $path
  } else { throw 'unsupported-tool-path' }
  $Context.tool = $path
}

# Drain bounded chunks while stdin writes asynchronously; neither stream can deadlock a child.
function Invoke-Tool([hashtable]$Context, [string[]]$Arguments, [string]$InputText = '') {
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $Context.executable
  $info.WorkingDirectory = $root
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.RedirectStandardInput = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  $info.StandardInputEncoding = $utf8
  $info.StandardOutputEncoding = $utf8
  $info.StandardErrorEncoding = $utf8
  foreach ($argument in (@($Context.prefix) + @($Arguments))) { $info.ArgumentList.Add($argument) }
  foreach ($name in @('NODE_OPTIONS', 'NODE_PATH', 'BIOME_LOG_FILE', 'BIOME_LOG_PREFIX_NAME')) {
    $null = $info.Environment.Remove($name)
  }
  $info.Environment['NO_COLOR'] = '1'
  $info.Environment['CI'] = '1'
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $info
  try {
    $null = $process.Start()
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $write = $process.StandardInput.WriteAsync($InputText)
    $buffers = @([char[]]::new(4096), [char[]]::new(4096))
    $readers = @($process.StandardOutput, $process.StandardError)
    $tasks = @($readers[0].ReadAsync($buffers[0], 0, 4096), $readers[1].ReadAsync($buffers[1], 0, 4096))
    $texts = @([Text.StringBuilder]::new(), [Text.StringBuilder]::new())
    $encoders = @($utf8.GetEncoder(), $utf8.GetEncoder())
    $encodedChunk = [byte[]]::new($utf8.GetMaxByteCount(4096))
    $capturedBytes = 0
    $closed = $false
    while (-not $process.HasExited -or $tasks[0] -or $tasks[1]) {
      if ($watch.Elapsed.TotalSeconds -gt $TimeoutSeconds) { throw 'tool-timeout' }
      if (-not $closed -and $write.IsCompleted) {
        $write.GetAwaiter().GetResult()
        $process.StandardInput.Close()
        $closed = $true
      }
      for ($index = 0; $index -lt 2; $index++) {
        if ($tasks[$index] -and $tasks[$index].IsCompleted) {
          $count = $tasks[$index].GetAwaiter().GetResult()
          $charactersUsed = 0
          $bytesUsed = 0
          $completed = $false
          $encoders[$index].Convert(
            $buffers[$index], 0, $count, $encodedChunk, 0, $encodedChunk.Length,
            ($count -eq 0), [ref]$charactersUsed, [ref]$bytesUsed, [ref]$completed
          )
          if ($charactersUsed -ne $count -or -not $completed) { throw 'invalid-formatter-output' }
          $capturedBytes += $bytesUsed
          if ($capturedBytes -gt 4194304) { throw 'tool-output-limit' }
          if ($count -eq 0) {
            $tasks[$index] = $null
            continue
          }
          # UTF-8 encoders carry split surrogate pairs across chunks; budget is
          # combined stdout/stderr bytes, not UTF-16 character count.
          $null = $texts[$index].Append($buffers[$index], 0, $count)
          $tasks[$index] = $readers[$index].ReadAsync($buffers[$index], 0, 4096)
        }
      }
      [Threading.Thread]::Sleep(10)
    }
    $process.WaitForExit()
    return @{ code = $process.ExitCode; output = $texts[0].ToString() }
  } finally {
    if ($process.Id -and -not $process.HasExited) {
      $process.Kill($true)
      $process.WaitForExit(1000) | Out-Null
    }
    $process.Dispose()
  }
}

# Strict decoders avoid lossy rewrites. Mixed/newline-sensitive representations are not normalized.
function Read-Source([hashtable]$Context) {
  $bytes = [IO.File]::ReadAllBytes($Context.full)
  $offset = 0
  $encoding = $utf8
  $utf32 = $bytes.Length -ge 4 -and (
    ($bytes[0] -eq 255 -and $bytes[1] -eq 254 -and $bytes[2] -eq 0 -and $bytes[3] -eq 0) -or
    ($bytes[0] -eq 0 -and $bytes[1] -eq 0 -and $bytes[2] -eq 254 -and $bytes[3] -eq 255)
  )
  if ($utf32) { throw 'unsupported-encoding' }
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) { $offset = 3 }
  elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 255 -and $bytes[1] -eq 254) {
    $encoding = [Text.UnicodeEncoding]::new($false, $true, $true)
    $offset = 2
  } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 254 -and $bytes[1] -eq 255) {
    $encoding = [Text.UnicodeEncoding]::new($true, $true, $true)
    $offset = 2
  }
  try { $text = $encoding.GetString($bytes, $offset, $bytes.Length - $offset) } catch { throw 'unsupported-encoding' }
  if ($text.Contains([char]0)) { throw 'unsupported-encoding' }
  if ($text -match '\r(?!\n)' -or ($text.Contains("`r`n") -and $text -match '(?<!\r)\n')) {
    throw 'mixed-or-unsupported-eol'
  }
  $header = $text.Substring(0, [Math]::Min(4096, $text.Length))
  if ($header -match '(?im)(auto[- ]generated|generated file|do not edit)') {
    throw 'protected-generated-content'
  }
  $Context.bytes = $bytes
  $Context.encoding = $encoding
  # Assign directly: returning an empty array from an if expression produces
  # $null in PowerShell and would prepend a NUL byte during candidate assembly.
  $Context.bom = [byte[]]@()
  if ($offset) { $Context.bom = [byte[]]$bytes[0..($offset - 1)] }
  $Context.eol = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
  $Context.text = $text
  $Context.hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
}

# Honor applicable Git exclusions even for tracked/literal paths; never initialize Git here.
function Test-GitIgnored([hashtable]$Context) {
  $hasIgnore = @($Context.ignores | Where-Object { [IO.Path]::GetFileName($_) -eq '.gitignore' }).Count -gt 0
  $rootMarker = Test-Path -LiteralPath (Join-Path $root '.git')
  if (-not $rootMarker) {
    foreach ($directory in $parentDirectories) {
      if (Test-Path -LiteralPath (Join-Path $directory '.git')) { throw 'git-policy-boundary' }
    }
  }
  if (-not $hasIgnore -and -not $rootMarker) { return $false }
  $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $git) { throw 'git-policy-unavailable' }
  $gitContext = @{ executable = $git.Source; prefix = @() }
  $boundary = Invoke-Tool $gitContext @('-C', $root, 'rev-parse', '--show-toplevel')
  $repository = $boundary.output.Trim().Replace('/', '\')
  if ($boundary.code -ne 0 -or -not $repository.Equals($root.Replace('/', '\'), $comparison)) {
    throw 'git-policy-boundary'
  }
  $probe = Invoke-Tool $gitContext @('-C', $root, 'check-ignore', '--no-index', '-q', '--', $Context.row.path)
  if ($probe.code -gt 1) { throw 'git-policy-unavailable' }
  return $probe.code -eq 0
}

# Fixed formatter-only arguments; native ignored files are excluded before requesting output.
function Get-Candidate([hashtable]$Context) {
  $kind = $Context.row.formatter
  $versionArguments = @('--version')
  if ($kind -eq 'PowerShell') {
    $versionArguments = @('-Mode', 'Version', '-ModulePath', $Context.modulePath)
  }
  $version = Invoke-Tool $Context $versionArguments
  if ($version.code -ne 0 -or [string]::IsNullOrWhiteSpace($version.output) -or
      $version.output.Trim().Length -gt 100 -or
      $version.output.Trim() -match '[\r\n\x00]') { throw 'tool-version-failed' }
  $Context.row.version = $version.output.Trim()
  $arguments = @()
  if ($kind -eq 'Prettier') {
    $ignoreArguments = @()
    foreach ($path in $Context.ignores) {
      if ([IO.Path]::GetFileName($path) -in @('.gitignore', '.prettierignore')) {
        $ignoreArguments += @('--ignore-path', $path)
      }
    }
    $fileInfo = Invoke-Tool $Context (@('--file-info', $Context.full) + $ignoreArguments)
    if ($fileInfo.code -ne 0) { throw 'tool-policy-failed' }
    try { $metadata = ConvertFrom-Json -InputObject $fileInfo.output -AsHashtable } catch { throw 'tool-policy-failed' }
    if ($metadata.ignored -isnot [bool]) { throw 'tool-policy-failed' }
    if ($metadata.ignored) { $Context.row.status = 'excluded'; $Context.row.reason = 'formatter-ignored'; return }
    if (-not $metadata.inferredParser) { throw 'unsupported-file-type' }
    $arguments = @('--stdin-filepath', $Context.full) + $ignoreArguments
    $arguments += if ($Context.config) { @('--config', $Context.config) } else { @('--no-config') }
    $editorConfigs = @(
      $Context.ignores | Where-Object { [IO.Path]::GetFileName($_) -eq '.editorconfig' }
    )
    if (-not $editorConfigs.Count) { $arguments += '--no-editorconfig' }
  } elseif ($kind -eq 'Ruff') {
    $arguments = @('format', '--stdin-filename', $Context.full, '--force-exclude', '--no-cache')
    $arguments += if ($Context.config) { @('--config', $Context.config) } else { @('--isolated') }
    $arguments += '-'
  } elseif ($kind -eq 'Biome') {
    $arguments = @('format', "--stdin-file-path=$($Context.full)", "--config-path=$($Context.config)")
  } else {
    $arguments = @('-Mode', 'Format', '-ModulePath', $Context.modulePath)
    if ($Context.config) { $arguments += @('-SettingsPath', $Context.config) }
  }
  $formatted = Invoke-Tool $Context $arguments $Context.text
  if ($formatted.code -ne 0) { throw 'formatter-failed' }
  if (-not [string]::IsNullOrWhiteSpace($Context.text) -and
      [string]::IsNullOrWhiteSpace($formatted.output)) { throw 'empty-formatter-output' }
  $text = $formatted.output.Replace("`r`n", "`n").Replace("`n", $Context.eol)
  if ($text.Contains([char]0) -or $text -match '\r(?!\n)') { throw 'invalid-formatter-output' }
  $Context.candidate = [byte[]](@($Context.bom) + @($Context.encoding.GetBytes($text)))
  if ($Context.candidate.Length -gt 4194304) { throw 'tool-output-limit' }
  $original = [Convert]::ToBase64String($Context.bytes)
  $candidate = [Convert]::ToBase64String($Context.candidate)
  $Context.row.changed = -not $original.Equals($candidate, [StringComparison]::Ordinal)
  $Context.row.status = if ($Context.row.changed) { 'would-change' } else { 'clean' }
  $Context.row.reason = 'candidate-compared'
}

# Verify original content and all inspected config snapshots after trusted child execution.
function Assert-Unchanged {
  foreach ($context in $contexts) {
    Assert-Plain $context.full
    $hash = (Get-FileHash -LiteralPath $context.full -Algorithm SHA256).Hash
    if ($hash -ne $context.hash) { throw 'source-changed-during-execution' }
  }
  foreach ($path in $snapshots.Keys) {
    Assert-Plain $path
    $hash = 'absent'
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
    if ($hash -ne $snapshots[$path]) { throw 'config-changed-during-execution' }
  }
}

# Keep incidental .NET/process diagnostics and absolute paths out of the public JSON.
function Get-Reason($Failure) {
  $message = $Failure.Exception.Message
  if ($message -cmatch '^[a-z][a-z0-9-]{0,79}$') { return $message }
  return 'unexpected-runtime-failure'
}

$globalFailure = $null
try {
  try { $root = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('/', '\') } catch { throw 'invalid-project-root' }
  Assert-Plain $root
  if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'invalid-project-root' }
  $parentDirectories = @(Get-ParentDirectories)
  if ($Files.Count -eq 0 -or $Files.Count -gt 100) { throw 'file-count-limit' }
  $seen = @{}
  foreach ($relative in $Files) {
    $displayPath = if ([IO.Path]::IsPathRooted($relative)) { '<invalid>' } else { $relative.Replace('\', '/') }
    $row = @{
      path = $displayPath; formatter = $null; configPaths = @(); status = 'blocked'
      reason = $null; version = $null; changed = $false
    }
    $rows.Add($row)
    try {
      $full = Resolve-File $relative
      if ($seen.ContainsKey($full)) { throw 'duplicate-file' }
      $seen[$full] = $true
      $context = @{ row = $row; full = $full; ancestors = @(Get-Ancestors $full) }
      Read-Source $context
      Find-Selection $context
      Assert-Config $context
      Resolve-Tool $context
      $row.status = 'planned'
      $row.reason = 'metadata-selected-policy-pending'
      $contexts.Add($context)
    } catch { $row.reason = Get-Reason $_ }
  }
  $selectedFormatters = @($contexts | ForEach-Object { $_.row.formatter } | Sort-Object -Unique)
  if ($ToolPath -and $selectedFormatters.Count -gt 1) { throw 'mixed-explicit-tool-path' }
  if ($Action -ne 'Plan') {
    if (-not $TrustTooling) { throw 'tooling-acknowledgment-required' }
    if ($Action -eq 'Apply' -and -not $AllowWrite) { throw 'write-acknowledgment-required' }
    if (@($rows | Where-Object status -eq 'blocked').Count) { throw 'batch-preflight-blocked' }
    foreach ($context in $contexts) {
      try {
        if (Test-GitIgnored $context) {
          $context.row.status = 'excluded'
          $context.row.reason = 'git-ignored'
          continue
        }
        Get-Candidate $context
      } catch { $context.row.status = 'error'; $context.row.reason = Get-Reason $_ }
    }
    Assert-Unchanged
    if ($Action -eq 'Apply') {
      if (@($rows | Where-Object status -in @('blocked', 'error')).Count) {
        foreach ($row in $rows | Where-Object status -eq 'would-change') {
          $row.status = 'blocked'; $row.reason = 'batch-candidate-failed'
        }
      } else {
        foreach ($context in $contexts | Where-Object { $_.row.status -eq 'would-change' }) {
          # Exclusive compare-before-write reduces concurrent-writer races. This is not
          # a multi-file transaction; a late I/O failure is reported as partial completion.
          $stream = $null
          try {
            Assert-Plain $context.full
            $stream = [IO.File]::Open(
              $context.full, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None
            )
            $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream))
            if ($hash -ne $context.hash) { throw 'source-changed-before-write' }
            $stream.Position = 0
            $stream.Write($context.candidate, 0, $context.candidate.Length)
            $stream.SetLength($context.candidate.Length)
            $stream.Flush($true)
            $context.row.status = 'applied'
            $context.row.reason = 'exact-file-written'
          } catch { $context.row.status = 'error'; $context.row.reason = 'write-failed-possible-partial'; break }
          finally { if ($stream) { $stream.Dispose() } }
        }
        if (@($rows | Where-Object status -eq 'error').Count) {
          foreach ($row in $rows | Where-Object status -eq 'would-change') {
            $row.status = 'blocked'; $row.reason = 'batch-write-interrupted'
          }
        }
      }
    }
  }
} catch {
  $globalFailure = Get-Reason $_
  foreach ($row in $rows | Where-Object status -in @('planned', 'would-change', 'clean')) {
    $row.status = 'blocked'; $row.reason = $globalFailure
  }
  if (-not $rows.Count) {
    $rows.Add(@{
      path = '<request>'; formatter = $null; configPaths = @(); status = 'blocked'
      reason = $globalFailure; version = $null; changed = $false
    })
  }
}

$blocked = @($rows | Where-Object status -eq 'blocked').Count
$errors = @($rows | Where-Object status -eq 'error').Count
$changed = @($rows | Where-Object changed).Count
$applied = @($rows | Where-Object status -eq 'applied').Count
@{
  schemaVersion = 1; kitVersion = '1.0.5'; action = $Action; results = $rows.ToArray()
  summary = @{ total = $rows.Count; changed = $changed; applied = $applied; blocked = $blocked; errors = $errors }
  limitations = @(
    'metadata-selection-not-semantic-authority', 'trusted-process-not-os-sandbox',
    'formatting-not-semantic-proof', 'multi-file-writes-not-transactional'
  )
} | ConvertTo-Json -Depth 8
if ($blocked -or $errors -or $globalFailure) { exit 2 }
if ($Action -eq 'Check' -and $changed) { exit 1 }
exit 0
