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

Read [role routing](../team-core/references/role-routing.md), [file ownership](../team-core/references/file-ownership.md), [handoff format](../team-core/references/handoff-format.md), [execution templates](../team-core/references/execution-templates.md), [test and acceptance contract](../team-core/references/test-acceptance-contract.md), and [feedback recording](../team-core/references/feedback-recording.md).

1. Create a Task record. Identify outcome, constraints, acceptance checks, and unknowns.
2. Discover only the facts needed to choose an approach. Use `team-explorer` for uncertain scope and `team-architect` for cross-module contracts.
3. Create a Work contract before assigning writers. Declare ownership for shared APIs, schemas, migrations, generated clients, and lockfiles. Keep production-code ownership to one writer by default.
4. Before implementation, create the target repository's Git-tracked stage verification packet required by the Test & Acceptance Contract. `team-tester` owns its coverage matrix and human verification script.
5. Delegate bounded work with expected output, relevant constraints, and verification. Run at most three child threads; child agents do not orchestrate further agents.

## Execute and integrate

Wait for required discovery or contract decisions before dependent work begins. Communicate only at integration points: a shared contract is agreed, a dependency is ready, a handoff identifies a blocker, or verification changes the plan.

After a coherent implementation pass, assign `team-tester` and `team-reviewer` independently when the change is material. Include `team-database-specialist` for material data work. The Lead de-duplicates findings, assigns focused fixes, and keeps the original owner responsible for the changed boundary.

## Verify and close

Create a Verification record from actual checks. Record commands and outcomes, inspected behavior, and checks that could not run. Do not close the task until acceptance checks have evidence or the user-facing remaining risk is explicit.

Reconcile every stage-packet row with actual evidence. Human checks remain `manual pending` until user evidence exists. Archive the packet only after manual verification or explicit user deferral; otherwise link the active packet in the Handoff.

After the normal Handoff is prepared, create the local minimal feedback record described in [feedback recording](../team-core/references/feedback-recording.md). Include only redacted workflow evidence. A recording failure is a non-blocking remaining risk, never a reason to alter the task outcome.

## Return paths

- New scope, contract, or ownership concern → update the Work contract before continuing.
- Failed verification or valid review finding → assign a focused return to Execute, then rerun the affected verification.
- Missing environment, credentials, or user decision → hand off the blocker with the smallest useful next step.

## Output contract

Report changed files, acceptance checks, verification evidence, valid review findings addressed, and remaining risks. Only the Lead claims task completion.
