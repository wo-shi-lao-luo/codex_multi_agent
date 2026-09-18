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
.\tests\test-install-user.ps1
.\tests\test-feedback-runtime.ps1
```

These tests run only in unique system-temporary directories. They verify invalid metadata and missing local references, the complete package and update behavior, and the feedback runtime's validation, aggregation, archive, deletion-confirmation, and cleanup behavior; each directory is removed before its test exits.

The installer copies agents to `~/.codex/agents` and Skills (including the internal `team-core` policy bundle and feedback runtime) to `~/.agents/skills`. It does not overwrite `~/.codex/config.toml`. If you want the recommended three-subagent cap, merge [`config/recommended-config.toml`](config/recommended-config.toml) into that file once.

The installer validates the kit before writing. Use `-WhatIf` to preview its actions. It stops on an existing file or Skill directory unless it is an unchanged installation recorded by the kit; use `-Force` only when you want conflicting destinations backed up and replaced. The installation receipt and backups are stored under `~/.agents/codex-multi-agent/` by default.

Agent names use the `team-` prefix to avoid collisions with personal agents. If an earlier kit version installed generic names such as `architect.toml`, they are left untouched; remove them manually only after confirming the `team-*` agents work for you.

Current release: `0.3.0`. Explicit `team-*` workflows now write a small, redacted local acceptance record through `team-core`; these records never enter the business repository. See [feedback recording](skills/team-core/references/feedback-recording.md) and the [changelog](CHANGELOG.md). Version 0.1.0 also renamed `sql-safety` to `database-engineering` and `test-strategy` to `testing-engineering`. Earlier installed Skill directories are left untouched; remove them manually only after confirming the renamed Skills work for you.

Restart Codex if a newly installed Skill is not immediately visible.

## Operating rules

- The Lead starts at most three child threads at once.
- One owner writes production code by default. The Lead uses worktrees only after assigning non-overlapping files or modules.
- Read-heavy exploration, tests, and reviews are safe to parallelize; shared-contract changes are planned before any writer starts.
- A role reports findings, touched files, verification, and blockers back to the Lead. Only the Lead claims completion.

See [architecture](docs/architecture.md), [role routing](skills/team-core/references/role-routing.md), and [source notes](docs/upstreams.md).
