# Verification: Conditional Designer and optional Impeccable

Packet schema version: 2
Stage slug: optional-designer
Contract status: planned
Final manual status: manual pending
Final manual evidence:


## Stage context
- Objective: conditionally route missing-page UI tasks or explicit user page-design/adjustment requests to Designer; use Impeccable only when actually accessible.
- Authority: approved user discussion in this task. Backend/logic-only work and incidental polish must not automatically invoke Designer. Engineer remains sole production-page owner; Designer supplies concrete proposals or bounded isolated prototypes.
- Scope: role/routing, optional Skill discovery and non-blocking installation/update advice. No product UI, external installs/downloads, hooks, global configuration changes or paid evaluation.
- Environment/data/cleanup: copied real package and explicit fake Codex/Agents homes in unique OS-temp sandbox; shared package-test helper validates owned cleanup and fixture absence. Current catalog lacks new Designer; native behavior cannot be claimed from file inspection.
- Ownership: team-tester owns this packet and tests only. Production writer owns helper/wrappers; docs owner owns guidance. No product AI evaluation introduced. Host-reported runtime role/model identity: unknown.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| OD01 | Missing page in UI task | Inspect baseline and route | Named Designer proposes concrete design; engineer solely owns production page | happy |
| OD02 | Existing page, explicit user design/adjust request, including small adjustment | Route both substantial and small explicit requests; inspect ownership handoff | Designer may create isolated prototype, never concurrently write production page; task size does not bypass explicit intent | happy |
| OD03 | Backend/logic task or incidental polish | Route without explicit design request | No automatic Designer or extra design gate | edge |
| OD04 | Provider accessible, missing, unloaded or child-inaccessible | Inspect installed provider docs before commands | Use verified available commands only; fallback never blocks or overwrites Kit frontend-design | alternate |
| OD05 | Initial install/update to fake homes | Inspect actual wrapper output and receipt | Optional official guidance; no downloads/hooks/global edits or loaded assertion | happy |
| OD06 | Preview or conflicting fake-home deployment | Compare fingerprints and outcome | Preview unchanged and labeled; failed deploy not success; customization preserved | edge |
| OD07 | Copied real source | Validate and install/update isolated package | Role/reference bytes distributed exactly, missing optional dependency tolerated | happy |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | required | Deterministic advisory behavior at coordinated helper interface |
| integration | required | Actual copied installer/updater, fake homes |
| contract/API | required | Package role/reference discoverability and wrapper outcome preserved |
| E2E | conditional | Native routing needs fresh catalog; planned, not passing |
| regression | required | Missing dependency, preview, failed deployment and distribution |
| manual | required | Native ownership, capability availability and advisory clarity |
| component/UI | not applicable | No product component changed |
| accessibility | not applicable | No rendered UI changed |
| visual regression | not applicable | No concrete page baseline changed |
| performance/load | not applicable | No service or performance claim |
| security | required | Fake homes, offline behavior, no unintended writes |
| compatibility | conditional | Current PowerShell host; other OS execution not inferred |
| data migration/rollback | not applicable | No receipt/schema migration; recovery unchanged |
| resilience/recovery | required | Failure/preview preserve files and accurate outcome |
| exploratory/usability | required | Bounded advisory clarity and negative routing inspection |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Conditional routing and single owner | Unwanted spawn or concurrent writes | E2E | manual-or-environmental | OD01-OD03 native cases | n/a | planned | planned | New Designer absent from current catalog; static review cannot prove runtime compliance | team-tester | manual pending |
| Available provider or safe fallback | False invocation or blocker | E2E | manual-or-environmental | OD04 native cases | n/a | planned | planned | Actual loaded capability and command selection need fresh client observation | team-tester | manual pending |
| Advice and delivery safety | Misleading outcome or unintended writes | integration | test-first | OD05-OD07 tests/test-optional-designer.ps1 | Preproduction RedOnly exit1: OD05 optional-capabilities provider is missing | Identical suite outside filesystem sandbox exit0, OD05-OD07 passed | Final copied-package validator exit0 and complete fingerprint unchanged after frontend instruction/setup comment delta | Native role behavior remains separate and pending | team-tester | passing |

Assess unit, integration, contract/API, E2E, regression, manual, component/UI, accessibility, visual regression, performance/load, security, compatibility, data migration/rollback, resilience/recovery, and exploratory/usability.

## Automated test and E2E plan
- Before production GO: coordinated Get-OptionalCapabilityGuidance no-argument static string helper; Red command `tests/test-optional-designer.ps1 -RedOnly` exited1 with OD05 missing provider before production implementation. After owners freeze: one focused copied-package test batch and packet validation; do not run broad suite. Forecast unknown; no external/paid operations authorized. Tester runs public-pair gates after docs freeze, once.
- Native OD01-OD04 stay pending until fresh client exposes actual Designer and optional provider. Source text checks establish discovery, not runtime behavior, design quality or manual acceptance.
- Initial Green attempt: copied validator, provider string/nonmutation and initial WhatIf passed; actual fake-home install failed with `Exception calling Move with 3 arguments: Access to the path is denied`, caller `scripts/install-user.ps1:17` invoking unchanged `deploy-user.ps1`. The emitted stack did not identify which atomic JSON/receipt destination failed; do not infer an exact failed destination. Both candidate transaction operations are inside the owned GUID sandbox fake homes. Cleanup completed and owned root absence confirmed.
- One Lead-approved identical-suite filesystem-sandbox discrimination retry ran outside that sandbox and passed exit0: static optional advice and source nonmutation; actual copied package validator; initial WhatIf absent homes; real fake-home install; exact Designer and optional-reference bytes/receipt membership; updater advisory exactly once; managed preview full-tree nonmutation; customized-file conflict nonzero with no success advice and no fixture-file changes. All fake homes were inside the suite-owned OS-temp GUID root and cleanup/absence assertions passed. The changed execution environment and prior failure are retained, not relabeled as a sandboxed pass. No real homes, external installs or network were used.
- Own-run progress checkpoint found receipt present and the final conflict update running after deliberate Designer customization; healthy progress was observed, not a timeout/stall. Narrow fixture/process observation did not read unrelated task content.
- Late independent-review fixes narrowed the frontend role's routine-polish exemption to requests without explicit design intent and expanded setup contract comments, with no installer logic/test assertion/Designer/reference delta. The earlier isolated install result is reused for those unchanged inputs, not claimed as exact final whole-package evidence. A final fresh PublicDocs/config package copy ran the real validator exit0 and complete before/after fingerprint equality; owned final-validator fixture cleanup and absence passed. No second install batch was needed for that prose/comment-only delta.
- A direct final repository validator attempt also exposed 13 broken links inside unrelated ignored `_work/github-promotion/` partial snapshots. That root-scan result failed and remains distinct from the passing isolated distributable validator; no foreign task files were changed or deleted.
- Seven changed PowerShell files parsed successfully. Six added setup report assertions are written in existing macOS/Linux scenarios; no native Unix execution on this Windows host. Running a zero-scenario setup suite is not evidence and was avoided.
- Lead reports writer-executed public-pair validator and bilingual regression passed; this Tester did not rerun them merely for a different agent. Supplemental Python skill validator could not start because PyYAML was unavailable; not a passing result or authority to install dependencies.
- Choose the lowest-observation-cost adequate entrypoint, runner, and observation mode per case. Retain full trusted result artifacts, inspect summaries first, and drill down for failures, ambiguity, unexpected behavior, or material/safety-sensitive risk.
- API/integration scenarios generally cover broader business permutations at a declared real application boundary; browser checks retain representative complete journeys and distinct UI/client/front-end-back-end risks. Record evidence and rationale for reduced duplicate browser permutations. Do not treat mocks, direct model calls, or narrow endpoint checks as a complete user journey.
- Include every manual scenario/requirement in the E2E plan with equivalent conditions, expected results and explicit checkpoints; list gaps without treating plans/exceptions as passing.
- On encountered user-added/changed manual cases, update E2E and applicable other-layer tests/assertions, reopen affected evidence and rerun; ask on ambiguity, expanded scope or automation exceptions. Preserve archived acceptance with a follow-up stage.

### Execution and observation choices
| Case / test ID | Execution entrypoint and real boundary | Runner / command | Observation mode and rationale | Retained browser / visual checkpoints | Evidence / drill-down / gaps |
| --- | --- | --- | --- | --- | --- |
| OD01-OD04 | Fresh native Team tasks in disposable target project | New-page, adjustment and negative-task cases | Actual invocation ledger, proposal and production diff ownership | Inspect isolated prototype if produced | Planned; Designer absent in current catalog |
| OD05-OD07 | Copied real package wrappers, explicit fake homes | tests/test-optional-designer.ps1 | Exit/output/receipt and complete fingerprints; inspect failures | Not applicable | Passed outside filesystem sandbox; original sandbox Move failure retained; final copied validator passed |

### Manual-to-automated coverage mapping
| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| OD01-OD03 | Native new-page, explicit substantial and small adjustment, backend and incidental-polish flows; check actual role selector and production ownership | Static package/role discovery; independent semantic review | planned | Current catalog unavailable; no automation exception accepted |
| OD04 | Accessible/missing/unloaded provider flows; check installed command docs, real invocation and fallback | Package tolerates absent provider | planned | Files alone do not prove active capability |
| OD05-OD07 | Complete copied-package install/update/preview/conflict flow; check output, exits, bytes and fingerprints | Deterministic helper checks and actual package validator | passing: isolated suite exit0 and final copied validator exit0 | Fake homes do not establish active Codex loading; native Unix setup report assertions unexecuted |

## Human verification script
### Preparation
1. Prepare disposable project and fresh client exposing Designer; separately obtain authority before any real installation. Record actual source/client identity. Prepare missing page, existing page, backend and incidental-polish requests; provider available or absent as indicated.
### Happy path
1. OD01: request missing page in UI task. Expected: named Designer gives concrete proposal, frontend engineer alone owns production implementation.
2. OD02: explicitly request page-design adjustment; repeat with a small requested page adjustment. Expected: bounded Designer handoff in both cases, no size-threshold bypass, concurrent production writes or unnecessary long loop.
3. OD04: use accessible Impeccable. Expected: installed docs read, only supported scoped commands, no collision with Kit frontend-design or hooks/unapproved files.
4. OD05/OD07: run isolated test batch. Expected: optional clear official guidance, exact distribution/receipt bytes, no real-home changes.
### Recommended edge cases
1. OD03: request backend/logic or incidental polish without design intent. Expected: no automatic Designer or extra design gate.
2. OD04: hide/unload provider or make it inaccessible to child. Expected: existing workflow continues without successful invocation claim.
3. OD06: run preview and customized-file conflict. Expected: unchanged preview fingerprints; conflict remains failure and customization survives; no loaded claim.
### Result
- OD05-OD07 isolated deterministic delivery checks passed; OD01-OD04 native Designer/provider workflows and six Unix setup report assertions remain pending. No user manual acceptance or rendered-product visual quality is inferred. Both owned test fixtures were removed with absence verified; no real installations changed.
- Comment/readability self-check: owned test file overview, helper contracts and independent scenario/expected-result comments inspected against assertions; new suite has no lines over 120 characters. Existing setup assertions retain their native-only boundary and scenario explanations. No project formatter configuration changed; PowerShell parser checks passed. Host-reported actual role/model identity is unknown; no child agents were used by Tester.
- Advisory helper source inspection found only a static-string return, no filesystem discovery, network, downloads, hooks or global writes. Fingerprints cover actual copied source/fake-home effects, not arbitrary external filesystem proof. Independent semantic review is a separate Lead gate.
