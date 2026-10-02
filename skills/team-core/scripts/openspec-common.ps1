# Shared local path and snapshot operations for the optional OpenSpec adapter.
# No CLI calls or writes occur merely by loading this file. PowerShell 7 is required.
#requires -Version 7.0

# Resolve a repository-relative path and reject traversal, alternate streams and linked ancestors.
# Missing leaves are allowed for creation; an existing ancestor must remain a real local directory.
function Resolve-SpecPath([string]$Root, [string]$Relative) {
  $base = [IO.Path]::GetFullPath($Root)
  if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)|:') { throw 'PATH: Expected a contained repository-relative path.' }
  $full = [IO.Path]::GetFullPath((Join-Path $base $Relative))
  if (-not $full.StartsWith($base.TrimEnd('/','\') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'PATH: Path escapes project.' }
  $cursor = $full
  while ($cursor) {
    if (Test-Path -LiteralPath $cursor) {
      if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'PATH: Linked paths are not supported.' }
    }
    $cursor = Split-Path -Parent $cursor
  }
  return $full
}

# Enumerate without following symlinks; validate each directory before descending into it.
function Get-SpecFiles([string]$Root, [string]$Relative) {
  $path = Resolve-SpecPath $Root $Relative
  if (-not (Test-Path -LiteralPath $path)) { return }
  foreach ($item in Get-ChildItem -LiteralPath $path -Force) {
    $rel = [IO.Path]::GetRelativePath($Root, $item.FullName).Replace('\','/')
    $null = Resolve-SpecPath $Root $rel
    if ($item.PSIsContainer) { Get-SpecFiles $Root $rel } else { $item }
  }
}

# Fingerprint baseline and authored specification inputs. Any baseline change invalidates the review
# conservatively, including concurrent changes to another capability. Task checkboxes are excluded.
function Get-SpecSnapshot([string]$Root, [string]$ChangeId) {
  $paths = @('openspec/config.yaml', 'openspec/team-integration.json', "openspec/changes/$ChangeId/proposal.md", "openspec/changes/$ChangeId/design.md", "openspec/changes/$ChangeId/.openspec.yaml")
  $files = @(Get-SpecFiles $Root 'openspec/specs') + @(Get-SpecFiles $Root "openspec/changes/$ChangeId/specs")
  foreach ($file in $files) { $paths += [IO.Path]::GetRelativePath($Root, $file.FullName).Replace('\','/') }
  $snapshot = [ordered]@{}
  foreach ($relative in ($paths | Sort-Object -Unique)) {
    $path = Resolve-SpecPath $Root $relative
    $snapshot[$relative] = if (Test-Path -LiteralPath $path -PathType Leaf) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() } else { 'absent' }
  }
  # Task wording is part of the contract; checking a box is progress, not a new specification.
  $tasks = "openspec/changes/$ChangeId/tasks.md"
  $taskPath = Resolve-SpecPath $Root $tasks
  $snapshot[$tasks] = 'absent'
  if (Test-Path -LiteralPath $taskPath -PathType Leaf) {
    $content = (Get-Content -LiteralPath $taskPath -Raw) -replace '(?m)^(\s*- )\[[ xX]\]', '$1[ ]'
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $snapshot[$tasks] = [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($content))).Replace('-','').ToLowerInvariant() } finally { $hash.Dispose() }
  }
  return $snapshot
}

# Read the explicit opt-in marker. A plain openspec directory is not permission to adopt a project.
function Get-SpecIntegration([string]$Root) {
  $path = Resolve-SpecPath $Root 'openspec/team-integration.json'
  if (-not (Test-Path -LiteralPath $path)) { throw 'DISABLED: Explicit Enable is required.' }
  try { $config = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable } catch { throw 'CONFIG: Invalid integration JSON.' }
  if ($config.schemaVersion -ne 1 -or $config.enabled -ne $true -or $config.openSpecVersion -ne '1.13.2') { throw 'CONFIG: Unsupported integration configuration.' }
  return $config
}
