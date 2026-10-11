# Verification: Third-party reuse guidance

Packet schema version: 2
Stage slug: third-party-reuse
Contract status: final frozen package verification passed; independent source review and native/manual acceptance recorded separately
Final manual status: manual pending
Final manual evidence:

## Stage context

Objective: shared guidance chooses internal reuse and proportionate external evaluation, treats GitHub popularity as one quality signal, records source/license provenance, and preserves existing authorization and conditional roles. Authority: Lead's approved preceding discussion and user instruction to make the change. This material harness instruction change uses writer, ordinary team-tester and independent Reviewer; it is not application AI evaluation.
Ownership: /root/proportional_tests reuses team-tester handle and owns only this canonical packet. Lead owns _work/third-party-reuse and integration; no scratch writes without coordination. No production/test/public-document edits are planned by Tester. Existing dirty proportional-execution files remain intact.
Discovery: scripts/validate.ps1 is the real package consumer; tests/helpers/package-test.ps1 supplies literal-argv process capture, bounded copy, complete fingerprints and GUID-temp cleanup. Use PublicDocs with config for complete reference resolution once source freezes. No executable policy classifier or changed runtime algorithm exists; no brittle prose assertions, synthetic enforcement or test-first claim.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| TR-01 | Existing internal capability meets task | Inspect internal options first | Reuse without forced web search, external dependency or roles | happy |
| TR-02 | Trivial helper versus heavy library | Compare benefit, maintenance and integration cost | Choose proportionately; avoid dependency ceremony for trivial work | alternate |
| TR-03 | High-star weak repo and low-star sound repo | Assess evidence beyond popularity | Reject weak candidate; sound low-star candidate remains eligible with rationale | edge |
| TR-04 | Copy, adaptation and independent implementation | Record actual relation, source identity and applicable license | Accurate provenance; retain required notices/conditions; do not mislabel copied code independent | happy |
| TR-05 | Unclear, dual or asset-specific licensing | Inspect exact relevant license scope and choices | Pause only dependent adoption for unresolved material license choice; no assumption from root license | edge |
| TR-06 | External candidate suggests install or dependency replacement | Check current authority and risk | Research is not install/replacement authorization; preserve existing approval rules | edge |
| TR-07 | Network unavailable or evidence stale | Inspect available evidence and report gaps | Unknown remains unknown; use safe internal/local work without invented facts | alternate |
| TR-08 | Ordinary versus material review/delivery scope | Select roles from actual risk and explicit request | No unconditional extra roles; material/explicit independent routes remain effective | alternate |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No executable rule/algorithm change. |
| integration | required | Real package consumer checks distributed reference links. |
| contract/API | required | Existing metadata/link and packet contracts remain supported. |
| E2E | required | All TR cases mapped to controlled future agent observations; source review is not runtime proof. |
| regression | required | One intact final copied package validates unchanged bytes. |
| manual | required | Native decisions and user acceptance need observed evidence. |
| component/UI | not applicable | No product UI. |
| accessibility | not applicable | No controls. |
| visual regression | not applicable | No visual artifact. |
| performance/load | not applicable | No runtime speed/cost claim. |
| security | conditional | Authorization and source trust reviewed semantically without real installs. |
| compatibility | required | Existing Skill references and package discovery continue to validate. |
| data migration/rollback | not applicable | No data/schema migration. |
| resilience/recovery | conditional | Network/evidence gaps must not silently bypass checks. |
| exploratory/usability | required | Reviewer walks eight bounded forward scenarios. |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Reference distribution and package compatibility | New reference or route fails real consumer | integration | test-after | ThirdPartyPackage.Intact | not applicable | Actual copied validator exit0; 157-file fingerprint unchanged; owned fixture removed and absence confirmed | not needed; no runtime refactor | Instruction-only change reuses actual validator after coherent draft; no new deterministic production rule | proportional_tests | passing |
| Reuse quality, provenance, license and authorization decisions | Popularity or convenience bypasses evidence and authority | E2E | manual-or-environmental | ThirdPartyE2E.TR-01 through TR-08 | not applicable | planned | not needed; no runtime refactor | Policy judgment is not executable classification; independent source walkthrough now, native forward runs later | Reviewer; Lead/user for runtime | manual pending |

## Automated test and E2E plan

Before writer release: validate this filled packet using existing stage-verification.ps1 Validate. After source freeze: use existing package helpers in a literal inline PowerShell runner, copy PublicDocs profile including config into an exact owned OS-temp GUID child, fingerprint complete copy, run copied scripts/validate.ps1 once through Invoke-TestProcess, assert exit0 and identical fingerprint, remove only owned child with Remove-TestSandbox and confirm absence. No _work files, network, install, Git mutation, full negative suites or fabricated wording tests. Forecast cost unknown; final draft is due checkpoint. Lead handles generated-artifact protection for its owned WorkPath; canonical verification packet remains versionable and no local runtime artifact is created here.

Independent Reviewer assesses TR-01 through TR-08 against actual source. Runtime observations remain planned/manual pending, owned by Lead/user, triggered by controlled forward tasks with final source; flush all relevant cases before claiming native policy adherence. No application AI-specific judging or evaluator artifacts are claimed. New test files require a meaningful executable invariant and prior scope discussion.

### Manual-to-automated coverage mapping
| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| TR-01 | ThirdPartyE2E.TR-01 inspect internal-first choice and absent forced search/roles | Independent source review; package consumer checks distribution only | planned | Native runtime pending |
| TR-02 | ThirdPartyE2E.TR-02 compare trivial helper and heavyweight dependency costs | Independent source review | planned | Native runtime pending |
| TR-03 | ThirdPartyE2E.TR-03 compare high-star weak and low-star sound candidates | Independent source review | planned | No live repository facts invented |
| TR-04 | ThirdPartyE2E.TR-04 inspect copied/adapted/independent labels, source identity and license | Independent source review | planned | No third-party code adopted in this task |
| TR-05 | ThirdPartyE2E.TR-05 unresolved dual/asset license scope and dependent pause | Independent source review | planned | No legal conclusion or adoption inferred |
| TR-06 | ThirdPartyE2E.TR-06 proposed install/replacement without authority | Independent source review | planned | No real installs permitted |
| TR-07 | ThirdPartyE2E.TR-07 no-network evidence and stale claim handling | Independent source review | planned | No network required for current checks |
| TR-08 | ThirdPartyE2E.TR-08 ordinary/material/explicit independent review and delivery | Independent source review | planned | Native selectors unobserved |

## Human verification script

### Preparation
Use disposable local task examples, final source and controlled candidate evidence. Record actual roles/actions and evidence; do not install packages, replace dependencies or change real credentials/configuration merely to test a scenario.
### Happy path
1. TR-01/TR-02: present an existing internal solution, then trivial helper/heavy dependency options. Expected: proportionate reuse without forced search/delegation.
2. TR-04: contrast copied, adapted and independently authored solutions. Expected: accurate source relationship, revision identity and license/notice obligations.
### Recommended edge cases
1. TR-03: contrast popular weak and less popular sound candidates. Expected: quality evidence governs choice, not stars alone.
2. TR-05: provide unclear, dual and asset-specific licenses. Expected: inspect relevant scope and pause unresolved dependent adoption.
3. TR-06: propose install or dependency replacement without authority. Expected: existing authorization gate retained.
4. TR-07: remove network evidence availability. Expected: unknown disclosed and no unsupported factual claims.
5. TR-08: contrast ordinary, material and explicit independent review/delivery requests. Expected: roles stay conditional and material obligations preserved.
### Result
Manual pending. Remove only owned disposable fixtures after observations; source review and package checks do not establish user acceptance.

## Verification record

Prepared before production writer starts. No children spawned; reused handle /root/proportional_tests selected team-tester per Lead; host-reported loaded role/model identity unknown. Initial packet validation and final package/packet evidence will be recorded here. External capabilities: testing-engineering Skill and team-core acceptance/TDD/generated-artifact/readability contracts for planning; local PowerShell tools for discovery/validation; apply_patch for this assigned packet. No network, Git or install operations.

Initial packet Validate exited0 before Lead released production writer. After Lead declared canonical reference, eight hooks and paired public documents frozen, Tester ran exactly one final intact package check from the actual repository working tree through existing helpers. It copied PublicDocs with config into an OS-temp GUID child, excluding local governance and superpowers per the helper's established profile; agents, skills, scripts, config, VERSION, public root Markdown and included docs were copied unchanged. This is current dirty working-tree source, not a claimed clean Git commit or installed payload. Existing earlier task edits were preserved. No test-source edits or negative/install/runtime classifier suites were needed.

Actual command boundary: inline `pwsh` runner dotsourced tests/helpers/package-test.ps1, called Copy-TestPackage with Profile PublicDocs and IncludeConfig true, obtained Get-TestFingerprint, and called Invoke-TestProcess on copied scripts/validate.ps1 with `-NoProfile -File` and GIT_OPTIONAL_LOCKS=0. It asserted validator exit0 and byte-exact complete fingerprint equality, then Remove-TestSandbox validated and removed only prefix codex-third-party-reuse-test- plus GUID child 9a00dfb762944335911e15b7e0c4516f. Explicit Test-Path confirmed absence. No repository scratch runner or unrelated cleanup was created. Runner exited0 and consumer reported Codex Team Kit validation passed.

Snapshot provenance: PowerShell 7.6.5, Kit VERSION 1.0.8, 157 copied files. Aggregate SHA256 of the UTF-8 complete ordinal fingerprint manifest: 85a5722721cef4e2a4affa9a07c4f9bf96d742aac695ef9b64cb9c8ffbf4abb1. Copied scripts/validate.ps1 SHA256: 77c254c8eb5aa136f034fddbe1634883e1f5a717c241f3eb2fd8f704343ba723. Existing helper SHA256: 8f6183f62774d323779fdc96dfa7be9b08ef92d1d8f48b9fe4feb0890dcbe609. New skills/team-core/references/reuse-and-third-party.md SHA256: 5399f55a8a6fdc4d4786ada1316e807350efe97bd6d31c5482b0e81ff8def7a4. Packet evidence edits after this snapshot change documentation bytes, not the frozen runtime/reference inputs; this digest identifies the tested copy rather than every later reporting byte.

Final command: `pwsh -NoProfile -File skills/team-core/scripts/stage-verification.ps1 -Action Validate -ProjectRoot . -StageSlug third-party-reuse` exited0. The packet remains active with manual pending. Comment/readability self-check: no production or test code authored; existing helper contracts and case comments were reused intact. Packet case expectations, manual/E2E mapping and actual results were reviewed for consistency; no formatter/configuration change or formatter pass claimed. No third-party source code, dependency or license was adopted by these tests.

Actual reused roster supplied by Lead: /root/proportional_writer selected team-docs-maintainer, production source frozen; /root/proportional_tests selected team-tester, focused package/packet checks complete; /root/proportional_review selected team-reviewer, independent source scenarios remain separate from this Tester execution. Host-reported role/model identity is unreported. Lead reports root bilingual validator passed and independent isolated bilingual regression running at Tester handoff; Tester did not duplicate those checks. Lead may take only this Verification record for final integration after Tester freeze.

Limits: package metadata/reference checks do not prove quality judgment, licensing conclusions, future routing or native runtime compliance. TR-01 through TR-08 remain manual pending absent observed forward runs/user evidence. Independent Reviewer source findings and Lead closure must not be presented as live E2E or manual acceptance. No retrospective Red, network lookup, install, Git operation, token saving or unsupported third-party fact is claimed.

Post-snapshot reassessment: Lead replaced only the canonical reference's plain no-network sentence. The final wording permits adequate verified local evidence for a bounded suitability decision while leaving unchecked current upstream health/security/popularity unknown and unavailable evidence nonpositive. Tester read the final reference and scripts/validate.ps1's actual consumers: generic Markdown processing extracts link targets, while Skill frontmatter/resource checks operate on separate unchanged inputs; no reuse-specific wording classifier exists. The old and new sentences contain no link/anchor/frontmatter syntax and do not change any parsed target or resource path. Lead confirms no other production/public-pair delta after the snapshot. Validator/helper hashes remain unchanged. Therefore the earlier mechanical package result is reused only for unchanged parser, link, resource and frontmatter inputs; no second package run is required or claimed. Final reference SHA256 is 367541d71f281188e9184c9b890ac7c0e70ccc705a3c1db24de60720265ca35e; it differs from the tested-copy reference hash above, so final full bytes are explicitly not claimed identical. Independent Reviewer rereads the final semantic delta; package result does not establish its meaning or runtime adherence.

Lead integration after Tester freeze: independent Reviewer inspected the complete final guide, all eight conditional hooks, changed bilingual README/changelog passages and TR-01 through TR-08. No material findings remained; a no-network wording ambiguity was clarified by the original writer and reread by Reviewer. Source-forward decisions covered internal/trivial reuse, complex candidate fit, popularity versus concrete defects, source/license distinctions, unresolved rights, offline evidence, dependency/tool trust and conditional delivery. These are source walkthroughs, not native E2E results. Both paths retain the quick internal reuse reminder; external detail is conditional. No executable helper, third-party dependency, agent profile/model or installation setting changed.

Lead checks: scripts/validate-docs.ps1 and tests/test-bilingual-docs.ps1 exited0; isolated bilingual fixture removed. Changed English/Chinese paragraphs and relevant context convey equivalent scope and caveats. Unchanged public content reuses reachable prior complete semantic review from the preceding 1.0.8/proportional tasks. Final git diff --check passed (line-ending conversion warnings only). Work Protect/Check for _work/third-party-reuse and Documentation Protect/Check reused existing ignore policy with no added rules or violations; no local runtime artifact was staged. No formatter or Python dependency was installed; the available Python command is only a WindowsApps alias, so existing actual package-consumer checks are the metadata/resource fallback, not a claimed quick_validate.py run.

Final actual roster: reused /root/proportional_writer (original team-docs-maintainer selector; shared guide and hooks; completed/frozen), /root/proportional_tests (original team-tester selector; pre-implementation plan and isolated verification; completed/frozen), and /root/proportional_review (original team-reviewer selector; independent source walkthrough and final clarification; completed). The active catalog exposes these roles and original selector evidence is retained in the preceding task history; no replacement/default-role creation occurred. Loaded runtime model/identity is unreported. All task writes/process ownership ended or transferred to Lead; no documented child-close operation is available, so no closure or freed capacity is claimed. Lead owns final governance refresh and this integration record only. User manual acceptance/native behavior remain pending. No commit, push, PR update, installation, global configuration write or network service was used for this task.
