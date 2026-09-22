# Codex Multi-Agent Kit

A small, user-level development team for Codex. It uses Codex native subagents and Skills; it does not require ECC, OMX, a task daemon, or another agent harness at runtime.

## Entry points

- `$team-dev <goal>` — plan, implement, test, review, and report a development task.
- `$team-plan <goal>` — produce a decision-ready plan without editing code.
- `$team-review <scope>` — review a branch, diff, or change set in parallel.
- `$team-debug <symptom>` — investigate an uncertain failure before changing code.

## Team

`team-explorer`, `team-architect`, `team-frontend-engineer`, `team-backend-engineer`, `team-database-specialist`, `team-tester`, and `team-reviewer` are Codex custom agents. The main Codex thread is the Lead and owns the task state, integration, and final answer.

## Install for one user

Run PowerShell from this repository:

```powershell
.\scripts\validate.ps1
.\scripts\install-user.ps1
```

To safely update an existing installation after pulling a newer kit version, run:

```powershell
.\scripts\update-user.ps1
```

`update-user.ps1` uses the same receipt, `-WhatIf`, conflict protection, and `-Force` backup behavior as the installer. It does not modify `~/.codex/config.toml`.

To verify the distributable package without touching your actual Codex or Skills directories, run:

```powershell
.\tests\test-validate.ps1
.\tests\test-stage-verification.ps1
.\tests\test-project-blueprint.ps1
.\tests\test-install-user.ps1
.\tests\test-feedback-runtime.ps1
```

These tests run only in unique system-temporary directories. They verify invalid metadata and missing local references, TDD stage-packet initialization and safe state transitions, the complete package and update behavior, and the feedback runtime's validation, aggregation, archive, deletion-confirmation, and cleanup behavior; each directory is removed before its test exits.

The installer copies agents to `~/.codex/agents` and Skills (including the internal `team-core` policy bundle and feedback runtime) to `~/.agents/skills`. It does not overwrite `~/.codex/config.toml`. If you want the recommended three-subagent cap, merge [`config/recommended-config.toml`](config/recommended-config.toml) into that file once.

The installer validates the kit before writing. Use `-WhatIf` to preview its actions. It stops on an existing file or Skill directory unless it is an unchanged installation recorded by the kit; use `-Force` only when you want conflicting destinations backed up and replaced. The installation receipt and backups are stored under `~/.agents/codex-multi-agent/` by default.

Agent names use the `team-` prefix to avoid collisions with personal agents. If an earlier kit version installed generic names such as `architect.toml`, they are left untouched; remove them manually only after confirming the `team-*` agents work for you.

Current release: `0.6.0`. Explicit `team-*` workflows write a small, redacted local acceptance record through `team-core`. `$team-dev` creates and validates Git-tracked stage verification packets in target projects, using `test-first` where practical and documented alternatives where it is not. See [feedback recording](skills/team-core/references/feedback-recording.md), [test and acceptance contract](skills/team-core/references/test-acceptance-contract.md), [TDD protocol](skills/team-core/references/tdd-protocol.md), [code comment contract](skills/team-core/references/code-comments.md), [versioning policy](docs/release-versioning.md), and the [changelog](CHANGELOG.md). Version 0.1.0 also renamed `sql-safety` to `database-engineering` and `test-strategy` to `testing-engineering`. Earlier installed Skill directories are left untouched; remove them manually only after confirming the renamed Skills work for you.

Visible UI work uses [frontend-design](skills/frontend-design/SKILL.md) alongside frontend-engineering. The [UI delivery contract](skills/team-core/references/ui-quality.md) preserves page-level goals through delegation and requires rendered inspection separate from functional tests. No extra design agent, model change or per-page design document is required. Missing browser evidence must be reported as visually unverified, not release-ready.

Restart Codex if a newly installed Skill is not immediately visible.

## Operating rules


New applications, multi-stage initiatives and material structural changes use a [Project Blueprint](skills/team-core/references/project-blueprint.md). Discover an existing repository before documenting its modules and file responsibilities. Structural refactoring requires explicit user approval; if declined or deferred, preserve the current structure and record its constraints. Stage packets reference the blueprint revision, module IDs, file scope and entrypoint exceptions. Blueprint validation checks document structure; code review checks the actual architecture.

- The Lead starts at most three child threads at once.
- One owner writes production code by default. The Lead uses worktrees only after assigning non-overlapping files or modules.
- Read-heavy exploration, tests, and reviews are safe to parallelize; shared-contract changes are planned before any writer starts.
- A role reports findings, touched files, verification, and blockers back to the Lead. Only the Lead claims completion.

See [architecture](docs/architecture.md), [role routing](skills/team-core/references/role-routing.md), and [source notes](docs/upstreams.md).
