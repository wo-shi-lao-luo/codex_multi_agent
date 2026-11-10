# macOS and Linux setup

The setup entrypoint checks prerequisites, installs the kit, and verifies client Skill discovery on macOS and Linux, targeting ARM64 and x64. It uses the existing PowerShell deployment manager. This release does not provide a native application or DMG installer. Historical platform coverage and remaining limits are summarized in the [platform matrix](platform-support.md#platform-matrix-and-evidence).

## Prepare existing runtimes

The setup commands require PowerShell 7 and a compatible native Codex CLI. If Codex was installed through npm, its required Node.js runtime must also be available on `PATH`, including the Homebrew or nvm directory when applicable. The shell wrapper reports the operating system and architecture and looks for `pwsh`; PowerShell then checks the selected Codex client. Python and a virtual machine are not required for user setup.

If a runtime is missing, follow its official installation instructions using the user's approved network route:

- [PowerShell on macOS](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-macos)
- [PowerShell on Ubuntu](https://learn.microsoft.com/en-us/powershell/scripting/install/install-ubuntu); other Linux distributions need their corresponding Microsoft installation instructions
- [Codex CLI](https://learn.chatgpt.com/docs/codex/cli)

For `Doctor` and `Verify`, setup does not download or provision runtimes. Full `Install` prepares the Task Board launcher runtime unless `-Offline` is selected: it reuses compatible Node from inherited `PATH` or provisions pinned Node.js `26.13.0` into the private AgentsHome cache. This applies to implemented Windows/macOS/Linux paths; only Windows x64 has been verified. Runtime acquisition uses the pinned official archive with digest verification; setup does not run a package manager, log in, or send inference requests. Network and device-identifier approvals from earlier runs do not authorize new downloads or account activity.

Client checks must run with external networking denied. macOS uses the operating system's Seatbelt sandbox. Linux needs a working `bwrap` executable and the namespace permissions needed by Bubblewrap. If the sandbox is absent or blocked by the host policy, setup stops with guidance. It does not retry the client without isolation, use `sudo`, or modify global AppArmor or sysctl policy.

## Check, install, and verify

Run these commands from the repository checkout:

```sh
sh scripts/setup.sh
sh scripts/setup.sh -Action Install
sh scripts/setup.sh -Action Verify
```

The first command defaults to `Doctor`. It checks prerequisite readiness without installing or changing the kit; a `ready` result can still mean the kit is missing or its discovery check did not pass. Use `Verify` for the complete installed-state check. `Install` first checks the client interface, then uses the existing installer and validates the installed result. After a successful actual `Install`, the setup output includes a short optional Impeccable reminder linking to its [getting-started guide](https://impeccable.style/tutorials/getting-started/). It is not shown by `Doctor`, `Verify`, or `-WhatIf` preview and does not check whether Impeccable is installed. `Verify` checks an existing installation's receipt and client discovery; a missing receipt is a failure, and it does not install missing files or repair a failed check.

## Optional Task Board diagnostics and tests

The Task Board runtime is not needed for ordinary questions, brief explanations, or standalone read-only consultation/review, and users may opt out of Board activation. Authorized execution tasks use the Board visibility checkpoint by default; if runtime prerequisites are unavailable, activation remains pending and independently safe authorized work may continue. Full installation provisions its launcher runtime unless `-Offline` is selected; offline mode forbids network acquisition and requires compatible Node on `PATH` or a verified `-RuntimeArchivePath`. `BoardDoctor` is informational: it selects the managed runtime when available, checks Node.js `>=26.13.0 <27` and actual built-in `node:sqlite` SQLite `>=3.54.0`, and never downloads or changes global configuration. `Doctor` and `Verify` are also download-free. `-WhatIf` is read-only and does not provision. Windows x64 is the only verified installation platform; macOS/Linux behavior remains unverified.

```powershell
pwsh -NoProfile -File ./scripts/setup-user.ps1 -Action BoardDoctor
```

Use `-BoardNodePath <path>` to select a one-shot diagnostic override. A missing/unsupported runtime is reported as Board unavailable; for an authorized execution task, Board activation remains pending while independently safe work may continue. The macOS/Linux `scripts/setup.sh` Install action delegates to the full installer and therefore provisions the runtime by default (or requires a compatible PATH runtime/local archive with `-Offline`). This path is implemented but remains unverified on macOS/Linux.

Task Board source and package tests are separately opt-in. The opt-in runtime-install suite requires an explicit `-RuntimeArchivePath`. The existing `install-user` suite accepts `-TaskBoardNodePath` (launcher), `-NodePath` (direct), or `-RuntimeArchivePath`; it always runs offline. The normal full test run requires an actually compatible Board Node runtime or an explicit archive and never downloads one. Select `-Suite task-board` for source behavior or `-Suite task-board-package` for packaged runtime checks:

```powershell
pwsh -NoProfile -File ./scripts/test.ps1 -Suite task-board
pwsh -NoProfile -File ./scripts/test.ps1 -Suite task-board-package -TaskBoardManifestSha256 '<reviewed-manifest-sha256>' -TaskBoardAppSha256 '<reviewed-app-sha256>'
```

Use `-TaskBoardNodePath <path>` to select the Node executable for either suite. The package suite's `CurrentPayload` check requires explicit manifest and application hashes that have already been reviewed for the candidate payload. Do not derive the expected hashes automatically from unreviewed source. See the [Task Board contract](../skills/team-core/references/task-coordination.md) for the optional capability boundary and current operation help for exact CLI fields.

## Optional integrations

These integrations are not prerequisites for the Kit. Installing or updating the Kit does not install or enable them.

| Integration | Purpose | Requirements and activation |
| --- | --- | --- |
| [Impeccable](https://github.com/pbakaus/impeccable) | Frontend design and visual refinement. | Install separately with user approval. For relevant assigned UI/design work, use its accessible guidance unless the user opts out; see the [usage guide](../skills/team-core/references/impeccable-usage.md) and [adapter](../skills/team-core/references/impeccable-integration.md). |
| [OpenSpec](https://github.com/Fission-AI/OpenSpec/tree/v1.13.2) | Specification, change and archive management. | The adapter supports `@fission-ai/openspec` **1.13.2**, PowerShell 7 and Node.js **20.19+**. Install separately with user approval, then explicitly enable integration in each target project; see the [supported profile, setup and recovery guide](../skills/team-core/references/openspec-integration.md). Do not substitute the latest upstream version without compatibility verification. |

The Kit does not download or install Impeccable or enable its hooks. It is not a setup prerequisite. The reminder is informational; a link or file on disk does not prove the active client loaded the capability. Follow the adapter when a relevant task encounters a known installation that the active role cannot access. OpenSpec does not generate an installation reminder, and projects without an opt-in marker continue using the normal Kit workflow.

## Additional setup options

The shell wrapper accepts an explicit PowerShell executable before forwarding the remaining arguments:

```sh
sh scripts/setup.sh --pwsh /path/to/pwsh -Action Doctor -CodexPath /path/to/codex
```

The shell wrapper sets `POWERSHELL_TELEMETRY_OPTOUT=1` and `POWERSHELL_UPDATECHECK=Off` before launching PowerShell. Manager and client subprocesses also receive both settings explicitly. For direct invocation from a POSIX shell, set them before the parent PowerShell process starts; the script cannot suppress that parent's startup activity retroactively:

```sh
env POWERSHELL_TELEMETRY_OPTOUT=1 POWERSHELL_UPDATECHECK=Off pwsh -NoProfile -File ./scripts/setup-user.ps1 -Action Doctor
env POWERSHELL_TELEMETRY_OPTOUT=1 POWERSHELL_UPDATECHECK=Off pwsh -NoProfile -File ./scripts/setup-user.ps1 -Action Install -WhatIf
env POWERSHELL_TELEMETRY_OPTOUT=1 POWERSHELL_UPDATECHECK=Off pwsh -NoProfile -File ./scripts/setup-user.ps1 -Action Verify -Json
```

Use `-CodexHome` and `-AgentsHome` for explicit alternative installation roots. They retain the existing installer's confinement and non-overlap requirements. Guided setup additionally refuses a selected Skills directory that overlaps the sandbox's masked private roots: the user's `.config`, `.codex`, or selected `-CodexHome`. It fails before starting a client probe or writing installation targets, including for a fresh or preview installation. Use the default `.agents` root or another non-overlapping unmasked root. The direct installer's path contract is unchanged. Without overrides, the kit uses the user's `.codex/agents` and `.agents/skills` locations. Keep custom paths quoted when they contain spaces.

`-Action Install -WhatIf` still runs the offline prerequisite probe and the installer preview, but writes no installation targets and does not claim a post-install verification pass. Its text output and JSON `installation.plan` show the selected roots and counts of planned installs, replacements, and removals. The plan follows the selected source inventory: version `1.0.9` has 34 managed units, comprising 15 agent profiles and 19 Skill bundles. An existing installation's plan depends on its receipt and current files. `-Force` is an explicit installation option for the existing deployment manager's conflict handling; inspect the preview and [safe deployment guide](safe-deployment.md) before choosing it. These options do not authorize dependency downloads or global configuration changes.

## What verification establishes

Client probes use a fresh temporary `HOME` and `CODEX_HOME`, with no imported personal authentication or client configuration. They retain the caller's executable search `PATH` so an existing npm launcher can locate Node.js; other child environment values remain explicitly allowlisted. Compatibility is checked by the reported version and actual local initialization/Skill-list operations. `-TimeoutSeconds` bounds individual client probes, previews and Verify calls; the default is `120`, with a permitted range of `1` to `300` seconds. An authorized full Install waits for its finite trusted file transaction to finish rather than killing an active deployment at a universal wall-clock deadline; dependency downloads, runtime probes and extraction retain their separate bounds, and installer pipe collection remains bounded after process exit. Interrupted transactions retain the documented journal recovery path. The check does not substitute another client or model when a capability is missing.

After installation, setup requires successful receipt verification and client discovery of every expected kit Skill at its installed path. The expected names and count come from the selected source inventory, currently 19 Skills, rather than a fixed discovery count. The probe creates an owned temporary `.agents/skills` alias to the selected installed Skill root and checks each returned path against the actual installed file. Unrelated personal Skills do not replace or satisfy any required kit entry. This checks that the tested client can parse and discover those installed resources; it does not prove that the user's existing configuration or currently open session has enabled them, and it does not establish account/model availability, loaded agent role or model identity, or a completed development workflow. Those require separate acceptance evidence.

For an existing managed Skill with malformed content, an explicitly requested `-Action Install -Force` can proceed through the existing manager's backup/replacement flow after client compatibility checks. The pre-install probe does not require that broken installation to pass discovery; the fresh post-install probe still requires a valid receipt and complete discovery of the selected source's Skills. `Verify` remains strict and does not perform repairs. Linked paths and other deployment conflicts retain the manager's existing protections.

Global Codex configuration remains a manual choice. Setup does not merge the optional configuration fragment or change the Lead model. The existing installer continues to protect unrelated components and own deployment receipts, backups, and recovery. A failed post-install check is reported as a failure; consult the recorded diagnostic and deployment state before attempting repair.

Use `-Json` for a structured setup result and the process exit status to detect failure. A failure remains unsuccessful even if earlier checks passed. Keep any saved diagnostic outside a clean source checkout, and do not include credentials when sharing it.

Cleanup terminates and waits for tracked client processes, attempts to terminate attached descendants, and removes the owned probe directory. JSON identifies this scope as `cleanup.processScope: "tracked-client-processes"`. On macOS, this does not prove that a child orphaned before its parent exited was terminated; Linux's isolated PID namespace gives a stronger lifetime boundary. The Skill-only probe sends no model-thread or inference request. Reported cleanup failure makes the setup result unsuccessful.

## Troubleshooting and scope

- Missing PowerShell or Codex: install the appropriate runtime through an approved route, or select an existing executable explicitly, then rerun `Doctor`.
- Missing or restricted sandbox: follow the host administrator's supported configuration process. Setup never weakens host policy automatically.
- Unsupported client protocol: use a client with the required local capabilities and rerun `Doctor`; a version string alone is not proof of compatibility.
- Failed receipt or missing Skill: inspect the selected roots and [deployment verification/recovery procedure](safe-deployment.md). `Verify` is read-only and does not silently repair the installation.

The existing [direct PowerShell installer](../scripts/install-user.ps1) remains available on Windows, macOS, and Linux. This convenience layer targets macOS/Linux setup; it does not replace Windows support or install the Codex desktop app.
