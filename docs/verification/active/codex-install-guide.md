# Verification: Codex local installation guide

Packet schema version: 2
Stage slug: codex-install-guide
Contract status: active
Final manual status: manual pending
Final manual evidence: No actual user-home installation or fresh-client activation observed.

## Stage context

Objective: Add a Codex-facing local installation guide and discovery entrypoints.
Scope: docs/codex-install.md, approved narrow AGENTS routing, brief bilingual README navigation, paired 1.0.5 release records, VERSION and four helper version literals only. No installer algorithm, global configuration, actual installation, network or paid operation changes.
Owners: Docs owns guide/routing/public pairs/VERSION; Backend owns four metadata literals; Tester owns this packet; Lead integrates and requests independent post-freeze review.
Plan established before implementation: use existing repository PowerShell checks; no new test script or prompt keyword tests. Semantic decision walkthrough checks instructions against native wrapper/deployer contracts. Protect Work/Documentation completed by Lead before this packet was created. No active PRD, Blueprint or refactor is introduced by this bounded documentation task.
Environment/test data/cleanup: PowerShell 7; bilingual suite creates and removes its own temporary fixture. No credentials, real-home writes or install command execution. Keep this one packet active until user acceptance or explicit deferral.

## Use-case map

| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| CI-01 | Kit not installed; user supplies GitHub URL only | Read remote instructions, obtain approved fresh checkout or verified existing reuse, then reread local instructions | Human prompt needs no manual clone prerequisite; AI guide is reachable without installed Skills; no forced overwrite; selected local instructions govern execution | happy |
| CI-02 | Fresh target or managed existing installation | Select install/update and preview before applying | Explicit authorized write follows preview; update uses current wrapper; no automatic Force or stable promotion | happy / alternate |
| CI-03 | Conflict, requested Git ref or dirty checkout | Follow source-selection and conflict branches | Preserve unknown/personal content and dirty source; explain Force scope; no checkout/reset/fetch implied | edge |
| CI-04 | Missing prerequisites or optional config needs | Check PowerShell, paths and configuration boundary | Stop with concrete prerequisite; global config is separately reviewed/authorized, not silently merged | edge |
| CI-05 | Files installed but conversation already active | Verify disk and start fresh task/client as needed | Verify proves managed bytes only; current session loading remains separate and honestly reported | edge |
| CI-06 | Reader starts from README/AGENTS or release history | Follow guide links and compare languages/version | Narrow local-install route; brief paired entries, exact technical parity and matching 1.0.5 release | happy |

## Coverage-category decisions

| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No new algorithm; metadata literals do not need implementation-mirroring tests. |
| integration | required | Package and bilingual command boundaries validate distributed metadata and paired public docs. |
| contract/API | required | Read guide command parameters against native wrappers; no product API exists. |
| E2E | required | CI-01 through CI-06 include actual install/activation journey; manual pending in this task. |
| regression | required | Existing bilingual suite checks technical drift and read-only validation. |
| manual | required | User confirms real homes and fresh-session loading separately from source inspection. |
| component/UI | not applicable | No product controls or browser-rendered interface changes. |
| accessibility | not applicable | No rendered controls changed. |
| visual regression | not applicable | Markdown navigation only; no visual acceptance requirement. |
| performance/load | not applicable | No runtime performance change. |
| security | required | Inspect authorization, conflict and optional global-config boundaries; no live writes. |
| compatibility | required | AST-parse four helpers and verify version-only diff; native behavior unchanged. |
| data migration/rollback | conditional | Explain existing safe-deployment recovery authority; no migration or rollback performed. |
| resilience/recovery | conditional | Guide must route failed/conflicting deployments to native inspection/recovery guidance. |
| exploratory/usability | required | Bootstrap and discovery instructions must be understandable without installed Kit. |

## TDD behavior matrix

| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Guide decision paths CI-01 through CI-05 | Unsafe or circular bootstrap and false activation claims | security / E2E | manual-or-environmental | Semantic.CI-01 through CI-05; LocalInstallE2E.CI-01 through CI-05 | not applicable | Semantic source walkthrough complete; actual E2E unexecuted | No production refactor | Real homes/client are outside this source-only task; native contracts inspected; retain actual E2E pending | Tester / user | manual pending |
| Discovery and paired release CI-06 | Broken navigation or technical language drift | integration / regression | test-after | validate-docs.ps1; test-bilingual-docs.ps1; Semantic.CI-06 | not applicable | Final frozen-source commands exit0; complete-pair meaning/navigation inspected | No production refactor | Existing checks cover final authored documents; semantic parity inspected separately from structural pass | Tester / Docs | passing |
| Package and version-only helpers | Syntax/package drift or unexpected behavior change | compatibility | test-after | validate.ps1; MetadataAST.FourHelpers; scoped diff review | not applicable | Package exit0; four AST parses clean; four diff changes are version literals only | No production refactor | Existing algorithm unchanged; post-freeze parser/package checks plus literal-only diff are proportionate | Tester | passing |

## Automated test and E2E plan

Execution entrypoint: PowerShell CLI and source inspection, with concise result output and failure drill-down. No browser/API provides meaningful observation for this Markdown/configuration task. Forecast unknown; no hard budget inferred.

After Lead GO on frozen inputs: run `scripts/validate-docs.ps1 -ProjectRoot .`, `tests/test-bilingual-docs.ps1`, `scripts/validate.ps1`, AST parse documentation.ps1/project-rules.ps1/ai-simulation.ps1/format-code.ps1, scoped whitespace checks and `stage-verification.ps1 -Action Validate -ProjectRoot . -StageSlug codex-install-guide`. Read complete public pairs and guide; verify relative links, actual parameter contracts and metadata-only diffs.

Existing doc-policy/install algorithms and tests are unchanged. Prior doc-consolidation evidence is supplementary baseline only: active packet records documentation suite exit0/186.53s and fake-home installer exit0/178.32s at 1.0.4. Do not rerun those full suites or label old output a current 1.0.5 distribution pass. Relevant new source/pair/package checks run fresh. Reassess if final diff expands beyond approved literals/docs.

| Manual case / requirement ID | E2E scenario and checkpoints | Other layers | Status / gap |
| --- | --- | --- | --- |
| CI-01 | LocalInstallE2E.CI-01: GitHub URL only; remote instructions read; approved fresh clone or verified reuse; local instructions reread; source/homes inspected | Semantic native discovery/bootstrap walkthrough completed | actual client E2E manual pending |
| CI-02 | LocalInstallE2E.CI-02: fresh and existing managed target; preview, authorized apply, verify | Native wrapper parameter inspection completed; prior isolated suite baseline only | actual installation manual pending |
| CI-03 | LocalInstallE2E.CI-03: conflict/ref/dirty state; preserve original data and source; report blockers | Native source/conflict contract inspected | actual E2E manual pending; no Force/write/checkout executed |
| CI-04 | LocalInstallE2E.CI-04: missing prerequisite/config change; concrete stop and separate authority | Guide/native prerequisites/configuration inspected | actual E2E manual pending; no global config mutation |
| CI-05 | LocalInstallE2E.CI-05: disk verifies; existing session versus fresh client loading distinguished | Guide disk/session claims inspected | fresh client activation manual pending |
| CI-06 | LocalInstallE2E.CI-06: README/AGENTS guide navigation and release parity | Fresh doc/bilingual/package checks passed; complete-pair semantic review completed | runtime route adherence manual pending |

## Human verification script

1. Preparation: for later separately authorized actual installation, supply the GitHub URL only; record approved fresh destination or verified existing checkout/ref/dirty state and homes, preserve personal data/configuration; stop active writers. This source task does not grant that future authority.
2. CI-01/CI-06: without an installed Kit or manual clone, copy the short README prompt with actual repository URL. Expected: AI reads remote instructions, obtains approved fresh clone or verified existing reuse without forced overwrite, rereads selected local instructions before execution; narrow route and consistent paired release facts.
3. CI-02: review fresh/install and managed/update preview, then apply only the approved target. Expected: correct homes, package validation and Verify; no automatic Force or stable promotion.
4. CI-03: use disposable conflict/ref/dirty fixtures. Expected: conflicts surfaced before replacement, explicit bounded Force decision, source/worktree preserved and no network fetch implied.
5. CI-04: inspect missing PowerShell/prerequisite and optional configuration paths. Expected: concrete stop or separate reviewed configuration authority, with no implicit global edit.
6. CI-05: compare disk Verify with already-active session and fresh task/client. Expected: byte verification and loaded capability observations reported separately; no unsupported active-model claim.
7. Result/cleanup: record actual user observations here; preserve user originals and remove only exact owned disposable fixtures. Final manual status remains pending until evidence is supplied.

## Verification record

Pre-GO plan and amended URL-first requirement passed stage validation before post-freeze execution. No Red claimed; no new test/code formatter needed. Existing scenario/expected-result explanations remain untouched. No commit/push, child spawning or actual installation by Tester.

Fresh post-freeze evidence: `pwsh -NoProfile -File scripts/validate-docs.ps1 -ProjectRoot .` exit0; `pwsh -NoProfile -File tests/test-bilingual-docs.ps1` exit0 with every controlled drift rejection, successful final checks and reported owned fixture removal; `pwsh -NoProfile -File scripts/validate.ps1` exit0. Parser.ParseFile reported no errors for documentation.ps1, project-rules.ps1, ai-simulation.ps1 and format-code.ps1. Their complete diffs change only four Kit provenance values from 1.0.4 to 1.0.5; policy3, schema and algorithms stay identical. `git diff --check` exit0; nonfatal LF/CRLF warnings reflect existing Git conversion policy. Local guide links resolve to docs/safe-deployment.md; no remote content was fetched by Tester. No clean-index claim is made; Lead owns final actual staging/protection checks.

Semantic walkthrough CI-01: both complete READMEs offer the same actual GitHub URL and copyable request without requiring manual clone; guide separates remote reading, local executor, safe empty destination and selected local instructions. CI-02: install/update wrappers forward WhatIf/Force to the same manager; guide orders validation, preview, authorized application and Status/Verify, stops failed checks and retains consistent custom homes. CI-03: deployer GitRef exports a locally available commit without checkout/fetch; directory source records dirty provenance; selected-unit conflicts fail before writes unless explicitly forced. Guide routes those branches to existing safe-deployment authority rather than silently applying Force, recovery or pruning. CI-04: mandatory PowerShell7/Git and no automatic dependency installation match source; optional config is separately user-managed. Lead's initial Git-prerequisite defect was corrected before frozen-input verification. CI-05: Verify compares receipt-owned bytes, not selected source identity or active-session loading; guide distinguishes package/version/provenance and fresh-client discovery and refuses unsupported role/model claims. CI-06: complete public language pairs preserve equivalent changed facts, navigation, release1.0.5/date/item and technical values; historical records are retained. AGENTS route stays limited to direct installation/update authority. Writer's intermediate bilingual drift failures occurred before restoration and are not reused as final results or new repair loops.

No browser/API meaningful UI observation is available or needed for this Markdown task. Actual user-home install, agent adherence, account availability and fresh-client loading remain manual pending, with no accepted automation exception. Full documentation policy and fake-home installer suites were intentionally not rerun; prior doc-consolidation results are historical baseline only, not a current-source pass.

Independent Reviewer inspected the frozen diff, complete public pairs, guide and native deployment contracts. Its P2 finding was resolved at `docs/codex-install.md`: preview lists unit operations, not source version/commit/dirty provenance. The corrected paragraph checks preview operations and selected homes separately from source identity, then compares installed provenance with post-deployment Status. Focused independent reread confirmed resolution with no remaining material findings. Only that guide paragraph changed after the passing checks; public pairs, package payload and helper metadata remained unchanged, so those results remain applicable. Lead separately reread the correction and will revalidate this finalized packet before handoff. No real installation was performed.

### Actual invocation ledger

| Handle | Actual selected role | Scope | Known state |
| --- | --- | --- | --- |
| /root/install_guide_docs | team-docs-maintainer | Guide, approved routing, paired public docs, VERSION | Complete; production and authored readiness frozen |
| /root/install_guide_tests | team-tester | Initial plan/packet and post-freeze verification | Selected checks complete; final packet frozen after validation |
| /root/install_guide_version | team-backend-engineer | Four Kit version literals only | Complete and frozen |
| /root/install_guide_review | team-reviewer | Independent read-only frozen diff and complete-pair review | Complete; P2 correction independently rechecked |

Lead supplied exact role-selector/handle evidence; all four selected roles are available in the active catalog. Runtime resolved role/model/effort remain unknown. Lead explained the fourth child before creation: independent read-only review requires distinct evidence after production writers freeze; it does not overlap Tester packet or Docs readiness writes. Host Close is unavailable, so completed Backend is not reported as a released slot. No failure/retry or capacity-release operation is reported. Tester spawned no child. Lead owns final review/status reconciliation.
