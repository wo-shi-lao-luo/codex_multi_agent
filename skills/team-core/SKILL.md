---
name: team-core
description: Internal reference bundle for Codex Multi-Agent Kit team workflows. Provides the shared execution, routing, ownership, and handoff contracts that team Skills read.
---

# Team core

For every Team workflow, read [role routing](references/role-routing.md): preflight needed roles against the active tool catalog, explicitly select named roles without silent generic fallback, reconcile actual calls and show the final actual-agent roster under [handoff format](references/handoff-format.md). Source profiles and task labels are not runtime identity evidence.

Before planning/implementation and when project docs change, read [documentation governance](references/documentation-governance.md). It assigns document content responsibilities and placement, requires bounded evidence-backed corrections discovered during authorized edits, and preserves active PRD authority, optional categories and user decisions on ambiguity. Its docs/governance marker tracks adoption and scoped review evidence; `scripts/documentation.ps1` detects evidence changes without resolving semantics or moving legacy docs.

When a target project has `openspec/team-integration.json`, read [spec lifecycle](references/spec-lifecycle.md) and [OpenSpec integration](references/openspec-integration.md). This optional adapter keeps the Lead in control and links native specs/tasks to existing stage evidence. Without the marker, do not adopt OpenSpec automatically.

For new pages and visible UI changes, read the [UI delivery contract](references/ui-quality.md). It preserves page-level goals through delegation and separates functional verification from rendered visual inspection; frontend-design supplies the implementation guidance.

For code implementation or review, read the [code comment contract](references/code-comments.md) for layered documentation minimums, mandatory per-test scenario/expected-result explanations, writer self-checks and semantic review.

For project and multi-stage work, read the [Project Blueprint contract](references/project-blueprint.md). `scripts/project-blueprint.ps1` initializes and validates the architecture document; it never reorganizes source code. Existing-project discovery, explicit refactor approval, and continued work after refusal are part of this contract.

This is a supporting Skill, not a user-facing workflow entrypoint. Team workflow Skills read the files in `references/` so their shared operating contracts ship with the installed kit. Use `references/execution-contract.md` as the common lifecycle and its minimum-team/complete-obligations rules for code-changing `$team-dev`; use `references/role-routing.md` for named-role routing, approved Lead-only exceptions, ownership, and handoffs. The implementation-agent minimum does not apply to pure consultation or read-only workflows.

For an explicit `team-*` workflow close, read [feedback recording](references/feedback-recording.md). It defines the minimal, local acceptance record and the conditions under which the installed runtime may be called. The runtime lives at `scripts/feedback-runtime.ps1`; it does not write inside a business repository or make any external request.

For `$team-dev` implementation work, read [test and acceptance contract](references/test-acceptance-contract.md) and [TDD protocol](references/tdd-protocol.md). Its `scripts/stage-verification.ps1` intentionally creates and validates Git-tracked verification packets inside the target project; archival occurs only after a validated, authoritative final manual status.

For test planning, execution, or review in Codex workflows, apply the contract's [efficient test execution](references/test-acceptance-contract.md#efficient-test-execution) rule by default; the contract remains the single source for execution and observation choices.
