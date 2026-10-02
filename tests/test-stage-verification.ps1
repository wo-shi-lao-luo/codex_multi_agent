# Exercise packet initialization, schema2 compatibility and user-only archival authority
# in disposable projects. These checks do not certify future agent test-plan semantics.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $root 'skills\team-core\scripts\stage-verification.ps1'
$temporaryParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRootName = 'codex-multi-agent-stage-verification-test-' + [Guid]::NewGuid().ToString('N')
$testRoot = Join-Path $temporaryParent $testRootName

function Assert-Condition {
  param([Parameter(Mandatory = $true)][bool]$Condition, [Parameter(Mandatory = $true)][string]$Message)
  if (-not $Condition) { throw $Message }
}

function Invoke-ExpectFailure {
  param([Parameter(Mandatory = $true)][scriptblock]$Operation, [Parameter(Mandatory = $true)][string]$Message)
  $failed = $false
  try { & $Operation } catch { $failed = $true }
  Assert-Condition $failed $Message
}

function Set-ValidPacket {
  param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$FinalManualStatus)

  @"
# Verification: TDD protocol smoke test

Packet schema version: 2
Stage slug: tdd-smoke
Contract status: active
Final manual status: $FinalManualStatus
Final manual evidence: test operator result

## Stage context
- Objective: Verify the protocol packet parser.
- Scope, environment, test data, and cleanup: isolated temporary directory; remove at test exit.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| Validate a deterministic behavior | Test runner available | Run the named test | Evidence is recorded | happy |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | required | Parser behavior is deterministic. |
| integration | not applicable | This isolated script has no service boundary. |
| contract/API | not applicable | This isolated script exposes no API. |
| E2E | conditional | A later real workflow task exercises the user journey. |
| regression | required | The script prevents unsafe archival regressions. |
| manual | required | A human reviews the generated packet in a target project. |
| component/UI | not applicable | No UI component exists. |
| accessibility | not applicable | No user interface exists. |
| visual regression | not applicable | No rendered visual output exists. |
| performance/load | not applicable | The parser has no material load requirement. |
| security | conditional | The target project controls its own secret and permission surface. |
| compatibility | conditional | The script supports PowerShell available to the kit. |
| data migration/rollback | not applicable | The script only creates or moves packet files. |
| resilience/recovery | conditional | Failed validation leaves the packet unchanged. |
| exploratory/usability | conditional | Human packet readability is reviewed during real use. |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Validates a deterministic packet | malformed acceptance record | unit | test-first | PacketValidationTests.AcceptsValidPacket | `pwsh test-stage-verification.ps1` failed before parser implementation | `pwsh test-stage-verification.ps1` passed after parser implementation | Relevant test rerun after refactor passed | not applicable | team-tester | passing |

## Automated test and E2E plan
- Commands, fixtures, environment, cleanup, and TDD exceptions: run this isolated script; no external service or retained data.

## Human verification script
### Preparation
1. Prepare isolated temporary project.
### Happy path
1. Run validation.
   Expected result: valid packet is accepted.
### Recommended edge cases
1. Set final manual status to manual pending.
   Expected result: archive is rejected.
### Result
- Observations and cleanup: temporary directory removed by this test.
"@ | Set-Content -LiteralPath $Path -Encoding utf8
}

try {
  New-Item -ItemType Directory -Path $testRoot -ErrorAction Stop | Out-Null
  & $scriptPath -Action Initialize -ProjectRoot $testRoot -StageSlug 'tdd-smoke' -StageTitle 'TDD protocol smoke test' | Out-Null
  $packet = Join-Path $testRoot 'docs\verification\active\tdd-smoke.md'
  Assert-Condition (Test-Path -LiteralPath $packet) 'Initialize did not create an active packet.'
  $initialized = Get-Content -LiteralPath $packet -Raw
  foreach ($requiredField in 'Packet schema version:', 'Final manual status:', '## Coverage-category decisions', '## TDD behavior matrix', 'Red evidence', 'Green evidence', 'Refactor verification') {
    Assert-Condition $initialized.Contains($requiredField) "Initialize omitted required TDD packet field: $requiredField"
  }

  # Scenario: a generated packet lets authors choose execution boundaries and
  # observation evidence without confusing cheaper execution with weaker coverage.
  # Expected: six ordered planning fields and one fillable row are emitted.
  $executionSection = [regex]::Match($initialized, '(?ms)^### Execution and observation choices\s*\r?\n(?<body>.*?)(?=^### |^## |\z)')
  $executionRows = @($executionSection.Groups['body'].Value -split "`r?`n" | Where-Object { $_.Trim().StartsWith('|') })
  Assert-Condition ($executionRows.Count -eq 3) 'Initialize did not emit a fillable execution and observation table.'
  $executionColumns = @($executionRows[0].Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
  $expectedExecutionColumns = @('Case / test ID', 'Execution entrypoint and real boundary', 'Runner / command', 'Observation mode and rationale', 'Retained browser / visual checkpoints', 'Evidence / drill-down / gaps')
  Assert-Condition (($executionColumns -join ';') -eq ($expectedExecutionColumns -join ';')) 'Execution planning fields omit boundary, runner, observation, retained checkpoints or evidence.'
  $fillableExecutionCells = @($executionRows[2].Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
  Assert-Condition ($fillableExecutionCells.Count -eq 6 -and @($fillableExecutionCells | Where-Object { $_ }).Count -eq 0) 'Execution planning row is not empty and fillable.'

  # Scenario: a new packet needs per-manual-case E2E and other-layer evidence fields.
  # Expected: its emitted mapping has five ordered data columns and a fillable row,
  # without pretending that table presence establishes semantic or executed coverage.
  $mappingSection = [regex]::Match($initialized, '(?ms)^### Manual-to-automated coverage mapping\s*\r?\n(?<body>.*?)(?=^## |\z)')
  $mappingRows = @($mappingSection.Groups['body'].Value -split "`r?`n" | Where-Object { $_.Trim().StartsWith('|') })
  Assert-Condition ($mappingRows.Count -eq 3) 'Initialize did not emit a fillable manual-to-automated mapping table.'
  $mappingColumns = @($mappingRows[0].Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
  $expectedColumns = @('Manual case / requirement ID', 'E2E scenario / test ID and checkpoints', 'Other test layers / test IDs or reasons', 'Status and evidence', 'Gap / user exception decision')
  Assert-Condition (($mappingColumns -join ';') -eq ($expectedColumns -join ';')) 'Mapping data columns do not expose case identity, test layers, evidence and user exception decisions.'

  # Scenario: mapped cases are filled and a user adds a case after initial planning.
  # Expected: schema2 Validate preserves every authored mapping and pending result;
  # even a listed automated test cannot authorize archive without user acceptance.
  $syncPacket = Join-Path $testRoot 'docs/verification/active/coverage-sync-smoke.md'
  Set-ValidPacket -Path $syncPacket -FinalManualStatus 'manual pending'
  $filledMapping = $mappingSection.Value.Replace('| | | | | |', '| M01 | E01: valid packet accepted | contract: PacketValidationTests.AcceptsValidPacket | planned; no execution evidence | none |').TrimEnd()
  $pendingMapping = '| M02 | E02: pending manual status blocks archive | regression: ArchiveRejectsPending | planned; no execution evidence | none |'
  $filledMapping += "`n" + $pendingMapping + "`n"
  $syncContent = (Get-Content -LiteralPath $syncPacket -Raw).Replace('Stage slug: tdd-smoke', 'Stage slug: coverage-sync-smoke').Replace('## Human verification script', $filledMapping + "`n## Human verification script")
  $syncContent = $syncContent.Replace('1. Run validation.', '1. M01: run validation.').Replace('1. Set final manual status to manual pending.', '1. M02: set final manual status to manual pending.')
  Set-Content -LiteralPath $syncPacket -Value $syncContent -Encoding utf8
  & $scriptPath -Action Validate -ProjectRoot $testRoot -StageSlug 'coverage-sync-smoke' | Out-Null
  $newMapping = '| M03 | E03: new visual scenario retained; subjective observation unavailable | component/screenshot check conditional; user intent decision pending | manual pending; no passing evidence | user exception pending |'
  $syncContent = $syncContent.Replace($pendingMapping, $pendingMapping + "`n" + $newMapping).Replace('### Recommended edge cases', "### Recommended edge cases`n1. M03: user-added subjective visual scenario; expected user review remains pending.")
  Set-Content -LiteralPath $syncPacket -Value $syncContent -Encoding utf8
  $syncHash = (Get-FileHash -LiteralPath $syncPacket -Algorithm SHA256).Hash
  & $scriptPath -Action Validate -ProjectRoot $testRoot -StageSlug 'coverage-sync-smoke' | Out-Null
  Assert-Condition ((Get-FileHash -LiteralPath $syncPacket -Algorithm SHA256).Hash -eq $syncHash) 'Validate changed authored mappings or pending evidence.'
  Invoke-ExpectFailure { & $scriptPath -Action Archive -ProjectRoot $testRoot -StageSlug 'coverage-sync-smoke' } 'Mapped plans bypassed pending user acceptance.'
  Assert-Condition (Test-Path -LiteralPath $syncPacket) 'Rejected archive moved the mapped active packet.'

  Invoke-ExpectFailure { & $scriptPath -Action Validate -ProjectRoot $testRoot -StageSlug 'tdd-smoke' } 'Validate accepted an incomplete initialized packet.'

  Set-ValidPacket -Path $packet -FinalManualStatus 'manual pending'
  & $scriptPath -Action Validate -ProjectRoot $testRoot -StageSlug 'tdd-smoke' | Out-Null

  # Scenario: an existing schema2 packet has no new subsection; an author then
  # adds concrete programmatic and rendered-observation choices for a future run.
  # Expected: both forms validate, byte-for-byte authored choices stay unchanged,
  # and planning metadata cannot turn manual pending into archive permission.
  $legacyHash = (Get-FileHash -LiteralPath $packet -Algorithm SHA256).Hash
  & $scriptPath -Action Validate -ProjectRoot $testRoot -StageSlug 'tdd-smoke' | Out-Null
  Assert-Condition ((Get-FileHash -LiteralPath $packet -Algorithm SHA256).Hash -eq $legacyHash) 'Validate mutated the legacy schema2 packet.'
  $filledExecution = $executionSection.Value.Replace('| | | | | | |', '| CRUD-01 | real application HTTP and persistence boundary | isolated scenario runner | structured summary; drill into failed assertions | browser submit and rendered error check remain pending | trace reference; token telemetry unknown |').TrimEnd()
  $executionContent = (Get-Content -LiteralPath $packet -Raw).Replace('## Human verification script', $filledExecution + "`n`n## Human verification script")
  Set-Content -LiteralPath $packet -Value $executionContent -Encoding utf8
  $executionHash = (Get-FileHash -LiteralPath $packet -Algorithm SHA256).Hash
  & $scriptPath -Action Validate -ProjectRoot $testRoot -StageSlug 'tdd-smoke' | Out-Null
  Assert-Condition ((Get-FileHash -LiteralPath $packet -Algorithm SHA256).Hash -eq $executionHash) 'Validate changed authored execution choices or pending observations.'
  Invoke-ExpectFailure { & $scriptPath -Action Archive -ProjectRoot $testRoot -StageSlug 'tdd-smoke' } 'Execution choices bypassed pending user acceptance.'

  $blueprintScript = Join-Path (Split-Path -Parent $scriptPath) 'project-blueprint.ps1'
  & $blueprintScript -Action Initialize -ProjectRoot $testRoot | Out-Null
  $blueprintPath = Join-Path $testRoot 'docs/architecture/project-blueprint.md'
  $blueprint = (Get-Content -LiteralPath $blueprintPath -Raw).Replace('Project context: draft', 'Project context: existing').Replace('Refactor decision: pending', 'Refactor decision: not needed').Replace('Decision evidence:', 'Decision evidence: Existing parser structure inspected; no reorganization proposed.').Replace('| | | | |', '| parser | Validate packets | skills/team-core/scripts | none |')
  $blueprint = $blueprint -replace '(?m)^(## [^\r\n]+)', ('$1'+"`nExisting parser boundary inspected; run isolated tests and retain its file ownership.")
  Set-Content -LiteralPath $blueprintPath -Value $blueprint -Encoding utf8
  $alignment = @'

## Structural alignment
Blueprint path: docs/architecture/project-blueprint.md
Blueprint revision: 1
Blueprint modules: parser
Allowed existing files: skills/team-core/scripts/stage-verification.ps1
Planned additions: none
Composition roots affected: none
Blueprint amendment: none
'@
  $basePacket = Get-Content -LiteralPath $packet -Raw
  Set-Content -LiteralPath $packet -Value ($basePacket + $alignment) -Encoding utf8
  & $scriptPath -Action Validate -ProjectRoot $testRoot -StageSlug 'tdd-smoke' | Out-Null
  Set-Content -LiteralPath $packet -Value ($basePacket + $alignment.Replace('Blueprint revision: 1', 'Blueprint revision: 9')) -Encoding utf8
  Invoke-ExpectFailure { & $scriptPath -Action Validate -ProjectRoot $testRoot -StageSlug 'tdd-smoke' } 'Stale blueprint revision accepted.'
  Set-Content -LiteralPath $packet -Value ($basePacket + $alignment.Replace('Blueprint modules: parser', 'Blueprint modules: unknown')) -Encoding utf8
  Invoke-ExpectFailure { & $scriptPath -Action Validate -ProjectRoot $testRoot -StageSlug 'tdd-smoke' } 'Unknown blueprint module accepted.'
  Set-Content -LiteralPath $packet -Value $basePacket -Encoding utf8
  Invoke-ExpectFailure { & $scriptPath -Action Validate -ProjectRoot $testRoot -StageSlug 'tdd-smoke' -BlueprintPath 'docs/architecture/project-blueprint.md' } 'Explicit blueprint requirement was ignored.'

  $missingCoverageDecision = (Get-Content -LiteralPath $packet -Raw) -replace '(?m)^\| accessibility \| not applicable \| No user interface exists\. \|\r?\n', ''
  Set-Content -LiteralPath $packet -Value $missingCoverageDecision -Encoding utf8
  Invoke-ExpectFailure { & $scriptPath -Action Validate -ProjectRoot $testRoot -StageSlug 'tdd-smoke' } 'Validate accepted a packet without a coverage-category decision.'
  Set-ValidPacket -Path $packet -FinalManualStatus 'manual pending'

  Add-Content -LiteralPath $packet -Value 'Historical manual status: manually verified' -Encoding utf8
  Invoke-ExpectFailure { & $scriptPath -Action Archive -ProjectRoot $testRoot -StageSlug 'tdd-smoke' } 'Archive accepted historical status text instead of the authoritative final status.'
  Assert-Condition (Test-Path -LiteralPath $packet) 'Rejected archive moved the active packet.'

  $invalidNonTestFirst = (Get-Content -LiteralPath $packet -Raw).Replace('| test-first |', '| manual-or-environmental |').Replace('| not applicable | team-tester | passing |', '|  | team-tester | exception accepted |')
  Set-Content -LiteralPath $packet -Value $invalidNonTestFirst -Encoding utf8
  Invoke-ExpectFailure { & $scriptPath -Action Validate -ProjectRoot $testRoot -StageSlug 'tdd-smoke' } 'Validate accepted a non-test-first row without a rationale.'

  Set-ValidPacket -Path $packet -FinalManualStatus 'manually verified'
  & $scriptPath -Action Archive -ProjectRoot $testRoot -StageSlug 'tdd-smoke' | Out-Null
  $archive = Join-Path $testRoot 'docs\verification\archive'
  $archivedPacket = Get-ChildItem -LiteralPath $archive -Filter '*_tdd-smoke.md' -File
  Assert-Condition ($archivedPacket.Count -eq 1) 'Archive did not create exactly one archived packet.'
  Assert-Condition (-not (Test-Path -LiteralPath $packet)) 'Archive left the active packet in place.'
  Invoke-ExpectFailure { & $scriptPath -Action Archive -ProjectRoot $testRoot -StageSlug 'tdd-smoke' } 'Archive accepted a second move for the same stage.'

  Write-Host 'Stage verification tests passed.'
} finally {
  $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
  $resolvedParent = [System.IO.Path]::GetFullPath((Split-Path -Parent $resolvedTestRoot)).TrimEnd([char]'\', [char]'/' )
  $normalizedTemporaryParent = $temporaryParent.TrimEnd([char]'\', [char]'/' )
  if ($resolvedParent -ne $normalizedTemporaryParent -or -not ([System.IO.Path]::GetFileName($resolvedTestRoot).StartsWith('codex-multi-agent-stage-verification-test-'))) {
    throw "Refusing to clean unexpected test path: $resolvedTestRoot"
  }
  if (Test-Path -LiteralPath $resolvedTestRoot) {
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction Stop
  }
  Assert-Condition (-not (Test-Path -LiteralPath $resolvedTestRoot)) 'Stage-verification test cleanup left an unexpected directory.'
  Write-Host 'Isolated stage-verification directory removed.'
}
