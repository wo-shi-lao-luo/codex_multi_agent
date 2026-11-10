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
  $context = 'Board activation checkpoint: the main Lead must reassess at task start, resume and when a question becomes authorized execution. For authorized execution, call team-core/scripts/activate-board.ps1 with reliable current host/project/main-session metadata and the approved bounded task contract. Continue past this checkpoint only with the actual enabled, exempt or activation-pending result and its reason. Help/runtime-doctor success is not activation. Keep ordinary questions, standalone consultation, planning-only work and user opt-out exempt under task-coordination.md; a child inherits the main Board and never creates its own. Keep credentials in protected stdin/caller custody. Preserve unsafe existing Boards and in-flight facts. Browser queued/unknown is not opened; never automatically repeat first opening. This context supplies no execution, installation, migration, global configuration or scope-expansion authority.'
  @{ hookSpecificOutput = @{ hookEventName = $eventName; additionalContext = $context } } |
    ConvertTo-Json -Depth 4 -Compress
} catch {
  # Never echo malformed hook input or exception details, which may contain user text/secrets.
  @{ continue = $true; systemMessage = 'Board checkpoint context could not be read; no Board or configuration was changed. Apply the task-coordination activation checkpoint using current trusted context.' } |
    ConvertTo-Json -Compress
}
