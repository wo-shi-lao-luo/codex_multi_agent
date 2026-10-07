---
name: code-review
description: Independently review a change set for correctness, security, maintainability, compatibility, and verification gaps using a structured evidence workflow.
---

# Code review

Use this Skill for focused review work. Read the shared [execution contract](../team-core/references/execution-contract.md), [execution templates](../team-core/references/execution-templates.md), and applicable [Test & Acceptance Contract](../team-core/references/test-acceptance-contract.md) in full; findings must be evidence-backed and actionable.


## When to activate

Use for a branch, diff, pull request, staged change, or bounded change set that needs independent correctness and maintainability review.

Do not use without an inspectable scope. Do not turn a review into a style rewrite or make a finding from preference alone.

## Establish scope and risk coverage

For visible UI changes, apply the [UI delivery contract](../team-core/references/ui-quality.md). Inspect available final-page evidence against the UI brief, not only the component diff. Record which routes, viewports and states were inspected; code-only evidence cannot establish visual quality. Do not relabel agent inspection as user approval.

1. Record the baseline, changed files, intended behavior, and relevant tests or verification already run.
2. Read the diff and enough surrounding code to trace changed inputs, outputs, error handling, authorization, data effects, concurrency, compatibility, and observable behavior.
3. Build a Review coverage record. Identify which risks were reviewed and which need a specialized reviewer, such as database safety or test adequacy.

## Evaluate findings

For an enabled OpenSpec project, apply the [spec lifecycle](../team-core/references/spec-lifecycle.md). Inspect intent/design/task consistency and actual assertion coverage beyond the structural link validator. Report stale snapshots, unmapped scenarios, unsupported exceptions and premature closure; do not run write operations or certify user acceptance.

Apply the [code comment contract](../team-core/references/code-comments.md): check layered documentation minimums and every in-scope test's scenario/expected-result explanation against behavior and assertions. Missing mandatory explanations are contract-compliance gaps, not stylistic preferences. Record scope, outcome, exemptions and gaps; rank misleading explanations by concrete impact.

Apply the [code readability contract](../team-core/references/code-readability.md) for assigned code. Judge layout against the project's existing formatter/configuration and concrete readability needs; do not turn review into a style rewrite. A formatting-only pass must preserve behavior and existing test explanations.

Prioritize incorrect assumptions, broken error handling, authorization gaps, unsafe data changes, concurrency issues, compatibility breaks, and missing verification. A material finding includes:

```text
Impact
Precise file reference
Evidence and concrete failure mode
Smallest useful remediation or verification step
```

Classify a concern without evidence as a question or uncovered risk, not as a defect.

For a standalone small fix, use the [small-task test rule](../team-core/references/test-acceptance-contract.md#tier-selection-reuse-and-resource-limits): check affected evidence and its due handoff without demanding every layer/full suite by default. Preserve risk/gate overrides, complete planned coverage, manual/E2E evidence, and acceptance authority.

## Return paths

- No usable diff or baseline → request the review scope.
- A material issue is confirmed → return it to the owning implementation contract for a focused fix and re-verification.
- When returning a confirmed issue for repair, preserve its existing identity and cumulative history under the [repair and diagnosis loop guard](../team-core/references/repair-loop-guard.md); review does not reset or replenish an attempt budget.
- A specialized risk is outside review coverage → name the gap and recommend the smallest expanded review.

## Output contract

Report findings ranked by impact, followed by scope inspected, checks performed, evidence, and uncovered risks. If no material issue is found, state the coverage achieved rather than manufacturing stylistic feedback.
