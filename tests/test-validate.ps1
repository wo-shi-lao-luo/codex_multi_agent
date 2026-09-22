# Validate package contracts in a disposable copy; no real installation is modified.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$temporaryParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRootName = "codex-multi-agent-validate-test-" + [Guid]::NewGuid().ToString('N')
$testRoot = Join-Path $temporaryParent $testRootName
$validator = Join-Path $testRoot 'scripts\validate.ps1'

function Assert-Condition {
  # Abort a scenario when its observable package-validation result is wrong.
  param([Parameter(Mandatory = $true)][bool]$Condition, [Parameter(Mandatory = $true)][string]$Message)
  if (-not $Condition) { throw $Message }
}

function Invoke-CopiedValidator {
  # Return success as a Boolean while preserving the caller's error/exit state.
  $previousErrorActionPreference = $ErrorActionPreference
  $previousLastExitCode = $global:LASTEXITCODE
  try {
    $ErrorActionPreference = 'Continue'
    $global:LASTEXITCODE = 0
    & $validator 2>&1 | Out-Null
    return ($global:LASTEXITCODE -eq 0)
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
    $global:LASTEXITCODE = $previousLastExitCode
  }
}

try {
  New-Item -ItemType Directory -Path $testRoot -ErrorAction Stop | Out-Null
  foreach ($item in 'agents', 'skills', 'scripts', 'VERSION', 'CHANGELOG.md') {
    Copy-Item -LiteralPath (Join-Path $root $item) -Destination $testRoot -Recurse -Force -ErrorAction Stop
  }

  # Scenario: an intact package. Expected: validation succeeds before mutations.
  Assert-Condition (Invoke-CopiedValidator) 'Baseline validation failed in an isolated package copy.'

  # Scenario: each UI workflow loses its contract route while links remain valid.
  # Expected: reject each mutation, and accept the restored package.
  foreach ($skillName in 'team-dev', 'team-plan', 'team-review', 'team-core', 'frontend-engineering', 'code-review', 'testing-engineering', 'frontend-design') {
    $uiSkill = Join-Path $testRoot "skills/$skillName/SKILL.md"
    $originalUiSkill = Get-Content -LiteralPath $uiSkill -Raw
    Set-Content -LiteralPath $uiSkill -Value ($originalUiSkill.Replace('ui-quality.md', 'execution-contract.md')) -Encoding utf8
    Assert-Condition (-not (Invoke-CopiedValidator)) "Validation accepted missing UI routing in $skillName."
    Copy-Item -LiteralPath (Join-Path $root "skills/$skillName/SKILL.md") -Destination $uiSkill -Force
  }
  Assert-Condition (Invoke-CopiedValidator) 'Validation failed after restoring UI routes.'

  # Scenario: a missing design entrypoint or shared UI contract.
  # Expected: reject the package; restoring each file restores successful validation.
  foreach ($relativePath in 'skills/frontend-design/SKILL.md', 'skills/team-core/references/ui-quality.md') {
    $missingPath = Join-Path $testRoot $relativePath
    Remove-Item -LiteralPath $missingPath -Force
    Assert-Condition (-not (Invoke-CopiedValidator)) "Validation accepted missing $relativePath."
    Copy-Item -LiteralPath (Join-Path $root $relativePath) -Destination $missingPath -Force
    Assert-Condition (Invoke-CopiedValidator) "Validation failed after restoring $relativePath."
  }

  # Scenario: the native frontend agent loses its design-Skill route.
  # Expected: reject it without requiring any particular instruction wording.
  $frontendAgentPath = Join-Path $testRoot 'agents/team-frontend-engineer.toml'
  $frontendAgentContent = Get-Content -LiteralPath $frontendAgentPath -Raw
  Set-Content -LiteralPath $frontendAgentPath -Value ($frontendAgentContent.Replace('frontend-design', 'frontend-engineering')) -Encoding utf8
  Assert-Condition (-not (Invoke-CopiedValidator)) 'Validation accepted missing native frontend design routing.'
  Copy-Item -LiteralPath (Join-Path $root 'agents/team-frontend-engineer.toml') -Destination $frontendAgentPath -Force
  Assert-Condition (Invoke-CopiedValidator) 'Validation failed after restoring native frontend routing.'

  # Scenario: remove a comment-contract route but keep its replacement link valid.
  # Expected: reject each missing route rather than rely on generic link checks.
  foreach ($skillName in 'team-core', 'team-dev', 'team-review', 'code-review', 'frontend-engineering', 'backend-engineering', 'database-engineering', 'testing-engineering') {
    $commentSkill = Join-Path $testRoot "skills/$skillName/SKILL.md"
    $originalSkill = Get-Content -LiteralPath $commentSkill -Raw
    Set-Content -LiteralPath $commentSkill -Value ($originalSkill.Replace('code-comments.md', 'execution-contract.md')) -Encoding utf8
    Assert-Condition (-not (Invoke-CopiedValidator)) "Validation accepted missing comment-contract routing in $skillName."
    Copy-Item -LiteralPath (Join-Path $root "skills/$skillName/SKILL.md") -Destination $commentSkill -Force
  }

  $invalidAgent = Join-Path $testRoot 'agents\team-architect.toml'
  # Scenario: remove the comment contract. Expected: reject, then pass after restoration.
  $commentReference = Join-Path $testRoot 'skills/team-core/references/code-comments.md'
  Remove-Item -LiteralPath $commentReference -Force
  Assert-Condition (-not (Invoke-CopiedValidator)) 'Validation accepted a missing code-comment contract.'
  Copy-Item -LiteralPath (Join-Path $root 'skills/team-core/references/code-comments.md') -Destination $commentReference -Force
  Assert-Condition (Invoke-CopiedValidator) 'Validation did not recover after restoring comment routing and the contract.'

  # Scenario: add an unsupported TOML field. Expected: validation rejects it.
  Add-Content -LiteralPath $invalidAgent -Value 'unsupported = "value"' -Encoding utf8
  Assert-Condition (-not (Invoke-CopiedValidator)) 'Validation accepted an unsupported TOML field.'
  Copy-Item -LiteralPath (Join-Path $root 'agents\team-architect.toml') -Destination $invalidAgent -Force

  $skillPath = Join-Path $testRoot 'skills\team-dev\SKILL.md'
  # Scenario: introduce a broken local link. Expected: reject the package.
  Add-Content -LiteralPath $skillPath -Value '[broken link](missing-local-reference.md)' -Encoding utf8
  Assert-Condition (-not (Invoke-CopiedValidator)) 'Validation accepted a missing local Markdown reference.'

  Copy-Item -LiteralPath (Join-Path $root 'skills\team-dev\SKILL.md') -Destination $skillPath -Force
  # Scenario: remove TDD guidance. Expected: the existing contract remains enforced.
  Remove-Item -LiteralPath (Join-Path $testRoot 'skills\team-core\references\tdd-protocol.md') -Force
  Assert-Condition (-not (Invoke-CopiedValidator)) 'Validation accepted a missing TDD protocol reference.'

  Write-Host 'Validation tests passed.'
} finally {
  $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
  $resolvedParent = [System.IO.Path]::GetFullPath((Split-Path -Parent $resolvedTestRoot)).TrimEnd([char]'\', [char]'/' )
  $normalizedTemporaryParent = $temporaryParent.TrimEnd([char]'\', [char]'/' )
  if ($resolvedParent -ne $normalizedTemporaryParent -or -not ([System.IO.Path]::GetFileName($resolvedTestRoot).StartsWith('codex-multi-agent-validate-test-'))) {
    throw "Refusing to clean unexpected test path: $resolvedTestRoot"
  }
  if (Test-Path -LiteralPath $resolvedTestRoot) {
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction Stop
  }
  Assert-Condition (-not (Test-Path -LiteralPath $resolvedTestRoot)) "Test cleanup left an unexpected directory: $resolvedTestRoot"
  Write-Host 'Isolated validation directory removed.'
}
