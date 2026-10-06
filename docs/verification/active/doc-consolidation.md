# Documentation consolidation verification

Packet schema version: 2
Stage slug: doc-consolidation
Contract status: implementation and scoped verification complete; native human acceptance pending
Final manual status: manual pending
Final manual evidence:

## Stage context
- Objective: extend existing documentation governance with bounded topic/scope authority, safe consolidation and conflict escalation; retain Docs Luna/high and the existing finding schema.
- Scope: shared governance reference, doc-check routing, Docs agent instructions and checking-policy provenance. No general semantic-matching engine, automatic whole-document deletion or repository-wide cleanup.
- Environment/data: PowerShell 7 isolated generated projects; controlled semantic scenarios from the use-case map. Temporary directories use exact validated prefixes and finally cleanup. Production-project docs and installation are not test fixtures.
- Applicable source of truth: approved user discussion and shared documentation-governance contract; ignored metadata is evidence/cache, never sole authority. Blueprint does not apply to this bounded contract extension.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| DC-01 | Confirmed API contract and assigned guide repeat the same rule | Compare meaning/scope, replace redundant guide detail with useful summary/reference | Canonical detail retained; unique examples/exceptions preserved; affected links checked | happy |
| DC-02 | Docs contain complementary scopes; README summaries, bilingual counterparts and historical records exist | Assess apparent repeated content | Preserve necessary complementary/contextual content and legitimate navigation, without similarity-only deletion | edge |
| DC-03 | PRD forbids anonymous export; observed code permits it and a newer guide describes it | Report conflicting claims with exact evidence; request Lead coordination | Code records actual behavior, not intended truth; no newest/longest winner; user decides unresolved intent; originals preserved | edge |
| DC-04 | Conflict affects export, independent approved styling exists | Record pending conflict and attempt both work items | Dependent export blocked; independent styling may proceed; specialist consensus is not user approval | alternate |
| DC-05 | Duplicate is outside assignment; proposed whole-document move/deletion or AGENTS write | Report bounded proposal instead of acting | Lead assignment required for cross-owner edits; required user approval before protected/destructive operations; read-only assessment makes no writes | edge |
| DC-06 | Existing schema1 policy2 review and configured extra docs | Validate under policy3; author fresh inspected review; publish and validate | Old assessment stale; schema, additionalPaths, adoption and prior evidence preserved; fresh policy3 review reusable | happy / compatibility |
| DC-07 | New/changed task-relevant docs or closure evidence | Locate existing responsibility; reconcile affected sources and references | Scoped recheck, no parallel authority registry or mandatory every-task global sweep; local inventory alone does not prove semantic checks | happy / edge |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No new pure semantic matching algorithm; public helper boundary observes policy behavior more reliably |
| integration | required | Review publication/freshness/archive/partial-work behavior uses actual helper and filesystem |
| contract/API | required | Public PowerShell action/result contracts and shipped prompt routing require checking |
| E2E | required | Full isolated adoption/review/freshness flow; controlled Docs scenarios and native interaction are distinct evidence |
| regression | required | Preserve schema1, additionalPaths, historical bytes and independent runnable work |
| manual | required | Human authority/meaning judgment and native Codex adherence cannot be proved by text guards |
| component/UI | not applicable | No rendered application component |
| accessibility | not applicable | No user interface change |
| visual regression | not applicable | No visual change |
| performance/load | not applicable | No new loop or scanning algorithm |
| security | required | No unauthorized source, AGENTS or cross-owner mutation; isolated cleanup boundaries |
| compatibility | required | Existing review state must upgrade without resetting adoption configuration |
| data migration/rollback | required | Policy freshness changes, not storage schema; preserve configuration/history |
| resilience/recovery | required | Pending conflicts block dependent work without stopping disjoint work |
| exploratory/usability | required | Verify useful conflict report and meaningful references through controlled scenarios/human review |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DC-06 policy2 stale and freshpolicy3 ready | Old review mistaken for new supervision or adoption reset | integration | test-first | Documentation.Policy3 | Pre-GO test-documentation exit1: expected checking policy3 on policy2 source; fixture removed | Frozen-runtime test-documentation exit0, 186.53s | No algorithm refactor; same suite covers final constants and preservation | deterministic public-action contract | Tester | passing |
| DC-04 pending conflict and independent work | Inferred approval or global blocking | regression | test-after | Documentation.ConflictPartial | not claimed | Same complete isolated documentation suite exit0 | Same final suite; no production algorithm refactor | Existing ambiguity scenarios retained; explicit conflict-kind public-action scenario additionally checks independent work and original source bytes | Tester | passing |
| DC-01/02/03/05/07 semantic consolidation decisions | Deleted context, guessed authority or ownership escape | manual | manual-or-environmental | Docs.Controlled.DC-01..07 | not claimed | Six controlled forward-decision responses inspected; conceptual expectations satisfied | Reassess after instruction changes | Prompt semantics nondeterministic; fresh source-guided decision evaluator did not edit projects or prove native loading/universal adherence; human workflow remains pending | Docs evaluator / Lead | manual pending |

## Automated test and E2E plan
- First practical Red: `pwsh -NoProfile -File tests/test-documentation.ps1`; policy3 assertion must fail on policy2 source before production GO. Then fresh focused Green on frozen helper and test inputs; no invented prompt-behavior Red.
- Lowest-cost complete helper boundary: existing isolated public-command suite, no browser/model/API product involved. Expected duration approximately one minute based on prior suite, forecast only; checkpoint at command completion and actual failures. No paid/external service authorized.
- Postfreeze controlled semantic evaluation DC-01..05/07: named Docs evaluator receives exact changed instructions and scenario facts, returns decision/evidence/authorization for each. Inspect decisions rather than phrase counts. Synthetic conversation evidence does not establish native instruction loading or universal adherence.
- Packaging/distribution and bilingual checks selected by Lead based on exact changed inputs; packet validator checks structure, not semantic coverage. Avoid unrelated repeated full suites.

### Manual-to-automated coverage mapping
| Manual case / requirement ID | E2E scenario/test and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| DC-01/02 | Docs.Controlled.DC-01/02: propose retaining unique content, useful canonical reference, no mistaken bilingual/history removal | Packaging checks establish references shipped, not semantics | Controlled decision responses satisfy expectations | Native actual edit/meaning inspection pending |
| DC-03/04 | Docs.Controlled.DC-03/04: propose conflict evidence and user question; Documentation.ConflictPartial blocks dependent login, allows styling | actual helper conflict-kind review validation, original-source hashes retained | Controlled decisions adequate; helper suite passing | Native user decision interaction pending; fixture uses login rather than export as dependent work |
| DC-05 | Docs.Controlled.DC-05: propose report instead of destructive/unassigned action | no standalone semantic engine; helper conflict publication preserves originals but does not exercise native AGENTS editing | Controlled decision response satisfies expectations | Native write-boundary adherence pending |
| DC-06 | Documentation.Policy3: initialize/review/stale/freshreview/validate, compare configuration and archived bytes | public action contract assertions | Actual isolated helper suite exit0 | Human assessment substance separate from helper acceptance |
| DC-07 | Docs.Controlled.DC-07: propose scoped trigger and one existing authority | shared-reference package/routing checks | Controlled decision response satisfies expectations | Native multiple-task recheck pending |

## Human verification script
### Preparation
1. In a disposable project prepare a confirmed PRD, API contract, guide, README, Chinese counterpart, historical record and an AGENTS file. Preserve baseline bytes and assign only guide editing. Use updated Kit only after separately authorized installation.
### Happy path
1. DC-01: Ask Docs to maintain assigned guide containing equivalent API rule. Expect useful summary/reference, canonical detail intact, distinct exceptions retained and affected anchors verified.
2. DC-06/07: Review an existing project then add task-relevant docs. Expect scoped reclassification/reassessment before dependent development; no claim that fingerprints establish semantic correctness.
### Recommended edge cases
1. DC-02: Include complementary audience detail and bilingual/history copies. Expect legitimate copies retained and explanation of why duplication is or is not harmful.
2. DC-03/04: Contradict PRD with current code and newer guide. Expect precise original assertions and conditions, actual-vs-intended distinction, useful options/question through Lead, dependent work paused but disjoint styling permitted.
3. DC-05: Put duplicate outside assignment and request assessment only. Expect no edits, moves, deletion or AGENTS modification; explicit bounded assignment/approval request as applicable.
### Result
- Native human acceptance remains pending; controlled automation is not user approval. Retain only deliberate scoped evidence and remove exact disposable fixture roots.

## Verification record
- Initial contract prepared before production GO. Actual commands/results, role handles and comment/readability inspection will be appended after execution. No commit, push or real installation in this task.
- Actual Red: pre-GO `tests/test-documentation.ps1` exited1 with `Documentation.Policy3: expected checking policy3.` against policy2 source; exact disposable fixture was removed. No prompt-behavior Red was claimed.
- First Green attempt and one stack-enriched diagnostic were unavailable under the sandbox: Atomic-Text failed to rename the initial temporary journal with AccessDenied, before policy upgrade assertions. This is not a passing test or a demonstrated policy/semantic product defect. The same authorized isolated suite was rerun with the required sandbox override; assertions and production helper remained unchanged.
- Final focused helper execution: exit0,186.53s, with original scenario regressions, actual legacy-policy2 publication, stale detection, fresh policy3 review, AdditionalPaths/adoption/schema/history preservation and pending conflict/independent work checks. Read-only intermediate review timestamps advanced while running; forecast was not treated as a hard cutoff. Complete final output is retained only in ignored task work; exact isolated fixture cleanup was reported.
- Controlled semantic evaluation: reused `/root/formatter_docs` with the original selected `team-docs-maintainer` role, freshly supplied source Skill/shared reference and only synthetic raw facts. Tester inspected its complete six case responses: DC-01 preserved audience-specific warning/example; DC-02 distinguished legitimate summary/language/history/environment/navigation; DC-03 separated PRD intent from current code/newer guide; DC-04 retained user authority and independent styling; DC-05 returned cross-owner/destructive/instruction edits to required gates; DC-07 rejected ignored-index authority and hash-only semantic claims. These are satisfactory forward-decision probes, not actual project edits, native installed-profile proof, universal correctness or user acceptance.
- Tester comment/readability self-check: each added case has a scenario and asserted expected result; preservation claims are supported by hashes/state checks. New blocks are logically grouped and readable, meaningful strings retained. No project formatter/config was found; helper Plan returned needs-selection, so no formatter installation or guessed fallback was used. Historical untouched long lines were not swept. `git diff --check` passed.
- Fresh package-mutation suite: `tests/test-validate.ps1` exit0,64.39s; actual package guards rejected their controlled missing/invalid inputs and recovered on exact restoration. Disposable package copy removed. No semantic-prompt proof is inferred from the guard checks.
- Fresh distribution suite: `tests/test-install-user.ps1` exit0,178.32s. Only disposable fake homes were installed/updated; dynamic payload assertions compared every managed source asset with installed bytes, and WhatIf/preservation/conflict paths passed. Observed kitVersion1.0.4 and package digest `ca616adb585b5c443d1fa44d97d4a41dcbe07b91b1f81b008a2ab991f3bca322`. The entire exact fixture was removed. This does not mean the real user Codex was updated or loaded the new instructions.
- Retained final suite output is in ignored `_work/doc-consolidation/test-documentation.log`, `test-validate.log` and `test-install-user.log`; source/fixture data and identity are not public machine-path disclosures. No accessible prior suite result was relabeled reused; all three suites above executed fresh against their frozen consumed inputs.
- Observed runtime PowerShell7.6.5. Final SHA256 identities: `tests/test-documentation.ps1` = `32DE3366BD348D4AAA4737769EDDFEE00305CD9EC2E6EE8991578CA2282A6E2F`; documentation helper = `E003B4B3B2585A5B921ED469550FEABF56E9CBD456163C1BABF0C1DA7CD3A0F8`; governance reference = `7FC85189BEA81C74FDE94F55202A991EEADDE4F0538AF7F24437A7B881253A21`; doc-check Skill = `6BB78C9D347005A52CED068817BD1E171B49B6881C3E0C1AA4C7180FA1D22850`; Docs profile = `6211BEFFA10AC8C9FCA18C589665FACDE93768DAFF5CA5DA12A2BCC6C8BFE2BB`. Package digest covers distributed assets, not unrelated tests/public prose; individual hashes are not a fabricated complete environment manifest.
- Lead separately reported package validation exit0; Docs owner reported public-pair structural validator/bilingual tests passing and full semantic pair review. Skill-creator optional Python quick-validator could not run because bundled Python lacks PyYAML; no dependency was installed and that unavailable check is not a pass. Existing package/distribution checks provide separate evidence, not proof of every quick-validator assertion.
- Native human scenarios and actual installation/loading remain pending without an accepted automation exception. Keep this one packet active; do not archive or manufacture human acceptance. No commit/push/real installation occurred. Final readiness publication and independent closure review are Lead-owned after this packet freezes.
- Independent Reviewer closure completed with no material findings after inspecting the frozen source/test identities, three retained suite results, six controlled responses and invocation evidence. The Lead subsequently reconciled completion statuses below; this factual bookkeeping does not change test coverage or human acceptance. Final readiness publication remains a separate Lead operation.

### Actual child invocation roster
| Handle | Actual selected role | This task scope | Final known state |
| --- | --- | --- | --- |
| `/root/doc_consolidation_writer` | `team-docs-maintainer` | Shared documentation behavior, Skill/profile routing and paired release docs | Completed and frozen; final scoped readiness input returned |
| `/root/doc_consolidation_runtime` | `team-backend-engineer` | Policy3/release1.0.4 helper provenance constants | Completed and frozen |
| `/root/doc_consolidation_tests` | `team-tester` | Pre-GO packet, focused regressions and verification | Completed; tests and packet frozen |
| `/root/formatter_docs` | `team-docs-maintainer` (existing exact role reused) | Independent fresh-source controlled decision evaluation | Completed |
| `/root/readability_review` | `team-reviewer` (existing exact role reused) | Independent full scoped diff review and closure check | Completed; no material findings |

The Lead supplied actual spawn selectors/returned handles for the three new children and the original selectors for both reused children; no failed spawn, generic fallback or replacement was reported. Host-resolved role/model/effort metadata is unknown; selected roles and source/tool expected profiles are not proof of loaded runtime model identity. No Tester child was spawned.
