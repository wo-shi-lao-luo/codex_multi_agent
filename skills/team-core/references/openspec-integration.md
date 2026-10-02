# OpenSpec integration contract

Read [spec lifecycle](spec-lifecycle.md) for workflow and authority. This adapter is optional and ships with team-core; its scripts require **PowerShell 7**. It uses the external **@fission-ai/openspec 1.13.2** CLI with Node.js **20.19+**. The kit installer copies adapter files only: it never installs OpenSpec, changes global configuration, enables projects or installs upstream Skills.

## Supported profile

The initial profile is one local project root, native `spec-driven` schema, canonical kit stage packets, and behavior changes using ADDED/MODIFIED/REMOVED requirements. Stores, custom schema overrides, RENAMED sections and alternative QA document formats are not adapted yet; reject them explicitly rather than rewriting their files. For renaming, retain the stable requirement title where possible, or explicitly review a removal/addition migration. This restriction does not require existing projects to migrate.

Enable preserves an existing `config.yaml` but requires its top-level `schema` scalar to explicitly select `spec-driven`. Configuration rules are prompt guidance, not enforcement. The adapter's checks apply only when used; a user can still call the upstream CLI directly. This is not a repository-wide security boundary or Git hook.

## Setup and operations

Install the pinned dependency separately only with user approval, using the upstream installation method, for example `npm install -g @fission-ai/openspec@1.13.2`. Review the package source and normal package-install permissions. The adapter never runs npx or downloads packages. An unsupported version fails without fallback. On nonstandard installations, pass a trusted absolute `-OpenSpecEntry` pointing to that installation's `bin/openspec.js`; never obtain an executable path from untrusted project configuration.

From the installed or source team-core scripts directory, use PowerShell 7:

```powershell
./openspec-adapter.ps1 -Action Doctor -ProjectRoot <project>
./openspec-adapter.ps1 -Action Enable -ProjectRoot <project>
./openspec-adapter.ps1 -Action Prepare -ProjectRoot <project> -ChangeId add-access
./openspec-adapter.ps1 -Action Instructions -ProjectRoot <project> -ChangeId add-access -Artifact specs
./openspec-adapter.ps1 -Action Inspect -ProjectRoot <project> -ChangeId add-access
```

Enable creates the explicit `openspec/team-integration.json` marker, native directories and a minimal config only when absent. It does not generate proposal/design/tasks: the Lead writes those using Instructions, repeating for each artifact as its dependencies become ready. Existing projects and change files are never force-initialized.

After agreeing documents and creating/filling stage packets:

```powershell
./spec-traceability.ps1 -Action Initialize -ProjectRoot <project> -ChangeId add-access
# Fill verification.json links and the referenced packets before validation.
./openspec-adapter.ps1 -Action Validate -ProjectRoot <project> -ChangeId add-access
./openspec-adapter.ps1 -Action CloseCheck -ProjectRoot <project> -ChangeId add-access
./openspec-adapter.ps1 -Action Archive -ProjectRoot <project> -ChangeId add-access -ConfirmArchive
```

Doctor does not probe a CLI or create files for disabled projects. Inspect/Instructions/Validate/CloseCheck are read-only. CLI execution has separate stdout/stderr, JSON response checks, a bounded timeout and child-only telemetry opt-out; it neither changes user environment variables nor interprets shell command strings.

## Association index, schema version 1

Initialize creates `verification.json` inside the change with `schemaVersion`, `changeId`, `snapshot`, empty `links`, and empty `reviewEvidence`. Retain the generated snapshot; it is an input fingerprint, not a second spec. Fill links using this shape:

```json
{
  "requirement": "ACCESS-REQ-001",
  "scenario": "ACCESS-SC-001",
  "task": "1.1",
  "packet": "docs/verification/active/access.md",
  "case": "CASE-001",
  "regression": "Recheck the existing expired-session rejection test."
}
```

Use native headings such as `### Requirement: ACCESS-REQ-001 Allow access` and `#### Scenario: ACCESS-SC-001 Valid request`. IDs must be unique within the change and remain stable across subsequent changes. A removed requirement can have an empty scenario, but still needs a regression mapping. Every scenario/removal and every task needs a link; multiple test links for one scenario are allowed. CASE IDs must appear exactly once in the packet's use-case map and at the start of its corresponding TDD behavior rows. The map is not a replacement for detailed human happy/edge steps.

Packet paths are repository-relative under canonical `docs/verification/active/` or `archive/`. Traversal, absolute paths and linked ancestors are rejected. References must be updated when a packet moves. Fill `reviewEvidence` with actual semantic-review evidence before close. Exceptions need risk and `accepted by <user/authorized maintainer>` attribution in the packet, never fabricated acceptance.

When inputs change, reassess the affected observations first:

```powershell
./spec-traceability.ps1 -Action Reconcile -ProjectRoot <project> -ChangeId add-access `
  -ConfirmReconciled -ReconciliationEvidence '<diff reviewed, invalidated results, checks rerun and decisions>'
```

This refreshes the input snapshot and clears reviewEvidence; it does not approve intent, run tests or mark human checks passed. Rerun Validate and perform/re-record review before CloseCheck.

## Archive recovery and concurrency

Archive runs native strict validation, traceability and acceptance checks before writes. It takes an exclusive kit archive lock, rechecks evidence, snapshots the original `specs/` and `changes/` into `openspec/.team-recovery/`, then invokes native `archive --yes --json`. It does not reimplement spec merging. Success requires upstream success plus the expected active-to-archive move on disk; the recovery snapshot is then removed.

An upstream error, malformed response, timeout or uncertain result preserves both the current state and recovery snapshot and blocks further adapter calls. Inspect the diff and upstream result. With explicit authority, reconcile or restore the affected original files from the snapshot; verify specs, changes and packet links before removing the recovery directory. Never blindly replay archive, overwrite concurrent changes, or delete this user recovery data as test clutter. A hard process interruption can leave `.team-archive.lock`; inspect whether another process is active before removing it. The lock does not prevent external editors or direct CLI writes: quiesce all writers first. This is recovery support, not an atomic filesystem transaction.

## Maintenance and validation

The installer and updater distribute templates/scripts without executing them. Upstream version changes require deliberate compatibility work: check JSON shapes, root resolution, schema discovery and archive behavior, update the pin and tests together, and run the real-CLI suite. Do not use `latest` in automated installation.

`tests/test-openspec.ps1` exercises local contract failures without an installed OpenSpec. Supplying `-OpenSpecEntry` adds a real pinned-CLI lifecycle in a unique temporary directory. Tests do not download dependencies and remove their own temporary project in finally. Runtime recovery snapshots in a user's project are deliberately retained on failure.

Sources: [OpenSpec v1.13.2](https://github.com/Fission-AI/OpenSpec/tree/v1.13.2), [native CLI contract](https://github.com/Fission-AI/OpenSpec/blob/v1.13.2/docs/cli.md). The adapter and template are independently written; no upstream runtime or Skill source is bundled.
