---
name: team-dev
description: Run a bounded, evidence-backed Codex development workflow for a feature, bug fix, refactor, or integration. Use explicitly as $team-dev when the user wants coordinated implementation work.
---

# Team development

Act as the Lead. This workflow owns the full shared [execution contract](../team-core/references/execution-contract.md): **Context → Discover → Contract → Execute → Verify → Handoff**.

## When to activate

Use when the user wants a coordinated implementation, not merely advice, a plan, or a review. For code-changing work, including small bounded tasks, default to one exact named domain implementer and `team-tester`; the Tester prepares the stage packet's concise coverage plan before implementation and verifies afterward, with separate test and production-file ownership. Every material implementation also receives an independent `team-reviewer` review. Small scope reduces role count and record size, not applicable process obligations. Pure consultation and read-only work do not inherit this implementation-role minimum. Truly nonbehavior typo/format corrections may be Lead-owned; behavior-changing Skills, policies or agent-routing/configuration that govern the harness remain implementation work. Ordinary application scripts/configuration follow their domain. Classify risk by impact and boundary, not file or line count.

Do not use this workflow to create a task daemon, push branches, merge pull requests, or alter external systems unless the user explicitly asks.

## Establish the work

For Kit-owned temporary/generated files in a target Git project, follow the [generated-artifact protection contract](../team-core/references/generated-artifacts.md). Call `Protect` for each applicable profile before writing. Before an authorized commit or handoff, call `Protect` again for those profiles, then `Check` to inspect the actual index. `Check` cannot add missing protection. Stop on violations or `ARTIFACTS` conflicts and ask the user how to handle tracked files or explicit include rules; never untrack them automatically. Documentation governance metadata, index and reviews stay local to that checkout; user-authored governance docs, PRDs, Blueprint, verification packets and native specs remain versionable. A fresh checkout must establish its own governance review state from available documents. The helper does not stage, commit, push, or prevent manual forced staging.

Apply [documentation governance](../team-core/references/documentation-governance.md) before writers begin. Scan/adopt unchecked existing projects, classify new docs, and validate a Lead-reviewed assessment against the current task/scope. A marker alone is not a pass. In the Work contract, assign each documentation path its purpose and source-of-truth responsibility as well as its owner. Use team-docs-maintainer for substantial documentation work and Explorer for code facts; route technical judgments through the Lead. During authorized content edits, correct relevant evidence-backed defects within the assigned boundary and recheck affected links/indexes; ask the Lead for a bounded assignment before crossing owners. Review the actual doc diff for placement, factual accuracy, duplication and purpose alignment. Respect applicable active PRDs and ask the user before resolving substantive ambiguity or disputed archival. Only explicitly independent work may proceed under a partial assessment. Recheck relevant inputs after material changes, and synchronize factual docs/PRD decisions at handoff. Do not require all document types.

At task start and when work first enters another relevant module, assess the applicable instruction chain under the [project-rules contract](../team-core/references/project-rules.md); reassess only when relevant rule, command, convention, or source evidence changes. When inspected evidence shows a material gap for the current task, the Lead gives the user the affected path, evidence, impact, suggested delta, and asks for approval even if the task did not mention `AGENTS.md`. A target-instruction write of any kind requires user approval for its bounded path/rules; ordinary code-development authorization is insufficient. Missing, short, or old instructions alone are not gaps and do not block unrelated authorized work. Record a prior proposal and decision in existing Work/governance evidence and do not repeat it unless relevant evidence or scope materially changes. There is no background watcher or automatic edit.

Check for `openspec/team-integration.json`. If present, apply the [spec lifecycle](../team-core/references/spec-lifecycle.md): read the active change, use its sole task list, link all scenarios/tasks to stage packets, and run the adapter's Validate before implementation and CloseCheck before archive. Missing dependencies or stale evidence block affected spec-backed work; never silently fall back or run a competing OpenSpec apply workflow. Without the marker, keep the native kit path and do not initialize OpenSpec.

For visible UI work, apply the [UI delivery contract](../team-core/references/ui-quality.md). Preserve the complete product/page goal in the UI brief before delegation, name one page/flow owner, and include necessary shared-style ownership. Small demos normally use one implementer rather than component-by-component delegation. Require the owner to use frontend-design alongside frontend-engineering; routine authorized polish needs no new design approval.

Read the [Project Blueprint contract](../team-core/references/project-blueprint.md) before assigning stages. Assess its gate; for existing projects, inspect the baseline first. Record adequate structure as-is; propose evidenced structural repairs separately and obtain explicit user approval before refactoring. If declined or deferred, document retained constraints and continue within the actual structure. When the gate applies, the Lead creates/updates the blueprint from the architect's read-only proposal and includes its path/revision, modules, file scope, root exceptions and amendment decision in every stage packet. Use `-BlueprintPath` for canonical packet validation. Review actual file placement at close; return unplanned boundary changes to Contract.

Read [role routing](../team-core/references/role-routing.md), [file ownership](../team-core/references/file-ownership.md), [handoff format](../team-core/references/handoff-format.md), [execution templates](../team-core/references/execution-templates.md), [test and acceptance contract](../team-core/references/test-acceptance-contract.md), [TDD protocol](../team-core/references/tdd-protocol.md), and [feedback recording](../team-core/references/feedback-recording.md).

For any persistent issue returned from verification or review, apply the shared [repair and diagnosis loop guard](../team-core/references/repair-loop-guard.md) before assigning another repair. Carry acceptance-based identity and cumulative history into the existing packet/Work record; satisfy its retrospective and pause gates before continuing. A failed repair never silently switches the task into a debug allocation.

Apply the test contract's [efficient test execution](../team-core/references/test-acceptance-contract.md#efficient-test-execution) rule by default. Before implementation, record the adequate entrypoint/real boundary, runner, observation mode and rationale in the Work contract or stage packet. Use repeatable runners and summary-first inspection while retaining the complete evidence and all required E2E, browser, visual and manual checkpoints.

Use the test contract's risk tiers and reuse identity when planning execution. If the affected test surface is unclear, a bounded Explorer inventory may locate it after behavior/modules are scoped; Tester retains coverage and execution decisions. Never use a narrow tier or reused result to bypass a repository-required gate.

1. Create a Task record. Identify outcome, constraints, acceptance checks, and unknowns.
2. Discover only the facts needed to choose an approach. Use `team-explorer` for uncertain scope and `team-architect` for cross-module contracts.
3. Create a Work contract before assigning writers. Declare ownership for shared APIs, schemas, migrations, generated clients, and lockfiles. Keep production-code ownership to one writer by default.
4. Before implementation, discover the available test entrypoints and create the target repository's Git-tracked stage verification packet required by the Test & Acceptance Contract. `team-tester` owns its concise coverage matrix, TDD-track decisions, Red/Green evidence design, and human verification script, and post-verifies the implementation. Keep Tester-owned test files separate from production-code ownership.
5. Fill and validate the packet before writers begin. Every material behavior is `test-first`, `test-after`, or `manual-or-environmental`; unexplained exceptions block an unqualified start.
6. Delegate bounded work with expected output, relevant constraints, and verification. Follow [adaptive child-thread concurrency](../team-core/references/role-routing.md#adaptive-child-thread-concurrency), including its host-capacity and above-three explanation/recording rules; child agents do not orchestrate further agents.

Before assigning any child, including `team-tester` for step 4 packet planning, briefly state task type/risk, applicable standards, planned named roles/ownership and checks. Apply role routing's named-role preflight against the active tool catalog and pass the exact named role in the supported selector (e.g. `agent_type`). A task name or prompt is not selection. If no available named role legitimately fits, pause and ask about a specific alternative; do not silently use a generic agent or the Lead. Lead-only implementation requires the user's explicit request that the Lead personally implement the work, or approval of a specific proposed exception. Ordinary requests such as “do it” or “fix this” authorize implementation but do not authorize Lead-only ownership. Under an approved exception, the Lead takes the writer and Tester planning/execution duties as self-check; that is not independent Tester evidence and does not waive independent Reviewer review for material work. If a no-delegation request conflicts with required independent review, explain the conflict and ask for scoped direction.

## Execute and integrate

Wait for required discovery or contract decisions before dependent work begins. Communicate only at integration points: a shared contract is agreed, a dependency is ready, a handoff identifies a blocker, or verification changes the plan.

After a coherent implementation pass, have the assigned `team-tester` verify the implementation; under an approved Lead-only exception, the Lead performs this as a self-check instead of independent Tester evidence. Every material implementation still receives independent `team-reviewer` review. Include `team-database-specialist` for material data work. The Lead de-duplicates findings, assigns focused fixes, and keeps the original owner responsible for the changed boundary.

## Verify and close

For applicable UI work, check final integrated page evidence and separate functional results from visual status under the UI delivery contract. Re-inspect affected results if integration invalidated earlier evidence. Do not claim visual readiness with missing inspection or unresolved material visual defects; include specific remaining gaps without falsifying manual acceptance.

Apply the [code comment contract](../team-core/references/code-comments.md). Require writers to meet layered documentation minimums and explain every in-scope test's scenario and expected result, even simple tests. Record a per-unit self-check against behavior and assertions, including exemptions and gaps, even without an independent reviewer. Include this coverage when assigning review; missing mandatory explanations must be resolved or explicitly disclosed before completion.

Create a Verification record from actual checks. Record commands and outcomes, inspected behavior, and checks that could not run. Do not close the task until acceptance checks have evidence or the user-facing remaining risk is explicit.

Reconcile planned roles against actual spawn arguments and returned handles under role routing. Distinguish source/tool profiles from confirmed runtime identity and leave unreported model data unknown.

At close, reconcile the start declaration and Work contract against actual role calls, completed workflow checks, evidence and remaining gaps. Use the existing Verification record or stage packet; keep the summary proportionate and distinguish self-check from independent evidence.

Reconcile every stage-packet row with actual evidence, including Red/Green/refactor evidence or documented alternatives. Run the packet validator before Handoff. Human checks remain `manual pending` until user evidence exists. Archive the packet only after manual verification or explicit user deferral; otherwise link the active packet in the Handoff.

Apply the Test & Acceptance Contract's [manual scope and automated coverage](../team-core/references/test-acceptance-contract.md#manual-scope-and-automated-coverage) before writers start, on encountered user additions and at close. The E2E plan includes every manual case/requirement with equivalent conditions/results and explicit checkpoints. User-added/changed cases update the manual script, E2E plan/tests and applicable other-layer tests within scope; reopen affected evidence and rerun it. Ask before resolving ambiguity, expanding product scope or accepting automation exceptions. Do not silently omit late cases, count planned/blocked checks as passing, or change archived acceptance; use a follow-up packet when needed.

After the normal Handoff is prepared, create the local minimal feedback record described in [feedback recording](../team-core/references/feedback-recording.md). Include only redacted workflow evidence. A recording failure is a non-blocking remaining risk, never a reason to alter the task outcome.

## Return paths

- New scope, contract, or ownership concern → update the Work contract before continuing.
- Failed verification or valid review finding → assign a focused return to Execute, then rerun the affected verification.
- Before each repeated repair, apply the [repair and diagnosis loop guard](../team-core/references/repair-loop-guard.md); a reached threshold or earlier decision blocker pauses the affected issue and requires its evidence-led user report.
- Missing environment, credentials, or user decision → hand off the blocker with the smallest useful next step.

## Output contract

Report changed files, acceptance checks, verification evidence, valid review findings addressed, and remaining risks. Only the Lead claims task completion.

Always include the handoff format's actual child-agent roster: ID/task handle, selected role, task, final known status and identity limitations, including created failures/retries/interrupted agents. If none were used, state that explicitly; distinguish failed creation attempts with no ID.
