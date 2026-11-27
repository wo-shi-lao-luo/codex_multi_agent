# Implement opt-in user event capture and case-linked candidate promotion for
# feedback-runtime.ps1. Loading this helper performs no store I/O.

# Parse the flat feedback format without coercing JSON dates or accepting duplicate
# properties. Intake files are capped before parsing. Stored candidate links can
# grow across promotions and use the same reader without the intake cap.
function Read-UserFeedbackJson {
  param([string]$Path, [switch]$Intake)

  Assert-TeamPlainPath $Path
  try {
    $share = [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete
    $file = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, $share)
    try {
      if ($Intake -and $file.Length -gt 32KB) {
        throw 'Feedback input exceeds 32 KiB.'
      }
      $reader = [IO.StreamReader]::new($file, [Text.UTF8Encoding]::new($false, $true))
      try {
        $document = [System.Text.Json.JsonDocument]::Parse(
          $reader.ReadToEnd(), [System.Text.Json.JsonDocumentOptions]::new()
        )
      } finally {
        $reader.Dispose()
      }
    } finally {
      $file.Dispose()
    }
    try {
      $fields = New-TeamOrdinalMap
      foreach ($property in $document.RootElement.EnumerateObject()) {
        $value = $property.Value
        $fields.Add($property.Name, $(switch ($value.ValueKind) {
          'String' { $value.GetString() }
          'Number' { $value.GetInt32() }
          'True' { $true }
          'False' { $false }
          'Array' {
            ,@($value.EnumerateArray() | ForEach-Object {
              if ($_.ValueKind -ne 'String') {
                throw 'Feedback arrays must contain strings.'
              }
              $_.GetString()
            })
          }
          default { throw 'Unsupported feedback field type.' }
        }))
      }
      return $fields
    } finally {
      $document.Dispose()
    }
  } catch {
    # JSON parser and filesystem exceptions may include input or local path names.
    throw 'USER_FEEDBACK: Could not read a valid feedback JSON object.'
  }
}

# Validate exact fields with case-sensitive keys and require schema version 1.
function Assert-UserFeedbackFields {
  param([hashtable]$Fields, [string[]]$Names)

  if ($Fields.Count -ne $Names.Count) {
    throw 'USER_FEEDBACK: Unexpected or missing fields.'
  }
  foreach ($name in $Names) {
    if (-not $Fields.ContainsKey($name)) {
      throw "USER_FEEDBACK: Missing required field $name."
    }
  }
  if ($Fields.schemaVersion -isnot [int] -or $Fields.schemaVersion -ne 1) {
    throw 'USER_FEEDBACK: schemaVersion must be the integer 1.'
  }
}

# Resolve a caller-provided intake filename using PowerShell's current directory.
# Reject alternate streams and linked paths before opening the plain file.
function Read-UserFeedbackInput {
  param([string]$InputPath)

  if ([string]::IsNullOrWhiteSpace($InputPath)) {
    throw 'USER_FEEDBACK: This action requires -InputPath.'
  }
  $resolved = Resolve-Path -LiteralPath $InputPath -ErrorAction SilentlyContinue
  if ($null -eq $resolved -or $resolved.Provider.Name -ne 'FileSystem' -or
      -not (Test-Path -LiteralPath $resolved.ProviderPath -PathType Leaf)) {
    throw 'USER_FEEDBACK: InputPath must be a plain file.'
  }
  $directory = [IO.Path]::GetDirectoryName($resolved.ProviderPath)
  $name = [IO.Path]::GetFileName($resolved.ProviderPath)
  $path = Resolve-TeamContainedPath $directory $name
  return Read-UserFeedbackJson -Path $path -Intake
}

# This checks obvious credential and absolute path markers. The caller remains
# responsible for semantic redaction of names, snippets and identifying context.
function Assert-UserFeedbackSummary {
  param($Value, [string]$Name, [switch]$AllowEmpty)

  if ($Value -isnot [string] -or $Value.Length -gt 500 -or
      (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($Value))) {
    throw "USER_FEEDBACK: $Name must be a bounded summary of at most 500 characters."
  }
  $pathMarkers = '(?:\b[A-Z]:[\\/]|\\\\|' +
    '(?:^|[\s"''\p{Pi}\p{Ps}=:\uFF1A\x60])(?:~[/\\]|/[^\s/])|://)'
  # Recognize bare credential prefixes at token starts so words such as
  # task-coordination do not look like credentials.
  $secretMarkers = '(?:-----BEGIN|(?:api[-_ ]?key|password|token|secret)\s*[:=]\s*\S|' +
    '(?<![A-Za-z0-9_])(?:Bearer\s+\S{8,}|(?:sk-|gh[pousr]_|github_pat_)[A-Za-z0-9_-]{8,}))'
  if ($Value -match '[\p{Cc}]|\x60{3}' -or $Value -match $pathMarkers -or
      $Value -match $secretMarkers) {
    throw "USER_FEEDBACK: $Name contains an unsupported sensitive-data or copy marker."
  }
}

function Assert-UserFeedbackDigest {
  param($Value, [string]$Name)

  if ($Value -isnot [string] -or $Value -cnotmatch '\A[0-9a-f]{64}\z') {
    throw "USER_FEEDBACK: $Name must be 64 lowercase hex characters."
  }
}

function Assert-UserFeedbackKey {
  param($Value, [string]$Name)

  if ($Value -isnot [string] -or $Value.Length -gt 64 -or
      $Value -cnotmatch '\A[a-z0-9]+(?:-[a-z0-9]+)*\z') {
    throw "USER_FEEDBACK: $Name must be a lowercase kebab key of at most 64 characters."
  }
}

# An absent opt-in file is disabled. Malformed existing settings fail closed.
function Get-UserFeedbackEnabled {
  param([string]$Store)

  $settings = Resolve-TeamContainedPath $Store 'feedback/user-feedback-settings.json'
  if (-not (Test-Path -LiteralPath $settings)) { return $false }
  $value = Read-UserFeedbackJson -Path $settings
  Assert-UserFeedbackFields $value @('schemaVersion', 'enabled')
  if ($value.enabled -isnot [bool]) {
    throw 'USER_FEEDBACK: Capture settings must contain a boolean enabled value.'
  }
  return $value.enabled
}

# Strictly separate event intake from workflow run feedback; only the named
# redacted fields enter the stored event.
function Read-UserFeedbackEventPayload {
  param([string]$InputPath, [switch]$Update)

  $payload = Read-UserFeedbackInput -InputPath $InputPath
  if ($Update) {
    Assert-UserFeedbackFields $payload @('schemaVersion', 'status', 'result')
    Assert-UserFeedbackOutcome $payload
    return $payload
  }

  Assert-UserFeedbackEventPayload $payload
  return $payload
}

# A persisted record must still satisfy the original intake contract before a
# replay can use its file as evidence of an earlier successful write.
function Assert-UserFeedbackEventPayload {
  param([hashtable]$Payload, [switch]$Persisted)

  $fields = @(
    'schemaVersion', 'workflow', 'projectDigest', 'sessionDigest', 'taskDigest',
    'messageDigest', 'issueKey', 'kitVersion', 'observed', 'expected', 'impact', 'severity'
  )
  if ($Persisted) {
    $fields += @('id', 'caseId', 'recordedAt', 'updatedAt', 'status', 'result')
  }
  Assert-UserFeedbackFields $Payload $fields
  $workflows = @(
    'team-dev', 'team-plan', 'team-debug', 'team-review', 'verification-only',
    'team-code-maintain', 'team-doc-check', 'team-project-rules', 'team-ai-simulate',
    'team-delivery-check'
  )
  if ($payload.workflow -isnot [string] -or $payload.workflow -cnotin $workflows) {
    throw 'USER_FEEDBACK: Unsupported workflow.'
  }
  foreach ($name in @('projectDigest', 'sessionDigest', 'taskDigest', 'messageDigest')) {
    Assert-UserFeedbackDigest $payload[$name] $name
  }
  Assert-UserFeedbackKey $payload.issueKey 'issueKey'
  $versionPattern = '\A(?:unknown|[0-9]+\.[0-9]+\.[0-9]+' +
    '(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?)\z'
  if ($payload.kitVersion -isnot [string] -or $payload.kitVersion.Length -gt 48 -or
      $payload.kitVersion -cnotmatch $versionPattern) {
    throw 'USER_FEEDBACK: kitVersion must be a short version or unknown.'
  }
  if ($payload.severity -isnot [string] -or $payload.severity -cnotin @('normal', 'high')) {
    throw 'USER_FEEDBACK: Unsupported severity.'
  }
  Assert-UserFeedbackSummary $payload.observed 'observed'
  Assert-UserFeedbackSummary $payload.expected 'expected' -AllowEmpty
  Assert-UserFeedbackSummary $payload.impact 'impact' -AllowEmpty
  if ($Persisted) {
    Assert-UserFeedbackOutcome $Payload
    foreach ($name in @('recordedAt', 'updatedAt')) {
      $value = $Payload[$name]
      if ($value -isnot [string] -or
          $value -cnotmatch '\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{7}Z\z') {
        throw 'USER_FEEDBACK: Invalid persisted event timestamp.'
      }
    }
  }
}

# Keep the stored outcome and its update request on the same bounded contract.
function Assert-UserFeedbackOutcome {
  param([hashtable]$Payload)

  if ($Payload.status -isnot [string] -or
      $Payload.status -cnotin @('open', 'investigating', 'resolved', 'deferred')) {
    throw 'USER_FEEDBACK: Unsupported result status.'
  }
  Assert-UserFeedbackSummary $Payload.result 'result' -AllowEmpty
}

# Derive the same receipt identifiers for direct storage and a relayed payload
# before the receiving chat has made any changes.
function Get-UserFeedbackEventIdentity {
  param([hashtable]$Payload)

  $caseKey = @(
    $Payload.projectDigest, $Payload.sessionDigest, $Payload.taskDigest, $Payload.issueKey
  ) -join ':'
  $caseId = Get-HashId "user-feedback-case:$caseKey"
  return @{
    caseId = $caseId
    eventId = Get-HashId "user-feedback-event:$($caseId):$($Payload.messageDigest)"
  }
}

# Check the contents against the pending receipt under the caller's store lock.
# A corrupt or unrelated plain file must never be acknowledged or replaced.
function Assert-UserFeedbackDuplicate {
  param([string]$Path, [hashtable]$Expected)

  try {
    $stored = Read-UserFeedbackJson -Path $Path -Intake
    Assert-UserFeedbackEventPayload -Payload $stored -Persisted
    $identity = Get-UserFeedbackEventIdentity $stored
    if ($stored.id -cne $Expected.eventId -or $stored.caseId -cne $Expected.caseId -or
        $identity.eventId -cne $Expected.eventId -or $identity.caseId -cne $Expected.caseId) {
      throw 'Stored event identity did not match.'
    }
  } catch {
    throw 'USER_FEEDBACK: Existing event cannot verify the duplicate receipt.'
  }
}

# Record once per message and issue. Routed events enter with a prevalidated
# payload and separate consent store. Updates leave the original report intact.
function Save-UserFeedbackEvent {
  param(
    [string]$Store,
    [string]$InputPath,
    [string]$EventId,
    [switch]$Update,
    [hashtable]$Payload,
    [string]$ConsentStore = $Store,
    [hashtable]$ReceiverBinding
  )

  if (-not (Get-UserFeedbackEnabled $ConsentStore)) { return @{ action = 'disabled' } }
  if ($Update) { Assert-UserFeedbackDigest $EventId 'EventId' }
  if ($null -eq $Payload) {
    $Payload = Read-UserFeedbackEventPayload -InputPath $InputPath -Update:$Update
  }

  $storeLock = Enter-FeedbackStoreLock -Store $Store
  try {
    # Recheck consent and the expected route after a potential wait on this store.
    if (-not (Get-UserFeedbackEnabled $ConsentStore)) { return @{ action = 'disabled' } }
    if ($ReceiverBinding) {
      $currentBinding = Get-UserFeedbackReceiverBinding $ConsentStore
      if (-not (Test-UserFeedbackReceiverBinding $currentBinding $ReceiverBinding)) {
        return @{ action = 'unconfigured' }
      }
    }
    $now = Get-UtcTimestamp
    if ($Update) {
      $eventPath = Resolve-TeamContainedPath $Store "feedback/user-events/$EventId.json"
      if (-not (Test-Path -LiteralPath $eventPath -PathType Leaf)) {
        throw 'USER_FEEDBACK: Event not found.'
      }
      $event = Read-UserFeedbackJson -Path $eventPath
      $event.status = $payload.status
      $event.result = $payload.result
      $action = 'updated'
    } else {
      $identity = Get-UserFeedbackEventIdentity $Payload
      $EventId = $identity.eventId
      $eventPath = Resolve-TeamContainedPath $Store "feedback/user-events/$EventId.json"
      if (Test-Path -LiteralPath $eventPath -PathType Leaf) {
        Assert-UserFeedbackDuplicate -Path $eventPath -Expected $identity
        return @{ action = 'duplicate'; eventId = $EventId; caseId = $identity.caseId }
      }
      $event = $payload
      $event.caseId = $identity.caseId
      $event.id = $EventId
      $event.recordedAt = $now
      $event.status = 'open'
      $event.result = ''
      $action = 'recorded'
    }
    $event.updatedAt = $now
    Write-AtomicJson -Path $eventPath -Value $event
    return @{ action = $action; eventId = $EventId; caseId = $event.caseId }
  } finally {
    $storeLock.Dispose()
  }
}

# Return recent persisted events even when capture is disabled. Only event files
# are eligible; atomic-write temporaries never enter the result.
function Get-UserFeedbackEvents {
  param([string]$Store, [int]$Limit)

  $directory = Resolve-TeamContainedPath $Store 'feedback/user-events'
  $limit = [Math]::Clamp($Limit, 1, 500)
  $files = @()
  if (Test-Path -LiteralPath $directory) {
    $files = @(Get-ChildItem -LiteralPath $directory -Filter '*.json' -File |
      Where-Object { $_.Name -cmatch '\A[0-9a-f]{64}\.json\z' } |
      Sort-Object LastWriteTimeUtc, Name -Descending)
  }
  $events = @($files | Select-Object -First $limit | ForEach-Object {
    Read-UserFeedbackJson -Path $_.FullName
  })
  return @{ events = $events; truncated = $files.Count -gt $limit }
}

# Promotion needs an explicit, separately analyzed payload with real evidence links.
function Read-UserFeedbackPromotion {
  param([string]$InputPath)

  $payload = Read-UserFeedbackInput -InputPath $InputPath
  Assert-UserFeedbackFields $payload @(
    'schemaVersion', 'key', 'category', 'summary', 'mechanism', 'applicability',
    'boundary', 'verification', 'eventIds'
  )
  Assert-UserFeedbackKey $payload.key 'key'
  Assert-UserFeedbackKey $payload.category 'category'
  foreach ($name in @('summary', 'mechanism', 'applicability', 'boundary', 'verification')) {
    Assert-UserFeedbackSummary $payload[$name] $name
  }
  if ($payload.eventIds -isnot [array] -or $payload.eventIds.Count -lt 1 -or
      $payload.eventIds.Count -gt 100) {
    throw 'USER_FEEDBACK: eventIds must be an array of 1 to 100 event IDs.'
  }
  foreach ($eventId in $payload.eventIds) {
    Assert-UserFeedbackDigest $eventId 'eventIds entry'
  }
  return $payload
}

# Caller holds the shared store lock. Count independent cases, retain traceable
# links and leave promotion separate from any candidate state transition.
function Save-UserFeedbackCandidate {
  param([string]$Store, [hashtable]$Promotion)

  $newEventIds = @($Promotion.eventIds | Sort-Object -Unique)
  $newCaseIds = @(foreach ($eventId in $newEventIds) {
    $eventPath = Resolve-TeamContainedPath $Store "feedback/user-events/$eventId.json"
    if (-not (Test-Path -LiteralPath $eventPath -PathType Leaf)) {
      throw 'USER_FEEDBACK: A promoted event does not exist.'
    }
    $event = Read-UserFeedbackJson -Path $eventPath
    Assert-UserFeedbackDigest $event.caseId 'caseId'
    $event.caseId
  })

  $key = 'user-feedback:' + $Promotion.key
  $candidateId = Get-HashId $key
  $candidatePath = Resolve-TeamContainedPath $Store "feedback/candidates/$candidateId.json"
  $now = Get-UtcTimestamp
  if (Test-Path -LiteralPath $candidatePath) {
    $candidate = Read-UserFeedbackJson -Path $candidatePath
    if ($candidate.eventIds -isnot [array] -or $candidate.caseIds -isnot [array]) {
      throw 'USER_FEEDBACK: Candidate key collides with existing workflow feedback.'
    }
    # A shared key can collect more evidence only for the same analyzed mechanism
    # and scope. Keep the existing analysis and state when adding links.
    foreach ($name in @('category', 'mechanism', 'applicability', 'boundary')) {
      if ($candidate[$name] -cne $Promotion[$name]) {
        throw "USER_FEEDBACK: Existing candidate has a different $name; use a distinct key."
      }
    }
    $eventIds = @($candidate.eventIds + $newEventIds | Sort-Object -Unique)
    if ($eventIds.Count -eq $candidate.eventIds.Count) {
      return @{ action = 'duplicate'; candidateId = $candidateId; caseCount = $candidate.count }
    }
    $candidate.eventIds = $eventIds
    $candidate.caseIds = @($candidate.caseIds + $newCaseIds | Sort-Object -Unique)
  } else {
    $candidate = @{
      schemaVersion = 1
      id = $candidateId
      key = $key
      category = $Promotion.category
      summary = $Promotion.summary
      mechanism = $Promotion.mechanism
      applicability = $Promotion.applicability
      boundary = $Promotion.boundary
      verification = $Promotion.verification
      state = 'candidate'
      firstObservedAt = $now
      runIds = @()
      eventIds = $newEventIds
      caseIds = @($newCaseIds | Sort-Object -Unique)
    }
  }
  $candidate.count = $candidate.caseIds.Count
  $candidate.lastObservedAt = $now
  Write-AtomicJson -Path $candidatePath -Value $candidate
  return @{ action = 'promoted'; candidateId = $candidateId; caseCount = $candidate.count }
}
