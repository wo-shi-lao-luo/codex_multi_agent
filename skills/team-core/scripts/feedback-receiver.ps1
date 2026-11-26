# Validate explicit feedback relay bindings and persist accepted events in the
# bound worktree. The caller proves native chat identities and handles transport.

function Get-UserFeedbackReceiverPath {
  param([string]$ConsentStore)

  return Resolve-TeamContainedPath $ConsentStore 'feedback/user-feedback-receiver.json'
}

# Validate an exact receiver binding before publishing or using it. The root
# digest is SHA-256 of the canonical path's exact UTF-8 bytes, including case.
function Assert-UserFeedbackReceiverBinding {
  param([hashtable]$Binding)

  Assert-UserFeedbackFields $Binding @(
    'schemaVersion', 'threadId', 'hostId', 'projectId', 'projectRootDigest'
  )
  foreach ($field in @('threadId', 'hostId', 'projectId')) {
    if ($Binding[$field] -isnot [string] -or
        $Binding[$field] -cnotmatch '\A[A-Za-z0-9][A-Za-z0-9._:-]{0,255}\z') {
      throw "USER_FEEDBACK_RECEIVER: Invalid $field."
    }
  }
  Assert-UserFeedbackDigest $Binding.projectRootDigest 'projectRootDigest'
}

# Read the local opt-in destination without writing or guessing one.
function Get-UserFeedbackReceiverBinding {
  param([string]$ConsentStore)

  $bindingPath = Get-UserFeedbackReceiverPath $ConsentStore
  if (-not (Test-Path -LiteralPath $bindingPath)) { return $null }
  $binding = Read-UserFeedbackJson -Path $bindingPath -Intake
  Assert-UserFeedbackReceiverBinding $binding
  return $binding
}

function Test-UserFeedbackReceiverBinding {
  param([hashtable]$Current, [hashtable]$Expected)

  return $null -ne $Current -and
    $Current.threadId -ceq $Expected.threadId -and
    $Current.hostId -ceq $Expected.hostId -and
    $Current.projectId -ceq $Expected.projectId -and
    $Current.projectRootDigest -ceq $Expected.projectRootDigest
}

# Prepare validated data and expected IDs for the host caller to dispatch. A
# response with action=ready does not mean any chat or store accepted it.
function New-UserFeedbackDelivery {
  param([string]$ConsentStore, [string]$InputPath)

  if (-not (Get-UserFeedbackEnabled $ConsentStore)) { return @{ action = 'disabled' } }
  $binding = Get-UserFeedbackReceiverBinding $ConsentStore
  if ($null -eq $binding) { return @{ action = 'unconfigured' } }
  $payload = Read-UserFeedbackEventPayload -InputPath $InputPath
  $identity = Get-UserFeedbackEventIdentity $payload
  return @{
    action = 'ready'
    receiver = $binding
    event = $payload
    eventId = $identity.eventId
    caseId = $identity.caseId
  }
}

# Run fixed read-only Git checks without inherited index, directory, or config
# redirects. Discard stderr because Git may include private filesystem paths.
function Invoke-UserFeedbackReceiverGit {
  param([string]$Root, [string[]]$Arguments, [string]$InputText)

  $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($null -eq $git) { throw 'USER_FEEDBACK_RECEIVER: Git is required for local intake.' }
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $git.Source
  $info.WorkingDirectory = $Root
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  $info.RedirectStandardInput = $true
  foreach ($name in @($info.Environment.Keys)) {
    if ($name -like 'GIT_*') { $null = $info.Environment.Remove($name) }
  }
  $info.Environment['GIT_CONFIG_NOSYSTEM'] = '1'
  $info.Environment['GIT_CONFIG_GLOBAL'] = '/dev/null'
  $info.Environment['GIT_OPTIONAL_LOCKS'] = '0'
  $info.Environment['GIT_NO_LAZY_FETCH'] = '1'
  $configuration = @('-c', 'core.excludesFile=/dev/null', '-c', 'core.fsmonitor=false')
  foreach ($argument in $configuration + $Arguments) {
    $info.ArgumentList.Add($argument)
  }

  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $info
  try {
    $null = $process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if ($InputText) { $process.StandardInput.Write($InputText) }
    $process.StandardInput.Close()
    if (-not $process.WaitForExit(5000)) {
      $process.Kill($true)
      throw 'Git inspection timed out.'
    }
    $null = $stderr.GetAwaiter().GetResult()
    return @{ code = $process.ExitCode; output = $stdout.GetAwaiter().GetResult() }
  } catch {
    throw 'USER_FEEDBACK_RECEIVER: Could not inspect the receiver repository.'
  } finally {
    $process.Dispose()
  }
}

# Require the exact receiving worktree and an untracked, ignored archive.
# Check concrete destinations too because an ignore rule can have exceptions.
function Get-UserFeedbackReceiverStore {
  param([string]$Root, [string]$EventId)

  $relative = '_work/team-feedback'
  $store = Resolve-TeamContainedPath $Root $relative
  $probe = Invoke-UserFeedbackReceiverGit $Root @('rev-parse', '--show-toplevel')
  if ($probe.code -ne 0 -or -not $probe.output.Trim()) {
    throw 'USER_FEEDBACK_RECEIVER: ProjectRoot must be the exact Git worktree root.'
  }
  $gitRoot = Get-TeamCanonicalRoot $probe.output.Trim()
  if (-not [string]::Equals($Root, $gitRoot, (Get-TeamPathComparison))) {
    throw 'USER_FEEDBACK_RECEIVER: ProjectRoot must be the exact Git worktree root.'
  }
  $indexed = Invoke-UserFeedbackReceiverGit $Root @('ls-files', '--cached', '-z', '--', $relative)
  if ($indexed.code -ne 0 -or $indexed.output.Length) {
    throw 'USER_FEEDBACK_RECEIVER: The archive cannot contain tracked or staged paths.'
  }

  $event = "$relative/feedback/user-events/$EventId.json"
  $lock = "$relative/.feedback.lock"
  $null = Resolve-TeamContainedPath $Root $lock
  $null = Resolve-TeamContainedPath $Root $event
  $paths = @("$relative/", $lock, $event)
  $separator = [char]0
  $probe = Invoke-UserFeedbackReceiverGit $Root @('check-ignore', '--no-index', '-z', '--stdin') (
    ($paths -join $separator) + $separator
  )
  $ignored = @(($probe.output -split $separator) | Where-Object { $_ })
  if ($probe.code -ne 0 -or @($paths | Where-Object { $_ -cnotin $ignored }).Count) {
    throw 'USER_FEEDBACK_RECEIVER: The archive and its files must already be Git-ignored.'
  }
  return $store
}

# Store an exact prepared event only from the native source identity provided
# by the caller. The script cannot attest to host-delivered message metadata.
function Receive-UserFeedbackDelivery {
  param(
    [string]$ConsentStore,
    [string]$InputPath,
    [string]$ProjectRoot,
    [string]$ReceiverThreadId,
    [string]$ReceiverHostId,
    [string]$ReceiverProjectId,
    [string]$SourceThreadId,
    [string]$ExpectedEventId
  )

  if (-not (Get-UserFeedbackEnabled $ConsentStore)) { return @{ action = 'disabled' } }
  $binding = Get-UserFeedbackReceiverBinding $ConsentStore
  if ($null -eq $binding) { return @{ action = 'unconfigured' } }
  try { $root = Get-TeamCanonicalRoot $ProjectRoot }
  catch { throw 'USER_FEEDBACK_RECEIVER: Invalid receiver project directory.' }
  $current = @{
    threadId = $ReceiverThreadId
    hostId = $ReceiverHostId
    projectId = $ReceiverProjectId
    projectRootDigest = Get-HashId $root
  }
  if (-not (Test-UserFeedbackReceiverBinding $binding $current)) {
    throw 'USER_FEEDBACK_RECEIVER: Current chat, host, project or root does not match the binding.'
  }
  $payload = Read-UserFeedbackEventPayload -InputPath $InputPath
  if ($SourceThreadId -cnotmatch '\A[A-Za-z0-9][A-Za-z0-9._:-]{0,255}\z' -or
      $SourceThreadId -ceq $ReceiverThreadId -or
      (Get-HashId $SourceThreadId) -cne $payload.sessionDigest) {
    throw 'USER_FEEDBACK_RECEIVER: Source chat does not match the delivery.'
  }
  Assert-UserFeedbackDigest $ExpectedEventId 'ExpectedEventId'
  $identity = Get-UserFeedbackEventIdentity $payload
  if ($ExpectedEventId -cne $identity.eventId) {
    throw 'USER_FEEDBACK_RECEIVER: Expected event ID does not match the delivery.'
  }

  # Reuse the local lock and atomic event writer; the global opt-in remains
  # read-only during intake so the receiving chat only needs its own worktree.
  $store = Get-UserFeedbackReceiverStore -Root $root -EventId $identity.eventId
  $write = @{
    Store = $store
    ConsentStore = $ConsentStore
    Payload = $payload
    ReceiverBinding = $binding
  }
  try {
    return Save-UserFeedbackEvent @write
  } catch {
    throw 'USER_FEEDBACK_RECEIVER: Receiver store unavailable; no persisted receipt issued.'
  }
}
