# Test optional scientist package contracts through actual isolated entrypoints.
# Source instruction semantics and native role loading require separate manual evidence.
#requires -Version 7.0
[CmdletBinding()]
param([switch]$RedOnly, [switch]$DeliveryOnly)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/package-test.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$payload = @(
  'agents/team-data-scientist.toml',
  'skills/data-science/SKILL.md',
  'skills/data-science/agents/openai.yaml',
  'skills/data-science/references/data-preparation.md',
  'skills/data-science/references/model-development.md',
  'skills/data-science/references/time-series.md'
)

# Stop immediately with a stable case identity on any unexpected observable outcome.
function Assert-Scientist([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

# DS-01: before production the additive payload is unavailable.
# Expected: fail at the actual missing identity without creating fixtures.
foreach ($relative in $payload) {
  Assert-Scientist (Test-Path -LiteralPath (Join-Path $repo $relative) -PathType Leaf) (
    "DS-01 missing payload: $relative"
  )
}
if ($RedOnly) { Write-Output 'DS-01 payload discovery passed.'; exit 0 }

$sandbox = Join-Path (Get-TestTemporaryParent) (
  'codex-data-science-test-' + [guid]::NewGuid().ToString('N')
)
$package = Join-Path $sandbox 'package'
$shell = (Get-Process -Id $PID).Path

# Execute only explicit copied entrypoints; capture real exit and both output pipes.
function Invoke-ScientistScript([string]$Relative, [string[]]$Arguments = @()) {
  Invoke-TestProcess -FilePath $shell -ArgumentList (
    @('-NoProfile', '-File', (Join-Path $package $Relative)) + $Arguments
  )
}

try {
  Copy-TestPackage -SourceRoot $repo -DestinationRoot $package `
    -Profile PublicDocs -IncludeConfig $true
  $before = Get-TestFingerprint -Root $package

  # DS-02 intact source: supported role metadata and complete routes/resources.
  # Expected: actual validator accepts the package without writing any source file.
  $profile = Get-Content (Join-Path $package $payload[0]) -Raw
  foreach ($setting in @(
    'model = "gpt-6.1-sol"', 'model_reasoning_effort = "high"',
    'sandbox_mode = "workspace-write"'
  )) {
    Assert-Scientist ($profile.Contains($setting)) "DS-02 incorrect profile: $setting"
  }
  $valid = Invoke-ScientistScript 'scripts/validate.ps1'
  Assert-Scientist ($valid.Exit -eq 0) "DS-02 baseline rejected: $($valid.Out) $($valid.Error)"
  Assert-Scientist ((Get-TestFingerprint $package) -ceq $before) 'DS-02 validator mutated source.'

  # A targeted delivery retest reuses separate recorded mutation evidence; no omitted case is a pass.
  if (-not $DeliveryOnly) {
    # DS-02 missing payload: each optional role's required distributable file disappears.
    # Expected: validator rejects every omission and accepts exact restoration.
    foreach ($relative in $payload) {
      $path = Join-Path $package $relative
      Remove-Item -LiteralPath $path -Force
      $rejected = Invoke-ScientistScript 'scripts/validate.ps1'
      Assert-Scientist ($rejected.Exit -ne 0) "DS-02 omission accepted: $relative"
      Copy-Item -LiteralPath (Join-Path $repo $relative) -Destination $path
      $restored = Invoke-ScientistScript 'scripts/validate.ps1'
      Assert-Scientist ($restored.Exit -eq 0) "DS-02 restore rejected: $relative"
    }

    # DS-02 corrupt profile: supported model/effort and Skill route must be enforced.
    # Expected: each independently invalid profile rejects; exact bytes restore success.
    $profilePath = Join-Path $package $payload[0]
    foreach ($mutation in @(
      @{from='gpt-6.1-sol'; to='unsupported-data-model'},
      @{from='model_reasoning_effort = "high"'; to='model_reasoning_effort = "low"'},
      @{from='sandbox_mode = "workspace-write"'; to='sandbox_mode = "read-only"'},
      @{from='data-science'; to='backend-engineering'}
    )) {
      $changed = $profile.Replace($mutation.from, $mutation.to)
      Assert-Scientist ($changed -cne $profile) 'DS-02 invalid mutation fixture.'
      Set-Content -LiteralPath $profilePath -Value $changed -Encoding utf8
      $rejected = Invoke-ScientistScript 'scripts/validate.ps1'
      Assert-Scientist ($rejected.Exit -ne 0) "DS-02 corrupt profile accepted: $($mutation.from)"
      Copy-Item -LiteralPath (Join-Path $repo $payload[0]) -Destination $profilePath -Force
    }
    $restored = Invoke-ScientistScript 'scripts/validate.ps1'
    Assert-Scientist ($restored.Exit -eq 0) 'DS-02 restored profile rejected.'

    # DS-02 valid-but-wrong links: generic link existence cannot enforce required routing.
    # Expected: redirecting any conditional reference or role route to another real file rejects.
    foreach ($route in @(
      @{path='skills/data-science/SKILL.md'; from='references/data-preparation.md'; to='../team-core/references/execution-contract.md'},
      @{path='skills/data-science/SKILL.md'; from='references/model-development.md'; to='../team-core/references/execution-contract.md'},
      @{path='skills/data-science/SKILL.md'; from='references/time-series.md'; to='../team-core/references/execution-contract.md'},
      @{path='skills/team-core/references/role-routing.md'; from='../../data-science/SKILL.md'; to='../../backend-engineering/SKILL.md'}
    )) {
      $routePath = Join-Path $package $route.path
      $original = Get-Content -LiteralPath $routePath -Raw
      $pattern = '\[[^\]]+\]\(' + [regex]::Escape($route.from) + '\)'
      Assert-Scientist ($original -match $pattern) "DS-02 missing baseline link: $($route.from)"
      $changed = [regex]::Replace($original, $pattern, "[valid unrelated route]($($route.to))")
      Set-Content -LiteralPath $routePath -Value $changed -Encoding utf8
      $rejected = Invoke-ScientistScript 'scripts/validate.ps1'
      Assert-Scientist ($rejected.Exit -ne 0) "DS-02 wrong route accepted: $($route.from)"
      Copy-Item -LiteralPath (Join-Path $repo $route.path) -Destination $routePath -Force
    }
    $restored = Invoke-ScientistScript 'scripts/validate.ps1'
    Assert-Scientist ($restored.Exit -eq 0) 'DS-02 restored links rejected.'
  }

  $codex = Join-Path $sandbox 'fake-codex'
  $agents = Join-Path $sandbox 'fake-agents'
  $targets = @('-CodexHome', $codex, '-AgentsHome', $agents)
  # DS-03 preview: fresh explicit fake homes stay absent.
  # Expected: successful real preview creates neither target.
  $preview = Invoke-ScientistScript 'scripts/install-user.ps1' ($targets + '-WhatIf')
  Assert-Scientist ($preview.Exit -eq 0) 'DS-03 preview failed.'
  Assert-Scientist (-not (Test-Path $codex) -and -not (Test-Path $agents)) (
    'DS-03 preview created fake homes.'
  )

  # DS-03 full delivery: generic installer must include role, Skill and all refs.
  # Expected: byte-identical installed files, each recorded once in receipt; no source changes.
  $install = Invoke-ScientistScript 'scripts/install-user.ps1' $targets
  Assert-Scientist ($install.Exit -eq 0) "DS-03 install failed: $($install.Out) $($install.Error)"
  $receipt = Get-Content (Join-Path $agents 'codex-multi-agent/install-receipt.json') -Raw |
    ConvertFrom-Json
  foreach ($relative in $payload) {
    $targetRoot = if ($relative.StartsWith('agents/')) { $codex } else { $agents }
    $target = Join-Path $targetRoot $relative
    Assert-Scientist (Test-Path -LiteralPath $target -PathType Leaf) "DS-03 omitted $relative"
    Assert-Scientist ((Get-FileHash $target).Hash -ceq
      (Get-FileHash (Join-Path $package $relative)).Hash) "DS-03 changed bytes: $relative"
    Assert-Scientist (@($receipt.files | Where-Object path -eq $target).Count -eq 1) (
      "DS-03 receipt omitted/duplicated $relative"
    )
  }
  Assert-Scientist ((Get-TestFingerprint $package) -ceq $before) 'DS-03 source changed.'
  if ($DeliveryOnly) {
    Write-Output 'DS-01 + intact DS-02 + DS-03 delivery checks passed; mutation cases skipped.'
  } else {
    Write-Output 'DS-01/02/03 optional data scientist package checks passed.'
  }
} finally {
  # Refuse anything except this invocation's direct OS-temp GUID sandbox.
  Remove-TestSandbox -Path $sandbox -Prefix 'codex-data-science-test-'
  Assert-Scientist (-not (Test-Path -LiteralPath $sandbox)) 'DS-03 cleanup failed.'
  Write-Output 'Owned data-science fixture removed.'
}
