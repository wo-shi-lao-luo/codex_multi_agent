# Verification: QA user perspective

Packet schema version: 2
Stage slug: qa-user-perspective
Contract status: frozen-source package verification and independent source walkthrough complete; native/manual acceptance pending
Final manual status: manual pending
Final manual evidence:

## Stage context

Objective: QA uses authoritative inputs, observable expected results and evidence provenance; observes bounded user-facing issues beyond assigned cases; distinguishes defects, questions and suggestions; routes repairs through Lead and original engineer; verifies actual fixed revisions; separates QA verdict from existing status and user acceptance. Preserve light-path proportionality, budgets, authority and existing roles/artifacts.
Authority and ownership: Lead's approved QA guidance task. /root/proportional_tests reuses exact team-tester assignment and owns only this packet; Lead owns integration and protected _work/qa-user-perspective. No production, public-document or test-source edits, scratch files, children or external actions by Tester. Existing dirty changes remain intact. Loaded role/model identity is unreported.
Discovery: existing scripts/validate.ps1 is the real distribution consumer; tests/helpers/package-test.ps1 supplies PublicDocs+config copying, literal argv process capture, complete fingerprints and bounded GUID-temp cleanup. Existing stage-verification.ps1 Validate checks schema2 packets. This material harness guidance uses separate writer, Tester and independent Reviewer, with no executable classifier or product UI/runtime change.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| QA-01 | QA task with approved requirements and apparent HTTP 200/toast success | Establish oracle/provenance, then inspect persisted/read-back/reload business outcome | Expected results come from authority; superficial success is insufficient when actual business outcome fails | happy |
| QA-02 | Assigned cases pass but adjacent user journey shows an issue | Inspect bounded relevant user-facing behavior | Record material observation within scope/budget without blanket exploration or new scope | alternate |
| QA-03 | Clear regression, uncertain behavior and taste preference coexist | Classify each observation | Defect, question and suggestion remain distinct; do not turn preference into failure | edge |
| QA-04 | Reproducible defect or intermittent failure | Capture smallest useful evidence and observed attempts | Include revision, conditions, steps, expected/actual result and impact; no invented frequency or mandatory deterministic reproduction/root cause before reporting | edge |
| QA-05 | Clear authorized defect including UI/UX | Send evidence through Lead to original engineer | Engineer owns repair; Tester edits no production; no unnecessary user gate for clear in-scope correction | happy |
| QA-06 | Ambiguous requirement, historical behavior, scope expansion or taste | Identify missing authority | Ask user through Lead for substantive choice; preserve independent work | alternate |
| QA-07 | Engineer reports a fix | Track finding owner/disposition/retest decision, identify fixed revision and verify | Retest actual fixed inputs and relevant regressions; no stale passing evidence or blanket suite | happy |
| QA-08 | QA finishes with findings or evidence gaps | Report QA verdict, lifecycle status and acceptance separately | Quality advice does not change packet Final manual status, user acceptance or release authority; unknown stays unknown | edge |
| QA-09 | Eligible light path, limited budget or unavailable environment | Select proportionate checks and conditional roles | No forced full packet/tests/new role/report; retain existing stage/manual obligations and budget/authority limits | alternate |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No executable classifier or algorithm change. |
| integration | required | Actual copied package validator checks distribution. |
| contract/API | required | Existing link/resource and schema2 packet contracts preserved. |
| E2E | required | All QA cases mapped to future controlled agent observations; source review cannot prove runtime decisions. |
| regression | required | One final intact package pass plus complete nonmutation check. |
| manual | required | User-perspective judgment and acceptance require observed evidence. |
| component/UI | not applicable | Guidance concerns UI findings but no real product UI is changed or tested. |
| accessibility | conditional | Relevant findings remain valid QA observations; no product controls implemented. |
| visual regression | not applicable | No rendered product or visual baseline change. |
| performance/load | not applicable | No runtime cost/speed assertion. |
| security | conditional | QA evidence and repair authority assessed semantically without sensitive external actions. |
| compatibility | required | Existing packet statuses, roles and installed references preserved. |
| data migration/rollback | not applicable | No persisted schema/data migration. |
| resilience/recovery | conditional | Intermittency/evidence gaps must not invent frequency or passing results. |
| exploratory/usability | required | Independent bounded source walkthrough covers user-perspective and taste/scope boundaries. |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Guidance references and package compatibility | Broken route or metadata prevents consuming shared rules | integration | test-after | QaPerspectivePackage.Intact | not applicable | One actual copied validator exit0; 158-file fingerprint unchanged; validated GUID fixture removed and absence confirmed | not needed; no executable refactor | Instruction-only change reuses existing real validator after source freeze; no new deterministic production behavior | proportional_tests | passing |
| QA classification, evidence, repair routing and closure authority | Observation bypasses scope, engineer ownership or user acceptance | E2E | manual-or-environmental | QaPerspectiveE2E.QA-01 through QA-09 | not applicable | planned | not needed; no executable refactor | Policy judgment has no executable classifier; independent source walkthrough now and controlled native forward runs later | Reviewer; Lead/user for runtime | manual pending |

## Automated test and E2E plan

Before writer GO: validate this filled packet. After Lead freezes production and paired public documents: one literal inline PowerShell runner reuses existing tests/helpers/package-test.ps1; Copy-TestPackage PublicDocs with config to an exact OS-temp GUID child, Get-TestFingerprint before/after, Invoke-TestProcess on copied scripts/validate.ps1 exactly once, assert exit0 and byte equality, Remove-TestSandbox only the owned prefix/GUID root and explicitly confirm absence. Record snapshot aggregate SHA256, relevant reference/validator/helper hashes, runtime/Kit version, actual result and cleanup. No repository scratch artifact, network, install, Git mutation, prose classifier, negative suite or real product browser test. Forecast unknown; final draft is the due checkpoint.

Independent Reviewer walks QA-01 through QA-09 against frozen source. Native forward runs belong to Lead/user, remain planned/manual pending, and are triggered by controlled future tasks using final guidance. Flush relevant runtime cases before claiming actual agent adherence; source review is not live E2E or human acceptance. No application AI-specific judging is assigned here. Canonical packet stays versionable; generated-artifact protection for Lead's WorkPath does not authorize Tester scratch writes.

### Manual-to-automated coverage mapping
| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| QA-01 | QaPerspectiveE2E.QA-01 inspect oracle/provenance and contrast HTTP 200/toast with persisted/read-back/reload business outcome | Source walkthrough; distribution checks are supplementary | planned | Native behavior pending |
| QA-02 | QaPerspectiveE2E.QA-02 bounded adjacent user-journey observation | Source walkthrough | planned | No real product fixture |
| QA-03 | QaPerspectiveE2E.QA-03 classify defect/question/suggestion | Source walkthrough | planned | No synthetic classifier |
| QA-04 | QaPerspectiveE2E.QA-04 reproducible/intermittent minimum evidence and attempts | Source walkthrough | planned | No invented reproduction or frequency |
| QA-05 | QaPerspectiveE2E.QA-05 Lead routes clear code/UI/UX defect to original engineer | Source walkthrough | planned | Native routing unobserved |
| QA-06 | QaPerspectiveE2E.QA-06 ambiguous/history/scope/taste user decision | Source walkthrough | planned | No inferred approval |
| QA-07 | QaPerspectiveE2E.QA-07 actual fixed revision retest and affected regressions | Source walkthrough | planned | No actual product repair claimed |
| QA-08 | QaPerspectiveE2E.QA-08 verdict/status/acceptance separation | Existing packet Validate plus source walkthrough | planned | User acceptance remains pending |
| QA-09 | QaPerspectiveE2E.QA-09 light-path/budget/environment proportionality | Source walkthrough | planned | No forced extra report/roles or budget expansion |

## Human verification script

### Preparation
Use a disposable task fixture and final guidance; preserve approved requirements, observed revision, environment and actual check evidence. Do not create production defects, change credentials or expand authority for a test.
### Happy path
1. QA-01/QA-02: supply approved requirements and a flow that returns HTTP 200 or a success toast but loses its result on read-back/reload; then present an adjacent relevant user-flow issue. Expected: authoritative oracle/provenance and final persisted business outcome are checked, superficial success does not pass the failing journey, and adjacent observation stays bounded.
2. QA-05/QA-07: present a clear authorized UI/UX or code defect and then a fixed revision. Expected: Lead routes to original engineer, finding owner/disposition/retest decision remains visible, Tester avoids production edits, and actual fixed revision plus affected regressions are verified.
### Recommended edge cases
1. QA-03/QA-06: mix a clear defect, ambiguous/history behavior, scope expansion and preference. Expected: distinct defect/question/suggestion classification; user decides missing substantive authority.
2. QA-04: provide one observed intermittent failure and successful attempts. Expected: minimal useful evidence with actual attempts, no invented frequency, and no deterministic reproduction/root-cause prerequisite for reporting.
3. QA-08: finish with missing environment or unresolved findings. Expected: QA quality advice remains separate from supported lifecycle/Final manual status, user-only acceptance and release authority.
4. QA-09: use eligible light scope and explicit budget limits. Expected: proportionate existing records/checks with retained required stage/manual obligations; no unconditional full suite/new role/report.
### Result
Manual pending. Remove only owned disposable fixtures after recording observations; source/package checks do not certify native workflow execution.

## Verification record

Coverage prepared and packet validated exit0 before writer release; later QA-01 clarified actual business outcome and QA-04/07/08 clarified intermittent evidence, finding disposition and advisory authority without adding cases or claiming runtime execution. Reused /root/proportional_tests team-tester handle; no child agents; loaded role/model identity unknown. Capabilities used: testing-engineering Skill and team-core acceptance/TDD/generated-artifact/readability contracts for planning; local PowerShell tools and existing package helpers for discovery/validation; apply_patch for this assigned packet. No production/public/test-source changes, network, install or Git mutation.

After Lead declared all five normative files and four public documents frozen, Tester ran exactly one final isolated real package validator. Inline PowerShell dotsourced tests/helpers/package-test.ps1, copied actual working-tree source with Copy-TestPackage Profile PublicDocs and IncludeConfig true into an absolute OS-temp GUID child, fingerprinted all copied files, then invoked copied scripts/validate.ps1 once through Invoke-TestProcess with literal `-NoProfile -File` arguments and GIT_OPTIONAL_LOCKS=0. Validator exited0 and reported Codex Team Kit validation passed. Complete before/after fingerprint matched exactly. Remove-TestSandbox verified the exact absolute direct-temp child with prefix codex-qa-perspective-test- and GUID b290bd9d25c64bdb9a181906bbf2ee02, removed only that fixture, and explicit Test-Path confirmed absence; outer runner exited0. No other suites, browser/product checks, negative loops or installation ran.

Snapshot provenance: Lead-reported baseline HEAD 4a66992 with current task working-tree edits, not a claim of clean commit or installed payload; Kit 1.0.8, PowerShell 7.6.5, 158 copied files. PublicDocs profile copied agents, skills, scripts, config, VERSION, root Markdown and included docs; existing helper excludes local governance/superpowers and does not copy unrelated _work. Aggregate SHA256 of the UTF-8 complete ordinal fingerprint manifest: a051467409f4d0e0b95327f3afa6a00f033115dd87b861e99091c9030b1c9b8f. Copied validator SHA256: 77c254c8eb5aa136f034fddbe1634883e1f5a717c241f3eb2fd8f704343ba723. Existing helper SHA256: 8f6183f62774d323779fdc96dfa7be9b08ef92d1d8f48b9fe4feb0890dcbe609. Later packet evidence edits change included documentation bytes; the tested-copy digest identifies that snapshot and is not a claim that all final reporting bytes remain identical.

The canonical QA guidance is a new section of existing skills/team-core/references/test-acceptance-contract.md, not a newly named QA reference file. Final frozen source hashes read after copied validation: test-acceptance-contract.md d1f970d0fef8a582e8f68b580f07b3e9da030d917ecade35737a8cdf5989e332; skills/testing-engineering/SKILL.md 4ad102d1c50276e7329f38b04a695c25c12a772551c53c3a1c69c1341feccaa3; agents/team-tester.toml c28b54f81cb5e9c008500446962b4b688ab1b3d19d3b2fdb5d7cc5bd4e657d92; skills/team-core/references/ui-quality.md 431f5e0fdc2a762d89a2fc1adc3804625f2ef372a1285bb599a5c777615552c2; skills/team-dev/SKILL.md 48fb96eb2840ec00aaa32c5b10fd98ec65970b3bb31edf587e7a15b95b54b2fd. Lead confirms production inputs remained frozen; no source delta or repeated package check occurred.

Actual reused roster supplied by Lead: /root/proportional_writer selected team-docs-maintainer completed/frozen; /root/proportional_tests selected team-tester completed focused package/packet checks; /root/proportional_review selected team-reviewer completed independent source-forward QA-01 through QA-09, five normative files and four public documents with no material findings. That review inspected meanings and links, and claimed no tests/native execution. Lead separately reports required bilingual validator and isolated bilingual suite passed with owned fixture removed, plus Work/Documentation Protect and Check clean with no rules added; these are Lead checks, not Tester execution.

Comment/readability self-check: no production or test code authored; existing helper comments/interfaces and literal-argv safety were reused unchanged. Packet scenarios, expected outcomes and manual/E2E mappings were checked for consistency, preserving nine case purposes and supported statuses. No formatter/configuration change or formatter pass claimed. Updated testing-engineering Skill and canonical QA section were read after freeze; actual package results establish resource/link/metadata compatibility only. No full-category product tests are required or claimed for this instruction change.

Final packet command: `pwsh -NoProfile -File skills/team-core/scripts/stage-verification.ps1 -Action Validate -ProjectRoot . -StageSlug qa-user-perspective`. Native QA-01 through QA-09 stay manual pending: no live QA decisions, product persistence flow, intermittent reproduction, engineering repair or user acceptance was executed. Source walkthrough is not executed E2E. No retrospective Red, role/model identity claim, new schema/status/mandatory report, or unmeasured saving is introduced. Lead may take only this Verification record for final integration after Tester freeze.
