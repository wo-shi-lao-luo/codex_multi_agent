# Verify packaged peer-contract discovery through the real isolated validator.
# Native messaging, authority and independence require separate source/manual evidence.
#requires -Version 7.0
[CmdletBinding()]
param([switch]$RedOnly)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/package-test.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$contract = 'skills/team-core/references/peer-communication.md'

# Fail with a stable case identity; caller supplies the observed condition and failure detail.
function Assert-Peer([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

# PC-01 new resource discovery: absent peer contract must fail before fixture creation.
# Expected: actual missing-resource Red before production, success after delivery.
Assert-Peer (Test-Path -LiteralPath (Join-Path $repo $contract) -PathType Leaf) (
  "PC-01 missing peer contract: $contract"
)
if ($RedOnly) { Write-Output 'PC-01 peer contract discovery passed.'; exit 0 }

$sandbox = Join-Path (Get-TestTemporaryParent) ('codex-peer-test-' + [guid]::NewGuid().ToString('N'))
$package = Join-Path $sandbox 'package'
$shell = (Get-Process -Id $PID).Path

# Run only the copied production validator with unchanged exit and captured stdout/stderr.
function Invoke-PeerValidator {
  Invoke-TestProcess -FilePath $shell -ArgumentList @(
    '-NoProfile', '-File', (Join-Path $package 'scripts/validate.ps1')
  )
}

try {
  Copy-TestPackage -SourceRoot $repo -DestinationRoot $package -Profile PublicDocs -IncludeConfig $true
  $before = Get-TestFingerprint -Root $package

  # PC-02 complete package: actual validator accepts supported peer wiring without writes.
  # Expected: exit0 and exact source fingerprint preservation.
  $valid = Invoke-PeerValidator
  Assert-Peer ($valid.Exit -eq 0) "PC-02 intact package rejected: $($valid.Out) $($valid.Error)"
  Assert-Peer ((Get-TestFingerprint $package) -ceq $before) 'PC-02 validator mutated source.'

  # PC-02 missing contract: remove only the required resource in our copied package.
  # Expected: rejection, followed by success after exact source restoration.
  $contractPath = Join-Path $package $contract
  Remove-Item -LiteralPath $contractPath -Force
  $rejected = Invoke-PeerValidator
  Assert-Peer ($rejected.Exit -ne 0) 'PC-02 missing peer contract accepted.'
  Copy-Item -LiteralPath (Join-Path $repo $contract) -Destination $contractPath
  $valid = Invoke-PeerValidator
  Assert-Peer ($valid.Exit -eq 0) 'PC-02 restored contract rejected.'

  # PC-03 valid but unrelated targets: merely resolving a Markdown link is insufficient.
  # Expected: replacing each required discovery route rejects; exact restoration succeeds.
  foreach ($route in @(
    @{path='skills/team-core/SKILL.md'; from='references/peer-communication.md'; to='references/execution-contract.md'},
    @{path='skills/team-core/references/role-routing.md'; from='peer-communication.md'; to='execution-contract.md'},
    @{path='skills/team-core/references/external-research.md'; from='peer-communication.md'; to='execution-contract.md'},
    @{path='skills/team-core/references/execution-contract.md'; from='peer-communication.md'; to='role-routing.md'},
    @{path='skills/team-core/references/agent-handoffs.md'; from='peer-communication.md'; to='execution-contract.md'}
  )) {
    $path = Join-Path $package $route.path
    $original = Get-Content -LiteralPath $path -Raw
    $pattern = '\[[^\]]+\]\(' + [regex]::Escape($route.from) + '\)'
    Assert-Peer ($original -match $pattern) "PC-03 missing baseline route: $($route.path)"
    $changed = [regex]::Replace($original, $pattern, "[unrelated contract]($($route.to))")
    Set-Content -LiteralPath $path -Value $changed -Encoding utf8
    $rejected = Invoke-PeerValidator
    Assert-Peer ($rejected.Exit -ne 0) "PC-03 unrelated route accepted: $($route.path)"
    Copy-Item -LiteralPath (Join-Path $repo $route.path) -Destination $path -Force
    $valid = Invoke-PeerValidator
    Assert-Peer ($valid.Exit -eq 0) "PC-03 restored route rejected: $($route.path)"
  }
  Assert-Peer ((Get-TestFingerprint $package) -ceq $before) 'PC-03 package bytes changed.'
  Write-Output 'PC-01/02/03 packaged peer contract checks passed.'
} finally {
  # Cleanup is confined to this invocation's direct temporary GUID sandbox.
  # Expected: no surviving fixture, including on assertion failure.
  Remove-TestSandbox -Path $sandbox -Prefix 'codex-peer-test-'
  Assert-Peer (-not (Test-Path -LiteralPath $sandbox)) 'PC-03 cleanup failed.'
  Write-Output 'Owned peer fixture removed.'
}
