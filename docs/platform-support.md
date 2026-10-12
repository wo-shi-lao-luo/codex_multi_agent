# Platform support and verification

The kit uses one PowerShell implementation for Windows, macOS, and Linux. Agent profiles, Skills, installation receipts, and recovery commands share the same layout and interfaces. The [macOS/Linux setup entrypoint](setup.md) provides prerequisite checks, installation, and offline client Skill verification. Version 0.10.4 removed the separate developer acceptance harnesses, VM launcher, asset locks, and per-run reports from the current tree; user setup, runtime support, reusable regression tests, and CI remain available. This release remains a review preview.

## Runtime and installation

Install PowerShell 7 separately and make `pwsh` available to the shell that runs the kit. The installer and default test suite do not install runtimes or download packages. Runtime acquisition, Git traffic, and any later live provider test must follow the user's approved network route. The default test suite itself uses local fixtures.

The same commands work from PowerShell, macOS zsh, or Linux shells once `pwsh` is available:

```powershell
pwsh -NoProfile -File ./scripts/validate.ps1
pwsh -NoProfile -File ./scripts/install-user.ps1 -WhatIf
pwsh -NoProfile -File ./scripts/install-user.ps1
pwsh -NoProfile -File ./scripts/update-user.ps1
```

Installation defaults to the user's `.codex/agents` and `.agents/skills` directories. `-CodexHome` and `-AgentsHome` select alternative non-overlapping roots. Global Codex configuration is configured separately. Directory installation can operate without Git; deploying a local `-GitRef` requires Git. Verification and snapshot recovery remain independent of Git and of the source checkout. See [safe deployment](safe-deployment.md) for receipts, backups, restore, recovery, and pruning.

The full developer suite additionally requires Git for local deployment and repository-policy fixtures, and Node.js for the OpenSpec and formatter CLI fixtures. A real OpenSpec installation is not needed for the default suite. The optional real adapter retains its pinned version and Node.js requirement in the [integration contract](../skills/team-core/references/openspec-integration.md).

## Filesystem contract

- Stored package keys and project-relative identities use forward slashes. Paths with spaces and non-ASCII characters are handled as literal paths and argument values.
- On macOS, selected roots and system-temporary anchors may use the verified operating-system aliases `/tmp` to `/private/tmp` and `/var` to `/private/var`. The runtime canonicalizes only these known aliases after checking their actual targets. Other linked roots, linked descendants, and dangling links are rejected.
- Project-relative paths cannot escape their selected root, including through traversal or case-different sibling directories. Non-Windows confinement uses conservative case-sensitive comparison.
- Target-project inventories preserve case-distinct filenames on case-sensitive filesystems. Distributable package paths must remain portable: case-colliding package entries are rejected rather than silently merged.
- Protected documentation metadata and historical-document namespaces retain conservative case-insensitive checks, including on case-insensitive macOS volumes; ordinary document identities remain exact.
- Installation ownership, snapshots, and freshness evidence continue to use exact file bytes. Checkout newline changes can invalidate earlier evidence and require reassessment. Never refresh old fingerprints merely to present prior verification as current.
- Recovery keeps a self-contained manager outside agent/Skill discovery. Its installed copy must not depend on the current checkout or a helper that payload downgrade could remove.

## Automated verification

Run the common entrypoint from the repository:

```powershell
pwsh -NoProfile -File ./scripts/test.ps1
pwsh -NoProfile -File ./scripts/test.ps1 -Suite portability,deployment,documentation
pwsh -NoProfile -File ./scripts/test.ps1 -ResultPath ../platform-results.json
```

Each selected check runs in its own PowerShell process. The runner reports the operating system, process architecture, runtime versions, check outcomes, and a failing exit status when a required check cannot pass. Individual suites own unique temporary fixtures and must clean up those fixtures. Checks never install into real user homes or acquire dependencies. Missing prerequisites are failures, not successful skips.

The default run selects 27 checks: two validators and 25 suites, including the upstream AI, generated-artifact, design-exploration, formatter, workflow routing, Git delivery, shared test support, and web engineering checks. `-Suite` also accepts a comma-separated string when invoked from zsh or Bash. `-ResultPath` optionally saves a JSON result summary to a chosen file whose parent already exists; keep that generated result outside a clean CI checkout. Platform-specific cases that cannot apply to the current fixture report `NOT APPLICABLE`; an overall suite pass does not establish those cases were exercised. Record case-sensitive-volume and filesystem-permission coverage separately.

Required coverage includes installation/update, unchanged preview, conflicts and backups, exact downgrade, offline restore, interrupted recovery, separate-process locking, unrelated-file preservation, path containment, symlink/dangling-link refusal, case-sensitive inventory, Unicode paths, metadata validation, and bilingual documentation. Optional real OpenSpec lifecycle results are recorded separately from local CLI-double results.

## Platform matrix and evidence

Version 1.0.9 integrates upstream master `d1841e1` and expands the runner to 27 checks. On 2026-10-12, focused local checks passed on macOS 26.5.1 ARM64 with PowerShell 7.6.6 and .NET 10.0.12: package/provenance and bilingual validation, the refactored shared test helper and its consumers, Team routing, web guidance, Git delivery, and installation/setup (59 scenarios). The first integration had passed all 23 then-available checks before upstream advanced. Exact-commit hosted results for the final combined branch are recorded in [PR #10](https://github.com/wo-shi-lao-luo/codex_multi_agent/pull/10); the earlier 14-check and 13-Skill results below remain historical.

A separate offline macOS check with native client `0.162.0-alpha.17.2` discovered all 19 Skills, verified installation, rejected a malformed managed Skill, preserved an unchanged Force preview, repaired the Skill with an exact damaged-file backup, and verified the result and cleanup. It used disposable homes with client networking denied. The local APFS volume exercised system aliases, linked/dangling paths and formatter case-alias refusal; case-distinct-file branches require a case-sensitive target such as the Ubuntu CI runner. These checks add no new authentication, inference or live-workflow coverage.

These targets define the initial verification matrix. Source support and recorded execution are separate claims. Record the actual OS release, architecture, PowerShell/.NET version, filesystem, source revision, and result for every run.

| Target | Filesystem coverage | Recorded coverage |
| --- | --- | --- |
| Windows Server 2022 x64 | Case-insensitive temporary filesystem, junction and recovery regressions | All 14 checks passed on the hosted runner with PowerShell 7.6.6; Windows ACL-denial behavior remains unverified. |
| macOS arm64 | Hosted case-insensitive temporary filesystem; local default/case-sensitive APFS and verified system aliases | All 14 checks passed on macOS 15.7.9 with PowerShell 7.6.5 and locally on macOS 26.5.1 with PowerShell 7.6.6. Local verification adds alias/case-sensitive coverage and strict live acceptance with pinned client `0.162.0-alpha.17.2`, configured role/model checks, the regression review, preservation, and cleanup. |
| Ubuntu 24.04.5 LTS x64 | Case-sensitive temporary filesystem, symbolic links and Unix permission denial | All 14 checks passed on the hosted runner with PowerShell 7.6.6. |
| Ubuntu 24.04.5 LTS arm64 | Case-sensitive native guest filesystem in an isolated Lima VZ VM | All 14 checks, expanded offline preflight, and strict live acceptance passed with PowerShell 7.6.6 and pinned client `0.162.0-alpha.17.2`. Evidence includes 13-Skill discovery, standalone restore, helper execution/discovery, configured role/model checks, the regression review, preservation, and client/VM cleanup. The guest used Bubblewrap and a scoped AppArmor profile; live feedback-file writing remains unverified. |
| macOS x64 | Native architecture-specific run | Unverified until separately exercised. |

The historical [Windows verification](verification/active/project-rules.md) remains available. The table summarizes execution before the 0.10.4 cleanup; it does not certify future revisions or every supported runtime version. The declared PowerShell 7 minimum requires separate execution evidence; a version declaration alone is not a compatibility result.

The 0.10.3 setup checks passed on macOS ARM64 and Ubuntu ARM64 with the pinned native client: readiness, unchanged preview, installation, receipt and 13-Skill verification, and reinstall. These were offline checks in disposable homes, with no authentication or inference. They do not add x64 live coverage or repeat the earlier live workflow.

The [hosted run for commit `7b1bfa0`](https://github.com/Andy-Wang-010/codex_multi_agent/actions/runs/38128096920) passed all 14 checks on Windows x64, Ubuntu x64, and macOS ARM64. Per-run JSON files are no longer kept in the current source tree. The earlier acceptance tools, locks, guide, and committed reports (including unsuccessful attempts) remain in the rebased history at Git commit `d74c41addbfda69b46d621e7b3a6449692da3469`, before cleanup. Those reports retain their original source identities and do not certify the rebased commit. Future result files should be saved outside the checkout or retained as CI artifacts.

## CI and live workflow acceptance

The manual platform CI workflow uses preprovisioned self-hosted Windows, macOS, and Linux runners. Each runner needs PowerShell, Git, Node.js, and a clean checkout of the exact requested commit at `KIT_SOURCE_ROOT`. Provisioning and runner connectivity must use the approved route. The workflow verifies the checkout and runs local tests; it contains no checkout action, package installation, or network fallback. It does not provision runners automatically.

A separate [hosted workflow](../.github/workflows/platform-tests-hosted.yml) serves environments without those runners. It uses GitHub-hosted Windows, Ubuntu, and macOS jobs, exact-commit checkout, and JSON results with runtime/source provenance retained as CI artifacts for seven days. It supports manual dispatch and an initial push trigger restricted to `zhiheng`, allowing branch verification without changing the default branch. Publishing that branch starts the jobs. GitHub connectivity, checkout, and artifact transport require an approved route. Check actual runtime versions and filesystem cases exercised in each run rather than inferring them from matrix labels.

After automated checks pass on a target, rehearse installation and restore in disposable homes. Separately verify agent and Skill discovery in a fresh client session and a small explicitly requested workflow. A byte-equal fake-home installation does not establish client loading, model availability, or human acceptance. Retain the results outside the checkout and record a concise coverage summary before expanding published support claims.

The earlier live acceptance runs checked client-reported role, model, and reasoning effort for the Lead and exactly one named reviewer, an expected regression finding, unchanged protected inputs and installed payloads, and cleanup. Provider-reported model identity was a separate optional field. Any new live check requires fresh authentication in a disposable client home, an approved network route, and installation-identifier authorization for that specific run.

The recorded macOS and Ubuntu ARM64 runs passed these strict checks with Lead `gpt-6-astra` / `high` and exactly one `team-reviewer` using `gpt-6.1-sol` / `high` with `fork_turns: none`. Both completed the seeded regression review and independent 143-case oracle. Provider-resolved model identity remains unknown. The Ubuntu Lead reported an optional feedback-write failure, and its result records no project changes; this run establishes the review handoff but not successful live feedback-file writing.

The tested VM target was Ubuntu 24.04 arm64 on an Apple Silicon Mac using native virtualization, a verified local image, a copied source snapshot, and a Linux filesystem without shared host directories. This target is distinct from the Ubuntu x64 hosted results above. Live workflow coverage remains unverified on Linux x64, other Linux distributions, and macOS x64.
