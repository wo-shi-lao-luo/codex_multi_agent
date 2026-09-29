# Folder structure

## Purpose

`codex_multi_agent` is the editable source repository for a user-level, Codex-only multi-agent development toolkit.

## Active deliverable

The toolkit source is the current editable master. `scripts/install-user.ps1` validates current source and delegates installation to `scripts/deploy-user.ps1`, which also manages explicit downgrade and recovery.

## Directory map

- `agents/` — native Codex custom-agent TOML files.
- `skills/` — reusable Codex Skills. `team-*` skills are explicit workflow entrypoints; `team-core` bundles their shared policy references for installation.
- `skills/team-core/references/code-comments.md` — shared code-comment writing, self-check and review contract.
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
- `tests/` — isolated package, installation, feedback, stage-verification and project-blueprint tests.
- `tests/fixtures/` — controlled CLI doubles for transport and partial-failure regression tests; never production runtimes.
- `docs/verification/active/` — implementation verification records awaiting maintainer review; not automated manual acceptance.
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
