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

# Scenario: internal development and external PR review must discover the same maintained method.
# Expected: executable Markdown routes resolve to the packaged guide, not merely its name.
foreach ($entry in @('code-review', 'team-review', 'team-dev')) {
  Assert-Contains "skills/$entry/SKILL.md" '](../team-core/references/code-review-method.md)' 'Shared review method must be reachable'
}
Assert-Contains 'skills/team-core/SKILL.md' '](references/code-review-method.md)' 'Core must expose the review method'
Assert-Contains 'agents/team-reviewer.toml' 'Lead-supplied resolved team-core code-review method' 'Reviewer must receive cross-repository context'
$methodPath = Join-Path $root 'skills/team-core/references/code-review-method.md'
if (-not (Test-Path -LiteralPath $methodPath -PathType Leaf)) { throw 'ASSERTION_FAILED: Missing packaged code-review method' }

# Scenario: evidence certainty, impact, and action are different decisions in both review modes.
# Expected: a material unknown stays pending; a confirmed defect is not optional; reviewer remains read-only.
foreach ($section in @('## Shared evidence procedure', '## Disposition and human decisions',
  '## Structure, reuse and repository lifecycle', '## Internal development review',
  '## External PR assistance', '## Review quality evaluation')) {
  Assert-Contains 'skills/team-core/references/code-review-method.md' $section 'Method must cover the approved review surfaces'
}
foreach ($invariant in @('must-fix', 'human-decision', 'optional', 'unproven',
  'requiredChecks', 'checkResults', 'base/head', 'hidden tests', 'false positives', 'token')) {
  Assert-Contains 'skills/team-core/references/code-review-method.md' $invariant 'Review method must preserve evidence and evaluation boundaries'
}
Assert-Contains 'skills/team-core/references/execution-templates.md' 'Disposition and human decision' 'Handoff must retain actionable decisions'

# Scenario: design, implementation, testing and review use the same packaged UI method.
# Expected: each real entrypoint reaches the authoritative UI contract and its guide.
# This is context-routing evidence, not a test of model judgment or user experience.
foreach ($entry in @('frontend-design', 'frontend-engineering', 'testing-engineering', 'code-review')) {
  Assert-Contains "skills/$entry/SKILL.md" '](../team-core/references/ui-quality.md)' 'UI contract must be reachable from its consumers'
}
Assert-Contains 'skills/team-core/references/ui-quality.md' '](ui-design-and-evaluation.md)' 'UI contract must expose the shared design and diagnosis method'
$uiMethodPath = Join-Path $root 'skills/team-core/references/ui-design-and-evaluation.md'
if (-not (Test-Path -LiteralPath $uiMethodPath -PathType Leaf)) { throw 'ASSERTION_FAILED: Missing packaged UI design and diagnosis method' }

Write-Host 'PASS: review context source contracts (model behavior not tested)'
