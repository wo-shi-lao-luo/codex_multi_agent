# Folder structure

## Purpose

`codex_multi_agent` is the editable source repository for a user-level, Codex-only multi-agent development toolkit.

## Active deliverable

The toolkit source is the current editable master. `scripts/install-user.ps1` validates current source and delegates installation to `scripts/deploy-user.ps1`, which also manages explicit downgrade and recovery.

## Directory map

- `agents/` — native Codex custom-agent TOML files.
- `agents/team-docs-maintainer.toml` — Luna/high documentation specialist; bounded assigned-doc maintenance and evidence-backed findings.
- `skills/` — reusable Codex Skills. `team-*` skills are explicit workflow entrypoints; `team-core` bundles their shared policy references for installation.
- `skills/team-doc-check/` — documentation readiness/adoption entrypoint; distributed Skill source, not repository discovery configuration.
- `skills/team-core/references/documentation-governance.md` — task-scoped sufficiency, PRD authority, ambiguity and legacy contract with runtime schema.
- `skills/team-core/scripts/documentation.ps1` — local document inventory, adoption, scoped review and stale-evidence detector.
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
- `docs/governance/` — this project's documentation adoption marker, index and current scoped reviews, when initialized. Historical system-owned review records stay under `reviews/archive/`.
- `docs/PRD/` — product requirements when needed; do not create an empty folder merely for template completeness.
- `docs/legacy/` — confirmed superseded project documentation, preserving replacement/reason and references; no automatic age-based moves.
- `docs/` — architecture, source-attribution notes, and approved system-design specifications.
- `docs/superpowers/specs/` — dated, approved architectural designs that await an implementation plan.
- `docs/superpowers/plans/` — dated, approved implementation plans for architectural designs.
- `docs/release-versioning.md` — release-numbering policy for maintainers.
- `backlog/` — Confirmed engineering improvements deferred for later work.
- `CHANGELOG.md` — public release history for this distributable kit.
- `VERSION` — the distributable kit version recorded by the installer.

## Conventions

Keep this repository as the source of truth. Do not edit installed copies under a user's home directory; change this repository and rerun the installer. Do not add a general-purpose agent, connector, hook, or background service without a concrete workflow need.

## Archive policy

No archive exists yet. Move superseded generated artifacts to `待删除/<date>_<reason>/`; preserve source, installed configuration, and user-created project files.
