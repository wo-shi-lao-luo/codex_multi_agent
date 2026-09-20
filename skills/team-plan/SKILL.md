---
name: team-plan
description: Produce a decision-ready, evidence-backed implementation plan without editing code. Use explicitly as $team-plan for a feature, refactor, integration, or uncertain technical change.
---

# Team plan

Act as the Lead. This workflow owns **Context → Discover → Contract → Handoff** from the shared [execution contract](../team-core/references/execution-contract.md). Do not edit production code, tests, configuration, or external systems.

## When to activate

Use for a feature, refactor, integration, or technical change that needs repository evidence, an agreed design, ordered work, or an ownership decision before implementation.

Do not use for a one-line factual answer, a request to implement immediately after a sufficient approved plan, or a review of an existing change set; route those to the appropriate direct workflow.

## Build the plan

Read [role routing](../team-core/references/role-routing.md), [file ownership](../team-core/references/file-ownership.md), [handoff format](../team-core/references/handoff-format.md), [execution templates](../team-core/references/execution-templates.md), [test and acceptance contract](../team-core/references/test-acceptance-contract.md), [TDD protocol](../team-core/references/tdd-protocol.md), and [feedback recording](../team-core/references/feedback-recording.md).

1. Create a Task record: outcome, constraints, acceptance checks, and open questions.
2. Discover repository facts. Use `team-explorer` for unfamiliar scope and `team-architect` for cross-module contracts; request bounded findings with evidence.
3. Turn evidence into a Work contract. Define affected boundaries, ownership, compatibility, verification, and rollout or recovery needs when material.
4. Write ordered tasks only after shared contracts are resolved. Each task needs an owner, a deliverable, dependencies, and a verification step.
5. Self-check the plan: every acceptance check has a task and verification; no task assumes facts that discovery did not establish.
6. Include use cases, coverage-category decisions, a preliminary behavior-to-test mapping, likely TDD tracks, known test entrypoints and environment gaps, automated/E2E plan, and human verification requirements. `$team-dev` turns this into the tracked, validated stage packet before implementation.

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
