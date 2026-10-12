# macOS and Linux setup

The setup entrypoint checks prerequisites, installs the kit, and verifies client Skill discovery on macOS and Linux, targeting ARM64 and x64. It uses the existing PowerShell deployment manager. This release does not provide a native application or DMG installer. Historical platform coverage and remaining limits are summarized in the [platform matrix](platform-support.md#platform-matrix-and-evidence).

## Prepare existing runtimes

The setup commands require PowerShell 7 and a compatible native Codex CLI. If Codex was installed through npm, its required Node.js runtime must also be available on `PATH`, including the Homebrew or nvm directory when applicable. The shell wrapper reports the operating system and architecture and looks for `pwsh`; PowerShell then checks the selected Codex client. Python and a virtual machine are not required for user setup.

If a runtime is missing, follow its official installation instructions using the user's approved network route:

- [PowerShell on macOS](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-macos)
- [PowerShell on Ubuntu](https://learn.microsoft.com/en-us/powershell/scripting/install/install-ubuntu); other Linux distributions need their corresponding Microsoft installation instructions
- [Codex CLI](https://learn.chatgpt.com/docs/codex/cli)

Choose a runtime for the detected operating system and architecture. Dependency acquisition is a separate manual step: setup does not run a package manager, download software, log in, or send inference requests. Network and device-identifier approvals for earlier acceptance runs do not authorize new downloads or account activity.

Client checks must run with external networking denied. macOS uses the operating system's Seatbelt sandbox. Linux needs a working `bwrap` executable and the namespace permissions needed by Bubblewrap. If the sandbox is absent or blocked by the host policy, setup stops with guidance. It does not retry the client without isolation, use `sudo`, or modify global AppArmor or sysctl policy.

## Check, install, and verify

Run these commands from the repository checkout:

```sh
sh scripts/setup.sh
sh scripts/setup.sh -Action Install
sh scripts/setup.sh -Action Verify
```

The first command defaults to `Doctor`. It checks prerequisite readiness without installing or changing the kit; a `ready` result can still mean the kit is missing or its discovery check did not pass. Use `Verify` for the complete installed-state check. `Install` first checks the client interface, then uses the existing installer and validates the installed result. `Verify` checks an existing installation's receipt and client discovery; a missing receipt is a failure, and it does not install missing files or repair a failed check.

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

Client probes use a fresh temporary `HOME` and `CODEX_HOME`, with no imported personal authentication or client configuration. They retain the caller's executable search `PATH` so an existing npm launcher can locate Node.js; other child environment values remain explicitly allowlisted. Compatibility is checked by the reported version and actual local initialization/Skill-list operations. `-TimeoutSeconds` controls individual client and installer waits, including installer output collection; the default is `120`, with a permitted range of `1` to `300` seconds. It is not a single deadline for the complete setup. The check does not substitute another client or model when a capability is missing.

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
