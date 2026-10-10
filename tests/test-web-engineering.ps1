# Verify offline web-guidance discovery and distribution through actual consumers.
# Exact links prove packaging, not semantic proportionality or native agent behavior.
#requires -Version 7.0
[CmdletBinding()]
param([switch]$RedOnly, [switch]$InstallOnly)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$assets = @(
  'skills/team-core/references/web-engineering.md',
  'skills/frontend-engineering/references/state-data.md',
  'skills/frontend-engineering/references/usability-performance.md',
  'skills/backend-engineering/references/service-reliability.md'
)
$routes = @(
  @{ path = 'skills/team-core/SKILL.md'; target = 'references/web-engineering.md' },
  @{ path = 'skills/frontend-engineering/SKILL.md'; target = 'references/state-data.md' },
  @{ path = 'skills/frontend-engineering/SKILL.md'; target = 'references/usability-performance.md' },
  @{ path = 'skills/backend-engineering/SKILL.md'; target = 'references/service-reliability.md' }
)
foreach ($skill in @('frontend-engineering', 'backend-engineering',
  'testing-engineering', 'code-review', 'team-dev')) {
  $routes += @{ path = "skills/$skill/SKILL.md"; target = '../team-core/references/web-engineering.md' }
}
foreach ($guide in @('frontend-engineering/references/state-data.md',
  'frontend-engineering/references/usability-performance.md',
  'backend-engineering/references/service-reliability.md')) {
  $routes += @{ path = $assets[0]; target = "../../$guide" }
}

# Fail immediately with a named case; no mutation or error masking.
function Assert([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

# WEB01 scenario: a required normative guide is not distributed yet.
# Expected: actual source absence gives genuine preproduction Red without fixtures.
foreach ($relative in $assets) {
  Assert (Test-Path -LiteralPath (Join-Path $repo $relative) -PathType Leaf) (
    "WEB01: missing source guide $relative"
  )
}
if ($RedOnly) { Write-Output 'WEB01 source guides passed.'; exit 0 }

# WEB02 scenario: consumers must discover only the agreed reference targets.
# Expected: every exact Markdown target exists; no wording-based behavior claim.
foreach ($route in $routes) {
  $body = Get-Content -LiteralPath (Join-Path $repo $route.path) -Raw
  Assert ($body.Contains("]($($route.target))")) (
    "WEB02: missing discovery route $($route.path) -> $($route.target)"
  )
}

$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$sandbox = Join-Path $tempParent ('codex-web-engineering-test-' + [guid]::NewGuid().ToString('N'))
$package = Join-Path $sandbox 'package'
$pwshExe = (Get-Process -Id $PID).Path
$script:checks = 0

# Start the copied real consumer with literal argv and captured independent pipes.
# Explicit fake-home arguments are mandatory for installer calls below.
function Run-Script([string]$Path, [string[]]$Arguments = @()) {
  $start = [Diagnostics.ProcessStartInfo]::new($pwshExe)
  $start.UseShellExecute = $false
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
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

# Copy exact authoritative package bytes, excluding all foreign/local Work trees.
# Formatter documents are required existing validator links, not invented fixtures.
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

# The actual validator must match expected validity; retain diagnostics on mismatch.
function Validate-Package([bool]$ExpectedValid, [string]$Scenario) {
  $result = Run-Script (Join-Path $package 'scripts/validate.ps1')
  $script:checks++
  Assert (($result.Exit -eq 0) -eq $ExpectedValid) (
    "$Scenario validator exit $($result.Exit), expected valid=$ExpectedValid. " +
    "$($result.Out) $($result.Error)"
  )
}

# Full file manifest detects unintended consumer writes and incomplete restoration.
function Package-Identity {
  return (@(Get-ChildItem -LiteralPath $package -Recurse -Force -File | ForEach-Object {
    "$([IO.Path]::GetRelativePath($package, $_.FullName))`t" +
      (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
  } | Sort-Object -CaseSensitive) -join "`n")
}

try {
  Copy-Package
  $before = Package-Identity
  # WEB02 intact scenario: real copied package validates without byte mutations.
  # Expected: exit0 and identical full manifest, independent of route semantics.
  Validate-Package $true 'WEB02 intact package'
  Assert ((Package-Identity) -ceq $before) 'WEB02 validator mutated intact package.'
  if (-not $InstallOnly) {
    # WEB02 omission scenarios: remove one linked guide at a time, then restore.
    # Expected: real generic link validation rejects each omission; final bytes exact.
    foreach ($relative in $assets) {
      $path = Join-Path $package $relative
      $bytes = [IO.File]::ReadAllBytes($path)
      Remove-Item -LiteralPath $path -Force
      Validate-Package $false "WEB02 omit $relative"
      [IO.File]::WriteAllBytes($path, $bytes)
    }
    Validate-Package $true 'WEB02 restored package'
    Assert ((Package-Identity) -ceq $before) 'WEB02 package restoration mismatch.'
  } else {
    # WEB03 scenario: the existing installer copies the new four-guide unit.
    # Expected: source, installed bytes and receipt hashes agree only in fake homes.
    $codexHome = Join-Path $sandbox 'fake-codex'
    $agentsHome = Join-Path $sandbox 'fake-agents'
    $install = Run-Script (Join-Path $package 'scripts/install-user.ps1') @(
      '-CodexHome', $codexHome, '-AgentsHome', $agentsHome
    )
    Assert ($install.Exit -eq 0) "WEB03 fake-home installation failed: $($install.Error)"
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
        $entry[0].sha256 -eq $sourceHash) "WEB03 payload/receipt mismatch: $relative"
    }
    Write-Output "WEB03 payload proof passed: $($receipt.packageDigest)"
  }
  Write-Output "Web engineering package tests passed: $script:checks validator checks, $($routes.Count) routes."
} finally {
  # Delete only this invocation's validated GUID root, never repository or user homes.
  $resolved = [IO.Path]::GetFullPath($sandbox)
  Assert ([IO.Path]::GetDirectoryName($resolved).TrimEnd('\', '/') -eq
    $tempParent.TrimEnd('\', '/') -and
    (Split-Path -Leaf $resolved) -match '^codex-web-engineering-test-[a-f0-9]{32}$') (
    'Unsafe web engineering cleanup target.'
  )
  if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
