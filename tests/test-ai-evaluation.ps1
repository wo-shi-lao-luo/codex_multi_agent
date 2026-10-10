# Verify AI evaluation resource/profile discovery at the package validator CLI.
# This is structural evidence, not an AI evaluation engine or native role test.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/package-test.ps1')
$root = Split-Path -Parent $PSScriptRoot
$shell = (Get-Process -Id $PID).Path
$temporaryParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $temporaryParent (
  'codex-multi-agent-ai-evaluation-test-' + [guid]::NewGuid().ToString('N')
)
$resources = @(
  'agents/team-ai-tester.toml'
  'skills/ai-testing-engineering/SKILL.md'
  'skills/ai-testing-engineering/agents/openai.yaml'
  'skills/team-core/references/ai-evaluation.md'
)
$routes = @(
  @{ path = 'skills/team-core/SKILL.md'; target = 'references/ai-evaluation.md' }
  @{
    path = 'skills/ai-testing-engineering/SKILL.md'
    target = '../team-core/references/ai-evaluation.md'
  }
  @{
    path = 'skills/ai-engineering/SKILL.md'
    target = '../team-core/references/ai-evaluation.md'
  }
  @{
    path = 'skills/testing-engineering/SKILL.md'
    target = '../team-core/references/ai-evaluation.md'
  }
  @{
    path = 'skills/team-ai-simulate/SKILL.md'
    target = '../team-core/references/ai-evaluation.md'
  }
  @{ path = 'skills/team-core/references/execution-contract.md'; target = 'ai-evaluation.md' }
  @{ path = 'skills/team-core/references/test-acceptance-contract.md'; target = 'ai-evaluation.md' }
  @{ path = 'skills/team-core/references/role-routing.md'; target = 'ai-evaluation.md' }
)

function Assert-Condition {
  # Stop with the violated observable expectation; do not silently repair fixtures.
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Invoke-Validation {
  # Observe the copied CLI exit and retain both output streams for diagnostics.
  $result = Invoke-TestProcess -FilePath $shell -ArgumentList @(
    '-NoProfile', '-File', (Join-Path $testRoot 'scripts/validate.ps1')
  )
  return [pscustomobject]@{
    Passed = ($result.Exit -eq 0)
    Output = ($result.Out + $result.Error)
  }
}

function Get-Fingerprint {
  # Relative names and complete hashes detect content changes, additions and deletions.
  return Get-TestFingerprint -Root $testRoot
}

try {
  Copy-TestPackage -SourceRoot $root -DestinationRoot $testRoot `
    -Profile PublicDocs -IncludeConfig $true

  # Scenario AE-01: finalized source includes the new approved AI Tester profile.
  # Expected: admit complete source, retain ordinary Tester and mutate no inputs.
  foreach ($relative in $resources + @('agents/team-tester.toml')) {
    Assert-Condition (Test-Path -LiteralPath (Join-Path $testRoot $relative) -PathType Leaf) (
      "Missing finalized fixture resource: $relative"
    )
  }
  $before = Get-Fingerprint
  $baseline = Invoke-Validation
  Assert-Condition $baseline.Passed "Complete evaluation package rejected: $($baseline.Output)"
  Assert-Condition ((Get-Fingerprint) -eq $before) 'Validator mutated complete source.'

  # Scenario AE-02: intended evaluation link disappears but replacement resolves.
  # Expected: reject each identifiable lost route with its own discovery diagnostic.
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
      Set-Content -LiteralPath $path -Value (
        $content.Replace($anchor, "]($replacement)")
      ) -Encoding utf8
      $result = Invoke-Validation
      $diagnostic = "$($route.path) must link to $($route.target)"
      Assert-Condition (-not $result.Passed) "Validator accepted lost route: $diagnostic"
      Assert-Condition ($result.Output.Contains($diagnostic)) (
        "Lost-route diagnostic missing: $($result.Output)"
      )
    } finally {
      [IO.File]::WriteAllBytes($path, $original)
    }
    Write-Host "Rejected lost evaluation route: $($route.path)"
  }

  # Scenario AE-02: a required role, Skill, metadata or shared reference is absent.
  # Expected: reject each omission with an explicit evaluation-resource diagnostic.
  foreach ($relative in $resources) {
    $path = Join-Path $testRoot $relative
    $original = [IO.File]::ReadAllBytes($path)
    try {
      Remove-Item -LiteralPath $path
      $result = Invoke-Validation
      Assert-Condition (-not $result.Passed) "Validator accepted missing resource: $relative"
      Assert-Condition ($result.Output.Contains("Missing AI evaluation resource: $relative")) (
        "Resource diagnostic missing: $($result.Output)"
      )
    } finally {
      [IO.File]::WriteAllBytes($path, $original)
    }
    Write-Host "Rejected missing evaluation resource: $relative"
  }

  # Scenario AE-02: role exists but routes to ordinary rather than AI evaluation.
  # Expected: reject the lost AI Skill route without interpreting prose quality.
  $profilePath = Join-Path $testRoot 'agents/team-ai-tester.toml'
  $profileBytes = [IO.File]::ReadAllBytes($profilePath)
  try {
    $content = Get-Content -LiteralPath $profilePath -Raw
    Assert-Condition ($content.Contains('ai-testing-engineering')) 'Missing role route anchor.'
    Set-Content -LiteralPath $profilePath -Value (
      $content.Replace('ai-testing-engineering', 'testing-engineering')
    ) -Encoding utf8
    $result = Invoke-Validation
    Assert-Condition (-not $result.Passed) 'Validator accepted lost AI Tester Skill route.'
    Assert-Condition ($result.Output.Contains(
      'team-ai-tester must route to ai-testing-engineering'
    )) "Role route diagnostic missing: $($result.Output)"
  } finally {
    [IO.File]::WriteAllBytes($profilePath, $profileBytes)
  }

  # Scenario AE-03: new AI Tester model/effort drifts from the approved profile.
  # Expected: reject both substitutions; restored new and existing profiles pass.
  foreach ($mutation in @(
    @{ before = 'model = "gpt-6.1-sol"'; after = 'model = "gpt-6-luna"' }
    @{ before = 'model_reasoning_effort = "medium"'; after = 'model_reasoning_effort = "low"' }
  )) {
    try {
      $content = Get-Content -LiteralPath $profilePath -Raw
      Assert-Condition ($content.Contains($mutation.before)) 'Missing profile fixture anchor.'
      Set-Content -LiteralPath $profilePath -Value (
        $content.Replace($mutation.before, $mutation.after)
      ) -Encoding utf8
      $result = Invoke-Validation
      Assert-Condition (-not $result.Passed) 'Validator accepted unsupported AI Tester profile.'
      Assert-Condition ($result.Output.Contains(
        'team-ai-tester.toml does not match the required model profile'
      )) "Profile diagnostic missing: $($result.Output)"
    } finally {
      [IO.File]::WriteAllBytes($profilePath, $profileBytes)
    }
  }

  # Scenario AE-01/AE-04: all rejected mutations are byte-exactly restored.
  # Expected: valid source passes again; ordinary Tester and old routes unchanged.
  $restored = Invoke-Validation
  Assert-Condition $restored.Passed "Restored evaluation source rejected: $($restored.Output)"
  Assert-Condition ((Get-Fingerprint) -eq $before) 'Fixture was not fully restored.'
  Write-Host 'AI evaluation distribution/profile/routing tests passed.'
} finally {
  # Scenario: success or failure must not leave owned temporary package copies.
  # Expected: validate exact OS-temp child/prefix before deletion; fixture absent.
  $resolvedRoot = [IO.Path]::GetFullPath($testRoot)
  try {
    Remove-TestSandbox -Path $testRoot -Prefix 'codex-multi-agent-ai-evaluation-test-'
  } catch {
    throw "Refusing cleanup outside owned fixture: $resolvedRoot. $($_.Exception.Message)"
  }
  Assert-Condition (-not (Test-Path -LiteralPath $resolvedRoot)) 'Fixture cleanup failed.'
  Write-Host 'Isolated AI evaluation directory removed.'
}
