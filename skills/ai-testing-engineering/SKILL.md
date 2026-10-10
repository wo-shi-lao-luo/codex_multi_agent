---
name: ai-testing-engineering
description: Plan, implement, and assess focused evaluation tests for application AI behavior during Agent, Workflow, or model changes. Use with team-ai-tester; local prototype simulation remains a separate explicit workflow.
---

# AI testing engineering

Use this Skill for authorized application AI behavior testing, including when changing a model, prompt, context policy, tools, Agent or Workflow. It does not authorize product changes, paid calls, or convert a prototype into production acceptance.

Read the shared [execution contract](../team-core/references/execution-contract.md) for the Team lifecycle and ownership rules.

Read the shared [AI evaluation contract](../team-core/references/ai-evaluation.md) for role boundaries, case/rubric design, evaluator calibration, stochastic baselines, bounded repeats, and evidence. For shared test-tier, packet, TDD and manual/E2E obligations, read the [Test & Acceptance Contract](../team-core/references/test-acceptance-contract.md) and [TDD protocol](../team-core/references/tdd-protocol.md). For captured application-boundary fixtures, also read the [AI record/replay testing contract](../team-core/references/ai-record-replay-testing.md).

Use the four shared AI design guides conditionally when the evaluated behavior involves workflow shape, instructions/references, context assembly or tools: [workflow](../team-core/references/ai-workflow-design.md), [instruction](../team-core/references/ai-instruction-design.md), [context](../team-core/references/ai-context-design.md) and [tool](../team-core/references/ai-tool-design.md). Assert that intended instruction/reference revisions and selected context reach the call path; a source-file or selector-only check is insufficient. Where traces expose intermediate calls, use them to locate assembly/routing failures and pair them with user-visible outcome checks. Diagnose whether a failure arises from design/instructions, selection or assembly, tool/runtime, model variability, or evaluator/rubric. Reuse the evaluation contract for judges, hard gates, baselines, repeats and budgets; do not create a competing rubric or result schema. Cost remains unknown without reliable telemetry.

Own only the assigned AI evaluation cases, tests/runners, curated fixtures, and canonical stage-packet scope. If selected as the packet owner, maintain that single packet; otherwise write only the assigned AI-evaluation section in the packet owned by the Lead or another Tester. Do not create a parallel result packet or decide/certify user acceptance yourself. Update manual-acceptance fields only from direct user evidence or explicit user deferral, following the shared [Test & Acceptance Contract](../team-core/references/test-acceptance-contract.md). Keep expected criteria and scoring independent from the behavior under test. Coordinate one canonical packet owner with the Lead and ordinary `team-tester` when a task also needs separate software-level assertions; do not duplicate a role without a distinct coverage need. Harness/package tests belong to ordinary software testing.

Do not edit production prompts, application/runtime code, workflow definitions, or the local `$team-ai-simulate` definition. During simulation, assess only the Lead-provided criteria from an independent context; never score the actor through its own context. Report each attempt, calibration limits, known/unknown tested and judge identities, and unverified risks without treating source model settings as runtime evidence.

Follow existing TDD tracks: deterministic assertions use test-first where practical; a stochastic baseline is recorded before a behavior change when authorized but is not fabricated Red evidence. Preserve the existing packet schema, required E2E/manual mapping, approval gates, explicit budgets and user-only acceptance.

## When to activate

Use when an authorized task needs tests or independent assessment of an application's AI behavior, including a model, prompt, context, tool, Agent or Workflow change. For local AI prototype simulation, activate only through the explicit `$team-ai-simulate` workflow. Harness/package tests remain ordinary software testing.

## Output contract

Return Result, Evidence, Risks, Next step, assigned evaluation files changed, and verification performed. State the tested behavior and judge identities separately when known, preserve unknowns honestly, and leave user-only acceptance pending without user evidence.
