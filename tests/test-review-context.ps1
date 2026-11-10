$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function Assert-Contains {
  param([string]$Path, [string]$Text, [string]$Message)
  $content = Get-Content -LiteralPath (Join-Path $root $Path) -Raw
  if (-not $content.Contains($Text)) { throw "ASSERTION_FAILED: $Message ($Path)" }
}

# These are source-contract checks only; they do not establish model compliance.
$profiles = @(
  'agents/team-ai-engineer.toml',
  'agents/team-ai-tester.toml',
  'agents/team-backend-engineer.toml',
  'agents/team-database-specialist.toml',
  'agents/team-frontend-engineer.toml',
  'agents/team-tester.toml'
)
# Scenario: a specialist starts in an unrelated target repository.
# Expected: its designated reference comes from the Lead and missing context is escalated.
foreach ($profile in $profiles) {
  $content = Get-Content -LiteralPath (Join-Path $root $profile) -Raw
  if (-not ($content.Contains('Lead-supplied resolved team-core code-readability reference') -or $content.Contains('Lead-supplied resolved team-core AI evaluation reference'))) { throw "ASSERTION_FAILED: Profile must use Lead-resolved reference ($profile)" }
  Assert-Contains $profile 'ask the Lead for its resolved installed/source location' 'Profile must route missing reference to Lead'
  Assert-Contains $profile 'do not guess a target-repository-relative path' 'Profile must prohibit guessed repo-relative reference'
}

# Scenario: the reviewed diff is ordinary prose rather than executable harness instructions.
# Expected: test guidance is conditional while material harness behavior keeps its gates.
Assert-Contains 'skills/team-review/SKILL.md' 'Read the [TDD protocol](../team-core/references/tdd-protocol.md) sections only when changed behavior or test evidence is in scope' 'TDD reading must be conditional'
Assert-Contains 'skills/team-review/SKILL.md' 'For prose-only documentation changes, review factual meaning and links' 'Review must distinguish prose-only documentation'
Assert-Contains 'skills/team-review/SKILL.md' 'executable Skill, workflow, or configuration instructions' 'Executable harness documentation must retain behavior review'
Assert-Contains 'skills/code-review/SKILL.md' 'For prose-only documentation, review factual meaning and links' 'Code review must distinguish prose-only documentation'
Assert-Contains 'skills/code-review/SKILL.md' 'treat changes to executable Skill/workflow/configuration instructions as harness behavior' 'Harness instruction changes must receive behavior review'

Write-Host 'PASS: review context source contracts (model behavior not tested)'
