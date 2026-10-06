#requires -Version 7.0
<#
Read-only instruction-candidate discovery for a bounded project-root-to-CWD chain.
Reports byte provenance and expected dependencies, not policy meaning, permission,
actual Codex loading, or a complete repository inventory. Never executes file content.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ProjectRoot,
  [string]$WorkingDirectory = '.',
  [string[]]$FallbackNames = @(),
  [ValidateRange(1,[long]::MaxValue)][long]$MaxBytes = 32768
)
$ErrorActionPreference = 'Stop'

# Preserve volume roots while normalizing ordinary directory paths. Root may be
# absolute; all inspected paths below it must be strictly repository-relative.
try { $root = [IO.Path]::GetFullPath($ProjectRoot) }
catch { throw 'PATH: ProjectRoot must be a valid existing directory.' }
if ($root -ne [IO.Path]::GetPathRoot($root)) { $root = $root.TrimEnd('/','\') }
if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'PATH: ProjectRoot must be an existing directory.' }
$comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }

# Check every existing ancestor and candidate: a relative path must not traverse a
# junction/symlink. These local checks are not a sandbox against hostile concurrent edits.
function Assert-Plain([string]$Path) {
  $cursor = $Path
  while ($cursor) {
    # Get-Item also observes dangling links; Test-Path alone may report their
    # missing targets as absent and lose the linked-path security boundary.
    try { $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop }
    catch [System.Management.Automation.ItemNotFoundException] { $item = $null }
    catch { throw 'PATH: Cannot safely inspect candidate ancestors.' }
    if ($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'PATH: Linked/reparse paths are unsupported.' }
    $next = Split-Path -Parent $cursor
    if ($next -eq $cursor) { break }
    $cursor = $next
  }
}

# Use the documentation runtime's credential/dependency/generated exclusions; an
# explicit fallback name does not grant permission to inspect an excluded location.
function Test-Excluded([string]$Relative) {
  foreach ($part in ($Relative -split '/')) {
    if ($part -match '^(\.git|\.codex|\.agents|\.aws|\.ssh|\.azure|\.gnupg|node_modules|vendor|dist|build|coverage|\.next|\.cache|__pycache__|\.venv|venv)$') { return $true }
    if ($part -match '^\.env($|\.)|^(\.npmrc|\.pypirc|\.netrc|id_rsa|id_ed25519|credentials|credentials\.(json|toml|ini|yaml|yml)|secrets\.(json|toml|ini|yaml|yml)|tokens\.json)$|\.(pem|key|pfx|p12|keystore)$') { return $true }
    if ($part -match '^(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|poetry\.lock|uv\.lock)$') { return $true }
  }
  return $false
}

# Reject traversal, aliases, ADS and Windows reserved names even on other hosts;
# valid input produces one stable forward-slash repository-relative identity.
function Normalize-Relative([string]$Relative) {
  if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative)) { throw 'PATH: Require a repository-relative path.' }
  $normalized = $Relative.Replace('\','/')
  foreach ($part in ($normalized -split '/')) {
    if ($part -in @('','.','..') -or $part -match '[<>:"|?*\x00-\x1f]' -or $part -match '[ .]$' -or $part -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)') { throw 'PATH: Unsafe path segment.' }
  }
  if (Test-Excluded $normalized) { throw 'PATH: Sensitive, dependency and generated locations are excluded.' }
  return $normalized
}

# Resolve only already-normalized candidate paths; linked absent-file ancestors
# are checked too, so expected absent dependencies cannot escape through a link.
function Resolve-Candidate([string]$Relative) {
  $absolute = [IO.Path]::GetFullPath((Join-Path $root $Relative))
  $prefix = $root.TrimEnd('/','\') + [IO.Path]::DirectorySeparatorChar
  if (-not $absolute.StartsWith($prefix,$comparison)) { throw 'PATH: Candidate leaves ProjectRoot.' }
  Assert-Plain $absolute
  return $absolute
}

Assert-Plain $root
if (Test-Excluded (Split-Path -Leaf $root)) { throw 'PATH: Excluded ProjectRoot is unsupported.' }
$working = if ($WorkingDirectory -ceq '.') { '.' } else { Normalize-Relative $WorkingDirectory }
if ($working -ne '.') {
  $workingAbsolute = Resolve-Candidate $working
  if (-not (Test-Path -LiteralPath $workingAbsolute -PathType Container)) { throw 'PATH: WorkingDirectory must be an existing directory.' }
}
$names = [Collections.Generic.List[string]]::new()
$names.Add('AGENTS.override.md'); $names.Add('AGENTS.md')
$seenNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$null = $seenNames.Add('AGENTS.override.md'); $null = $seenNames.Add('AGENTS.md')
foreach ($name in $FallbackNames) {
  $normalized = Normalize-Relative $name
  if ($normalized.Contains('/')) { throw 'INPUT: Each fallback must be a single filename.' }
  if (-not $seenNames.Add($normalized)) { throw 'INPUT: Duplicate fallback or standard instruction filename.' }
  $names.Add($normalized)
}
$directories = [Collections.Generic.List[string]]::new()
$directories.Add('.')
if ($working -ne '.') {
  $relative = ''
  foreach ($part in ($working -split '/')) {
    $relative = if ($relative) { "$relative/$part" } else { $part }
    $directories.Add($relative)
  }
}

# Validate the entire bounded path set before reading any instruction bytes.
$pending = [Collections.Generic.List[object]]::new()
foreach ($directory in $directories) {
  foreach ($name in $names) {
    $path = if ($directory -eq '.') { $name } else { "$directory/$name" }
    $absolute = Resolve-Candidate $path
    if (Test-Path -LiteralPath $absolute -PathType Container) { throw 'PATH: Instruction candidate must be a file, not a directory.' }
    $pending.Add(@{ path=$path; directory=$directory; name=$name; absolute=$absolute })
  }
}
$candidates = [Collections.Generic.List[object]]::new()
$selected = [Collections.Generic.List[string]]::new()
$dependencies = [Collections.Generic.List[string]]::new()
$selectedDirectories = @{}
[long]$total = 0
$utf8 = [Text.UTF8Encoding]::new($false,$true)
foreach ($candidate in $pending) {
  Assert-Plain $candidate.absolute
  if (Test-Path -LiteralPath $candidate.absolute -PathType Container) { throw 'PATH: Instruction candidate must remain a file.' }
  $exists = Test-Path -LiteralPath $candidate.absolute -PathType Leaf
  $nonempty = $false; [long]$size = 0; $hash = $null; $status = 'absent'
  if ($exists) {
    # One snapshot supplies all provenance fields. Strict decoding prevents silent
    # replacement bytes; a UTF8 BOM alone is not a meaningful instruction document.
    try {
      $bytes = [IO.File]::ReadAllBytes($candidate.absolute)
      $text = $utf8.GetString($bytes)
    } catch { throw 'READ: Cannot read/decode instruction candidate as UTF8.' }
    Assert-Plain $candidate.absolute
    $size = $bytes.LongLength
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
    $nonempty = -not [string]::IsNullOrWhiteSpace($text.TrimStart([char]0xFEFF))
    if (-not $nonempty) { $status = 'empty' }
    elseif ($selectedDirectories.ContainsKey($candidate.directory)) { $status = 'shadowed' }
    else {
      $status = 'selected'; $selectedDirectories[$candidate.directory] = $true
      $selected.Add($candidate.path); $total += $size
    }
  }
  $dependencies.Add($candidate.path)
  $candidates.Add([ordered]@{ path=$candidate.path; directory=$candidate.directory; name=$candidate.name; exists=[bool]$exists; nonempty=[bool]$nonempty; sizeBytes=$size; sha256=$hash; status=$status })
}
$warnings = [Collections.Generic.List[string]]::new()
if ($total -gt $MaxBytes) { $warnings.Add('Selected source bytes exceed MaxBytes; actual runtime loading/truncation is unknown. Reduce instructions or inspect the actual configured limit and loading evidence.') }
# Source-byte sum is a diagnostic, not Codex's exact assembled prompt accounting.
# No global settings are read: fallback names and limit are caller-supplied evidence.
[ordered]@{
  schemaVersion=1; kitVersion='1.0.3'; workingDirectory=$working
  fallbackNames=@($FallbackNames); maxBytes=$MaxBytes; directories=@($directories)
  candidates=@($candidates); selectedPaths=@($selected); dependencyPaths=@($dependencies)
  totalSelectedBytes=$total; exceedsMaxBytes=($total -gt $MaxBytes)
  warnings=@($warnings); runtimeLoaded='unknown'
} | ConvertTo-Json -Depth 10
