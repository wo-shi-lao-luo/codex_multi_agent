# Verification: Tiered test execution

Packet schema version: 2
Stage slug: tiered-test-execution
Contract status: active
Final manual status: manual pending
Final manual evidence: Real Codex selection/reuse/budget behavior and user acceptance remain unobserved.

## Stage context

Objective: Preserve complete behavioral coverage while selecting adequate per-iteration execution, trustworthy result reuse and explicit expensive-batch planning.
Scope: Instruction-only shared test-acceptance contract, routing/templates/workflow pointers and coordinated release 0.9.5 public pairs. No scheduler, cache engine, framework, production seam, deleted/weakened tests, actual installation or claimed token savings.
Owners: Lead scope/cost approval, readiness and metadata integration; Docs Maintainer instruction/public-doc writer; Explorer directed read-only test evidence discovery; Tester packet, coverage judgment/selection and final checks; Reviewer independent semantic/evidence review.
Authority: Existing test-acceptance contract owns selection/reuse/budget rules. Existing architecture is adequate; no Blueprint amendment or refactor needed. Repository gates and full manual/E2E mapping remain authoritative.
Data/environment/cleanup: Semantic scenarios use controlled histories/snapshots without expensive external calls; existing PowerShell suites use unique temporary repositories and explicit fake homes with checked cleanup. Real Agent scenarios require separately authorized disposable project. No personal absolute paths or sensitive transcripts retained.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| TE-01 | Complete case plan; bounded module change | Select iteration tests then stage closure | Affected behaviors/dependents plus core smoke executed; omitted cases remain planned/reused with reason, not silently passing | happy |
| TE-02 | Delivery or mandated repository gate | Reconcile complete plan and required suite | Full fallback/gates honored; selective iterations do not waive required final execution | happy |
| TE-03 | Shared/security/config/dependency change | Assess cross-cutting impact | Expand beyond local tests; explicit affected/dependent risk evidence, no narrow-only closure | edge |
| TE-04 | Unknown dependency graph/impact | Ask Explorer scoped questions, then select | Uncertainty explicit and conservative expansion; discovery is not test pass | edge |
| TE-05 | Prior trustworthy result; different Agent | Inspect reachable evidence and unchanged relevant inputs | Reuse allowed without rerunning whole suite solely because Agent changed; material risk may justify reproduction | happy |
| TE-06 | Same commit but dirty code/test/config/dependency/fixture changes | Check working snapshot rather than only commit | Invalidate affected prior results; unchanged relevant subset can remain reusable only with evidence | edge |
| TE-07 | Environment/external state changed or artifact absent | Evaluate trust/current conditions | Old result not reused for changed/unverifiable relevant inputs; rerun or disclose gap | edge |
| TE-08 | Old/missing tests or uncertain assertions | Explorer locates exact IDs/assertions/commands/dependents | Tester judges adequacy and adds scoped plan/gaps; absence/discovery never counts as passing coverage | edge |
| TE-09 | Focused failure repaired | Reproduce narrow failure, then close | Narrow diagnosis first; broader stable regression/core/final checks after fix; failing-only run not final closure | alternate |
| TE-10 | Expensive batch or paid/resource-heavy calls | Declare purpose/range/prior duration or unknown/resources/concurrency | Lead approves scoped cost; soft estimates distinguished from explicit hard user budgets; no invented universal deadline | happy |
| TE-11 | Long healthy operation or budget checkpoint | Inspect progress, preserve state | Continue healthy authorized work; explicit budget prompts safe stop/checkpoint, not blind kill/reset or unauthorised paid calls | edge |
| TE-12 | Whole suite already cheap | Compare selection overhead to adequate full suite | Run whole suite when simpler/adequate; no mandatory filtering framework or cost-saving assertion | alternate |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No executable selector/cache/budget engine implemented. |
| integration | required | Contract routing/public docs/package compatibility observed through existing suites. |
| contract/API | required | Semantic selection/reuse/authority boundary reviewed independently. |
| E2E | required | Every manual scenario mapped to real workflow checkpoints, pending environment/user authorization. |
| regression | required | Existing package/doc/fake-home behavior must remain valid. |
| manual | required | User verifies actual selection/trust/cost decisions. |
| component/UI | not applicable | No application UI change. |
| accessibility | not applicable | No control change. |
| visual regression | not applicable | No rendered interface change. |
| performance/load | conditional | Resource planning applies, but measured savings unavailable. |
| security | required | Paid-call authority, sensitive evidence and safe process preservation reviewed. |
| compatibility | required | Native/fake-home/documentation/stage contracts preserved. |
| data migration/rollback | not applicable | No deployment or state migration. |
| resilience/recovery | required | Failure narrowing, invalidation and progress/budget checkpoints covered. |
| exploratory/usability | required | Independent scenario judgment beyond structural checks. |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Tiered selection with full closure and impact expansion | Missing behavior/gates or excessive repeated suites | E2E | manual-or-environmental | TE-01 through TE-04 and TE-12 | not applicable | Source semantic walkthrough/review complete; runtime/manual pending | No production refactor | Instruction-based decisions cannot be proven by regex or invented selector; independent semantic walkthrough then real workflow observations | Reviewer / user | manual pending |
| Evidence reuse with dirty/environmental input invalidation | Stale or unreachable pass reused | security | manual-or-environmental | TE-05 through TE-07 | not applicable | Source semantic walkthrough/review complete; runtime/manual pending | No production refactor | Relevant snapshots and trust are contextual; no cache runtime is implemented | Reviewer / user | manual pending |
| Explorer discovery versus Tester coverage and broader failure closure | Discovery mistaken for pass or failing-only closure | regression | manual-or-environmental | TE-08 and TE-09 | not applicable | Source semantic walkthrough/review complete; runtime/manual pending | No production refactor | Directed evidence discovery does not execute assertions; source walkthrough cannot prove actual Agent adherence | Reviewer / user | manual pending |
| Batch resource planning, explicit budgets and healthy work | Unapproved expense or unsafe termination | resilience/recovery | manual-or-environmental | TE-10 and TE-11 | not applicable | Source semantic walkthrough/review complete; runtime/manual pending | No production refactor | Authority and process health require real decisions; no universal timer or fake timeout parser | Reviewer / user | manual pending |
| Public pairs and native package compatibility | Broken routes/version/install payload | integration | test-after | Existing doc/native and isolated package/install/documentation/stage suites | not applicable | Native/docs validators and five isolated suites exit 0 on coherent 0.9.5 source | One final coherent-source run each, no source refactor | Existing suites exercise structural/payload boundaries after new instructions exist; no fabricated pre-edit Red or behavioral enforcement claim | Tester | passing |

## Automated test and E2E plan

Discovered commands: scripts/validate.ps1; scripts/validate-docs.ps1 -ProjectRoot .; tests/test-bilingual-docs.ps1; tests/test-validate.ps1; tests/test-install-user.ps1; tests/test-documentation.ps1; tests/test-stage-verification.ps1; skills/team-core/scripts/stage-verification.ps1 -Action Validate -ProjectRoot . -StageSlug tiered-test-execution. Native/doc checks are cheap core smoke; changed shared test instructions, release pairs and metadata justify related package/install/doc/stage suites at coherent closure. Unrelated deployment/OpenSpec/DB/UI suites remain outside this instruction-only change absent new impact evidence; preserve repository-mandated gates if applicable. No test execution until Lead final GO, except packet structural validation.

### Execution and observation choices
| Case / test ID | Execution entrypoint and real boundary | Runner / command | Observation mode and rationale | Retained browser / visual checkpoints | Evidence / drill-down / gaps |
| --- | --- | --- | --- | --- | --- |
| TE-01 through TE-12 | Actual contract and controlled real Codex workflow decisions | Independent semantic walkthrough, then authorized disposable scenarios | Review exact case/assertion IDs, snapshot/trust rationale, omitted/reused status, scope/cost authority | None; not a visual app | Source review is not runtime E2E pass; no measured savings |
| Compatibility | Real native/doc commands and unique-temp fixture/fake-home suites | Listed existing entrypoints | Summary-first; inspect failure/safety effects, preserve exact outputs/cleanup | None | Commands must execute against coherent current inputs, no inherited prior-task pass |

### Manual-to-automated coverage mapping
| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| TE-01 | Runtime.TE-01 module iteration and stage: selected affected/dependent plus core smoke, complete plan statuses | Semantic tier review | manual pending | Future Agent adherence unobserved |
| TE-02 | Runtime.TE-02 delivery with required full suite: inspect final gate execution and gaps; explicitly fresh gate cannot use reuse, unknown freshness never assumed satisfied | Semantic full-fallback review | manual pending | Selection does not waive repository gates |
| TE-03 | Runtime.TE-03 shared/security/config/dependency mutation: inspect expanded scope before closure | Semantic risk-boundary review | manual pending | Each cross-cutting condition must be assessed |
| TE-04 | Runtime.TE-04 unknown graph: Explorer facts/uncertainty, Tester conservative expansion | Semantic discovery/selection review | manual pending | Discovery not passing assertions |
| TE-05 | Runtime.TE-05 new Agent, same relevant inputs and reachable trusted artifact; reuse exact checked assertions; reproduce material risk where justified | Semantic evidence-trust review | manual pending | Different role is not automatic rerun or automatic trust |
| TE-06 | Runtime.TE-06 unchanged commit with each dirty code/test/config/dependency/fixture input: invalidate affected evidence, document any unchanged relevant subset | Semantic working-snapshot review | manual pending | Commit ID alone insufficient |
| TE-07 | Runtime.TE-07 changed environment/external state or lost artifact: rerun or disclose gap | Semantic invalidation review | manual pending | No inaccessible result counted passing |
| TE-08 | Runtime.TE-08 missing/old tests: Explorer exact IDs/assertions/commands/dependents, Tester adequacy judgment and gaps | Semantic role-boundary review | manual pending | Discovery does not replace test execution or add coverage by name |
| TE-09 | Runtime.TE-09 focused failure then repair: narrow reproduction and wider stable closure/core/full gates | Semantic failure/closure review | manual pending | No failure-only final success |
| TE-10 | Runtime.TE-10 expensive batch plan: purpose/range/duration or unknown/resources/paid calls/concurrency, Lead approval and explicit budget | Semantic cost-authority review | manual pending | No paid/expensive experiment needed to inspect planning |
| TE-11 | Runtime.TE-11 healthy long progress and hard budget checkpoint: safe preservation/stop decision; paid batch without authority does not start; concurrent duplicate/shared-state jobs or snapshot drift cause safe replan/invalidation | Semantic progress/budget/concurrency review | manual pending | No unsafe hang/kill or paid-call injection |
| TE-12 | Runtime.TE-12 cheap whole suite: adequate full run chosen without obligatory selector overhead | Semantic pragmatic-whole-suite review | manual pending | No claim selection always cheaper |

## Human verification script
### Preparation
1. Use disposable project and reviewed snapshot. Supply realistic existing test IDs/results and input snapshots with no secrets; authorize real workflow execution separately. Keep full case/E2E/manual plan. Cleanup only exact owned fixtures; do not run paid calls or unsafe processes to create evidence.
### Happy path
1. TE-01: request bounded module change. Expected: selected affected/dependent checks plus core smoke; stage reassesses coverage and omitted/reused cases remain explicitly tracked.
2. TE-02: request delivery with repository full-suite gate. Expected: final required gate honored, all case statuses reconciled; no iteration-selection exemption. A required fresh-current-revision result is not replaced with reuse unless gate explicitly allows it; unknown freshness is not assumed passing.
3. TE-05: new Agent receives trusted reachable result and unchanged relevant inputs. Expected: may reuse exact assertions without whole-suite rerun merely for identity change; material-risk reproduction allowed with reason.
4. TE-10: propose expensive batch with prior duration or unknown, resources, paid calls and concurrency. Expected: purpose/range/cost approved, estimate not mistaken for hard user budget, no universal timer.
5. TE-12: supply cheap adequate whole suite. Expected: run it when simpler than filtering, no new framework forced.
### Recommended edge cases
1. TE-03: change shared dependency, security rule, config and dependency inputs. Expected: expand beyond local suite with risk evidence.
2. TE-04: dependency graph unknown. Expected: directed Explorer evidence and uncertainty, conservative Tester plan; discovery not pass.
3. TE-06: retain commit but dirty code, tests, config, dependency or fixtures. Expected: affected cached evidence invalidated; only demonstrably unchanged relevant subset reusable.
4. TE-07: alter environment/external state or make evidence artifact unreachable. Expected: rerun/disclose gap, not infer pass from old summary.
5. TE-08: locate old/absent test. Expected: Explorer returns actual files/IDs/assertions/commands/dependents/gaps; Tester judges coverage and plans missing checks; no discovery-as-pass or deleted/weakened tests.
6. TE-09: repair focused failure. Expected: narrow reproduction then broader stable closure checks and required final gates, not only formerly failing test.
7. TE-11: healthy long run then explicit budget checkpoint. Expected: inspect progress and take safe authorized stop/checkpoint decision; no blind kill/reset or unapproved external expense. Propose a paid batch without authority: expected ask before starting, not treat Lead plan as expanded user permission. Propose duplicate concurrent/shared mutable fixture jobs or source drift between batches: expected avoid conflicting runs, replan safe independent same-snapshot execution and invalidate affected evidence.
### Result
Observations: manual pending. No runtime/E2E pass or automation exception accepted; archive only after user verifies or explicitly defers.

## Verification record

Pre-writer plan: instruction adherence manual-or-environmental; existing compatibility suites test-after. No executable selector/cache/budget evaluator or new regex enforcement tests. Test plan remains complete while chosen execution is bounded; all manual cases map to equivalent runtime checkpoints. Existing dirty work preserved; no production writes or previous packet edits.

Invocation planning: /root/concurrency_tester reused original selected team-tester; /root/test_scope_explorer selected team-explorer as reported by Lead, directed read-only discovery. Tester spawns no children; loaded metadata unknown. Lead owns actual final roster and scope/cost authority. Await writer/final verification GO; packet validation is structure, not test behavior pass.

Final independent current-source verification: scripts/validate.ps1 exit 0; scripts/validate-docs.ps1 -ProjectRoot . exit 0; tests/test-bilingual-docs.ps1 exit 0 and isolated bilingual fixture removed; tests/test-validate.ps1 session 69529 exit 0 and copied-package root removed; tests/test-install-user.ps1 session 7208 exit 0 and fake-home root removed, exact absence independently confirmed; tests/test-documentation.ps1 session 41399 exit 0 and documentation root removed; tests/test-stage-verification.ps1 exit 0 and stage root removed. All were executed once on this coherent current source, not inherited from 0.9.4. Writer remained idle during runs as confirmed by Lead; unique fixture roots avoid shared mutable test state. Native/docs checks supply cheap core smoke; package/install/doc/stage checks cover changed shared instructions, Explorer profile payload, release pairs and metadata. No unrelated broad deployment/OpenSpec run justified by this scoped instruction-only change; no required gate intentionally waived.

Source/result provenance: canonical test-acceptance-contract.md SHA256 F52363ED43FB51AF4BF58EB81AB4FBBFD013C4B5E885309F042090DAD74D23FF; fake-home installer packageDigest 44b6e59e6b2c9ccc9dedd3a60c470a64aa4698dcb73c05ae6efce7307e8a4ad8 and receipt version 0.9.5. Existing installer suite enumerates all source agents and Skill files, verifies actual installed SHA256 equals source and every receipt entry; changed shared contract and Explorer instructions are covered. WhatIf nonmutation and managed/conflict/backup checks passed. All installer calls specify temporary CodexHome/AgentsHome; no real home installation/config write. Existing Git-ignore permission warnings are nonfatal, no personal settings changed.

Semantic TE-01 through TE-12 walkthrough: selection retains full case plan and stage/core checks; cross-cutting/unknown impact expands conservatively. Canonical instructions explicitly retain repository gate freshness and prohibit unknown gate reuse assumptions. Reuse binds actual assertions/input provenance including dirty source/tests/config, dependency/fixtures/runtime/environment/external state, with reachable artifacts; new Agent alone neither forces rerun nor validates stale evidence. Directed Explorer returns exact paths/IDs/assertions/commands/real boundaries/dependencies/artifacts/gaps, not pass/skip/sufficiency decisions. Tester owns coverage and execution, Lead applies existing authority, only user expands external/paid/budget authority. Cost unknown stays unknown; no universal timer, blind kill, unauthorized paid start or concurrency. Duplicate/shared-state test batches avoided, same snapshot required, drift reopens affected evidence. Narrow failing reproduction does not imply complete closure. Cheap full suite remains allowed; complete manual/E2E mapping unchanged. This source review does not prove future Agent/runtime compliance or measured savings. Independent Reviewer reports no material source findings; runtime/manual cases remain pending.

Public-document and comment self-check: both complete 0.9.5 release sections preserve equivalent tier/reuse/Explorer/authority limits; both README version references agree and remain orientation, not test-result journals. Existing 0.9.4 history retained. Targeted public-file search found no personal machine absolute paths. No test/production logic changed by Tester; human steps explain each scenario/expected result with equivalent E2E checkpoints. Explorer model gpt-6-luna, effort medium, sandbox read-only unchanged; only developer_instructions changed. Lead's documentation.ps1 kitVersion 0.9.5 metadata-only stamp is declarative provenance, not a new logic unit; isolated recording compatibility passed.

Optional helper limitation: fresh skill-creator quick_validate.py attempt for skills/testing-engineering exited 1 before checks with ModuleNotFoundError yaml as reported by Lead. No dependency installation/shim; helper unavailable, not passing. Native package validation and semantic checks provide their actual limited evidence; they are not a replacement claim of helper success.

Written rule traceability: skills/team-core/references/test-acceptance-contract.md Efficient test execution / Tier selection, reuse, and resource limits / Directed test-surface discovery are the canonical written rules; role-routing.md contains the targeted discovery row and boundaries; execution-templates.md Work contract Tier/reuse plan and Verification record Per-batch disposition hold evidence. Skill file routes are written in skills/team-core/SKILL.md final test-planning paragraph; skills/testing-engineering/SKILL.md Discover the test surface; skills/team-dev/SKILL.md Establish the work; skills/team-plan/SKILL.md test planning; skills/team-review/SKILL.md efficient execution audit. agents/team-explorer.toml developer_instructions contains bounded evidence-only discovery, not model/config changes. These are actual source edits, not conversation memory.

Actual task roster: /root/test_scope_explorer fresh selector team-explorer, directed read-only discovery, complete; /root/repair_guard_writer_v2 reused original team-docs-maintainer, bounded current instructions/public-doc/Explorer-instruction writer, complete; /root/concurrency_tester reused original team-tester, packet/independent current-source verification, complete at handoff; /root/tiered_test_reviewer fresh team-reviewer, independent semantic/evidence review, source and final evidence review complete with no material findings. Reviewer independently matched canonical provenance and reused the actual suite evidence without duplicate execution. No creation failures in this task, no generic fallback or child recursion. Selected profiles/handles are not confirmed loaded identities/models/effort; unreported metadata unknown. Lead owns final readiness and roster reconciliation. Real E2E/manual stays pending; active packet not archived.
