# Install the Kit for Codex

This guide installs the Codex Multi-Agent Kit for the user account on the machine running PowerShell. It covers initial installation and updates from a selected local checkout. Bootstrapping does not require the Kit to be installed first or a Kit workflow role to be available. Use [safe deployment](safe-deployment.md) for conflict recovery, stable snapshots, downgrade, or direct deployment from a locally available Git commit or tag.

## Before you start

- Use PowerShell 7. A local directory or working-tree source can be deployed without Git; Git is required for `-GitRef`, and source commit provenance is recorded when available. Do not install missing tools automatically. The installer scripts are run from the Kit source checkout; an already-installed Kit is not required.
- Run the commands on the machine and under the user account where the agents and Skills should be installed. A repository open on another computer or a remote Codex executor does not install files on your local computer.
- If the user provides only the repository URL, first inspect its README and installation guide through an available repository or browser view. If those sources cannot be read, obtain the repository before acting; do not install from snippets. Then use the local executor on the target machine. A remote or cloud executor cannot write to the user's local Codex homes.
- If no local checkout is available, ask the user to confirm a safe, new, empty clone destination before acquiring the source. Never clone over or replace a non-empty directory. After checkout, read the selected revision's local `AGENTS.md` and `docs/codex-install.md` before running any commands. If the destination or source is uncertain, stop and resolve it first.
- Select the exact checkout you intend to use. Do not assume that the default branch is the newest or a stable release. The repository `VERSION` file identifies the package version, not a guarantee that a branch or commit is stable.
- If the checkout is a Git repository, inspect the selected commit and whether the working tree has local changes. Do not deploy an unexpected or unreviewed checkout. An install from a working tree can include its local edits.
- The manager does not fetch a ref or switch your checkout. For an exact Git-ref deployment, follow the separate procedure in [safe deployment](safe-deployment.md).

The full `install-user.ps1` and `update-user.ps1` entrypoints also establish the optional Task Board runtime. They reuse Node.js only when its version is `>=26.13.0` and `<27` and its actual built-in SQLite version is `>=3.54.0`; otherwise they provision the pinned Node.js `26.13.0` into a private, versioned directory under the selected Agents home. The official archive digest is verified before extraction; only the Node executable and its `LICENSE` are retained. This does not change `PATH` or install global npm packages. The Task Board is unnecessary for ordinary questions, brief explanations and standalone read-only consultation/review; authorized execution tasks use its visibility checkpoint by default, subject to user opt-out and prerequisite availability. Windows x64 is the only verified platform for this runtime path; other platforms remain unverified.

Full installation accepts `-SourceRoot`, `-GitRef`, `-RuntimeArchivePath`, and `-Offline` in addition to the deployment options. A selected Git ref is resolved and digest-checked. Existing Node is reused only when found on the inherited `PATH` and both version/SQLite checks pass; otherwise `-RuntimeArchivePath` supplies the exact platform archive for offline provisioning, while `-Offline` forbids network acquisition. No custom executable pointer is persisted. `-WhatIf` is read-only and does not download or provision a runtime. Inspect current command help for exact parameter sets.

Check the PowerShell version and the source you selected:

```powershell
$PSVersionTable.PSVersion
git --version
```

After the user confirms the destination, substitute the trusted URL and confirmed new empty directory:

```powershell
git clone <trusted-repository-url> <new-empty-directory>
Set-Location <new-empty-directory>
```

For an existing checkout, change to its root directory. Run all remaining commands from the root of the selected Kit checkout.

Then inspect the selected source:

```powershell
Get-Content .\VERSION
git rev-parse HEAD
git status --short
```

Run the Git commands from the selected repository when it is a Git checkout. A local directory or working-tree deployment can proceed without Git; when Git metadata is unavailable, commit/ref provenance is simply unavailable. Git is required to select `-GitRef`; if that requested ref cannot be resolved and verified, stop before deployment.

## Preview and install

For a combined commit, push and install request, finish the authorized commit and
publication first and confirm the final remote commit. Then preview and install
that exact source once. Reuse matching review and test evidence under the
[delivery contract](../skills/team-core/references/git-delivery.md#bounded-combined-delivery);
refresh only affected evidence and the operation's current source/target checks.
An installation-only request may still use its explicitly selected local source;
it does not require publication or authorize Git actions.

Validate the selected source first:

```powershell
.\scripts\validate.ps1
```

For a first installation, preview the installer:

```powershell
.\scripts\install-user.ps1 -WhatIf
```

For an existing installation, first inspect its status and integrity, then preview the update:

```powershell
.\scripts\deploy-user.ps1 -Action Status
.\scripts\deploy-user.ps1 -Action Verify
.\scripts\update-user.ps1 -WhatIf
```

Review the preview's planned add, replace, and remove operations, target homes, source provenance, package digest, and confirmation message. Compare the reported source commit/provenance with the intended checkout, and compare its `VERSION` separately because the package version is not a commit identity. `Verify` checks the installed payload against its receipt; a successful check of an older installation does not prove that the selected checkout has been installed. After deployment, compare the receipt provenance reported by `Status` with the source you selected.

Run the matching command without `-WhatIf` only when the user has explicitly requested installation or update and the preview matches the intended source and target. If source validation, preview, or verification reports a failure or unexpected result, stop and resolve it before continuing; do not treat a failed check as a pass:

```powershell
.\scripts\install-user.ps1
# or, for an existing installation:
.\scripts\update-user.ps1
```

After a successful actual installation or update, the Kit displays a brief optional Impeccable reminder linking to its [getting-started guide](https://impeccable.style/tutorials/getting-started/). Impeccable is not an installation prerequisite and the Kit does not detect, download, or install it; the reminder is not shown for a preview or failed deployment. If you install it separately, use its accessible guidance for relevant design/UI work unless the user opts out. See the Kit's [usage guide](../skills/team-core/references/impeccable-usage.md), [adapter](../skills/team-core/references/impeccable-integration.md), and [official repository](https://github.com/pbakaus/impeccable).

Do not add `-Force` to get past a conflict. Stop, inspect the named destination and ownership, and choose a documented recovery path. `-Force` backs up and replaces the selected managed unit; it is a separate, consequential choice. Do not run recovery or pruning automatically. See [safe deployment](safe-deployment.md) for conflict resolution, backup retention, interruption recovery, and rollback.

The deployment manager installs receipt-owned agents and complete Skill directories in the current user's Codex homes (by default `~/.codex/agents` and `~/.agents/skills`). The full install/update wrapper additionally reuses or provisions the pinned private Node.js runtime required by the installed Task Board launcher; the lower-level payload-only `deploy-user.ps1` remains offline and does not acquire dependencies. Neither flow changes global `PATH`, installs global npm packages, merges or rewrites global Codex configuration, or changes the source checkout. If you use custom homes, pass the same explicit home options to status, verification, preview, and deployment commands; see [safe deployment](safe-deployment.md). Configuration fragments in `config/` are optional and must be handled separately by the user.

## Check discovery and report

After deployment, check the installed receipt/payload and the actual Task Board launcher health:

```powershell
.\scripts\deploy-user.ps1 -Action Status
.\scripts\deploy-user.ps1 -Action Verify
$launcher = Join-Path $HOME '.agents/skills/team-core/scripts/task-board.ps1'
& $launcher -BoardArguments @('runtime-doctor')
```

Full installation is complete only when receipt Verify succeeds and launcher doctor reports `available: true`. If either check fails or is unexpected, treat the operation as unsuccessful even if payload files were committed; inspect the status and follow [safe deployment](safe-deployment.md) to restore a verified snapshot or repair. Compare version and source provenance with the selected checkout. Keep receipts private: status and backup metadata can contain local paths or machine-specific details.

Open a fresh Codex conversation or restart the client if a newly installed Skill does not appear. Files on disk do not prove that the active client loaded a Skill or agent. See OpenAI's [Skills discovery guidance](https://learn.chatgpt.com/docs/build-skills) and [subagent guidance](https://learn.chatgpt.com/docs/agent-configuration/subagents) for their current discovery behavior. A packaged agent name or model assignment is not proof that the target account has that role or model available. If you want to check a named role or model, check availability in the target account/client separately; this optional check does not require the Kit to be installed first.

When handing back the result, summarize the package version, selected source/ref and whether it had local changes, the checks run, whether a backup was created, and any remaining discovery or availability gap. Do not paste raw receipts, backup contents, or personal machine paths into public notes.
