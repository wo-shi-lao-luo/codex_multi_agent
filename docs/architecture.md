# Architecture

The system has three layers:

1. **Codex native executor** — creates, observes, and joins subagent threads.
2. **Custom agents** — define bounded roles, model choices, and write permissions.
3. **Skills** — provide the recommended `$team` composition entry, task-matched to requests for engineering work or available by explicit invocation, alongside direct workflow entries. The internal `team-core` Skill ships shared execution, routing, ownership, and handoff references with the workflow Skills.

The main Codex thread is the Lead. It reads project instructions, decides whether parallel work materially helps, gives each child a bounded task, and consolidates outcomes. The Lead is not a separate custom agent. Team workflows use the shared execution contract: Context, Discover, Contract, Execute, Verify, and Handoff.

## Default execution

`$team-dev` starts with a brief task/risk declaration and scope analysis. Code-changing work, including small bounded tasks, defaults to one named domain implementer plus the Tester role selected for the behavior: `team-tester` generally, or `team-ai-tester` when application AI behavior evaluation is the primary test need. The selected Tester plans concise packet coverage before implementation and verifies afterward, with test-file ownership separate from production files; mixed work follows shared routing for one canonical packet owner and distinct software assertions. Every material implementation also receives independent `team-reviewer` review, with relevant specialists added when risk or boundaries warrant them. Medium and large tasks normally add `team-explorer` plus `team-architect` or a targeted specialist when discovery or cross-module design requires it. Small tasks keep the same applicable documentation, stage-packet, TDD, coverage, comments, domain and verification obligations in a shorter record. Pure consultation and read-only investigation do not inherit the implementation-agent minimum; debug repairs enter the implementation path. Only an explicit request for the Lead personally to implement, or approval of a specific Lead-only exception, changes the default ownership. Such an exception does not waive stage evidence or material-change independent review; unresolved conflicts are returned for direction. At close, the Lead reconciles intended roles/checks with actual invocation and verification evidence.

## Unified Team entry

`$team` may be selected automatically for a user request to carry out engineering work or invoked explicitly. This applies to the current task and directly relevant follow-ups only, not as a durable mode for unrelated conversations. Task matching is best effort and host/model-dependent, not proof of active-session loading; explicit `$team` remains available. The Lead selects or composes existing workflow Skills from intent, authorization, evidence, and risk; ordinary factual questions can be answered directly, while explicit workflow choices and opt-out take precedence. Selection does not require a second command or waive the selected workflow's permissions, roles, evidence, budgets, or approval gates. Direct entries remain supported. The Lead does not create a router agent or runtime, and asks only for a materially missing choice or authority. [`workflow-routing.md`](../skills/team-core/references/workflow-routing.md) is the sole composition contract; domain rules stay in their existing Skills and shared references.

| Module | Owner files and responsibility | Dependencies |
| --- | --- | --- |
| Unified Team entry (TEAM-ENTRY) | `skills/team/SKILL.md` provides the task-matched or explicit Lead entry; `skills/team/agents/openai.yaml` permits implicit selection without guaranteeing host matching/loading; `skills/team-core/references/workflow-routing.md` selects existing workflows and links their contracts | Existing workflow Skills, role routing, TDD and repair guards, and feedback schema; no router role, runtime, or new lifecycle |

## Risk-proportional design exploration

`$team-plan` and `$team-dev` choose a light check or fuller design exploration based on material risk and unresolved uncertainty, not task/file size. The Lead owns the context brief and decision; Explorer supplies bounded repository facts, Architects provide read-only proposals when a material question warrants them, and assigned Developers/Testers check only their scopes. The normative source is [`design-exploration.md`](../skills/team-core/references/design-exploration.md), linked through the shared Team contracts. Reuse the active PRD, existing Blueprint/OpenSpec where applicable, Work contract and stage packet; do not add a competing planner, design runtime or mandatory document. AI simulation actors are excluded from this design guidance. Existing acceptance, approval, target-instruction, refactor and repair/debug-budget boundaries remain unchanged.

## Code readability and formatting

Every assigned codewriter and tester follows the shared [code-readability contract](../skills/team-core/references/code-readability.md) alongside the existing code-comment rules. The target project's formatter/configuration takes precedence; shared line lengths are guidance when no project rule applies. For supported formatters, the team-core helper plans, checks and applies formatting to exact assigned files with established tool trust and write authority. The codewriting Agent or assigned Luna maintainer reviews what mechanical formatting does not address and runs a final formatter check after its own edits. A direct formatting-only request uses the `team-code-maintain` Lead adapter and exact `team-code-maintainer` role with proportionate scoped checks. A transfer within material feature work starts only after the original writer freezes its files, and the existing Tester/Reviewer gates remain in force. The maintainer cannot make behavior, API, control-flow, or architecture changes. See the [formatter tool guide](formatter-tool.md) for supported adapters and limits.

| Module | Owner files and responsibility | Dependencies |
| --- | --- | --- |
| Bounded code readability (CODE-READABILITY) | `skills/team-core/scripts/format-code.ps1` and its fixed PowerShell worker select/check/apply supported formatters; `skills/team-core/references/formatter-tool.md` is the portable installed contract; `skills/team-code-maintain/SKILL.md`, `skills/team-core/references/code-readability.md`, and `agents/team-code-maintainer.toml` route safe direct and post-freeze formatting | Existing project formatter/configuration; exact literal files; explicit established tool trust and write authority; final Agent readability review and formatter check; original writer freeze and existing Tester/Reviewer gates for material work |

## UI work

For new pages and visible UI changes, the Lead passes a lightweight UI brief and names one owner for the coherent page or user flow. The owner uses frontend-design for hierarchy, styling and rendered refinement alongside frontend-engineering for implementation correctness. Small demos normally stay with one implementer; independent work may still be delegated. File boundaries must include necessary shared styles or be adjusted explicitly.

Functional tests and rendered visual inspection are separate evidence. The Lead checks the final integrated page's evidence, and missing browser access remains an explicit unverified state. Agent inspection never replaces user manual acceptance. See the [UI delivery contract](../skills/team-core/references/ui-quality.md). This workflow does not claim measured visual improvement until a matched-task comparison is actually run.

## Risk-proportional web engineering

For actual frontend/backend work, `skills/team-core/references/web-engineering.md` maps risk in the changed boundary to selected client or service guidance. Frontend state/data, usability/performance, and backend reliability references are conditional; they preserve the existing Work contract, role selection, stage packet, test tiers, and approval boundaries. Real data, permissions, exposure, or side effects remain relevant even in a demo, while isolated fake-data work does not automatically inherit production hardening. The shared guide is progressive disclosure, not a new lifecycle or a requirement to read every linked document.

| Area | Conditional source | Scope |
| --- | --- | --- |
| Shared selection | `skills/team-core/references/web-engineering.md` | Selects relevant client/service risks and evidence within existing workflow contracts. |
| Frontend | `skills/frontend-engineering/references/state-data.md`; `usability-performance.md` | State ownership, asynchronous data, affected interaction/accessibility behavior, or a measured performance concern. |
| Backend | `skills/backend-engineering/references/service-reliability.md` | Actual API/job contracts, authorization, retries, idempotency, concurrency, partial failure, or recovery. |

## Data work

`team-database-specialist` owns SQL safety, schema design, migrations, indexing, query plans, transaction boundaries, and data-change rollback. It is invoked only when data-layer changes are material.

## Git delivery readiness

`$team-delivery-check` is a conditional, read-only assessment for clear commit, push, pull request, merge, release, or installation-source intent. It checks the operation's exact staged index or outgoing history against applicable project policy, user decisions, and current verification evidence. Ordinary implementation and code review do not trigger it. `team-delivery-checker` interprets policy and evidence; the PowerShell 7 collector supplies bounded mechanical facts. `ready-for-review`, `blocked`, and `needs-user-decision` are collector states, not semantic approval. The Lead retains any separately authorized Git action and installation remains with the existing deployment workflow.

| Module | Owner files and responsibility | Dependencies |
| --- | --- | --- |
| Git delivery assessment (GIT-DELIVERY) | `agents/team-delivery-checker.toml` and `skills/team-delivery-check/SKILL.md` route conditional read-only semantic review; `skills/team-core/references/git-delivery.md` defines policy and scope; `skills/team-core/scripts/git-delivery.ps1` collects bounded local Git evidence | Active catalog exposure of the exact named role; explicit operation, base/target and user intent where required; applicable project policy and current verification evidence; PowerShell 7 and a local Git worktree |

## Optional AI simulation and engineering

`$team-ai-simulate` is an explicit-only local prototyping workflow for AI agents and AI workflows. It uses the existing Codex executor and one bounded, read-only actor profile: `team-ai-simulation-actor-basic` or `team-ai-simulation-actor-advanced`. Both have the same behavior restrictions; the Lead selects the profile from the declared target model family/tier and test purpose, while `team-ai-tester` independently owns case coverage and scoring. The Lead assembles case packets, responds to mock-tool requests, chooses routing and integrates evidence. The AI Tester does not edit the definition or use actor context to score behavior; ordinary `team-tester` covers helper/package behavior and distinct software assertions. `team-ai-architect` may propose bounded AI-domain designs when material questions warrant it; it does not replace software-wide `team-architect`. The workflow adds no scheduler, general workflow engine, production API adapter, recursive delegation or secure thread sandbox. `team-ai-engineer` with `ai-engineering` owns authorized application AI behavior such as prompts, model-call contracts, context/history, tool protocols, routing, and workflow state. Generic service infrastructure remains with `team-backend-engineer`; a shared interface must have one agreed contract and disjoint file ownership. A prototype is a separate decision from engineering production behavior.

| Module | Owner files and responsibility | Dependencies |
| --- | --- | --- |
| Simulation workflow (SIM-WORKFLOW) | `skills/team-ai-simulate/SKILL.md`, `skills/team-core/references/ai-simulation.md`, and target-project versioned definitions/cases; explicit user choice, context packet contract and prototype scope | Native named actor role; user decisions; existing stage packet |
| Simulation evidence (SIM-EVIDENCE) | `skills/team-core/scripts/ai-simulation.ps1` and `skills/team-core/templates/ai-simulation/definition.json`; validate bounded definitions, freeze declared sources, record calls and inspect integrity/drift | PowerShell 7; existing generated-artifact Work protection; target-project local files |
| Simulation actor (SIM-ACTOR) | `agents/team-ai-simulation-actor-basic.toml` and `agents/team-ai-simulation-actor-advanced.toml`; same bounded read-only behavior with purpose-selected profiles | Host-selected exact named role; explicit case packet |
| AI architecture (AI-ARCHITECT) | `agents/team-ai-architect.toml`; bounded read-only AI-domain design, separate from broad software architecture | `ai-engineering`; Lead-owned cross-boundary contract |
| AI engineering (AI-ENGINEERING) | `agents/team-ai-engineer.toml` and `skills/ai-engineering/SKILL.md`; own application-specific prompt/context/model/tool/state behavior after authorization | `$team-dev`; backend boundary agreement; applicable test and review contracts |
| Simulation verification (SIM-VERIFY) | Existing stage verification packet and `tests/test-ai-simulation.ps1`; retain independent acceptance criteria and validate helper behavior in isolation | `team-ai-tester` owns scenario coverage/scoring; ordinary `team-tester` covers helper/package behavior; Reviewer; no live production service |

The helper records supplied packets, observed outputs, mock results, state and Lead routing evidence. It cannot prove the full host prompt, actor identity without host metadata, cost when telemetry is absent, semantic acceptance, or criteria secrecy through shared files. Luna can serve as a proxy for a lightweight target; proxy success is not target-model equivalence. No code restructure of the existing executor or business runtime is required.

Application AI behavior evaluations use the separate `team-ai-tester` role and [`ai-evaluation.md`](../skills/team-core/references/ai-evaluation.md). It owns assigned evaluation cases and artifacts; ordinary `team-tester` remains responsible for Kit helper/package behavior and distinct software assertions when needed. Simulation actors remain separate from the independent evaluator. This is guidance and role routing, not a new evaluation runtime.

The `ai-engineering` Skill chooses the simplest sufficient application execution shape, then conditionally routes the focused guides [`ai-workflow-design.md`](../skills/team-core/references/ai-workflow-design.md), [`ai-instruction-design.md`](../skills/team-core/references/ai-instruction-design.md), [`ai-context-design.md`](../skills/team-core/references/ai-context-design.md) and [`ai-tool-design.md`](../skills/team-core/references/ai-tool-design.md). They guide design for other projects and add no target-model runtime or reference loader. A target application's model receives a Skill or document only if its own runtime explicitly assembles or retrieves it; engineering evidence must trace the canonical source through the actual call path.

### Replaceable application AI capabilities and record/replay tests

Application business backends depend on a project-defined Agent/Workflow capability contract through an adapter; a model change stays inside the Agent/Workflow implementation. The contract may be in-process or service-based and does not prescribe a universal framework. Business authorization, validation, persistence and side-effect policy remain with the application layer that owns them. The shared sources are [`ai-capability-contract.md`](../skills/team-core/references/ai-capability-contract.md) and [`ai-record-replay-testing.md`](../skills/team-core/references/ai-record-replay-testing.md); their concise starting outlines live in `skills/team-core/templates/ai-capability/`.

A representative real application run may provide separate assertions for the capability protocol, AI behavior and backend handling. Its recorded boundary interaction can later be replayed through the real consumer path, but replay does not establish live E2E or prove a replacement AI implementation. Keep the stage packet authoritative for results and preserve required TDD, manual, E2E and repository gates. This Kit adds guidance and templates only: it adds no general runtime, recorder, replay engine or production adapter.

For material cross-cutting migrations beyond this replaceable AI capability, the shared [`architecture-migration.md`](../skills/team-core/references/architecture-migration.md) maps old behavior to approved target contracts, consumers, owners and verification. It is conditional guidance: the existing architecture/Blueprint source owns structure, and the stage packet owns test results and acceptance.

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
