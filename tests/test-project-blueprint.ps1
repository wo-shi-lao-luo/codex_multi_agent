[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'skills/team-core/scripts/project-blueprint.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $tempParent ('codex-blueprint-test-' + [Guid]::NewGuid().ToString('N'))
function Assert-Fails([scriptblock]$Check, [string]$Label) {
  $failed = $false
  try { & $Check | Out-Null } catch { $failed = $true }
  if (-not $failed) { throw "Expected rejection: $Label" }
}
try {
  New-Item -ItemType Directory -Path $testRoot | Out-Null
  & $scriptPath -Action Initialize -ProjectRoot $testRoot | Out-Null
  $packet = Join-Path $testRoot 'docs/architecture/project-blueprint.md'
  Assert-Fails { & $scriptPath -Action Validate -ProjectRoot $testRoot } 'blank template'
  Assert-Fails { & $scriptPath -Action Initialize -ProjectRoot $testRoot } 'overwrite'
  Assert-Fails { & $scriptPath -Action Initialize -ProjectRoot $testRoot -BlueprintPath '../escape.md' } 'path escape'
  $valid = @'
# Project blueprint
Blueprint schema: 1
Blueprint revision: 1
Project context: existing
Refactor decision: declined
Decision evidence: User declined extraction; retain current entrypoint for this stage.
## Scope
Extend an existing settings screen.
## Baseline assessment
Inspected src/App.tsx and its tests. Settings share the application root; baseline tests pass.
## Modules
| Module | Responsibility | Location | Dependencies |
| --- | --- | --- | --- |
| settings | User preferences | src/App.tsx | none |
## File responsibilities
src/App.tsx retains composition and settings logic under the recorded exception.
## Composition roots
src/App.tsx; retain baseline because extraction was declined. Limit edits to settings.
## Interfaces and ownership
Lead owns settings props and state boundary.
## Structural evolution
Future extraction requires explicit user approval and characterization tests.
## Verification
Run settings tests and review the stage diff against the retained boundary.
## Retained constraints
Settings remain coupled to the root. Do not move files under this decision.
'@
  Set-Content -LiteralPath $packet -Value $valid -Encoding utf8
  $before = (Get-FileHash -LiteralPath $packet).Hash
  $result = & $scriptPath -Action Validate -ProjectRoot $testRoot | ConvertFrom-Json
  if ($result.refactorDecision -ne 'declined' -or $before -ne (Get-FileHash -LiteralPath $packet).Hash) { throw 'Declined baseline was not accepted read-only.' }
  foreach ($decision in 'not needed', 'pending', 'approved', 'deferred') {
    Set-Content -LiteralPath $packet -Value $valid.Replace('Refactor decision: declined', "Refactor decision: $decision") -Encoding utf8
    & $scriptPath -Action Validate -ProjectRoot $testRoot | Out-Null
  }
  Set-Content -LiteralPath $packet -Value ($valid + "`nBlueprint revision: 2") -Encoding utf8
  Assert-Fails { & $scriptPath -Action Validate -ProjectRoot $testRoot } 'duplicate metadata'
  Set-Content -LiteralPath $packet -Value ($valid -replace 'Decision evidence:[^\r\n]*', 'Decision evidence:') -Encoding utf8
  Assert-Fails { & $scriptPath -Action Validate -ProjectRoot $testRoot } 'missing decision evidence'
  Set-Content -LiteralPath $packet -Value $valid.Replace('| settings | User preferences | src/App.tsx | none |', '| | | | |') -Encoding utf8
  Assert-Fails { & $scriptPath -Action Validate -ProjectRoot $testRoot } 'empty module'
  Set-Content -LiteralPath $packet -Value $valid -Encoding utf8
  & $scriptPath -Action Initialize -ProjectRoot $testRoot -BlueprintPath 'architecture/current.md' | Out-Null
  Set-Content -LiteralPath (Join-Path $testRoot 'architecture/current.md') -Value $valid.Replace('Project context: existing', 'Project context: new').Replace('Refactor decision: declined', 'Refactor decision: not needed') -Encoding utf8
  & $scriptPath -Action Validate -ProjectRoot $testRoot -BlueprintPath 'architecture/current.md' | Out-Null
  $stageScript = Join-Path (Split-Path -Parent $scriptPath) 'stage-verification.ps1'
  & $stageScript -Action Initialize -ProjectRoot $testRoot -StageSlug 'settings' -BlueprintPath 'docs/architecture/project-blueprint.md' | Out-Null
  $stage = Get-Content -LiteralPath (Join-Path $testRoot 'docs/verification/active/settings.md') -Raw
  if (-not $stage.Contains('Blueprint path: docs/architecture/project-blueprint.md')) { throw 'Missing structural alignment.' }
  Write-Host 'Blueprint tests passed.'
} finally {
  $resolved = [IO.Path]::GetFullPath($testRoot)
  if ((Split-Path -Parent $resolved).TrimEnd('\', '/') -ne $tempParent.TrimEnd('\', '/') -or -not (Split-Path -Leaf $resolved).StartsWith('codex-blueprint-test-')) { throw 'Unsafe test cleanup path.' }
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
  if (Test-Path -LiteralPath $resolved) { throw 'Test directory remains.' }
  Write-Host 'Blueprint test directory removed.'
}
