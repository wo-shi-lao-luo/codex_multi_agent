---
name: team-debug
description: Investigate a bug with uncertain root cause using bounded, evidence-led Codex analysis. Use explicitly as $team-debug before implementing a complex or poorly understood fix.
---

# Team debug

Act as the Lead. This workflow emphasizes **Context → Discover → Contract** from the shared [execution contract](../team-core/references/execution-contract.md). It produces a recommended fix scope and verification plan; it does not turn speculation into implementation.

## When to activate

Use for a failing test, unexpected behavior, regression, performance symptom, data inconsistency, or integration failure whose cause is not established.

Do not use when the root cause and safe fix are already evidenced, or when the request is only to review an existing diff. Route data consistency, query, transaction, or migration symptoms to `team-database-specialist`.

## Investigate

Read [handoff format](../team-core/references/handoff-format.md) and [execution templates](../team-core/references/execution-templates.md).

1. Create a Task record with symptom, expected behavior, reproduction, available logs, and impact.
2. Build a Debug hypothesis ledger. Separate observations from hypotheses and choose the smallest discriminating check for each hypothesis.
3. Delegate independent investigations to `team-explorer`, `team-tester`, and the relevant domain owner. Give each a different question or evidence source; do not create duplicate exploration.
4. Compare results. Reject hypotheses with contrary evidence and identify the most likely root cause, including confidence and remaining uncertainty.
5. Produce a Work contract for the smallest fix scope and its verification. Implementation begins only after this evidence gate passes.

## Decision and return gates

- Reproduction is absent or evidence conflicts → continue Discover with a narrower hypothesis.
- An experiment changes code or data materially → treat it as implementation and establish a Work contract first.
- The cause is external, environmental, or still unproven → report the investigated evidence, containment options, and monitoring needed; do not label it fixed.

## Output contract

Return:

```text
Symptom, reproduction, and impact
Observations and evidence
Hypotheses tested: supported, rejected, or inconclusive
Likely root cause and confidence
Recommended fix scope, owner, and verification plan
Remaining uncertainty or required user decision
```
