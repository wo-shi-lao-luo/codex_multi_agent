---
name: team-doc-check
description: Assess and maintain task-scoped development documentation, adopt existing projects, classify new documents and recheck stale evidence before implementation.
---

# Team documentation check

When invoked by the user in the main thread, act as Lead under the shared [execution contract](../team-core/references/execution-contract.md). A delegated Docs Maintainer follows only assigned documentation scope, prepares assessment/recommendations and requests specialist evidence through the Lead; it does not coordinate, spawn agents or authorize start. Read the [documentation governance](../team-core/references/documentation-governance.md) and [project-rules](../team-core/references/project-rules.md) authorities in full; they own documentation authority, classification, instruction coverage, ambiguity and review requirements.


## When to activate

Use for development-readiness checks, existing-project document adoption, new/changed-document classification or factual documentation maintenance. Team planning/development applies the same contract automatically. Do not turn an ordinary explanation into project adoption or a background monitor.

For readiness and documentation tasks, assess applicable target-project instruction coverage at the task/module checkpoints in the project-rules contract. The Lead surfaces only material task-relevant gaps with evidence and an approval question. Absence, length or age alone is not a finding. A delegated Docs Maintainer reports proposals through the Lead and never prompts the user or writes target instruction files without approval for the bounded path/rules. Do not repeat unchanged prior proposals or claim live loading unless observed.

## Assess and maintain

When acting as Lead, read [role routing](../team-core/references/role-routing.md) and [handoff format](../team-core/references/handoff-format.md) in full. Select exact available roles, preserve identity limits, and reconcile the actual roster including failures/retries or explicit none. A delegated maintainer only reports its own available identity evidence; it does not spawn agents or prepare the overall roster.

Establish the task and applicable decisions, then inspect the relevant document sources and prior assessment evidence. Use `team-docs-maintainer` for substantial document work, Explorer for bounded code facts, and obtain architecture/acceptance judgment through the Lead when needed. Small tasks may stay with the Lead; do not add roles without a distinct need.

Use Scan before initializing absent governance; classify actual sources, including unread/inaccessible ones. Apply task-specific information needs, preserve active PRD constraints, distinguish implementation from confirmed intent, and never infer whole-project readiness from a scoped sample. For authorized edits, declare purpose/source of truth, follow the governance placement rules, correct evidence-backed defects only within assigned ownership, and recheck affected links/indexes. Read-only checks report defects; cross-owner fixes and ambiguous authority return to the Lead/user.

For cross-document consistency, apply the shared contract's [claim classification and authority rules](../team-core/references/documentation-governance.md#cross-document-consistency): distinguish redundant detail, complementary scope, genuine conflicts and legitimate repetition before proposing a correction. Reuse the existing `conflict` or `ambiguous` finding kind; similarity or inventory evidence alone does not justify consolidation. Keep the check scoped to relevant documents and report any changed passages, retained authority, unique context preserved, and links/indexes rechecked.

When reviewing small-change test guidance, use the [standalone small-task rule](../team-core/references/test-acceptance-contract.md#tier-selection-reuse-and-resource-limits), including its risk/gate override.

Read-only `Scan`, `Status`, and `Validate` do not change ignore policy. Before an explicitly authorized operation generates local governance files or temporary output, follow the [generated-artifact Git protection contract](../team-core/references/generated-artifacts.md) and protect the applicable scope first. The Documentation profile keeps the governance metadata, index and full reviews subtree on disk locally, outside Git; it does not ignore all of `governance/`. User-authored governance documents and formal project evidence remain versionable. A fresh checkout cannot inherit another checkout's adoption/readiness record: scan its available documents and establish local governance state/review as applicable.

Before resolving a substantive ambiguity, ask the user with evidence, options and a recommendation. Preserve disputed documents and pause only dependent work. Update unambiguous assigned indexes/links and factual records within task authority. Confirm legacy suitability and references before moving anything; uncertain material stays in place. Follow the [Project Blueprint contract](../team-core/references/project-blueprint.md) for structural questions and refactor approval.

The Lead uses RecordReview only after inspecting actual assessment evidence, then Validate against the current task and scope. A delegated maintainer may run read-only discovery/validation and publish an explicitly assigned Lead-approved record, but does not self-approve it. Refreshing a marker or hashes is not a semantic review. Recheck new/changed docs and selected code dependencies before implementation; use partial outcomes only for explicitly independent work. In an opted-in OpenSpec project, read [spec lifecycle](../team-core/references/spec-lifecycle.md) and reconcile authority conflicts rather than replacing its artifacts.

## Output contract

Return scope, indexed/read/unread sources, applicable PRDs and decisions, sufficiency findings with evidence and affected work, ready/partial/blocked recommendation, questions and permitted independent work, a changed-document ledger for corrections, and the current review path. Lead owns final start authorization. No production implementation, automatic archival, deletion, model fallback, push or installation is implied.
