---
name: team-plan
description: Produce a decision-ready, evidence-backed implementation plan without editing code. Use explicitly as $team-plan for a feature, refactor, integration, or uncertain technical change.
---

# Team plan

Act as the Lead. This workflow owns **Context → Discover → Contract → Handoff** from the shared [execution contract](../team-core/references/execution-contract.md). Do not edit production code, tests, configuration, or external systems.

## When to activate

Use for a feature, refactor, integration, or technical change that needs repository evidence, an agreed design, ordered work, or an ownership decision before implementation.

Do not use for a one-line factual answer, a request to implement immediately after a sufficient approved plan, or a review of an existing change set; route those to the appropriate direct workflow.

When the proposed product behavior includes an AI agent or workflow, identify prompts, context/history, model/tool calls, state transitions and human gates in the plan. Use `team-ai-architect` for a bounded read-only proposal when material AI-specific design choices are unresolved; `team-architect` retains software-wide structure and cross-module architecture. If the user wants to explore behavior before coding, offer the explicit `$team-ai-simulate` workflow; its prototype is a separate decision point and does not replace `$team-dev` or authorize production implementation.

## Build the plan

At task start, use the shared [risk-proportional design-exploration contract](../team-core/references/design-exploration.md) to choose a light check or fuller exploration from material risk and unresolved uncertainty, not task/file size. An already accepted cross-module design does not need to be reopened unless relevant evidence or scope changed. For child assignments, pass the overall goal, applicable PRD and accepted design/Blueprint revisions, non-goals, relevant constraints/evidence/decisions/unknowns, and the exact applicable shared reference; do not assume conversation or Skill inheritance. Explorer supplies bounded facts, Architects propose read-only designs when material questions require them, and no role is added without a concrete need.

Apply [role routing](../team-core/references/role-routing.md) before delegation: check needed named roles in the active tool catalog, explicitly select them, and ask before any unavailable-role alternative. Task labels and source profiles do not prove runtime identity. Reconcile actual calls and include the [handoff format](../team-core/references/handoff-format.md)'s actual child roster in the final response, including failures/retries or explicit none.

Apply [documentation governance](../team-core/references/documentation-governance.md). Discover docs and scoped review evidence, assess missing/stale records, identify applicable active PRDs and task-specific information needs. Use team-docs-maintainer for substantial inventory/consistency work and Explorer for code evidence. Report ambiguity with options for the user; never silently resolve conflicting requirements or archival choices. Planning proposes governance adoption/record updates; persist them only within the user's documentation authority. A plan can identify gaps without pretending development is ready; team-dev establishes a current validated assessment before writers start.

At task start, when planning first enters another relevant module, and when relevant rule/command/convention evidence changes, assess applicable instructions under the [project-rules contract](../team-core/references/project-rules.md). If evidence shows a material gap affecting the planned work, the Lead presents the exact path, evidence, impact, suggested delta, and approval question even when the plan did not request an `AGENTS.md` change. Planning never writes target instructions. Any later write, including a factual/link correction, needs user approval for its bounded path/rules; ordinary implementation permission does not cover it. Do not raise a duplicate approved, declined, or deferred proposal unless relevant evidence or task scope materially changes.

Check for `openspec/team-integration.json`. If present, apply the [spec lifecycle](../team-core/references/spec-lifecycle.md): read current behavior and active deltas, resolve ambiguity, reuse the blueprint, and designate the change's tasks.md as the sole implementation list. Planning may propose artifacts but does not enable the integration, mutate its configuration or authorize implementation. Missing/stale specification evidence remains explicit. Without the marker, keep the native planning workflow.

For UI work, apply the [UI delivery contract](../team-core/references/ui-quality.md). Include a lightweight UI brief, coherent page/flow ownership, baseline resource paths, necessary shared-style scope and separate functional/rendered verification. Do not reduce the product goal to component tickets or add a mandatory design-document approval gate.

Apply the [Project Blueprint contract](../team-core/references/project-blueprint.md) before breaking an initiative into stages. Inspect existing architecture and representative code first, distinguish facts from proposals, then map stages to durable modules. For a sound existing structure, establish an as-is blueprint. For structural problems, present evidence, a bounded refactor with tests/recovery, and an as-is alternative. Require explicit user approval for refactoring; declining it preserves the actual structure with documented constraints. Planning does not authorize code moves.

Read [role routing](../team-core/references/role-routing.md), [file ownership](../team-core/references/file-ownership.md), [handoff format](../team-core/references/handoff-format.md), [execution templates](../team-core/references/execution-templates.md), [test and acceptance contract](../team-core/references/test-acceptance-contract.md), [TDD protocol](../team-core/references/tdd-protocol.md), and [feedback recording](../team-core/references/feedback-recording.md).

When planning work likely to revisit a known defect, use the [repair and diagnosis loop guard](../team-core/references/repair-loop-guard.md) to identify the issue by acceptance behavior/conditions/deviation and preserve earlier attempts. State any requested debug mode, bounded diagnostic/repair allocation, progress checkpoints for long operations, and stop condition in the Work contract; planning itself does not grant repair or debug authority.

Apply the test contract's [efficient test execution](../team-core/references/test-acceptance-contract.md#efficient-test-execution) rule when proposing test layers and commands. Record the proposed entrypoint, real boundary, runner, observation mode and rationale in the Work contract or stage plan; preserve full manual-scenario coverage and explain any duplicate browser business permutations represented by equivalent API/integration evidence.

Use its test-tier, prior-evidence and resource-budget rules when planning checks. Request a scoped Explorer test inventory only when the relevant surface is not already readily known; the plan records evidence and gates without deciding that a required test may be skipped.

1. Create a Task record: outcome, constraints, acceptance checks, and open questions.
2. Discover repository facts. Use `team-explorer` for unfamiliar scope and `team-architect` for cross-module contracts; request bounded findings with evidence.
3. Turn evidence into a Work contract. Define affected boundaries, ownership, compatibility, verification, and rollout or recovery needs when material.
4. Write ordered tasks only after shared contracts are resolved. Each task needs an owner, a deliverable, dependencies, and a verification step.
5. Self-check the plan: every acceptance check has a task and verification; no task assumes facts that discovery did not establish.
6. Include use cases, coverage-category decisions, a preliminary behavior-to-test mapping, likely TDD tracks, known test entrypoints and environment gaps, automated/E2E plan, and human verification requirements. `$team-dev` turns this into the tracked, validated stage packet before implementation.

Under the [Test & Acceptance Contract](../team-core/references/test-acceptance-contract.md#manual-scope-and-automated-coverage), the E2E scenario plan includes every manual case/requirement with equivalent conditions/results and checkpoints, including later user additions encountered during planning. Assess applicable other test layers and proposed assertion updates; disclose gaps and ask before automation exceptions or ambiguous scope decisions. Planning proposes test changes but does not implement them or rewrite archived acceptance.

## Decision and return gates

- Missing repository facts, conflicting findings, or an unknown test entrypoint → return to Discover.
- A shared API, schema, generated client, or lockfile has no owner → return to Contract.
- A material product or compatibility decision belongs to the user → present options and pause the affected task.

## Output contract

Return a plan package with:

```text
Objective and acceptance checks
Repository evidence and affected areas
Proposed contracts and compatibility decisions
Ordered tasks: owner, dependency, deliverable, verification
Test, migration, rollout, or recovery strategy
Risks and unresolved decisions
```

State what was verified from the repository versus what remains an assumption. The Lead hands this package to `$team-dev` or the user; it does not claim implementation completion.

After preparing this plan handoff, create the local minimal feedback record described in [feedback recording](../team-core/references/feedback-recording.md). Record evidence quality and unresolved decisions, never repository contents. If recording fails, keep the planning result intact and state the local recording gap only as a remaining risk.
