---
name: team-review
description: Review a branch, diff, pull request, or change set with independent, evidence-backed Codex coverage. Use explicitly as $team-review when a change needs structured review rather than implementation.
---

# Team review

Read [documentation governance](../team-core/references/documentation-governance.md) when reviewing development readiness or document alignment. Inspect the current review's scope/freshness, applicable PRD decisions, actual read evidence and unresolved findings. A marker/hash alone cannot prove sufficiency. Check implemented changes against confirmed intent and factual documentation; do not rewrite or archive disputed material during review.

Act as the Lead. This workflow owns **Discover → Verify → Handoff** from the shared [execution contract](../team-core/references/execution-contract.md). It reviews existing work and does not edit code unless the user explicitly starts a follow-up implementation task.

## When to activate

Use for a branch, diff, pull request, staged change, or specified change set that needs independent review coverage.

Do not use without a reviewable scope. Do not convert a review into a refactor, a style pass, or an implementation task.

## Establish coverage

Apply [role routing](../team-core/references/role-routing.md) before delegation: check needed named roles in the active tool catalog, explicitly select them, and ask before any unavailable-role alternative. Task labels and source profiles do not prove runtime identity. Reconcile actual calls and include the [handoff format](../team-core/references/handoff-format.md)'s actual child roster in the final response, including failures/retries or explicit none. Audit recorded selection against call evidence; an authored ledger is not independent proof.

For a project with `openspec/team-integration.json`, apply the [spec lifecycle](../team-core/references/spec-lifecycle.md). Review requirement/scenario/task/packet links, changed and removed behavior, stale evidence, and real assertions; IDs and checked tasks alone do not prove correctness. Inspect CloseCheck results without archiving or changing reviewer/user acceptance. Do not enable an absent integration during review.

For UI changes, use the [UI delivery contract](../team-core/references/ui-quality.md) to review the assembled page against its brief and rendered evidence. Separate functional and visual conclusions; missing browser evidence is an uncovered visual check, not a pass. Report concrete hierarchy, consistency, layout or interaction defects without imposing personal taste.

Apply the [code comment contract](../team-core/references/code-comments.md): check layered documentation minimums and every in-scope test's scenario/expected-result explanation against behavior and assertions. Missing mandatory explanations are contract-compliance gaps, not stylistic preferences. Record scope, outcome, exemptions and gaps; rank misleading explanations by concrete impact.

When returning a confirmed finding for implementation, link it to the owning issue and its existing repair history under the [repair and diagnosis loop guard](../team-core/references/repair-loop-guard.md). A review finding does not create a fresh retry budget.

Apply the [Project Blueprint contract](../team-core/references/project-blueprint.md): compare the actual diff with declared modules, file responsibilities and root exceptions. Verify any existing-code refactor has explicit approval for that scope. Respect recorded declined/deferred decisions; report new concrete risks without re-demanding a previously declined refactor. Structural review is semantic; document validation alone does not establish compliance.

Read [role routing](../team-core/references/role-routing.md), [handoff format](../team-core/references/handoff-format.md), [execution templates](../team-core/references/execution-templates.md), [TDD protocol](../team-core/references/tdd-protocol.md), and [feedback recording](../team-core/references/feedback-recording.md).

1. Record the exact review scope, baseline, and stated intent. Inspect the actual diff and enough surrounding code to understand behavior.
2. Build a Review coverage record. Choose independent read-only roles only where they add distinct coverage: `team-reviewer` for correctness and maintainability, `team-tester` for verification gaps, `team-database-specialist` for material data changes, and `team-explorer` for unfamiliar areas.
3. Give each reviewer a bounded question, requested evidence, and file scope. Follow [adaptive child-thread concurrency](../team-core/references/role-routing.md#adaptive-child-thread-concurrency); review tasks may use fewer roles when that gives sufficient independent coverage.
4. Audit behavior-to-test traceability where a stage packet exists: test-first rows need Red/Green/refactor evidence; non-test-first rows need a concrete reason and alternative evidence. Treat unsupported exceptions and material regression gaps as verification findings.
5. De-duplicate findings. A finding needs impact, evidence, a precise file reference, and a concrete failure mode or missing verification.

Audit the [manual scope and automated coverage contract](../team-core/references/test-acceptance-contract.md#manual-scope-and-automated-coverage): compare every manual case/requirement, including user additions, against actual E2E conditions/checkpoints/results and applicable other-layer assertions. Report unmapped cases, stale passes, lower-layer-only substitutes and unapproved automation exceptions. A complete plan table is not proof of executed coverage or user acceptance. Review recommends updates without editing tests or historical packets.

Also audit the test contract's [efficient test execution](../team-core/references/test-acceptance-contract.md#efficient-test-execution) choices: confirm that API/integration evidence exercises its declared real boundary, that browser checks retain complete representative journeys and distinct UI/client/linkage risks, that prior results were reused only with adequate relevant-input provenance, and that wider repository gates were honored. Any reduced duplicate browser permutations need equivalent per-case evidence. Check retained artifacts and status distinctions; summaries alone do not establish a pass, reused evidence is not freshly executed, and missing safety-sensitive inspection remains a gap.

## Decision and return gates

- No diff, baseline, or usable change scope → stop and request it rather than inventing review coverage.
- A reviewer reports a concern without evidence or a plausible failure mode → treat it as a question, not a finding.
- A material data, security, or contract risk is uncovered outside the assigned scope → report it as an uncovered risk and recommend the smallest expanded review.

## Output contract

Return findings ranked by impact, then the coverage record: scope inspected, checks performed, TDD evidence audited, and uncovered risks. If there are no material findings, say so and state what was reviewed; do not manufacture stylistic findings.

After preparing the review handoff, create the local minimal feedback record described in [feedback recording](../team-core/references/feedback-recording.md). Keep it to coverage, evidence, and risks; do not copy the reviewed diff or raw findings into the feedback store. A recording failure leaves the review result unchanged.
