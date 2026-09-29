# Codex Multi-Agent Kit

A small, user-level development team for Codex. It uses Codex native subagents and Skills; it does not require ECC, OMX, a task daemon, or another agent harness at runtime.

## Entry points

- `$team-dev <goal>` — plan, implement, test, review, and report a development task.
- `$team-plan <goal>` — produce a decision-ready plan without editing code.
- `$team-review <scope>` — review a branch, diff, or change set in parallel.
- `$team-debug <symptom>` — investigate an uncertain failure before changing code.

## Team

`team-explorer`, `team-architect`, `team-frontend-engineer`, `team-backend-engineer`, `team-database-specialist`, `team-tester`, and `team-reviewer` are Codex custom agents. The main Codex thread is the Lead and owns the task state, integration, and final answer.

## Model allocation

| Role | Model | Reasoning effort |
| --- | --- | --- |
| Architect | `gpt-6-astra` | high |
| Explorer | `gpt-6-luna` | medium |
| Frontend, Backend, Tester | `gpt-6-sol` | medium |
| Database specialist, Reviewer | `gpt-6-sol` | high |

For the Lead, select GPT-6 Astra / high in the main session. This is a recommendation, not an installed agent setting. The optional configuration fragment sets generic subagents to GPT-6 Sol / medium; named team roles retain their explicit profiles. Existing users who merged the old fragment must update its two `default_subagent_*` values explicitly; the installer does not merge global configuration.

These are workload choices, not measured quality guarantees. See the official [subagent model guidance](https://learn.chatgpt.com/docs/agent-configuration/subagents). Confirm availability in the target account/client before use.

The kit does not implement automatic model fallback. Keep previous model assignments in Git history as a manual recovery reference, not a second active profile. If a model is unavailable or shows a reproducible regression, first identify the cause and confirm a replacement is available; make an explicit, scoped configuration change with matching validator updates and verification. Do not silently switch models or assume a legacy model bypasses service outages or account limits.

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

Current release: `0.7.0`. Explicit `team-*` workflows write a small, redacted local acceptance record through `team-core`. `$team-dev` creates and validates Git-tracked stage verification packets in target projects, using `test-first` where practical and documented alternatives where it is not. See [feedback recording](skills/team-core/references/feedback-recording.md), [test and acceptance contract](skills/team-core/references/test-acceptance-contract.md), [TDD protocol](skills/team-core/references/tdd-protocol.md), [code comment contract](skills/team-core/references/code-comments.md), [versioning policy](docs/release-versioning.md), and the [changelog](CHANGELOG.md). Version 0.1.0 also renamed `sql-safety` to `database-engineering` and `test-strategy` to `testing-engineering`. Earlier installed Skill directories are left untouched; remove them manually only after confirming the renamed Skills work for you.

Visible UI work uses [frontend-design](skills/frontend-design/SKILL.md) alongside frontend-engineering. The [UI delivery contract](skills/team-core/references/ui-quality.md) preserves page-level goals through delegation and requires rendered inspection separate from functional tests. No extra design agent, model change or per-page design document is required. Missing browser evidence must be reported as visually unverified, not release-ready.

Restart Codex if a newly installed Skill is not immediately visible.

## Operating rules

### Optional OpenSpec integration (review preview)

The kit can optionally use OpenSpec **1.13.2** as an external specification manager while keeping its own Lead, TDD and acceptance flow. It is not installed or enabled by the kit installer. The adapter requires PowerShell 7 and upstream Node.js 20.19+; see [setup, supported profile and recovery](skills/team-core/references/openspec-integration.md). Existing projects without an opt-in marker are unchanged. Custom schemas/stores are not adapted in this first profile.

Run `tests/test-openspec.ps1` for isolated contract tests. Pass `-OpenSpecEntry <trusted-installation>/bin/openspec.js` to add the real pinned-CLI lifecycle; no dependency downloads occur in tests. This capability is versioned as 0.7.0; assigning a version does not mark it as maintainer-approved stable or update the local installation.


New applications, multi-stage initiatives and material structural changes use a [Project Blueprint](skills/team-core/references/project-blueprint.md). Discover an existing repository before documenting its modules and file responsibilities. Structural refactoring requires explicit user approval; if declined or deferred, preserve the current structure and record its constraints. Stage packets reference the blueprint revision, module IDs, file scope and entrypoint exceptions. Blueprint validation checks document structure; code review checks the actual architecture.

- The Lead starts at most three child threads at once.
- One owner writes production code by default. The Lead uses worktrees only after assigning non-overlapping files or modules.
- Read-heavy exploration, tests, and reviews are safe to parallelize; shared-contract changes are planned before any writer starts.
- A role reports findings, touched files, verification, and blockers back to the Lead. Only the Lead claims completion.

See [architecture](docs/architecture.md), [role routing](skills/team-core/references/role-routing.md), and [source notes](docs/upstreams.md).
