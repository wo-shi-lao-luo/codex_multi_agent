---
name: team-project-rules
description: Proactively assess target-project instruction coverage during Codex Team planning and development, and propose evidence-backed, user-approved AGENTS.md updates. Use for repository rules, not product requirements or global Codex settings.
---

# Team project rules

This Skill supports project-level `AGENTS.md` coverage during ordinary Codex Team planning and development, as well as direct requests to review or change instruction files. The target project's instructions describe how agents should work there; they are not the kit's own rules.

Apply the shared [project-rules contract](../team-core/references/project-rules.md) alongside [documentation governance](../team-core/references/documentation-governance.md), the [execution contract](../team-core/references/execution-contract.md), and [role routing](../team-core/references/role-routing.md). The project-rules contract defines discovery, authority, approval, scope, and upkeep. Use `team-explorer` through the Lead for bounded repository facts and `team-docs-maintainer` for assigned drafting or maintenance. The Lead owns decisions and readiness; do not create a new agent role or grant authority by editing the file.

When invoked directly as the workflow Lead, follow the shared execution and role contracts and use the [handoff format](../team-core/references/handoff-format.md), including its actual child-agent roster. A delegated Docs Maintainer follows only the assigned documentation scope, returns findings to the Lead, and does not coordinate the task, spawn agents, or authorize readiness.

## When to activate

Use for direct requests to assess or change target-project instructions. `$team-plan` and `$team-dev` also assess applicable instruction coverage at task start, when work first enters another relevant module, and when relevant rule, command, or convention evidence changes. This is a checkpoint in those workflows, not a background watcher or global hook. A relevant, evidence-backed coverage gap should be brought to the user even when the original task did not mention `AGENTS.md`; a missing, short, or old file alone is not a gap. For a standalone document-readiness request, use `$team-doc-check` and apply this contract when project instructions are in scope.

Do not use this Skill to edit the toolkit's own distributed rules, product requirements, or global Codex settings. Route those requests to their appropriate workflow.

## Workflow

1. Establish the target repository, current task, applicable project rules, and existing governance scope. Use the read-only [candidate-discovery helper](../team-core/scripts/project-rules.ps1) to find root-to-working-directory candidates, including absent and shadowed paths. Then read the actual applicable files and relevant linked sources. The helper returns candidate metadata but not instruction text, and does not interpret policy.
2. Have Explorer provide only the bounded repository facts needed for the task. Separate verified facts, confirmed policy, and proposals or unknowns. Do not treat a current code defect as intended policy or invent commands.
3. Keep the review in the existing task or `docs/governance` record. Identify proposed edits, affected work, material conflicts, user decisions, and the evidence that must be rechecked. A missing instruction file alone does not block unrelated authorized implementation; if the user declines or defers it, preserve current constraints and proceed with independent work.
4. Preserve existing user-authored content. Any write to a target project instruction file (`AGENTS.md`, `AGENTS.override.md`, or an explicitly configured equivalent) requires the user's approval for the bounded path and rules being changed, including factual and link-only edits. An explicit request to create or edit a specified file/rule is approval for that scope; ordinary code-development authorization or a request to assess/recommend is not. If evidence reveals an in-scope gap without prior rules-edit approval, the Lead presents the exact path, evidence, affected work, suggested delta, and approval question. Ask the user when the actual policy, conflict winner, or scope remains materially ambiguous, and pause only dependent work.
5. Check any reachable prior proposal and user decision before raising it again. Do not repeat an unchanged approved, declined, or deferred proposal unless relevant evidence or task scope has materially changed. Record the proposal, evidence, and decision in the existing Work, governance, or project decision record where available; do not create a separate tracker. If no durable record exists, rely only on the current task/conversation and make no cross-session suppression promise. A retained refusal or deferral is not permission to make the change later.
6. Recheck actual file contents, candidate paths and relevant links after an approved edit. Report factual findings separately from policy proposals. Do not claim live Codex loading or reloading unless the active environment confirms it.

## Output contract

Return the target and inspected scope; instruction candidates read, unread, absent or shadowed; applicable authority and approval evidence; verified facts versus proposals; affected work, findings and decisions needed; proposal status and exact pending approval scope/question; changed files and rechecks; runtime-loading status; risks and next step. The Lead owns the readiness decision and final handoff. Do not claim project-wide coverage from a scoped review.
