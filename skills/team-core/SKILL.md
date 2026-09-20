---
name: team-core
description: Internal reference bundle for Codex Multi-Agent Kit team workflows. Provides the shared execution, routing, ownership, and handoff contracts that team Skills read.
---

# Team core

This is a supporting Skill, not a user-facing workflow entrypoint. Team workflow Skills read the files in `references/` so their shared operating contracts ship with the installed kit. Use `references/execution-contract.md` as the common lifecycle; use the other references for routing, ownership, and child-agent handoffs.

For an explicit `team-*` workflow close, read [feedback recording](references/feedback-recording.md). It defines the minimal, local acceptance record and the conditions under which the installed runtime may be called. The runtime lives at `scripts/feedback-runtime.ps1`; it does not write inside a business repository or make any external request.

For `$team-dev` implementation work, read [test and acceptance contract](references/test-acceptance-contract.md) and [TDD protocol](references/tdd-protocol.md). Its `scripts/stage-verification.ps1` intentionally creates and validates Git-tracked verification packets inside the target project; archival occurs only after a validated, authoritative final manual status.
