# Verification: Risk-proportional web engineering

Packet schema version: 2
Stage slug: web-engineering
Contract status: ready
Final manual status: manual pending
Final manual evidence: Native adoption, target-app outcomes and user acceptance not observed.

## Stage context
- Objective: short conditional frontend/backend guidance within existing lifecycle; demo/MVP avoids needless hardening but never waives real risks.
- Authority: approved _work/web-engineering/work.md; baseline 5988c5ec2c28d150b44d809d976a47b5a0fd2c46. No PRD/OpenSpec, architecture or schema migration applies. Lead owns documentation sufficiency and start GO.
- Scope: Tester owns tests/test-web-engineering.ps1 and this canonical packet. Production instructions/public pairs owned by Docs; independent review/source-forward exercises owned by Reviewer. No production edits, actual homes, network, Git writes or children by Tester.
- Fixtures: exact-source controlled package copies in unique codex-web-engineering-test GUID temp roots. Cleanup resolves exact owned parent/name; preserve other owners' work. Installation compatibility repairs out of scope.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| WEB01 | Source before/after production | Require four exact guide paths | Missing source fails before implementation; final resources present | happy / edge |
| WEB02 | Frozen source | Check agreed discovery links and copied actual validator; omit each guide and restore | Routes discover existing assets; broken resource references reject; exact bytes restored | integration / edge |
| WEB03 | Frozen package | Copy via actual installer to explicit disposable homes | Four source/installed/receipt hashes equal; cleanup safe | packaging |
| WEB04 | Frozen instructions | Independent neutral source-forward decisions only | Apply relevant risks without extra lifecycle or blanket hardening | source-forward |
| WEB05 | Eligible native task/session | Observe same scenarios in actual work | Applicable guidance adopted proportionately; genuine outcomes recorded | manual |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No executable web rule or app added. |
| integration | required | Actual package validator and installer consumers. |
| contract/API | required | Four assets and agreed discovery links, not target API tests. |
| E2E | required | Offline distribution chain; native scenario counterparts pending. |
| regression | required | Existing discovery, offline package and language-pair facts retained. |
| manual | required | Proportionality/native adoption cannot be proven by regex. |
| component/UI | not applicable | No target component or application implemented. |
| accessibility | conditional | Relevant interaction guidance source-reviewed; real target UI absent. |
| visual regression | not applicable | No rendered product changes. |
| performance/load | conditional | Guidance proportionality assessed; no runtime benchmark or savings claim. |
| security | required | Demo labels cannot waive real data/auth/exposure/side-effect risks. |
| compatibility | required | Existing lifecycle/roles/packets/TDD and distribution retained. |
| data migration/rollback | not applicable | No runtime/schema/data migration. |
| resilience/recovery | required | Source scenarios cover stale requests, retry/idempotency/partial failure when relevant. |
| exploratory/usability | required | Independent bounded source-forward scenarios plus native pending. |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| WEB01 guide distribution | Missing normative resource | contract/API | test-first | test-web-engineering.ps1 -RedOnly and default | 2026-10-10 exit1 actual missing skills/team-core/references/web-engineering.md before production | Frozen default command exit0, all four actual resources present | Frozen source hashes unchanged before/after; no subsequent refactor | none | Tester | passing |
| WEB02 discovery/consumer | Missing guidance or broken offline links | integration | test-after | test-web-engineering.ps1 | not applicable | Exit0: six actual validator checks and twelve exact routes | Full package manifest unchanged/restored; no subsequent refactor | Exact route subset agreed with writer; generic validator unchanged, resource source has genuine Red | Tester | passing |
| WEB03 final payload | Installer omits new references | integration | test-after | test-web-engineering.ps1 -InstallOnly | not applicable | Exit0: all four source/installed/receipt hashes equal | Final resource hashes rechecked unchanged | Existing installer unchanged; final four-resource byte proof adequate | Tester | passing |
| WEB04 conditional guidance | Heavy demo process or waived real risk | manual | test-after | Forward.WEB01-08 | not applicable | Eight independent neutral source exercises consistent; final actual-diff review no material findings | Reviewer confirmed four-guide/test hashes, unchanged validator and AST/diff clean | Instructions have no deterministic semantic router; source reasoning narrower than native behavior | Reviewer | passing |
| WEB05 native use | Source mistaken for improved engineering | manual | manual-or-environmental | Native.WEB01-08 | not applicable | pending | not applicable | No target app or eligible native task; no native/effectiveness/cost guarantee | Lead / User | manual pending |

## Automated test and E2E plan
- Existing convention: standalone PowerShell assertions and exact-source controlled copies, as in test-team-entry.ps1. Run source Red only after packet Validate; dependent runs wait for accepted readiness/GO and production freeze. Forecast unknown; no paid/external call.
- Due frozen checkpoint: focused resource/route/validator tests, one fake-home payload proof, AST/comment/readability/diff checks and packet Validate. Docs owner executes required validate-docs/test-bilingual-docs plus complete paired semantic read; no duplicate Tester runs. Generic validator/installer unchanged: no unrelated full suite unless changed inputs/failure demand expansion.
- Native deferred owner Lead/User, IDs Native.WEB01-08, status manual pending, trigger separately authorized eligible engineering task; flush before claiming actual adoption/outcomes. No automation exception accepted. Source-forward Reviewer executes neutral inputs before criteria exposure; no browser/model/Git/install operations.

### Execution and observation choices
| Case / test ID | Execution entrypoint and real boundary | Runner / command | Observation mode and rationale | Retained browser / visual checkpoints | Evidence / drill-down / gaps |
| --- | --- | --- | --- | --- | --- |
| WEB01/02 | Actual guides/routes and copied validator | test-web-engineering.ps1 | Exit, exact discovery targets and manifest restoration | not applicable | passing: six validator checks/twelve routes; packaging only |
| WEB03 | Actual copied installer, fake homes | -InstallOnly | Four SHA256 source/installed/receipt matches | not applicable | passing; no active loading claim |
| WEB04 | Frozen source-forward review | Forward.WEB01-08 | Selected conditional guidance and preserved boundaries | not applicable | eight source exercises consistent; final review no material findings, no native evidence |
| WEB05 | Real engineering task | Native.WEB01-08 | Actual applicable checks, outcomes and scope | Target-task checkpoints if applicable | manual pending |

### Manual-to-automated coverage mapping
| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| WEB01/02/03 | Source/discovery -> actual validator -> fake-home resource/receipt proof | Exact assets/routes and omission/restoration checks | passing: actual frozen consumers and four hashes | Cannot establish native use |
| Native.WEB01-08 | Same conditions and expected checkpoints below in eligible actual task | Forward.WEB01-08 source reasoning only; package checks prove availability | manual pending | No native execution or user exception; no E2E effectiveness/savings claim |

## Source-forward and native scenarios
| ID | Conditions | Expected decision / observable checkpoint |
| --- | --- | --- |
| WEB01 | Static local fake-data landing-page demo | Existing light correctness/UI baseline; no fabricated backend/security audit, production stack or blanket guide loading. |
| WEB02 | Small CRUD MVP with real personal data and authenticated writes | MVP label does not waive validation/authorization/data exposure/mutation recovery; only relevant guidance. |
| WEB03 | Search requests complete out of order with selected account/cache changes | Identify state authority/derivation, stale-response/race and cache-scope risks; focused cases under existing packet. |
| WEB04 | Optimistic save fails or partially completes | Relevant mutation reconciliation/recovery and user feedback; no blanket library mandate. |
| WEB05 | Keyboard-dependent form, large interactive list or slow real page | Applicable interaction/accessibility/performance evidence; React-specific hints conditional, no assumed benchmark success. |
| WEB06 | Retried externally visible backend operation and concurrent updates | Contract/error meaning, retry ownership/deadline/idempotency/concurrency/partial failure proportionate to actual operation. |
| WEB07 | Simple isolated backend read versus exposed privileged/unbounded endpoint | Simple read stays light; actual auth/bounds/exposure risk triggers needed security/reliability guidance, not production audit by label. |
| WEB08 | Writer hands relevant risks to Tester/Reviewer on existing task | Same selected risks/packet/TDD and evidence reused; no new Agent, report, mandatory suite/audit stage or fabricated approval. |

## Human verification script
### Preparation
1. Scripted fixtures use exact owned temp roots only. Native checks require separately authorized task and actual capability/identity evidence.
### Happy path
1. Run focused test after freeze. Expected: four resources/routes available, actual copied validator accepts intact package and rejects missing linked guides, restoration exact.
2. Run -InstallOnly once. Expected: four source/installed/receipt hashes equal in disposable homes only; fixtures removed.
3. Execute Native.WEB01-08 with conditions above. Expected: relevant guidance and existing gates preserved; record actual observations without inferring use from installed files.
### Recommended edge cases
1. Native.WEB01/02/07: contrast fake-data demo with real data/exposure. Expected: no heavy process for absent risk and no waived actual risk.
2. Native.WEB03/04/06: retain stale result, failed mutation and retry/concurrency conditions. Expected: applicable focused engineering evidence, not blanket tool adoption.
### Result
- Scripted package and fake-home results passed, exact owned fixtures removed; eight independent source-forward outcomes consistent and final independent diff review no material findings. Native/user acceptance remains manual pending; retain active packet.

## Verification and invocation record
- Original /root/delivery_tests selected team-tester reused; no children created. Docs/Reviewer original named handles reused by Lead; resolved host identity/model unknown. No supported close/capacity-release claim.
- Skills: testing-engineering and shared execution/TDD/test/comment/readability contracts; workspace-hygiene for owned fixture lifecycle. Local PowerShell/patch tools and collaboration only for Tester; no network/service calls.
- Phase1 schema2 packet Validate exited0 before test creation/execution. Actual command pwsh -NoProfile -File tests/test-web-engineering.ps1 -RedOnly then exited1: WEB01 missing source guide skills/team-core/references/web-engineering.md. No fixture created by Red, no production writes. Production-dependent runs remain held for GO/freeze.
- Lead confirmed twelve exact discovery routes: six shared-guide consumers (frontend/backend/testing/code-review/team-dev and core), two frontend local guides, one backend local guide and shared guide to all three domain guides. Optional frontend-design/ui-quality shared links are not required. Exact targets sent to Docs owner; tests never assert semantic phrases or read-all behavior.
- Authored test scenarios and helper interfaces include purpose/expected outcome and ownership/cleanup constraints. Phase1 test AST parses clean; no lines over 120 characters or trailing whitespace, scoped diffcheck clean. Manual comment/readability self-check matched explanations to actual assertions, no configured formatter replacement. Updated packet Validate exit0/manual pending; no source-forward/native result claimed.
- After Lead freeze/GO: pwsh -NoProfile -File tests/test-web-engineering.ps1 exited0, "Web engineering package tests passed: 6 validator checks, 12 routes." Actual intact package accepted without byte writes; each guide omission rejected by real generic link validator; exact restoration accepted and complete file manifest matched. Route assertions are availability/discovery only, not semantic proportionality. No validator/installer changes or broad full suite needed for this instruction-only delta.
- One final pwsh -NoProfile -File tests/test-web-engineering.ps1 -InstallOnly exited0: four actual source/installed/receipt hashes equal; packageDigest 2547c72ebc02ec32bdb5ce993dd85ae183b13ceedb997a9567a16b64477b66a4. Actual copied installer used explicit uniquely owned fake CodexHome/AgentsHome only. Source boundary copied actual agents/skills/scripts/config/VERSION/changelog pair and existing required formatter guide/packet, excludes all Work and both README files. Later README.zh-CN precision correction therefore does not affect this payload snapshot. No fabricated production content or validator exclusion change. All owned processes finished and exact GUID fixture roots removed.
- SHA256 before/after checks identical: scripts/validate.ps1 77C254C8EB5AA136F034FDDBE1634883E1F5A717C241F3EB2FD8F704343BA723; shared web-engineering.md 6CD02473D7E4AC6A6A299449EE845F12856DCD8D3E7A99D9568D03401AA9DE3C; frontend state-data.md FA75CC8123CBCD4DFD026B3D8B971F75D1A86323EC5E7898DF9752A7B8F51559; usability-performance.md 278907EAD6513C684F6AB100EDACF617BE4D1A9795F7705589208B1D8825F621; backend service-reliability.md A2DA287F07C04AD5411780BE36809AC317EF4D3C755FA393687CCDFCC55170B9. Frozen test SHA256 173BF55E7FE97F149F5A258F7950BEC8C20B445DAC016A9ED10DADB759557AF6. Final test AST/width/trailing-whitespace/scoped diffcheck clean; comment self-check matched scenario/interface explanations to actual assertions. No target product/browser/model/effectiveness or savings evidence is claimed.
- VERSION remains 1.0.7. Known raw-root foreign Work broken-link issue is not repaired or represented as passing; controlled package success is narrower. Lead reports Docs final scripts/validate-docs.ps1 -ProjectRoot . and tests/test-bilingual-docs.ps1 both exit0 after Chinese precision correction, fixtures cleaned; full paired README/changelog semantic reading complete. Tester does not duplicate these checks.
- Lead-reported independent Reviewer neutral exercises before expected criteria exposure: WEB01 static fake-data demo retained light UI baseline; WEB02 real CRUD retained actual risks; WEB03 out-of-order response and identity boundaries recognized; WEB04 provisional versus committed state/reconciliation distinguished; WEB05 keyboard/focus and actual performance measurement selected only as relevant; WEB06 retry owner/deadline/idempotency/partial failure preserved; WEB07 simple read versus exposed privilege/bounds distinguished; WEB08 existing developer self-check/same-risk testing-review and original gates retained. All eight were consistent with bounded guidance. These are source-following decisions, not native workflow/UI/backend or cost-savings evidence. Formal actual-diff review completed with no material findings; Reviewer independently confirmed AST/diff clean, matching guide/test hashes and unchanged validator, covering tracked changes, new guides/test/packet, shared authorities and actual consumers.
- Final packet Validate exit0/manual pending. Original /root/delivery_docs under team-docs-maintainer completed production and bilingual checks; /root/delivery_review under team-reviewer completed neutral exercises and independent review; /root/delivery_tests under team-tester completed assigned packet/tests. Host-resolved identity/model remains unknown; no supported child-close or capacity-release claim. Scripted and source-level checkpoints complete, native/user acceptance remains pending. No further test/source edits planned; Lead readiness refresh is next.
