---
name: team-task-docs
description: Prepare a Development Plan, System Design, and Test Plan for user review before development, then reconcile useful decisions into existing project docs. Use through Team when the user requests or accepts task documents, and at handoff for an adopted document set.
---

# Task planning documents

The Lead owns the document set, alignment, user review, and closeout. Follow the shared [execution contract](../team-core/references/execution-contract.md) and use the existing [Team plan](../team-plan/SKILL.md) and [Team development](../team-dev/SKILL.md) workflows. Bring in specialists only for decisions or evidence that need them.

## When to activate

### Select the document path

- An explicit request to write the documents authorizes drafting. Resolve critical premises before calling the package ready. Honor an explicit request to skip these optional files and continue authorized work under the normal risk and acceptance rules.
- If the user has not chosen, offer the set once when a material architecture, migration, workflow, or acceptance decision would benefit from review. Name the decision at stake. For a bounded change with a known approach, continue directly with a short task/check note.
- Reuse an accepted plan and compatible project conventions. Changes to required blueprint, specification, stage verification, TDD, or review obligations still follow their existing contracts. Revisit the decision only when a material new boundary or uncertainty warrants it.

## Draft and review

1. Identify one outcome and relevant current PRD/spec, Blueprint, code, tests, and decisions. Separate observed facts, proposals, and unknowns. Validate critical technical premises, including applicable native platform capabilities, under the [design evidence check](../team-core/references/design-exploration.md#critical-premises-and-technical-evidence). Show the user a short direction summary when the approach needs a choice.
2. Resolve artifact ownership and placement before creating files. Reuse native task, design and spec artifacts in an [opted-in OpenSpec project](../team-core/references/spec-lifecycle.md). Keep a single authority for ordering and progress, technical decisions, and acceptance results. If the user requests distinct review files, use concise links/views for content already owned by a native artifact.
3. Apply the [Development Plan](assets/development-plan.md) and [System Design](assets/system-design.md) templates in the selected locations. Without native or project conventions, use `docs/changes/<outcome-id>/development-plan.md` and `docs/changes/<outcome-id>/system-design.md` for an authorized reviewable set. Apply the [Test Plan and Acceptance](assets/test-plan.md) guidance in the canonical stage packet or QA artifact and link it from the Plan. When an opted-in light task has neither an applicable packet nor a project QA artifact, use `test-plan.md` alongside the plan as its sole test and acceptance record. For multiple stages, link the stage-specific packets and use their existing case identities. Follow the project's local/private and Git retention policy.
4. Backcheck the chain from approved behavior and actual baseline to design decisions, work packages, and observable test cases. Check ownership, failure paths, material unknowns, and the planned Agent preflight for each manual case. Share the three paths and the decisions needing review. Acknowledgment of receipt is different from approval to start. When the user reviews and authorizes development, use that decision directly.
5. Keep the approved scope and document revisions in the existing Work record. Correct factual drift in place. Return material changes to product behavior, module or interface boundaries, rollout, or acceptance criteria for scoped review before dependent work continues. Recheck only affected tasks, cases, and evidence.

## Reconcile at implementation handoff

Use the approved set, actual implementation diff, current authoritative docs, and observed verification. On the light path, apply the same scoped reconciliation when the change affects durable docs, using the existing short handoff. Treat the code diff as observed behavior and confirmed requirements as intent. Surface disagreements that need a decision.

- Find the owner of each durable claim under [documentation governance](../team-core/references/documentation-governance.md#document-responsibility-and-placement). Within authorized scope, update existing paragraphs in place for additions, replacements and removals. Put confirmed user behavior into its authoritative PRD or spec, structural and interface changes in their current Blueprint/technical sources, UI rules in UI guidance, and reusable commands or verification procedures into the test guide. Link material decisions to their existing decision record. Use the project roadmap/backlog for approved future work.
- For adopted OpenSpec, keep behavior changes in the native delta until the existing [spec verification and closure](../team-core/references/spec-lifecycle.md#verify-and-close) checks permit their promotion. Keep the change active with manual acceptance pending. Apply the supported native operation with existing authority so this handoff cannot preemptively rewrite the canonical spec or invalidate the active change's baseline.
- If Git is available, compare the scoped baseline with the actual change and inspect any concurrent human edits to affected docs. Preserve independent edits and valid context. Where intent is ambiguous or conflicts, record the precise claim, source, and affected work and ask the user before changing that claim. Follow [Agent document reconciliation](../team-core/references/agent-documentation.md#reconciliation-procedure) for adopted source maps. Advance mapped evidence only after the content is reconciled.
- Keep implementation steps, discarded approaches, logs, screenshots, per-run results, and user acceptance in their task/PR/verification evidence. Use handoff records for remaining work with a next owner or checkpoint. When no durable claim changed, a concise no-change result in the existing handoff is sufficient.
- Report which pages changed and why, what evidence was used, and what is still pending. Mark verified implementation and pending human acceptance separately. Retain/revise/archive the task documents through the project's policy and existing [acceptance and spec closure](../team-core/references/test-acceptance-contract.md#verification-and-closure). Canceled or superseded work remains identifiable as such. Preserve links and evidence when retiring an obsolete passage or document.

## Output contract

At review, return the three artifact paths or authoritative equivalents, the decisions that need review, and any conditional or blocked scope. At implementation handoff, report Agent preflight and human acceptance separately, link the updated durable docs, and identify unresolved claims or next work in the existing handoff.

See [research and design choices](references/sources.md) when maintaining the templates.
