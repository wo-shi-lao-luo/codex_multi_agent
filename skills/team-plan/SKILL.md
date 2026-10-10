---
name: team-plan
description: Produce a decision-ready, evidence-backed implementation plan without editing code. Use explicitly as $team-plan for a feature, refactor, integration, or uncertain technical change.
---

# Team plan

Act as the Lead. This workflow owns **Context → Discover → Contract → Handoff** from the shared [execution contract](../team-core/references/execution-contract.md). Do not edit production code, tests, configuration, or external systems.


## When to activate

Use for a feature, refactor, integration, or technical change that needs repository evidence, an agreed design, ordered work, or an ownership decision before implementation.

Do not use for a one-line factual answer, a request to implement immediately after a sufficient approved plan, or a review of an existing change set; route those to the appropriate direct workflow.

When the proposed product behavior includes an AI agent or workflow, identify prompts, context/history, model/tool calls, state transitions and human gates in the plan. Follow [ai-engineering](../ai-engineering/SKILL.md) to select the simplest sufficient execution shape and pass only applicable shared design guides with the bounded handoff. Use `team-ai-architect` for a read-only proposal only when material AI-specific choices remain unresolved; `team-architect` retains software-wide structure and cross-module architecture. Simulation is optional and explicit; it is not a prerequisite or production authorization.

When the plan includes application AI behavior evaluation, read the shared [AI evaluation contract](../team-core/references/ai-evaluation.md) and identify `team-ai-tester`'s evaluation scope and evidence. Keep ordinary business, integration, UI and harness assertions assigned under shared role routing.

## Build the plan

At task start, use the shared [risk-proportional design-exploration contract](../team-core/references/design-exploration.md) to choose a light check or fuller exploration from material risk and unresolved uncertainty, not task/file size. An already accepted cross-module design does not need to be reopened unless relevant evidence or scope changed. For child assignments, pass the overall goal, applicable PRD and accepted design/Blueprint revisions, non-goals, relevant constraints/evidence/decisions/unknowns, and the exact applicable shared reference; do not assume conversation or Skill inheritance. Explorer supplies bounded facts, Architects propose read-only designs when material questions require them, and no role is added without a concrete need.

Apply [role routing](../team-core/references/role-routing.md) before delegation: check needed named roles in the active tool catalog, explicitly select them, and ask before any unavailable-role alternative. Task labels and source profiles do not prove runtime identity. Reconcile actual calls and include the [handoff format](../team-core/references/handoff-format.md)'s actual child roster in the final response, including failures/retries or explicit none.

Read the [documentation governance](../team-core/references/documentation-governance.md) authority in full. Assess task-specific docs, stale evidence and applicable PRDs; use team-docs-maintainer for substantial inventory/consistency work and Explorer for code facts. Report ambiguity rather than resolving it. Planning may identify governance gaps but does not authorize records or claim development readiness; `$team-dev` validates the current assessment before writers start.

Read the [project-rules contract](../team-core/references/project-rules.md) in full and assess applicable instructions at the task/module checkpoints it defines. Surface only material evidenced gaps with the exact path, impact, proposed delta and approval question. Planning never writes target instructions; any later write needs approval for its bounded path/rules. Reuse reachable decisions unless relevant evidence or scope materially changes.

Check for `openspec/team-integration.json`. If present, read the [spec lifecycle](../team-core/references/spec-lifecycle.md) in full: use its sole task list and link scenarios/tasks to packets. Planning may propose artifacts but does not enable the integration, change its configuration, or authorize implementation; missing/stale spec evidence remains explicit. Without the marker, keep the native planning workflow.

For UI work, read and apply the [UI delivery contract](../team-core/references/ui-quality.md) in full. Include a lightweight brief, coherent page/flow ownership, baseline resources, shared-style scope, and separate functional/rendered verification. Do not reduce the product goal to component tickets or add a design-document approval gate.

For a new application, multi-stage effort, or material boundary change, read the [Project Blueprint contract](../team-core/references/project-blueprint.md) in full and assess its gate before breaking work into stages. Distinguish inspected facts from proposals and use its mapping. If not applicable, record that briefly. Planning does not authorize code moves; structural refactoring requires explicit user approval and a retained-baseline option.

For a material architecture, contract, workflow/state, configuration/eligibility, persisted-data/job, or compatibility migration, use the conditional [architecture and contract migration guide](../team-core/references/architecture-migration.md) to map old rules to approved target semantics, actual consumers, owners, and tests. Keep module structure in the Blueprint and acceptance evidence in the existing packet; do not impose an exhaustive migration pass on an internal/model-only change with unchanged approved semantics.

Read [role routing](../team-core/references/role-routing.md) and [file ownership](../team-core/references/file-ownership.md) in full before delegation or assigning ownership. Read [execution templates](../team-core/references/execution-templates.md), the [Test & Acceptance Contract](../team-core/references/test-acceptance-contract.md), and [TDD protocol](../team-core/references/tdd-protocol.md) in full when forming the Work contract and preliminary test plan. Read the [handoff format](../team-core/references/handoff-format.md) in full when preparing the plan handoff; read [feedback recording](../team-core/references/feedback-recording.md) in full after that handoff is prepared.

For work likely to revisit a known defect, read the [repair and diagnosis loop guard](../team-core/references/repair-loop-guard.md) in full. Preserve issue identity/history and state any requested mode, allocation, long-operation checkpoints and stop condition in the Work contract; planning grants no repair/debug authority.

Apply the [efficient test execution and tier rules](../team-core/references/test-acceptance-contract.md#efficient-test-execution) in full when proposing test layers and commands, including the [standalone small-task rule](../team-core/references/test-acceptance-contract.md#tier-selection-reuse-and-resource-limits). Record the entrypoint, real boundary, runner, observation mode and rationale; preserve complete manual coverage. Name iteration, first-usable-chain, and acceptance checkpoints, set due evidence before downstream reliance, and give deferred checks owners/triggers. Do not plan dependent work across known failures or past due evidence. Request scoped Explorer facts only when the surface is not readily known; the plan never decides a required test may be skipped.

1. Create a Task record: outcome, constraints, acceptance checks, and open questions.
2. Discover repository facts. Use `team-explorer` for unfamiliar scope and `team-architect` for cross-module contracts; request bounded findings with evidence.
3. Turn evidence into a Work contract. Define affected boundaries, ownership, compatibility, verification, and rollout or recovery needs when material.
4. Write ordered tasks only after shared contracts are resolved. Each task needs an owner, a deliverable, dependencies, and a verification step.
5. Self-check the plan: every acceptance check has a task and verification; no task assumes facts that discovery did not establish.
6. Include use cases, coverage-category decisions, a preliminary behavior-to-test mapping, likely TDD tracks, known test entrypoints and environment gaps, automated/E2E plan, and human verification requirements. `$team-dev` turns this into the tracked, validated stage packet before implementation.

Read the [manual-scope and automated-coverage rules](../team-core/references/test-acceptance-contract.md#manual-scope-and-automated-coverage) in full. Map every manual case to E2E conditions/results and checkpoints, assess other applicable layers, and ask before exceptions or ambiguous scope; planning does not implement tests or rewrite archived acceptance.

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
