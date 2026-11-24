# Exercise user feedback through the runtime commands against a disposable store.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/platform.ps1')
$root = Split-Path -Parent $PSScriptRoot
$runtime = Join-Path $root 'skills/team-core/scripts/feedback-runtime.ps1'
$temporaryParent = Get-TestTemporaryParent
$testPrefix = 'codex-multi-agent-user-feedback-test-'
$testRoot = Join-Path $temporaryParent ($testPrefix + [Guid]::NewGuid().ToString('N'))
$feedbackHome = Join-Path $testRoot 'feedback-home'
$eventDirectory = Join-Path $feedbackHome 'feedback/user-events'
$candidateDirectory = Join-Path $feedbackHome 'feedback/candidates'
$payloadPath = Join-Path $testRoot 'payload.json'

function Assert-Condition([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Invoke-Feedback([string]$Action, [hashtable]$Options = @{}) {
  $output = & $runtime -Action $Action -FeedbackHome $feedbackHome -Confirm:$false @Options
  return ($output | Out-String | ConvertFrom-Json -ErrorAction Stop)
}

function Set-FeedbackPayload($Payload) {
  $Payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $payloadPath -Encoding utf8
}

function Assert-FeedbackRejected([scriptblock]$Attempt, [string]$Scenario) {
  try {
    & $Attempt | Out-Null
  } catch {
    # Require a runtime validation exception instead of a binding or JSON parsing error.
    if ($_.Exception.Message -notmatch '^USER_FEEDBACK:') { throw }
    return
  }
  throw "Expected feedback rejection for $Scenario."
}

function Get-FeedbackFiles([string]$Directory) {
  if (Test-Path -LiteralPath $Directory -PathType Container) {
    Get-ChildItem -LiteralPath $Directory -File -Filter '*.json'
  }
}

try {
  New-Item -ItemType Directory -Path $testRoot | Out-Null
  $eventPayload = @{
    schemaVersion = 1
    workflow = 'team-dev'
    projectDigest = 'a' * 64
    sessionDigest = 'b' * 64
    taskDigest = 'c' * 64
    messageDigest = 'd' * 64
    issueKey = 'hidden-guide-entry'
    kitVersion = '2.0.7'
    observed = 'The task-coordination guide did not show how a returning visitor could reopen it.'
    expected = 'The guide entry stays available after replay.'
    impact = 'The visitor could not resume the handoff.'
    severity = 'normal'
  }
  $updatePayload = @{
    schemaVersion = 1
    status = 'resolved'
    result = 'Verified the guide opens after returning from replay.'
  }
  $payloadOption = @{ InputPath = $payloadPath }

  # A fresh fixture is opted out, and checking its status leaves the store absent.
  $status = Invoke-Feedback 'UserFeedbackStatus'
  Assert-Condition ($status.enabled -is [bool] -and -not $status.enabled) `
    'User feedback capture must default to disabled.'
  Assert-Condition (-not (Test-Path -LiteralPath $feedbackHome)) `
    'Checking default capture status created a feedback store.'

  # Disabled recording and updating are no-ops, including on a fresh store.
  Set-FeedbackPayload $eventPayload
  $disabledRecord = Invoke-Feedback 'RecordUserEvent' $payloadOption
  Set-FeedbackPayload $updatePayload
  $disabledUpdate = Invoke-Feedback 'UpdateUserEvent' @{
    EventId = 'e' * 64
    InputPath = $payloadPath
  }
  Assert-Condition ($disabledRecord.action -eq 'disabled') 'Disabled capture accepted a record.'
  Assert-Condition ($disabledUpdate.action -eq 'disabled') 'Disabled capture accepted an update.'
  Assert-Condition (-not (Test-Path -LiteralPath $feedbackHome)) `
    'A disabled capture operation created a feedback store.'

  # Explicit opt-in persists across commands. A valid event is stored with an open outcome.
  Invoke-Feedback 'SetUserFeedbackCapture' @{ CaptureState = 'enabled' } | Out-Null
  Assert-Condition ((Invoke-Feedback 'UserFeedbackStatus').enabled -eq $true) `
    'The explicit opt-in was not visible to the next command.'
  Set-FeedbackPayload $eventPayload
  $first = Invoke-Feedback 'RecordUserEvent' $payloadOption
  Assert-Condition ($first.action -eq 'recorded' -and $first.eventId -and $first.caseId) `
    'Recording a valid event did not return its event and case IDs.'
  $eventPath = Join-Path $eventDirectory ($first.eventId + '.json')
  $event = Get-Content -LiteralPath $eventPath -Raw | ConvertFrom-Json
  Assert-Condition ($event.status -eq 'open' -and $event.observed -eq $eventPayload.observed) `
    'The persisted event did not retain the observation and its initial open status.'

  # Replay is idempotent. A second message is a new event in the same case.
  $duplicate = Invoke-Feedback 'RecordUserEvent' $payloadOption
  Assert-Condition ($duplicate.action -eq 'duplicate' -and $duplicate.eventId -eq $first.eventId) `
    'Replaying the same message did not reuse its event.'
  Assert-Condition (@(Get-FeedbackFiles $eventDirectory).Count -eq 1) `
    'Replaying the same message created an extra event file.'
  $followUpPayload = $eventPayload.Clone()
  $followUpPayload.messageDigest = 'e' * 64
  $followUpPayload.observed = 'The same visitor hit the issue again on the review screen.'
  Set-FeedbackPayload $followUpPayload
  $followUp = Invoke-Feedback 'RecordUserEvent' $payloadOption
  Assert-Condition ($followUp.action -eq 'recorded' -and $followUp.eventId -ne $first.eventId `
    -and $followUp.caseId -eq $first.caseId) 'A follow-up did not create a distinct event in its case.'

  # Even with matching task and message digests, a different project gets a separate case.
  $otherProjectPayload = $eventPayload.Clone()
  $otherProjectPayload.projectDigest = 'f' * 64
  Set-FeedbackPayload $otherProjectPayload
  $otherProject = Invoke-Feedback 'RecordUserEvent' $payloadOption
  Assert-Condition ($otherProject.action -eq 'recorded' -and $otherProject.eventId -ne $first.eventId `
    -and $otherProject.caseId -ne $first.caseId) 'Feedback from two projects shared an event or case.'
  Assert-Condition (@(Get-FeedbackFiles $candidateDirectory).Count -eq 0) `
    'Capturing a user event automatically created a promotion candidate.'

  # Reject malformed digests, prose that exposes private data, and schema drift without a write.
  foreach ($invalid in @(
    @{ Label = 'uppercase digest'; MessageDigest = 'A' * 64 },
    @{ Label = 'short digest'; MessageDigest = 'a' * 63 },
    @{ Label = 'non-kebab issue key'; IssueKey = 'Hidden Guide' },
    @{ Label = 'unsupported workflow'; Workflow = 'team' },
    @{ Label = 'invalid severity'; Severity = 'urgent' },
    @{ Label = 'unexpected field'; Transcript = 'Synthetic fixture transcript' },
    @{ Label = 'absolute path'; Observed = 'The fixture mentioned C:\private-fixture\notes.txt.' },
    @{ Label = 'obvious secret'; Observed = 'password=fixture-only-placeholder' },
    @{ Label = 'overlong observation'; Observed = 'x' * 501 }
  )) {
    $invalidPayload = $eventPayload.Clone()
    $invalidPayload.messageDigest = '1' * 64
    foreach ($field in $invalid.Keys | Where-Object { $_ -ne 'Label' }) {
      $invalidPayload[$field] = $invalid[$field]
    }
    Set-FeedbackPayload $invalidPayload
    Assert-FeedbackRejected { Invoke-Feedback 'RecordUserEvent' $payloadOption } $invalid.Label
  }
  Assert-Condition (@(Get-FeedbackFiles $eventDirectory).Count -eq 3) `
    'Invalid input left an unexpected persisted event.'

  # Resolve one event. Attempts to include an issue field must leave its original evidence intact.
  $updateOption = @{ EventId = $first.eventId; InputPath = $payloadPath }
  Set-FeedbackPayload $updatePayload
  $traversalOption = @{ EventId = '../' + $first.eventId; InputPath = $payloadPath }
  Assert-FeedbackRejected { Invoke-Feedback 'UpdateUserEvent' $traversalOption } 'event ID traversal'
  $invalidUpdate = $updatePayload.Clone()
  $invalidUpdate.issueKey = 'replacement-issue'
  Set-FeedbackPayload $invalidUpdate
  Assert-FeedbackRejected { Invoke-Feedback 'UpdateUserEvent' $updateOption } 'rewriting issue fields'
  $untouchedEvent = Get-Content -LiteralPath $eventPath -Raw | ConvertFrom-Json
  Assert-Condition ($untouchedEvent.issueKey -eq $eventPayload.issueKey -and
    $untouchedEvent.status -eq 'open') 'A rejected outcome update partially changed the event.'
  Set-FeedbackPayload $updatePayload
  $update = Invoke-Feedback 'UpdateUserEvent' $updateOption
  Assert-Condition ($update.action -eq 'updated') 'A valid outcome update failed.'
  Set-FeedbackPayload $eventPayload
  Invoke-Feedback 'RecordUserEvent' $payloadOption | Out-Null
  $updatedEvent = Get-Content -LiteralPath $eventPath -Raw | ConvertFrom-Json
  Assert-Condition ($updatedEvent.status -eq 'resolved' -and $updatedEvent.result -eq $updatePayload.result) `
    'An event replay lost the updated outcome.'
  foreach ($field in $eventPayload.Keys) {
    Assert-Condition ($updatedEvent.$field -ceq $eventPayload[$field]) `
      "Updating the outcome changed the original event field $field."
  }

  # Opting out stops new writes without hiding or deleting previously captured feedback.
  Invoke-Feedback 'SetUserFeedbackCapture' @{ CaptureState = 'disabled' } | Out-Null
  Assert-Condition (-not (Invoke-Feedback 'UserFeedbackStatus').enabled) `
    'The explicit opt-out was not visible to the next command.'
  $newMessagePayload = $eventPayload.Clone()
  $newMessagePayload.messageDigest = '2' * 64
  Set-FeedbackPayload $newMessagePayload
  $recordAfterOptOut = Invoke-Feedback 'RecordUserEvent' $payloadOption
  Set-FeedbackPayload @{ schemaVersion = 1; status = 'deferred'; result = 'Await review.' }
  $updateAfterOptOut = Invoke-Feedback 'UpdateUserEvent' $updateOption
  Assert-Condition ($recordAfterOptOut.action -eq 'disabled' -and $updateAfterOptOut.action -eq 'disabled') `
    'Opting out did not stop both new writes and outcome mutations.'
  $listed = Invoke-Feedback 'ListUserEvents'
  $retained = @($listed.events | Where-Object id -EQ $first.eventId)
  Assert-Condition (@($listed.events).Count -eq 3 -and $retained.Count -eq 1 `
    -and $retained[0].status -eq 'resolved') 'Opting out hid, removed, or modified stored feedback.'
  $limited = Invoke-Feedback 'ListUserEvents' @{ Limit = 2 }
  Assert-Condition (@($limited.events).Count -eq 2) 'List did not honor its requested event limit.'

  # Manual promotion works while opted out and requires all linked events to exist.
  $promotionPayload = @{
    schemaVersion = 1
    key = 'durable-guide-entry'
    category = 'testing'
    summary = 'Preserve access to the guide after replay.'
    mechanism = 'Check recovery from more than one visitor state.'
    applicability = 'Workflows with resumable onboarding.'
    boundary = 'Only applies to recoverable guide progress.'
    verification = 'Verify active and paused visitors can reopen the guide.'
    eventIds = @($first.eventId, ('0' * 64))
  }
  Set-FeedbackPayload $promotionPayload
  Assert-FeedbackRejected { Invoke-Feedback 'PromoteUserFeedback' $payloadOption } 'unknown event link'
  Assert-Condition (@(Get-FeedbackFiles $candidateDirectory).Count -eq 0) `
    'A promotion with an unknown event link persisted a candidate.'

  # Two messages from one case count once. A new case extends the same confirmed candidate.
  $promotionPayload.eventIds = @($first.eventId, $followUp.eventId)
  Set-FeedbackPayload $promotionPayload
  $promoted = Invoke-Feedback 'PromoteUserFeedback' $payloadOption
  Assert-Condition ($promoted.action -eq 'promoted' -and $promoted.candidateId) `
    'Manual promotion of existing feedback failed while capture was disabled.'
  $candidatePath = Join-Path $candidateDirectory ($promoted.candidateId + '.json')
  $candidate = Get-Content -LiteralPath $candidatePath -Raw | ConvertFrom-Json
  Assert-Condition ($candidate.count -eq 1 -and @($candidate.eventIds).Count -eq 2) `
    'Promotion did not retain both event links while counting their case once.'
  Invoke-Feedback 'SetCandidateState' @{
    CandidateId = $promoted.candidateId
    CandidateState = 'confirmed'
  } | Out-Null
  $promotionPayload.eventIds = @($otherProject.eventId)

  # A distinct mechanism cannot increase the case count through a reused key.
  $previousMechanism = $promotionPayload.mechanism
  $beforeCollision = (Get-FileHash -LiteralPath $candidatePath).Hash
  $promotionPayload.mechanism = 'Check approval persistence across browser restarts.'
  Set-FeedbackPayload $promotionPayload
  Assert-FeedbackRejected { Invoke-Feedback 'PromoteUserFeedback' $payloadOption } 'candidate mechanism collision'
  Assert-Condition ((Get-FileHash -LiteralPath $candidatePath).Hash -eq $beforeCollision) `
    'A different mechanism changed the approved candidate or its evidence.'
  $promotionPayload.mechanism = $previousMechanism
  Set-FeedbackPayload $promotionPayload
  Invoke-Feedback 'PromoteUserFeedback' $payloadOption | Out-Null
  Invoke-Feedback 'PromoteUserFeedback' $payloadOption | Out-Null
  $candidate = Get-Content -LiteralPath $candidatePath -Raw | ConvertFrom-Json
  Assert-Condition (@(Get-FeedbackFiles $candidateDirectory).Count -eq 1 `
    -and $candidate.count -eq 2 -and $candidate.state -eq 'confirmed') `
    'Extending and replaying promotion did not preserve the candidate state and distinct case count.'
  Assert-Condition (@($candidate.eventIds).Count -eq 3) 'Promotion replay introduced duplicate links.'
  foreach ($eventId in @($first.eventId, $followUp.eventId, $otherProject.eventId)) {
    Assert-Condition ($eventId -in $candidate.eventIds) 'Promotion lost a contributing event link.'
  }

  # Re-enabling capture permits a testing-only workflow to record its own observation.
  Invoke-Feedback 'SetUserFeedbackCapture' @{ CaptureState = 'enabled' } | Out-Null
  $verificationPayload = $eventPayload.Clone()
  $verificationPayload.workflow = 'verification-only'
  $verificationPayload.taskDigest = '3' * 64
  $verificationPayload.messageDigest = '4' * 64
  Set-FeedbackPayload $verificationPayload
  $verificationEvent = Invoke-Feedback 'RecordUserEvent' $payloadOption
  Assert-Condition ($verificationEvent.action -eq 'recorded' -and $verificationEvent.eventId) `
    'Capture rejected a valid event from the verification-only workflow.'

  Write-Host 'User feedback runtime tests passed.'
} finally {
  $resolvedRoot = [IO.Path]::GetFullPath($testRoot)
  $resolvedParent = [IO.Path]::GetDirectoryName($resolvedRoot)
  if ($resolvedParent -ne $temporaryParent -or
      -not ([IO.Path]::GetFileName($resolvedRoot).StartsWith($testPrefix))) {
    throw "Refusing to clean unexpected fixture path: $resolvedRoot"
  }
  if (Test-Path -LiteralPath $resolvedRoot) {
    Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
  }
  Assert-Condition (-not (Test-Path -LiteralPath $resolvedRoot)) 'Test fixture cleanup failed.'
}
