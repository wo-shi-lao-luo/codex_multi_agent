[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('Record', 'Maintain', 'SetCandidateState')]
  [string]$Action,
  [string]$InputPath,
  [string]$FeedbackHome,
  [string]$CandidateId,
  [ValidateSet('candidate', 'confirmed', 'applied', 'rejected')]
  [string]$CandidateState,
  [switch]$DeleteArchived,
  [switch]$ConfirmDeletion
)

$ErrorActionPreference = 'Stop'

function Get-DefaultFeedbackHome {
  $skillDirectory = Split-Path -Parent $PSScriptRoot
  $skillsDirectory = Split-Path -Parent $skillDirectory
  $agentsHome = Split-Path -Parent $skillsDirectory
  return Join-Path $agentsHome 'codex-multi-agent'
}

function Get-UtcTimestamp { return (Get-Date).ToUniversalTime().ToString('o') }

function Write-AtomicJson {
  param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)]$Value)
  $directory = Split-Path -Parent $Path
  New-Item -ItemType Directory -Force -Path $directory | Out-Null
  $temporaryPath = Join-Path $directory ('.' + [Guid]::NewGuid().ToString('N') + '.tmp')
  try {
    $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temporaryPath -Encoding utf8 -NoNewline
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
  } finally {
    if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue }
  }
}

function Get-HashId {
  param([Parameter(Mandatory = $true)][string]$Value)
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
  $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
  return -join ($hash | ForEach-Object { $_.ToString('x2') })
}

function Assert-RunPayload {
  param([Parameter(Mandatory = $true)]$Payload)
  $required = @('schemaVersion', 'workflow', 'objective', 'projectPathDigest', 'acceptanceChecks', 'verification', 'status', 'rework', 'remainingRisks')
  foreach ($field in $required) {
    if ($null -eq $Payload.$field) { throw "Run payload is missing required field: $field" }
  }
  if ([int]$Payload.schemaVersion -ne 1) { throw 'Run payload schemaVersion must be 1.' }
  if (@('team-dev', 'team-plan', 'team-debug', 'team-review') -notcontains [string]$Payload.workflow) { throw 'Run payload has an unsupported workflow.' }
  if (@('passed', 'completed_with_risk', 'blocked', 'failed') -notcontains [string]$Payload.status) { throw 'Run payload has an unsupported status.' }
  if ([string]::IsNullOrWhiteSpace([string]$Payload.objective)) { throw 'Run payload objective must not be empty.' }
  if ([string]$Payload.projectPathDigest -match '(^[a-zA-Z]:[\\/]|^/|^~|\\\\)') { throw 'projectPathDigest must be redacted and must not be an absolute path.' }
  if ($null -eq $Payload.rework.count -or [int]$Payload.rework.count -lt 0) { throw 'Run payload rework.count must be a non-negative integer.' }
}

function Get-DerivedSignals {
  param([Parameter(Mandatory = $true)]$Payload)
  $signals = New-Object System.Collections.Generic.List[object]
  foreach ($verification in @($Payload.verification)) {
    if (@('failed', 'unavailable') -contains [string]$verification.result) {
      $signals.Add([PSCustomObject]@{ key = 'verification-gap'; category = 'verification'; summary = 'A planned verification check failed or was unavailable.' })
      break
    }
  }
  if ([int]$Payload.rework.count -ge 2) { $signals.Add([PSCustomObject]@{ key = 'repeat-rework'; category = 'workflow'; summary = 'The task required two or more rework passes.' }) }
  if (@($Payload.remainingRisks).Count -gt 0) { $signals.Add([PSCustomObject]@{ key = 'remaining-risk'; category = 'risk'; summary = 'The task closed with an explicit remaining risk.' }) }
  if (@('blocked', 'failed') -contains [string]$Payload.status) { $signals.Add([PSCustomObject]@{ key = 'workflow-' + [string]$Payload.status; category = 'outcome'; summary = 'The workflow closed as ' + [string]$Payload.status + '.' }) }
  foreach ($signal in @($Payload.candidateSignals | Where-Object { $null -ne $_ })) {
    if ([string]::IsNullOrWhiteSpace([string]$signal.key) -or [string]::IsNullOrWhiteSpace([string]$signal.category) -or [string]::IsNullOrWhiteSpace([string]$signal.summary)) {
      throw 'Every candidateSignals entry needs key, category, and summary.'
    }
    $signals.Add([PSCustomObject]@{ key = [string]$signal.key; category = [string]$signal.category; summary = [string]$signal.summary })
  }
  return @($signals | Group-Object key | ForEach-Object { $_.Group[0] })
}

function Invoke-Maintenance {
  param([Parameter(Mandatory = $true)][string]$FeedbackStore, [switch]$AllowDeletion)
  $runsDirectory = Join-Path $FeedbackStore 'runs'
  $archiveDirectory = Join-Path $FeedbackStore 'archive\runs'
  $cutoff = (Get-Date).ToUniversalTime().AddDays(-90)
  $archived = 0
  if (Test-Path -LiteralPath $runsDirectory) {
    Get-ChildItem -LiteralPath $runsDirectory -Filter '*.json' -File | ForEach-Object {
      if ($_.LastWriteTimeUtc -lt $cutoff) {
        New-Item -ItemType Directory -Force -Path $archiveDirectory | Out-Null
        Move-Item -LiteralPath $_.FullName -Destination (Join-Path $archiveDirectory $_.Name) -Force
        $archived++
      }
    }
  }

  $deletionCutoff = (Get-Date).ToUniversalTime().AddDays(-180)
  $eligible = @()
  if (Test-Path -LiteralPath $archiveDirectory) {
    $eligible = @(Get-ChildItem -LiteralPath $archiveDirectory -Filter '*.json' -File | Where-Object { $_.LastWriteTimeUtc -lt $deletionCutoff })
  }
  $deleted = 0
  if ($AllowDeletion) {
    foreach ($file in $eligible) {
      if ($PSCmdlet.ShouldProcess($file.FullName, 'Permanently delete archived feedback record')) {
        Remove-Item -LiteralPath $file.FullName -Force
        $deleted++
      }
    }
  }
  return [PSCustomObject]@{ archived = $archived; eligibleForDeletion = $eligible.Count; deleted = $deleted }
}

if ([string]::IsNullOrWhiteSpace($FeedbackHome)) { $FeedbackHome = Get-DefaultFeedbackHome }
$FeedbackHome = [System.IO.Path]::GetFullPath($FeedbackHome)

switch ($Action) {
  'Record' {
    if ([string]::IsNullOrWhiteSpace($InputPath) -or -not (Test-Path -LiteralPath $InputPath)) { throw 'Record requires an existing -InputPath.' }
    $payload = Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json -ErrorAction Stop
    Assert-RunPayload -Payload $payload
    $runId = [Guid]::NewGuid().ToString('N')
    $record = [ordered]@{
      schemaVersion = 1; id = $runId; recordedAt = Get-UtcTimestamp; workflow = [string]$payload.workflow
      projectPathDigest = [string]$payload.projectPathDigest; objective = [string]$payload.objective
      acceptanceChecks = @($payload.acceptanceChecks); verification = @($payload.verification)
      status = [string]$payload.status; rework = $payload.rework; remainingRisks = @($payload.remainingRisks)
      feedbackCandidateIds = @()
    }
    $candidateDirectory = Join-Path $FeedbackHome 'feedback\candidates'
    foreach ($signal in Get-DerivedSignals -Payload $payload) {
      $candidateId = Get-HashId -Value ([string]$signal.key)
      $candidatePath = Join-Path $candidateDirectory ($candidateId + '.json')
      if (Test-Path -LiteralPath $candidatePath) {
        $candidate = Get-Content -LiteralPath $candidatePath -Raw | ConvertFrom-Json -ErrorAction Stop
        $candidate.count = [int]$candidate.count + 1
        $candidate.lastObservedAt = Get-UtcTimestamp
        if (@($candidate.runIds) -notcontains $runId) { $candidate.runIds = @($candidate.runIds) + @($runId) }
      } else {
        $candidate = [ordered]@{ schemaVersion = 1; id = $candidateId; key = [string]$signal.key; category = [string]$signal.category; summary = [string]$signal.summary; state = 'candidate'; firstObservedAt = Get-UtcTimestamp; lastObservedAt = Get-UtcTimestamp; count = 1; runIds = @($runId) }
      }
      Write-AtomicJson -Path $candidatePath -Value $candidate
      $record.feedbackCandidateIds += $candidateId
    }
    $runPath = Join-Path $FeedbackHome ('runs\' + $record.recordedAt.Replace(':', '').Replace('-', '').Replace('.', '') + '-' + $runId + '.json')
    Write-AtomicJson -Path $runPath -Value $record
    $maintenance = Invoke-Maintenance -FeedbackStore $FeedbackHome
    [PSCustomObject]@{ action = 'recorded'; runId = $runId; candidateCount = @($record.feedbackCandidateIds).Count; maintenance = $maintenance } | ConvertTo-Json -Depth 5
  }
  'Maintain' {
    if ($DeleteArchived -and -not $ConfirmDeletion) { throw 'Permanent deletion requires both -DeleteArchived and -ConfirmDeletion after direct user approval.' }
    $maintenance = Invoke-Maintenance -FeedbackStore $FeedbackHome -AllowDeletion:$DeleteArchived
    [PSCustomObject]@{ action = 'maintained'; maintenance = $maintenance } | ConvertTo-Json -Depth 4
  }
  'SetCandidateState' {
    if ([string]::IsNullOrWhiteSpace($CandidateId) -or [string]::IsNullOrWhiteSpace($CandidateState)) { throw 'SetCandidateState requires -CandidateId and -CandidateState.' }
    $candidatePath = Join-Path $FeedbackHome ('feedback\candidates\' + $CandidateId + '.json')
    if (-not (Test-Path -LiteralPath $candidatePath)) { throw "Candidate not found: $CandidateId" }
    $candidate = Get-Content -LiteralPath $candidatePath -Raw | ConvertFrom-Json -ErrorAction Stop
    $candidate.state = $CandidateState
    $candidate | Add-Member -NotePropertyName lastUpdatedAt -NotePropertyValue (Get-UtcTimestamp) -Force
    Write-AtomicJson -Path $candidatePath -Value $candidate
    [PSCustomObject]@{ action = 'candidate_state_updated'; candidateId = $CandidateId; state = $CandidateState } | ConvertTo-Json
  }
}
