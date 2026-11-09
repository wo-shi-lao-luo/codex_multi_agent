# Resolve and provision the Kit's private Node runtime. No global PATH or package manager changes.
# Dot-source this module; only Ensure-BoardRuntime may publish a dependency.
$script:BoardRuntimeLockPath = Join-Path $PSScriptRoot '../runtime/node-runtime.json'

# Reject links, including linked ancestors, before inspecting or writing managed paths.
function Assert-BoardRuntimePlain([string]$Path) {
  for ($cursor = [IO.Path]::GetFullPath($Path); $cursor; $cursor = Split-Path -Parent $cursor) {
    try { $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop }
    catch [System.Management.Automation.ItemNotFoundException] { $item = $null }
    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      if ($IsMacOS -and $cursor -in @('/tmp','/var') -and
          $item.LinkTarget -ceq ('/private'+$cursor)) { continue }
      throw 'RUNTIME_CONFLICT: Linked runtime path is unsupported.'
    }
  }
}

# Lock files are data. The installer compares selected-package data to its trusted local pin.
function Get-BoardRuntimeLock {
  return Get-Content -LiteralPath $script:BoardRuntimeLockPath -Raw | ConvertFrom-Json -AsHashtable
}

function Get-BoardRuntimePlatform {
  $os = if ($IsWindows) { 'win32' } elseif ($IsMacOS) { 'darwin' } else { 'linux' }
  $arch = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
  if ($arch -notin @('x64','arm64')) { throw 'RUNTIME_PLATFORM: Only x64 and arm64 are supported.' }
  return "$os-$arch"
}

# Run a bounded, captured probe; never include child output in an error or log.
function Invoke-BoardRuntimeProcess([string]$NodePath, [string[]]$Arguments) {
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $NodePath
  $info.UseShellExecute = $false
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $info
  try {
    $null = $process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(15000)) {
      $process.Kill($true)
      $process.WaitForExit()
      throw 'RUNTIME_PROBE: Timed out.'
    }
    $null = $stderr.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) { throw 'RUNTIME_PROBE: Child failed.' }
    return $stdout.GetAwaiter().GetResult() | ConvertFrom-Json -AsHashtable
  } finally { $process.Dispose() }
}

# Verify actual Node and in-memory SQLite versions rather than trusting a zero exit code.
function Assert-BoardRuntimeVersions($Result) {
  if ($Result.available -isnot [bool] -or $Result.available -cne $true -or
      $Result.nodeVersion -cnotmatch '^26\.(\d+)\.\d+$' -or
      [int]$Matches[1] -lt 13) { throw 'RUNTIME_UNAVAILABLE: Node >=26.13.0 <27 required.' }
  if ($Result.sqliteVersion -cnotmatch '^(\d+)\.(\d+)\.\d+$' -or
      ([int]$Matches[1] -lt 3) -or ([int]$Matches[1] -eq 3 -and [int]$Matches[2] -lt 54)) {
    throw 'RUNTIME_UNAVAILABLE: SQLite >=3.54.0 required.'
  }
}

# With no CLI, probe only fixed JavaScript and a closed memory database. With CLI, validate its envelope.
function Invoke-BoardRuntimeProbe([string]$NodePath, [string]$CliPath) {
  if ($CliPath) {
    $reply = Invoke-BoardRuntimeProcess $NodePath @($CliPath, 'runtime-doctor')
    if (($reply.schemaVersion -isnot [long] -and $reply.schemaVersion -isnot [int]) -or
        $reply.schemaVersion -ne 1 -or $reply.operation -cne 'runtime-doctor' -or
        $reply.ok -isnot [bool] -or $reply.ok -cne $true) {
      throw 'RUNTIME_PROTOCOL: Invalid runtime-doctor response.'
    }
    $result = $reply.result
  } else {
    $code = "const {DatabaseSync}=require('node:sqlite');const d=new DatabaseSync(':memory:');const s=d.prepare('SELECT sqlite_version() AS version').get().version;d.close();console.log(JSON.stringify({nodeVersion:process.versions.node,sqliteVersion:s,available:true}))"
    $result = Invoke-BoardRuntimeProcess $NodePath @('-e', $code)
  }
  Assert-BoardRuntimeVersions $result
  return $result
}

# A managed runtime is immutable and must have exactly its receipt-owned files before execution.
function Get-BoardManagedNode([string]$AgentsHome) {
  $lock = Get-BoardRuntimeLock
  $platform = Get-BoardRuntimePlatform
  $target = Join-Path $AgentsHome "codex-multi-agent/runtimes/node/$($lock.nodeVersion)/$platform"
  Assert-BoardRuntimePlain $target
  if (-not (Test-Path -LiteralPath $target)) { return $null }
  $nodeName = if ($IsWindows) { 'node.exe' } else { 'node' }
  $receiptPath = Join-Path $target 'runtime-receipt.json'
  $files = @(Get-ChildItem -LiteralPath $target -Force)
  if ($files.Count -ne 3 -or -not [IO.File]::Exists($receiptPath)) {
    throw 'RUNTIME_CONFLICT: Unknown runtime directory.'
  }
  $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json -AsHashtable
  if ($receipt.schemaVersion -ne 1 -or $receipt.nodeVersion -cne $lock.nodeVersion -or
      $receipt.platform -cne $platform -or
      $receipt.archiveSha256 -cne $lock.platforms[$platform].sha256 -or $receipt.files.Count -ne 2) {
    throw 'RUNTIME_CONFLICT: Invalid runtime receipt.'
  }
  foreach ($name in @($nodeName, 'LICENSE')) {
    $file = Join-Path $target $name
    Assert-BoardRuntimePlain $file
    if (-not [IO.File]::Exists($file) -or
        (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -cne $receipt.files[$name]) {
      throw 'RUNTIME_CONFLICT: Runtime integrity failed.'
    }
  }
  return Join-Path $target $nodeName
}

# Prefer the verified managed runtime; an explicit or PATH runtime must pass the same live probe.
function Resolve-BoardNode([string]$AgentsHome, [string]$NodePath) {
  $managed = Get-BoardManagedNode $AgentsHome
  if ($managed) { return @{ nodePath=$managed; kind='managed'; diagnostic=(Invoke-BoardRuntimeProbe $managed) } }
  if (-not $NodePath) {
    $command = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { $NodePath = $command.Source }
  }
  if ($NodePath -and [IO.File]::Exists($NodePath)) {
    try {
      $diagnostic = Invoke-BoardRuntimeProbe ([IO.Path]::GetFullPath($NodePath))
      return @{ nodePath=[IO.Path]::GetFullPath($NodePath); kind='existing'; diagnostic=$diagnostic }
    } catch { }
  }
  return $null
}

# Download only the fixed official archive, without redirects, with a 120-second/150-MiB bound.
function Save-BoardRuntimeArchive([string]$Archive, [string]$Destination) {
  $handler = [Net.Http.HttpClientHandler]::new()
  $handler.AllowAutoRedirect = $false
  $client = [Net.Http.HttpClient]::new($handler)
  $cancel = [Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(120))
  try {
    $uri = "https://nodejs.org/dist/v26.13.0/$Archive"
    Write-Information "Downloading pinned Node runtime from nodejs.org ($Archive)." -InformationAction Continue
    $response = $client.GetAsync($uri, [Net.Http.HttpCompletionOption]::ResponseHeadersRead,
      $cancel.Token).GetAwaiter().GetResult()
    try {
      if ([int]$response.StatusCode -ne 200) { throw 'RUNTIME_DOWNLOAD: Official download failed.' }
      $input = $response.Content.ReadAsStreamAsync($cancel.Token).GetAwaiter().GetResult()
      $output = [IO.File]::Create($Destination)
      try {
        $buffer = [byte[]]::new(65536)
        $total = 0L
        while (($read = $input.ReadAsync($buffer, 0, $buffer.Length, $cancel.Token).GetAwaiter().GetResult()) -gt 0) {
          $total += $read
          if ($total -gt 157286400) { throw 'RUNTIME_DOWNLOAD: Archive exceeds size limit.' }
          $output.Write($buffer, 0, $read)
        }
      } finally { $output.Dispose(); $input.Dispose() }
    } finally { $response.Dispose() }
  } finally { $cancel.Dispose(); $client.Dispose() }
}

# Extract only hash-authenticated allowlisted members. Never unpack npm or archive links.
function Expand-BoardRuntimeArchive([string]$ArchivePath, $Pin, [string]$Stage) {
  $nodeName = if ($IsWindows) { 'node.exe' } else { 'node' }
  if ($IsWindows) {
    $zip = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
      $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($entry in $zip.Entries) {
        if ($entry.FullName -match '(^|/)\.\.(/|$)|^[\\/]|:|\\' -or
            -not $seen.Add($entry.FullName) -or
            (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) {
          throw 'RUNTIME_ARCHIVE: Unsafe archive entry.'
        }
      }
      foreach ($pair in @(@($Pin.nodeMember,$nodeName), @($Pin.licenseMember,'LICENSE'))) {
        $entry = $zip.GetEntry($pair[0])
        if (-not $entry -or $entry.Length -gt 157286400) { throw 'RUNTIME_ARCHIVE: Invalid member.' }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $Stage $pair[1]))
      }
    } finally { $zip.Dispose() }
  } else {
    $tar = Get-Command tar -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $compression = if ($Pin.archive.EndsWith('.tar.gz')) { '-xzf' } else { '-xJf' }
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $tar.Source
    $info.UseShellExecute = $false
    foreach ($argument in @($compression,$ArchivePath,'-C',$Stage,'--',$Pin.nodeMember,$Pin.licenseMember)) {
      $info.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::Start($info)
    try {
      if (-not $process.WaitForExit(30000)) {
        $process.Kill($true)
        $process.WaitForExit()
        throw 'RUNTIME_ARCHIVE: Extraction timed out.'
      }
      if ($process.ExitCode -ne 0) { throw 'RUNTIME_ARCHIVE: Extraction failed.' }
    } finally { $process.Dispose() }
    foreach ($pair in @(@($Pin.nodeMember,$nodeName), @($Pin.licenseMember,'LICENSE'))) {
      $source = Join-Path $Stage $pair[0]
      Assert-BoardRuntimePlain $source
      [IO.File]::Move($source, (Join-Path $Stage $pair[1]))
    }
    $expanded = Join-Path $Stage ($Pin.nodeMember.Split('/')[0])
    [IO.Directory]::Delete($expanded, $true)
  }
}

# Resolve first; otherwise authenticate offline/downloaded bytes before extraction and execution.
# Publication uses a short exclusive lock and atomic same-volume rename; old versions are retained.
function Ensure-BoardRuntime([string]$AgentsHome,
    [string]$RuntimeArchivePath, [switch]$Offline) {
  $resolved = Resolve-BoardNode $AgentsHome
  if ($resolved) { return $resolved }
  $lock = Get-BoardRuntimeLock
  $platform = Get-BoardRuntimePlatform
  $pin = $lock.platforms[$platform]
  if ($Offline -and -not $RuntimeArchivePath) { throw 'RUNTIME_OFFLINE: Supply RuntimeArchivePath or a compatible runtime.' }
  $temporary = Join-Path ([IO.Path]::GetTempPath()) ('codex-node-'+[guid]::NewGuid().ToString('N'))
  $stage = $null
  $publishLock = $null
  try {
    [IO.Directory]::CreateDirectory($temporary) | Out-Null
    if (-not $RuntimeArchivePath) {
      $RuntimeArchivePath = Join-Path $temporary $pin.archive
      Save-BoardRuntimeArchive $pin.archive $RuntimeArchivePath
    }
    if (-not [IO.File]::Exists($RuntimeArchivePath) -or
        (Get-Item -LiteralPath $RuntimeArchivePath).Length -gt 157286400 -or
        (Get-FileHash -LiteralPath $RuntimeArchivePath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $pin.sha256) {
      throw 'RUNTIME_ARCHIVE: Archive SHA256 does not match the fixed official pin.'
    }
    $parent = Join-Path $AgentsHome "codex-multi-agent/runtimes/node/$($lock.nodeVersion)"
    Assert-BoardRuntimePlain $parent
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    $stage = Join-Path $parent ('.staging-'+[guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($stage) | Out-Null
    Expand-BoardRuntimeArchive $RuntimeArchivePath $pin $stage
    $nodeName = if ($IsWindows) { 'node.exe' } else { 'node' }
    $diagnostic = Invoke-BoardRuntimeProbe (Join-Path $stage $nodeName)
    $hashes = @{}
    foreach ($name in @($nodeName,'LICENSE')) {
      $hashes[$name] = (Get-FileHash -LiteralPath (Join-Path $stage $name) -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    @{schemaVersion=1; nodeVersion=$lock.nodeVersion; platform=$platform;
      archiveSha256=$pin.sha256; files=$hashes} | ConvertTo-Json -Depth 5 |
      Set-Content -LiteralPath (Join-Path $stage 'runtime-receipt.json') -Encoding utf8
    $lockPath = Join-Path $parent 'publish.lock'
    Assert-BoardRuntimePlain $lockPath
    $publishLock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None')
    $existing = Get-BoardManagedNode $AgentsHome
    if (-not $existing) { [IO.Directory]::Move($stage, (Join-Path $parent $platform)); $stage=$null }
    return @{nodePath=(Get-BoardManagedNode $AgentsHome);kind='managed';diagnostic=$diagnostic;retained=$true}
  } finally {
    if ($publishLock) { $publishLock.Dispose() }
    if ($stage -and [IO.Directory]::Exists($stage)) { [IO.Directory]::Delete($stage,$true) }
    if ([IO.Directory]::Exists($temporary)) { [IO.Directory]::Delete($temporary,$true) }
  }
}
