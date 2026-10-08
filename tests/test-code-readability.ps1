# Check readability package discovery and real validator rejection in isolated copies.
# This proves source distribution, never native Agent behavior or semantic correctness.
[CmdletBinding()]
param([switch]$SourceOnly)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$assets = @(
  'agents/team-code-maintainer.toml',
  'skills/team-code-maintain/SKILL.md',
  'skills/team-code-maintain/agents/openai.yaml',
  'skills/team-core/references/code-readability.md'
)
function Assert-Condition([bool]$Condition, [string]$Message) {
  # Fail at the observed boundary; callers supply scenario-specific diagnostics.
  if (-not $Condition) { throw $Message }
}
# CR-01: a source package must distribute the role, Skill metadata and shared reference.
# Expected: each asset is nonempty strict UTF-8; absent assets fail before installation.
foreach ($relative in $assets) {
  $path = Join-Path $root $relative
  Assert-Condition (Test-Path -LiteralPath $path -PathType Leaf) "CR-01 missing resource: $relative"
  $content = [Text.UTF8Encoding]::new($false, $true).GetString([IO.File]::ReadAllBytes($path))
  Assert-Condition (-not [string]::IsNullOrWhiteSpace($content)) "CR-01 empty resource: $relative"
}
if ($SourceOnly) { Write-Output 'CR-01 source payload passed; native behavior not tested.'; return }
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testRoot = Join-Path $tempParent ('codex-readability-test-' + [guid]::NewGuid().ToString('N'))
$validator = Join-Path $testRoot 'scripts/validate.ps1'
function Invoke-Validator {
  # Run the actual copied package boundary and restore caller preferences/exit state.
  $priorPreference = $ErrorActionPreference
  $priorExit = $global:LASTEXITCODE
  try {
    $ErrorActionPreference = 'Continue'
    $global:LASTEXITCODE = 0
    & $validator 2>&1 | Out-Null
    return ($global:LASTEXITCODE -eq 0)
  } finally {
    $ErrorActionPreference = $priorPreference
    $global:LASTEXITCODE = $priorExit
  }
}
try {
  New-Item -ItemType Directory -Path $testRoot | Out-Null
  foreach ($item in 'agents', 'skills', 'scripts', 'VERSION', 'CHANGELOG.md', 'CHANGELOG.zh-CN.md') {
    Copy-Item -LiteralPath (Join-Path $root $item) -Destination $testRoot -Recurse -Force
  }
  # CR-02 fixture completeness: release history links the real formatter guide and packet.
  # Expected: preserve these exact source documents/paths rather than weakening link checks.
  foreach ($relative in @('docs/formatter-tool.md', 'docs/verification/active/formatter-tool.md')) {
    $destination = Join-Path $testRoot $relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
    Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $destination
  }
  # CR-02 happy: intact approved source. Expected: actual validator accepts the package.
  Assert-Condition (Invoke-Validator) 'CR-02 intact readability package rejected.'
  # CR-02 edge: each required resource is omitted. Expected: reject and recover on restoration.
  foreach ($relative in $assets) {
    $path = Join-Path $testRoot $relative
    Remove-Item -LiteralPath $path -Force
    Assert-Condition (-not (Invoke-Validator)) "CR-02 accepted missing resource: $relative"
    Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $path -Force
    Assert-Condition (Invoke-Validator) "CR-02 restoration rejected: $relative"
  }
  # CR-02 edge: direct discovery route becomes unlinked prose.
  # Expected: existing Markdown targets elsewhere cannot hide this missing specific route.
  foreach ($route in @(
    @{ path = 'skills/team-core/SKILL.md'; target = 'references/code-readability.md' },
    @{ path = 'skills/team-code-maintain/SKILL.md'; target = '../team-core/references/code-readability.md' },
    @{ path = 'skills/team-dev/SKILL.md'; target = '../team-core/references/code-readability.md' },
    @{ path = 'skills/team-review/SKILL.md'; target = '../team-core/references/code-readability.md' },
    @{ path = 'skills/code-review/SKILL.md'; target = '../team-core/references/code-readability.md' },
    @{ path = 'skills/frontend-engineering/SKILL.md'; target = '../team-core/references/code-readability.md' },
    @{ path = 'skills/backend-engineering/SKILL.md'; target = '../team-core/references/code-readability.md' },
    @{ path = 'skills/database-engineering/SKILL.md'; target = '../team-core/references/code-readability.md' },
    @{ path = 'skills/ai-engineering/SKILL.md'; target = '../team-core/references/code-readability.md' },
    @{ path = 'skills/testing-engineering/SKILL.md'; target = '../team-core/references/code-readability.md' },
    @{ path = 'skills/team-core/references/execution-contract.md'; target = 'code-readability.md' }
  )) {
    $path = Join-Path $testRoot $route.path
    $original = Get-Content -LiteralPath $path -Raw
    $pattern = '\[[^\]]+\]\(' + [regex]::Escape($route.target) + '\)'
    Assert-Condition ($original -match $pattern) "CR-02 missing baseline route: $($route.path)"
    Set-Content -LiteralPath $path -Value ([regex]::Replace($original, $pattern, 'unlinked readability'))
    Assert-Condition (-not (Invoke-Validator)) "CR-02 accepted unlinked route: $($route.path)"
    Copy-Item -LiteralPath (Join-Path $root $route.path) -Destination $path -Force
    Assert-Condition (Invoke-Validator) "CR-02 route restoration rejected: $($route.path)"
  }
  # CR-02 edge: formatting route points at a different otherwise valid role.
  # Expected: a valid table/link elsewhere does not satisfy this workflow-to-owner mapping.
  $routing = Join-Path $testRoot 'skills/team-core/references/role-routing.md'
  $routingText = Get-Content -LiteralPath $routing -Raw
  Assert-Condition ($routingText.Contains('`team-code-maintainer`')) 'CR-02 baseline owner map missing.'
  Set-Content -LiteralPath $routing -Value ($routingText.Replace('`team-code-maintainer`', '`team-tester`'))
  Assert-Condition (-not (Invoke-Validator)) 'CR-02 accepted wrong formatting owner map.'
  Copy-Item -LiteralPath (Join-Path $root 'skills/team-core/references/role-routing.md') -Destination $routing -Force
  Assert-Condition (Invoke-Validator) 'CR-02 owner map restoration rejected.'
  # CR-02 edge: approved role profile or write scope drifts. Expected: reject each drift.
  $role = Join-Path $testRoot $assets[0]
  $roleText = Get-Content -LiteralPath $role -Raw
  foreach ($pair in @(
    @('model = "gpt-6-luna"', 'model = "gpt-6.1-sol"'),
    @('model_reasoning_effort = "medium"', 'model_reasoning_effort = "high"')
  )) {
    Assert-Condition ($roleText.Contains($pair[0])) `
      "CR-02 missing approved role field: $($pair[0])"
    Set-Content -LiteralPath $role -Value ($roleText.Replace($pair[0], $pair[1]))
    Assert-Condition (-not (Invoke-Validator)) "CR-02 accepted role drift: $($pair[1])"
    Copy-Item -LiteralPath (Join-Path $root $assets[0]) -Destination $role -Force
    Assert-Condition (Invoke-Validator) 'CR-02 role restoration rejected.'
  }
  # CR-02 edge: omitted sandbox uses the writable host default, while explicit read-only
  # removes the role's capability. Expected: reject read-only without forcing redundant config.
  $readonlyRole = if ($roleText -match '(?m)^sandbox_mode\s*=') {
    $roleText -replace '(?m)^sandbox_mode\s*=\s*"[^"]*"', 'sandbox_mode = "read-only"'
  } else { $roleText + "`nsandbox_mode = `"read-only`"`n" }
  Set-Content -LiteralPath $role -Value $readonlyRole
  Assert-Condition (-not (Invoke-Validator)) 'CR-02 accepted explicit read-only maintainer.'
  Copy-Item -LiteralPath (Join-Path $root $assets[0]) -Destination $role -Force
  Assert-Condition (Invoke-Validator) 'CR-02 sandbox restoration rejected.'
  # CR-02 edge: natural invocation is disabled, malformed, duplicated or outside policy.
  # Expected: every metadata mutation rejects; restored supported YAML passes.
  $metadata = Join-Path $testRoot $assets[2]
  $metadataText = Get-Content -LiteralPath $metadata -Raw
  Assert-Condition ($metadataText -match '(?m)^\s+allow_implicit_invocation:\s+true\s*$') `
    'CR-02 implicit metadata missing.'
  foreach ($mutation in @(
    ($metadataText -replace 'allow_implicit_invocation:\s+true', 'allow_implicit_invocation: false'),
    '# allow_implicit_invocation: true',
    ($metadataText.Replace('allow_implicit_invocation: true',
      "allow_implicit_invocation: true`n  allow_implicit_invocation: false")),
    ($metadataText.Replace('allow_implicit_invocation: true',
      "allow_implicit_invocation: true`n  allow_implicit_invocation: true")),
    ($metadataText + "`nallow_implicit_invocation: false`n"),
    ($metadataText -replace 'allow_implicit_invocation:\s+true', 'allow_implicit_invocation: "true"')
  )) {
    Set-Content -LiteralPath $metadata -Value $mutation
    Assert-Condition (-not (Invoke-Validator)) 'CR-02 accepted disabled or invalid implicit metadata.'
    Copy-Item -LiteralPath (Join-Path $root $assets[2]) -Destination $metadata -Force
    Assert-Condition (Invoke-Validator) 'CR-02 metadata restoration rejected.'
  }
  Write-Output 'CR-01/CR-02 readability package tests passed; native behavior not tested.'
} finally {
  # Delete only this exact generated child of the OS temp parent; assert no residual fixture.
  $resolved = [IO.Path]::GetFullPath($testRoot)
  Assert-Condition ((Split-Path $resolved -Parent) -eq $tempParent -and
    (Split-Path $resolved -Leaf) -like 'codex-readability-test-*') 'Unsafe readability cleanup path.'
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
  Assert-Condition (-not (Test-Path -LiteralPath $resolved)) 'Readability fixture cleanup failed.'
}
