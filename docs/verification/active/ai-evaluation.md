# Verification: AI behavior evaluation ownership

Packet schema version: 2
Stage slug: ai-evaluation
Contract status: active
Final manual status: manual pending
Final manual evidence: New AI Tester is not active in this session; native routing, product AI evaluations and user acceptance are unobserved.

## Stage context

Objective: Separate AI behavior evaluation into team-ai-tester and ai-testing-engineering while preserving deterministic software tests, evidence sharing and independent assessment.
Scope: role profile, shared ai-evaluation.md, conditional Skill/role routes, narrow package guards and isolated tests only. No runtime/evaluation platform, schema change, version/release, real installation, Git write or external API.
Baseline: clean ec790c4. Existing capability contracts and recording/replay guidance remain authoritative for their separate topics. Lead owns readiness and exact Work protection; Docs owns normative source; existing team-tester owns this packet, tests/test-ai-evaluation.ps1 and scripts/validate.ps1. The Tester creates no children and does not stand in for the unavailable native AI Tester.
Blueprint applicability: docs/architecture.md is the existing equivalent source-package architecture; this task extends role, Skill and shared-contract modules in place. No executor or structural source refactor approved/needed. Root AGENTS.md applies; Lead found no substantive instruction gap and performs no instruction-file write.
Conventions: existing PowerShell validator and GUID-owned temp fixtures; existing installer dynamically hashes all profile/Skill payload. No formatter configuration applies; preserve scenario/expected-result comments and readable grouping. Cost/time forecasts unknown; no hard budget inferred.
Data/cleanup: synthetic project facts and disposable package copies only; no credentials/live model calls. Clean only exact owned OS-temp child roots in finally after absolute parent/prefix validation. Existing fake-home suite uses its own guarded cleanup. No original project data changed.

## Use-case map

| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| AE-01 | Finalized complete package | Run validator and compare copied-file fingerprints | New role, Skill, shared resource and agreed direct links accepted without mutation; ordinary Tester retained | happy |
| AE-02 | Disposable complete source copy | Remove role/Skill/reference or required discovery link | Explicit missing-resource/route rejection even when replacement link resolves | edge |
| AE-03 | Disposable role profile | Change model or reasoning; retain/inspect existing profiles | Reject unsupported new profile; unchanged old Tester supported | edge |
| AE-04 | Fake homes only | Run existing installer and old capability routing regression | All profiles/Skills/refs distributed byte-exact; previous capability routes still validate and reject mutations | happy |
| AE-05 | Pure AI behavior change or software-only task | Select test ownership and plan before writing | One suitable AI Tester for pure AI; ordinary Tester for software-only; deterministic AI-adjacent code still checked | happy / alternate |
| AE-06 | Mixed task uses one connected trace | Assign disjoint assertions and one packet owner | Shared trace without duplicate generation or duplicate result authorities; software and AI conclusions remain distinct | happy |
| AE-07 | Nondeterministic output, negative case or ambiguous quality | Define approved cases/rubric and independent assessment | Output not self-certified; strict deterministic TDD where practical, justified alternate track for behavior; uncertain results retained, no fabricated quality pass | edge |
| AE-08 | Prototype request, unavailable role or external-cost requirement | Apply explicit entry/availability/authority limits | No implicit simulation, generic fallback, paid call, model identity or human-acceptance claim | edge |

## Coverage-category decisions

| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No product/runtime algorithm added; role/config guards tested at CLI boundary. |
| integration | required | Package discovery and fake-home distribution. |
| contract/API | required | Resource/profile/link contract plus source semantic evaluation ownership; no live API. |
| E2E | required | Native AE-05 through AE-08 mapped below but unavailable until authorized loaded-source use. |
| regression | required | Old capability routing and ordinary software Tester retained. |
| manual | required | Source walkthrough and separate native user verification. |
| component/UI | not applicable | No product controls or rendering. |
| accessibility | not applicable | No UI change. |
| visual regression | not applicable | No visual output requirements. |
| performance/load | conditional | Shared-trace efficiency is design intent, not measured savings; telemetry unavailable. |
| security | required | Independent scoring, external authority and safe temporary cleanup. |
| compatibility | required | Existing role and schema2 packet remain usable; unknown native catalog handled honestly. |
| data migration/rollback | not applicable | No storage/deployment operation. |
| resilience/recovery | required | Missing-role/failure/uncertainty cannot turn into silently accepted results. |
| exploratory/usability | required | Synthetic task classification checks clarity of ownership and coverage selection. |

## TDD behavior matrix

| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| New role admission AE-01/AE-03 | Approved valid profile rejected by existing validator | integration / compatibility | test-first | tests/test-ai-evaluation.ps1 baseline | Finalized valid source rejected only unsupported team-ai-tester profile; command exit1 before expected map edit | Same command exit0 after expected sol/medium profile and guards | No production refactor; restored fixture passes with unchanged fingerprint | Deterministic public CLI observation; Red belongs specifically to role admission | Tester | passing |
| New resource and route guards AE-02/AE-03 | Incomplete role distribution or lost discovery | integration / regression | test-after | tests/test-ai-evaluation.ps1 mutations | not applicable | Eight lost Markdown routes, lost role Skill route, four omissions and two profile drifts rejected; command exit0 | Restored bytes/fingerprint verified | Old validator cannot admit new valid role before profile fix; focused post-admission mutation tests distinguish guard behavior without fabricated Red | Tester | passing |
| Distribution/backward compatibility AE-04 | New payload omitted or old boundary broken | integration / compatibility | test-after | tests/test-install-user.ps1; tests/test-ai-capability-contracts.ps1; tests/test-validate.ps1 | not applicable | All three commands exit0 with scoped cleanup; installer escalation after sandbox limit | existing tests unchanged | Existing distribution/mutation harness exercised finalized changed inputs; no installer algorithm edits | Tester | passing |
| Public bilingual role/operation facts | Role added in one language only | compatibility | test-after | scripts/validate-docs.ps1; tests/test-bilingual-docs.ps1 | not applicable | Both commands exit0; separate source semantics reviewed | existing tests unchanged | Public README pair requires repository checks plus semantic review; no version/changelog edit planned | Tester / Docs | passing |
| Test selection and mixed ownership AE-05/AE-06 | Double testing or lost deterministic coverage | E2E / contract/API | manual-or-environmental | Semantic.AE-05/AE-06; NativeE2E.AE-05/AE-06 | not applicable | Source walkthrough coherent; native cases unexecuted | no runtime refactor | Native selection requires loaded new role unavailable here; minimal synthetic walkthrough is substitute reasoning only | Tester / user | manual pending |
| Evaluation independence AE-07 | Self-certification or authored prose mistaken for AI quality proof | security / E2E | manual-or-environmental | Semantic.AE-07; NativeE2E.AE-07 | not applicable | Source walkthrough coherent; native cases unexecuted | no runtime refactor | Behavior evaluation is nondeterministic/environment-dependent; inspect rubric and evidence rules without actual product claim | Tester / user | manual pending |
| Explicit prototype and authority AE-08 | Unavailable role silently replaced; unauthorized calls | security / E2E | manual-or-environmental | Semantic.AE-08; NativeE2E.AE-08 | not applicable | Source walkthrough coherent; native cases unexecuted | no runtime refactor | No actual new role/API authorization; source walkthrough retains environmental acceptance gate | Tester / user | manual pending |

## Automated test and E2E plan

Validate this plan before writer START. Wait Lead GO before tests/guard edits or execution. After GO, author focused CLI mutation tests; after normative freeze observe actual old-validator Red from rejection of the approved valid new role, then add expected profile and narrow guards and run Green. Red is role admission only, not retroactive route/resource Red; mutations use justified test-after above. Fast batch includes package validation, assigned AST, diff hygiene and packet validation. Handoff batch runs existing isolated installer, old capability regression and tests/test-validate.ps1 once because routing/profile inputs change; inspect dynamic fixtures first. Run public bilingual validator/regression once after README pair freeze and review semantics separately. No broad deployment/schema suite unless real behavior changes or failures demand expansion. Every runner returns summary; drill down on genuine failures. Source guidance semantics are not keyword tests.

| Manual case / requirement ID | E2E scenario and checkpoints | Other layers / source evidence | Status / gap |
| --- | --- | --- | --- |
| AE-05 | NativeE2E.AE-05: pure prompt/workflow, software-only, deterministic context/parser code; chosen owners and actual checks | Semantic.AE-05; profile/route checks only distribution | planned; new native role not active |
| AE-06 | NativeE2E.AE-06: mixed flow, disjoint assertions, one recorded trace, single canonical packet owner and distinct conclusions | Semantic.AE-06; capability/replay regression | planned; native product run unavailable |
| AE-07 | NativeE2E.AE-07: predeclared rubric/cases including bad output, independent scorer, retained uncertainty and known-limit report | Semantic.AE-07; no fabricated synthetic quality score | planned; real AI evaluation unexecuted |
| AE-08 | NativeE2E.AE-08: prototype mentioned vs explicitly requested, missing-role catalog, absent paid-call authority | Semantic.AE-08 | planned; user decisions must not be simulated |

Deferred checks AE-05 through AE-08: user/Lead owner, manual pending; trigger separately authorized disposable target project with new role/Skill actually available; flush before acceptance of that future workflow. Source handoff does not require or claim live AI acceptance. Retain pending E2E mappings; user-added cases update all applicable layers rather than weakening expected outcomes.

## Human verification script

1. Prepare a separately authorized disposable project, confirm available role catalog and source revision, use synthetic data; declare external budget if actual calls needed. No install/calls performed by this source change.
2. AE-05: request a pure AI behavior change, then a software-only change. Expected: appropriate single Tester selected. Edge: change deterministic context assembly/schema parsing alongside prompt. Expected: those code risks retain concrete software tests; AI ownership is not an exemption.
3. AE-06: request a mixed feature using one connected recorded run. Expected: disjoint AI/software assertions, shared trusted trace, one packet owner, separate explicit evidence conclusions; no repeated call merely to duplicate evidence.
4. AE-07: include failed/unsafe output and nondeterministic variations. Expected: criteria defined before evaluation, independent assessment, failures/uncertainty retained, no generator self-score or changed baseline to pass. Distinguish deterministic test evidence from behavior observations and pending user acceptance.
5. AE-08: mention prototype without invocation, supply missing new role or absent external budget. Expected: no implicit simulation, fallback or paid action; precise limitation/decision request. Explicit prototype evidence remains separate from actual product acceptance.
6. Record observations here and clean only owned disposable data. Final manual status remains pending until observed acceptance or explicit user deferral; no archival while pending.

## Verification record

Preimplementation plan validated exit0 before normative writer START. After Lead GO, tests authored and normative source frozen. First attempted admission check exposed new Skill missing existing execution-contract link and mandatory activation/output headings as well as unsupported new profile; that mixed failure is source-defect evidence, not clean Red. Docs fixed mandatory shape. Independent review also found architecture prose still claiming every stage requires ordinary Tester and missing canonical-packet write permission for AI Tester; those were fixed, with direct-user-only manual evidence clarified, before the final test snapshot.

Clean Red: `pwsh -NoProfile -File tests/test-ai-evaluation.ps1` exit1 solely because old validator rejected approved `team-ai-tester` as unsupported. Then expected profile and narrow guards were added. Green same command exit0; baseline admitted complete source/ordinary Tester, eight lost Markdown links and the profile's lost Skill route rejected with precise diagnostics, four resource omissions and both model/effort drifts rejected, restored source validated with unchanged fingerprint. All mutation fixtures removed. Guard mutations are test-after, not falsely labeled their own preimplementation Red.

Fresh `pwsh -NoProfile -File tests/test-ai-capability-contracts.ps1` and `pwsh -NoProfile -File tests/test-validate.ps1` exited0 with owned fixture cleanup. Old capability/replay routes and existing profile/config/routing guards retained. Fresh package validation, assigned PowerShell AST and scoped diff hygiene passed. `scripts/validate-docs.ps1 -ProjectRoot .` and isolated `tests/test-bilingual-docs.ps1` exited0; bilingual fixture removed. No prior pass relabeled fresh. Independent batches used separate owned fixtures and the same frozen source, with no shared writes.

Isolated `tests/test-install-user.ps1` sandbox attempt failed at existing .NET File.Move permission limit; finally removed its fixture. Approved exact escalation rerun used fake homes only and exited0. Dynamic map proved every current profile/Skill/reference file installed byte-exactly and receipt covered each once, including new AI Tester and AI testing Skill. WhatIf nonmutation, managed update, conflict preservation and fake-home Force backup/replacement passed; owned directory removed. Final package digest `01e9e6ed088eafef3c33f07c17f36e292b7d38a0750a8f1e95eaef2d80490a83`. No real installation or global config operation. Optional bundled Skill validator unavailable: Lead's one invocation failed missing Python yaml; no dependency installed or retry/pass claimed.

Source walkthrough AE-05/AE-06: pure prompt/workflow selects one AI Tester; software/Kit tests remain ordinary; deterministic context/parser/state assertions stay covered, mixed scopes declare disjoint assertions/files with one packet owner and share suitable traces. AE-07: case criteria precede output, hard authorization/schema gates cannot be offset by quality scores, judge calibration and known-bad/borderline cases required, untrusted candidate output cannot instruct evaluator, nondeterministic baselines are not fabricated Red and all bounded attempts retained. AE-08: prototype entry remains explicit, independent scorer never uses actor context, no secure-blinding claim, missing native target/proxy/live-call budget causes a limitation/decision rather than silent execution. Shared packet write permission and recording only direct user evidence/deferral preserve human acceptance authority. Tester read the final new Skill/shared evaluation reference and inspected changed routes/profile; this is source/proxy design reasoning, not actual product or new-role behavior.

Reviewer source-forward walkthrough (reported by Lead) used minimal synthetic project/trace facts: sensible pure/mixed scope and retained deterministic checks; lookup-only trace does not prove completed refund; prompt-injection candidate remains data not grader instructions; alternatives permitted within hard approval/effect gates; unavailable target/proxy/live-budget causes no calls. The reviewer context is independent but not blind, and is not the new native role or product runtime. No native AE-05 through AE-08, real API, savings or user acceptance claimed.

Comment/readability self-check: new file overview states structural scope; local helpers document responsibilities; every independent scenario/parameterized block explains conditions and expected outcomes supported by assertions; byte restoration and absolute cleanup safety explicit. Validator additions state discovery-not-quality limitations. No formatter config applies; AST and manual grouping/layout review passed, semantic route/model literals retained.

### Written Skill rule ledger

All entries below were actually written to source by Docs, not just conversation context or memory. Detailed evaluation authority is the new shared reference rather than duplicated rule bodies.

| Exact Skill file | Written section / rule |
| --- | --- |
| skills/ai-testing-engineering/SKILL.md | New introduction/reference/ownership guidance, When to activate and Output contract: evaluation scope, common contracts, canonical packet permission, independent scoring and direct-user manual evidence. |
| skills/team-dev/SKILL.md | When to activate; Establish the work workflow step 4 and predelegation declaration; Execute and integrate: role-selected Tester, AI-only/mixed scope, packet ownership and postverification. |
| skills/team-core/SKILL.md | Team core conditional AI evaluation pointer and role selection. |
| skills/ai-engineering/SKILL.md | When to activate: conditional AI evaluation route and retained software scope. |
| skills/testing-engineering/SKILL.md | Introduction before When to activate: conditional AI evaluation reference and deterministic/harness scope. |
| skills/team-ai-simulate/SKILL.md | When to activate role preflight/scorer boundary; Output contract independent AI Tester assessment. |
| skills/team-plan/SKILL.md | When to activate conditional planning/evaluation scope pointer. |
| skills/team-debug/SKILL.md | When to activate; Investigate delegation step 3: bounded AI evaluation versus software diagnosis. |
| skills/team-review/SKILL.md | Establish coverage: AI evaluation evidence pointer and review-coverage step 2 role selection. |
| skills/code-review/SKILL.md | Evaluate findings: conditional AI evaluation calibration/hard-gate review pointer. |

Actual roster: Lead reused `/root/ai_contract_docs` under original exact `team-docs-maintainer` selector (complete, source frozen), `/root/ai_contract_tests` under original exact `team-tester` selector (complete, all assigned files frozen), and `/root/ai_contract_review` under original exact `team-reviewer` selector (complete, independent review/source-forward walkthrough and final evidence check). Final review has no unresolved material findings; source and test corrections were read back. New `team-ai-tester` is source configuration only, unavailable in the active catalog; no generic stand-in or actual new-role call. Host resolved role/model/effort unknown. No new spawn, failed creation or Tester child. No documented host Close operation, no slot-release claim; write ownership ends at freeze independently. Lead owns final readiness/roster reconciliation.
