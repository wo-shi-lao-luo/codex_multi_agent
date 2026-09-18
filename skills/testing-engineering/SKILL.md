---
name: testing-engineering
description: Plan and implement focused, evidence-backed tests for changed behavior, regressions, boundary cases, and integration risks.
---

# Testing engineering

Use this Skill to design and verify meaningful tests. Apply the shared [execution contract](../team-core/references/execution-contract.md) and [execution templates](../team-core/references/execution-templates.md); tests should demonstrate behavior and risk coverage, not mirror implementation details.

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

## Execute and verify

Implement tests using local conventions. Run the relevant commands once they meaningfully cover the changed path. Record whether each planned scenario passed, failed as expected during diagnosis, was not runnable, or needs a wider environment.

## Return paths

- A test exposes a behavior or contract mismatch → return it to the owner with the failing evidence.
- A unit test cannot observe the risk → revise the test contract to an integration, end-to-end, or manual verification layer.
- A flaky or environment-dependent result → separate the observed evidence from the suspected cause; do not count it as stable regression coverage.

## Output contract

Return the test matrix, changed or inspected test files, commands and results, uncovered risks, and the verification evidence that supports completion.
