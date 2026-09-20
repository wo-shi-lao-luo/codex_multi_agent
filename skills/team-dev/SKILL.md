---
name: team-dev
description: Run a bounded, evidence-backed Codex development workflow for a feature, bug fix, refactor, or integration. Use explicitly as $team-dev when the user wants coordinated implementation work.
---

# Team development

Act as the Lead. This workflow owns the full shared [execution contract](../team-core/references/execution-contract.md): **Context → Discover → Contract → Execute → Verify → Handoff**.

## When to activate

Use when the user wants a coordinated implementation, not merely advice, a plan, or a review. Choose the smallest team that materially improves speed or quality; a small clear change may be handled by the Lead with an independent review only when useful.

Do not use this workflow to create a task daemon, push branches, merge pull requests, or alter external systems unless the user explicitly asks.

## Establish the work

Read the [Project Blueprint contract](../team-core/references/project-blueprint.md) before assigning stages. Assess its gate; for existing projects, inspect the baseline first. Record adequate structure as-is; propose evidenced structural repairs separately and obtain explicit user approval before refactoring. If declined or deferred, document retained constraints and continue within the actual structure. When the gate applies, the Lead creates/updates the blueprint from the architect's read-only proposal and includes its path/revision, modules, file scope, root exceptions and amendment decision in every stage packet. Use `-BlueprintPath` for canonical packet validation. Review actual file placement at close; return unplanned boundary changes to Contract.

Read [role routing](../team-core/references/role-routing.md), [file ownership](../team-core/references/file-ownership.md), [handoff format](../team-core/references/handoff-format.md), [execution templates](../team-core/references/execution-templates.md), [test and acceptance contract](../team-core/references/test-acceptance-contract.md), [TDD protocol](../team-core/references/tdd-protocol.md), and [feedback recording](../team-core/references/feedback-recording.md).

1. Create a Task record. Identify outcome, constraints, acceptance checks, and unknowns.
2. Discover only the facts needed to choose an approach. Use `team-explorer` for uncertain scope and `team-architect` for cross-module contracts.
3. Create a Work contract before assigning writers. Declare ownership for shared APIs, schemas, migrations, generated clients, and lockfiles. Keep production-code ownership to one writer by default.
4. Before implementation, discover the available test entrypoints and create the target repository's Git-tracked stage verification packet required by the Test & Acceptance Contract. `team-tester` owns its coverage matrix, TDD-track decisions, Red/Green evidence design, and human verification script.
5. Fill and validate the packet before writers begin. Every material behavior is `test-first`, `test-after`, or `manual-or-environmental`; unexplained exceptions block an unqualified start.
6. Delegate bounded work with expected output, relevant constraints, and verification. Run at most three child threads; child agents do not orchestrate further agents.

## Execute and integrate

Wait for required discovery or contract decisions before dependent work begins. Communicate only at integration points: a shared contract is agreed, a dependency is ready, a handoff identifies a blocker, or verification changes the plan.

After a coherent implementation pass, assign `team-tester` and `team-reviewer` independently when the change is material. Include `team-database-specialist` for material data work. The Lead de-duplicates findings, assigns focused fixes, and keeps the original owner responsible for the changed boundary.

## Verify and close

Apply the [code comment contract](../team-core/references/code-comments.md). Require writers to meet layered documentation minimums and explain every in-scope test's scenario and expected result, even simple tests. Record a per-unit self-check against behavior and assertions, including exemptions and gaps, even without an independent reviewer. Include this coverage when assigning review; missing mandatory explanations must be resolved or explicitly disclosed before completion.

Create a Verification record from actual checks. Record commands and outcomes, inspected behavior, and checks that could not run. Do not close the task until acceptance checks have evidence or the user-facing remaining risk is explicit.

Reconcile every stage-packet row with actual evidence, including Red/Green/refactor evidence or documented alternatives. Run the packet validator before Handoff. Human checks remain `manual pending` until user evidence exists. Archive the packet only after manual verification or explicit user deferral; otherwise link the active packet in the Handoff.

After the normal Handoff is prepared, create the local minimal feedback record described in [feedback recording](../team-core/references/feedback-recording.md). Include only redacted workflow evidence. A recording failure is a non-blocking remaining risk, never a reason to alter the task outcome.

## Return paths

- New scope, contract, or ownership concern → update the Work contract before continuing.
- Failed verification or valid review finding → assign a focused return to Execute, then rerun the affected verification.
- Missing environment, credentials, or user decision → hand off the blocker with the smallest useful next step.

## Output contract

Report changed files, acceptance checks, verification evidence, valid review findings addressed, and remaining risks. Only the Lead claims task completion.
