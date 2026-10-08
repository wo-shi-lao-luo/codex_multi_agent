#requires -Version 7.0
<#
Protect exact kit-owned local artifacts before their callers create them. Check is a
read-only index/policy audit; neither action initializes Git or changes its index.
Documentation protects the generated marker, index and whole review subtree; other
formal governance documents remain outside this local runtime bundle.
WorkPath ownership must be declared by the task contract. Ignore rules are staging
hygiene, not a security boundary against git add -f or external writers.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('Protect','Check')][string]$Action,
  [Parameter(Mandatory)][string]$ProjectRoot,
  [string]$DocsRoot = 'docs',
  [Parameter(Mandatory)][ValidateSet('Documentation','OpenSpec','Work')][string]$Profile,
  [string]$WorkPath
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('/','\')
if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'PATH: ProjectRoot must be an existing directory.' }

# Missing leaves are permitted, but existing linked ancestors never confer ownership.
function Assert-ArtifactPlain([string]$Path) {
  $cursor = $Path
  while ($cursor) {
    if (Test-Path -LiteralPath $cursor) {
      if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'PATH: Linked artifact paths are unsupported.' }
    }
    $next = Split-Path -Parent $cursor
    if ($next -eq $cursor) { break }; $cursor = $next
  }
}
# Validate literal project paths before using them as anchored Gitignore patterns.
function Resolve-ArtifactRelative([string]$Relative) {
  if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative)) { throw 'PATH: Require a repository-relative artifact path.' }
  $value = $Relative.Replace('\','/')
  foreach ($part in ($value -split '/')) {
    if ($part -in @('','.','..') -or $part -match '[<>:"|?*\[\]#\x00-\x1f]' -or $part -match '[ .]$' -or $part -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)' -or $part -match '^(\.git|\.aws|\.ssh|\.azure|\.gnupg|node_modules|vendor|\.venv|venv)$') { throw 'PATH: Unsafe artifact path segment.' }
  }
  $full = [IO.Path]::GetFullPath((Join-Path $root $value))
  if (-not $full.StartsWith($root + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'PATH: Artifact path leaves ProjectRoot.' }
  Assert-ArtifactPlain $full
  return $value
}
Assert-ArtifactPlain $root
$DocsRoot = Resolve-ArtifactRelative $DocsRoot
if ($Profile -eq 'Work') {
  $WorkPath = Resolve-ArtifactRelative $WorkPath
  if ($WorkPath -notmatch '^_work/[a-z][a-z0-9]*(?:-[a-z0-9]+)*$' -or $WorkPath.Length -gt 86) { throw 'PATH: WorkPath must name one explicitly owned _work/<bounded-task-slug> subtree.' }
} elseif ($WorkPath) { throw 'PATH: WorkPath is valid only for the Work profile.' }
$governance = "$DocsRoot/governance"
$uuidGlob = ('[0-9a-f]' * 32)
$rules = switch ($Profile) {
  Documentation {
    "/$governance/reviews/"; "/$governance/documentation.json"; "/$governance/doc-index.md"
    "/$governance/.documentation.lock"; "/$governance/.pending.json"
    foreach ($leaf in @('documentation.json','doc-index.md','.pending.json')) { "/$governance/$leaf.$uuidGlob.tmp" }
    foreach ($extension in @('json','md')) { "/$governance/reviews/*.$extension.$uuidGlob.tmp" }
  }
  OpenSpec { '/openspec/.team-recovery/'; '/openspec/.team-archive.lock' }
  Work { "/$WorkPath/" }
}
$localDirectories = switch ($Profile) { Documentation { "$governance/reviews" } OpenSpec { 'openspec/.team-recovery' } Work { $WorkPath } }
$scanRoots = switch ($Profile) { Documentation { $governance } OpenSpec { 'openspec/.team-recovery' } Work { $WorkPath } }

# Classification is independent of ignore matching: tracked files remain risky even
# when a project already ignores them. Near-miss UUID and user lock names stay visible.
function Test-LocalArtifact([string]$Relative) {
  foreach ($directory in $localDirectories) {
    if ($Relative -ceq $directory -or $Relative.StartsWith("$directory/",[StringComparison]::Ordinal)) { return $true }
  }
  if ($Profile -eq 'OpenSpec') { return $Relative -ceq 'openspec/.team-archive.lock' }
  if ($Profile -eq 'Work') { return $false }
  $prefix = [regex]::Escape($governance)
  return $Relative -cmatch "^$prefix/(?:documentation\.json|doc-index\.md|\.documentation\.lock|\.pending\.json|(?:documentation\.json|doc-index\.md|\.pending\.json)\.[a-f0-9]{32}\.tmp|reviews/[^/]+\.(?:json|md)\.[a-f0-9]{32}\.tmp)$"
}
$probes = switch ($Profile) {
  Documentation {
    "$governance/documentation.json"; "$governance/doc-index.md"
    foreach ($extension in @('json','md')) { "$governance/reviews/kit-probe.$extension" }
    "$governance/reviews/archive/kit-probe.json"; "$governance/.documentation.lock"; "$governance/.pending.json"
    foreach ($leaf in @('documentation.json','doc-index.md','.pending.json')) { "$governance/$leaf.$('a' * 32).tmp" }
    foreach ($extension in @('json','md')) { "$governance/reviews/kit-probe.$extension.$('a' * 32).tmp" }
  }
  OpenSpec { 'openspec/.team-recovery/kit-probe.json'; 'openspec/.team-archive.lock' }
  Work { "$WorkPath/kit-probe.txt" }
}
foreach ($probe in $probes) { $null = Resolve-ArtifactRelative $probe }
$ignorePath = Join-Path $root '.gitignore'
Assert-ArtifactPlain $ignorePath
if (Test-Path -LiteralPath $ignorePath -PathType Container) { throw 'PATH: .gitignore must be a plain file.' }
$gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $gitCommand) { throw 'DEPENDENCY: Git is required to inspect artifact staging policy.' }
# Sandbox identities can differ from the project owner. Trust only the containing
# explicit local Git boundary for these fixed read-only commands, never a wildcard.
$trustedGitRoot = $root
while ($trustedGitRoot -and -not (Test-Path -LiteralPath (Join-Path $trustedGitRoot '.git'))) {
  $next = Split-Path -Parent $trustedGitRoot
  if ($next -eq $trustedGitRoot) { break }; $trustedGitRoot = $next
}
if ($trustedGitRoot) { Assert-ArtifactPlain (Join-Path $trustedGitRoot '.git') }

# Fixed argument arrays, bounded subprocesses, and child-only config isolation avoid
# global configuration/excludes and never execute a shell, hooks or network operations.
function Invoke-ArtifactGit([string[]]$Arguments, [int[]]$Allowed = @(0), [string]$InputText = '') {
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $gitCommand.Source; $info.WorkingDirectory = $root
  $info.UseShellExecute = $false; $info.CreateNoWindow = $true
  $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
  $info.RedirectStandardInput = $true
  $info.Environment['GIT_CONFIG_NOSYSTEM'] = '1'; $info.Environment['GIT_CONFIG_GLOBAL'] = '/dev/null'
  $info.Environment['GIT_OPTIONAL_LOCKS'] = '0'
  foreach ($name in @('GIT_DIR','GIT_WORK_TREE','GIT_INDEX_FILE','GIT_COMMON_DIR','GIT_CONFIG','GIT_CONFIG_COUNT')) { $info.Environment.Remove($name) | Out-Null }
  $configuration = @('-c','core.excludesFile=/dev/null','-c','core.quotePath=false')
  if ($trustedGitRoot) { $configuration += @('-c',"safe.directory=$($trustedGitRoot.Replace('\','/'))") }
  foreach ($argument in $configuration + $Arguments) { $info.ArgumentList.Add($argument) }
  $process = [Diagnostics.Process]::new(); $process.StartInfo = $info
  try {
    $null = $process.Start(); $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
    if ($InputText) { $process.StandardInput.Write($InputText) }; $process.StandardInput.Close()
    if (-not $process.WaitForExit(30000)) { $process.Kill($true); $process.WaitForExit(); throw 'GIT: Artifact inspection timed out; no automatic retry.' }
    $output = $stdout.GetAwaiter().GetResult(); $null = $stderr.GetAwaiter().GetResult()
    if ($process.ExitCode -notin $Allowed) { throw "GIT: Artifact inspection failed (exit $($process.ExitCode)); inspect repository access and policy." }
    return @{ code = $process.ExitCode; output = $output }
  } finally { $process.Dispose() }
}
$repository = Invoke-ArtifactGit @('rev-parse','--show-toplevel') @(0,128)
$result = [ordered]@{schemaVersion=1;action=$Action.ToLowerInvariant();profile=$Profile;git=($repository.code -eq 0);status='not-git';rulesAdded=@();violations=@();decisionRequired=$false}
if ($repository.code -ne 0) {
  # Distinguish a genuinely unadopted folder from a broken/inaccessible Git boundary.
  $cursor = $root
  while ($cursor) {
    if (Test-Path -LiteralPath (Join-Path $cursor '.git')) { throw 'GIT: Existing Git metadata could not be inspected; no artifact protection was written.' }
    $next = Split-Path -Parent $cursor; if ($next -eq $cursor) { break }; $cursor = $next
  }
  $result | ConvertTo-Json -Depth 10; return
}
$gitRoot = [IO.Path]::GetFullPath($repository.output.Trim()).TrimEnd('/','\')
Assert-ArtifactPlain $gitRoot
$projectPrefix = [IO.Path]::GetRelativePath($gitRoot,$root).Replace('\','/')
if ($projectPrefix -eq '.') { $projectPrefix = '' } else { $projectPrefix += '/' }
if ($projectPrefix.StartsWith('../')) { throw 'GIT: ProjectRoot is outside the resolved working tree.' }
$violations = [Collections.Generic.List[object]]::new()
$indexed = Invoke-ArtifactGit @('ls-files','--cached','-z','--full-name')
foreach ($path in ($indexed.output -split "`0" | Where-Object { $_ })) {
  if ($projectPrefix -and -not $path.StartsWith($projectPrefix,[StringComparison]::Ordinal)) { continue }
  $relative = $path.Substring($projectPrefix.Length)
  if (Test-LocalArtifact $relative) { $violations.Add(@{path=$relative;reason='indexed-local-artifact'}) }
}

# Read only ignore files capable of affecting the bounded outputs. Never recurse
# source/dependency trees just to discover unrelated policies; do not follow links.
$policyFiles = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
function Add-ArtifactPolicy([string]$Directory) {
  Assert-ArtifactPlain $Directory
  $file = Join-Path $Directory '.gitignore'; Assert-ArtifactPlain $file
  if (Test-Path -LiteralPath $file -PathType Leaf) { $null = $policyFiles.Add($file) }
}
foreach ($probe in $probes) {
  $cursor = Split-Path -Parent (Join-Path $root $probe)
  while ($cursor -and ($cursor -eq $gitRoot -or $cursor.StartsWith($gitRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase))) {
    Add-ArtifactPolicy $cursor
    if ($cursor -eq $gitRoot) { break }; $cursor = Split-Path -Parent $cursor
  }
}
$actual = [Collections.Generic.List[string]]::new()
function Visit-ArtifactTree([string]$Directory) {
  Assert-ArtifactPlain $Directory
  if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { return }
  Add-ArtifactPolicy $Directory
  foreach ($item in Get-ChildItem -LiteralPath $Directory -Force) {
    Assert-ArtifactPlain $item.FullName
    if ($item.PSIsContainer) { Visit-ArtifactTree $item.FullName }
    else {
      $relative = [IO.Path]::GetRelativePath($root,$item.FullName).Replace('\','/')
      if (Test-LocalArtifact $relative) { $actual.Add($relative) }
    }
  }
}
foreach ($scan in $scanRoots) { Visit-ArtifactTree (Join-Path $root $scan) }
if ($Profile -eq 'OpenSpec' -and (Test-Path -LiteralPath (Join-Path $root 'openspec/.team-archive.lock'))) { $actual.Add('openspec/.team-archive.lock') }

# Ask Git about effective includes as well as declared child policy. The no-index
# option is essential: cached entries cannot disappear from this audit merely by
# being tracked. Global excludes are disabled in the subprocess contract above.
$probeInput = ((@($probes) + @($actual)) -join "`0") + "`0"
$ignored = Invoke-ArtifactGit @('check-ignore','--no-index','--verbose','-z','--stdin') @(0,1) $probeInput
$ignoreFields = @($ignored.output -split "`0")
for ($offset = 0; $offset + 3 -lt $ignoreFields.Count; $offset += 4) {
  if ($ignoreFields[$offset + 2].StartsWith('!')) {
    $violations.Add(@{path=$ignoreFields[$offset + 3];reason='explicit-include-policy';pattern=$ignoreFields[$offset + 2]})
  }
}

# Explicit scoped includes are intent, even when a parent ignore makes them inactive.
# Exact unrelated includes remain intact. Wildcard scopes that could include local
# artifacts fail conservatively for a user policy decision instead of being overridden.
foreach ($file in $policyFiles) {
  $base = [IO.Path]::GetRelativePath($root,(Split-Path -Parent $file)).Replace('\','/')
  if ($base -eq '.') { $base = '' }
  foreach ($line in [IO.File]::ReadAllLines($file)) {
    if (-not $line.StartsWith('!')) { continue }
    $pattern = $line.Substring(1).TrimEnd(); if (-not $pattern) { continue }
    $scoped = $pattern.Contains('/') -or $base -ne ''
    $pattern = $pattern.TrimStart('/').TrimEnd('/')
    # Normalize ancestor policy paths back into the task project namespace.
    $candidate = [IO.Path]::GetRelativePath($root,[IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $file) $pattern))).Replace('\','/')
    $conflict = $false
    if ($scoped) {
      $wildcard = $candidate.IndexOfAny([char[]]'*?[')
      if ($wildcard -lt 0) {
        $conflict = Test-LocalArtifact $candidate
        foreach ($directory in $localDirectories) { if ($directory.StartsWith("$candidate/",[StringComparison]::Ordinal)) { $conflict = $true } }
      } else {
        $literal = $candidate.Substring(0,$wildcard)
        foreach ($probe in $probes) {
          if ($probe.StartsWith($literal,[StringComparison]::Ordinal) -or $literal.StartsWith((Split-Path -Parent $probe).Replace('\','/') + '/', [StringComparison]::Ordinal)) { $conflict = $true }
        }
        foreach ($directory in $localDirectories) {
          if ($literal.StartsWith("$directory/",[StringComparison]::Ordinal) -or $directory.StartsWith($literal,[StringComparison]::Ordinal)) { $conflict = $true }
        }
      }
    } else {
      # Basename includes such as !important.log may be unrelated root policy.
      # Apply them to named controls/temps and real existing output names only.
      $matcher = [Management.Automation.WildcardPattern]::new($pattern,[Management.Automation.WildcardOptions]::None)
      foreach ($probe in @($probes | Where-Object { -not ($_ -match '/(?:archive|\.team-recovery)/') }) + @($actual)) {
        if ($matcher.IsMatch(($probe -split '/')[-1])) { $conflict = $true }
      }
    }
    if ($conflict) { $violations.Add(@{path=[IO.Path]::GetRelativePath($gitRoot,$file).Replace('\','/');reason='explicit-include-policy';pattern=$line}) }
  }
}
$result.violations = @($violations); $result.decisionRequired = $violations.Count -gt 0
if ($Action -eq 'Check') {
  $result.status = if ($violations.Count) { 'violations' } else { 'clean' }
  $result | ConvertTo-Json -Depth 10; return
}
if ($violations.Count) { throw ('ARTIFACTS: Existing index/include policy requires a user decision before local output generation: ' + (($violations | ForEach-Object { "$($_.path) [$($_.reason)]" }) -join ', ')) }

# Reuse only project ignore policy, never a global exclude file. Missing rules are
# appended to this project's file; ancestors outside ProjectRoot are never edited.
$bytes = [byte[]]::new(0)
if (Test-Path -LiteralPath $ignorePath) { $bytes = [IO.File]::ReadAllBytes($ignorePath) }
try { $text = [Text.UTF8Encoding]::new($false,$true).GetString($bytes).TrimStart([char]0xfeff) } catch { throw 'ARTIFACTS: .gitignore is not UTF-8; inspect its encoding before protection.' }
$lines = @($text -split '\r?\n')
$missing = @($rules | Where-Object { $_ -cnotin $lines -and $_.TrimStart('/') -cnotin $lines })
if ($Profile -eq 'Work' -and $missing.Count) {
  # Honor effective literal project policy for this task or its _work parent.
  # Broader staging policy does not expand task ownership or the audits above.
  $taskDirectory = [IO.Path]::GetFullPath((Join-Path $root $WorkPath))
  $workDirectory = [IO.Path]::GetFullPath((Join-Path $root '_work'))
  for ($offset = 0; $offset + 3 -lt $ignoreFields.Count; $offset += 4) {
    # One ignored descendant does not prove coverage of the whole owned task.
    if ($ignoreFields[$offset + 3] -cne @($probes)[0]) { continue }
    $matchedPattern = $ignoreFields[$offset + 2]
    if ($matchedPattern.StartsWith('!') -or -not $matchedPattern.EndsWith('/') -or
        $matchedPattern -match '[*?\[\\]') { continue }
    $source = $ignoreFields[$offset]
    $sourcePath = if ([IO.Path]::IsPathRooted($source)) { $source } else { Join-Path $gitRoot $source }
    $sourcePath = [IO.Path]::GetFullPath($sourcePath)
    if (-not $policyFiles.Contains($sourcePath)) { continue }
    $literal = $matchedPattern.Trim('/')
    if (-not $matchedPattern.StartsWith('/') -and -not $literal.Contains('/')) {
      # A bare directory basename can match below its ignore file, including
      # a nested ProjectRoot; anchored and multi-segment rules cannot.
      $covered = if ($literal -ceq (Split-Path -Leaf $taskDirectory)) {
        $taskDirectory
      } elseif ($literal -ceq '_work') {
        $workDirectory
      } else { continue }
    } else {
      $covered = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $sourcePath) $literal))
    }
    $sourceDirectory = Split-Path -Parent $sourcePath
    if (-not $covered.StartsWith(
        $sourceDirectory + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)) { continue }
    if ($covered -eq $taskDirectory -or $covered -eq $workDirectory) {
      $missing = @()
      break
    }
  }
}
if ($Profile -eq 'Work' -and $actual.Count -gt 0 -and $missing.Count) { throw 'ARTIFACTS: Nonempty WorkPath ownership is uncertain without an accepted existing ignore rule; user decision required.' }
if ($missing.Count) {
  $eol = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
  $separator = if ($bytes.Length -gt 0 -and -not $text.EndsWith("`n")) { $eol } else { '' }
  $suffix = [Text.Encoding]::UTF8.GetBytes($separator + '# Codex Team Kit: exact local artifacts (' + $Profile + ')' + $eol + ($missing -join $eol) + $eol)
  Assert-ArtifactPlain $ignorePath
  $stream = [IO.File]::Open($ignorePath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
  try {
    if ($stream.Length -ne $bytes.Length) { throw 'ARTIFACTS: Ignore policy changed concurrently; inspect before retrying.' }
    $current = [byte[]]::new($bytes.Length); $read = $stream.Read($current,0,$current.Length)
    if ($read -ne $bytes.Length -or [Convert]::ToBase64String($current) -cne [Convert]::ToBase64String($bytes)) { throw 'ARTIFACTS: Ignore policy changed concurrently; inspect before retrying.' }
    try { $stream.Position = $stream.Length; $stream.Write($suffix,0,$suffix.Length); $stream.Flush($true) }
    catch { $stream.SetLength($bytes.Length); throw }
  } finally { $stream.Dispose() }
  $result.rulesAdded = $missing
}
$result.status = 'protected'
$result | ConvertTo-Json -Depth 10
