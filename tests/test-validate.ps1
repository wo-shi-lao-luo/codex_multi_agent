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
  foreach ($item in 'agents', 'skills', 'scripts', 'VERSION') {
    Copy-Item -LiteralPath (Join-Path $root $item) -Destination $testRoot -Recurse -Force -ErrorAction Stop
  }

  Assert-Condition (Invoke-CopiedValidator) 'Baseline validation failed in an isolated package copy.'

  $invalidAgent = Join-Path $testRoot 'agents\team-architect.toml'
  Add-Content -LiteralPath $invalidAgent -Value 'unsupported = "value"' -Encoding utf8
  Assert-Condition (-not (Invoke-CopiedValidator)) 'Validation accepted an unsupported TOML field.'
  Copy-Item -LiteralPath (Join-Path $root 'agents\team-architect.toml') -Destination $invalidAgent -Force

  $skillPath = Join-Path $testRoot 'skills\team-dev\SKILL.md'
  Add-Content -LiteralPath $skillPath -Value '[broken link](missing-local-reference.md)' -Encoding utf8
  Assert-Condition (-not (Invoke-CopiedValidator)) 'Validation accepted a missing local Markdown reference.'

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
