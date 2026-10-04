# Folder structure

## Purpose

`codex_multi_agent` is the editable source repository for a user-level, Codex-only multi-agent development toolkit.

## Active deliverable

The toolkit source is the current editable master. `scripts/install-user.ps1` validates current source and delegates installation to `scripts/deploy-user.ps1`, which also manages explicit downgrade and recovery.

## Directory map

- `agents/` — native Codex custom-agent TOML files.
- `agents/team-docs-maintainer.toml` — Luna/high documentation specialist; bounded assigned-doc maintenance and evidence-backed findings.
- `skills/` — reusable Codex Skills. Most `team-*` Skills are explicit workflow entrypoints; `team-project-rules` also routes from task-time evidence checks in `$team-plan`/`$team-dev`. `team-core` bundles their shared policy references for installation.
- `skills/team-doc-check/` — documentation readiness/adoption entrypoint; distributed Skill source, not repository discovery configuration.
- `skills/team-project-rules/` — entrypoint for reviewing, drafting and maintaining target-project `AGENTS.md` files.
- `skills/team-core/references/documentation-governance.md` — task-scoped sufficiency, PRD authority, ambiguity and legacy contract with runtime schema.
- `skills/team-core/references/project-rules.md` — target-project instruction-file authority, candidate discovery, approval and maintenance contract.
- `skills/team-core/scripts/documentation.ps1` — local document inventory, adoption, scoped review and stale-evidence detector.
- `skills/team-core/scripts/generated-artifacts.ps1` — narrow profile-based local artifact protection and read-only Git-index checks; see `skills/team-core/references/generated-artifacts.md`.
- `skills/team-core/references/generated-artifacts.md` — artifact profiles, durable evidence boundaries, result schema, conflict handling and caller lifecycle.
- `skills/team-core/scripts/project-rules.ps1` — read-only discovery metadata for applicable project instruction-file candidates.
- `skills/team-core/references/code-comments.md` — shared code-comment writing, self-check and review contract.
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
- `tests/test-deployment.ps1` — isolated fake-home deployment and fault-injection suite; no actual installation.
- `tests/test-documentation.ps1` — isolated existing-project adoption and readiness/ambiguity regression tests.
- `tests/` — isolated package, installation, feedback, stage-verification and project-blueprint tests.
- `tests/fixtures/` — controlled CLI doubles for transport and partial-failure regression tests; never production runtimes.
- `docs/verification/active/` — implementation verification records awaiting maintainer review; not automated manual acceptance.
- `docs/verification/active/role-invocation.md` — role-routing regression evidence, actual invocation roster and pending human checks for the bounded workflow correction.
- `docs/verification/active/coverage-sync.md` — manual-to-E2E/other-layer synchronization contract evidence, isolated regressions and pending real-workflow acceptance.
- `docs/verification/active/small-task-routing.md` — minimal named-team routing, Lead-only exception and complete-workflow evidence; isolated regressions and pending runtime acceptance.
- `docs/governance/` — local documentation-adoption metadata, navigation index and scoped review runtime state, when initialized. The Kit keeps `documentation.json`, `doc-index.md` and the entire `reviews/` subtree on disk but outside Git; user-authored governance documents elsewhere remain versionable. A fresh checkout establishes its own adoption/review state from available documents. See `skills/team-core/references/generated-artifacts.md` for exact protection boundaries.
- `docs/PRD/` — product requirements when needed; do not create an empty folder merely for template completeness.
- `docs/legacy/` — confirmed superseded project documentation, preserving replacement/reason and references; no automatic age-based moves.
- `docs/` — architecture, source-attribution notes, and approved system-design specifications.
- `docs/superpowers/specs/` — dated, approved architectural designs that await an implementation plan.
- `docs/superpowers/plans/` — dated, approved implementation plans for architectural designs.
- `docs/release-versioning.md` — release-numbering policy for maintainers.
- `scripts/validate-docs.ps1` — repository-only structural checks for the English/Simplified Chinese public documentation pairs; separate from package validation and installation.
- `tests/test-bilingual-docs.ps1` — isolated regression tests for paired public-document structure, technical-value drift and read-only behavior.
- `backlog/` — Confirmed engineering improvements deferred for later work.
- `CHANGELOG.md` — public release history for this distributable kit.
- `CHANGELOG.zh-CN.md` — complete Simplified Chinese release history paired with `CHANGELOG.md`.
- `README.md` and `README.zh-CN.md` — default English and Simplified Chinese public entrypoints.
- `VERSION` — the distributable kit version recorded by the installer.

## Conventions

Keep this repository as the source of truth. Do not edit installed copies under a user's home directory; change this repository and rerun the installer. Do not add a general-purpose agent, connector, hook, or background service without a concrete workflow need.

## Archive policy

System-owned documentation-governance reviews, including local history under `docs/governance/reviews/archive/`, remain in place as local runtime state; Git ignore rules do not delete or move them. For other authorized artifact lifecycle work, move clearly superseded generated artifacts to `待删除/<date>_<reason>/` reversibly and preserve source, installed configuration, and user-created project files.
