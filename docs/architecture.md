# Architecture

The system has three layers:

1. **Codex native executor** — creates, observes, and joins subagent threads.
2. **Custom agents** — define bounded roles, model choices, and write permissions.
3. **Skills** — provide explicit team workflows and routing rules. The internal `team-core` Skill ships shared execution, routing, ownership, and handoff references with the workflow Skills.

The main Codex thread is the Lead. It reads project instructions, decides whether parallel work materially helps, gives each child a bounded task, and consolidates outcomes. The Lead is not a separate custom agent. Team workflows use the shared execution contract: Context, Discover, Contract, Execute, Verify, and Handoff.

## Default execution

`$team-dev` starts with a brief task/risk declaration and scope analysis. Code-changing work, including small bounded tasks, defaults to one named domain implementer plus `team-tester`; the Tester plans the concise packet coverage before implementation and verifies afterward, with test-file ownership separate from production files. Every material implementation also receives independent `team-reviewer` review, with relevant specialists added when risk or boundaries warrant them. Medium and large tasks normally add `team-explorer` plus `team-architect` or a targeted specialist when discovery or cross-module design requires it. Small tasks keep the same applicable documentation, stage-packet, TDD, coverage, comments, domain and verification obligations in a shorter record. Pure consultation and read-only investigation do not inherit the implementation-agent minimum; debug repairs enter the implementation path. Only an explicit request for the Lead personally to implement, or approval of a specific Lead-only exception, changes the default ownership. Such an exception does not waive stage evidence or material-change independent review; unresolved conflicts are returned for direction. At close, the Lead reconciles intended roles/checks with actual invocation and verification evidence.

## UI work

For new pages and visible UI changes, the Lead passes a lightweight UI brief and names one owner for the coherent page or user flow. The owner uses frontend-design for hierarchy, styling and rendered refinement alongside frontend-engineering for implementation correctness. Small demos normally stay with one implementer; independent work may still be delegated. File boundaries must include necessary shared styles or be adjusted explicitly.

Functional tests and rendered visual inspection are separate evidence. The Lead checks the final integrated page's evidence, and missing browser access remains an explicit unverified state. Agent inspection never replaces user manual acceptance. See the [UI delivery contract](../skills/team-core/references/ui-quality.md). This workflow does not claim measured visual improvement until a matched-task comparison is actually run.

## Data work

`team-database-specialist` owns SQL safety, schema design, migrations, indexing, query plans, transaction boundaries, and data-change rollback. It is invoked only when data-layer changes are material.

## Optional specification boundary

OpenSpec integration adds an optional external CLI boundary, not a fourth executor or a second Lead. The existing workflow stays unchanged without a project opt-in marker. See the [spec lifecycle](../skills/team-core/references/spec-lifecycle.md) and [integration contract](../skills/team-core/references/openspec-integration.md).

| Module | Owner files and responsibility | Dependencies |
| --- | --- | --- |
| Specification adapter | team-core/scripts/openspec-adapter.ps1: versioned CLI transport, explicit adoption, native archive with recovery | Trusted external CLI, traceability, common helpers |
| Traceability | team-core/scripts/spec-traceability.ps1: stable links, stale-input detection and close gates | Existing stage validation, common helpers |
| Shared spec IO | team-core/scripts/openspec-common.ps1: contained paths and fingerprints; no orchestration | Local filesystem |
| Stage verification | Existing stage-verification.ps1: packet authority; optional read-only archived-packet validation | Existing blueprint validation; safe path helper for explicit PacketPath |

Production files remain grouped by these responsibilities rather than implementation stage. No existing-code structural refactor was required or performed. Specs and task wording are fingerprinted; stage packets own results. The adapter cannot establish semantic correctness or authenticate approvals. Its archive lock coordinates kit archives only; external writers must be stopped.

## Documentation governance boundary

Task-scoped documentation review runs before planning/implementation and is refreshed when relevant evidence changes. The Lead owns readiness decisions; team-docs-maintainer (Luna/high) inventories and maintains assigned docs; Explorer supplies code facts, Architect judges architectural questions and Tester checks acceptance sufficiency. Existing adequate docs remain authoritative in their original locations. This kit has no OpenSpec opt-in marker in its own repository, so its native workflow is retained.

| Module | Responsibility and owned files | Dependencies |
| --- | --- | --- |
| Documentation runtime (DOC-RUNTIME) | team-core/scripts/documentation.ps1: contained discovery, adoption, review validation, fingerprints and current-record pointers | PowerShell 7 and local repository files only |
| Shared contract (DOC-CONTRACT) | team-core/references/documentation-governance.md: PRD authority, ambiguity, optional information requirements and legacy decisions | Existing Blueprint, OpenSpec and stage acceptance contracts |
| Routing (DOC-ROUTING) | team-doc-check Skill, docs maintainer agent and existing team workflow routes | Shared contract; one Lead, bounded doc ownership |
| Project instructions (DOC-RULES) | team-project-rules Skill, team-core/references/project-rules.md and team-core/scripts/project-rules.ps1: proactive material-gap proposals at task/module checkpoints and bounded approved maintenance of AGENTS.md, overrides and configured equivalents | Explorer repository facts; existing Work/docs-governance evidence; user approval for every target instruction-file write |
| Verification (DOC-TEST) | tests/test-documentation.ps1 and canonical stage packet | Disposable project copies and existing package/installer suites |

The documentation runtime keeps its adoption metadata and reviews under docs/governance locally; PRDs live in docs/PRD and confirmed historical docs in docs/legacy. The runtime never resolves semantic conflicts, moves original documents or rewrites source. Policy version is separate from Kit version; a local adoption record is not a readiness decision. Reviews bind task wording, document inventory/classification and declared code dependencies. Hashes do not establish approval authenticity or semantic sufficiency. Existing project layout is preserved; no code refactor is part of this capability.

## Generated-artifact Git protection boundary

`skills/team-core/scripts/generated-artifacts.ps1` owns narrow local-artifact protection and read-only Git-index checks for the `Documentation`, `OpenSpec`, and exact-path `Work` profiles. Writers protect an applicable scope before generating local files; `$team-dev` repeats protection before an authorized commit or handoff and checks the actual index. The Documentation profile keeps the governance metadata, index and complete reviews subtree on disk locally but outside Git; it does not ignore all of `governance/`. User-authored governance documents, PRDs, Blueprint, verification packets and native specs remain versionable. A fresh checkout must assess its available documents and establish local adoption/review state as applicable. The helper does not stage, commit, or automatically untrack files. See the [generated-artifact protection contract](../skills/team-core/references/generated-artifacts.md) for its JSON result, conflict behavior and limits.

## Installation management boundary

The deployment manager is independent of the Kit's agent/Skill payload. `scripts/deploy-user.ps1` owns manifests, receipt migration, exact unit reconciliation, staging, before-images, recovery journals, stable selection and pruning. The existing install/update entrypoints route to it. Its content-addressed installed copy survives source checkout changes and payload downgrade. No Skill or agent can silently opt a project into rollback.

This approved installer refactor preserves global config and unrelated personal components; it changes the old per-unit restore into whole-operation recovery. No business source layout is reorganized. Snapshot/data compatibility and recovery limits are documented in [safe deployment](safe-deployment.md).

## Deliberate limits

The toolkit has no background task scheduler, no issue-tracker integration, no automatic Git push or merge, no global hook, and no recursive child orchestration. These limits keep the user-level workflow inspectable and portable across projects.
