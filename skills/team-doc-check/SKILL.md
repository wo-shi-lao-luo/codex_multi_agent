---
name: team-doc-check
description: Assess and maintain task-scoped development documentation, adopt existing projects, classify new documents and recheck stale evidence before implementation.
---

# Team documentation check

When invoked by the user in the main thread, act as the Lead under the shared [execution contract](../team-core/references/execution-contract.md). A delegated docs maintainer instead follows its assigned documentation scope: inspect and maintain authorized docs, prepare assessment input/recommendations and request specialist evidence through the Lead. Do not take over coordination, spawn agents or authorize the overall start. Read [documentation governance](../team-core/references/documentation-governance.md) for authority, locations, ambiguity, legacy handling, runtime and review schema.

## When to activate

Use for development-readiness checks, existing-project document adoption, new/changed-document classification or factual documentation maintenance. Team planning/development applies the same contract automatically. Do not turn an ordinary explanation into project adoption or a background monitor.

For project readiness and documentation tasks, assess applicable target-project instruction coverage at task start and when relevant work enters another module or its rule/command evidence changes. Apply [project rules](../team-core/references/project-rules.md) even if the user did not ask about project instruction files: only evidence of a material task-relevant gap prompts the Lead to present its path, evidence, impact, concise suggested delta, and approval question. Absence, length, or age alone is not a finding. The delegated Docs Maintainer reports proposals to the Lead and never prompts the user or writes target instructions (`AGENTS.md`, `AGENTS.override.md`, or configured equivalents) without approval for the bounded path/rules. Do not repeat an unchanged prior proposal with a reachable user decision unless relevant evidence or scope materially changes. Do not claim that a file is effective in the live Codex session unless loading was observed.

## Assess and maintain

When acting as Lead, apply [role routing](../team-core/references/role-routing.md): check needed named roles in the active tool catalog, explicitly select them, and ask before any unavailable-role alternative. Reconcile actual calls and show the [handoff format](../team-core/references/handoff-format.md)'s final actual roster, including failures/retries or explicit none. Source profiles and task labels are not runtime identity. A delegated maintainer only reports its own available identity evidence; it does not spawn agents or prepare the overall roster.

Establish the current task and relevant instructions; discover existing docs and previous assessments. Delegate substantial document work to `team-docs-maintainer`, focused code evidence to Explorer, architectural judgments to Architect and acceptance sufficiency to Tester through the Lead. Small tasks may stay with the Lead. Do not add agents just because roles exist.

Use Scan before initializing absent governance; classify actual sources, including unread/inaccessible ones. Apply task-specific information requirements, preserve active PRD constraints and distinguish implemented behavior from confirmed intent. Never require every document category or claim whole-project readiness from a scoped sample. Assign edited documents their content purpose/source-of-truth responsibility; follow documentation governance's placement rules (including the README entrypoint boundary where applicable). During authorized content edits, correct relevant, evidence-backed documentation defects within assigned ownership and recheck links/indexes; send cross-owner findings to the Lead for a bounded assignment. Read-only checks report defects without editing, and ambiguous authority or intent still goes to the user.

Before resolving a substantive ambiguity, ask the user with evidence, options and a recommendation. Preserve disputed documents and pause only dependent work. Update unambiguous assigned indexes/links and factual records within task authority. Confirm legacy suitability and references before moving anything; uncertain material stays in place. Follow the [Project Blueprint contract](../team-core/references/project-blueprint.md) for structural questions and refactor approval.

The Lead uses RecordReview only after inspecting actual assessment evidence, then Validate against the current task and scope. A delegated maintainer may run read-only discovery/validation and publish an explicitly assigned Lead-approved record, but does not self-approve it. Refreshing a marker or hashes is not a semantic review. Recheck new/changed docs and selected code dependencies before implementation; use partial outcomes only for explicitly independent work. In an opted-in OpenSpec project, read [spec lifecycle](../team-core/references/spec-lifecycle.md) and reconcile authority conflicts rather than replacing its artifacts.

## Output contract

Return scope, indexed/read/unread sources, applicable PRDs and decisions, sufficiency findings with evidence and affected work, ready/partial/blocked recommendation, questions and permitted independent work, changed documentation and current review path. Lead owns final start authorization. No production implementation, automatic archival, deletion, model fallback, push or installation is implied.
