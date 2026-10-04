# Verification: Optional AI workflow simulation and engineering

Packet schema version: 2
Stage slug: ai-simulation
Contract status: ready
Final manual status: manual pending
Final manual evidence:


## Stage context
- Current follow-up: user approved release line 1.0.0, AI-only team-ai-simulate naming, distinct basic/advanced model-agnostic actors and readonly AI architect. Existing 0.11.0 prototype evidence below remains historical, not inherited current follow-up acceptance. Major release numbering does not authorize a stable pointer update.
- Objective: optional native actor/workflow prototyping with frozen supplied-input evidence and separately approved engineering. Current modules SIM-WORKFLOW, SIM-EVIDENCE, SIM-ACTOR, AI-ARCHITECT, AI-ENGINEERING and SIM-VERIFY; no existing-code refactor.
- Scope, environment, test data, and cleanup: PowerShell 7; disposable Git projects/fake homes, synthetic JSON/rules/prompts only; finally cleanup verifies owned temporary paths. No credentials/live API/home installation. Local helper is not model execution; unknown hidden context/model/usage remains unknown, proxy pass is not target acceptance.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| SIM-01 | source package | discover/install optional roles and Skills in fake home | all assets and approved profiles present | happy |
| SIM-02 | synthetic definition | Validate, InitializeRun, RecordCall for four modes, Status | frozen assets, ordered unique complete calls; status is not acceptance | happy |
| SIM-03 | invalid input | traversal/IDs/context/oversize | reject without unsafe or partial writes | edge |
| SIM-04 | initialized run | duplicate/exhaust budget/tamper | immutable evidence, bounded calls and integrity failures | edge |
| SIM-05 | approved disposable native session | stateless/dialogue/node/agent with mock tools and independent scorer | fresh/selected context, mock labels, no self-pass | happy / edge |
| SIM-06 | proxy and unknown metadata | inspect evidence then request engineering | no invented target proof or automatic production work | edge |
| SIM-07 | disposable new/old packages | downgrade | remove new capability residue, preserve unrelated content | regression |
| SIM-08 | current source package | discover AI-only workflow, basic/advanced actors and AI architect | retired names absent; approved source profiles and 1.0.0 present | happy / edge |
| SIM-09 | synthetic old/new packages, pinned old fake-home snapshot | old to new to old, restore pinned snapshot | old names removed on upgrade, new names removed on downgrade, user files and stable snapshot unchanged | regression |
| SIM-10 | approved native session with new roles loaded | route AI design, basic/advanced simulation; request non-AI simulation | distinct AI/system architecture roles and task model choices, AI-only scope; no unapproved stable promotion | happy / edge |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | required | schema/context/ID/budget boundaries |
| integration | required | Git protection, snapshots, call records |
| contract/API | required | local JSON/CLI contract, no network API |
| E2E | required | complete native workflow planned, not implied by helper tests |
| regression | required | package validator and lifecycle |
| manual | required | user AI behavior acceptance and engineering approval |
| component/UI | not applicable | no rendered UI |
| accessibility | not applicable | no UI |
| visual regression | not applicable | no rendered change |
| performance/load | conditional | byte/call bounds, no live model load |
| security | required | contained paths, ignored evidence, mock/approval boundaries |
| compatibility | required | PowerShell 7 and approved profiles |
| data migration/rollback | required | fake-home downgrade removes new assets |
| resilience/recovery | required | reject duplicate/tampered evidence |
| exploratory/usability | conditional | native instruction usability needs approved session |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Capability discovery | omitted assets | integration | test-first | SIM-01 test-ai-simulation -DiscoveryOnly | Before writer GO: missing team-simulate/SKILL.md observed; exception | final complete test-ai-simulation exit 0 | corrected final source rerun passed; no structural refactor | none | Tester | passing |
| Local evidence and fail-closed constraints | corruption/unbounded inputs | contract/API | test-first | SIM-02 through SIM-04 test-ai-simulation -BehaviorOnly | Before helper creation: command exit 1 missing ai-simulation.ps1; practical suite written against agreed schema | final complete test-ai-simulation exit 0 | corrected final source rerun passed; no structural refactor | none | Tester | passing |
| Expanded context, raw Git protection, global stop/error budgets and corruption recovery | incomplete boundary coverage | security | test-after | SIM-03/SIM-04 follow-up blocks in test-ai-simulation | not applicable | final complete test-ai-simulation exit 0 | corrected final source rerun passed; no structural refactor | additional risk cases were added after first helper version; no preimplementation Red claimed | Tester | passing |
| Missing immutable call suffix or entire ledger cannot replenish budget | prefix-chain truncation accepted as unused allocation | resilience/recovery | test-first | SIM-04 deleted call tail/all ledger assertions | Before head fix: BehaviorOnly exit 1 Deleted call tail status was accepted; helper 036f6dad | final complete test-ai-simulation exit 0 | corrected final source rerun passed; no structural refactor | none | Tester | passing |
| Raw JSON numeric values remain exact or unsupported values are rejected | irreversible numeric evidence corruption | contract/API | test-first | SIM-04 numeric fidelity and unsupported precision | Before Decimal fix: BehaviorOnly NumericRed exit 1 Raw JSON numeric input was accepted but rounded | NumericRed and final complete suite exit 0 on helper 4d45710e | corrected final source rerun passed; no structural refactor | none | Tester | passing |
| Native actor/context and approval gates | instructions mistaken for enforcement | E2E | manual-or-environmental | Native.SIM-05 Native.SIM-06 | not applicable | authorized session pending | no refactor planned | new roles unavailable; stochastic native behavior cannot be proven by local scripts | Tester / Reviewer / user | manual pending |
| Installation compatibility and downgrade | missing profiles/residue | compatibility | test-after | SIM-01 SIM-07 tests/test-validate.ps1, tests/test-install-user.ps1, tests/test-deployment.ps1 | not applicable | all three isolated suites exit 0; payload/profile/downgrade removal assertions passed | final affected suites passed on unchanged input identity | existing suites observe final package; no retrospective Red | Tester | passing |
| Current 1.0.0 source naming and default profiles | missing role, old name or wrong model/effort | compatibility | test-first | SIM-08 source discovery inside test-ai-simulation | Before writer GO: missing skills/team-ai-simulate/SKILL.md observed | final complete simulator suite exit 0 with naming/profile/readonly/VERSION/run-manifest checks | final corrected source and affected suites passed; no helper behavior refactor | none | Tester | passing |
| Current old/new/old package migration and stable isolation | rename residue or implicit stable promotion | data migration/rollback | test-after | SIM-09 tests/test-deployment.ps1 and tests/test-install-user.ps1 | not applicable | both final isolated suites exit 0 | final affected suites passed; source inputs unchanged | extend existing lifecycle harness for new identity after approved metadata changes; no claimed preimplementation migration Red | Tester | passing |
| Current AI-only routing and AI architect boundary | native role selection or scope differs from text | E2E | manual-or-environmental | Native.SIM-08 through Native.SIM-10 | not applicable | native role session pending | no production refactor | newly defined roles unavailable in active session; actual runtime adherence needs approved session | Tester / Reviewer / user | manual pending |

Assess unit, integration, contract/API, E2E, regression, manual, component/UI, accessibility, visual regression, performance/load, security, compatibility, data migration/rollback, resilience/recovery, and exploratory/usability.

## Automated test and E2E plan
- Commands, fixtures, environment, cleanup, and TDD exceptions:
- Choose the lowest-observation-cost adequate entrypoint, runner, and observation mode per case. Retain full trusted result artifacts, inspect summaries first, and drill down for failures, ambiguity, unexpected behavior, or material/safety-sensitive risk.
- API/integration scenarios generally cover broader business permutations at a declared real application boundary; browser checks retain representative complete journeys and distinct UI/client/front-end-back-end risks. Record evidence and rationale for reduced duplicate browser permutations. Do not treat mocks, direct model calls, or narrow endpoint checks as a complete user journey.
- Include every manual scenario/requirement in the E2E plan with equivalent conditions, expected results and explicit checkpoints; list gaps without treating plans/exceptions as passing.
- On encountered user-added/changed manual cases, update E2E and applicable other-layer tests/assertions, reopen affected evidence and rerun; ask on ambiguity, expanded scope or automation exceptions. Preserve archived acceptance with a follow-up stage.

### Execution and observation choices
| Case / test ID | Execution entrypoint and real boundary | Runner / command | Observation mode and rationale | Retained browser / visual checkpoints | Evidence / drill-down / gaps |
| --- | --- | --- | --- | --- | --- |
| SIM-01 through SIM-04 | real local CLI, disposable Git project | tests/test-ai-simulation.ps1 | tree/hash/JSON assertions | none | Red then bounded Green; no actor execution |
| SIM-01 SIM-07 | real package lifecycle in fake homes | existing validation/install/deployment suites | payload/profile/removal assertions | none | freeze source first |
| Native.SIM-05 Native.SIM-06 | full native orchestration/mock tool workflow | authorized disposable Codex session | inspect supplied inputs/observed responses/routing/approval | none | pending actual session |

### Manual-to-automated coverage mapping
| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| SIM-01 | Native.SIM-01 launch workflow and check named role routing | fake-home package assertions | planned | source install not live role loading |
| SIM-02 | Native.SIM-02 run four context modes, compare inputs/output/routing | local CLI snapshot/sequence tests | planned | helper is not actor E2E |
| SIM-03 | Native.SIM-03 reject invalid input before actor call | local fail-closed checks | planned | native compliance pending |
| SIM-04 | Native.SIM-04 duplicates/budget/tamper stop further actor calls | immutable/budget tests | planned | no exception accepted |
| SIM-05 | Native.SIM-05 fresh stateless input, selected dialogue/node data, mock tool results and independent scoring | semantic review/context schema tests | manual pending | actual behavior unobserved |
| SIM-06 | Native.SIM-06 proxy/unknown telemetry and separate human engineering approval | metadata/schema/source review | manual pending | exact host context/target equivalence not observable |
| SIM-07 | Native.SIM-07 downgrade then new assets unavailable, unrelated file preserved | fake-home deployment | planned | live role lifecycle pending |
| SIM-08 | Native.SIM-08 launch team-ai-simulate and observe distinct basic/advanced actor and AI architect selectors | source discovery/default-profile and fake-home tests | planned | source profiles are not resolved runtime model proof |
| SIM-09 | Native.SIM-09 upgrade old names to new names, downgrade and restore approved old stable snapshot | isolated old/new/old deployment and install stable-absence assertions | planned | actual installed session pending; no stable promotion authorized |
| SIM-10 | Native.SIM-10 separate AI architect from system architect; choose task model/actor and decline generic non-AI simulation scope | independent semantic review | manual pending | native routing unobserved; no exception accepted |

## Human verification script
### Preparation
1. Prepare a disposable synthetic project and approved native session; declare budgets/context/scoring. Keep answers outside supplied actor input; shared filesystem is not secure isolation.
### Happy path
1. SIM-01/SIM-02/SIM-05: launch optional workflow and run all four context modes with mock tools.
   Expected result: declared inputs, frozen assets, observed outputs and independent scoring; no production changes or self-pass.
### Recommended edge cases
1. SIM-08/SIM-09/SIM-10: inspect new AI-only names and selected actor tier/source default, upgrade and downgrade a disposable installation; ask for generic non-AI simulation and AI architecture.
   Expected result: model-agnostic basic/advanced actor naming, dedicated readonly AI architect, no old/new asset residue or implicit stable promotion. Non-AI simulation remains outside this optional entrypoint. Capture actual native selectors/model metadata only when reported.
1. SIM-03/SIM-04: submit invalid path/context/oversize, duplicate, tampered or exhausted-budget inputs.
   Expected result: fail closed without unsafe/partial writes or extra actor calls.
2. SIM-06: use Luna as a Flash-like proxy with unavailable metadata, then suggest engineering.
   Expected result: explicit proxy/unknown labels and separate approval, no target pass.
3. SIM-07: downgrade disposable package.
   Expected result: remove new assets only and preserve unrelated content.
### Result
- Observations and cleanup: actual user/native checks remain pending; keep active packet. Retain raw traces until diagnosis/acceptance, then remove only owned temporary runs.

## Verification record
- Batch plan: focused simulator suite then existing validate/install/deployment suites on frozen source. Forecast unknown; no paid/external operation or new hard budget.
- Tester task simulation_tests; selected role team-tester; resolved model/effort unknown. Lead reconciles full actual roster.
- Comments: every independent new scenario states purpose and expected assertions.
- Development observations: initial non-elevated temporary Git init was sandbox-blocked and cleaned; approved isolated rerun reached a fixture JSON array-shape defect, corrected without production change. Two developmental behavioral runs subsequently exited 0 and cleaned their fixtures; concurrent production edits mean neither is final frozen evidence.
- Frozen follow-up run (helper SHA256 036f6dad2621c6d564bdf7402da50418c753fb4e67d08c188b1aff5b7dca533e; test SHA256 340aba76eef0959a014c9d0efdef6077df98eb1a2965e1716315cd1f03d7cb84) reached an overly strong test expectation that removed ignores would automatically be restored. Lead clarified existing Work Protect must instead pause/fail closed on nonempty unprotected scope, without overriding user policy. The test now explicitly checks no raw append, unchanged index/ignore policy and later success only after simulated human restoration. This was a test-contract correction, not a production defect; no live E2E/manual pass inferred.
- Actual independent review regressions: deleting the last observed call yielded accepted Status (BehaviorOnly exit 1 before head fix); literal large integer/fraction input was accepted with rounded values (NumericRed exit 1 before Decimal fix). Both owned fixtures were cleaned. Backend repaired persisted terminal-head checks and bounded exact Decimal parsing; numeric focused and full final Green passed. Hash chains detect accidental corruption, not authenticated evidence against a writer able to replace every file.
- Final executed local batch: `pwsh -NoProfile -File tests/test-ai-simulation.ps1` exit 0 on PowerShell 7.6.5. Helper SHA256 `4d45710e8f7083b5ab125b4b1723f43a2a334da09e6341184a478b2b59475460`; test SHA256 `79db6dcd9daa3d6a600e853e1fcf76b5b32f63f7f7bdbaa42117b1dc85cfbd15`. Inputs remained unchanged; all owned fixture directories removed. Runtime 7.0 compatibility was source-reviewed, not executed on a separate 7.0 runtime. Actual model/usage/cost unknown. Exact record equality covers authored instructions/current input/history/summary/upstream/state/mock results/mock requests/output/routing and before/after state; numeric tests compare values, not harmless JSON lexical normalization.

### Actual child invocation roster

This table records the earlier 0.11.0 prototype task, not additional child creation for the 1.0.0 follow-up. The follow-up reuses only the runtime, docs, tests and review handles listed in its section below.

Role selectors follow the Lead's Work assignment; returned task handles/status were inspected through collaboration listing. Source/active profile expectations are not resolved model proof; resolved model/effort is unknown for every entry.

| Task handle | Selected role | Responsibility | Last observed status | Resolved model / effort |
| --- | --- | --- | --- | --- |
| /root/simulation_architecture | team-architect | readonly boundaries/schema | completed | unknown |
| /root/simulation_integration_map | team-explorer | readonly package/test map | completed | unknown |
| /root/simulation_runtime | team-backend-engineer | helper and package validator | completed | unknown |
| /root/simulation_skills_docs | team-docs-maintainer | Skills, profiles and public/source docs | completed | unknown |
| /root/simulation_tests | team-tester | tests and this packet | verification completed | unknown |
| /root/simulation_review | team-reviewer | independent source/risk review | completed | unknown |

### Final broader evidence and remaining gates

- Executed independently scoped batches: `tests/test-validate.ps1`, `tests/test-install-user.ps1`, `tests/test-deployment.ps1`, all exit 0. Package validator rejects each omitted simulation asset and every new role model/effort mutation. Fake-home install covers all new profiles/Skills/helper byte hashes and receipt; observed 0.11.0 package digest `910c398820ba23473543dcbbcd251b54a85441f11df943f9b4068770348792cb`. Synthetic new-to-old deployment removes both roles, both Skills and a new helper inside retained core, preserving unrelated user configuration/Skill. Preview/recovery/fault-injection/ownership regressions remain passing.
- Relevant identity: 83 source/package/runner files from agents, skills, scripts, tests, VERSION and both changelogs; pre/post aggregate SHA256 `4c898554c7d97f663587e44f8b45d8705da4093c39882888c94b84326f6a3218`, unchanged; PowerShell 7.6.5. These are current uncommitted source observations, not acceptance of an unknown later commit. Runtime/Agent/token costs unknown; no measured savings claim.
- Cleanup: all three suites ran their guarded finally cleanup; installer/validator explicitly reported owned temporary directory removal, deployment reported owned cleanup. Read-only exact postchecks confirmed fake-home installer and deployment fixture directories absent. No real home installation, model API, credential or network operation occurred.
- Lead-reported independent results: package validator and validate-docs exit 0; bilingual test exit 0 with its owned fixture removed; main and Reviewer completed full paired-document semantic review. Independent Reviewer closed SIM-REV-01, SIM-REV-02 and SIM-REV-03 with no remaining material finding. Optional skill-creator quick_validate was unavailable because PyYAML is missing; it is not recorded as passing.
- Forward preflight only planned two cases/eight calls. New actor role was unavailable in this session; observed native actor calls were 0/8. This is neither executed native E2E nor target-model acceptance; SIM-05/SIM-06 and every Native.SIM-* case remain pending. No user automation exception or manual acceptance was invented. Final manual status stays manual pending; do not archive.

## Current 1.0.0 follow-up verification

- User-approved changes: AI-only `team-ai-simulate`; distinct model-agnostic `team-ai-simulation-actor-basic` (Luna/medium default) and `team-ai-simulation-actor-advanced` (6.1 Sol/medium); readonly `team-ai-architect` (6.1 Sol/xhigh), distinct from system architecture. Model profile values are source defaults, not proof of resolved identity. Major-line `1.0.0` does not automatically mark stable.
- Planning/TDD: new SIM-08..10 cases and manual-to-native-E2E mapping prepared before writer GO; stage Validate passed. Focused discovery Red: missing new Skill observed before creation. Final source/package profile discovery, validator, fake-home install and synthetic old0.11.0/new1.0.0/old0.11.0 deployment batches executed once after full package freeze, all exit 0. Forecast/cost unknown; previous 0.11.0 evidence was not reused as current passing evidence.
- Existing helper behavior is unchanged by the approved naming/profile scope; full focused helper suite reran once with final discovery and deployment metadata and passed, proving tested local boundary integration rather than inheriting old evidence. Native role routing/AI scope, tier selection and run-level requested-versus-observed model identity remain manual-or-environmental pending because the new source roles are not loaded here. The helper records model identity; it does not expose a native custom-role model override API. No actual installation, network/model API, credentials or real stable pointer mutation occurred.
- Follow-up actually reused handles: `/root/simulation_runtime` (`team-backend-engineer`, validator metadata, completed); `/root/simulation_skills_docs` (`team-docs-maintainer`, profiles/Skills/docs, completed); `/root/simulation_tests` (`team-tester`, tests/packet, verification completed); `/root/simulation_review` (`team-reviewer`, read-only independent review, completed), reused only after the first coherent writer pass. Resolved model/effort unknown. No new child creation claimed. Lead owns final selector/status reconciliation.
- Owned follow-up tests: discovery verifies all current assets, retired-source absence, three new profile defaults, readonly sandbox and VERSION1.0.0; validator mutation tests reject missing/misprofiled/writable roles and syntactically valid retired workflow; install tests verify payload hashes/current identities/no implicit stable pointer; deployment tests explicitly verify old names removed on upgrade, new names absent on downgrade and stable restore, preservation of unrelated files and pinned stable snapshot. All assertions passed.
- Executed current commands: `pwsh -NoProfile -File tests/test-ai-simulation.ps1`, `tests/test-validate.ps1`, `tests/test-install-user.ps1`, and `tests/test-deployment.ps1`, all exit 0. Independent fixtures ran in parallel under approved isolation; no duplicate suite rerun. Full helper checkpoint assertions retain prior corruption, precision, budgets, context, Git protection and complete-record tests with fresh current evidence.
- Current input identity: 85 files in agents/skills/scripts/tests plus VERSION/both changelogs; aggregate SHA256 `dc21b35515cc7b56793c70312dd92a0824d8d19eacdb48ffb398b6c8c234cfc5` identical before/after execution; PowerShell 7.6.5. Helper SHA256 `83f1b0e952172681d762e3df2d377d9d5b3f57d11ca35ff9d5fb1b4ad88d9608`; test SHA256 `57310dc6f2e77c6bbb97612b814d0709e0f6551f53c64e3836d21afa51c1f219`. This is the tested uncommitted source snapshot, not proof for unknown later edits/commits.
- Fake-home installation observed VERSION1.0.0, twelve source role profiles and package digest `cf22503814b346cd702f433fba3476b90b06af6d0675eadffaf0f6756e3b9acd`; exact installed payload hashes match source. Initial installation did not create stable.json. Existing pinned fake-home stable pointer/snapshot remains unchanged across synthetic upgrade/downgrade; pinning itself was explicit controlled test setup, not a real installation decision.
- Cleanup: all four guarded finally blocks completed; helper/validator/installer reported owned fixture removal and deployment reported its ownership/cleanup pass. Independent exact installer/deployment path postchecks returned absent. No generated test fixture or fake home was retained in the user repository or real installation; reusable test source remains under tests/.
- Independent closeout reported by Lead: scripts/validate.ps1, scripts/validate-docs.ps1 -ProjectRoot ., and tests/test-bilingual-docs.ps1 exit 0; bilingual owned fixture removed. Complete README/CHANGELOG pairs were semantically reviewed with equivalent history/values/caveats; public-path privacy check passed. Reviewer found no new material issue, retained prior three resolutions, syntax-checked six PowerShell files and completed readonly review. Optional Python quick_validate was unavailable because PyYAML is missing; no dependency installation or passing claim.
- Remaining gates: no current basic/advanced actor or AI architect native session executed, no target-model/real adapter acceptance, no user manual acceptance. Current Native.SIM-08..10 plus earlier unexecuted native scenarios remain pending; existing manual-to-E2E plan includes them without treating a plan as coverage achieved. Final manual status remains manual pending and packet stays active.
