# Verification: Shared test support

Packet schema version: 2
Stage slug: test-support
Contract status: active
Final manual status: manual pending
Final manual evidence:

## Stage context

- Objective: Extract common test mechanisms without changing the six consumer suites' scenarios, flags, assertions, diagnostics, copied-source boundaries or cleanup guarantees.
- Scope: tests/helpers/, six existing suites, tests/test-test-support.ps1 and the folder-purpose guide. Production validators, installation behavior, Skills, public documents and version are unchanged in scope.
- Ownership: team-backend-engineer writes helper/consumers; reused team-tester owns helper tests and this packet; a separate team-reviewer reviews the frozen result. No application AI behavior is evaluated.
- Environment, test data and cleanup: offline PowerShell 7; exact owned GUID OS-temp roots, local fixture Git only, explicit fake homes only. Tester logs live under _work/test-support/tester/. No real repository Git mutation, network or actual-home operation.
- Design: light, bounded common-mechanism extraction; no scenario merging, new framework or material product architecture migration. Forecast unknown; checkpoint each suite, with independent fixture batches only.

## Use-case map

| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| TS01 process | Controlled child script | Pass literal arguments and explicit environment; capture stdout/stderr and nonzero exit | Exact argument/env values and independent output/exit; parent env unchanged | happy / edge |
| TS02 package copy | Owned synthetic source | Copy narrow and public-document profiles | Exact approved files copied; private/unrelated trees omitted; source unchanged | happy / edge |
| TS03 fingerprint | Owned fixture tree | Edit/add/remove a file, including hidden file | Stable identity initially; every material path/byte change detected without writes | happy / edge |
| TS04 cleanup | Owned exact sandbox plus sibling sentinel | Remove exact GUID child; submit wrong parent/name/broad targets | Owned root removed; invalid targets rejected and sibling bytes survive | happy / edge |
| TS05 consumer characterization | Six frozen existing suites | Execute existing commands before and after extraction | Same cases/flags/diagnostics and actual consumer boundaries; byte restoration and cleanup preserved | regression |
| M01 review contracts | Frozen diff and evidence | Human reviews preserved assertions and helper interfaces | Accept or identify a concrete behavior difference | manual |

## Coverage-category decisions

| Category | Decision | Reason |
| --- | --- | --- |
| unit | required | Deterministic helper transport, identity, copy and cleanup rules. |
| integration | required | Six suites invoke actual validator/feedback consumers and fixture processes. |
| contract/API | required | Helper argument/result and fixture-profile contracts. |
| E2E | required | Retained offline suite CLI and fake-home modes; no product journey exists. |
| regression | required | Preserve all existing scenarios, flags and diagnostics. |
| manual | required | Maintainer acceptance remains pending; agent review is separate. |
| component/UI | not applicable | No UI component. |
| accessibility | not applicable | No user interface. |
| visual regression | not applicable | No rendered output. |
| performance/load | not applicable | No performance claim; runtime savings unmeasured. |
| security | required | Literal argv, explicit env, source-copy isolation and cleanup refusal. |
| compatibility | required | Existing standalone commands and distinct copy profiles retained. |
| data migration/rollback | not applicable | No production persisted-data migration. |
| resilience/recovery | required | Nonzero children, restoration and failure cleanup retain evidence. |
| exploratory/usability | not applicable | Internal test mechanism extraction. |

## TDD behavior matrix

| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TS01 literal process transport | Shell interpolation or lost output/env | unit | test-first | test-test-support.ps1 TS01 | Preproduction suite exit1 at TS00: missing shared helper tests/helpers/package-test.ps1; function cases not reached | Final reviewed helper suite exit0; exact literal argv/env, independent 128KiB streams, exit17 and success control | Final reviewed suite after review fixes exit0; logs below | none | team-tester | passing |
| TS02 exact profile copies | Source boundary silently widens or shrinks | compatibility | test-first | test-test-support.ps1 TS02 | Same actual preproduction TS00 availability failure; copy cases not reached | Final reviewed suite exit0; four exact manifests, pre-copy source hashes, BOM/CRLF bytes, source preservation and overlap refusals | Byte-proof review strengthening rerun exit0; final suite101 assertions | none | team-tester | passing |
| TS03 complete fingerprint | Hidden/add/remove changes missed | regression | test-first | test-test-support.ps1 TS03 | Same actual preproduction TS00 availability failure; fingerprint cases not reached | Final reviewed suite exit0; ordinal order, hidden files/directories, nested byte changes and read-only checks | Final reviewed suite exit0 after helper freeze | none | team-tester | passing |
| TS04 safe owned cleanup | Foreign path deleted | security | test-first | test-test-support.ps1 TS04 | Same actual preproduction TS00 availability failure; cleanup cases not reached | Final reviewed suite exit0; exact removal/absence, wrong prefix, literal regex prefix, nested/uppercase/absent invalid roots and Windows junction refusal | Final reviewed suite exit0 after platform comparison fix; non-Windows native case remains unverified | none | team-tester | passing |
| TS05 existing consumer preservation | Shared extraction changes test semantics | integration | test-after | six existing suite commands and affected flags | not applicable | Six defaults and three fake-home modes exit0 on pre-platform-fix freeze; final-hash three TE guards exit0; preserved assertions/diagnostics and bounded Windows reuse rationale below | Final helper101 assertions and three guards exit0; no duplicate nine-run rerun for the reviewed platform-only delta | Behavior already exists; pre-extraction characterization is not Red. Original scenarios remain; three inline cleanup assertions migrated into tested helper safety. | team-tester | passing |
| M01 maintainer review | Automated results mistaken for user acceptance | manual | manual-or-environmental | human verification below | not applicable | planned | planned | User acceptance cannot be performed by agent. | user | manual pending |

## Automated test and E2E plan

- Before writer GO: validate this packet; execute six independent existing default suites, retaining source/test hashes, logs, exit and asserted-case inventory. Then write executable helper tests against the agreed API and observe actual missing-helper Red.
- At freeze: helper test, six default suites, affected source-only/synthetic/installation and Git mode flags. Compare assertion/diagnostic inventory and inspect the actual diff. Run broader checks only for evidenced impact. All due checks must be resolved or reported before handoff.
- Runner: fresh pwsh with isolated TEMP/TMP per batch; baseline runner never invokes repository Git commands. Existing Git suite may create its own temporary .git repositories. Installation flags use explicit fake homes, never actual homes.
- Logs and immutable observations: _work/test-support/tester/. Do not fabricate Red, reuse unknown inputs, infer active models, or claim runtime savings.

### Preproduction observations

Initial schema2 packet Validate exited0 before baseline or writer GO. The actual command
`pwsh -NoProfile -File tests/test-test-support.ps1` exited1 with
`TS00: missing shared helper tests/helpers/package-test.ps1` before helper implementation.
This proves the absent helper fails the executable suite; TS01-04 function assertions were
written but not reached in that Red. Subsequent ordinal-order/prefix-negative additions did
not change this missing-helper boundary. PowerShell AST parsing reported zero errors.

Six default commands characterized the unchanged consumers before extraction:

| Consumer | Exit | Observed seconds | Evidence under _work/test-support/tester/ |
| --- | --- | --- | --- |
| test-web-engineering.ps1 | 0 | 13.36 | baseline-web-engineering.json and stdout/stderr logs |
| test-team-entry.ps1 | 0 | 60.85 | baseline-team-entry.json and stdout/stderr logs |
| test-ai-capability-contracts.ps1 | 0 | 34.28 | baseline-ai-capability-contracts.json and stdout/stderr logs |
| test-ai-evaluation.ps1 | 0 | 43.17 | baseline-ai-evaluation.json and stdout/stderr logs |
| test-architecture-migration.ps1 | 0 | 43.95 | baseline-architecture-migration.json and stdout/stderr logs |
| test-git-delivery.ps1 | 0 | 103.38 | baseline-reviewed-git-delivery.json and stdout/stderr logs |

Each captured test-file SHA256 remained unchanged and each independent outer TEMP/TMP root
was empty after the suite, then its exact GUID root was removed. JSON inventories retain
static assertion call sites, not executed-case counts; stdout retains emitted case/diagnostic
evidence. The runner's first five console summaries incorrectly selected dictionary properties
and printed nulls; retained JSON/log contents contain actual observations, and summary output
was corrected before the reviewed Git run. No source test was altered by that runner fix.

Git's first sandboxed attempt exited1 on temporary fixture `.git/config` Permission denied;
its original baseline-git-delivery logs remain retained. The same authorized offline command
reran under reviewed permissions and exited0. This is an environment failure followed by a
successful characterization, not a production regression or TDD Red. Times describe these
runs only; parallel baseline timings do not establish future savings.

### Execution and observation choices

| Case / test ID | Execution entrypoint and real boundary | Runner / command | Observation mode and rationale | Retained browser / visual checkpoints | Evidence / drill-down / gaps |
| --- | --- | --- | --- | --- | --- |
| TS01-04 | test-only helper with controlled filesystem/child scripts | pwsh -NoProfile -File tests/test-test-support.ps1 | exact argv/output/exit/env, manifests and sentinel hashes | not applicable | Final helper suite passed 101 assertions; final-reviewed-test-support logs capture matching helper hashes before/after; non-Windows native branch unverified. |
| TS05 | existing actual copied consumers | six original tests/test-*.ps1 commands and affected flags | exit, CASE diagnostics, source identity and exact fixture cleanup | not applicable | Pre-platform-fix six defaults and three fake-home modes passed; final-helper-hash three TE guards passed. Baseline/post logs and bounded Windows reuse rationale below retain provenance; earlier helper hashes unknown. |
| M01 | full frozen diff and above evidence | human review | semantic acceptance | not applicable | manual pending |

### Manual-to-automated coverage mapping

| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| M01 preserved consumer contracts | TS05 original commands/flags and exact consumers | TS01-04 helper assertions; independent reviewer semantic inspection | Selected automated checks passing with provenance/platform limits below; user manual acceptance pending. | user acceptance pending |

### Frozen implementation observations and review closure

All evidence below is retained under `_work/test-support/tester/`; each run has JSON,
stdout and stderr. Every outer fixture was empty after its suite and then removed by
validated exact GUID cleanup; every captured consumer/test source hash stayed unchanged.

| Executed scope | Evidence prefix | Result / observable checkpoints |
| --- | --- | --- |
| Six default suites | post-web-engineering, post-team-entry, post-ai-capability-contracts, post-ai-evaluation, post-architecture-migration, post-reviewed-git-delivery | All exit0; WEB6 validator checks/12 routes, TE26 validator checks, GD33 read-only invocations; AC8 lost routes/4 missing resources, AE8 lost routes/4 missing resources plus role/profile assertions, AM13 lost routes/missing/empty. |
| WEB InstallOnly, TE InstallOnly, GD InstallCopyOnly | post-install-reviewed-web-engineering, post-install-reviewed-team-entry, post-install-reviewed-git-delivery | All exit0; actual copied-source/fake-home payload/receipt SHA256 proofs retained; packageDigest2547c72ebc02ec32bdb5ce993dd85ae183b13ceedb997a9567a16b64477b66a4. |
| TE GuardRedCase Resource, Link, Policy | final-guard-resource, final-guard-link, final-guard-policy | All exit0 on final helper hash; each synthetic intact baseline accepted and selected damage rejected. |
| Final helper suite | final-reviewed-test-support | Exit0, TS01-04 all101 assertions on Windows, including junction refusal and exact byte proofs. Non-Windows parent case test explicitly not applicable on this host. |

The first independent helper Green passed 91 assertions before review strengthening;
the byte-proof strengthening rerun passed 101. These are retained in green-reviewed and
green-byte-reviewed logs, not substituted for the final run. Writer's earlier TS01-03
smoke hit sandbox permission denial creating the Windows junction; final reviewed execution
exercised TS04 successfully. Fake-home/Git/junction runs used reviewed permissions only for
already-authorized offline fixtures, never actual homes, repository Git or network.

Baseline versus post stdout is byte-identical for WEB, TE, AC, AE and AM; GD retains the
same 33-invocation summary. AST assertion-inventory comparison preserved all original AC/AE/AM
call texts and all WEB/TE/GD scenario assertions; only three inline cleanup assertions moved
into Remove-TestSandbox. Exact source review also preserved CASE comments, expected-result
explanations, parameter flags, TE child Git-lock policy, Git child configuration policy,
AM source-file hashes, restoration/no-effect assertions and local final-payload proof logic.
Narrow copies retain config=true for WEB/TE/GD10 and false for GD06; public AC/AE/AM copies
retain their original public-root-document and docs exclusion boundary.

GD HelperOnly, PackageOnly, ReleaseOnly and GitSafetyOnly are preserved selectors of branches
already executed by its default suite; they were source-reviewed, not separately executed.
Early source-check flags remain in source and were reviewed; they were not reported as
additional passing runs. The approved affected-mode matrix adds only distinct TE synthetic
guard and fake-home branches, not redundant default subsets.

Independent review identified two P2 gaps, now resolved within assigned ownership:

1. TS02 decoded-text checks did not prove representation bytes, and its source fingerprint
   started after copies. Tester now captures original source hashes/fingerprint before all
   four copies, compares every destination against those hashes, explicitly checks BOM/CRLF
   bytes, and checks source identity after copying. Final helper suite passed 101 assertions.
2. Helper cleanup parent comparison used a case-insensitive PowerShell operator on non-Windows.
   Writer changed only that comparison to Windows OrdinalIgnoreCase / other Ordinal; Tester
   added an absent case-swapped-parent refusal without creating any outside directory.
   The final Windows run explicitly marks that non-Windows native assertion not applicable.

Final helper SHA256:
`FE51AAE8EDD6B8C944C9B8BC3CC8428A69BE46C4B3745A4DF3B1F465F2BEB0F3`.
Final helper and three TE guard JSONs captured this exact hash both before and after execution.
Earlier nine consumer-run helper hashes are **unknown**, because that runner version did not
capture them. Do not retrospectively assign the final hash to those runs. Their last JSON
timestamp was 2026-10-10 14:41:32 UTC; the platform-only helper edit was 14:41:50 UTC, so no
consumer copy/fingerprint run crossed the edit. The actual observed Windows paths used the
same GetTempPath-derived canonical parent; both old and new comparisons accept those exact
strings. Process/copy/fingerprint bytes and all other cleanup guards were unchanged. Lead
and Reviewer accepted this bounded reuse/source-review rationale; it is not a blanket claim
that culture-sensitive and ordinal comparisons are equivalent. Final helper/TE guards bridge
the changed entrypoint, while non-Windows native execution remains unverified.

Tester readability/comment check: all new scenario blocks explain purpose and expected
outcomes; exact literals remain intact and no line exceeds120 characters. Existing formatter
Plan returned needs-selection with formatter=null/configPaths=[]; no formatter was introduced
or downloaded, so configured formatter Check is unavailable. AST checks are syntax evidence,
not behavioral acceptance. Lead reported the independent Reviewer closed both P2 findings
and found no remaining material issue after reading the final helper and three guard logs.
Full-suite, performance and actual Agent evaluation were outside
the bounded contract; no runtime savings are claimed.

## Human verification script

### Preparation

1. Read the frozen test/helper diff and retained logs.

### Happy path

1. M01: verify original consumer CASE identities, flags and exact expected outcomes remain.
   Expected result: common mechanisms change without weakening scenario assertions or consumer evidence.

### Recommended edge cases

1. Inspect TS01 literal arguments/env and TS04 wrong-target refusal evidence.
   Expected result: no shell evaluation, parent-environment mutation or foreign cleanup.
2. Inspect distinct narrow/public copy manifests and restoration assertions.
   Expected result: original copied-source boundaries and byte guarantees remain.

### Result

- Selected automated checks passed with the provenance/platform limits above. Final manual
  acceptance remains pending. Keep this packet active; do not archive it as user acceptance.
