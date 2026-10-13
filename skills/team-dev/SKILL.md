---
name: team-dev
description: Run a bounded, evidence-backed Codex development workflow for a feature, bug fix, refactor, or integration. Use explicitly as $team-dev when the user wants coordinated implementation work.
---

# Team development

Act as the Lead. This workflow owns the full shared [execution contract](../team-core/references/execution-contract.md): **Context → Discover → Contract → Execute → Verify → Handoff**.

For frontend/backend changes, use the shared [risk-proportional web engineering guide](../team-core/references/web-engineering.md) only to select guidance relevant to the actual client, service, data, and side-effect boundaries. Pass the same material risks to the assigned Developer, Tester, and Reviewer within the existing Work contract and packet; this adds no role or workflow stage.


## When to activate

Use when the user wants a coordinated implementation, not merely advice, a plan, or a review. First apply the shared [risk-proportional light path](../team-core/references/execution-contract.md#risk-proportional-light-path). Eligible bounded low-risk tasks may be Lead-owned with scoped checks and no forced implementation/Tester/Reviewer roles; standard-path code work uses one exact named domain implementer and the Tester role selected through shared role routing: `team-tester` generally, or `team-ai-tester` when application AI behavior evaluation is the primary test need. The selected Tester prepares the stage packet's concise coverage plan before implementation and verifies afterward, with separate test and production-file ownership. Every material implementation also receives an independent `team-reviewer` review. Pure consultation and read-only work do not inherit this implementation-role minimum. Truly nonbehavior typo/format corrections may be Lead-owned; behavior-changing Skills, policies or agent-routing/configuration that govern the harness remain implementation work. Ordinary application scripts/configuration follow their domain. Classify risk by impact and boundary, not file or line count.

When Team is explicitly invoked or task-matched to engineering work, shared [workflow routing](../team-core/references/workflow-routing.md) may select this mode only when implementation is authorized and fits the current intent and evidence. Do not require a second `$team-dev` command. Apply the light-path eligibility in the execution contract; otherwise selection does not waive this workflow's standard-path roles, documentation, packet, TDD, verification, review, or approval gates.

For eligible light work, follow the [canonical light path](../team-core/references/execution-contract.md#risk-proportional-light-path): use its short task/check note, read only relevant domain, project-instruction and test guidance, then run scoped checks and hand off actual evidence. Do not run the standard pipeline below by default. Existing stage/spec/manual artifacts, active PRD authority, adopted project rules, and applicable target-instruction approval boundaries still govern. The following full-reference and packet steps apply to noneligible work or when an existing obligation makes a step relevant.

Before implementation on either path, briefly check whether a suitable existing project capability, approved dependency, or standard framework fits. Read [reuse and third-party guidance](../team-core/references/reuse-and-third-party.md) when external selection, adoption, copying, or adaptation warrants its detail; do not force web research, extra roles, or an audit for routine reuse.

For application AI behavior—including prompt sources, model calls, context/history, tool protocols, agent roles and workflow state—route the bounded production files to `team-ai-engineer` using [ai-engineering](../ai-engineering/SKILL.md). Pass the approved goal and decisions with only the applicable guides that Skill selects. Ask `team-ai-architect` for a bounded read-only proposal only when material AI-specific design choices need it; `team-architect` retains overall software architecture. Keep generic API/service/authentication/job infrastructure with `team-backend-engineer` and agree shared interfaces before parallel work. `$team-ai-simulate` is an optional, explicit prototype workflow; a simulation result alone does not authorize production implementation.

When the stage needs application AI behavior evaluation, route those cases/tests to `team-ai-tester` using the [AI evaluation contract](../team-core/references/ai-evaluation.md). The selected Tester role owns the canonical packet; add `team-tester` only for distinct required software assertions, and use ordinary `team-tester` for Kit/helper/package changes.

Do not use this workflow to create a task daemon, push branches, merge pull requests, or alter external systems unless the user explicitly asks.

When the user intends a commit, push, pull request, merge, release or installation
source delivery, route the bounded read-only assessment through
[$team-delivery-check](../team-delivery-check/SKILL.md) and the
[Git delivery contract](../team-core/references/git-delivery.md). Ordinary edits do
not trigger this route; delivery execution still needs its own authority.

## Establish the work

Before design proposals or implementation, read the [risk-proportional design-exploration contract](../team-core/references/design-exploration.md) in full. Use its light/full triggers; do not reopen accepted decisions without material new evidence. Pass each child its bounded task context and exact relevant authority. Explorer supplies facts, Architects are read-only, and bounded simulation actors do not join design work.

For Kit-owned temporary/generated files in a target Git project, read and follow the [generated-artifact protection contract](../team-core/references/generated-artifacts.md) in full. Protect each applicable profile before writing and before an authorized handoff/commit, then check the actual index. Stop on violations or `ARTIFACTS` conflicts and ask about tracked/include-rule handling; never untrack automatically. User-authored governance evidence remains versionable, and a fresh checkout establishes its own review state.

Apply [documentation governance](../team-core/references/documentation-governance.md) before writers begin. Eligible light work reads relevant project evidence and honors adopted rules without a forced full inventory/runtime scan. For other work, read this authority fully; scan/adopt existing project evidence, classify assigned docs, and validate the Lead-reviewed task/scope assessment. Assign each path its purpose/source of truth and owner. Use team-docs-maintainer for substantial docs and Explorer for code facts; route technical judgments through the Lead. Correct evidence-backed defects only within assigned scope, recheck affected links/indexes, and ask before resolving ambiguity or crossing owners. Respect active PRDs; a marker is not review evidence, partial readiness permits only explicitly independent work, and optional document categories remain optional.

At task start and when work enters a relevant module, read the [project-rules contract](../team-core/references/project-rules.md) fully and assess applicable instructions; revisit only when relevant rule, command, convention, or evidence changes. The Lead surfaces only material evidenced gaps with path, impact, suggested delta, and an approval question. Any target-instruction write requires approval for its bounded path/rules; absence, brevity, or age alone is not a gap. Reuse reachable decisions and do not turn this checkpoint into a background watcher or automatic edit.

Check for `openspec/team-integration.json`. If present, read the [spec lifecycle](../team-core/references/spec-lifecycle.md) in full: use its sole task list, link scenarios/tasks to packets, and run Validate before implementation and CloseCheck before archive. Stop affected work for missing dependencies or stale evidence; never silently fall back or run a competing apply workflow. Without the marker, use the native kit path and do not initialize OpenSpec.

For visible UI work, read and apply the [UI delivery contract](../team-core/references/ui-quality.md) in full. Preserve the complete goal in the UI brief, name one page/flow owner with needed shared-style scope, and require frontend-design with frontend-engineering. Small demos normally have one implementer; routine authorized polish needs no new design approval.

For a new application, multi-stage effort, or material boundary change, read the [Project Blueprint contract](../team-core/references/project-blueprint.md) in full and assess its gate. It owns baseline assessment, module mapping, proposal/refactor approval and packet fields. If not applicable, record that briefly. Preserve an adequate existing structure; do not refactor without explicit user approval. Review actual placement at close and return unplanned boundary changes to Contract.

When the task materially migrates architecture, contracts, workflow/state, configuration or eligibility, persisted data/jobs, or compatibility behavior, also apply the conditional [architecture and contract migration guide](../team-core/references/architecture-migration.md). Trace existing rules to approved targets and affected consumers; keep structural decisions in the Blueprint and verification/results in the stage packet. An internal/model-only change with unchanged approved semantics does not need an exhaustive migration pass.

Read [role routing](../team-core/references/role-routing.md) and [file ownership](../team-core/references/file-ownership.md) in full before delegation. Use [execution templates](../team-core/references/execution-templates.md), the [Test & Acceptance Contract](../team-core/references/test-acceptance-contract.md), and [TDD protocol](../team-core/references/tdd-protocol.md) as applicable. The light path uses a concise note and suitable existing evidence; the standard path creates/validates its required stage packet. Read the [handoff format](../team-core/references/handoff-format.md) when preparing handoff. After normal handoff, consult [feedback recording](../team-core/references/feedback-recording.md); eligible light work needs no persisted record or runtime call.

For any persistent issue returned from verification or review, read and apply the [repair and diagnosis loop guard](../team-core/references/repair-loop-guard.md) in full before assigning another repair. Preserve issue identity/history in the existing record; a failed repair never silently becomes a debug allocation.

Apply the [efficient test execution and tier rules](../team-core/references/test-acceptance-contract.md#efficient-test-execution) in full. For a standalone small change or bug, follow the [small-task rule](../team-core/references/test-acceptance-contract.md#tier-selection-reuse-and-resource-limits); keep complete coverage/manual planning and do not skip risk-triggered or repository-required gates. Record the real boundary, runner, observation mode and rationale before implementation. The contract owns iteration, linkage-smoke, acceptance-checkpoint, deferral, failure-blocking, reuse and expansion details; a scoped tier or reused result never waives a required gate. If the test surface is unclear, request bounded Explorer facts after scope is known; Tester retains coverage and sufficiency decisions.

1. Create a Task record. Identify outcome, constraints, acceptance checks, and unknowns.
2. Discover only the facts needed to choose an approach. Use `team-explorer` for uncertain scope and `team-architect` for cross-module contracts.
3. Create a Work contract before assigning writers. Declare ownership for shared APIs, schemas, migrations, generated clients, and lockfiles. Keep production-code ownership to one writer by default.
4. For standard-path work, before implementation discover available test entrypoints and create the target repository's Git-tracked stage packet required by the Test & Acceptance Contract. The role-selected Tester owns its concise coverage matrix, TDD-track decisions, Red/Green evidence design, and human verification script, and post-verifies the implementation. Keep Tester-owned test files separate from production-code ownership.
5. For standard-path work, fill and validate the packet before writers begin. Every material behavior is `test-first`, `test-after`, or `manual-or-environmental`; unexplained exceptions block an unqualified start. Eligible light code work still uses practical TDD/regression checks and concise evidence, without forcing the packet schema.
6. Delegate bounded work with expected output, relevant constraints, and verification. Follow [adaptive child-thread concurrency](../team-core/references/role-routing.md#adaptive-child-thread-concurrency), including its host-capacity and above-three explanation/recording rules, and the [child-thread lifecycle](../team-core/references/role-routing.md#child-thread-lifecycle) checkpoints for roster reconciliation, reuse, safe close and capacity evidence; child agents do not orchestrate further agents.

Before assigning any child, including the selected Tester role for packet planning, briefly state task type/risk, applicable standards, planned roles/ownership and checks. Follow role routing's full named-role preflight, selector, unavailable-role, child-lifecycle and approved Lead-only rules; keep the top-level role minimum and independent Reviewer requirement above, and never infer role selection from a task name or silently substitute.

## Execute and integrate

Wait for required discovery or contract decisions before dependent work begins. Communicate only at integration points: a shared contract is agreed, a dependency is ready, a handoff identifies a blocker, or verification changes the plan.

After a coherent implementation pass, the assigned Tester verifies standard-path scope; for an eligible light task the Lead runs scoped checks as self-check. Under a separately approved Lead-only exception outside the light path, the Lead performs Tester duties as self-check rather than independent evidence. Every material implementation still receives independent `team-reviewer` review. Include `team-database-specialist` for material data work. The Lead de-duplicates findings, assigns focused fixes, and keeps the original owner responsible for the changed boundary.

## Verify and close

For applicable UI work, read the UI delivery contract in full; check final integrated-page evidence and report functional results separately from visual status. Re-inspect invalidated results and do not claim visual readiness with missing inspection or material defects.

Read and apply the [code comment contract](../team-core/references/code-comments.md) in full. Require the defined layered comments, per-test explanations and behavior/assertion self-check; resolve or disclose mandatory gaps before completion.

Read and apply the [code readability contract](../team-core/references/code-readability.md) in full alongside project conventions. Route standalone formatting requests through `$team-code-maintain`; a post-freeze formatting transfer must finish before the already planned final tests and review.

Create a Verification record from actual checks. Record commands and outcomes, inspected behavior, and checks that could not run. For QA, summarize relevant coverage gaps, findings and retest state, UX decisions, and risks in the existing packet or record; follow the [canonical QA inputs and user-perspective verification guidance](../team-core/references/test-acceptance-contract.md#qa-inputs-and-user-perspective-verification). Do not close the task until acceptance checks have evidence or the user-facing remaining risk is explicit.

Reconcile planned roles against actual spawn arguments and returned handles under role routing. Distinguish source/tool profiles from confirmed runtime identity and leave unreported model data unknown.

At close, reconcile the start declaration and Work contract against actual role calls, completed workflow checks, evidence and remaining gaps. Run the child-thread lifecycle's task-close checkpoint to reuse or close eligible task-owned children safely and record any unavailable/uncertain closure. Use the existing Verification record or stage packet; keep the summary proportionate and distinguish self-check from independent evidence.

For standard-path work, read and apply the [Test & Acceptance Contract](../team-core/references/test-acceptance-contract.md) and [TDD protocol](../team-core/references/tdd-protocol.md) in full through packet planning and close. Reconcile every packet row with actual evidence and validate before handoff; human checks stay `manual pending` without user evidence, and archive only after manual verification or explicit deferral. Preserve all manual/E2E mappings and user additions; reopen affected evidence, ask before exceptions/ambiguity, and never treat planned/blocked checks as passing or rewrite archived acceptance. Use a follow-up packet for archived-stage additions. Eligible light work retains any existing required artifacts and records practical checks in a suitable existing record.

After the normal Handoff is prepared, read [feedback recording](../team-core/references/feedback-recording.md). Eligible light work does not require a record; for other supported work, include only redacted workflow evidence and treat recording failure as a non-blocking remaining risk.

## Return paths

- New scope, contract, or ownership concern → update the Work contract before continuing.
- Failed verification or valid review finding → assign a focused return to Execute, then rerun the affected verification.
- Before each repeated repair, apply the [repair and diagnosis loop guard](../team-core/references/repair-loop-guard.md); a reached threshold or earlier decision blocker pauses the affected issue and requires its evidence-led user report.
- Missing environment, credentials, or user decision → hand off the blocker with the smallest useful next step.

## Output contract

Report changed files, acceptance checks, verification evidence, valid review findings addressed, and remaining risks. Only the Lead claims task completion.

Use the [handoff format](../team-core/references/handoff-format.md) in full for the actual child-agent roster, including failures/retries/interrupted agents or explicit none; distinguish failed creation attempts with no ID.
