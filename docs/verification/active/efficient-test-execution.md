# Verification: Efficient test execution defaults

Packet schema version: 2
Stage slug: efficient-test-execution
Contract status: active
Final manual status: manual pending
Final manual evidence: No real target-project workflow or user acceptance observed.

## Stage context

Objective: Make programmatic repeatable execution and summary-first observation the Codex default for every product, without weakening coverage, UI evidence, safety or user acceptance.
Scope: shared testing contract, referencing Skills and generated packet planning fields; version 0.9.3. No production test seam, parser/schema change, forced API, actual installation or external operation.
Owners: Lead owns integration/version/governance; Docs writer owns shared instructions and generated-template string; Tester owns this packet and justified isolated regression; independent Reviewer owns final review.
Environment/test data/cleanup: existing PowerShell suites use unique temporary projects/fake homes and remove exact owned fixture roots at exit. No credentials, real home writes, external requests or business-project mutation. Retain this one canonical packet; no duplicate result authority.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| ET-01 | Non-AI order product with established API and persistence tests | Check inventory-rejection permutations via API; retain browser order submission, error and recovery | Default applies regardless of product AI; broad business-rule combinations need not repeat in browser, but full core journeys, frontend/backend linkage and distinct UI risks stay covered; only full real boundary counts API E2E | happy |
| ET-02 | Frontend-only product without API, or client/server duplicated validation | Choose existing component/browser runner and identify client-only risks | No forced API, universal API superset or production seam; lower-layer/server evidence cannot waive UI/component checks; no automatic test deletion for cost | alternate |
| ET-03 | UI interaction and visual hierarchy requirements | Use structural assertions plus actual rendered inspection | UI checkpoints remain; functional/screenshot-diff results do not replace visual inspection | edge |
| ET-04 | Passing and failing scripted runs | Read summaries then relevant failed evidence | Runner executes assertions and retains traceability; summary is not skipped evidence or fabricated pass | happy |
| ET-05 | Test could send payment, email or destructive external writes | Check authority and isolated substitute | Stop unsafe unapproved operation; show blocked gap rather than weaken expected result | edge |
| ET-06 | Token telemetry absent or simulator costs separately available | Report available evidence and missing measurements | Unknown stays unknown; no unsupported saving claim or mixed product/testing cost | edge |
| ET-07 | Existing schema2 packet and newly initialized packet | Validate both, fill execution choices, validate again | New table fillable; old packet accepted; authored bytes and pending acceptance preserved | happy |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No new algorithm; wording matching cannot establish agent behavior. |
| integration | required | Isolated package, documentation and installation checks exercise reference distribution. |
| contract/API | required | Initialize output planning fields and compatible packet validation are observable contracts. |
| E2E | required | Real Codex workflow observations map every manual case; pending in this source task. |
| regression | required | Preserve legacy packet nonmutation and manual-only archival authority. |
| manual | required | User accepts actual workflow behavior, separately from source checks. |
| component/UI | not applicable | No product UI code changes; ET-03 is a future workflow fixture. |
| accessibility | not applicable | No rendered controls changed. |
| visual regression | not applicable | No visual output changed; rendered-check obligations inspected semantically. |
| performance/load | conditional | Matched token/cost experiment needs available telemetry and target-project runs. |
| security | required | Review authority/side-effect and sensitive evidence constraints; no live external operations. |
| compatibility | required | Existing schema2 records remain valid without the optional planning subsection. |
| data migration/rollback | not applicable | No installation, storage migration or deployment requested. |
| resilience/recovery | conditional | Failed checks retain drill-down evidence and truthful gaps; real workflow pending. |
| exploratory/usability | required | Assess practical default/exception clarity without imposing API on frontend-only work. |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Generated execution-planning fields | Missing observable planning entrypoint | contract/API | test-first | tests/test-stage-verification.ps1: initialized six-field execution table and fillable row | pwsh -NoProfile -File tests/test-stage-verification.ps1 exit1 before writer release: Initialize did not emit a fillable execution and observation table; fixture removed | Same command exit0 after coherent draft; six ordered fields and fillable row verified | No production refactor; completed-draft run covers template and unchanged parser together | not applicable | Tester | passing |
| Compatible authored choices and manual authority | New metadata mutates old records or implies acceptance | regression | test-after | tests/test-stage-verification.ps1: legacy/new packet nonmutation and pending archive rejection | not applicable | Suite exit0; legacy and filled subsection validation nonmutating; pending archive rejected | Coherent draft tested; no parser/schema refactor | Unchanged parser behavior; new authored subsection only available after template implementation; existing compatibility cases reused, no independent Red claimed | Tester | passing |
| Universal efficient execution and retained coverage/safety | Wrong product-AI scope, shortcuts or unsafe actions | E2E | manual-or-environmental | EfficientExecutionE2E.ET-01 through ET-06 | not applicable | planned | not needed; no production refactor | Real workflow requires disposable target fixtures; semantic source review is substitute, not executed E2E | Lead / user | manual pending |
| Distributed reference/installation integrity | Broken links or managed package regression | integration | test-after | scripts/validate.ps1; tests/test-validate.ps1; tests/test-documentation.ps1; tests/test-install-user.ps1; tests/test-deployment.ps1 | not applicable | All commands exit0; disposable fixture cleanup confirmed | Coherent versioned draft tested; no runtime refactor | Reuse existing behavioral suites after complete draft; no retrospective Red for unchanged runtime | Tester | passing |

## Automated test and E2E plan

Before writer release: run the focused new Initialize regression for actual Red and validate this plan. After Lead releases final coherent draft: run scripts/validate.ps1, tests/test-stage-verification.ps1, tests/test-validate.ps1, tests/test-documentation.ps1 and tests/test-install-user.ps1. Native validation and isolated regressions do not prove Agent adherence or measured token savings. Interpret ET-01 through ET-06 against actual final diff; do not add normative prose-match tests.

### Execution and observation choices
| Case / test ID | Execution entrypoint and real boundary | Runner / command | Observation mode and rationale | Retained browser / visual checkpoints | Evidence / drill-down / gaps |
| --- | --- | --- | --- | --- | --- |
| ET-07 | Real Initialize/Validate/Archive scripts in unique temporary projects | pwsh -NoProfile -File tests/test-stage-verification.ps1 | exit/result summary then focused failing assertion | not applicable; packet generator has no UI | Actual Red/Green below; exact owned cleanup reported |
| ET-01 through ET-06 | Future disposable target product and actual Codex workflow | environment-dependent; do not invent executed command | source walkthrough now; runtime evidence pending | ET-02/ET-03 retain UI behavior and rendered inspection | No product fixture, measured token savings or workflow pass claimed |

### Manual-to-automated coverage mapping
| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| ET-01 | EfficientExecutionE2E.ET-01: non-AI order inventory permutations at complete real API boundary plus browser submit, rejection message and recovery; inspect equivalent conditions/assertions/risk evidence, not counts | Unit/integration business assertions supplementary, not full-boundary substitutes | planned; runtime pending | No universal API superset or exception accepted |
| ET-02 | EfficientExecutionE2E.ET-02: no-API frontend retains existing browser path without added seam | Semantic contract review | planned; runtime pending | No exception accepted |
| ET-03 | EfficientExecutionE2E.ET-03: deterministic UI assertions plus rendered visual evidence | UI contract source review | planned; runtime pending | User-only visual acceptance remains pending |
| ET-04 | EfficientExecutionE2E.ET-04: successful/failing summaries reference executed assertions and drill-down evidence | Generator checks evidence planning fields only | planned; runtime pending | Metadata is not assertion execution |
| ET-05 | EfficientExecutionE2E.ET-05: unapproved external effects remain blocked and reported | Safety boundary source review | planned; runtime pending | No real external action authorized |
| ET-06 | EfficientExecutionE2E.ET-06: missing telemetry reported unknown; distinct cost accounts retained | Source review; no token measurement available | planned; runtime pending | No saving estimate or pass invented |
| ET-07 | EfficientExecutionE2E.ET-07: operator initializes and authors packet, legacy form validates, pending archive blocked | tests/test-stage-verification.ps1 exercises script lifecycle in isolation | Real-workflow E2E planned; isolated script lifecycle passed exit0 | Actual Codex authoring and human acceptance unobserved |

## Human verification script
### Preparation
1. Use disposable non-AI CRUD and frontend-only fixtures; record source revision and instructions. Supply only authorized local test data. Do not use production credentials or real external transactions.
### Happy path
1. ET-01: request non-AI order testing with multiple backend inventory-rejection conditions.
   Expected result: broad business combinations tested programmatically; browser retains complete core order journey, frontend/backend linkage, rejection display and recovery without repeating every backend permutation. Map exact conditions/assertions and evidence, not test counts; lower-layer checks are not API E2E.
2. ET-04: run a controlled passing scenario and injected failure.
   Expected result: all assertions execute; Agent reads summary first and expands relevant failure evidence, without claiming unchecked results.
3. ET-07: initialize/fill a new packet, validate an old schema2 packet, attempt archive with manual pending.
   Expected result: six planning fields are fillable, bytes preserved, old form accepted, archive rejected.
### Recommended edge cases
1. ET-02: provide frontend-only project with no API, then a case with duplicated client/server rules.
   Expected result: existing component/browser entrypoint chosen; no production seam or universal API-superset assumption; client behavior and distinct UI risks retained. Existing tests are not automatically deleted to save tokens.
2. ET-03: include a layout/visual requirement and an interaction requirement.
   Expected result: appropriate assertions plus actual rendered inspection; no screenshot-every-step mandate or omitted UI path.
3. ET-05: propose a test that would send real payment/email.
   Expected result: require authority or safe isolation, preserve gap; no real external action.
4. ET-06: omit token telemetry or expose only one cost account.
   Expected result: unknown measurements explicit; testing Agent, auxiliary simulator/grader and product costs not conflated.
### Result
Observations: manual pending. Remove only verified owned disposable fixtures; preserve the canonical evidence and user originals.

## Verification record

Planning established before writer release. Tester handle /root/efficient_test_tester; planned/tool-selected role team-tester per Lead assignment; loaded inference identity/model/effort not independently confirmed. No children spawned. Source walkthrough, actual regression outcomes, changed-file/comment check and Lead-provided complete invocation ledger will be reconciled after coherent draft. No commit, push, installation, real-home mutation or business-project change by Tester.

Observed verification after Lead's coherent-draft release: native scripts/validate.ps1 plus isolated tests/test-stage-verification.ps1, tests/test-validate.ps1, tests/test-documentation.ps1, tests/test-install-user.ps1 and tests/test-deployment.ps1 all exited0. Stage suite supplied actual Green after observed pre-implementation Red. Documentation session63294, installation9498 and deployment64443 completed successfully. Suites reported owned fixture cleanup; exact installation/deployment roots independently checked absent. Installation suite used fake homes only and checked 0.9.3 distribution, not real local installation. Nonfatal Git ignore-permission/line-ending warnings do not indicate a failed test; no personal Git configuration was changed. git diff --check on owned test source passed.

Independent Tester semantic source walkthrough: ET-01 is supported by universal Codex workflow applicability, broad integrated business permutations and equivalent per-case dedup evidence while preserving core browser journeys/linkage. ET-02 explicitly retains frontend-only or duplicated client assertions without requiring new API/seams, forbids unauthorized test removal and does not assert an API superset. ET-03 requires rendered inspection where structured observations cannot judge visual states, while avoiding per-step screenshot mandate. ET-04 retains trusted complete artifacts, truthful planned/skipped/timeout/failed/executed/pass distinctions and material-risk drill-down; summaries do not waive assertions. ET-05 relies on existing test-authority/manual exception and TDD side-effect safety rules plus explicit safety-sensitive evidence inspection; no real external action was run. ET-06 separates testing Agent/product/auxiliary usage, marks unknown telemetry and forbids unmeasured saving claims. ET-07 is supported by actual generated-table/nonmutation/manual-authority regressions. These source interpretations and script checks are not actual Codex workflow E2E; all real-workflow mappings and final manual status remain pending. No measured cost reduction is claimed.

Comment self-check: inspected tests/test-stage-verification.ps1's actual new diff and nearby module overview. Both independent new cases have scenario and expected-result comments; table schema/fillable-row, byte hashes and archive rejection assertions support their stated outcomes. No new helper/public interface or production logic; existing helpers untouched. No normative prose-match tests added. Parser/schema unchanged and no production refactor, so no separate post-refactor run needed beyond completed-draft regression.

Lead-reported optional Skill helper limitation: skill-creator's Python quick_validate could not start validation because yaml was unavailable. No dependency installed, no Skill failure inferred and no helper pass claimed; native package validation is the available substitute for unchanged frontmatter/naming/routes. Lead owns final readiness and independent Reviewer closure.

Lead close reconciliation: the scoped readiness and initial Tester plan were read and validated before writer release; actual missing-table Red was recorded before the Initialize template changed. Docs Maintainer completed the shared contract and short routes; Tester verified actual Green, all five isolated suites, cleanup and semantic source cases; independent Reviewer found no material implementation issues and independently passed native/packet validation and whitespace checks. Lead read the actual source/test diff and final packet, corrected the stale ET-07 isolated-result label without changing runtime/manual acceptance, and synchronizes VERSION, README, CHANGELOG and the documentation runtime's Kit provenance to 0.9.3. This is a patch extension of existing testing support, not stable promotion. Final governance is refreshed from this inspection, not hashes alone. No parser/schema/policyVersion, architecture, model profile, product API or installed payload change; no commit or push.

Actual invocation ledger: /root/efficient_test_tester selected with agent_type team-tester, owned initial plan/packet/tests and post-verification, complete; /root/efficient_test_writer selected with agent_type team-docs-maintainer, owned the shared rule, five Skill routes, execution fields and Initialize template literal, complete; /root/efficient_test_reviewer selected with agent_type team-reviewer, owned independent read-only review, complete. All three exact roles were available in the active tool catalog before invocation. Source and active catalog expectations matched the named profiles, but returned handles establish creation, not independently confirmed loaded role/model/effort; runtime identities remain unknown. No failed creation attempts, replacements, retries, generic-role substitution or further child spawning occurred. Unrelated older agents are excluded.

Document-purpose reconciliation: the shared Test & Acceptance Contract is the rule authority; Skill entrypoints route to that same section; execution/Initialize templates expose planning and observed-result fields; README retains a short stable summary/navigation; CHANGELOG records release changes; this packet owns test results and pending human verification; governance owns reviewed task-input sufficiency. No duplicate test report, broad cleanup or historical acceptance rewrite was introduced. Lead code-comment self-check: documentation.ps1 changes only its explicit Kit provenance constant under its existing lifecycle overview; stage-verification.ps1 changes only literal authoring guidance/table under its existing module overview. The Tester verified nearby scenario/expected-result comments for every new independent test and assertions support their promises. No new function/interface, runtime algorithm or structural refactor requires additional commentary.
