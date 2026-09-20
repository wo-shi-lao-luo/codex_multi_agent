---
name: team-review
description: Review a branch, diff, pull request, or change set with independent, evidence-backed Codex coverage. Use explicitly as $team-review when a change needs structured review rather than implementation.
---

# Team review

Act as the Lead. This workflow owns **Discover → Verify → Handoff** from the shared [execution contract](../team-core/references/execution-contract.md). It reviews existing work and does not edit code unless the user explicitly starts a follow-up implementation task.

## When to activate

Use for a branch, diff, pull request, staged change, or specified change set that needs independent review coverage.

Do not use without a reviewable scope. Do not convert a review into a refactor, a style pass, or an implementation task.

## Establish coverage

Apply the [code comment contract](../team-core/references/code-comments.md): inspect important comments against behavior and missing rationale at risky decisions. Record scope and outcome; report concrete impact, not stylistic preferences.

Apply the [Project Blueprint contract](../team-core/references/project-blueprint.md): compare the actual diff with declared modules, file responsibilities and root exceptions. Verify any existing-code refactor has explicit approval for that scope. Respect recorded declined/deferred decisions; report new concrete risks without re-demanding a previously declined refactor. Structural review is semantic; document validation alone does not establish compliance.

Read [role routing](../team-core/references/role-routing.md), [handoff format](../team-core/references/handoff-format.md), [execution templates](../team-core/references/execution-templates.md), [TDD protocol](../team-core/references/tdd-protocol.md), and [feedback recording](../team-core/references/feedback-recording.md).

1. Record the exact review scope, baseline, and stated intent. Inspect the actual diff and enough surrounding code to understand behavior.
2. Build a Review coverage record. Choose independent read-only roles only where they add distinct coverage: `team-reviewer` for correctness and maintainability, `team-tester` for verification gaps, `team-database-specialist` for material data changes, and `team-explorer` for unfamiliar areas.
3. Give each reviewer a bounded question, requested evidence, and file scope. Use at most three child threads.
4. Audit behavior-to-test traceability where a stage packet exists: test-first rows need Red/Green/refactor evidence; non-test-first rows need a concrete reason and alternative evidence. Treat unsupported exceptions and material regression gaps as verification findings.
5. De-duplicate findings. A finding needs impact, evidence, a precise file reference, and a concrete failure mode or missing verification.

## Decision and return gates

- No diff, baseline, or usable change scope → stop and request it rather than inventing review coverage.
- A reviewer reports a concern without evidence or a plausible failure mode → treat it as a question, not a finding.
- A material data, security, or contract risk is uncovered outside the assigned scope → report it as an uncovered risk and recommend the smallest expanded review.

## Output contract

Return findings ranked by impact, then the coverage record: scope inspected, checks performed, TDD evidence audited, and uncovered risks. If there are no material findings, say so and state what was reviewed; do not manufacture stylistic findings.

After preparing the review handoff, create the local minimal feedback record described in [feedback recording](../team-core/references/feedback-recording.md). Keep it to coverage, evidence, and risks; do not copy the reviewed diff or raw findings into the feedback store. A recording failure leaves the review result unchanged.
