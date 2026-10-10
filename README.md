# Codex Multi-Agent Kit

English | [简体中文](README.zh-CN.md)

A small, user-level development team for Codex. Give it a development goal; the Lead coordinates planning, implementation, testing, and review through native Codex subagents and Skills. It does not require ECC, OMX, a task daemon, or another agent harness at runtime.

## Start here

Use this Kit when you want repeatable development handoffs instead of writing a new coordination prompt for every task. You can also start with planning or a read-only review.

| Your next task | Start with |
| --- | --- |
| Route a task through the appropriate Team workflow | `$team <goal>` |
| Understand a change before editing | `$team-plan <goal>` |
| Implement a feature with verification | `$team-dev <goal>` |
| Check a branch or diff | `$team-review <scope>` |
| Investigate a failure with an unclear cause | `$team-debug <symptom>` |

**First visit:** [install with Codex](docs/codex-install.md), then follow the [first-task walkthrough](docs/first-task.md). The walkthrough includes a small development exercise, acceptance checks, and a way to report where you got stuck.

The Kit is on the 1.0 preview line. Model availability and permissions depend on your Codex account and client. Its instructions and validators do not guarantee runtime behavior, lower costs, or better results; inspect the actual changes and verification evidence.

## Entry points

- `$team <goal>` — the recommended unified entry. Codex may task-match `$team` when you ask for engineering work, or you can invoke it explicitly. The Lead selects or combines existing workflows from intent, authority, evidence, and risk; a second command is not needed. Small fixes, test-only requests, and scoped maintenance can qualify; ordinary factual questions do not enter the full lifecycle. A direct workflow choice or opt-out wins. Automatic selection is best effort, not a guarantee of host loading; explicit `$team` remains the reliable fallback. The entry applies only to the current task and relevant follow-ups. See the [workflow-routing contract](skills/team-core/references/workflow-routing.md).
- `$team-dev <goal>` — plan, implement, test, review, and report a development task.
- `$team-plan <goal>` — produce a decision-ready plan without editing code.
- `$team-review <scope>` — review a branch, diff, or change set in parallel.
- `$team-debug <symptom>` — investigate an uncertain failure before changing code.
- `$team-ai-simulate <AI agent or workflow>` — explicitly prototype bounded AI behavior locally before deciding whether to engineer it.
- `$team-doc-check <task>` — adopt or recheck project documentation and produce a scoped readiness assessment.
- `$team-project-rules <task>` — review, draft, or maintain the target project's `AGENTS.md` guidance.
- `$team-code-maintain <files>` — safely format assigned code or accept a completed-owner readability pass.
- `$team-delivery-check <operation>` — check a planned commit, push, pull request, merge, release, or installation source against project policy and current evidence.

## Team

`team-explorer`, `team-architect`, `team-ai-architect`, `team-docs-maintainer`, `team-frontend-engineer`, `team-backend-engineer`, `team-database-specialist`, `team-tester`, `team-ai-tester`, `team-reviewer`, `team-ai-simulation-actor-basic`, `team-ai-simulation-actor-advanced`, `team-ai-engineer`, `team-code-maintainer`, and `team-delivery-checker` are Codex custom agents. The basic and advanced simulation actors serve one bounded behavior node with the same restrictions; `team-ai-architect` proposes AI-domain designs, `team-ai-engineer` implements assigned AI application behavior, `team-ai-tester` evaluates assigned application AI behavior and simulation cases, `team-code-maintainer` handles assigned behavior-preserving formatting, and `team-delivery-checker` assesses Git delivery scope, project policy, and evidence without changing Git or executing delivery. The main Codex thread is the Lead and owns the task state, integration, and final answer.

`$team` is a Skill entry used by the Lead, not an additional custom agent or model assignment. Direct workflow entries remain available.

## Model allocation

| Role | Model | Reasoning effort |
| --- | --- | --- |
| Architect | `gpt-6.1-sol` | xhigh |
| Explorer | `gpt-6-luna` | medium |
| Docs maintainer | `gpt-6-luna` | high |
| Frontend, Backend, Tester | `gpt-6.1-sol` | medium |
| AI Tester | `gpt-6.1-sol` | medium |
| Database specialist, Reviewer | `gpt-6.1-sol` | high |
| AI simulation actor basic | `gpt-6-luna` | medium |
| AI simulation actor advanced | `gpt-6.1-sol` | medium |
| AI architect | `gpt-6.1-sol` | xhigh |
| AI engineer | `gpt-6.1-sol` | medium |
| Code maintainer | `gpt-6-luna` | medium |
| Git delivery checker | `gpt-6-luna` | high |

For the Lead, select GPT-6 Astra / high in the main session. This is a recommendation, not an installed agent setting. The optional configuration fragment sets generic subagents to GPT-6.1 Sol / medium; named team roles retain their explicit profiles. Existing users who merged the old fragment must update its two `default_subagent_*` values explicitly; the installer does not merge global configuration.

These are workload choices, not measured quality guarantees. See the official [subagent model guidance](https://learn.chatgpt.com/docs/agent-configuration/subagents). Confirm availability in the target account/client before use.

Architect uses GPT-6.1 Sol / xhigh to budget more reasoning for architecture tradeoffs; the Astra Lead checks material decisions before implementation. Higher effort is not evidence of equivalence to Astra. See the [official model guidance](https://developers.openai.com/api/docs/models/gpt-6.1-sol); evaluate omissions, rework and completion time on representative projects.

The kit does not implement automatic model fallback. Keep previous model assignments in Git history as a manual recovery reference, not a second active profile. If a model is unavailable or shows a reproducible regression, first identify the cause and confirm a replacement is available; make an explicit, scoped configuration change with matching validator updates and verification. Do not silently switch models or assume a legacy model bypasses service outages or account limits.

Version `1.0.7` includes the AI development, evaluation and migration guidance described below; see the [changelog](CHANGELOG.md) for the complete release record. Git delivery checking and the unified `$team` entry are available in source as unreleased capabilities; the current release remains `1.0.7`. For a source installation, use the installation receipt's source commit and package digest to identify the installed content, not the version number alone.

When a commit, push, pull request, merge, release, or installation source decision is in scope, `$team-delivery-check` assesses the operation's exact Git scope against project policy and current evidence. It can activate when that delivery intent is clear; ordinary edits and code review alone do not activate it. The collector is read-only, and its mechanical `ready-for-review` result is not semantic approval or permission to perform the Git action. See the [Git delivery contract](skills/team-core/references/git-delivery.md).

Risk-proportional frontend and backend guidance is available in source as an unreleased capability. It selects checks for actual client or service risks; a demo label does not waive real data, permission, or side-effect risks, while static fake-data work does not inherit blanket production hardening. See the [shared web engineering guide](skills/team-core/references/web-engineering.md) and its conditional [frontend](skills/frontend-engineering/references/state-data.md) and [backend](skills/backend-engineering/references/service-reliability.md) references.

## Application AI development and architecture changes

For AI agents and workflows in your own applications, [ai-engineering](skills/ai-engineering/SKILL.md) routes relevant work to shared guides for [workflow shape](skills/team-core/references/ai-workflow-design.md), [instructions and reusable Skills](skills/team-core/references/ai-instruction-design.md), [context assembly and retention](skills/team-core/references/ai-context-design.md), and [tool contracts and side effects](skills/team-core/references/ai-tool-design.md). Use only the guides needed for the task. They help define the target application's behavior; Codex development Skills and file links do not automatically reach the application's model.

The dedicated [ai-testing-engineering](skills/ai-testing-engineering/SKILL.md) Skill and `team-ai-tester` cover application AI behavior. Ordinary software tests still cover deterministic code and integration boundaries. Independent review traces approved intent through the authoritative instruction/workflow source, actual runtime assembly and calls, and verification evidence; static checks alone do not prove adherence or better outcomes.

Material architecture, contract or workflow changes use the [migration-completeness guide](skills/team-core/references/architecture-migration.md) to check affected consumers, state/completion gates, configuration, data and compatibility. Completion reports distinguish a finished component from a finished product migration and identify pending verification. The guide reuses existing project authorities and stage packets; it does not require an exhaustive migration pass for an internal change that preserves behavior and contracts.

## Install for one user

### Human quickstart

Use Codex on the machine where the Kit should be installed and share the [Kit repository](https://github.com/wo-shi-lao-luo/codex_multi_agent). You do not need to clone it manually. If Codex needs a local checkout, it should confirm a safe new destination with you first. A remote/cloud Codex session cannot install files on your computer.

### Copyable request for Codex

> Please install or update this Kit for the current user on this machine from https://github.com/wo-shi-lao-luo/codex_multi_agent. Read its README and `docs/codex-install.md`; if you need a local checkout, ask me to confirm a safe new destination first. Use a local executor, follow the guide, and stop if the source or a conflict is uncertain.

### Manual installation (optional)

From PowerShell 7 in the repository, the direct commands are:

```powershell
.\scripts\validate.ps1
.\scripts\install-user.ps1
```

To update an existing installation, use:

```powershell
.\scripts\update-user.ps1
```

The [Codex installation guide](docs/codex-install.md) explains source selection, preview and discovery checks. The update entrypoint uses the same receipt, `-WhatIf`, conflict protection, and `-Force` backup behavior as the installer. It does not modify `~/.codex/config.toml`. Install, upgrade and downgrade share one deployment manager. Receipt-owned components absent from the target are removed, including obsolete files inside retained Skills. Unknown or modified contents block replacement unless explicitly backed up with `-Force`. See [safe deployment](docs/safe-deployment.md) to pin a tested stable snapshot before trying a new version, restore offline, or deploy a local Git commit without changing the checkout. Backups and the recovery manager intentionally remain outside agent/Skill discovery; project data is not rolled back.

To verify the distributable package without touching your actual Codex or Skills directories, run:

```powershell
.\tests\test-validate.ps1
.\tests\test-stage-verification.ps1
.\tests\test-project-blueprint.ps1
.\tests\test-install-user.ps1
.\tests\test-deployment.ps1
.\tests\test-documentation.ps1
.\tests\test-feedback-runtime.ps1
.\tests\test-ai-simulation.ps1
```

These tests run only in unique system-temporary directories. They verify invalid metadata and missing local references, TDD stage-packet initialization and safe state transitions, the complete package and update behavior, the feedback runtime's validation, aggregation, archive, deletion-confirmation, and cleanup behavior, and local AI-simulation definition/run evidence handling; each directory is removed before its test exits.

To validate public documentation structure and synchronization separately from package validation, run:

```powershell
.\scripts\validate-docs.ps1 -ProjectRoot .
.\tests\test-bilingual-docs.ps1
```

The installer copies agents to `~/.codex/agents` and Skills (including the internal `team-core` policy bundle and feedback runtime) to `~/.agents/skills`. It does not overwrite or merge `~/.codex/config.toml`. The optional [`config/recommended-config.toml`](config/recommended-config.toml) recommends a ceiling of six concurrently open child threads per session, excluding the Lead. If you already merged an older fragment, explicitly update `max_concurrent_threads_per_session` from `3` to `6`. The active Codex session may enforce a lower limit; a config value does not prove the setting is loaded or that six threads are available.

The installer validates the kit before writing. Use `-WhatIf` to preview its actions. It stops on an existing file or Skill directory unless it is an unchanged installation recorded by the kit; use `-Force` only when you want conflicting destinations backed up and replaced. The installation receipt and backups are stored under `~/.agents/codex-multi-agent/` by default.

Agent names use the `team-` prefix to avoid collisions with personal agents. Historical components absent from the installation receipt are left untouched; inspect their ownership before removing them manually.

Current release: `1.0.7` (AI development/evaluation guidance, migration completeness and first-use onboarding on the 1.0 preview line; not a stable-release declaration). Kit-owned local generated artifacts use narrow Git protection and an index check. Documentation governance metadata, index and review records stay on disk locally but are not shared through Git; a fresh checkout must establish its own adoption/review state. User-authored project documents, PRDs, Blueprint, verification packets and native specs remain versionable. Tracked local artifacts and explicit include-rule conflicts need a user decision. The kit installs no Git hooks or background watcher, and manual forced staging remains possible. See [generated-artifact Git protection](skills/team-core/references/generated-artifacts.md). The feedback runtime currently supports `$team-dev`, `$team-plan`, `$team-debug`, and `$team-review`; `$team-ai-simulate` keeps its separate bounded local run trace and does not call that runtime. `$team-dev` creates and validates Git-tracked stage verification packets in target projects, using `test-first` where practical and documented alternatives where it is not. Persistent repair loops research relevant external evidence after two ordinary failures; applicable new evidence may support one conditional extension, up to five repair attempts total. Debug research uses the existing six-round allocation. Pauses remain evidence-based and require user authorization to resume; long healthy operations have task-specific progress checkpoints, not a universal time cutoff. Test execution uses risk tiers and evidence-based reuse, with scoped Explorer discovery available when the test surface is unclear; required E2E/manual scope and repository gates remain authoritative. See [repair and diagnosis loop guard](skills/team-core/references/repair-loop-guard.md), [feedback recording](skills/team-core/references/feedback-recording.md), [test and acceptance contract](skills/team-core/references/test-acceptance-contract.md), [TDD protocol](skills/team-core/references/tdd-protocol.md), [code comment contract](skills/team-core/references/code-comments.md), [code readability contract](skills/team-core/references/code-readability.md), [scoped formatter tool](docs/formatter-tool.md), [project rules](skills/team-core/references/project-rules.md), [AI simulation guide](docs/ai-simulation.md), [versioning policy](docs/release-versioning.md), and the [changelog](CHANGELOG.md). Version 0.1.0 also renamed `sql-safety` to `database-engineering` and `test-strategy` to `testing-engineering`. Historical Skill directories not recorded in the receipt remain untouched; receipt-owned retired Skills are reconciled against the selected target.

Visible UI work uses [frontend-design](skills/frontend-design/SKILL.md) alongside frontend-engineering. The [UI delivery contract](skills/team-core/references/ui-quality.md) preserves page-level goals through delegation and requires rendered inspection separate from functional tests. No extra design agent, model change or per-page design document is required. Missing browser evidence must be reported as visually unverified, not release-ready.

Restart Codex if a newly installed Skill is not immediately visible.

## Operating rules

Direct formatting/readability requests route through `$team-code-maintain` to `team-code-maintainer`. For supported project setups, the role uses the installed formatter helper on exact files, reviews readability left after mechanical formatting, and runs a final formatter check. Tool execution and writes use the caller's already-established trust and authorization; the helper does not install tools or silently replace unsupported project formatters. Its Skill allows per-request implicit invocation; it does not install a background formatter. `$team-delivery-check` is another conditional exception: clear commit, push, pull request, merge, release, or installation-source intent can trigger its read-only assessment; ordinary edits and code review alone do not. The unified `$team` entry can be selected by task matching for engineering work or invoked explicitly; ordinary questions stay direct, explicit workflow choices and opt-out take precedence, and selection does not waive permissions or gates. This is not a durable global mode. An explicit request to run existing tests only can use a bounded verification scope without a production writer or an invented review diff. This pure maintenance path does not force the full `$team-dev` lifecycle. A formatting transfer inside material feature work starts after the original writer freezes the files; that task's Tester/Reviewer gates remain in force. The later Lead-only exception is for genuinely trivial corrections incidental to other work. See the [code readability contract](skills/team-core/references/code-readability.md) and [formatter tool guide](docs/formatter-tool.md).

Code changes through `$team-dev` or a Team-selected development mode, including small fixes and behavior-changing scripts/configuration/Skill instructions, default to a named implementer and the Tester role selected for the behavior: `team-tester` generally, or `team-ai-tester` when application AI behavior evaluation is primary. Mixed tasks use one canonical packet owner and add a second Tester only for distinct required coverage. Risk and material impact, not file or line count, determine independent review and specialist needs. Small tasks may shorten records but retain every applicable engineering check. Lead-only code execution requires a specific user request/approved exception; ordinary "just fix it" is not that approval, and missing roles never permit silent fallback. See [role routing](skills/team-core/references/role-routing.md), the [minimum complete path](skills/team-core/references/execution-contract.md), and the [AI evaluation contract](skills/team-core/references/ai-evaluation.md). Pure nonbehavior spelling/formatting edits may remain Lead-only. Start and close declarations reconcile intended roles/checks with actual evidence. The unified `$team` entry is task-matched or explicit, with direct workflow choices and opt-out taking precedence; `$team-code-maintain` and `$team-delivery-check` retain their own conditional invocation boundaries.

`$team-plan` and `$team-dev` choose light or fuller design exploration from material risk and unresolved uncertainty, not task/file size; already accepted decisions are not re-gated without relevant new evidence. See the shared [design-exploration contract](skills/team-core/references/design-exploration.md).

Stage test plans use [manual-to-automated coverage](skills/team-core/references/test-acceptance-contract.md#manual-scope-and-automated-coverage): E2E plans include every manual scenario/requirement with equivalent conditions/results and checkpoints. Encountered user additions synchronize E2E and applicable other-layer tests, mappings and affected evidence. Unautomatable observations stay visible pending a user exception decision; plan inclusion is not passing coverage. No background watcher or automatic modification of archived acceptance is introduced.

[Efficient test execution](skills/team-core/references/test-acceptance-contract.md#efficient-test-execution) is the default for Codex-run testing of any product. Prefer repeatable programmatic runners and structured result summaries; cover business-rule combinations broadly through adequate API/integration entrypoints, while retaining complete browser journeys and distinct UI/client risks. Avoid duplicate assertions only with equivalent conditions and evidence; preserve rendered visual checks and manual acceptance. No API, new test seam, screenshot-every-step workflow or measured token-saving claim is imposed.

### Documentation readiness

Team planning/development applies [documentation governance](skills/team-core/references/documentation-governance.md). Existing projects get scoped discovery/adoption; new/changed docs are classified and previous evidence is checked before reuse. The docs/governance marker tracks adoption, not a whole-project pass. Prefer docs/, active applicable PRDs in docs/PRD, and confirmed historical material in docs/legacy; no mandatory document set or empty category directories. Readiness depends on task information, not filenames. Cross-document reviews distinguish redundant detail, complementary guidance, same-scope conflicts and legitimate repeated references; authority is assessed by topic and scope. Unresolved intent remains for user direction, with dependent work paused and independent work allowed to continue. Runtime hashes detect changes but do not certify semantic sufficiency or approval. Checks are task-scoped; there is no background monitoring or automatic OpenSpec adoption.

At task start, when work first enters a relevant module, and when related rule/command/convention evidence changes, `$team-plan` and `$team-dev` assess applicable project instructions. The Lead brings evidence-backed, task-relevant gaps to the user with a suggested change even when the task did not mention `AGENTS.md`; missing, short, or old files alone do not trigger a proposal. Any target instruction-file write requires approval for its bounded path/rules, while ordinary code-development permission is not enough. Reuse the existing decision record to avoid repeating an unchanged proposal. See the [project-rules contract](skills/team-core/references/project-rules.md) for root/nested scope, overrides and limits; the checks add no background watcher or automatic edits.

### Optional OpenSpec integration (review preview)

The kit can optionally use OpenSpec **1.13.2** as an external specification manager while keeping its own Lead, TDD and acceptance flow. It is not installed or enabled by the kit installer. The adapter requires PowerShell 7 and upstream Node.js 20.19+; see [setup, supported profile and recovery](skills/team-core/references/openspec-integration.md). Existing projects without an opt-in marker are unchanged. Custom schemas/stores are not adapted in this first profile.

Run `tests/test-openspec.ps1` for isolated contract tests. Pass `-OpenSpecEntry <trusted-installation>/bin/openspec.js` to add the real pinned-CLI lifecycle; no dependency downloads occur in tests. This capability is versioned as 0.7.0; assigning a version does not mark it as maintainer-approved stable or update the local installation.


New applications, multi-stage initiatives and material structural changes use a [Project Blueprint](skills/team-core/references/project-blueprint.md). Discover an existing repository before documenting its modules and file responsibilities. Structural refactoring requires explicit user approval; if declined or deferred, preserve the current structure and record its constraints. Stage packets reference the blueprint revision, module IDs, file scope and entrypoint exceptions. Blueprint validation checks document structure; code review checks the actual architecture.

- The recommended ceiling is six concurrently open child threads across the Lead's session, subject to lower host capacity. Usually 2–3 is enough; add more only for ready, independent work. Before exceeding three, explain the reason and record distinct outputs, dependencies, write boundaries and integration in the existing work record. See [adaptive concurrency](skills/team-core/references/role-routing.md#adaptive-child-thread-concurrency).
- One owner writes production code by default. The Lead uses worktrees only after assigning non-overlapping files or modules.
- Parallelize only work with ready inputs and independent outputs, such as read-only checks, disjoint files or isolated fixtures. Keep shared mutable test state and dependent work sequential; plan shared-contract changes before a writer starts.
- A role reports findings, touched files, verification, and blockers back to the Lead. Only the Lead claims completion.
- Team workflows preflight needed named roles against the active tool catalog and explicitly select them; task labels or source TOMLs are not proof of role/model loading. Unavailable roles require a user decision before an alternative. Every final response lists the actually used child agents (ID, selected role, task and status), including created failures/retries, or explicitly states none; unconfirmed runtime identity/model stays unknown.

See [architecture](docs/architecture.md), [role routing](skills/team-core/references/role-routing.md), and [source notes](docs/upstreams.md).
