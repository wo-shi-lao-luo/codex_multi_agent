# Verification: reusable deployment and rollback

Status: automated checks passed; maintainer acceptance pending.

## Scope and evidence boundaries

Version 0.8.0 adds the deployment manager, install/update routing, receipt migration, stable snapshots, offline/Git-ref rollback, recovery and retention. The preceding OpenSpec work was separately committed as 0.7.0 (`eedd26a`). No real user installation, push, model session or formal stable promotion was performed for this change.

All executable scenarios use unique temporary package copies, fake Codex/Skills homes and local Git repositories, with finally cleanup. This is filesystem/process isolation, not a VM or container. No credentials, network, external CLI downloads or real-home writes are required. Stop unrelated writers before a future real deployment; the manager's lock cannot lock editors or old installers.

Architecture: see `docs/architecture.md`, Installation management boundary. One self-contained script deliberately keeps recovery independent of the source checkout and target-version helper files. No Skill content or model allocation changed.

## Use cases and coverage

| Case | Expected outcome | Automated evidence |
| --- | --- | --- |
| Preview an empty installation | No homes or management state created | test-deployment |
| Install and verify | Exact inventory, receipt v2, persistent entrypoint | test-deployment; test-install-user |
| Explicit stable selection, then upgrade | Stable pointer unchanged by upgrade | test-deployment |
| Downgrade to old package | New-only agent, whole Skill and inner file removed | test-deployment |
| Offline stable restore | Installed launcher restores without relying on repository helpers | test-deployment |
| Personal config/Skill coexistence | Unrelated bytes unchanged | test-deployment |
| Modified owned file | Refuse by default; Force retains original in snapshot | test-deployment; test-install-user |
| Failure during activation or either receipt boundary | Complete original payload and exact receipt restored | test-deployment fault injection |
| Forced process exit | Pending blocks deployment; Recover restores and removes staging | test-deployment child process |
| External edit after interruption | Recovery blocks without erasing user edit; retry after preserving/resolving edit | test-deployment |
| Concurrent manager | Exclusive lock refusal, no payload/receipt mutation | test-deployment |
| Corrupt snapshot or escaping receipt path | Refuse before destructive writes | test-deployment |
| Incompatible runtime schema | Refuse downgrade | test-deployment |
| Local Git target with dirty checkout | Deploy immutable commit; preserve checkout | test-deployment |
| Legacy receipt | Adopt validated ownership; upgrade receipt and restore stable | test-deployment |
| Explicit prune | Preview read-only; retain stable and requested recent snapshots | test-deployment |

Unit-level guards are exercised through public commands rather than exported internal functions. Integration, CLI contract, local E2E, regression, compatibility, security and resilience/recovery coverage are required and represented above. UI, accessibility and visual tests are not applicable. Performance, full disk/power-loss simulation, arbitrary future metadata protocols and hostile same-user tampering are not certified by these tests. Hashes detect accidental payload corruption, not an attacker who rewrites payload and manifests together.

## TDD record

- Initial deployment suite was written first and failed because `scripts/deploy-user.ps1` did not exist.
- The first implemented recovery exposed a scope-comparison error: the test detected an uncleared pending journal. The comparison was fixed and the suite passed.
- Receipt-boundary fault injection, post-crash external edits, lock and snapshot-corruption checks were added during hardening (test-after). They are not claimed as initial red/green evidence.
- Existing installer and package suites were reused for regression. Test fixtures use comments stating scenario and expected outcome.

## Automated results — 2026-09-29

Passed in PowerShell 7 on Windows:

- `scripts/validate.ps1`
- `tests/test-deployment.ps1`
- `tests/test-install-user.ps1`
- `tests/test-validate.ps1`
- `tests/test-stage-verification.ps1`
- `tests/test-project-blueprint.ps1`
- `tests/test-feedback-runtime.ps1`
- `tests/test-openspec.ps1` (offline CLI doubles only; real upstream CLI not rerun for this installer change)

Generated test roots are removed by their suites. Persistent snapshots in an intentional real install are recovery assets, not disposable test litter. Do not publish runtime receipts or snapshots: they can contain machine-local paths and local edits.

## Manual checklist — not yet executed

Use the [deployment guide](../../safe-deployment.md) for commands. Choose disposable homes for rehearsal; real installation is a separate explicit choice.

1. Review the currently installed version with Verify and Status. Happy path: receipt and payload agree. Recommended edge: change one disposable managed file and confirm Verify fails; restore that file before proceeding.
2. Mark the known-good installation stable. Record its snapshot ID. Happy path: stable points to the verified old bytes, not the current source checkout. Edge: an unverified/modified install must not be accepted as stable.
3. Preview the experimental install, then install into the chosen homes. Check added/replaced/removed units. Happy path: stable ID stays unchanged and unrelated config/Skills survive. Edge: confirm a local customization blocks unless Force is explicitly chosen and its backup is retained.
4. Restore stable using the persistent installed launcher. Happy path: Verify passes; new-only components and internal files are absent. Try a source checkout that lacks the new manager to confirm independence. If custom homes were chosen, supply those same homes to the launcher.
5. Start a fresh task/client for a separately authorized real trial. Happy path: old workflows are discovered and work as expected. An existing conversation may retain new instructions, so it is not valid rollback evidence.
6. Review retention preview. Happy path: stable is not scheduled for deletion. Only execute prune when the displayed recovery copies are no longer needed; deletion is irreversible through this tool.

Do not simulate a hard crash or corrupt metadata in real homes; use the isolated test suite for those cases. Record actual manual results and user acceptance here after review; do not infer them from automated success.
