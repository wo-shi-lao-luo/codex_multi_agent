# Folder structure

## Purpose

`codex_multi_agent` is the editable source repository for a user-level, Codex-only multi-agent development toolkit.

## Active deliverable

The toolkit source is the current editable master. `scripts/install-user.ps1` validates current source and delegates installation to `scripts/deploy-user.ps1`, which also manages explicit downgrade and recovery.

## Directory map

- `.github/ISSUE_TEMPLATE/` — optional bilingual first-use support and usage-feedback forms; no automatic telemetry.

- `agents/` — native Codex custom-agent TOML files.
- `agents/team-docs-maintainer.toml` — Luna/high documentation specialist; bounded assigned-doc maintenance and evidence-backed findings.
- `agents/team-ai-simulation-actor-basic.toml` and `team-ai-simulation-actor-advanced.toml` — bounded read-only AI workflow actors with the same behavior contract and basic/advanced profiles.
- `agents/team-ai-architect.toml` — Sol/xhigh read-only AI-domain architect, separate from software-wide `team-architect`.
- `agents/team-ai-engineer.toml` — Sol/medium implementation role for assigned AI prompts, context, model/tool protocols and workflow state.
- `agents/team-ai-tester.toml` — Sol/medium specialist for assigned application AI behavior evaluation; production behavior remains with its implementation owner.
- `agents/team-code-maintainer.toml` — Luna/medium role for assigned, behavior-preserving code formatting after ownership is frozen.
- `skills/` — reusable Codex Skills. Most `team-*` Skills are explicit workflow entrypoints; `team-project-rules` also routes from task-time evidence checks in `$team-plan`/`$team-dev`. `team-core` bundles their shared policy references for installation.
- `skills/team-ai-simulate/` — explicit-only local AI agent/workflow prototyping Skill; simulation is separate from production authorization.
- `skills/team-code-maintain/` — implicitly invokable Lead adapter for direct formatting requests and bounded post-freeze readability transfers; behavior changes remain with the original code owner.
- `skills/team-core/scripts/format-code.ps1` and `format-code-powershell.ps1` — bounded Plan/Check/Apply adapter for supported installed formatters; its portable contract is `skills/team-core/references/formatter-tool.md`.
- `skills/ai-engineering/` — AI application behavior Skill for authorized engineering of prompts, context, model/tool protocols and workflow state.
- `skills/ai-testing-engineering/` — AI application behavior evaluation Skill, with detailed case, rubric and evidence rules in the shared `skills/team-core/references/ai-evaluation.md`.
- `skills/team-core/references/ai-simulation.md` — shared local simulation context, evidence, privacy and acceptance contract.
- `skills/team-core/references/ai-evaluation.md` — application AI case design, independent judging, model/evaluator identity, stochastic baselines and bounded evidence contract.
- `skills/team-core/references/ai-capability-contract.md` and `ai-record-replay-testing.md` — project-specific Agent/Workflow replacement boundary and distinct live, record, replay and synthetic test evidence contracts.
- `skills/team-core/templates/ai-capability/` — optional concise starting outlines for a target project's capability brief and record/replay test plan; the target project adapts or omits them to match existing authorities.
- `skills/team-core/references/design-exploration.md` — shared risk-proportional design-depth, bounded proposal, approval and decision-reuse contract for Team planning/development.
- `skills/team-core/references/architecture-migration.md` — conditional, cross-cutting map for material architecture, contract, workflow/state, configuration/eligibility, persisted-data/job, and compatibility migrations; existing Blueprint and stage packets remain authoritative.
- `skills/team-core/scripts/ai-simulation.ps1` and `templates/ai-simulation/definition.json` — bounded definition validation, frozen source snapshots, non-replaceable call records with a mutable fail-closed terminal head, and a reusable target-project definition example.
- `skills/team-doc-check/` — documentation readiness/adoption entrypoint; distributed Skill source, not repository discovery configuration.
- `skills/team-project-rules/` — entrypoint for reviewing, drafting and maintaining target-project `AGENTS.md` files.
- `skills/team-core/references/documentation-governance.md` — task-scoped sufficiency, topic-scoped document authority, semantic consolidation and conflict handling, ambiguity and legacy contract with runtime schema.
- `skills/team-core/references/project-rules.md` — target-project instruction-file authority, candidate discovery, approval and maintenance contract.
- `skills/team-core/scripts/documentation.ps1` — local document inventory, adoption, scoped review and stale-evidence detector.
- `skills/team-core/scripts/generated-artifacts.ps1` — narrow profile-based local artifact protection and read-only Git-index checks; see `skills/team-core/references/generated-artifacts.md`.
- `skills/team-core/references/generated-artifacts.md` — artifact profiles, durable evidence boundaries, result schema, conflict handling and caller lifecycle.
- `skills/team-core/scripts/project-rules.ps1` — read-only discovery metadata for applicable project instruction-file candidates.
- `skills/team-core/references/code-comments.md` — shared code-comment writing, self-check and review contract.
- `skills/team-core/references/code-readability.md` — formatter-first code readability rules, bounded helper use, safe formatting boundaries, and writer self-check.
- `skills/team-core/references/formatter-tool.md` — portable installed-helper interface, formatter/configuration boundaries, caller authority, result codes and failure limits.
- `skills/team-core/references/role-routing.md` and `handoff-format.md` — named-role availability, explicit invocation evidence and final actual child-agent roster contracts.
- `skills/frontend-design/` — implementation-oriented interface design and rendered refinement Skill, distributed by the installer.
- `skills/team-core/references/ui-quality.md` — shared UI brief, page ownership and visual-verification contract.
- `skills/team-core/references/spec-lifecycle.md` and `openspec-integration.md` — optional specification lifecycle and pinned external CLI contract.
- `skills/team-core/scripts/openspec-*.ps1` and `spec-traceability.ps1` — optional CLI boundary, safe paths, input snapshots and evidence-link checks.
- `skills/team-core/templates/openspec/` — independently authored native-schema configuration, copied only on explicit project enablement.
- `config/` — an optional, manually merged Codex configuration fragment.
- `scripts/` — user-level validation, installation, and safe update helpers.
- `scripts/deploy-user.ps1` — self-contained versioned deployment/recovery manager; installed copies live outside Skill discovery paths.
- `docs/safe-deployment.md` — durable installation, stable snapshot, downgrade, recovery and retention guide.
- `docs/codex-install.md` — local Codex user installation and update steps, source checks, preview, and runtime-discovery limits.
- `tests/test-deployment.ps1` — isolated fake-home deployment and fault-injection suite; no actual installation.
- `tests/test-documentation.ps1` — isolated existing-project adoption and readiness/ambiguity regression tests.
- `tests/` — isolated package, installation, feedback, AI-simulation, stage-verification and project-blueprint tests.
- `tests/fixtures/` — controlled CLI doubles for transport and partial-failure regression tests; never production runtimes.
- `docs/verification/active/` — implementation verification records awaiting maintainer review; not automated manual acceptance.
- `docs/verification/active/role-invocation.md` — role-routing regression evidence, actual invocation roster and pending human checks for the bounded workflow correction.
- `docs/verification/active/coverage-sync.md` — manual-to-E2E/other-layer synchronization contract evidence, isolated regressions and pending real-workflow acceptance.
- `docs/verification/active/small-task-routing.md` — minimal named-team routing, Lead-only exception and complete-workflow evidence; isolated regressions and pending runtime acceptance.
- `docs/verification/active/ai-simulation.md` — bounded simulation helper and routing evidence, isolated regressions and pending real Codex actor/manual acceptance.
- `docs/governance/` — local documentation-adoption metadata, navigation index and scoped review runtime state, when initialized. The Kit keeps `documentation.json`, `doc-index.md` and the entire `reviews/` subtree on disk but outside Git; user-authored governance documents elsewhere remain versionable. A fresh checkout establishes its own adoption/review state from available documents. See `skills/team-core/references/generated-artifacts.md` for exact protection boundaries.
- `docs/PRD/` — product requirements when needed; do not create an empty folder merely for template completeness.
- `docs/legacy/` — confirmed superseded project documentation, preserving replacement/reason and references; no automatic age-based moves.
- `docs/` — architecture, source-attribution notes, technical use guides, and approved system-design specifications.
- `docs/ai-simulation.md` — target-project local simulation workflow, evidence limits and engineering handoff guide.
- `docs/formatter-tool.md` — repository-facing navigation and verification-maintenance notes for the installed formatter tool; the portable Skill reference is normative.
- `docs/superpowers/specs/` — local dated architectural designs; retained on disk but ignored by Git and absent from fresh clones.
- `docs/superpowers/plans/` — local dated implementation plans; retained on disk but ignored by Git and absent from fresh clones.
- `docs/release-versioning.md` — release-numbering policy for maintainers.
- `scripts/validate-docs.ps1` — repository-only structural checks for the English/Simplified Chinese public documentation pairs; separate from package validation and installation.
- `tests/test-bilingual-docs.ps1` — isolated regression tests for paired public-document structure, technical-value drift and read-only behavior.
- `backlog/` — local confirmed engineering improvements deferred for later work; retained on disk but ignored by Git and absent from fresh clones.
- `_work/` — repository-local task inputs, logs, temporary runners, scenarios and generated intermediates; retained on disk, ignored by Git and absent from fresh clones.
- `CHANGELOG.md` — public release history for this distributable kit.
- `CHANGELOG.zh-CN.md` — complete Simplified Chinese release history paired with `CHANGELOG.md`.
- `README.md` and `README.zh-CN.md` — default English and Simplified Chinese public entrypoints.
- `VERSION` — the distributable kit version recorded by the installer.

## Conventions

Keep this repository as the source of truth. Do not edit installed copies under a user's home directory; change this repository and rerun the installer. Do not add a general-purpose agent, connector, hook, or background service without a concrete workflow need.

Keep `backlog/` and `docs/superpowers/` local only. Do not force-add their contents or link required public setup/runtime instructions to them. Removing existing entries from Git tracking preserves local files; the deletion reaches the remote branch after commit and push, without erasing historical commits. Shared authoritative requirements and reusable workflow contracts belong in versioned locations outside these local-only directories.

Keep task work under one explicitly owned `_work/<task>/` subtree. Reusable tests, helper source and authoritative documents belong in `tests/`, `scripts/` or `docs/`, as appropriate. The root `/_work/` ignore policy preserves local files; it does not delete them, remove tracked files from the index, grant ownership of sibling tasks, or authorize cleanup.

## Archive policy

System-owned documentation-governance reviews, including local history under `docs/governance/reviews/archive/`, remain in place as local runtime state; Git ignore rules do not delete or move them. For other authorized artifact lifecycle work, move clearly superseded generated artifacts to `待删除/<date>_<reason>/` reversibly and preserve source, installed configuration, and user-created project files.
