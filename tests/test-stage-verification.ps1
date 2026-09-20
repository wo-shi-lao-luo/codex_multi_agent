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

  Invoke-ExpectFailure { & $scriptPath -Action Validate -ProjectRoot $testRoot -StageSlug 'tdd-smoke' } 'Validate accepted an incomplete initialized packet.'

  Set-ValidPacket -Path $packet -FinalManualStatus 'manual pending'
  & $scriptPath -Action Validate -ProjectRoot $testRoot -StageSlug 'tdd-smoke' | Out-Null

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
