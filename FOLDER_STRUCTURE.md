# Folder structure

## Purpose

`codex_multi_agent` is the editable source repository for a user-level, Codex-only multi-agent development toolkit.

## Active deliverable

The toolkit source is the current editable master. It is installed into a user's Codex directories only by `scripts/install-user.ps1`.

## Directory map

- `agents/` — native Codex custom-agent TOML files.
- `skills/` — reusable Codex Skills. `team-*` skills are explicit workflow entrypoints; `team-core` bundles their shared policy references for installation.
- `config/` — an optional, manually merged Codex configuration fragment.
- `scripts/` — user-level validation, installation, and safe update helpers.
- `tests/` — isolated package, installation, feedback, stage-verification and project-blueprint tests.
- `docs/` — architecture, source-attribution notes, and approved system-design specifications.
- `docs/superpowers/specs/` — dated, approved architectural designs that await an implementation plan.
- `docs/superpowers/plans/` — dated, approved implementation plans for architectural designs.
- `docs/release-versioning.md` — release-numbering policy for maintainers.
- `docs/existing-project-handoff.md` — installed-resource reading index for agents working in existing projects.
- `backlog/` — Confirmed engineering improvements deferred for later work.
- `CHANGELOG.md` — public release history for this distributable kit.
- `VERSION` — the distributable kit version recorded by the installer.

## Conventions

Keep this repository as the source of truth. Do not edit installed copies under a user's home directory; change this repository and rerun the installer. Do not add a general-purpose agent, connector, hook, or background service without a concrete workflow need.

## Archive policy

No archive exists yet. Move superseded generated artifacts to `待删除/<date>_<reason>/`; preserve source, installed configuration, and user-created project files.
