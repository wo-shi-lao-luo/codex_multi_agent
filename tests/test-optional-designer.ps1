# Exercise optional design guidance and actual package delivery using fake homes only.
# Native Designer routing/visual quality require a fresh client and are not text-test passes.
#requires -Version 7.0
[CmdletBinding()]
param([switch]$RedOnly)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/package-test.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$guidancePath = Join-Path $repo 'scripts/optional-capabilities.ps1'

# Fail with the scenario identity; no retry, swallowed failure or implicit repair.
function Assert-Optional([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

# OD05 deterministic preproduction case: the advisory provider must exist.
# Expected: a missing provider fails before implementation, without fixture creation.
Assert-Optional (Test-Path -LiteralPath $guidancePath -PathType Leaf) (
  'OD05: optional-capabilities provider is missing.'
)
if ($RedOnly) { Write-Output 'OD05 provider discovery passed.'; exit 0 }

$sandbox = Join-Path (Get-TestTemporaryParent) (
  'codex-optional-designer-test-' + [guid]::NewGuid().ToString('N')
)
$package = Join-Path $sandbox 'package'
$pwsh = (Get-Process -Id $PID).Path

# Execute copied real entrypoints, capturing both pipes and exit without a live client.
function Invoke-OptionalScript([string]$Relative, [string[]]$Arguments = @()) {
  return Invoke-TestProcess -FilePath $pwsh -ArgumentList (
    @('-NoProfile', '-File', (Join-Path $package $Relative)) + $Arguments
  )
}

try {
  Copy-TestPackage -SourceRoot $repo -DestinationRoot $package `
    -Profile PublicDocs -IncludeConfig $true

  # OD05 helper scenario: requesting advice has no package writes and is optional.
  # Expected: one static string with upstream URL, no success-pipeline diagnostics.
  $before = Get-TestFingerprint -Root $package
  . (Join-Path $package 'scripts/optional-capabilities.ps1')
  $advice = @(Get-OptionalCapabilityGuidance)
  Assert-Optional ($advice.Count -eq 1 -and $advice[0] -is [string]) (
    'OD05: advice is not one string.'
  )
  Assert-Optional ($advice[0] -match '(?i)optional' -and
    $advice[0] -match 'https://(impeccable\.style/tutorials/getting-started/|github\.com/pbakaus/impeccable)') (
    'OD05: advice omits optionalness or official upstream URL.'
  )
  Assert-Optional ((Get-TestFingerprint -Root $package) -ceq $before) (
    'OD05: requesting advice changed package bytes.'
  )

  # OD07 source scenario: actual complete copied package must validate read-only.
  # Expected: successful validation without any package-file mutation.
  $validation = Invoke-OptionalScript 'scripts/validate.ps1'
  Assert-Optional ($validation.Exit -eq 0) (
    "OD07: validation failed: $($validation.Out) $($validation.Error)"
  )
  Assert-Optional ((Get-TestFingerprint -Root $package) -ceq $before) (
    'OD07: validator changed copied package bytes.'
  )

  $codex = Join-Path $sandbox 'fake-codex'
  $agents = Join-Path $sandbox 'fake-agents'
  $homeArguments = @('-CodexHome', $codex, '-AgentsHome', $agents)

  # OD06 initial preview scenario: absent homes must stay absent.
  # Expected: successful preview with no installed files and no success advisory.
  $preview = Invoke-OptionalScript 'scripts/install-user.ps1' ($homeArguments + '-WhatIf')
  Assert-Optional ($preview.Exit -eq 0) "OD06: preview failed: $($preview.Error)"
  Assert-Optional (-not (Test-Path -LiteralPath $codex) -and
    -not (Test-Path -LiteralPath $agents)) 'OD06: preview created target homes.'
  Assert-Optional (-not $preview.Out.Contains($advice[0])) (
    'OD06: preview emitted actual-install advice.'
  )

  # OD05/OD07 install scenario: a missing optional provider must not block delivery.
  # Expected: exact Designer bytes and receipt, one advisory, no package edits.
  $install = Invoke-OptionalScript 'scripts/install-user.ps1' $homeArguments
  Assert-Optional ($install.Exit -eq 0) (
    "OD05: installation failed: $($install.Out) $($install.Error)"
  )
  Assert-Optional ($install.Out.Contains($advice[0])) 'OD05: install omitted optional advice.'
  $designer = Join-Path $codex 'agents/team-designer.toml'
  $sourceDesigner = Join-Path $package 'agents/team-designer.toml'
  Assert-Optional ((Get-FileHash -LiteralPath $designer).Hash -ceq
    (Get-FileHash -LiteralPath $sourceDesigner).Hash) 'OD07: Designer bytes differ.'
  $receiptPath = Join-Path $agents 'codex-multi-agent/install-receipt.json'
  $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
  Assert-Optional (@($receipt.files | Where-Object path -eq $designer).Count -eq 1) (
    'OD07: receipt omitted Designer.'
  )
  $reference = 'skills/team-core/references/impeccable-integration.md'
  $installedReference = Join-Path $agents $reference
  $sourceReference = Join-Path $package $reference
  Assert-Optional ((Get-FileHash -LiteralPath $installedReference).Hash -ceq
    (Get-FileHash -LiteralPath $sourceReference).Hash) (
    'OD07: optional Impeccable reference bytes differ.'
  )
  Assert-Optional (@($receipt.files | Where-Object path -eq $installedReference).Count -eq 1) (
    'OD07: receipt omitted optional Impeccable reference.'
  )

  # OD05 update scenario: delegated installation should not duplicate guidance.
  # Expected: updater succeeds and emits the static optional reminder exactly once.
  $update = Invoke-OptionalScript 'scripts/update-user.ps1' $homeArguments
  Assert-Optional ($update.Exit -eq 0) "OD05: update failed: $($update.Error)"
  $adviceCount = [regex]::Matches($update.Out, [regex]::Escape($advice[0])).Count
  Assert-Optional ($adviceCount -eq 1) 'OD05: update omitted/duplicated optional advice.'

  # OD06 managed preview scenario: complete fake-home and package trees stay exact.
  # Expected: no receipt/backups or other files change on an update preview.
  $homesBefore = Get-TestFingerprint -Root $sandbox
  $updatePreview = Invoke-OptionalScript 'scripts/update-user.ps1' (
    $homeArguments + '-WhatIf'
  )
  Assert-Optional ($updatePreview.Exit -eq 0) 'OD06: update preview failed.'
  Assert-Optional ((Get-TestFingerprint -Root $sandbox) -ceq $homesBefore) (
    'OD06: update preview mutated fixture files.'
  )
  Assert-Optional (-not $updatePreview.Out.Contains($advice[0])) (
    'OD06: update preview emitted actual-install advice.'
  )

  # OD06 conflict scenario: preserve customization and the failing outcome.
  # Expected: nonzero exit, exact pre-failure tree, and no success-only advice.
  Set-Content -LiteralPath $designer -Value '# isolated user customization' -Encoding utf8
  $conflictBefore = Get-TestFingerprint -Root $sandbox
  $failed = Invoke-OptionalScript 'scripts/update-user.ps1' $homeArguments
  Assert-Optional ($failed.Exit -ne 0) 'OD06: customized-file conflict succeeded.'
  Assert-Optional (-not $failed.Out.Contains($advice[0])) (
    'OD06: failed deployment emitted success-only advice.'
  )
  Assert-Optional ((Get-TestFingerprint -Root $sandbox) -ceq $conflictBefore) (
    'OD06: failing deployment changed fixture files.'
  )
  Assert-Optional ((Get-TestFingerprint -Root $package) -ceq $before) (
    'OD07: delivery changed copied source bytes.'
  )
  Write-Output 'Optional Designer package/advisory tests passed (OD05-OD07).'
} finally {
  # Only remove this invocation's direct OS-temp GUID sandbox, never real homes.
  Remove-TestSandbox -Path $sandbox -Prefix 'codex-optional-designer-test-'
  Assert-Optional (-not (Test-Path -LiteralPath $sandbox)) 'Owned test fixture survived.'
}
