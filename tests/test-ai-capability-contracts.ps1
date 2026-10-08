# Exercise instruction distribution/discovery at the actual validator CLI boundary.
# These tests do not prove native Agent behavior or execute a product AI runtime.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$shell = (Get-Process -Id $PID).Path
$temporaryParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $temporaryParent (
  'codex-multi-agent-ai-contract-test-' + [guid]::NewGuid().ToString('N')
)
$payload = @(
  'skills/team-core/references/ai-capability-contract.md'
  'skills/team-core/references/ai-record-replay-testing.md'
  'skills/team-core/templates/ai-capability/contract-brief.md'
  'skills/team-core/templates/ai-capability/record-replay-plan.md'
)
$routes = @(
  @{ path = 'skills/team-core/SKILL.md'; target = 'references/ai-capability-contract.md' }
  @{ path = 'skills/team-core/SKILL.md'; target = 'references/ai-record-replay-testing.md' }
  @{
    path = 'skills/ai-engineering/SKILL.md'
    target = '../team-core/references/ai-capability-contract.md'
  }
  @{
    path = 'skills/testing-engineering/SKILL.md'
    target = '../team-core/references/ai-record-replay-testing.md'
  }
  @{
    path = 'skills/backend-engineering/SKILL.md'
    target = '../team-core/references/ai-capability-contract.md'
  }
  @{
    path = 'skills/team-core/references/test-acceptance-contract.md'
    target = 'ai-record-replay-testing.md'
  }
  @{
    path = 'skills/team-core/references/ai-capability-contract.md'
    target = '../templates/ai-capability/contract-brief.md'
  }
  @{
    path = 'skills/team-core/references/ai-record-replay-testing.md'
    target = '../templates/ai-capability/record-replay-plan.md'
  }
)

function Assert-Condition {
  # Stop with the violated observable expectation; no implicit repair/retry.
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Invoke-Validation {
  # Run the copied validator in a child process and retain its real exit/output.
  $validator = Join-Path $testRoot 'scripts/validate.ps1'
  $output = & $shell -NoProfile -File $validator 2>&1
  return [pscustomobject]@{
    Passed = ($LASTEXITCODE -eq 0)
    Output = ($output -join "`n")
  }
}

function Get-Fingerprint {
  # Relative names and hashes detect changed content, added files and deletions.
  return ((Get-ChildItem -LiteralPath $testRoot -File -Recurse | ForEach-Object {
    $relative = [IO.Path]::GetRelativePath($testRoot, $_.FullName)
    "$relative|$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
  } | Sort-Object) -join "`n")
}

try {
  New-Item -ItemType Directory -Path $testRoot | Out-Null
  foreach ($directory in @('agents', 'skills', 'scripts', 'config')) {
    Copy-Item -LiteralPath (Join-Path $root $directory) -Destination $testRoot -Recurse
  }
  # Public docs participate in the existing whole-package Markdown link check.
  # Exclude local governance/history data rather than copying user runtime records.
  $docsRoot = Join-Path $root 'docs'
  foreach ($document in Get-ChildItem -LiteralPath $docsRoot -File -Recurse) {
    $relative = [IO.Path]::GetRelativePath($docsRoot, $document.FullName) -replace '\\', '/'
    if ($relative -match '^(governance|superpowers)/') { continue }
    $destination = Join-Path $testRoot "docs/$relative"
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $document.FullName -Destination $destination
  }
  Copy-Item -LiteralPath (Join-Path $root 'VERSION') -Destination $testRoot
  foreach ($document in Get-ChildItem -LiteralPath $root -Filter '*.md' -File) {
    Copy-Item -LiteralPath $document.FullName -Destination $testRoot
  }

  # Scenario AC-01/AC-04: finalized package has all required payload and routes.
  # Expected: accept the copied source without changing any copied file.
  foreach ($relative in $payload) {
    Assert-Condition (Test-Path -LiteralPath (Join-Path $testRoot $relative) -PathType Leaf) (
      "Missing finalized fixture payload: $relative"
    )
  }
  $before = Get-Fingerprint
  $baseline = Invoke-Validation
  Assert-Condition $baseline.Passed "Complete package rejected: $($baseline.Output)"
  Assert-Condition ((Get-Fingerprint) -eq $before) 'Validator mutated a valid package.'

  # Scenario AC-03: every resource remains, but a required entry link is lost.
  # Expected: reject each lost route even though its replacement link resolves.
  foreach ($route in $routes) {
    $path = Join-Path $testRoot $route.path
    $original = [IO.File]::ReadAllBytes($path)
    try {
      $content = Get-Content -LiteralPath $path -Raw
      $anchor = "]($($route.target))"
      Assert-Condition ($content.Contains($anchor)) "Missing route fixture anchor: $anchor"
      $replacement = if ($route.path -eq 'skills/team-core/SKILL.md') {
        'references/execution-contract.md'
      } elseif ($route.path.EndsWith('/SKILL.md')) {
        '../team-core/references/execution-contract.md'
      } else {
        'execution-contract.md'
      }
      # Fixture mutation only: production source and meaningful payload stay intact.
      Set-Content -LiteralPath $path -Value (
        $content.Replace($anchor, "]($replacement)")
      ) -Encoding utf8
      $result = Invoke-Validation
      $diagnostic = "$($route.path) must link to $($route.target)"
      Assert-Condition (-not $result.Passed) "Validator accepted lost route: $diagnostic"
      Assert-Condition ($result.Output.Contains($diagnostic)) (
        "Lost-route failure omitted expected diagnostic: $($result.Output)"
      )
    } finally {
      [IO.File]::WriteAllBytes($path, $original)
    }
    Write-Host "Rejected lost route: $($route.path) -> $($route.target)"
  }

  # Scenario AC-02: one required packaged reference/template is absent.
  # Expected: explicit missing-resource failure for every resource, not success.
  foreach ($relative in $payload) {
    $path = Join-Path $testRoot $relative
    $original = [IO.File]::ReadAllBytes($path)
    try {
      Remove-Item -LiteralPath $path
      $result = Invoke-Validation
      Assert-Condition (-not $result.Passed) "Validator accepted missing payload: $relative"
      Assert-Condition ($result.Output.Contains("Missing AI capability resource: $relative")) (
        "Missing-resource failure omitted expected diagnostic: $($result.Output)"
      )
    } finally {
      [IO.File]::WriteAllBytes($path, $original)
    }
    Write-Host "Rejected missing resource: $relative"
  }

  # Scenario AC-04: rejected fixture mutations have been restored byte-for-byte.
  # Expected: restored package validates and its fingerprint equals the baseline.
  $restored = Invoke-Validation
  Assert-Condition $restored.Passed "Restored package rejected: $($restored.Output)"
  Assert-Condition ((Get-Fingerprint) -eq $before) 'Mutations were not fully restored.'
  Write-Host 'AI capability contract distribution/routing tests passed.'
} finally {
  # Scenario: successful or failed tests leave only owned disposable fixture data.
  # Expected: validate exact OS-temp child/prefix before deletion; no fixture remains.
  $resolvedRoot = [IO.Path]::GetFullPath($testRoot)
  $resolvedParent = [IO.Path]::GetFullPath((Split-Path -Parent $resolvedRoot))
  if ($resolvedParent.TrimEnd([char]'\', [char]'/') -ne
      $temporaryParent.TrimEnd([char]'\', [char]'/') -or
      -not [IO.Path]::GetFileName($resolvedRoot).StartsWith(
        'codex-multi-agent-ai-contract-test-'
      )) {
    throw "Refusing cleanup outside owned test directory: $resolvedRoot"
  }
  if (Test-Path -LiteralPath $resolvedRoot) {
    Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
  }
  Assert-Condition (-not (Test-Path -LiteralPath $resolvedRoot)) 'Fixture cleanup failed.'
  Write-Host 'Isolated AI contract test directory removed.'
}
