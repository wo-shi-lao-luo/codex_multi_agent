# Changelog

English | [简体中文](CHANGELOG.zh-CN.md)

## [1.0.7] - 2026-10-10

### Added

- Add the dedicated `team-ai-tester` role and `ai-testing-engineering` Skill for application AI behavior evaluation, with shared case, rubric, independent-judging, model/evaluator identity and bounded-evidence guidance. Preserve ordinary software testing for deterministic behavior and integration boundaries; prototype simulation remains a separate explicit workflow.
- Add conditional application AI design guides for workflow shape, instructions and reusable Skills, context assembly/retention, and tool contracts/side effects. Distinguish development-time Skills from context actually supplied to an application's model, and verify selected sources through the real assembly/call path.
- Add cross-cutting architecture-migration guidance for affected contracts, consumers, workflow/completion gates, configuration, persisted state and compatibility. Reuse existing authorities and acceptance packets; distinguish component completion, product migration completion and pending evidence.
- Add a bilingual README starting section, a first-task walkthrough, and optional installation-help and usage-feedback issue forms. Feedback is voluntary; no automatic telemetry is introduced.

### Changed

- Route planning, development, simulation assessment and review to the relevant AI design/evaluation contracts. Mixed software/AI tasks retain one canonical packet owner and add another Tester only for distinct required coverage. Review approved intent, canonical source, actual assembly/calls and independent evidence rather than treating file presence as runtime proof.
- Simplify Work artifact protection to the existing root `/_work/` ignore policy. Preserve local files and user-directed handling of already tracked content or explicit include-rule conflicts; add no automatic untracking, hooks or background watchers.
- Synchronize public capability descriptions and release records in both languages. Allow an optional leading Unreleased section in the repository documentation validator, with isolated tests for bilingual drift and invalid layouts. Version this enhancement as `1.0.7` on the existing preview line; preserve earlier release history and do not declare stable status.

## [1.0.6] - 2026-10-08

### Changed

- Schedule relevant fast checks during iterations, affected real integration/API and key smoke checks at the first usable chain, and costly browser/Agent-driven checks at named acceptance checkpoints. Preserve full planned coverage, risk-based expansion, required fresh gates and user-only manual acceptance; deferred evidence cannot satisfy a due checkpoint.
- Clarify bounded small-task testing: practical minimal reproduction and affected regression checks at the lowest adequate boundary, with due acceptance evidence at standalone handoff or an agreed batch checkpoint. Do not automatically require every test layer or the full suite for each fix.
- Consolidate duplicated procedures in twelve Skill entries into shared authoritative references with explicit use-point routing and complete reads of selected resources. Preserve role, approval, TDD, E2E and independent AI-simulation assessment boundaries; these instruction changes do not establish runtime enforcement or measured token savings.

## [1.0.5] - 2026-10-07

### Added

- Add a Codex-facing local installation guide and concise README entrypoints with a copyable install/update request. Clarify source selection, preview and conflict boundaries, and the difference between installed files and runtime discovery.

## [1.0.4] - 2026-10-07

### Added

- Extend task-scoped documentation governance with semantic consistency checks across relevant documents. Distinguish redundant detailed rules, complementary scopes and exceptions, conflicts under the same conditions, and legitimate repetition such as navigation, bilingual counterparts and historical evidence.
- Determine authority for each claim and scope from existing versioned sources or confirmed user decisions. Treat code/configuration as evidence of observed behavior, not approved intent; route focused Explorer, Architect and Tester evidence through the Lead. Do not create a parallel authority registry or a new finding kind.
- Allow assigned maintainers to replace a redundant passage with a useful summary and specific reference only when its authority is clear. Preserve unique context; keep disputed claims intact for user direction and pause only dependent work. Whole-document moves/deletion, historical or acceptance edits, and target instruction writes retain their existing approval boundaries.
- Add safe child-thread lifecycle guidance to the existing role-routing contract: reconcile roles and roster at workflow events, preserve named-role identity, require complete handoff and independent process/write ownership before a documented host close, and keep unsupported or uncertain closure distinct from capacity evidence. A confirmed close permits only a bounded retry of the same queued role; existing limits and final roster obligations remain.

### Changed

- Trigger semantic checks during scoped adoption, relevant document changes, material implementation changes affecting documented claims, task closure, or discovery of a related defect. This is not a full-repository sweep or background watcher.
- Increment documentation policy to version 3 so prior scoped assessments require fresh review; retain the existing review schema and adoption configuration. Keep detailed reconciliation rules in the shared governance reference, with concise routing in `team-doc-check` and the GPT-6 Luna / high Docs Maintainer instructions.

## [1.0.3] - 2026-10-07

### Added

- Add the PowerShell 7 `team-core/scripts/format-code.ps1` helper for bounded Plan, Check, and Apply operations over literal project-relative files. It supports Prettier, Ruff, PowerShell, and Biome when compatible with existing project configuration; it does not install tools or replace unsupported project formatters.
- Add [the formatter tool guide](docs/formatter-tool.md) and connect the helper to the shared code-readability contract and direct code-maintenance workflow, including trust/write acknowledgements and known failure limits.

### Changed

- Have codewriters use supported formatter checks for assigned files, then review remaining readability with the Agent and recheck formatting after further edits. Formatting remains behavior-preserving and uses only the authority already established for the files and tooling.

## [1.0.2] - 2026-10-07

### Added

- Add a shared code-readability contract for code authors, testers, and reviewers. Prefer each project's formatter; otherwise target 100 characters and treat lines over 120 as a review signal. Preserve meaningful strings, generated/vendor content, snapshots, and mandatory test explanations.
- Add implicitly invokable `$team-code-maintain` and the exact `team-code-maintainer` role configured as GPT-6 Luna / medium. Direct behavior-preserving formatting uses scoped checks without requiring the full `$team-dev` lifecycle; an unavailable named role does not silently fall back.

### Changed

- Route codewriters, testers, and reviewers through the shared readability contract. Formatting transfers start only after the original writer freezes the files and retain the material task's existing Tester/Reviewer gates; the formatting-only boundary excludes renames, API/control-flow changes, and behavior changes.

## [1.0.1] - 2026-10-05

- Add automatic, risk- and uncertainty-based design-depth checks to `$team-plan` and `$team-dev`: clear work uses a light check, while materially unresolved decisions receive bounded fuller exploration. Reuse accepted decisions unless relevant scope or evidence changes.
- Add shared context, proposal, routing and handoff guidance for Explorer, read-only Architects, Developers and Testers. Preserve existing PRD/Blueprint/OpenSpec/Work/stage authorities, approval/refactor/debug-budget gates, and exclude bounded AI simulation actors. No new runtime, agent or upstream dependency is introduced.

## [1.0.0] - 2026-10-05

- Start the new `1.0.0` major product line as a review preview; this version does not automatically promote the Kit to stable. Add the explicit-only `$team-ai-simulate` workflow for prototyping AI agents and AI workflows before a separate engineering decision.
- Add model-agnostic `team-ai-simulation-actor-basic` and `team-ai-simulation-actor-advanced` profiles with the same bounded behavior contract, a read-only `team-ai-architect`, and `team-ai-engineer` plus `ai-engineering` routing for authorized application AI behavior. Actor tier selection follows target model family/tier and test purpose; role configuration takes precedence over spawn model overrides.
- Define four explicit context modes, synthetic cases with criteria kept outside the actor packet, Lead-controlled routing/mock results, approved-proxy versus target-model distinctions, and host-context/identity/usage limits.
- Add the local `team-core/scripts/ai-simulation.ps1` helper and reusable definition template. It validates bounded definitions, freezes declared source snapshots, records non-replaceable call evidence with a terminal integrity head under an exact protected `_work/ai-sim-<task>/` path, and reports integrity/drift without running models or deciding acceptance.
- Add the shared AI-simulation contract, engineering guidance and verification entry; keep raw traces separate from the `team-core` feedback runtime, which continues to support `$team-dev`, `$team-plan`, `$team-debug`, and `$team-review` only.

## [0.10.1] - 2026-10-04

- Add bounded external-source research to persistent bug-fix and debug workflows: research follows the ordinary two-failure retrospective, while explicitly authorized debug research consumes an existing diagnostic round. Applicable evidence may qualify one conditional extension from three to at most five ordinary repair attempts; user budgets, scope/safety gates, and pause conditions remain controlling.
- Add `skills/team-core/scripts/generated-artifacts.ps1` with `Documentation`, `OpenSpec`, and `Work` profiles. `Work` protects only an exact `_work/<boundedtask>` path. `Protect` appends narrowly scoped rules to `ProjectRoot/.gitignore`; `Check` audits the actual index and effective include policy. Documentation temporary rules match only exact Kit-generated siblings with a 32-character lowercase-hex token and `.tmp`, not general `*.tmp` files.
- Protect documentation and OpenSpec local outputs before writing; `$team-dev` protects each applicable scope before generation and repeats `Protect` plus `Check` before an authorized commit or handoff. The complete Documentation governance runtime bundle (`<DocsRoot>/governance/reviews/` plus the exact `documentation.json` and `doc-index.md` files) stays on disk locally and defaults to ignored; other `governance/` content is not broadly ignored. A fresh checkout must establish adoption/review state from its available documents. User-authored governance docs, PRDs, `AGENTS.md`, Blueprint, active and archived verification packets, and native specs and archives remain versionable. Tracked artifacts and explicit include rules require user-directed handling. No files are automatically untracked or staged; no Git hook, background watcher, or prevention of manual `git add -f` is added. Add isolated real-Git regression coverage; this patch remains a review preview and does not update a local installation.

## [0.10.0] - 2026-10-04

- Add the `team-project-rules` Skill and shared contract for assessing, drafting, and maintaining target-project `AGENTS.md` instructions; connect it to planning, development preflight, and documentation checks.
- Define bounded discovery of root-to-working-directory instruction candidates, including `AGENTS.override.md`, `AGENTS.md`, explicit fallback names, and absent or shadowed paths. The read-only helper reports candidate metadata without exposing instruction contents or global Codex settings.
- Distinguish agent working guidance from product requirements, architecture, and task acceptance. Require actual user authorization for first creation or policy changes, preserve existing user content, and ask on material ambiguity while allowing independent authorized work to continue.
- Add isolated coverage for candidate precedence and scope, documentation review dependencies, and package routing. Discovery does not draft policy, authenticate approval, or prove the active Codex session loaded an instruction file.
- Assess instruction coverage at task start, first entry to a relevant module, and when related evidence changes; surface only material, evidenced gaps to the user, and require approval for every target instruction-file write. Reuse reachable decisions to avoid duplicate proposals; no background watcher or missing/short/old-file trigger is added.

## [0.9.5] - 2026-10-02

- Add risk-tiered test selection from changed behavior through affected modules/dependents, stage-impact and core smoke checks, with broader or full-suite execution when cheaper, required by repository gates, or justified by shared/security/data/dependency/build/test configuration, integration, or uncertain impact. E2E/manual coverage and acceptance gates remain unchanged.
- Permit reuse of prior results only when reachable artifacts establish the relevant source, test, configuration, dependency, data and environment identity; changed or unknown relevant inputs invalidate affected evidence. Distinguish reused evidence from fresh execution and record batch purpose, cost forecast or unknown, checkpoints, and any user hard budget.
- Define an optional, scoped Explorer test-surface inventory after behavior/module boundaries are supplied. Explorer reports paths, IDs, assertions, commands, boundaries, dependencies and evidence gaps; Tester retains coverage/execution/sufficiency decisions and Lead retains authorization, resource and gate decisions. No new packet schema, scheduler, cache framework, or measured savings claim is introduced.

## [0.9.4] - 2026-10-02

- Add a shared repair/diagnosis loop guard: ordinary repairs require an evidence retrospective after two failures and pause after three; explicitly requested/approved debug mode allows up to six purposeful diagnostic rounds, reviewed at three, with an earlier pause after three consecutive completed rounds without useful evidence or narrowing.
- Preserve issue identity and history across changed strategies, files, agents and handoffs; keep diagnostic and repair authority/budgets separate, require actionable evidence-led human pause reports and bounded resume, and use task-specific progress checkpoints for healthy long operations without a universal time limit. This is an inspectable instruction contract, not a runtime timer or guaranteed interrupt.

## [0.9.3] - 2026-10-02

- Default Codex-run testing of all products to adequate low-observation-cost entrypoints, repeatable programmatic execution and structured summaries with evidence drill-down; this is not restricted to products containing AI.
- Give API/integration tests broad business-rule coverage and browsers complete user journeys plus distinct UI/client and front-to-backend risks. Remove redundant business permutations from proposed browser plans only with equivalent conditions/assertions and evidence; preserve manual-to-E2E mapping and rendered inspection.
- Add execution/observation planning fields to new stage packets and workflow templates, with isolated generator/nonmutation regressions. Existing schema2 packets, TDD tracks and user-only acceptance/archival remain compatible; no forced API, new production seam, real installation, global activation or measured token savings is introduced.
- Add a complete Simplified Chinese README and changelog, reciprocal language navigation, same-change maintenance rules, and a separate repository-only structural validator with isolated tests. Semantic translation still needs human review; the 0.9.3 version line is retained.
- Recommend a per-session ceiling of six concurrently open child threads, excluding the Lead, with adaptive use based on ready independent work and actual host capacity. Explain and record expansion beyond three; preserve role obligations and avoid parallel work with shared mutable state or dependencies. Existing installations must update the setting explicitly; source config does not establish loaded runtime capacity.

## [0.9.2] - 2026-10-02

- Clarify document content ownership: README remains a stable project entrypoint; development journals, detailed test procedures, stage results and readiness records reuse their existing authoritative documents.
- Require prompt, evidence-backed correction of related documentation defects encountered during authorized edits, with bounded ownership, preserved history and references, user decisions for substantive ambiguity, and read-only tasks remaining non-mutating.
- Add Lead/writer assignment and semantic close checks for document placement and duplicate or stale facts; no automatic cleanup, new required document set, runtime/schema change or installation is introduced.

## [0.9.1] - 2026-10-02

- Require E2E scenario plans to include every manual case/requirement with equivalent conditions/results and explicit checkpoints; distinguish listed, implemented, executed and passing evidence and require user decisions for automation exceptions.
- Synchronize encountered user-added/changed manual samples and requirements into E2E and applicable other-layer test plans/assertions/results. Preserve ambiguity, product-scope authority and archived acceptance; no background watcher or new packet schema is introduced.
- Add a manual-to-automated mapping to new schema2 packets and isolated initializer/lifecycle regressions. Existing packet structure and user-only archival rules remain compatible; no automatic semantic coverage, stable promotion, local installation or push is claimed.
- Route small code-changing Team development tasks to a named implementer plus Tester; preserve independent review for material work and escalate by risk rather than file count. Lead-only code work requires specific user authorization and retains applicable engineering responsibilities.
- Separate team size from required lifecycle checks and add concise start/close reconciliation of roles, applicable standards and evidence. Nonbehavior typo/formatting work may remain Lead-only; no global activation, automatic fallback, new runtime gate or loaded-identity guarantee is introduced.

## [0.9.0] - 2026-09-30

- Add task-scoped documentation governance, existing-project adoption, document inventories and explicit review records with policy-version and input-change checks.
- Add team-doc-check and a GPT-6 Luna / high docs maintainer, routed from team planning, development and review. Lead owns readiness and specialist escalation.
- Prefer docs/ with PRDs in docs/PRD and confirmed superseded material in docs/legacy; categories remain task-dependent, substantive ambiguity requires a user decision, and historical/unread sources cannot silently become current authority.
- Add isolated adoption/readiness and package-routing tests. No automatic model-quality claim, background monitor, legacy move, local install or stable promotion is introduced.
- Require active-session named-role preflight, explicit role selection without silent generic fallback, invocation reconciliation and a final actual child-agent roster across Team workflows. Add isolated routing regressions; static package checks do not certify runtime calls or loaded models.

## [0.8.1] - 2026-09-30

- Move Architect to GPT-6.1 Sol / xhigh; retain the separate Lead recommendation of GPT-6 Astra / high.
- Move frontend, backend, testing, database and review roles and the optional generic subagent default to GPT-6.1 Sol, preserving their reasoning efforts. Explorer remains GPT-6 Luna / medium.
- Update profile validation and isolated regression checks. This configuration update does not establish measured model-quality improvements or change existing local installations automatically.

## [0.8.0] - 2026-09-29

- Replace per-component installation with receipt-based deployment, exact downgrade reconciliation and whole-operation recovery.
- Add explicit stable snapshots, an independent persistent rollback entrypoint, local Git-ref deployment, conflict protection and explicit snapshot pruning.
- Add isolated upgrade/downgrade and fault-injection tests; do not install or declare this preview stable automatically.

## [0.7.0] - 2026-09-29

- Add an opt-in, externally installed OpenSpec 1.13.2 adapter; retain one Lead and native kit behavior for non-adopters.
- Link stable requirement/scenario/task IDs to existing stage packets, detect stale specification inputs, and gate archive on actual evidence and user acceptance/deferral.
- Preserve recovery snapshots on uncertain upstream archive failure; add isolated fault-injection and optional real-CLI lifecycle tests.
- Version this new specification-management capability as 0.7.0; this does not mark it as maintainer-approved stable or install it locally.

All notable changes to this project are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions use [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.1] - 2026-09-29

### Changed

- Move implementation, database, testing and review roles to GPT-6 Sol; keep Tester at medium reasoning and database/review at high.
- Move Explorer to GPT-6 Luna with medium reasoning; retain Architect on GPT-6 Astra with high reasoning.
- Update the optional generic subagent default to GPT-6 Sol / medium and document the separate Lead recommendation.
- Add regression checks for the approved role profiles and rejection of model/effort drift. No automatic legacy-model fallback is introduced.

## [0.6.0] - 2026-09-22

### Added

- A frontend-design Skill for coherent first-version interfaces, reusable visual baselines and rendered-page refinement.
- A shared UI delivery contract preserving product goals, complete page/flow ownership and separate functional/visual evidence through delegation and integration.
- UI routing regression checks; the existing isolated installer tests cover the new packaged resources.

### Changed

- Frontend, planning, development, testing and review workflows now distinguish rendered visual verification from functional tests and user acceptance.
- Frontend role instructions include whole-page quality responsibility without changing model profiles or authorizing unrelated redesigns.

## [0.5.2] - 2026-09-21

### Changed

- Define layered comment minimums for files, interfaces, internal business logic and important implementation decisions.
- Require scenario and expected-result explanations for every in-scope test case, including parameterized and script-based tests, with assertion-consistency checks.
- Strengthen writer self-checks and review records to distinguish missing mandatory documentation from stylistic preferences.

## [0.5.1] - 2026-09-20

### Added

- Shared code-comment standards for non-obvious rationale, synchronized maintenance, writer self-checks and semantic review, with routing validation and isolated regression coverage.

### Removed

- The one-time existing-project handoff guide and its index links after use.

## [0.5.0] - 2026-09-20

### Added

- Project blueprints for application structure, module responsibilities and stage alignment.
- Existing-project discovery, explicit approval for structural refactoring, and continued development within a declined or deferred refactor baseline.
- Blueprint initialization/validation and stage checks for blueprint revisions and module IDs, with isolated regression tests.

## [0.4.0] - 2026-09-20

### Added

- A framework-neutral TDD protocol with `test-first`, documented `test-after`, and `manual-or-environmental` tracks.
- Packet validation that checks controlled coverage decisions, TDD evidence, a unique final manual status, and safe archival conditions.
- Isolated tests for stage-packet validation, state handling, archival, and test cleanup.

### Changed

- `$team-dev`, `$team-plan`, `$team-debug`, `$team-review`, and `testing-engineering` now use the shared TDD protocol at their relevant lifecycle points.

## [0.3.1] - 2026-09-20

### Added

- Git-tracked stage verification packets with use cases, coverage decisions, automated plans, and human verification scripts.

### Changed

- `$team-dev` establishes and reconciles a Test & Acceptance Contract before and after implementation.

## [0.3.0] - 2026-09-18

### Added

- Local, opt-in-by-workflow acceptance records for the four explicit `team-*` workflows.
- A `team-core` feedback runtime that validates run records, aggregates candidate signals, archives aged records, and requires explicit confirmation before deletion.
- Isolated runtime tests and an approved feedback-loop architecture design.

### Changed

- The installer now ships the feedback runtime as part of the existing `team-core` Skill package.

## [0.2.0] - 2026-09-18

### Added

- Safe user installation, update, validation, receipts, backups, and isolated package tests.
- Model routing for the seven team roles.

### Changed

- Standardized all executable Skills on the shared team execution harness.

## [0.1.0] - 2026-09-18

### Added

- Initial Codex multi-agent team, explicit workflow Skills, and shared execution contracts.
