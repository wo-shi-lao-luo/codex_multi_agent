---
name: team-project-rules
description: Proactively assess target-project instruction coverage during Codex Team planning and development, and propose evidence-backed, user-approved AGENTS.md updates. Use for repository rules, not product requirements or global Codex settings.
---

# Team project rules

This Skill supports project-level `AGENTS.md` coverage during ordinary Codex Team planning and development, as well as direct requests to review or change instruction files. The target project's instructions describe how agents should work there; they are not the kit's own rules.


Read the shared [project-rules contract](../team-core/references/project-rules.md) in full; it owns discovery, authority, approval, scope and upkeep. For an instruction-file change, also read [documentation governance](../team-core/references/documentation-governance.md) in full. When invoked directly as a Lead, read the [execution contract](../team-core/references/execution-contract.md) and [role routing](../team-core/references/role-routing.md) in full before coordinating/delegating, and the [handoff format](../team-core/references/handoff-format.md) before final roster reporting. Use Explorer through the Lead for bounded facts and Docs Maintainer for assigned drafting; the Lead owns decisions/readiness. Editing an instruction file never grants authority.

When invoked directly as the workflow Lead, follow the shared execution and role contracts and use the [handoff format](../team-core/references/handoff-format.md), including its actual child-agent roster. A delegated Docs Maintainer follows only the assigned documentation scope, returns findings to the Lead, and does not coordinate the task, spawn agents, or authorize readiness.

## When to activate

Use for direct requests to assess or change target-project instructions. `$team-plan` and `$team-dev` run the task/module checkpoints in the shared contract; this is not a watcher or global hook. Surface only relevant, evidence-backed gaps even if the task did not mention `AGENTS.md`; a missing, short or old file alone is not a gap. For standalone document readiness, use `$team-doc-check` and apply this contract when instructions are in scope.

Do not use this Skill to edit the toolkit's own distributed rules, product requirements, or global Codex settings. Route those requests to their appropriate workflow.

## Workflow

1. Establish the target repository/task and read applicable rules. Use the read-only [candidate-discovery helper](../team-core/scripts/project-rules.ps1) for root-to-working-directory candidates, including absent and shadowed paths; it returns metadata only, not instruction text or policy. Read actual applicable files and relevant linked sources in full.
2. Have Explorer provide only the bounded repository facts needed for the task. Separate verified facts, confirmed policy, and proposals or unknowns. Do not treat a current code defect as intended policy or invent commands.
3. Keep findings in the existing task or `docs/governance` record. State affected work, material conflicts, needed decisions and recheck evidence. A missing instruction alone does not block unrelated authorized implementation; if declined/deferred, preserve current constraints and proceed only with independent work.
4. Preserve existing user-authored content. Any write to a target project instruction file (`AGENTS.md`, `AGENTS.override.md`, or an explicitly configured equivalent) requires the user's approval for the bounded path and rules being changed, including factual and link-only edits. An explicit request to create or edit a specified file/rule is approval for that scope; ordinary code-development authorization or a request to assess/recommend is not. If evidence reveals an in-scope gap without prior rules-edit approval, the Lead presents the exact path, evidence, affected work, suggested delta, and approval question. Ask the user when the actual policy, conflict winner, or scope remains materially ambiguous, and pause only dependent work.
5. Reuse reachable prior proposals and decisions; do not repeat an unchanged one unless relevant evidence or scope materially changed. Record them in existing evidence, not a new tracker. Without durable history, make no cross-session suppression promise. A refusal/deferral is not later permission.
6. Recheck actual file contents, candidate paths and relevant links after an approved edit. Report factual findings separately from policy proposals. Do not claim live Codex loading or reloading unless the active environment confirms it.

When a proposed rule concerns small-change tests, use the [Test & Acceptance Contract's small-task rule](../team-core/references/test-acceptance-contract.md#tier-selection-reuse-and-resource-limits), including risk/gate overrides.

## Output contract

Return the target and inspected scope; instruction candidates read, unread, absent or shadowed; applicable authority and approval evidence; verified facts versus proposals; affected work, findings and decisions needed; proposal status and exact pending approval scope/question; changed files and rechecks; runtime-loading status; risks and next step. The Lead owns the readiness decision and final handoff. Do not claim project-wide coverage from a scoped review.
