---
name: team-core
description: Internal reference bundle for Codex Multi-Agent Kit team workflows. Provides the shared execution, routing, ownership, and handoff contracts that team Skills read.
---

# Team core

For every Team workflow, read [role routing](references/role-routing.md): preflight needed roles against the active tool catalog, explicitly select named roles without silent generic fallback, reconcile actual calls and show the final actual-agent roster under [handoff format](references/handoff-format.md). Source profiles and task labels are not runtime identity evidence.

Before planning/implementation and when project docs change, read [documentation governance](references/documentation-governance.md). It assigns document content responsibilities and placement, requires bounded evidence-backed corrections discovered during authorized edits, and preserves active PRD authority, optional categories and user decisions on ambiguity. Its docs/governance marker tracks adoption and scoped review evidence; `scripts/documentation.ps1` detects evidence changes without resolving semantics or moving legacy docs.

For `$team-plan` and `$team-dev`, use [risk-proportional design exploration](references/design-exploration.md) to choose a light check or fuller exploration from material risk and uncertainty, not task size. The Lead supplies the bounded context and applicable reference to children; read-only Architects propose, while assigned Developers/Testers check only their scopes. This is not an extra user-approval gate for already accepted decisions.

When a Team workflow generates Kit-owned local files in a target Git repository, read the [generated-artifact Git protection contract](references/generated-artifacts.md). It defines narrow profile-based protection, exact task work paths, index checks, conflict handling, the local governance runtime bundle, and formal project evidence that remains versionable.

During `$team-plan` and `$team-dev` preflight, assess applicable target-project instruction coverage at task start, on first entry to a relevant module, and when relevant instruction/command/convention evidence changes. Read the [project-rules contract](references/project-rules.md) for evidence-based proposals, approval scope, deduplication, and candidate discovery. A material gap is presented by the Lead even without an explicit instruction-file request. This workflow checkpoint does not add a background watcher or automatic edit.

When a target project has `openspec/team-integration.json`, read [spec lifecycle](references/spec-lifecycle.md) and [OpenSpec integration](references/openspec-integration.md). This optional adapter keeps the Lead in control and links native specs/tasks to existing stage evidence. Without the marker, do not adopt OpenSpec automatically.

For new pages and visible UI changes, read the [UI delivery contract](references/ui-quality.md). It preserves page-level goals through delegation and separates functional verification from rendered visual inspection; frontend-design supplies the implementation guidance.

For code implementation or review, read the [code comment contract](references/code-comments.md) for layered documentation minimums, mandatory per-test scenario/expected-result explanations, writer self-checks and semantic review.

Apply the [code readability contract](references/code-readability.md) when authoring or reviewing code. For supported configured formatters, use the [portable formatter tool reference](references/formatter-tool.md) and its bounded `scripts/format-code.ps1` flow to plan and check assigned files; require explicit tool-trust and write acknowledgements before execution/application, then review remaining readability and run a final formatter check. Existing unsupported project formatters stay authoritative and require a caller decision. Route an explicit formatting/readability request through `$team-code-maintain`; its exact named role performs bounded formatting without forcing the full `$team-dev` lifecycle for nonbehavioral maintenance.

For project and multi-stage work, read the [Project Blueprint contract](references/project-blueprint.md). `scripts/project-blueprint.ps1` initializes and validates the architecture document; it never reorganizes source code. Existing-project discovery, explicit refactor approval, and continued work after refusal are part of this contract.

This is a supporting Skill, not a user-facing workflow entrypoint. Team workflow Skills read the files in `references/` so their shared operating contracts ship with the installed kit. Use `references/execution-contract.md` as the common lifecycle and its minimum-team/complete-obligations rules for code-changing `$team-dev`; use `references/role-routing.md` for named-role routing, approved Lead-only exceptions, ownership, and handoffs. The implementation-agent minimum does not apply to pure consultation or read-only workflows.

For persistent failures being diagnosed or repaired, apply the shared [repair and diagnosis loop guard](references/repair-loop-guard.md). It defines acceptance-based issue identity, cumulative bounded attempts, evidence-triggered external research, the single conditional ordinary repair extension, pause evidence and human-authorized resume; workflow Skills route into it rather than duplicating its thresholds.

For closes of the supported workflows (`team-dev`, `team-plan`, `team-debug`, and `team-review`), read [feedback recording](references/feedback-recording.md). It defines the minimal, local acceptance record and the conditions under which the installed runtime may be called. The runtime lives at `scripts/feedback-runtime.ps1`; it does not write inside a business repository or make any external request. Other `team-*` workflows do not call it unless explicitly added to the accepted schema and routing.

For explicitly requested local prototyping of an AI agent or AI workflow, use `$team-ai-simulate` and read the [AI simulation contract](references/ai-simulation.md). Its local run trace is separate from the `team-core` feedback runtime and does not call that runtime. For authorized implementation of application prompts, context, model/tool protocols or AI workflow state, use the `ai-engineering` Skill and route the bounded AI-specific behavior to `team-ai-engineer`; use `team-ai-architect` only for material AI design questions, while overall architecture stays with `team-architect`.

For application AI evaluation, read [AI evaluation](references/ai-evaluation.md) and route assigned behavior cases to `team-ai-tester`. Use [role routing](references/role-routing.md) to retain ordinary software and harness tests and avoid duplicate Tester roles without distinct coverage.

For an application's replaceable Agent/Workflow boundary, read [AI capability contract](references/ai-capability-contract.md); for live evidence and offline fixture reuse, read [AI record/replay testing](references/ai-record-replay-testing.md). These project-specific contracts do not turn local AI simulation into product testing or a production adapter.

For `$team-dev` implementation work, read [test and acceptance contract](references/test-acceptance-contract.md) and [TDD protocol](references/tdd-protocol.md). Its `scripts/stage-verification.ps1` intentionally creates and validates Git-tracked verification packets inside the target project; archival occurs only after a validated, authoritative final manual status.

For test planning, execution, or review in Codex workflows, apply the contract's [efficient test execution](references/test-acceptance-contract.md#efficient-test-execution) rule by default; it remains the single source for test tiers, evidence reuse, cost limits, and observation choices.
