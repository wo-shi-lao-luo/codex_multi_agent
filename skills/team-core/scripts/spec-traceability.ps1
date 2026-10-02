# Validate stable requirement/scenario links against native specs, tasks and existing stage packets.
# This checks structural evidence, not test semantics or authenticity of human approval.
#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('Initialize','Reconcile','Validate','CloseCheck')][string]$Action,
  [Parameter(Mandatory)][string]$ProjectRoot,
  [Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9-]{0,79}$')][string]$ChangeId,
  [switch]$ConfirmReconciled,
  [string]$ReconciliationEvidence
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'openspec-common.ps1')
$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$null = Get-SpecIntegration $root
$change = Resolve-SpecPath $root "openspec/changes/$ChangeId"
if (-not (Test-Path -LiteralPath $change -PathType Container)) { throw 'CHANGE: Active change does not exist.' }
$indexPath = Resolve-SpecPath $root "openspec/changes/$ChangeId/verification.json"
$snapshot = Get-SpecSnapshot $root $ChangeId

if ($Action -eq 'Initialize') {
  if (Test-Path -LiteralPath $indexPath) { throw 'INDEX: Existing index must be reconciled, not overwritten.' }
  @{ schemaVersion = 1; changeId = $ChangeId; snapshot = $snapshot; links = @(); reviewEvidence = '' } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $indexPath -Encoding utf8
  @{ action = 'initialized'; index = "openspec/changes/$ChangeId/verification.json" } | ConvertTo-Json
  exit 0
}
try { $index = Get-Content -LiteralPath $indexPath -Raw | ConvertFrom-Json -AsHashtable } catch { throw 'INDEX: Missing or invalid verification.json.' }
if ($index.schemaVersion -ne 1 -or $index.changeId -cne $ChangeId -or $index.snapshot -isnot [System.Collections.IDictionary]) { throw 'INDEX: Unsupported schema or mismatched change.' }
if ($Action -eq 'Reconcile') {
  # Deliberate baseline refresh, never automatic: retained evidence must have been reassessed first.
  # Clear close-review evidence so refresh alone cannot immediately qualify the change for archive.
  if (-not $ConfirmReconciled -or [string]::IsNullOrWhiteSpace($ReconciliationEvidence)) { throw 'RECONCILE: Explicit confirmation and evidence of impact/test reassessment are required.' }
  $index.snapshot = $snapshot
  $index.reviewEvidence = ''
  $index.reconciliationEvidence = $ReconciliationEvidence
  $index | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $indexPath -Encoding utf8
  @{ action = 'reconciled'; reviewRequired = $true } | ConvertTo-Json
  exit 0
}
if ($snapshot.Count -ne $index.snapshot.Count) { throw 'STALE: Specification inputs changed; review and reconcile evidence before refreshing the snapshot.' }
foreach ($key in $snapshot.Keys) {
  if (-not $index.snapshot.Contains($key) -or $index.snapshot[$key] -cne $snapshot[$key]) { throw "STALE: Specification input changed: $key" }
}

# Stable IDs live in native Markdown titles, so OpenSpec's merge carries them into the main specs.
# Require a map for every added/modified scenario and for each removal (which may have no scenarios).
$requirements = @{}
$scenarios = @{}
$requiredLinks = [Collections.Generic.List[string]]::new()
foreach ($file in @(Get-SpecFiles $root "openspec/changes/$ChangeId/specs" | Where-Object Extension -eq '.md')) {
  $operation = ''; $requirement = ''
  foreach ($line in (Get-Content -LiteralPath $file.FullName)) {
    if ($line -match '^## (ADDED|MODIFIED|REMOVED|RENAMED) Requirements\s*$') {
      $operation = $Matches[1]
      if ($operation -eq 'RENAMED') { throw 'SPEC: v1 requires stable titles; express renames as reviewed REMOVED and ADDED requirements.' }
      $requirement = ''
    } elseif ($line -match '^### Requirement:\s*(.*)$') {
      if ($Matches[1] -notmatch '^([A-Z][A-Z0-9-]*-REQ-[0-9]+)\s+\S') { throw 'SPEC: Requirement title needs a stable DOMAIN-REQ-number ID and label.' }
      $requirement = $Matches[1]
      if (-not $operation -or $requirements.ContainsKey($requirement)) { throw 'SPEC: Missing delta operation or duplicate requirement ID.' }
      $requirements[$requirement] = $operation
      if ($operation -eq 'REMOVED') { $requiredLinks.Add("$requirement/") }
    } elseif ($line -match '^#### Scenario:\s*(.*)$') {
      if (-not $requirement -or $Matches[1] -notmatch '^([A-Z][A-Z0-9-]*-SC-[0-9]+)\s+\S') { throw 'SPEC: Scenario needs a requirement and stable DOMAIN-SC-number ID and label.' }
      $scenario = $Matches[1]
      if ($scenarios.ContainsKey($scenario)) { throw 'SCENARIO: Duplicate scenario ID.' }
      $scenarios[$scenario] = $requirement
      $requiredLinks.Add("$requirement/$scenario")
    }
  }
}
if ($requirements.Count -eq 0 -or $requiredLinks.Count -eq 0) { throw 'SPEC: No traceable behavior found; documentation-only changes use the native kit workflow.' }
foreach ($id in $requirements.Keys) {
  if ($requirements[$id] -ne 'REMOVED' -and $id -notin $scenarios.Values) { throw "SCENARIO: Requirement has no scenarios: $id" }
}
$tasksPath = Resolve-SpecPath $root "openspec/changes/$ChangeId/tasks.md"
$tasks = @{}
$taskContent = Get-Content -LiteralPath $tasksPath -Raw
foreach ($match in [regex]::Matches($taskContent, '(?m)^\s*- \[([ xX])\]\s+(\d+(?:\.\d+)+)\s+\S[^\r\n]*')) {
  $id = $match.Groups[2].Value
  if ($tasks.ContainsKey($id)) { throw 'TASK: Duplicate task ID.' }
  $tasks[$id] = $match.Groups[1].Value -ne ' '
}
if ($tasks.Count -eq 0) { throw 'TASK: Expected numbered native task checkboxes.' }
if ([regex]::Matches($taskContent, '(?m)^\s*- \[[^\]\r\n]*\]').Count -ne $tasks.Count) { throw 'TASK: Every task checkbox must have a unique numeric ID and description.' }
if (@($index.links).Count -eq 0) { throw 'LINK: At least one evidence mapping is required.' }
$covered = @{}
$coveredTasks = @{}
$packets = @{}
foreach ($link in $index.links) {
  if (-not $requirements.ContainsKey([string]$link.requirement)) { throw 'REQUIREMENT: Unknown requirement.' }
  if ($link.scenario) {
    if (-not $scenarios.ContainsKey([string]$link.scenario) -or $scenarios[$link.scenario] -cne $link.requirement) { throw 'SCENARIO: Unknown or mismatched scenario.' }
  } elseif ($requirements[$link.requirement] -ne 'REMOVED') { throw 'SCENARIO: Scenario is required except for removed requirements.' }
  if (-not $tasks.ContainsKey([string]$link.task)) { throw 'TASK: Unknown task.' }
  if ([string]::IsNullOrWhiteSpace($link.regression)) { throw 'REGRESSION: Explain the baseline and affected existing checks.' }
  $packetPath = Resolve-SpecPath $root ([string]$link.packet)
  if ($link.packet -notmatch '^docs/verification/(active|archive)/[a-z0-9_-]+\.md$') { throw 'PATH: v1 accepts canonical stage packets only.' }
  if (-not $packets.ContainsKey($link.packet)) {
    $body = Get-Content -LiteralPath $packetPath -Raw
    $slug = [regex]::Match($body, '(?m)^Stage slug:[ \t]*([a-z0-9-]+)\s*$').Groups[1].Value
    if (-not $slug) { throw 'PACKET: Stage slug missing.' }
    $validated = & (Join-Path $PSScriptRoot 'stage-verification.ps1') -Action Validate -ProjectRoot $root -StageSlug $slug -PacketPath $link.packet | ConvertFrom-Json
    $packets[$link.packet] = @{ body = $body; validation = $validated }
  }
  $body = $packets[$link.packet].body
  if ([string]$link.case -notmatch '^CASE-[0-9]+$') { throw 'CASE: Expected CASE-number identifier.' }
  $casePattern = [regex]::Escape($link.case)
  $cases = [regex]::Match($body, '(?ms)^## Use-case map\s*\r?\n(.*?)(?=^## |\z)').Groups[1].Value
  if ([regex]::Matches($cases, "(?m)^\| $casePattern(?: |\|)").Count -ne 1) { throw 'CASE: Case must occur exactly once in the use-case map.' }
  $matrix = [regex]::Match($body, '(?ms)^## TDD behavior matrix\s*\r?\n(.*?)(?=^## |\z)').Groups[1].Value
  $rows = @($matrix -split '\r?\n' | Where-Object { $_ -match "^\| $casePattern(?: |\|)" })
  if ($rows.Count -eq 0) { throw 'CASE: Case has no TDD behavior row.' }
  $covered["$($link.requirement)/$($link.scenario)"] = $true
  $coveredTasks[$link.task] = $true
}
foreach ($key in $requiredLinks) { if (-not $covered.ContainsKey($key)) { throw "LINK: Missing scenario/removal coverage: $key" } }
foreach ($key in $tasks.Keys) { if (-not $coveredTasks.ContainsKey($key)) { throw "TASK: Task has no verification mapping: $key" } }
if ($Action -eq 'CloseCheck') {
  if ($false -in $tasks.Values) { throw 'TASK: Unfinished tasks prevent close.' }
  if ([string]::IsNullOrWhiteSpace($index.reviewEvidence)) { throw 'REVIEW: Review evidence is required.' }
  foreach ($packet in $packets.Values) {
    if ($packet.validation.finalManualStatus -notin @('manually verified','deferred by user')) { throw 'MANUAL_PENDING: User acceptance or explicit deferral is required for every packet.' }
    # Unmapped unfinished rows also block closure: a partial mapping cannot hide unfinished stage work.
    $matrix = [regex]::Match($packet.body, '(?ms)^## TDD behavior matrix\s*\r?\n(.*?)(?=^## |\z)').Groups[1].Value
    foreach ($row in @($matrix -split '\r?\n' | Where-Object { $_ -match '^\| ' } | Select-Object -Skip 2)) {
      $cells = @($row.Trim().Trim('|').Split('|') | ForEach-Object Trim)
      if ($cells[10] -notin @('passing','manually verified','exception accepted')) { throw 'EVIDENCE: Stage contains unfinished behavior.' }
      if ($cells[10] -eq 'passing' -and ([string]::IsNullOrWhiteSpace($cells[6]) -or $cells[6] -in @('planned','not applicable'))) { throw 'EVIDENCE: Passing stage row lacks observed Green evidence.' }
      if ($cells[10] -eq 'exception accepted' -and $cells[8] -notmatch '(?i)accepted by\s+\S') { throw 'EVIDENCE: Exception requires risk and accepted by attribution.' }
    }
  }
}
@{ action = $Action; valid = $true; changeId = $ChangeId; requirements = $requirements.Count; scenarios = $scenarios.Count; packets = @($packets.Keys) } | ConvertTo-Json -Depth 10
