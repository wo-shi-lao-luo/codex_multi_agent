# Safe installation, downgrade and recovery

## Scope and safety contract

PowerShell 7 is required. `scripts/install-user.ps1` validates current source and calls `scripts/deploy-user.ps1`; `scripts/update-user.ps1` retains its existing entrypoint. The same manager handles installation, upgrade, downgrade and snapshot restoration. It never runs an old version's installer or validator, downloads packages, rewrites Git history, changes the worktree, or changes global Codex configuration.

The exact target is defined by an inventory of agent TOMLs and complete Skill directories. Before a deploy, the manager compares current receipt ownership with the target. It adds/replaces target units and removes retired receipt-owned units. New-only files inside retained Skills disappear as well. Personal agents/Skills outside those units are preserved. Unknown or changed content inside a selected unit is a conflict; `-Force` explicitly backs up and replaces the entire selected unit, not arbitrary neighboring content.

There is no fallback from a corrupt receipt to assumed ownership. Legacy schema-v1 receipts are accepted only after validating their paths against the requested homes. Old untracked leftovers not represented in a receipt are not inferred from a `team-` prefix: report and resolve them separately. Exact-cleanliness guarantees apply to known managed payload, not unrelated project data or undocumented historical installs.

## Before trying an experimental version

Stop tasks using the Kit and do not edit installed files during deployment. Review the current install before explicitly marking it stable:

```powershell
./scripts/deploy-user.ps1 -Action Verify
./scripts/deploy-user.ps1 -Action MarkStable
./scripts/install-user.ps1 -WhatIf
./scripts/install-user.ps1
```

MarkStable snapshots the currently installed bytes; it does not install the source checkout. It can bootstrap the recovery manager for a valid legacy installation before any experimental upgrade. A successful install/test does not automatically move the stable pointer. Stable means maintainer-selected here, not a claim of formal product release.

`-CodexHome` and `-AgentsHome` select non-overlapping homes. Tests always supply temporary fake homes. The examples omit these options for intentional real installation only; do not run them merely to test a script.

## Roll back without changing Git checkout

```powershell
# Default Restore selects the explicitly marked stable snapshot, entirely offline.
./scripts/deploy-user.ps1 -Action Restore -WhatIf
./scripts/deploy-user.ps1 -Action Restore

# Alternatively select a locally available trusted tag or commit; no fetch or checkout occurs.
./scripts/deploy-user.ps1 -Action Deploy -SourceRoot . -GitRef <tag-or-commit> -WhatIf
./scripts/deploy-user.ps1 -Action Deploy -SourceRoot . -GitRef <tag-or-commit>
```

Git targets are resolved to a commit and exported to a disposable directory, with unsafe archive entries rejected. Source code is treated as package data; its scripts are not executed. This preserves the active branch and uncommitted changes. A direct `-SourceRoot` deployment includes working-tree edits and records that provenance. For reproducible rollback prefer a commit or verified snapshot.

The installed entrypoint is `~/.agents/codex-multi-agent/rollback.ps1`. It validates a content-addressed manager copy outside Skill/agent discovery paths. Invoke that entrypoint with the same action/arguments after switching the repository to an older commit, or when the checkout is unavailable. The recovery engine is not downgraded with the Kit; newer management protocols must be handled deliberately, not overwritten by old payloads. Existing copies are retained for recovery rather than silently deleted.

## What survives a rollback

| Content | Treatment |
| --- | --- |
| Managed agents, Skills, scripts and templates | Exact target file/directory inventory and hashes; new-only payload removed |
| Personal global config and unrelated agents/Skills | Not modified |
| Target-project code, OpenSpec specs, stage packets and decisions | Not modified; reverting project work is a separate authorized operation |
| Feedback records and other runtime data | Preserved, never rolled back as code |
| External OpenSpec/npm installation | Not owned or uninstalled by this manager |
| Backups, manager runtime, receipts and operation logs | Kept outside discovery paths; not active new-version Kit features |

Packages default to runtime data schema 1. Future packages changing that contract must declare `runtimeDataSchema` in root `deployment.json`; downgrading to an older declared data schema is blocked. No automatic data migration is implemented. Legacy packages are treated as schema 1, not presumed compatible with unknown future data. The declaration is a maintenance contract, not automatic detection of every external data format.

## Transaction and recovery

The manager performs source/ownership checks, obtains an exclusive file lock, stages the target, saves a complete before-image, writes `pending.json`, applies all selected units, verifies the exact result, then atomically replaces the receipt and clears pending state. Metadata replacement is atomic within its directory; multi-directory payload replacement is recoverable, not globally atomic.

Failures during application trigger restoration of all selected units and the exact original receipt. If restoration fails or the process terminates, pending state blocks subsequent writes. Status can inspect the situation. Recover resumes restoration from the before-image:

```powershell
./scripts/deploy-user.ps1 -Action Status
./scripts/deploy-user.ps1 -Action Recover -WhatIf
./scripts/deploy-user.ps1 -Action Recover
./scripts/deploy-user.ps1 -Action Verify
```

Recover does not overwrite files changed outside the interrupted operation. A recovery conflict requires inspection and preservation of those files before retrying; Force is not a bypass for corrupted metadata or recovery conflicts. Keep snapshots and pending state until recovery is verified. On first-install rollback, the original absence of a receipt is restored. Lock files may remain as inactive coordination metadata; the exclusive OS handle, not the file's presence, determines whether an operation is running.

Stop external writers. The lock coordinates this manager only, not Codex sessions, antivirus, editors or legacy installers. After a file rollback, start a fresh task/restart the client before evaluating behavior: on-disk equality does not erase instructions already loaded in an existing conversation.

## Metadata and retention

Schema-v2 installation receipts record product version, installation ID, source commit/dirty state (or snapshot provenance), file hashes, exact directories, package digest, runtime data schema and manager protocol. Versions alone are not sufficient to identify an experimental package.

Backups live under `~/.agents/codex-multi-agent/backups/<snapshot-id>/`. Each contains original payload, manifest and original receipt text. They may contain local edits and machine-local paths; do not commit or publish them. Status lists snapshot IDs; Restore accepts an explicit `-SnapshotId` when stable is not desired.

No automatic pruning occurs during deployment. Preview and explicitly request pruning:

```powershell
./scripts/deploy-user.ps1 -Action Prune -KeepSnapshots 3 -WhatIf
./scripts/deploy-user.ps1 -Action Prune -KeepSnapshots 3 -ConfirmPrune
```

Prune preserves the selected stable snapshot and the newest requested number, refuses to run while a transaction is pending, and only removes recognized, valid manager snapshots. It does not delete legacy backups, manager copies or project data. Removed snapshots are not recoverable through this tool. An interrupted prune can leave a partially removed inactive snapshot; it never changes active payload or the protected stable snapshot.

## Verification

Run `tests/test-deployment.ps1` in PowerShell 7. It creates disposable source packages, fake homes and a local Git repository. It checks exact downgrade, personal-file preservation, Force backups, stable selection, standalone recovery, simulated failure/process exit, legacy receipts, malformed paths, data-schema blocking and pruning. It never uses real homes or network services. The existing installer test also runs exclusively in fake homes. See the active deployment verification record for current results and remaining manual review.
