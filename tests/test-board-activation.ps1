# Instruction-contract regression checks; these do not prove native model compliance.
#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$contract = Get-Content (Join-Path $root 'skills/team-core/references/task-coordination.md') -Raw
function Require([bool]$Value, [string]$Message) { if (-not $Value) { throw $Message } }
# BA01: sustained engineering collaboration has a default activation checkpoint.
# Expected: the old discretionary-only policy fails before production changes.
Require ($contract.Contains('## Default activation checkpoint')) 'BA01: default activation checkpoint missing.'
foreach ($entry in @('skills/team/SKILL.md','skills/team-dev/SKILL.md',
    'skills/team-core/references/execution-contract.md','skills/team-core/references/role-routing.md')) {
  # BA02: each dispatch entry reaches the same authority rather than defining another rule.
  # Expected: automatic and direct entry paths both retain the checkpoint link.
  $text = Get-Content (Join-Path $root $entry) -Raw
  Require ($text.Contains('task-coordination.md#default-activation-checkpoint')) "BA02: activation edge missing in $entry"
}
# BA03: exceptions and degradation are explicit; existing unsafe Boards cannot be replaced.
# Expected: lightweight work, opt-out and missing prerequisites do not silently bypass policy.
foreach ($term in @('user opt-out','one-off consultation','activation-pending',
    'before dependent dispatch','Do not fabricate','existing Board','not-attempted')) {
  Require ($contract.Contains($term)) "BA03: missing activation boundary: $term"
}
# BA04: URL minting is separate from UI success; retries cannot steal focus.
# Expected: queued/link-only/unknown states and no-reopen protections remain authoritative.
foreach ($term in @('service-open','open_in_codex','queued','link-only','unknown',
    'Do not open the panel again','SSE')) {
  Require ($contract.Contains($term)) "BA04: missing presentation safeguard: $term"
}
Write-Output 'Board activation instruction-contract checks passed; native automatic routing remains a separate acceptance.'
