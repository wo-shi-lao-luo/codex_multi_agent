---
name: team-core
description: Internal reference bundle for Codex Multi-Agent Kit team workflows. Provides the shared execution, routing, ownership, and handoff contracts that team Skills read.
---

# Team core

For new pages and visible UI changes, read the [UI delivery contract](references/ui-quality.md). It preserves page-level goals through delegation and separates functional verification from rendered visual inspection; frontend-design supplies the implementation guidance.

For code implementation or review, read the [code comment contract](references/code-comments.md) for layered documentation minimums, mandatory per-test scenario/expected-result explanations, writer self-checks and semantic review.

For project and multi-stage work, read the [Project Blueprint contract](references/project-blueprint.md). `scripts/project-blueprint.ps1` initializes and validates the architecture document; it never reorganizes source code. Existing-project discovery, explicit refactor approval, and continued work after refusal are part of this contract.

This is a supporting Skill, not a user-facing workflow entrypoint. Team workflow Skills read the files in `references/` so their shared operating contracts ship with the installed kit. Use `references/execution-contract.md` as the common lifecycle; use the other references for routing, ownership, and child-agent handoffs.

For an explicit `team-*` workflow close, read [feedback recording](references/feedback-recording.md). It defines the minimal, local acceptance record and the conditions under which the installed runtime may be called. The runtime lives at `scripts/feedback-runtime.ps1`; it does not write inside a business repository or make any external request.

For `$team-dev` implementation work, read [test and acceptance contract](references/test-acceptance-contract.md) and [TDD protocol](references/tdd-protocol.md). Its `scripts/stage-verification.ps1` intentionally creates and validates Git-tracked verification packets inside the target project; archival occurs only after a validated, authoritative final manual status.
