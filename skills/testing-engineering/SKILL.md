---
name: testing-engineering
description: Plan and implement focused, evidence-backed tests for changed behavior, regressions, boundary cases, and integration risks.
---

# Testing engineering

Use this Skill to design and verify meaningful tests. Read the shared [execution contract](../team-core/references/execution-contract.md), [execution templates](../team-core/references/execution-templates.md), [TDD protocol](../team-core/references/tdd-protocol.md), and [Test & Acceptance Contract](../team-core/references/test-acceptance-contract.md) in full; tests should demonstrate behavior and risk coverage, not mirror implementation details.

When a tested application includes a replaceable Agent/Workflow capability, read the [AI record/replay testing contract](../team-core/references/ai-record-replay-testing.md) for evidence boundaries, fixture safety and invalidation. Keep stage coverage and results in the packet; a replay is not live E2E evidence.

When test scope includes application AI behavior, read the [AI evaluation contract](../team-core/references/ai-evaluation.md) and route AI-specific evaluation to `team-ai-tester`; retain deterministic business behavior and harness/package coverage according to shared role routing.


## When to activate

Use when a change, defect, regression, integration, or acceptance check needs test planning or test implementation.

Do not use to impose a generic coverage target, create tests solely to increase count, or replace an existing repository test convention without a task-specific reason.

## Discover the test surface

1. Find the repository's test commands, test layers, fixtures, and nearby behavioral examples.
2. Read the Task record and Work contract. Identify changed behavior, failure paths, boundaries, integration points, and the regression that should be prevented.
   If a failing check is part of an existing diagnosis/repair loop, preserve its issue identity and result evidence under the [repair and diagnosis loop guard](../team-core/references/repair-loop-guard.md); a failed test run is not automatically a failed repair attempt.
3. Choose the adequate test boundary and observation method under the contract's [efficient execution and tier rules](../team-core/references/test-acceptance-contract.md#efficient-test-execution). For a standalone small change/bug, follow the [small-task rule](../team-core/references/test-acceptance-contract.md#tier-selection-reuse-and-resource-limits); include real UI/integration evidence when the symptom requires it. Do not force unrelated layers or a full suite for each fix, but honor risk expansion and repository gates. The Tester retains selection, execution and sufficiency decisions.
4. Plan checks at the contract's iteration, first-usable-chain and named acceptance checkpoints. For deferred checks, record owner, scope/IDs, status, next trigger and flush condition; planned work is never a pass, and known failures block dependent work. If the scoped test surface is unclear and not cheap to map, request a bounded Explorer lookup.

## Build a test contract

For an enabled OpenSpec project, apply the [spec lifecycle](../team-core/references/spec-lifecycle.md). Map requirement/scenario and task IDs to CASE IDs in the existing stage packet, cover changes/removals with regression evidence, and reassess results whenever the specification snapshot changes. Keep test results only in packets; the association index stores links, not duplicate outcomes. Agent verification never fabricates user acceptance.

Apply the [Project Blueprint contract](../team-core/references/project-blueprint.md) when a blueprint governs the task. Map behavioral tests to its module IDs. Before an approved existing-code refactor, capture current behavior with characterization/regression tests and baseline failures; verify behavior preservation after the move. A declined refactor retains current test entrypoints and documents coverage constraints.

For a material architecture, contract, workflow/state, configuration/eligibility, persisted-data/job, or compatibility migration, also use the conditional [architecture and contract migration guide](../team-core/references/architecture-migration.md). Where applicable, test the synthetic/replay boundary through the real consumer path to its storage, state, eligibility, user operation, and final outcome. Keep deterministic software assertions separate from AI behavior evaluation and live end-to-end evidence, and follow the existing packet's test tiers and deferral rules.

Create a concise test matrix:

```text
Behavior or acceptance check → test layer → scenario → expected evidence
Failure or boundary risk → test layer → scenario → expected evidence
```

State any important risk that cannot be tested in the available environment and identify the smallest practical substitute check.

For team development, assess unit, integration, contract/API, E2E, regression, and manual coverage as `required`, `conditional`, or `not applicable`; assess component/UI, accessibility, visual regression, performance/load, security, compatibility, data migration/rollback, resilience/recovery, and exploratory/usability when material. Record every reason; never use a line-coverage target as a substitute for behavior coverage.

For every material behavior, choose `test-first`, `test-after`, or `manual-or-environmental`. Prefer the narrowest observable layer. A completed `test-first` row records named test identity plus actual Red, Green, and post-refactor evidence; another track records a concrete reason and smallest credible alternative.

Apply [manual scope and automated coverage](../team-core/references/test-acceptance-contract.md#manual-scope-and-automated-coverage): the E2E plan includes every manual scenario/requirement by stable ID, equivalent conditions/results and explicit checkpoints, not counts. Lower-layer coverage does not replace an E2E flow. Keep unautomatable observations and pending user exception decisions visible; plan inclusion is not executed/passing coverage. When users add/change manual samples or requirements, preserve their input and update the manual/E2E mapping, E2E tests where feasible and applicable other test layers/assertions; reuse proven existing tests with exact evidence. Reassess tracks/results and rerun affected checks. Ask on ambiguity, expanded scope or automation exceptions; do not rewrite archived acceptance or implement during review-only work.

## Execute and verify

For visible UI changes, apply the [UI delivery contract](../team-core/references/ui-quality.md). Keep functional test results separate from rendered-page observations and visual status. Component/E2E assertions and screenshot-diff checks do not replace inspection for hierarchy, consistency and usability. Record unobserved states honestly; agent inspection does not complete user-only manual checks.

Apply the [code comment contract](../team-core/references/code-comments.md): meet its layered minimums for files, interfaces and internal business logic, and provide scenario/expected-result explanations for every in-scope test case, even simple ones. Self-check documentation against behavior and assertions; record scope, outcome, exemptions and gaps in the Verification record. For review-only work, inspect and report without editing.

Apply the shared [code readability contract](../team-core/references/code-readability.md) to assigned tests. Follow the project formatter/configuration and preserve the purpose/expected-result explanation for each independent scenario; formatting-only work must not change assertions or test behavior.

Implement tests using local conventions. Run the relevant commands once they meaningfully cover the changed path. Record whether each planned scenario passed, failed as expected during diagnosis, was not runnable, or needs a wider environment.

## Return paths

- A test exposes a behavior or contract mismatch → return it to the owner with the failing evidence.
- A unit test cannot observe the risk → revise the test contract to an integration, end-to-end, or manual verification layer.
- A flaky or environment-dependent result → separate the observed evidence from the suspected cause; do not count it as stable regression coverage.

## Output contract

Return the test matrix, changed or inspected test files, commands and results, uncovered risks, and the verification evidence that supports completion.
