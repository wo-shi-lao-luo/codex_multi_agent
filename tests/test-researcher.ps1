# Test optional researcher package contracts through actual isolated entrypoints.
# Source instruction semantics and native role loading require separate manual evidence.
#requires -Version 7.0
[CmdletBinding()]
param([switch]$RedOnly, [switch]$DeliveryOnly)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/package-test.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$payload = @(
  'agents/team-researcher.toml',
  'skills/team-core/references/external-research.md'
)

# Stop immediately with a stable case identity on any unexpected observable outcome.
function Assert-Researcher([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

# RS-01: before production the additive payload is unavailable.
# Expected: fail at the actual missing identity without creating fixtures.
foreach ($relative in $payload) {
  Assert-Researcher (Test-Path -LiteralPath (Join-Path $repo $relative) -PathType Leaf) (
    "RS-01 missing payload: $relative"
  )
}
if ($RedOnly) { Write-Output 'RS-01 payload discovery passed.'; exit 0 }

$sandbox = Join-Path (Get-TestTemporaryParent) (
  'codex-researcher-test-' + [guid]::NewGuid().ToString('N')
)
$package = Join-Path $sandbox 'package'
$shell = (Get-Process -Id $PID).Path

# Execute only explicit copied entrypoints; capture real exit and both output pipes.
function Invoke-ResearcherScript([string]$Relative, [string[]]$Arguments = @()) {
  Invoke-TestProcess -FilePath $shell -ArgumentList (
    @('-NoProfile', '-File', (Join-Path $package $Relative)) + $Arguments
  )
}

try {
  Copy-TestPackage -SourceRoot $repo -DestinationRoot $package `
    -Profile PublicDocs -IncludeConfig $true
  $before = Get-TestFingerprint -Root $package

  # RS-02 intact source: supported role metadata and complete routes/resources.
  # Expected: actual validator accepts the package without writing any source file.
  $profile = Get-Content (Join-Path $package $payload[0]) -Raw
  foreach ($setting in @(
    'model = "gpt-6-luna"', 'model_reasoning_effort = "medium"'
  )) {
    Assert-Researcher ($profile.Contains($setting)) "RS-02 incorrect profile: $setting"
  }
  $valid = Invoke-ResearcherScript 'scripts/validate.ps1'
  Assert-Researcher ($valid.Exit -eq 0) "RS-02 baseline rejected: $($valid.Out) $($valid.Error)"
  Assert-Researcher ((Get-TestFingerprint $package) -ceq $before) 'RS-02 validator mutated source.'

  # A targeted delivery retest reuses separate recorded mutation evidence; no omitted case is a pass.
  if (-not $DeliveryOnly) {
    # RS-02 missing payload: each optional role's required distributable file disappears.
    # Expected: validator rejects every omission and accepts exact restoration.
    foreach ($relative in $payload) {
      $path = Join-Path $package $relative
      Remove-Item -LiteralPath $path -Force
      $rejected = Invoke-ResearcherScript 'scripts/validate.ps1'
      Assert-Researcher ($rejected.Exit -ne 0) "RS-02 omission accepted: $relative"
      Copy-Item -LiteralPath (Join-Path $repo $relative) -Destination $path
      $restored = Invoke-ResearcherScript 'scripts/validate.ps1'
      Assert-Researcher ($restored.Exit -eq 0) "RS-02 restore rejected: $relative"
    }

    # RS-02 corrupt profile: supported model/effort and Skill route must be enforced.
    # Expected: each independently invalid profile rejects; exact bytes restore success.
    $profilePath = Join-Path $package $payload[0]
    foreach ($mutation in @(
      @{from='gpt-6-luna'; to='unsupported-data-model'},
      @{from='model_reasoning_effort = "medium"'; to='model_reasoning_effort = "low"'},
      @{from='name = "team-researcher"'; to='name = "unrelated-role"'}
    )) {
      $changed = $profile.Replace($mutation.from, $mutation.to)
      Assert-Researcher ($changed -cne $profile) 'RS-02 invalid mutation fixture.'
      Set-Content -LiteralPath $profilePath -Value $changed -Encoding utf8
      $rejected = Invoke-ResearcherScript 'scripts/validate.ps1'
      Assert-Researcher ($rejected.Exit -ne 0) "RS-02 corrupt profile accepted: $($mutation.from)"
      Copy-Item -LiteralPath (Join-Path $repo $payload[0]) -Destination $profilePath -Force
    }
    $restored = Invoke-ResearcherScript 'scripts/validate.ps1'
    Assert-Researcher ($restored.Exit -eq 0) 'RS-02 restored profile rejected.'
    # RS-02 unsupported parent-policy override: a custom role cannot establish its own sandbox.
    # Expected: both nominally restrictive and permissive override keys reject; restoration passes.
    foreach ($mode in @('read-only', 'workspace-write')) {
      Set-Content -LiteralPath $profilePath -Value ($profile + "`nsandbox_mode = `"$mode`"")
      $rejected = Invoke-ResearcherScript 'scripts/validate.ps1'
      Assert-Researcher ($rejected.Exit -ne 0) "RS-02 sandbox override accepted: $mode"
    }
    Copy-Item -LiteralPath (Join-Path $repo $payload[0]) -Destination $profilePath -Force

    # RS-02 valid but unrelated routes: existence alone cannot preserve research discovery.
    # Expected: replacing either required link with another real target rejects; restoration passes.
    foreach ($route in @(
      @{path='skills/team-core/SKILL.md'; from='references/external-research.md'; to='references/execution-contract.md'},
      @{path='skills/team-core/references/role-routing.md'; from='external-research.md'; to='execution-contract.md'}
    )) {
      $routePath = Join-Path $package $route.path
      $original = Get-Content -LiteralPath $routePath -Raw
      $pattern = '\[[^\]]+\]\(' + [regex]::Escape($route.from) + '\)'
      Assert-Researcher ($original -match $pattern) "RS-02 missing baseline route: $($route.from)"
      $changed = [regex]::Replace($original, $pattern, "[unrelated route]($($route.to))")
      Set-Content -LiteralPath $routePath -Value $changed -Encoding utf8
      $rejected = Invoke-ResearcherScript 'scripts/validate.ps1'
      Assert-Researcher ($rejected.Exit -ne 0) "RS-02 wrong route accepted: $($route.from)"
      Copy-Item -LiteralPath (Join-Path $repo $route.path) -Destination $routePath -Force
    }
    $restored = Invoke-ResearcherScript 'scripts/validate.ps1'
    Assert-Researcher ($restored.Exit -eq 0) 'RS-02 restored sandbox/routes rejected.'

  }

  $codex = Join-Path $sandbox 'fake-codex'
  $agents = Join-Path $sandbox 'fake-agents'
  $targets = @('-CodexHome', $codex, '-AgentsHome', $agents)
  # RS-03 preview: fresh explicit fake homes stay absent.
  # Expected: successful real preview creates neither target.
  $preview = Invoke-ResearcherScript 'scripts/install-user.ps1' ($targets + '-WhatIf')
  Assert-Researcher ($preview.Exit -eq 0) 'RS-03 preview failed.'
  Assert-Researcher (-not (Test-Path $codex) -and -not (Test-Path $agents)) (
    'RS-03 preview created fake homes.'
  )

  # RS-03 full delivery: generic installer must include role and shared reference.
  # Expected: byte-identical installed files, each recorded once in receipt; no source changes.
  $install = Invoke-ResearcherScript 'scripts/install-user.ps1' $targets
  Assert-Researcher ($install.Exit -eq 0) "RS-03 install failed: $($install.Out) $($install.Error)"
  $receipt = Get-Content (Join-Path $agents 'codex-multi-agent/install-receipt.json') -Raw |
    ConvertFrom-Json
  foreach ($relative in $payload) {
    $targetRoot = if ($relative.StartsWith('agents/')) { $codex } else { $agents }
    $target = Join-Path $targetRoot $relative
    Assert-Researcher (Test-Path -LiteralPath $target -PathType Leaf) "RS-03 omitted $relative"
    Assert-Researcher ((Get-FileHash $target).Hash -ceq
      (Get-FileHash (Join-Path $package $relative)).Hash) "RS-03 changed bytes: $relative"
    Assert-Researcher (@($receipt.files | Where-Object path -eq $target).Count -eq 1) (
      "RS-03 receipt omitted/duplicated $relative"
    )
  }
  Assert-Researcher ((Get-TestFingerprint $package) -ceq $before) 'RS-03 source changed.'
  if ($DeliveryOnly) {
    Write-Output 'RS-01 + intact RS-02 + RS-03 delivery checks passed; mutation cases skipped.'
  } else {
    Write-Output 'RS-01/02/03 optional external researcher package checks passed.'
  }
} finally {
  # Refuse anything except this invocation's direct OS-temp GUID sandbox.
  Remove-TestSandbox -Path $sandbox -Prefix 'codex-researcher-test-'
  Assert-Researcher (-not (Test-Path -LiteralPath $sandbox)) 'RS-03 cleanup failed.'
  Write-Output 'Owned researcher fixture removed.'
}
