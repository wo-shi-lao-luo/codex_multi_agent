# Exercise the optional adapter in disposable projects; no global installation or real project changes.
# Pass a trusted, already-installed 1.13.2 bin/openspec.js to include upstream lifecycle tests.
#requires -Version 7.0
[CmdletBinding()]
param([string]$OpenSpecEntry)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$adapter = Join-Path $repo 'skills/team-core/scripts/openspec-adapter.ps1'
$trace = Join-Path $repo 'skills/team-core/scripts/spec-traceability.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $tempParent ('codex-openspec-test-' + [guid]::NewGuid().ToString('N'))
$double = Join-Path $PSScriptRoot 'fixtures/openspec-cli.cjs'
$priorMode = $env:KIT_OPENSPEC_TEST_MODE

function Assert-True([bool]$Value, [string]$Message) { if (-not $Value) { throw $Message } }

# Failure assertions require the expected category, not merely any incidental exception.
function Assert-Fails([scriptblock]$Run, [string]$Pattern) {
  try { & $Run | Out-Null } catch {
    if ($_.Exception.Message -notmatch $Pattern) { throw "Expected $Pattern, got: $_" }
    return
  }
  throw "Expected failure: $Pattern"
}

# Supply a real schema-v2 packet. Each case records scenario, expected behavior and observed evidence.
function Write-Packet([string]$Root) {
  & (Join-Path $repo 'skills/team-core/scripts/stage-verification.ps1') -Action Initialize -ProjectRoot $Root -StageSlug 'sample' | Out-Null
  $path = Join-Path $Root 'docs/verification/active/sample.md'
  $body = Get-Content $path -Raw
  $body = $body.Replace('Contract status: draft', 'Contract status: active')
  $body = $body.Replace('| | | | | |', '| CASE-001 | ready | request access | granted | happy |')
  $body = $body.Replace('required / conditional / not applicable | |', 'not applicable | Isolated CLI fixture. |')
  $body = $body.Replace('| | | unit | test-first / test-after / manual-or-environmental | | planned | planned | planned | required for non-test-first | | planned |', '| CASE-001 access | regression | unit | test-first | access test | assertion failed before implementation | access test passed | rerun passed | none | tester | passing |')
  Set-Content $path $body
}

# Minimal native OpenSpec artifacts with stable IDs in titles; no upstream implementation copied.
function Write-Change([string]$Root, [string]$Change = 'sample') {
  $dir = Join-Path $Root "openspec/changes/$Change"
  New-Item -ItemType Directory -Force "$dir/specs/access" | Out-Null
  Set-Content "$dir/proposal.md" "## Why`nAccess must be specified for safe delivery.`n## What Changes`n- Add access checks.`n## Capabilities`n### New Capabilities`n- access: Access checks.`n## Impact`nAccess module and tests."
  Set-Content "$dir/design.md" "## Context`nUse the existing access boundary.`n## Decisions`nPreserve unrelated behavior."
  Set-Content "$dir/tasks.md" '- [x] 1.1 Implement access and regression test'
  Set-Content "$dir/specs/access/spec.md" "## Purpose`nDefine access behavior for the sample capability.`n## ADDED Requirements`n### Requirement: ACCESS-REQ-001 Allow access`nThe system SHALL allow a valid request.`n#### Scenario: ACCESS-SC-001 Valid request`n- **WHEN** a valid request arrives`n- **THEN** access is granted"
}

# Fill only the link index; results stay exclusively in the referenced packet.
function Link-Change([string]$Root, [string]$Change = 'sample', [string]$Scenario = 'ACCESS-SC-001') {
  & $trace -Action Initialize -ProjectRoot $Root -ChangeId $Change | Out-Null
  $path = Join-Path $Root "openspec/changes/$Change/verification.json"
  $index = Get-Content $path -Raw | ConvertFrom-Json
  $index.links = @(@{ requirement = 'ACCESS-REQ-001'; scenario = $Scenario; task = '1.1'; packet = 'docs/verification/active/sample.md'; case = 'CASE-001'; regression = 'Fixture baseline and existing access checks inspected.' })
  $index.reviewEvidence = 'Fixture operator inspected assertions and source; no findings.'
  $index | ConvertTo-Json -Depth 15 | Set-Content $path
}

try {
  New-Item -ItemType Directory $testRoot | Out-Null
  # Scenario: disabled project. Expected: Doctor is read-only and does not require a CLI.
  $doctor = & $adapter -Action Doctor -ProjectRoot $testRoot | ConvertFrom-Json
  Assert-True (-not $doctor.enabled) 'Disabled project reported enabled.'
  Assert-True (-not (Test-Path "$testRoot/openspec")) 'Doctor adopted project silently.'
  # Scenario: explicit adoption with unavailable CLI. Expected: fail before any project write.
  Assert-Fails { & $adapter -Action Enable -ProjectRoot $testRoot -OpenSpecEntry "$testRoot/missing.js" } 'DEPENDENCY'
  Assert-True (-not (Test-Path "$testRoot/openspec")) 'Missing dependency left project files.'
  # Scenario: supported CLI double. Expected: explicit Enable creates only the adapter project config.
  & $adapter -Action Enable -ProjectRoot $testRoot -OpenSpecEntry $double | Out-Null
  Assert-True (Test-Path "$testRoot/openspec/team-integration.json") 'Missing opt-in marker.'
  Assert-Fails { & $adapter -Action Enable -ProjectRoot $testRoot -OpenSpecEntry $double } 'ALREADY_ENABLED'
  Write-Change $testRoot
  # Scenario: incompatible CLI, nonzero exit, invalid JSON, or hung process. Expected: distinct failures, no fallback.
  foreach ($row in @(@('version','VERSION'), @('exit','UPSTREAM'), @('json','JSON'), @('timeout','TIMEOUT'), @('schema','SCHEMA'))) {
    $env:KIT_OPENSPEC_TEST_MODE = $row[0]
    Assert-Fails { & $adapter -Action Inspect -ProjectRoot $testRoot -ChangeId sample -OpenSpecEntry $double -TimeoutSeconds 1 } $row[1]
  }
  $env:KIT_OPENSPEC_TEST_MODE = ''
  Write-Packet $testRoot
  Link-Change $testRoot
  # Scenario: a complete mapping before user acceptance. Expected: planning validation passes, close is blocked.
  & $trace -Action Validate -ProjectRoot $testRoot -ChangeId sample | Out-Null
  Assert-Fails { & $trace -Action CloseCheck -ProjectRoot $testRoot -ChangeId sample } 'MANUAL_PENDING'
  $packet = "$testRoot/docs/verification/active/sample.md"
  $pending = Get-Content $packet -Raw
  Set-Content $packet ($pending.Replace('Final manual status: manual pending', 'Final manual status: deferred by user').Replace('Final manual evidence:', 'Final manual evidence: Fixture user explicitly deferred.'))
  & $trace -Action CloseCheck -ProjectRoot $testRoot -ChangeId sample | Out-Null
  $indexPath = "$testRoot/openspec/changes/sample/verification.json"
  $indexText = Get-Content $indexPath -Raw
  # Scenario: valid read-only checks. Expected: index and packet bytes are unchanged.
  $beforeIndex = (Get-FileHash $indexPath).Hash
  $beforePacket = (Get-FileHash $packet).Hash
  & $trace -Action Validate -ProjectRoot $testRoot -ChangeId sample | Out-Null
  & $trace -Action CloseCheck -ProjectRoot $testRoot -ChangeId sample | Out-Null
  Assert-True ((Get-FileHash $indexPath).Hash -eq $beforeIndex -and (Get-FileHash $packet).Hash -eq $beforePacket) 'Read-only validation mutated evidence.'
  # Scenario: malformed links. Expected: unknown scenario/task/case and escaped packet path are rejected.
  foreach ($row in @(@('ACCESS-SC-001','ACCESS-SC-999','SCENARIO'), @('"1.1"','"9.9"','TASK'), @('CASE-001','CASE-999','CASE'), @('docs/verification/active/sample.md','../escape.md','PATH'))) {
    Set-Content $indexPath ($indexText.Replace($row[0], $row[1]))
    Assert-Fails { & $trace -Action Validate -ProjectRoot $testRoot -ChangeId sample } $row[2]
  }
  Set-Content $indexPath $indexText
  # Scenario: an unfinished checkbox. Expected: contract validation succeeds, closure fails on task state.
  $tasksPath = "$testRoot/openspec/changes/sample/tasks.md"
  $tasksText = Get-Content $tasksPath -Raw
  [IO.File]::WriteAllText($tasksPath, $tasksText.Replace('[x]', '[ ]'))
  & $trace -Action Validate -ProjectRoot $testRoot -ChangeId sample | Out-Null
  Assert-Fails { & $trace -Action CloseCheck -ProjectRoot $testRoot -ChangeId sample } 'TASK'
  [IO.File]::WriteAllText($tasksPath, $tasksText)
  # Scenario: stage contains pending work outside the mapped row. Expected: close cannot hide it.
  $acceptedPacket = Get-Content $packet -Raw
  [IO.File]::WriteAllText($packet, $acceptedPacket.Replace('| CASE-001 access', '| CASE-002 other | risk | unit | test-first | other test | planned | planned | planned | none | tester | planned |' + "`n| CASE-001 access"))
  Assert-Fails { & $trace -Action CloseCheck -ProjectRoot $testRoot -ChangeId sample } 'EVIDENCE'
  [IO.File]::WriteAllText($packet, $acceptedPacket)
  # Scenario: changed authored spec. Expected: stale evidence blocks; reconciliation clears close review.
  $deltaPath = "$testRoot/openspec/changes/sample/specs/access/spec.md"
  Add-Content $deltaPath "`nAdditional agreed context."
  Assert-Fails { & $trace -Action Validate -ProjectRoot $testRoot -ChangeId sample } 'STALE'
  Assert-Fails { & $trace -Action Reconcile -ProjectRoot $testRoot -ChangeId sample } 'RECONCILE'
  & $trace -Action Reconcile -ProjectRoot $testRoot -ChangeId sample -ConfirmReconciled -ReconciliationEvidence 'Fixture rechecked the added context and test evidence.' | Out-Null
  Assert-Fails { & $trace -Action CloseCheck -ProjectRoot $testRoot -ChangeId sample } 'REVIEW'
  $refreshed = Get-Content $indexPath -Raw | ConvertFrom-Json
  $refreshed.reviewEvidence = 'Fixture semantic re-review completed after reconciliation.'
  $refreshed | ConvertTo-Json -Depth 20 | Set-Content $indexPath
  # Scenario: another change alters main specs. Expected: stale baseline is detected even with passing evidence.
  Set-Content "$testRoot/openspec/specs/concurrent.md" 'changed baseline'
  Assert-Fails { & $trace -Action CloseCheck -ProjectRoot $testRoot -ChangeId sample } 'STALE'
  Remove-Item -LiteralPath "$testRoot/openspec/specs/concurrent.md"
  # Scenario: upstream partially writes then fails. Expected: recovery snapshot remains and retry is blocked.
  Assert-Fails { & $adapter -Action Archive -ProjectRoot $testRoot -ChangeId sample -OpenSpecEntry $double -ConfirmArchive } 'RECOVERY'
  Assert-True (Test-Path "$testRoot/openspec/.team-recovery/specs") 'Original specs not backed up.'
  Assert-True (Test-Path "$testRoot/openspec/specs/damaged.md") 'Failure state silently overwritten.'
  Assert-Fails { & $adapter -Action Archive -ProjectRoot $testRoot -ChangeId sample -OpenSpecEntry $double -ConfirmArchive } 'RECOVERY'

  if ($OpenSpecEntry) {
    $real = Join-Path $testRoot 'real project'
    New-Item -ItemType Directory $real | Out-Null
    # Scenario: actual pinned CLI. Expected: create, instructions, validate, guarded archive and merged spec succeed.
    & $adapter -Action Enable -ProjectRoot $real -OpenSpecEntry $OpenSpecEntry | Out-Null
    & $adapter -Action Prepare -ProjectRoot $real -ChangeId sample -OpenSpecEntry $OpenSpecEntry | Out-Null
    Write-Change $real
    Write-Packet $real
    Link-Change $real
    & $adapter -Action Inspect -ProjectRoot $real -ChangeId sample -OpenSpecEntry $OpenSpecEntry | Out-Null
    & $adapter -Action Instructions -Artifact specs -ProjectRoot $real -ChangeId sample -OpenSpecEntry $OpenSpecEntry | Out-Null
    & $adapter -Action Validate -ProjectRoot $real -ChangeId sample -OpenSpecEntry $OpenSpecEntry | Out-Null
    Assert-Fails { & $adapter -Action Archive -ProjectRoot $real -ChangeId sample -OpenSpecEntry $OpenSpecEntry -ConfirmArchive } 'MANUAL_PENDING'
    $realPacket = "$real/docs/verification/active/sample.md"
    $body = Get-Content $realPacket -Raw
    Set-Content $realPacket ($body.Replace('Final manual status: manual pending','Final manual status: manually verified').Replace('Final manual evidence:', 'Final manual evidence: Fixture operator confirmed.'))
    $result = & $adapter -Action Archive -ProjectRoot $real -ChangeId sample -OpenSpecEntry $OpenSpecEntry -ConfirmArchive | ConvertFrom-Json
    Assert-True ($result.action -eq 'archived') 'Archive not confirmed.'
    Assert-True (Test-Path "$real/openspec/specs/access/spec.md") 'Delta not merged.'
    Assert-True (-not (Test-Path "$real/openspec/changes/sample")) 'Change still active.'
    Assert-True (-not (Test-Path "$real/openspec/.team-recovery")) 'Success left recovery directory.'
    Assert-Fails { & $adapter -Action Archive -ProjectRoot $real -ChangeId sample -OpenSpecEntry $OpenSpecEntry -ConfirmArchive } 'CHANGE'
    Assert-True (-not (Test-Path "$real/.agents")) 'Installed competing Skills.'
    # Scenario: changing an existing requirement. Expected: native merge replaces it, retaining its stable ID.
    & $adapter -Action Prepare -ProjectRoot $real -ChangeId modify-access -OpenSpecEntry $OpenSpecEntry | Out-Null
    Write-Change $real 'modify-access'
    $delta = "$real/openspec/changes/modify-access/specs/access/spec.md"
    $body = (Get-Content $delta -Raw).Replace('ADDED Requirements','MODIFIED Requirements').Replace('allow a valid request.','allow a valid request only after token validation.')
    Set-Content $delta $body
    Link-Change $real 'modify-access'
    & $adapter -Action Archive -ProjectRoot $real -ChangeId modify-access -OpenSpecEntry $OpenSpecEntry -ConfirmArchive | Out-Null
    Assert-True ((Get-Content "$real/openspec/specs/access/spec.md" -Raw).Contains('only after token validation')) 'Modified behavior not merged.'
    # Scenario: packet already archived. Expected: its canonical new path validates without recreating active evidence.
    $packetResult = & (Join-Path $repo 'skills/team-core/scripts/stage-verification.ps1') -Action Archive -ProjectRoot $real -StageSlug sample | ConvertFrom-Json
    & (Join-Path $repo 'skills/team-core/scripts/stage-verification.ps1') -Action Validate -ProjectRoot $real -StageSlug sample -PacketPath ([IO.Path]::GetRelativePath($real, $packetResult.packetPath).Replace('\','/')) | Out-Null
    # Scenario: retiring the final requirement. Expected: explicit retirement merges via upstream and keeps archived packet links valid.
    & $adapter -Action Prepare -ProjectRoot $real -ChangeId remove-access -OpenSpecEntry $OpenSpecEntry | Out-Null
    Write-Change $real 'remove-access'
    Set-Content "$real/openspec/changes/remove-access/specs/access/spec.md" "## REMOVED Requirements`n### Requirement: ACCESS-REQ-001 Allow access`n**Reason**: Retire the fixture capability.`n**Migration**: Consumers stop using this fixture."
    Add-Content "$real/openspec/changes/remove-access/.openspec.yaml" 'retire_capabilities: true'
    Link-Change $real 'remove-access' ''
    $removeIndexPath = "$real/openspec/changes/remove-access/verification.json"
    $removeIndex = Get-Content $removeIndexPath -Raw | ConvertFrom-Json
    $removeIndex.links[0].packet = [IO.Path]::GetRelativePath($real, $packetResult.packetPath).Replace('\','/')
    $removeIndex | ConvertTo-Json -Depth 20 | Set-Content $removeIndexPath
    & $adapter -Action Archive -ProjectRoot $real -ChangeId remove-access -OpenSpecEntry $OpenSpecEntry -ConfirmArchive | Out-Null
    Assert-True (-not (Test-Path "$real/openspec/specs/access/spec.md")) 'Retired capability still present.'
    # Scenario: an existing project uses custom schema. Expected: Enable refuses and preserves config bytes.
    $custom = Join-Path $testRoot 'custom'
    New-Item -ItemType Directory "$custom/openspec" -Force | Out-Null
    Set-Content "$custom/openspec/config.yaml" 'schema: custom-schema'
    $before = (Get-FileHash "$custom/openspec/config.yaml").Hash
    Assert-Fails { & $adapter -Action Enable -ProjectRoot $custom -OpenSpecEntry $OpenSpecEntry } 'SCHEMA'
    Assert-True ((Get-FileHash "$custom/openspec/config.yaml").Hash -eq $before) 'Existing configuration modified.'
    Assert-True (-not (Test-Path "$custom/openspec/team-integration.json")) 'Incompatible project adopted.'
  }
  Write-Host "OpenSpec tests passed. Real CLI exercised: $([bool]$OpenSpecEntry)"
} finally {
  $env:KIT_OPENSPEC_TEST_MODE = $priorMode
  # Only the unique temporary tree owned by this test may be recursively removed.
  if (Test-Path $testRoot) {
    $resolved = (Resolve-Path $testRoot).Path
    if (-not $resolved.StartsWith($tempParent, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'codex-openspec-test-*') { throw 'Unsafe cleanup target.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}
