# Check the receiver workflow through public commands in isolated Git worktrees.
#requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
. (Join-Path $PSScriptRoot 'helpers/platform.ps1')

$runtime = Join-Path (Split-Path -Parent $PSScriptRoot) 'skills/team-core/scripts/feedback-runtime.ps1'
$parent = Get-TestTemporaryParent
$prefix = 'codex-team-feedback-receiver-test-'
$fixture = Join-Path $parent ($prefix + [guid]::NewGuid().ToString('N'))
$consentHome = Join-Path $fixture 'user-home'
$receiverRoot = Join-Path $fixture 'receiver'
$otherRoot = Join-Path $fixture 'other'
$archive = Join-Path $receiverRoot '_work/team-feedback'
$eventDirectory = Join-Path $archive 'feedback/user-events'
$bindingPath = Join-Path $fixture 'binding.json'
$payloadPath = Join-Path $fixture 'event.json'
$sourceChat = 'source-chat-001'
$receiverChat = 'receiver-chat-001'
$receiverHost = 'test-host-001'
$receiverProject = 'test-project-001'

function Assert-Condition([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Get-TestDigest([string]$Value) {
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    $digest = $sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value))
    return [BitConverter]::ToString($digest).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha256.Dispose()
  }
}

function Set-JsonFixture([string]$Path, $Value) {
  $Value | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Invoke-Feedback([string]$Action, [hashtable]$Arguments = @{}) {
  $response = & $runtime -Action $Action -FeedbackHome $consentHome -Confirm:$false @Arguments
  return ($response | Out-String | ConvertFrom-Json -ErrorAction Stop)
}

function Assert-ReceiverRejected([hashtable]$Arguments, [string]$Scenario) {
  try {
    Invoke-Feedback 'ReceiveUserFeedback' $Arguments | Out-Null
  } catch {
    $errorMessage = $_.Exception.Message
    if ($errorMessage -notmatch '^(USER_FEEDBACK[^:]*|PATH):') { throw }
    Assert-Condition (-not $errorMessage.Contains($fixture)) 'Rejection exposed a local path.'
    return
  }
  throw "Expected receiver rejection for $Scenario."
}

function Invoke-FixtureGit([string]$Path, [string[]]$Arguments) {
  & git -C $Path @Arguments | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "TEST_SETUP: Git fixture failed on $($Arguments[0])." }
}

try {
  $null = New-Item -ItemType Directory -Path $fixture

  # Reading an untouched installation's routing status must not create state.
  $fresh = Invoke-Feedback 'GetUserFeedbackReceiver'
  Assert-Condition ($fresh.enabled -eq $false -and $null -eq $fresh.receiver) `
    'An unconfigured installation reported an enabled receiver.'
  Assert-Condition (-not (Test-Path -LiteralPath $consentHome)) `
    'Checking receiver status created state.'

  foreach ($projectRoot in @($receiverRoot, $otherRoot)) {
    $null = New-Item -ItemType Directory -Path $projectRoot
    Invoke-FixtureGit $projectRoot @('init', '--quiet')
    '/_work/' | Set-Content -LiteralPath (Join-Path $projectRoot '.gitignore') -Encoding utf8
  }
  $binding = @{
    schemaVersion = 1
    threadId = $receiverChat
    hostId = $receiverHost
    projectId = $receiverProject
    projectRootDigest = Get-TestDigest $receiverRoot
  }
  Set-JsonFixture $bindingPath $binding
  $bindingOptions = @{ InputPath = $bindingPath }
  $payload = @{
    schemaVersion = 1
    workflow = 'team-dev'
    projectDigest = 'a' * 64
    sessionDigest = Get-TestDigest $sourceChat
    taskDigest = 'c' * 64
    messageDigest = 'd' * 64
    issueKey = 'missing-filter-reset'
    kitVersion = '2.0.7'
    observed = 'The filter reset action removed the selection.'
    expected = 'The selection survives a filter reset.'
    impact = 'The user had to choose the item again.'
    severity = 'normal'
  }
  Set-JsonFixture $payloadPath $payload
  $prepareOptions = @{ InputPath = $payloadPath }
  $receiveOptions = @{
    InputPath = $payloadPath
    ProjectRoot = $receiverRoot
    ReceiverThreadId = $receiverChat
    ReceiverHostId = $receiverHost
    ReceiverProjectId = $receiverProject
    SourceThreadId = $sourceChat
    ExpectedEventId = '0' * 64
  }

  # A preview of the route change must leave both settings and receiver storage absent.
  & $runtime -Action SetUserFeedbackReceiver -FeedbackHome $consentHome -InputPath $bindingPath -WhatIf |
    Out-Null
  Assert-Condition (-not (Test-Path -LiteralPath $consentHome)) 'Preview wrote receiver settings.'

  # Capture preference applies to both sender preparation and receiver writes.
  Invoke-Feedback 'SetUserFeedbackReceiver' $bindingOptions | Out-Null
  $disabledSend = Invoke-Feedback 'PrepareUserFeedbackDelivery' $prepareOptions
  $disabledReceive = Invoke-Feedback 'ReceiveUserFeedback' $receiveOptions
  Assert-Condition ($disabledSend.action -eq 'disabled' -and $disabledReceive.action -eq 'disabled') `
    'A configured receiver ignored the opt-out.'
  Assert-Condition (-not (Test-Path -LiteralPath $archive)) 'Opt-out created a receiver archive.'

  # A valid preparation exposes deterministic receipt IDs and touches neither event store.
  Invoke-Feedback 'SetUserFeedbackCapture' @{ CaptureState = 'enabled' } | Out-Null
  $status = Invoke-Feedback 'GetUserFeedbackReceiver'
  Assert-Condition ($status.enabled -eq $true -and $status.receiver.threadId -ceq $receiverChat) `
    'The explicit binding was not visible to a later invocation.'
  $prepared = Invoke-Feedback 'PrepareUserFeedbackDelivery' $prepareOptions
  Assert-Condition ($prepared.action -eq 'ready' -and $prepared.receiver.hostId -ceq $receiverHost) `
    'Preparation did not return the bound destination.'
  $digestPattern = '^[a-f0-9]{64}$'
  Assert-Condition ($prepared.eventId -cmatch $digestPattern -and $prepared.caseId -cmatch $digestPattern) `
    'Preparation did not return deterministic receipt identifiers.'
  $receiveOptions.ExpectedEventId = $prepared.eventId
  Assert-Condition ($prepared.event.observed -ceq $payload.observed) 'Preparation lost the observation.'
  Assert-Condition (-not (Test-Path -LiteralPath $archive)) 'Preparing delivery created an archive.'
  $directEvents = Join-Path $consentHome 'feedback/user-events'
  Assert-Condition (-not (Test-Path -LiteralPath $directEvents)) `
    'Preparing delivery wrote an event to the consent store.'

  # Wrong native identity, checkout or sender must fail before creating any archive.
  $mismatches = @{
    ReceiverThreadId = 'wrong-chat'
    ReceiverHostId = 'wrong-host'
    ReceiverProjectId = 'wrong-project'
    ProjectRoot = $otherRoot
    SourceThreadId = 'wrong-source'
    ExpectedEventId = '0' * 64
  }
  foreach ($identity in $mismatches.Keys) {
    $wrong = $receiveOptions.Clone()
    $wrong[$identity] = $mismatches[$identity]
    Assert-ReceiverRejected $wrong $identity
  }
  $self = $receiveOptions.Clone()
  $self.SourceThreadId = $receiverChat
  $selfPayload = $payload.Clone()
  $selfPayload.sessionDigest = Get-TestDigest $receiverChat
  Set-JsonFixture $payloadPath $selfPayload
  $self.ExpectedEventId = (Invoke-Feedback 'PrepareUserFeedbackDelivery' $prepareOptions).eventId
  Assert-ReceiverRejected $self 'receiver originating its own delivery'
  Assert-Condition (-not (Test-Path -LiteralPath $archive)) 'A blocked route created an archive.'
  Assert-Condition (-not (Test-Path -LiteralPath (Join-Path $otherRoot '_work'))) `
    'A blocked route touched the other worktree.'

  # A nested folder can match a binding digest without being the worktree root.
  $nestedPath = Join-Path $receiverRoot 'subdirectory'
  $null = New-Item -ItemType Directory -Path $nestedPath
  $nestedBinding = $binding.Clone()
  $nestedBinding.projectRootDigest = Get-TestDigest $nestedPath
  Set-JsonFixture $bindingPath $nestedBinding
  Invoke-Feedback 'SetUserFeedbackReceiver' $bindingOptions | Out-Null
  Set-JsonFixture $payloadPath $payload
  $nested = $receiveOptions.Clone()
  $nested.ProjectRoot = $nestedPath
  Assert-ReceiverRejected $nested 'non-root destination'
  Set-JsonFixture $bindingPath $binding
  Invoke-Feedback 'SetUserFeedbackReceiver' $bindingOptions | Out-Null
  Assert-Condition (-not (Test-Path -LiteralPath (Join-Path $nestedPath '_work'))) `
    'A nested destination received an archive.'

  # The receiver revalidates forwarded text and rejects a private absolute path.
  $invalid = $payload.Clone()
  $invalid.observed = 'The output contains a path at C:\private\fixture.md.'
  Set-JsonFixture $payloadPath $invalid
  Assert-ReceiverRejected $receiveOptions 'private data in forwarded summary'
  Assert-Condition (-not (Test-Path -LiteralPath $archive)) 'Invalid text created an archive.'
  Set-JsonFixture $payloadPath $payload

  # An explicit ignore negation, or a tracked artifact, makes this route unsafe.
  $ignore = Join-Path $receiverRoot '.gitignore'
  @('/_work/*', '!/_work/team-feedback/') | Set-Content -LiteralPath $ignore -Encoding utf8
  Assert-ReceiverRejected $receiveOptions 'negative ignore rule'
  Assert-Condition (-not (Test-Path -LiteralPath $archive)) 'An unignored route created an archive.'
  '/_work/' | Set-Content -LiteralPath $ignore -Encoding utf8

  # A linked archive must not send the event to a different local directory.
  $null = New-Item -ItemType Directory -Path (Split-Path -Parent $archive)
  $redirected = Join-Path $fixture 'redirected'
  $null = New-Item -ItemType Directory -Path $redirected
  $linkCreated = $false
  try {
    New-TestDirectoryLink $archive $redirected
    $linkCreated = $true
  } catch {
    if (-not $IsWindows -or ($_.CategoryInfo.Category -ne 'PermissionDenied' -and
        $_.Exception.Message -notmatch 'privilege|Access is denied|拒绝访问')) { throw }
    Write-Host 'SKIP linked receiver directory: Windows refused creation of the test junction.'
  }
  if ($linkCreated) {
    try {
      Assert-ReceiverRejected $receiveOptions 'linked archive'
      Assert-Condition (@(Get-ChildItem -LiteralPath $redirected -Force).Count -eq 0) `
        'A linked archive wrote to the alternate directory.'
    } finally {
      Remove-TestLink $archive
    }
  }

  # With normal directory access restored, a tracked placeholder still blocks writes.
  $null = New-Item -ItemType Directory -Path $archive
  $tracked = Join-Path $archive 'fixture-tracked.txt'
  'Synthetic placeholder' | Set-Content -LiteralPath $tracked -Encoding utf8
  Invoke-FixtureGit $receiverRoot @('add', '-f', '--', '_work/team-feedback/fixture-tracked.txt')
  Assert-ReceiverRejected $receiveOptions 'tracked file under the ignored archive'
  Assert-Condition (-not (Test-Path -LiteralPath $eventDirectory)) 'A tracked route wrote feedback.'
  Invoke-FixtureGit $receiverRoot @('rm', '--cached', '-f', '--', '_work/team-feedback/fixture-tracked.txt')
  Remove-Item -LiteralPath $tracked

  # A replay returns the previously stored receipt, and a new message creates a distinct event.
  $recorded = Invoke-Feedback 'ReceiveUserFeedback' $receiveOptions
  $replayed = $payload.Clone()
  $replayed.observed = 'The repeated delivery has different wording.'
  Set-JsonFixture $payloadPath $replayed
  $duplicate = Invoke-Feedback 'ReceiveUserFeedback' $receiveOptions
  Assert-Condition ($recorded.action -eq 'recorded' -and $recorded.eventId -ceq $prepared.eventId `
    -and $recorded.caseId -ceq $prepared.caseId) 'The stored receipt differed from preparation.'
  Assert-Condition ($duplicate.action -eq 'duplicate' -and $duplicate.eventId -ceq $recorded.eventId) `
    'A replay did not return the original receipt.'
  $storedPath = Join-Path $eventDirectory ($recorded.eventId + '.json')
  $stored = Get-Content -LiteralPath $storedPath -Raw | ConvertFrom-Json
  Assert-Condition ($stored.observed -ceq $payload.observed -and $stored.sessionDigest -ceq $payload.sessionDigest) `
    'The receiver did not retain the original observation and hashed source.'

  # An existing file is not a receipt unless it holds the expected persisted event.
  # Leave corrupt and foreign data untouched so a later delivery cannot silently replace it.
  $validEventBytes = [IO.File]::ReadAllBytes($storedPath)
  $foreign = Get-Content -LiteralPath $storedPath -Raw | ConvertFrom-Json -AsHashtable
  $foreign.id = '9' * 64
  $invalidReplays = @(
    @{ Label = 'malformed persisted event'; Contents = '{"observed":' }
    @{ Label = 'foreign persisted event'; Contents = ($foreign | ConvertTo-Json -Depth 6) }
  )
  try {
    foreach ($invalidReplay in $invalidReplays) {
      [IO.File]::WriteAllText($storedPath, $invalidReplay.Contents)
      Assert-ReceiverRejected $receiveOptions $invalidReplay.Label
      Assert-Condition ([IO.File]::ReadAllText($storedPath) -ceq $invalidReplay.Contents) `
        'A replay altered the invalid persisted event.'
    }
  } finally {
    [IO.File]::WriteAllBytes($storedPath, $validEventBytes)
  }

  # A later message is separate evidence for the same case.
  $followUp = $payload.Clone()
  $followUp.messageDigest = 'e' * 64
  Set-JsonFixture $payloadPath $followUp
  $receiveOptions.ExpectedEventId = (Invoke-Feedback 'PrepareUserFeedbackDelivery' $prepareOptions).eventId
  $receivedFollowUp = Invoke-Feedback 'ReceiveUserFeedback' $receiveOptions
  Assert-Condition ($receivedFollowUp.action -eq 'recorded' -and $receivedFollowUp.eventId -cne $recorded.eventId `
    -and $receivedFollowUp.caseId -ceq $recorded.caseId) 'Distinct messages did not share the same case.'

  # Another source chat can deliver independently, even with the same issue key.
  $otherSource = $receiveOptions.Clone()
  $otherSource.SourceThreadId = 'source-chat-002'
  $otherEvent = $payload.Clone()
  $otherEvent.sessionDigest = Get-TestDigest $otherSource.SourceThreadId
  Set-JsonFixture $payloadPath $otherEvent
  $otherSource.ExpectedEventId = (Invoke-Feedback 'PrepareUserFeedbackDelivery' $prepareOptions).eventId
  $receivedOther = Invoke-Feedback 'ReceiveUserFeedback' $otherSource
  Assert-Condition ($receivedOther.action -eq 'recorded' -and $receivedOther.caseId -cne $recorded.caseId) `
    'Feedback from two source chats was conflated.'
  Assert-Condition (@(Get-ChildItem -LiteralPath $eventDirectory -File -Filter '*.json').Count -eq 3) `
    'The receiver stored an unexpected number of events.'
  $archiveEvents = & $runtime -Action ListUserEvents -FeedbackHome $archive |
    Out-String | ConvertFrom-Json -ErrorAction Stop
  Assert-Condition (@($archiveEvents.events).Count -eq 3) 'The receiving archive could not be reviewed.'
  Assert-Condition (-not (Test-Path -LiteralPath $directEvents)) 'Receiver used the default local archive.'

  # Changing the receiver stops old deliveries. Clearing preserves data and restores direct mode.
  Set-JsonFixture $payloadPath $followUp
  $rebound = $binding.Clone()
  $rebound.threadId = 'receiver-chat-002'
  Set-JsonFixture $bindingPath $rebound
  Invoke-Feedback 'SetUserFeedbackReceiver' $bindingOptions | Out-Null
  Assert-ReceiverRejected $receiveOptions 'stale receiver after rebinding'
  Invoke-Feedback 'ClearUserFeedbackReceiver' | Out-Null
  $cleared = Invoke-Feedback 'PrepareUserFeedbackDelivery' $prepareOptions
  Assert-Condition ($cleared.action -eq 'unconfigured') 'Clearing did not remove the route.'
  $receivedAfterClear = Invoke-Feedback 'ReceiveUserFeedback' $receiveOptions
  Assert-Condition ($receivedAfterClear.action -eq 'unconfigured') 'Clearing did not stop pending delivery.'
  Assert-Condition (@(Get-ChildItem -LiteralPath $eventDirectory -File -Filter '*.json').Count -eq 3) `
    'Clearing removed or changed delivered events.'
  $direct = Invoke-Feedback 'RecordUserEvent' $prepareOptions
  Assert-Condition ($direct.action -eq 'recorded' -and $direct.eventId -ceq $receivedFollowUp.eventId) `
    'The original direct mode or receipt identity changed.'

  Write-Host 'User feedback receiver tests passed.'
} finally {
  $resolved = [IO.Path]::GetFullPath($fixture)
  if ([IO.Path]::GetDirectoryName($resolved) -ne $parent -or
      -not ([IO.Path]::GetFileName($resolved).StartsWith($prefix))) {
    throw 'Refusing to clean an unexpected fixture path.'
  }
  if (Test-Path -LiteralPath $resolved) {
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
  Assert-Condition (-not (Test-Path -LiteralPath $resolved)) 'Test fixture cleanup failed.'
}
