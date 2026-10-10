# Exercise thin-entry package discovery through the real validator and feedback
# consumer. Source links/metadata prove packaging only, never native routing judgment.
#requires -Version 7.0
[CmdletBinding()]
param(
  [switch]$RedOnly,
  [switch]$AutomaticRedOnly,
  [ValidateSet('Resource', 'Link', 'Policy')][string]$GuardRedCase,
  [switch]$InstallOnly
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$assets = @(
  'skills/team/SKILL.md', 'skills/team/agents/openai.yaml',
  'skills/team-core/references/workflow-routing.md'
)
$entries = @(
  'team-plan', 'team-dev', 'team-debug', 'team-review', 'team-doc-check',
  'team-project-rules', 'team-code-maintain', 'team-delivery-check', 'team-ai-simulate'
)
$routes = @(
  @{ path = $assets[0]; target = '../team-core/references/workflow-routing.md' },
  @{ path = $assets[0]; target = '../team-core/references/execution-contract.md' },
  @{ path = 'skills/team-core/SKILL.md'; target = 'references/workflow-routing.md' },
  @{ path = 'skills/team-core/references/role-routing.md'; target = 'workflow-routing.md' }
)
foreach ($entry in $entries) {
  $routes += @{ path = $assets[2]; target = "../../$entry/SKILL.md" }
}
foreach ($shared in @('repair-loop-guard.md', 'feedback-recording.md', 'role-routing.md')) {
  $routes += @{ path = $assets[2]; target = $shared }
}

function Assert([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

# TE01: the new entry must ship all three assets without retiring direct entries.
# Expected: actual source absence fails before production; synthetic guard mode
# deliberately bypasses only this source check and never becomes payload evidence.
if (-not $GuardRedCase) {
  foreach ($relative in $assets) {
    Assert (Test-Path -LiteralPath (Join-Path $repo $relative) -PathType Leaf) (
      "TE01: missing source asset $relative"
    )
  }
}
foreach ($entry in $entries) {
  Assert (Test-Path -LiteralPath (Join-Path $repo "skills/$entry/SKILL.md") -PathType Leaf) (
    "TE01: existing direct entry missing: $entry"
  )
}
if ($RedOnly) { Write-Output 'TE01 source resources passed.'; exit 0 }

# AUTO01: the approved automatic entry must opt in through actual source metadata.
# Expected: the former explicit-only false value fails before production changes;
# metadata acceptance establishes host eligibility, never native matching behavior.
if (-not $GuardRedCase) {
  $entryPolicy = Get-Content -LiteralPath (Join-Path $repo $assets[1]) -Raw
  Assert ([regex]::Matches($entryPolicy, '(?m)^policy:\s*$').Count -eq 1 -and
    [regex]::Matches($entryPolicy, '(?m)^  allow_implicit_invocation: true\s*$').Count -eq 1) (
    'AUTO01: actual Team entry metadata must enable unique nested implicit invocation.'
  )
}
if ($AutomaticRedOnly) { Write-Output 'AUTO01 automatic source metadata passed.'; exit 0 }

$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$sandbox = Join-Path $tempParent ('codex-team-entry-test-' + [guid]::NewGuid().ToString('N'))
$package = Join-Path $sandbox 'package'
$pwshExe = (Get-Process -Id $PID).Path
$script:validatorChecks = 0

# Run literal argv with independent pipes; no shell expansion or actual user-home
# defaults. The installed wrapper receives explicit fixture paths when used.
function Run-Script([string]$Path, [string[]]$Arguments = @()) {
  $start = [Diagnostics.ProcessStartInfo]::new($pwshExe)
  $start.UseShellExecute = $false
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  $start.Environment['GIT_OPTIONAL_LOCKS'] = '0'
  foreach ($argument in @('-NoProfile', '-File', $Path) + $Arguments) {
    $start.ArgumentList.Add($argument)
  }
  $process = [Diagnostics.Process]::Start($start)
  $stdout = $process.StandardOutput.ReadToEndAsync()
  $stderr = $process.StandardError.ReadToEndAsync()
  $process.WaitForExit()
  $result = [pscustomobject]@{
    Exit = $process.ExitCode
    Out = $stdout.GetAwaiter().GetResult()
    Error = $stderr.GetAwaiter().GetResult()
  }
  $process.Dispose()
  return $result
}

# Writes only owned test data, including synthetic preimplementation candidates.
function Fixture([string]$Relative, [string]$Body) {
  $target = Join-Path $package $Relative
  New-Item -ItemType Directory -Force (Split-Path -Parent $target) | Out-Null
  [IO.File]::WriteAllText($target, $Body, [Text.UTF8Encoding]::new($false))
}

# Controlled package boundary excludes unrelated owners' ignored local work trees.
# Actual source bytes are copied unchanged; formatter guide/packet are validator links.
function Copy-Package {
  New-Item -ItemType Directory -Force $package | Out-Null
  foreach ($item in @('agents', 'skills', 'scripts', 'config', 'VERSION',
    'CHANGELOG.md', 'CHANGELOG.zh-CN.md')) {
    Copy-Item -LiteralPath (Join-Path $repo $item) -Destination $package -Recurse -Force
  }
  foreach ($relative in @('docs/formatter-tool.md', 'docs/verification/active/formatter-tool.md')) {
    $target = Join-Path $package $relative
    New-Item -ItemType Directory -Force (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo $relative) -Destination $target
  }
}

# Invoke the actual copied consumer and retain failure diagnostics. Validator
# read-only behavior is asserted independently from mutation/restoration behavior.
function Validate-Package([bool]$ExpectedValid, [string]$Scenario) {
  $result = Run-Script (Join-Path $package 'scripts/validate.ps1')
  $script:validatorChecks++
  Assert (($result.Exit -eq 0) -eq $ExpectedValid) (
    "$Scenario validator exit $($result.Exit), expected valid=$ExpectedValid. " +
    "$($result.Out) $($result.Error)"
  )
}

# Exact file manifest detects unintended validator writes as well as failed restoration.
function Package-Identity {
  return (@(Get-ChildItem -LiteralPath $package -Recurse -Force -File | ForEach-Object {
    $path = [IO.Path]::GetRelativePath($package, $_.FullName)
    "$path`t$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
  } | Sort-Object -CaseSensitive) -join "`n")
}

try {
  Copy-Package
  if ($GuardRedCase) {
    # TE02 preimplementation: synthetic candidate assets satisfy existing generic
    # package syntax so a missing new guard is observed through the real validator.
    # Expected: intact candidate validates, but the selected damaged contract rejects.
    $candidate = @'
---
name: team
description: Synthetic explicit Team candidate used only to expose missing package guards.
---
# Synthetic Team candidate
## When to activate
Read [execution](../team-core/references/execution-contract.md) only when applicable.
Read [routing](../team-core/references/workflow-routing.md).
## Output contract
This fixture establishes no native behavior or installation acceptance.
'@
    Fixture $assets[0] $candidate
    Fixture $assets[1] "policy:`n  allow_implicit_invocation: true`n"
    $links = @($routes | Where-Object path -eq $assets[2] | ForEach-Object {
      "[Fixture authority]($($_.target))"
    }) -join "`n"
    Fixture $assets[2] ("# Synthetic routing fixture`n" + $links + "`n")
    foreach ($route in $routes | Where-Object { $_.path -ne $assets[0] -and $_.path -ne $assets[2] }) {
      $body = Get-Content -LiteralPath (Join-Path $package $route.path) -Raw
      Fixture $route.path ($body + "`n[Candidate routing]($($route.target))`n")
    }
    Validate-Package $true 'TE02 synthetic intact baseline'
    switch ($GuardRedCase) {
      Resource { Remove-Item -LiteralPath (Join-Path $package $assets[1]) -Force }
      Link {
        $path = 'skills/team-core/SKILL.md'
        $body = Get-Content -LiteralPath (Join-Path $package $path) -Raw
        Fixture $path ($body.Replace('](references/workflow-routing.md)', '](references/role-routing.md)'))
      }
      Policy { Fixture $assets[1] "policy:`n  allow_implicit_invocation: false`n" }
    }
    Validate-Package $false "TE02 preimplementation $GuardRedCase guard"
    Write-Output "TE02 $GuardRedCase guard now rejects synthetic damage."
    exit 0
  }

  $before = Package-Identity
  Validate-Package $true 'TE02 actual intact package'
  Assert ((Package-Identity) -ceq $before) 'TE02 validator mutated intact package.'

  if (-not $InstallOnly) {
    # TE02a: remove each new required asset independently and restore exact bytes.
    # Expected: all omissions reject; later complete restoration validates unchanged.
    foreach ($relative in $assets) {
      $path = Join-Path $package $relative
      $bytes = [IO.File]::ReadAllBytes($path)
      Remove-Item -LiteralPath $path -Force
      Validate-Package $false "TE02a omit $relative"
      [IO.File]::WriteAllBytes($path, $bytes)
    }

    # TE02b: replace only one exact discovery target with a valid unrelated link.
    # Expected: specific-link guards reject each loss even though generic links resolve.
    foreach ($route in $routes) {
      $path = Join-Path $package $route.path
      $bytes = [IO.File]::ReadAllBytes($path)
      $body = [Text.Encoding]::UTF8.GetString($bytes)
      $needle = "]($($route.target))"
      Assert ($body.Contains($needle)) "TE02b missing baseline route: $($route.path) -> $($route.target)"
      $replacement = if ($route.path -eq $assets[0]) {
        '](../team-core/references/handoff-format.md)'
      } elseif ($route.path -eq 'skills/team-core/SKILL.md') {
        '](references/handoff-format.md)'
      } else { '](handoff-format.md)' }
      Fixture $route.path ($body.Replace($needle, $replacement))
      Validate-Package $false "TE02b unlink $($route.path) -> $($route.target)"
      [IO.File]::WriteAllBytes($path, $bytes)
    }

    # TE02c/AUTO02: automatic invocation policy must be unique, nested and true.
    # Expected: implicit=false, duplicate keys/sections and misplaced/missing keys reject;
    # the existing formatting adapter's implicit policy remains unchanged.
    $path = Join-Path $package $assets[1]
    $bytes = [IO.File]::ReadAllBytes($path)
    foreach ($policy in @(
      @{ name = 'implicit false'; body = "policy:`n  allow_implicit_invocation: false`n" },
      @{ name = 'duplicate key'; body = (
        "policy:`n  allow_implicit_invocation: true`n" +
        "  allow_implicit_invocation: true`n"
      ) },
      @{ name = 'top-level key'; body = "allow_implicit_invocation: true`n" },
      @{ name = 'missing key'; body = "policy:`n  other: true`n" },
      @{ name = 'duplicate section'; body = (
        "policy:`n  allow_implicit_invocation: true`n" +
        "policy:`n  allow_implicit_invocation: true`n"
      ) }
    )) {
      Fixture $assets[1] $policy.body
      Validate-Package $false "TE02c $($policy.name)"
    }
    [IO.File]::WriteAllBytes($path, $bytes)
    Validate-Package $true 'TE02 exact restoration'
    Assert ((Package-Identity) -ceq $before) 'TE02 package bytes not restored exactly.'

    # TE03: the router is not a new feedback workflow in the retained schema.
    # Expected: actual runtime rejects workflow=team before writing any feedback record.
    $inputPath = Join-Path $sandbox 'feedback-input.json'
    $feedbackHome = Join-Path $sandbox 'feedback-home'
    $payload = @{
      schemaVersion = 1; workflow = 'team'; objective = 'synthetic routing contract'
      projectPathDigest = 'fixture'; acceptanceChecks = @('one selected workflow')
      verification = @(); status = 'passed'; rework = @{ count = 0; reasons = @() }
      remainingRisks = @()
    } | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($inputPath, $payload)
    $feedback = Run-Script (Join-Path $package 'skills/team-core/scripts/feedback-runtime.ps1') @(
      '-Action', 'Record', '-InputPath', $inputPath, '-FeedbackHome', $feedbackHome
    )
    Assert ($feedback.Exit -ne 0 -and $feedback.Error -match 'unsupported workflow') (
      "TE03 runtime did not reject router workflow: $($feedback.Out) $($feedback.Error)"
    )
    Assert (-not (Test-Path -LiteralPath $feedbackHome)) 'TE03 runtime wrote a router record.'
  } else {
    # TE06: one copied installer run proves discovery of the final entry unit.
    # Expected: three source/installed/receipt hashes agree in owned fake homes only.
    $codexHome = Join-Path $sandbox 'fake-codex'
    $agentsHome = Join-Path $sandbox 'fake-agents'
    $installed = Run-Script (Join-Path $package 'scripts/install-user.ps1') @(
      '-CodexHome', $codexHome, '-AgentsHome', $agentsHome
    )
    Assert ($installed.Exit -eq 0) "TE06 fake-home installation failed: $($installed.Error)"
    $receipt = Get-Content -LiteralPath (
      Join-Path $agentsHome 'codex-multi-agent/install-receipt.json'
    ) -Raw | ConvertFrom-Json
    foreach ($relative in $assets) {
      $source = Join-Path $repo $relative
      $destination = [IO.Path]::GetFullPath((Join-Path $agentsHome $relative))
      $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
      $installedHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
      $entry = @($receipt.files | Where-Object path -eq $destination)
      Assert ($sourceHash -eq $installedHash -and $entry.Count -eq 1 -and
        $entry[0].sha256 -eq $sourceHash) "TE06 payload/receipt mismatch: $relative"
    }
    Write-Output "TE06 payload proof passed: $($receipt.packageDigest)"
  }
  Write-Output "Team entry package tests passed: $script:validatorChecks validator checks."
} finally {
  # Cleanup only the exact GUID fixture root created by this invocation.
  $resolved = [IO.Path]::GetFullPath($sandbox)
  $actualParent = [IO.Path]::GetDirectoryName($resolved).TrimEnd('\', '/')
  Assert ($actualParent -eq $tempParent.TrimEnd('\', '/') -and
    (Split-Path -Leaf $resolved) -match '^codex-team-entry-test-[a-f0-9]{32}$') (
    'Unsafe Team entry fixture cleanup target.'
  )
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
