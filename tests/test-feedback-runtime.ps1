[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$runtime = Join-Path $root 'skills\team-core\scripts\feedback-runtime.ps1'
$temporaryParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRootName = 'codex-multi-agent-feedback-test-' + [Guid]::NewGuid().ToString('N')
$testRoot = Join-Path $temporaryParent $testRootName
$feedbackHome = Join-Path $testRoot 'feedback-home'
$payloadPath = Join-Path $testRoot 'run.json'

function Assert-Condition {
  param([Parameter(Mandatory = $true)][bool]$Condition, [Parameter(Mandatory = $true)][string]$Message)
  if (-not $Condition) { throw $Message }
}

function Invoke-Runtime {
  param(
    [Parameter(Mandatory = $true)][string]$Action,
    [string]$InputPath,
    [string]$CandidateId,
    [string]$CandidateState,
    [switch]$DeleteArchived,
    [switch]$ConfirmDeletion
  )
  $arguments = @{ Action = $Action; FeedbackHome = $feedbackHome; Confirm = $false }
  if ($InputPath) { $arguments.InputPath = $InputPath }
  if ($CandidateId) { $arguments.CandidateId = $CandidateId }
  if ($CandidateState) { $arguments.CandidateState = $CandidateState }
  if ($DeleteArchived) { $arguments.DeleteArchived = $true }
  if ($ConfirmDeletion) { $arguments.ConfirmDeletion = $true }
  try {
    $output = & $runtime @arguments
  } catch {
    throw "Feedback runtime failed: $($_.Exception.Message)"
  }
  return ($output | Out-String | ConvertFrom-Json)
}

try {
  New-Item -ItemType Directory -Path $testRoot -ErrorAction Stop | Out-Null
  $payload = [ordered]@{
    schemaVersion = 1
    workflow = 'team-dev'
    objective = 'Verify local feedback recording'
    projectPathDigest = 'project-6a0d'
    acceptanceChecks = @('Tests run')
    verification = @([ordered]@{ check = 'unit tests'; result = 'failed'; evidence = 'exit code 1' })
    status = 'failed'
    rework = [ordered]@{ count = 2; reasons = @('verification failure') }
    remainingRisks = @('Tests remain failing')
    candidateSignals = @([ordered]@{ key = 'missing-fixture'; category = 'test'; summary = 'A reusable fixture was missing.' })
  }
  $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $payloadPath -Encoding utf8

  $first = Invoke-Runtime -Action 'Record' -InputPath $payloadPath
  Assert-Condition ($first.action -eq 'recorded') 'Record did not report success.'
  Assert-Condition ($first.candidateCount -eq 5) 'Record did not derive and retain all expected candidates.'
  $runFiles = @(Get-ChildItem -LiteralPath (Join-Path $feedbackHome 'runs') -Filter '*.json' -File)
  Assert-Condition ($runFiles.Count -eq 1) 'Record did not create exactly one run file.'
  $record = Get-Content -LiteralPath $runFiles[0].FullName -Raw | ConvertFrom-Json
  Assert-Condition ($record.projectPathDigest -eq 'project-6a0d') 'Record changed the redacted project identifier.'
  Assert-Condition ($record.feedbackCandidateIds.Count -eq 5) 'Run record did not link candidates.'

  Invoke-Runtime -Action 'Record' -InputPath $payloadPath | Out-Null
  $candidateFiles = @(Get-ChildItem -LiteralPath (Join-Path $feedbackHome 'feedback\candidates') -Filter '*.json' -File)
  Assert-Condition ($candidateFiles.Count -eq 5) 'Equivalent candidates were not deduplicated.'
  $fixtureCandidate = @($candidateFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json } | Where-Object { $_.key -eq 'missing-fixture' })
  Assert-Condition ($fixtureCandidate.Count -eq 1 -and $fixtureCandidate[0].count -eq 2) 'Candidate aggregation did not retain the observation count.'
  Invoke-Runtime -Action 'SetCandidateState' -CandidateId $fixtureCandidate[0].id -CandidateState 'confirmed' | Out-Null
  $confirmed = Get-Content -LiteralPath (Join-Path $feedbackHome ('feedback\candidates\' + $fixtureCandidate[0].id + '.json')) -Raw | ConvertFrom-Json
  Assert-Condition ($confirmed.state -eq 'confirmed') 'Candidate state was not updated.'

  $payloadWithoutOptionalSignals = $payload | ConvertTo-Json -Depth 6 | ConvertFrom-Json
  $payloadWithoutOptionalSignals.PSObject.Properties.Remove('candidateSignals')
  $payloadWithoutOptionalSignals.status = 'passed'
  $payloadWithoutOptionalSignals.rework.count = 0
  $payloadWithoutOptionalSignals.remainingRisks = @()
  $payloadWithoutOptionalSignals.verification = @([PSCustomObject]@{ check = 'unit tests'; result = 'passed'; evidence = 'exit code 0' })
  $payloadWithoutOptionalSignals | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $payloadPath -Encoding utf8
  $withoutOptionalSignals = Invoke-Runtime -Action 'Record' -InputPath $payloadPath
  Assert-Condition ($withoutOptionalSignals.candidateCount -eq 0) 'Runtime did not accept a payload without optional candidateSignals.'

  $badPayload = $payload | ConvertTo-Json -Depth 6 | ConvertFrom-Json
  $badPayload.projectPathDigest = 'C:\\private-project'
  $badPayload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $payloadPath -Encoding utf8
  $rejectedPath = $false
  try { Invoke-Runtime -Action 'Record' -InputPath $payloadPath | Out-Null } catch { $rejectedPath = $true }
  Assert-Condition $rejectedPath 'Runtime accepted an absolute project path.'

  $runFiles | ForEach-Object { $_.LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddDays(-91) }
  $maintenance = Invoke-Runtime -Action 'Maintain'
  Assert-Condition ($maintenance.maintenance.archived -eq 1) 'Maintenance did not archive the aged run.'
  $archiveDirectory = Join-Path $feedbackHome 'archive\runs'
  $archivedFiles = @(Get-ChildItem -LiteralPath $archiveDirectory -Filter '*.json' -File)
  Assert-Condition ($archivedFiles.Count -eq 1) 'Maintenance archive has an unexpected run count.'
  $archivedFiles[0].LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddDays(-181)
  $deletionRejected = $false
  try { Invoke-Runtime -Action 'Maintain' -DeleteArchived | Out-Null } catch { $deletionRejected = $true }
  Assert-Condition $deletionRejected 'Runtime allowed deletion without explicit confirmation.'
  $deleted = Invoke-Runtime -Action 'Maintain' -DeleteArchived -ConfirmDeletion
  Assert-Condition ($deleted.maintenance.deleted -eq 1) 'Confirmed deletion did not remove the eligible archive.'
  Assert-Condition (@(Get-ChildItem -LiteralPath $archiveDirectory -Filter '*.json' -File).Count -eq 0) 'Deletion left an archive file behind.'

  Write-Host 'Feedback runtime tests passed.'
} finally {
  $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
  $resolvedParent = [System.IO.Path]::GetFullPath((Split-Path -Parent $resolvedTestRoot)).TrimEnd([char]'\', [char]'/' )
  $normalizedTemporaryParent = $temporaryParent.TrimEnd([char]'\', [char]'/' )
  if ($resolvedParent -ne $normalizedTemporaryParent -or -not ([System.IO.Path]::GetFileName($resolvedTestRoot).StartsWith('codex-multi-agent-feedback-test-'))) {
    throw "Refusing to clean unexpected test path: $resolvedTestRoot"
  }
  if (Test-Path -LiteralPath $resolvedTestRoot) { Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction Stop }
  Assert-Condition (-not (Test-Path -LiteralPath $resolvedTestRoot)) "Test cleanup left an unexpected directory: $resolvedTestRoot"
  Write-Host 'Isolated feedback test directory removed.'
}
