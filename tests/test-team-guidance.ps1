# Exercise the explicit consent path only in disposable Codex and Agents homes.
#requires -Version 7.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/platform.ps1')
$installer = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/enable-team-guidance.ps1'
$parent = Get-TestTemporaryParent
$root = Join-Path $parent ('cma-team-guidance-' + [guid]::NewGuid().ToString('N'))
$codex = Join-Path $root 'codex'
$agents = Join-Path $root 'agents'
$target = Join-Path $codex 'AGENTS.md'
$override = Join-Path $codex 'AGENTS.override.md'
$skill = Join-Path $agents 'skills/team/SKILL.md'
$inherited = [Text.UTF8Encoding]::new($true)

function Assert-Guidance([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Test-SameGuidanceBytes([byte[]]$Expected, [byte[]]$Actual) {
  return [Collections.StructuralComparisons]::StructuralEqualityComparer.Equals($Expected, $Actual)
}

try {
  $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $skill))
  $null = [IO.Directory]::CreateDirectory($codex)
  [IO.File]::WriteAllText($skill, '# Fixture Team skill')
  [IO.File]::WriteAllText($target, "# Personal guidance`r`n`r`nKeep 测试 content.", $inherited)
  $original = [IO.File]::ReadAllBytes($target)

  # Preview names the target and leaves the original file and backup set untouched.
  $plan = & $installer -CodexHome $codex -AgentsHome $agents -WhatIf
  Assert-Guidance ($plan.action -ceq 'append' -and $plan.path -ceq $target) 'Wrong preview.'
  Assert-Guidance (Test-SameGuidanceBytes $original ([IO.File]::ReadAllBytes($target))) 'Preview changed the original.'
  Assert-Guidance (@(Get-ChildItem -LiteralPath $codex -File).Count -eq 1) 'Preview created a backup.'

  # Explicit enablement preserves the exact BOM/line endings and writes one managed block.
  $result = & $installer -CodexHome $codex -AgentsHome $agents
  $enabled = [IO.File]::ReadAllBytes($target)
  Assert-Guidance ($result.action -ceq 'appended') 'Opt-in did not append.'
  Assert-Guidance (Test-SameGuidanceBytes $original ([byte[]]$enabled[0..($original.Length - 1)])) 'Opt-in changed original bytes.'
  Assert-Guidance (Test-SameGuidanceBytes $original ([IO.File]::ReadAllBytes($result.backup))) 'Backup differs from original.'
  if ($IsWindows) {
    $originalAcl = Get-Acl -LiteralPath $target
    $backupAcl = Get-Acl -LiteralPath $result.backup
    $key = { "$($_.IdentityReference)|$($_.AccessControlType)|$($_.FileSystemRights)" }
    $expectedAccess = @($originalAcl.Access | ForEach-Object $key | Sort-Object)
    $actualAccess = @($backupAcl.Access | ForEach-Object $key | Sort-Object)
    Assert-Guidance ((Compare-Object $expectedAccess $actualAccess).Count -eq 0 -and $backupAcl.AreAccessRulesProtected) 'Backup access differs from the original file.'
  }
  $rule = [IO.File]::ReadAllText($target)
  Assert-Guidance ($rule.Contains('$team') -and $rule.Contains('light path')) 'Routing rule is missing.'

  # Repeated enablement is a no-op even when the user has added content below the block.
  [IO.File]::AppendAllText($target, "Keep later edits.`r`n", [Text.UTF8Encoding]::new($false))
  $afterUserEdit = [IO.File]::ReadAllBytes($target)
  $repeat = & $installer -CodexHome $codex -AgentsHome $agents
  Assert-Guidance ($repeat.action -ceq 'already-enabled' -and @(Get-ChildItem -LiteralPath $codex -File).Count -eq 2) 'Repeat created another block or backup.'
  Assert-Guidance (Test-SameGuidanceBytes $afterUserEdit ([IO.File]::ReadAllBytes($target))) 'Repeat overwrote a user edit.'

  # An active override and a changed managed block each require an explicit decision.
  [IO.File]::WriteAllText($override, 'Existing override')
  $blocked = $false
  try { & $installer -CodexHome $codex -AgentsHome $agents | Out-Null } catch { $blocked = $_.Exception.Message -match 'TEAM_GUIDANCE_OVERRIDE' }
  Assert-Guidance $blocked 'Active override did not block the opt-in.'
  Assert-Guidance ([IO.File]::ReadAllText($override) -ceq 'Existing override') 'Override was changed.'
  [IO.File]::WriteAllBytes($override, $inherited.GetPreamble())
  $blocked = $false
  try { & $installer -CodexHome $codex -AgentsHome $agents | Out-Null } catch { $blocked = $_.Exception.Message -match 'TEAM_GUIDANCE_OVERRIDE' }
  Assert-Guidance $blocked 'BOM-only override did not block the opt-in.'
  Remove-Item -LiteralPath $override
  [IO.File]::WriteAllText($target, $rule.Replace('light path', 'custom path'), $inherited)
  $edited = [IO.File]::ReadAllBytes($target)
  $blocked = $false
  try { & $installer -CodexHome $codex -AgentsHome $agents | Out-Null } catch { $blocked = $_.Exception.Message -match 'TEAM_GUIDANCE_CONFLICT' }
  Assert-Guidance ($blocked -and (Test-SameGuidanceBytes $edited ([IO.File]::ReadAllBytes($target)))) 'Modified managed block was overwritten.'

  # A clean but selected Codex home gets a new file only when Team is available.
  Remove-Item -LiteralPath $target
  Remove-Item -LiteralPath $skill
  $blocked = $false
  try { & $installer -CodexHome $codex -AgentsHome $agents | Out-Null } catch { $blocked = $_.Exception.Message -match 'TEAM_GUIDANCE_SKILL' }
  Assert-Guidance ($blocked -and -not (Test-Path -LiteralPath $target)) 'Unavailable Team created global instructions.'
  [IO.File]::WriteAllText($skill, '# Fixture Team skill')
  $new = & $installer -CodexHome $codex -AgentsHome $agents
  Assert-Guidance ($new.action -ceq 'created' -and -not $new.backup -and [IO.File]::ReadAllText($target).Contains('$team')) 'Fresh enablement failed.'
  Write-Host 'Team guidance tests passed.'
} finally {
  # The GUID-owned directory is the only recursive cleanup target.
  $resolved = [IO.Path]::GetFullPath($root)
  if (([IO.Path]::GetDirectoryName($resolved) -cne $parent) -or ([IO.Path]::GetFileName($resolved) -cnotmatch '^cma-team-guidance-[a-f0-9]{32}$')) {
    throw 'Unexpected Team guidance fixture path.'
  }
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
