# Explicit opt-in for the selected Codex home. The full installer calls this
# trusted script only when requested, after validating the installed payload.
#requires -Version 7.0
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
  [string]$CodexHome = (Join-Path $HOME '.codex'),
  [string]$AgentsHome = (Join-Path $HOME '.agents')
)

$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$begin = '<!-- codex-multi-agent:team-guidance:begin -->'
$end = '<!-- codex-multi-agent:team-guidance:end -->'
$block = @(
  $begin
  '## Codex Multi-Agent Kit task routing'
  ''
  'For repository-backed engineering design, planning, implementation, bug fixes, testing, review, or delivery, first read the available `$team` skill and follow its routing and selected workflow. Briefly state the selected path before starting. Use its light path and executor self-check for eligible small tasks. Answer ordinary questions directly and honor a workflow the user explicitly selects. If the Team workflow applies and the skill is unavailable, report that limitation.'
  $end
) -join "`n"

function Get-PlainGuidanceItem([string]$Path, [bool]$Directory) {
  try { $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop }
  catch [System.Management.Automation.ItemNotFoundException] { return }
  if ($item.PSIsContainer -ne $Directory -or
      ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.LinkType) {
    throw 'TEAM_GUIDANCE_PATH: The selected Codex home or guidance file is not a plain path.'
  }
  return $item
}

function New-GuidanceBackup([string]$OriginalPath, [string]$Directory) {
  if ($IsWindows) {
    # Preserve the original file's effective access rules at creation time.
    $path = Join-Path $Directory ('AGENTS.md.team-guidance-' + [guid]::NewGuid().ToString('N') + '.bak')
    $security = [IO.FileSystemAclExtensions]::GetAccessControl([IO.FileInfo]::new($OriginalPath))
    $security.SetAccessRuleProtection($true, $true)
    $handle = [IO.FileSystemAclExtensions]::Create([IO.FileInfo]::new($path),
      [IO.FileMode]::CreateNew, [Security.AccessControl.FileSystemRights]::Write,
      [IO.FileShare]::None, 4096, [IO.FileOptions]::None, $security)
    return @{path=$path; handle=$handle}
  }
  # mktemp requests owner-only access at creation, including under default ACLs.
  $path = & /usr/bin/mktemp (Join-Path $Directory 'AGENTS.md.team-guidance-XXXXXXXXXXXX')
  if ($LASTEXITCODE -ne 0 -or -not $path) { throw 'TEAM_GUIDANCE_BACKUP: Could not create a private backup.' }
  $null = Get-PlainGuidanceItem $path $false
  $handle = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::None)
  return @{path=$path; handle=$handle}
}

$homePath = [IO.Path]::GetFullPath($CodexHome)
$target = Join-Path $homePath 'AGENTS.md'
$override = Join-Path $homePath 'AGENTS.override.md'
# Check ancestors too so a custom home cannot redirect this write invisibly.
for ($directory = $homePath; $directory; $directory = [IO.Path]::GetDirectoryName($directory)) {
  $null = Get-PlainGuidanceItem $directory $true
}
$overrideItem = Get-PlainGuidanceItem $override $false
if ($overrideItem -and $overrideItem.Length -gt 0) {
  throw 'TEAM_GUIDANCE_OVERRIDE: A nonempty AGENTS.override.md takes priority; review it separately.'
}
$targetItem = Get-PlainGuidanceItem $target $false
$original = [byte[]]@()
if ($targetItem) { $original = [IO.File]::ReadAllBytes($target) }
try { $document = $utf8.GetString($original).TrimStart([char]0xFEFF) }
catch { throw 'TEAM_GUIDANCE_ENCODING: AGENTS.md must use UTF-8 to append guidance.' }
if ($document.Contains([char]0)) { throw 'TEAM_GUIDANCE_ENCODING: AGENTS.md must use UTF-8 to append guidance.' }
$normalized = $document.Replace("`r`n", "`n")
$markedBlock = '(?m)^' + [regex]::Escape($block) + '$'
$markers = [regex]::Matches($normalized, [regex]::Escape('<!-- codex-multi-agent:team-guidance:'))
if ($markers.Count -eq 2 -and [regex]::IsMatch($normalized, $markedBlock)) {
  return @{action='already-enabled'; path=$target; backup=$null}
}
if ($markers.Count -gt 0) { throw 'TEAM_GUIDANCE_CONFLICT: Existing Team guidance was changed; review it before editing.' }

$operation = if ($targetItem) { 'append' } else { 'create' }
if (-not $PSCmdlet.ShouldProcess($target, 'Enable Team task routing guidance')) {
  return @{action=$operation; path=$target; backup=$null}
}
if (-not [IO.File]::Exists((Join-Path $AgentsHome 'skills/team/SKILL.md'))) {
  throw 'TEAM_GUIDANCE_SKILL: Team must be installed in the selected Agents home first.'
}

$newline = if ($document.Contains("`r`n")) { "`r`n" } elseif ($document.Contains("`n")) { "`n" } else { [Environment]::NewLine }
$separator = if (-not $document.Length -or $document.EndsWith($newline + $newline)) { '' }
  elseif ($document.EndsWith($newline)) { $newline } else { $newline + $newline }
$suffix = $utf8.GetBytes($separator + $block.Replace("`n", $newline) + $newline)
$backup = $null
$null = [IO.Directory]::CreateDirectory($homePath)
$mode = if ($targetItem) { [IO.FileMode]::Open } else { [IO.FileMode]::CreateNew }
$stream = [IO.File]::Open($target, $mode, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)
try {
  # Recheck the bytes while holding a write handle. Retain the original prefix
  # in place and append only after a durable, exact backup of existing content.
  if ($targetItem) {
    $current = [IO.MemoryStream]::new()
    try {
      $stream.CopyTo($current)
      if (-not [Collections.StructuralComparisons]::StructuralEqualityComparer.Equals($original, $current.ToArray())) {
        throw 'TEAM_GUIDANCE_CHANGED: AGENTS.md changed during enablement; preview it again.'
      }
    } finally { $current.Dispose() }
    $snapshot = New-GuidanceBackup $target $homePath
    $backup = $snapshot.path
    try {
      $snapshot.handle.Write($original, 0, $original.Length)
      $snapshot.handle.Flush($true)
    } finally { $snapshot.handle.Dispose() }
  }
  try {
    $stream.Write($suffix, 0, $suffix.Length)
    $stream.Flush($true)
  } catch {
    $stream.SetLength($original.Length)
    $stream.Flush($true)
    throw
  }
} finally { $stream.Dispose() }

$action = if ($targetItem) { 'appended' } else { 'created' }
return @{action=$action; path=$target; backup=$backup}
