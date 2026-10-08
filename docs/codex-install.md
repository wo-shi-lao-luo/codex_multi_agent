# Install the Kit for Codex

This guide installs the Codex Multi-Agent Kit for the user account on the machine running PowerShell. It covers initial installation and updates from a selected local checkout. Bootstrapping does not require the Kit to be installed first or a Kit workflow role to be available. Use [safe deployment](safe-deployment.md) for conflict recovery, stable snapshots, downgrade, or direct deployment from a locally available Git commit or tag.

## Before you start

- Use PowerShell 7 and Git. The deployment manager requires Git even when the source is a working-tree directory. Do not install missing tools automatically. The installer scripts are run from the Kit source checkout; an already-installed Kit is not required.
- Run the commands on the machine and under the user account where the agents and Skills should be installed. A repository open on another computer or a remote Codex executor does not install files on your local computer.
- If the user provides only the repository URL, first inspect its README and installation guide through an available repository or browser view. If those sources cannot be read, obtain the repository before acting; do not install from snippets. Then use the local executor on the target machine. A remote or cloud executor cannot write to the user's local Codex homes.
- If no local checkout is available, ask the user to confirm a safe, new, empty clone destination before acquiring the source. Never clone over or replace a non-empty directory. After checkout, read the selected revision's local `AGENTS.md` and `docs/codex-install.md` before running any commands. If the destination or source is uncertain, stop and resolve it first.
- Select the exact checkout you intend to use. Do not assume that the default branch is the newest or a stable release. The repository `VERSION` file identifies the package version, not a guarantee that a branch or commit is stable.
- If the checkout is a Git repository, inspect the selected commit and whether the working tree has local changes. Do not deploy an unexpected or unreviewed checkout. An install from a working tree can include its local edits.
- The manager does not fetch a ref or switch your checkout. For an exact Git-ref deployment, follow the separate procedure in [safe deployment](safe-deployment.md).

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

Run the Git commands from the selected repository. If the selected source is not a Git checkout, the manager may report no commit identity; do not invent one. If Git is unavailable, the source, version, ref, or local changes are unexpected, stop and resolve that before deployment.

## Preview and install

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

Review the preview's planned add, replace, and remove operations, the default or explicitly selected target homes, and the manager's confirmation message. The preview does not report the source version or Git provenance: compare the selected source's `VERSION`, commit (when available), and dirty state separately before deployment. `Verify` checks the installed payload against its receipt; a successful check of an older installation does not prove that the selected checkout has been installed. After deployment, compare the receipt provenance reported by `Status` with the source you selected.

Run the matching command without `-WhatIf` only when the user has explicitly requested installation or update and the preview matches the intended source and target. If source validation, preview, or verification reports a failure or unexpected result, stop and resolve it before continuing; do not treat a failed check as a pass:

```powershell
.\scripts\install-user.ps1
# or, for an existing installation:
.\scripts\update-user.ps1
```

Do not add `-Force` to get past a conflict. Stop, inspect the named destination and ownership, and choose a documented recovery path. `-Force` backs up and replaces the selected managed unit; it is a separate, consequential choice. Do not run recovery or pruning automatically. See [safe deployment](safe-deployment.md) for conflict resolution, backup retention, interruption recovery, and rollback.

The manager installs receipt-owned agents and complete Skill directories in the current user's Codex homes (by default `~/.codex/agents` and `~/.agents/skills`). If you use custom homes, pass the same explicit home options to status, verification, preview, and deployment commands; see [safe deployment](safe-deployment.md). It does not merge or rewrite global Codex configuration, install tools or dependencies, or change the source checkout. Configuration fragments in `config/` are optional and must be handled separately by the user.

## Check discovery and report

After deployment, check the installed receipt and payload:

```powershell
.\scripts\deploy-user.ps1 -Action Status
.\scripts\deploy-user.ps1 -Action Verify
```

If either command reports a failure or an unexpected result, stop and resolve it before treating the installation as complete. Compare the reported version and source provenance with the checkout you selected. Keep the receipt private: status output and backup metadata can contain local paths or other machine-specific details.

Open a fresh Codex conversation or restart the client if a newly installed Skill does not appear. Files on disk do not prove that the active client loaded a Skill or agent. See OpenAI's [Skills discovery guidance](https://learn.chatgpt.com/docs/build-skills) and [subagent guidance](https://learn.chatgpt.com/docs/agent-configuration/subagents) for their current discovery behavior. A packaged agent name or model assignment is not proof that the target account has that role or model available. If you want to check a named role or model, check availability in the target account/client separately; this optional check does not require the Kit to be installed first.

When handing back the result, summarize the package version, selected source/ref and whether it had local changes, the checks run, whether a backup was created, and any remaining discovery or availability gap. Do not paste raw receipts, backup contents, or personal machine paths into public notes.
