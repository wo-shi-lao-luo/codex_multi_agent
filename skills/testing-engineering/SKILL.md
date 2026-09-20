---
name: testing-engineering
description: Plan and implement focused, evidence-backed tests for changed behavior, regressions, boundary cases, and integration risks.
---

# Testing engineering

Use this Skill to design and verify meaningful tests. Apply the shared [execution contract](../team-core/references/execution-contract.md), [execution templates](../team-core/references/execution-templates.md), and [TDD protocol](../team-core/references/tdd-protocol.md); tests should demonstrate behavior and risk coverage, not mirror implementation details.

## When to activate

Use when a change, defect, regression, integration, or acceptance check needs test planning or test implementation.

Do not use to impose a generic coverage target, create tests solely to increase count, or replace an existing repository test convention without a task-specific reason.

## Discover the test surface

1. Find the repository's test commands, test layers, fixtures, and nearby behavioral examples.
2. Read the Task record and Work contract. Identify changed behavior, failure paths, boundaries, integration points, and the regression that should be prevented.
3. Choose the narrowest test layer that can observe the risk. Escalate to integration or end-to-end coverage only when lower layers cannot establish the needed behavior.

## Build a test contract

Create a concise test matrix:

```text
Behavior or acceptance check → test layer → scenario → expected evidence
Failure or boundary risk → test layer → scenario → expected evidence
```

State any important risk that cannot be tested in the available environment and identify the smallest practical substitute check.

For team development, assess unit, integration, contract/API, E2E, regression, and manual coverage as `required`, `conditional`, or `not applicable`; assess component/UI, accessibility, visual regression, performance/load, security, compatibility, data migration/rollback, resilience/recovery, and exploratory/usability when material. Record every reason; never use a line-coverage target as a substitute for behavior coverage.

For every material behavior, choose `test-first`, `test-after`, or `manual-or-environmental`. Prefer the narrowest observable layer. A completed `test-first` row records named test identity plus actual Red, Green, and post-refactor evidence; another track records a concrete reason and smallest credible alternative.

## Execute and verify

Implement tests using local conventions. Run the relevant commands once they meaningfully cover the changed path. Record whether each planned scenario passed, failed as expected during diagnosis, was not runnable, or needs a wider environment.

## Return paths

- A test exposes a behavior or contract mismatch → return it to the owner with the failing evidence.
- A unit test cannot observe the risk → revise the test contract to an integration, end-to-end, or manual verification layer.
- A flaky or environment-dependent result → separate the observed evidence from the suspected cause; do not count it as stable regression coverage.

## Output contract

Return the test matrix, changed or inspected test files, commands and results, uncovered risks, and the verification evidence that supports completion.
