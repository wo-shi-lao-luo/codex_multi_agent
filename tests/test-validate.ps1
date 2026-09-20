[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$temporaryParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRootName = "codex-multi-agent-validate-test-" + [Guid]::NewGuid().ToString('N')
$testRoot = Join-Path $temporaryParent $testRootName
$validator = Join-Path $testRoot 'scripts\validate.ps1'

function Assert-Condition {
  param([Parameter(Mandatory = $true)][bool]$Condition, [Parameter(Mandatory = $true)][string]$Message)
  if (-not $Condition) { throw $Message }
}

function Invoke-CopiedValidator {
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

  Assert-Condition (Invoke-CopiedValidator) 'Baseline validation failed in an isolated package copy.'

  # Keep links valid while removing the required route: generic link checks
  # alone must not let a writer or reviewer silently lose this contract.
  foreach ($skillName in 'team-core', 'team-dev', 'team-review', 'code-review', 'frontend-engineering', 'backend-engineering', 'database-engineering', 'testing-engineering') {
    $commentSkill = Join-Path $testRoot "skills/$skillName/SKILL.md"
    $originalSkill = Get-Content -LiteralPath $commentSkill -Raw
    Set-Content -LiteralPath $commentSkill -Value ($originalSkill.Replace('code-comments.md', 'execution-contract.md')) -Encoding utf8
    Assert-Condition (-not (Invoke-CopiedValidator)) "Validation accepted missing comment-contract routing in $skillName."
    Copy-Item -LiteralPath (Join-Path $root "skills/$skillName/SKILL.md") -Destination $commentSkill -Force
  }

  $invalidAgent = Join-Path $testRoot 'agents\team-architect.toml'
  $commentReference = Join-Path $testRoot 'skills/team-core/references/code-comments.md'
  Remove-Item -LiteralPath $commentReference -Force
  Assert-Condition (-not (Invoke-CopiedValidator)) 'Validation accepted a missing code-comment contract.'
  Copy-Item -LiteralPath (Join-Path $root 'skills/team-core/references/code-comments.md') -Destination $commentReference -Force
  Assert-Condition (Invoke-CopiedValidator) 'Validation did not recover after restoring comment routing and the contract.'

  Add-Content -LiteralPath $invalidAgent -Value 'unsupported = "value"' -Encoding utf8
  Assert-Condition (-not (Invoke-CopiedValidator)) 'Validation accepted an unsupported TOML field.'
  Copy-Item -LiteralPath (Join-Path $root 'agents\team-architect.toml') -Destination $invalidAgent -Force

  $skillPath = Join-Path $testRoot 'skills\team-dev\SKILL.md'
  Add-Content -LiteralPath $skillPath -Value '[broken link](missing-local-reference.md)' -Encoding utf8
  Assert-Condition (-not (Invoke-CopiedValidator)) 'Validation accepted a missing local Markdown reference.'

  Copy-Item -LiteralPath (Join-Path $root 'skills\team-dev\SKILL.md') -Destination $skillPath -Force
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
