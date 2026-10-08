---
name: team-review
description: Review a branch, diff, pull request, or change set with independent, evidence-backed Codex coverage. Use explicitly as $team-review when a change needs structured review rather than implementation.
---

# Team review

When reviewing development readiness or document alignment, read [documentation governance](../team-core/references/documentation-governance.md) in full. Check review scope/freshness, applicable PRDs, actual read evidence and unresolved findings; a marker/hash alone cannot prove sufficiency. Compare changes with confirmed intent; do not rewrite/archive disputed material.

Act as the Lead. Read the shared [execution contract](../team-core/references/execution-contract.md) in full. This workflow owns **Discover → Verify → Handoff** and reviews existing work; do not edit code unless the user explicitly starts a follow-up implementation task.


## When to activate

Use for a branch, diff, pull request, staged change, or specified change set that needs independent review coverage.

Do not use without a reviewable scope. Do not convert a review into a refactor, a style pass, or an implementation task.

## Establish coverage

Read [role routing](../team-core/references/role-routing.md) in full before delegation. Check exact needed role selectors against the active catalog, preserve unavailable-role/identity limits, and reconcile call evidence; a task label or authored ledger is not independent proof. Include the actual roster, including failures/retries or explicit none, using the handoff format.

For a project with `openspec/team-integration.json`, read and apply the [spec lifecycle](../team-core/references/spec-lifecycle.md) in full. Check links, changed/removed behavior, stale evidence and actual assertions; inspect CloseCheck without archiving or changing acceptance. Do not enable an absent integration.

For UI changes, read the [UI delivery contract](../team-core/references/ui-quality.md) in full. Compare the assembled page with its brief/rendered evidence; separate functional and visual conclusions and report missing inspection as uncovered, not passed.

When the review includes an AI workflow or simulation, read the [AI simulation contract](../team-core/references/ai-simulation.md) in full and use `ai-engineering` when relevant. Check context, model identity, mock/real boundaries and prototype-versus-production claims.

The `team-reviewer` remains the independent review owner. Request `team-ai-architect` only when a material AI-specific design question needs a bounded read-only assessment; involve `team-architect` for overall software-architecture boundaries and let the Lead coordinate cross-boundary findings.

Read and apply the [code comment contract](../team-core/references/code-comments.md) in full. Compare required layered comments and per-test explanations with behavior/assertions; report missing obligations as contract gaps, not stylistic preferences.

Read and apply the [code readability contract](../team-core/references/code-readability.md) in full when reviewing layout; follow project conventions and report concrete issues, not taste. Formatting alone does not authorize behavior changes.

When returning a confirmed finding for implementation, link it to the owning issue and its existing repair history under the [repair and diagnosis loop guard](../team-core/references/repair-loop-guard.md). A review finding does not create a fresh retry budget.

When a Blueprint governs the project, read the [Project Blueprint contract](../team-core/references/project-blueprint.md) in full. Compare the diff to declared modules/file responsibilities and explicit refactor approval; respect declined/deferred decisions. Structural review is semantic, not document-validation alone.

Read [execution templates](../team-core/references/execution-templates.md) and [TDD protocol](../team-core/references/tdd-protocol.md) in full when creating review coverage and assessing test traceability. Read the [handoff format](../team-core/references/handoff-format.md) in full before final handoff; read [feedback recording](../team-core/references/feedback-recording.md) in full only after that handoff is prepared.

1. Record the exact review scope, baseline, and stated intent. Inspect the actual diff and enough surrounding code to understand behavior.
2. Build a Review coverage record. Choose independent read-only roles only where they add distinct coverage: `team-reviewer` for correctness and maintainability, `team-tester` for verification gaps, `team-database-specialist` for material data changes, and `team-explorer` for unfamiliar areas.
3. Give each reviewer a bounded question, requested evidence, and file scope. Follow [adaptive child-thread concurrency](../team-core/references/role-routing.md#adaptive-child-thread-concurrency); review tasks may use fewer roles when that gives sufficient independent coverage.
4. Audit behavior-to-test traceability where a stage packet exists: test-first rows need Red/Green/refactor evidence; non-test-first rows need a concrete reason and alternative evidence. Treat unsupported exceptions and material regression gaps as verification findings.
5. De-duplicate findings. A finding needs impact, evidence, a precise file reference, and a concrete failure mode or missing verification.

Read the [Test & Acceptance Contract](../team-core/references/test-acceptance-contract.md) and [TDD protocol](../team-core/references/tdd-protocol.md) in full. Compare manual cases—including user additions—to actual E2E conditions, checkpoints/results and applicable other-layer assertions; report unmapped cases, stale passes, lower-layer-only substitutes and unapproved exceptions. For small changes, apply the [small-task rule](../team-core/references/test-acceptance-contract.md#tier-selection-reuse-and-resource-limits): verify a practical reproduction, affected regression and due handoff without demanding a full suite absent risk or a required gate. Also check real API/integration boundaries, representative browser journeys, reused-result provenance, complete artifacts and status distinctions. Plans and summaries alone are not execution or user acceptance. Review recommends updates without editing tests or historical packets.

Review whether relevant fast checks, first-usable-chain smoke, and costly acceptance checkpoints were scheduled at the right readiness points; deferred work has an owner and concrete flush trigger; known failures block dependent progress; and no stage was accepted or passed beyond a due checkpoint without evidence or explicit user exception. Do not treat an iteration handoff with pending stage evidence as stage acceptance.

## Decision and return gates

- No diff, baseline, or usable change scope → stop and request it rather than inventing review coverage.
- A reviewer reports a concern without evidence or a plausible failure mode → treat it as a question, not a finding.
- A material data, security, or contract risk is uncovered outside the assigned scope → report it as an uncovered risk and recommend the smallest expanded review.

## Output contract

Return findings ranked by impact, then the coverage record: scope inspected, checks performed, TDD evidence audited, and uncovered risks. If there are no material findings, say so and state what was reviewed; do not manufacture stylistic findings.

After preparing the review handoff, create the local minimal feedback record described in [feedback recording](../team-core/references/feedback-recording.md). Keep it to coverage, evidence, and risks; do not copy the reviewed diff or raw findings into the feedback store. A recording failure leaves the review result unchanged.
