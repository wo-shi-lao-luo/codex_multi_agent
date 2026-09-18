---
name: code-review
description: Independently review a change set for correctness, security, maintainability, compatibility, and verification gaps using a structured evidence workflow.
---

# Code review

Use this Skill for focused review work. Apply the shared [execution contract](../team-core/references/execution-contract.md) and [execution templates](../team-core/references/execution-templates.md); review findings must be evidence-backed and actionable.

## When to activate

Use for a branch, diff, pull request, staged change, or bounded change set that needs independent correctness and maintainability review.

Do not use without an inspectable scope. Do not turn a review into a style rewrite or make a finding from preference alone.

## Establish scope and risk coverage

1. Record the baseline, changed files, intended behavior, and relevant tests or verification already run.
2. Read the diff and enough surrounding code to trace changed inputs, outputs, error handling, authorization, data effects, concurrency, compatibility, and observable behavior.
3. Build a Review coverage record. Identify which risks were reviewed and which need a specialized reviewer, such as database safety or test adequacy.

## Evaluate findings

Prioritize incorrect assumptions, broken error handling, authorization gaps, unsafe data changes, concurrency issues, compatibility breaks, and missing verification. A material finding includes:

```text
Impact
Precise file reference
Evidence and concrete failure mode
Smallest useful remediation or verification step
```

Classify a concern without evidence as a question or uncovered risk, not as a defect.

## Return paths

- No usable diff or baseline → request the review scope.
- A material issue is confirmed → return it to the owning implementation contract for a focused fix and re-verification.
- A specialized risk is outside review coverage → name the gap and recommend the smallest expanded review.

## Output contract

Report findings ranked by impact, followed by scope inspected, checks performed, evidence, and uncovered risks. If no material issue is found, state the coverage achieved rather than manufacturing stylistic feedback.
