# Verification: Application AI development guidance

Packet schema version: 2
Stage slug: ai-development-guidance
Contract status: active
Final manual status: manual pending
Final manual evidence: Native target-project adherence and user acceptance remain unobserved.


## Stage context
- Objective: Improve guidance for application Agents/Workflows in other projects without runtime, framework, model or authority changes.
- Scope, environment, test data, and cleanup: Four shared references and conditional routes; synthetic facts and isolated GUID package copies under protected _work/ai-development-guidance only. Work Protect reused /_work/ without changes. No real user-home writes/installation, network, target-application model/API calls or sibling cleanup; installed Skills were read and ordinary Codex task subagents were used. Lead owns readiness, writer production, Tester this canonical packet and focused test. Existing PowerShell standalone tests and source copies reused; no formatter configuration found. Existing architecture suffices; no OpenSpec, Blueprint or migration applies.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| AD-01 | Distributed source | Check four references | Nonempty strict UTF-8 resources exist | happy |
| AD-02 | Isolated source copy | Resolve routes; omit resource/route | Complete package passes, every loss rejected and original bytes restored | edge |
| AD-03 | Fixed workflow request | Review design and implementation guidance | Prefer proportionate fixed workflow; select applicable dimensions without forced platform/autonomy | happy |
| AD-04 | Ambiguous success/permission | Review intake/instruction guidance | Surface missing decision and observable acceptance; do not invent authority | edge |
| AD-05 | Budget loss or absent/stale retrieval | Review context guidance | Preserve authoritative state/provenance and explicit loss behavior | edge |
| AD-06 | Side-effect tool times out after possible commit | Review tool/recovery guidance | Scoped authorization, validation, idempotency/uncertainty and bounded retry | edge |
| AD-07 | Prompt assembled but unused/overridden | Trace design, source, actual call, evidence | Independent review detects fake assembly; no unsupported adherence/improvement claim | edge |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No product runtime algorithm. |
| integration | required | Real source-package distribution. |
| contract/API | required | Resource/routes; no live API. |
| E2E | conditional | Native other-project use separately authorized; mapped below. |
| regression | required | Resource and route-loss mutations. |
| manual | required | Source semantics and future user acceptance. |
| component/UI | not applicable | No UI. |
| accessibility | not applicable | No controls. |
| visual regression | not applicable | No visual requirement. |
| performance/load | not applicable | No runtime/performance claim. |
| security | required | AD-06 permission and side effects. |
| compatibility | required | Preserve existing routes/role models. |
| data migration/rollback | not applicable | No persisted-state migration. |
| resilience/recovery | required | AD-05/06 context loss and uncertain retry. |
| exploratory/usability | required | Lightweight applicable-subset guidance. |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| AD-01 distribution | Missing guidance shipped | integration / regression | test-first | tests/test-ai-development-guidance.ps1 -SourceOnly | Before writer edits command exit1: AD-01 missing resource skills/team-core/references/ai-workflow-design.md | Same SourceOnly command exit0 after normative freeze | No production refactor; full focused test exit0 and copied bytes restored | Deterministic package observation; genuine approved-resource absence, not fixture/setup failure | Tester | passing |
| AD-02 routes | Lost intended discovery | contract/API / regression | test-after | tests/test-ai-development-guidance.ps1 | not applicable | Full command exit0: 4 resources, 17 intended routes, resource/route/broken-link mutations rejected | Fingerprint equal after all restorations; owned fixture removed | Final links depend on writer; resolve real package routes and mutate copied resources/routes | Tester | passing |
| AD-03 through AD-07 semantics | Prose mistaken for runtime improvement | manual / E2E | manual-or-environmental | Semantic.AD-03..07; NativeE2E.AD-03..07 | not applicable | Frozen source walkthrough coherent; native cases unexecuted | No runtime refactor | Source inspection assesses guidance only; native adherence needs separately authorized environment | Tester / user | manual pending |

Assess unit, integration, contract/API, E2E, regression, manual, component/UI, accessibility, visual regression, performance/load, security, compatibility, data migration/rollback, resilience/recovery, and exploratory/usability.

## Automated test and E2E plan
- Commands, fixtures, environment, cleanup, and TDD exceptions: Before writer start validate packet and capture genuine AD-01 missing-resource Red if practical. After freeze run focused test, scripts/validate.ps1, AI capability/evaluation regressions and isolated installation checks. Lead coordinates bilingual gates if public pairs change. No broad tests before freeze. Forecast unknown; no hard budget inferred. Tester deferred package checks trigger writer freeze and flush before handoff. Native cases owner user/Lead, trigger separately authorized disposable target-project run, flush before that project's acceptance; no simulation implied.
- Choose the lowest-observation-cost adequate entrypoint, runner, and observation mode per case. Retain full trusted result artifacts, inspect summaries first, and drill down for failures, ambiguity, unexpected behavior, or material/safety-sensitive risk.
- API/integration scenarios generally cover broader business permutations at a declared real application boundary; browser checks retain representative complete journeys and distinct UI/client/front-end-back-end risks. Record evidence and rationale for reduced duplicate browser permutations. Do not treat mocks, direct model calls, or narrow endpoint checks as a complete user journey.
- Include every manual scenario/requirement in the E2E plan with equivalent conditions, expected results and explicit checkpoints; list gaps without treating plans/exceptions as passing.
- On encountered user-added/changed manual cases, update E2E and applicable other-layer tests/assertions, reopen affected evidence and rerun; ask on ambiguity, expanded scope or automation exceptions. Preserve archived acceptance with a follow-up stage.

### Execution and observation choices
| Case / test ID | Execution entrypoint and real boundary | Runner / command | Observation mode and rationale | Retained browser / visual checkpoints | Evidence / drill-down / gaps |
| --- | --- | --- | --- | --- | --- |
| AD-01/02 | Distributed source and isolated copied package | pwsh -NoProfile -File tests/test-ai-development-guidance.ps1 | Resource/route assertions and loss mutations | not applicable | executed/passing; structural only |
| Semantic.AD-03..07 | Frozen guides and roles | Source walkthrough against cases | Applicable subset and evidence boundary inspection | not applicable | executed source inspection coherent; no native proof |
| NativeE2E.AD-03..07 | Actual disposable other-project implementation | Separately authorized native run | Intake, source, actual call, outcome and independent assessment | target-project dependent | unexecuted, no environment/call authority |

### Manual-to-automated coverage mapping
| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| AD-03 | NativeE2E.AD-03: fixed workflow choice, implementation/call/output | Semantic.AD-03; AD-01/02 | planned | Native adherence unobserved |
| AD-04 | NativeE2E.AD-04: missing decision, authorized contract/source/call | Semantic.AD-04 | planned | User decision cannot be fabricated |
| AD-05 | NativeE2E.AD-05: history loss/stale retrieval, actual context and outcomes | Semantic.AD-05 | planned | Actual context behavior unobserved |
| AD-06 | NativeE2E.AD-06: uncertain commit, permission/retry and resulting effects | Semantic.AD-06 | planned | Isolated safe tools required |
| AD-07 | NativeE2E.AD-07: unused assembly contrasted with actual call and independent evidence | Semantic.AD-07 | planned | Actual call evidence unavailable |

## Human verification script
### Preparation
1. Prepare separately authorized disposable other project, synthetic inputs, loaded-source identity and explicit external-call budget. This Kit task performs no real user-level installation.
### Happy path
1. AD-03: request fixed workflow. Expected: proportionate workflow and applicable dimensions; inspect source and actual output.
### Recommended edge cases
1. AD-04: omit success/permission decision. Expected: surface decision without invented authority; inspect contract/source/call.
2. AD-05: truncate history or remove/stale retrieval. Expected: preserve authoritative state/provenance and explicit loss behavior; inspect actual context/outcome.
3. AD-06: safe tool timeout after possible commit. Expected: authorization, uncertainty/idempotency and bounded retry; inspect resulting effects.
4. AD-07: assemble unused/overridden prompt. Expected: independent design-to-source-to-actual-call-to-evidence review detects mismatch; do not infer improvement from file presence.
### Result
- Observations and cleanup: Record actual observations; clean only exact owned fixtures. Keep manual status pending absent user acceptance/explicit deferral.

## Verification record

Preimplementation packet Validate exit0; Lead independently repeated exit0 before authorizing normative writer edits. AD-01 Red: pwsh -NoProfile -File tests/test-ai-development-guidance.ps1 -SourceOnly exited1 before those edits with missing ai-workflow-design.md. Source tests cannot prove native agent adherence, actual Skill loading or capability improvement. Expected/actual selector: team-tester / /root/ai_guidance_tests; writer team-docs-maintainer / /root/ai_guidance_writer; host returned handles only, identity/model/effort unknown. Source and active catalog expectations Sol/medium and Luna/high are not runtime proof. Independent reviewer team-reviewer planned. Initial Lead inventory root only; Tester reserved through postfreeze checks; no close tool/release claim. Tester has no children or background processes; assigned write ownership retained until explicit freeze.

Focused package test covers four resources, intended direct links, guide-local link resolution and three role-to-Skill routes in a real copied package. Missing resources, lost intended routes replaced by valid unrelated links, and broken guide links are negative mutations; original bytes and fingerprint restored. These are test-owned assertions, not new production-validator guards. All selected execution followed normative freeze. Formatter Plan reported needs-selection (no project formatter configuration); no formatter installed or substituted. Assigned PowerShell AST parses and manual readability/comment review passed: file purpose/boundary, helper contracts and every independent scenario have accurate explanations; parameterized rows retain identifiable expectations and route strings. No missing explanation or semantic-layout gap found.

After Lead verification GO on frozen normative paths: SourceOnly exit0 and full focused test exit0. First full run failed due the test requiring literal suffix 'ai-engineering Skill' while a valid role says 'Use ai-engineering'; corrected only the test's overconstraint to inspect the Skill token in developer_instructions, then full test passed. This was not a production defect or new TDD Red. Existing scripts/validate.ps1 exit0; its generic local-link resolver already covers broken Markdown links, so no new production guard was introduced. Existing tests/test-ai-capability-contracts.ps1 and tests/test-ai-evaluation.ps1 exit0 with isolated negative mutations/restoration and cleanup. Writer then reopened only the AI-tester role to preserve explicit read-assigned-product authority; after final re-freeze, focused test and scripts/validate.ps1 reran exit0. Earlier isolated capability/evaluation fixtures copied source before that wording restoration; their tested routes/profiles/resources are unchanged, so no duplicate run was required.

Semantic.AD-03: workflow guide chooses deterministic code, bounded call, fixed workflow, tool agent or multi-agent only for justified boundaries, including state, ownership and stop conditions; ai-engineering selects only applicable dimensions. Semantic.AD-04: instruction guide defines task/inputs/output/method/limits/authority, missing-reference and unknown-fact handling; roles preserve unresolved-user-decision boundaries. Semantic.AD-05: context guide assigns field/assembler ownership, selection, caps, priority, reset/expiry, provenance and stale/loss recovery; actual node input rather than selector alone is verification target. Semantic.AD-06: tool guide places validation/authorization in application code, distinguishes result/error states, preserves logical operation identity and reconciles timeout-before-repeat with bounded retries. Semantic.AD-07: instruction/workflow guides and review route trace approved intent to canonical source, actual selection/assembly/call path and independent evidence; file presence and Codex Skill links are explicitly insufficient. These are source inspections, not scored application outputs or executed native E2E.

Unrelated concurrent README pair edits, .github files and the FOLDER_STRUCTURE .github/ISSUE_TEMPLATE row were preserved and excluded from task authorship/completion claims. Read-only validate-docs and test-bilingual-docs both exit0 for cross-package impact; no full-pair semantic equivalence claim. Optional creator quick_validate unavailable: default Python alias cannot start, trusted bundled Python starts but lacks yaml/PyYAML; no dependency installation or retry.

Installation check first sandbox run exited1 at existing deploy-user .NET Move(3), Access denied; finally cleanup removed owned fixture. This is environment failure, not code failure or TDD Red. Lead authorized one unchanged require_escalated rerun of tests/test-install-user.ps1 against its own temporary fake homes only; rerun exit0, Install-user tests passed and isolated directory removed. Existing Get-PackageFileMap recursively discovers every source Skill file, and assertions compare every installed file's SHA256 to source plus one matching receipt entry/hash, including the four new references. WhatIf fingerprint unchanged, managed update complete, customized conflict preserved without Force and backup retained before forced replacement, all within fake homes. Package digest: 180eaba7890f38e88f57f0bcb0dfd965c9a9494672661c98300b5e3b4366431b. No real user-level installation or active Skill-loading claim.

Invocation reconciliation: exact reviewer selector team-reviewer returned /root/ai_guidance_review; host identity/model/effort unreported. Reviewer source/catalog expectation Sol/high is not runtime proof. Writer final source frozen; Tester final packet Validate exit0 and assigned files frozen for Lead-only readiness publication. Assigned tests AST and scoped diff hygiene passed; Work Protect again reused existing rule and Check returned clean. No Tester children, live test sessions or background processes remain; test-process ownership ended at exit and assigned write ownership ends at this freeze. No close tool or slot-release claim.

Bounded forward-usability evidence supplied by Lead from /root/ai_guidance_review, performed before that Reviewer read this packet: support-ticket/KB/staff-approval proposal selected a fixed workflow with authorized fresh retrieval, bounded drafting call, schema/citation checks and pending staff queue; it identified canonical source, assembly and cancellation/approval/outcome evidence. Against predeclared AD-03/04/07 criteria this demonstrates a usable proportionate proposal and trace, not implementation. Forgotten-address/timeout/reusable-module proposal identified confirmed application state/provenance, scoped node fields and assembler ownership, differentiated persistence/assembly/model/tool causes, specified module trigger/non-trigger/overlap/method/reference loading, and reconciled client-held operation identity before retry. Against AD-05/06/07 this addresses context-loss and uncertain-effect criteria without guessed state/tool outcome. Both proposals named focused missing/malformed/security/failure checks. No blocking usability ambiguity observed in these two read-only reasoning exercises; they are ordinary Codex Reviewer proposals, not native product execution, model quality evaluation or acceptance.

Independent review complete: /root/ai_guidance_review reports no material findings after all 17 production paths and assigned test inspection; read-only AST/diff checks passed. Applicability permits tiny-change reuse without unnecessary full workflow design. Reviewer read the installed code-review Skill once and then repository source; no home writes/installation. Lead additionally read installed skill-creator, workspace-hygiene and brainstorming and looked up bundled dependencies through the app; no target-application call evidence or active-loaded-Skill proof inferred from those reads. Native cases and final user acceptance remain pending.

Close result: required package/distribution regressions passed, five scoped semantic walkthroughs coherent, two bounded Reviewer proposals assessed against declared criteria, no material independent-review findings. Optional creator validation unavailable; native application E2E, measurable capability improvement and user acceptance remain unverified. Keep packet active with Final manual status manual pending. Tester capabilities actually used: testing-engineering for coverage/TDD/evidence; workspace-hygiene for placement/lifecycle; team-core references and local helpers for schema2 packet, artifact protection and formatter discovery; PowerShell/file/patch tools for bounded test edits, package fixtures and execution; collaboration messaging for ownership and evidence coordination. No Tester-created subagents, external connector/service calls or target-application model/API calls.
