# Optional Codex lifecycle adapter: bounded context only, never Board/configuration writes.
# Register and trust this exact hook separately; installation does not enable it.
#requires -Version 7.0
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
try {
  $buffer = [char[]]::new(4096)
  $body = [Text.StringBuilder]::new()
  while (($read = [Console]::In.Read($buffer, 0, $buffer.Length)) -gt 0) {
    if ($body.Length + $read -gt 262144) { throw 'Input limit' }
    $null = $body.Append($buffer, 0, $read)
  }
  $eventData = $body.ToString() | ConvertFrom-Json -AsHashtable
  if ($eventData -isnot [System.Collections.IDictionary]) { throw 'Invalid event' }
  $eventName = $eventData.hook_event_name
  if ($eventName -notin @('SessionStart', 'UserPromptSubmit')) {
    Write-Output '{}'
    exit 0
  }
  # Event data, prompt text, transcript paths and names are never copied into developer context.
  # A hook cannot decide user authorization or supply missing host/project identity.
  $context = 'Board checkpoint: on each new instruction, the main Lead classifies new outcome, refinement, priority or status-only question and synchronizes task cards before dependent work. For one serial workstream the Lead executes directly; delegate only for a stated independent gate or genuinely ready parallel work with disjoint ownership. One serial executor advances one running task; record waiting work honestly and verify read-back. Reassess activation at start, resume and discussion-to-execution. Use team-core/scripts/activate-board.ps1 with fresh native host/project/main-session metadata and approved scope; report actual enabled, exempt or activation-pending and the reason. Help/runtime-doctor is not activation. Keep ordinary questions, standalone consultation, planning-only work and opt-out exempt; a child inherits the main Board. Retain credentials privately. Preserve unsafe existing Boards and in-flight facts. Browser queued/unknown is not opened; never automatically repeat first opening. This context supplies no additional authorization, installation, migration or configuration authority.'
  @{ hookSpecificOutput = @{ hookEventName = $eventName; additionalContext = $context } } |
    ConvertTo-Json -Depth 4 -Compress
} catch {
  # Never echo malformed hook input or exception details, which may contain user text/secrets.
  @{ continue = $true; systemMessage = 'Board checkpoint context could not be read; no Board or configuration was changed. Apply the task-coordination activation checkpoint using current trusted context.' } |
    ConvertTo-Json -Compress
}
