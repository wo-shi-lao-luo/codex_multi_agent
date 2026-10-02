# Verification: Adaptive child-agent concurrency

Packet schema version: 2
Stage slug: adaptive-concurrency
Contract status: active
Final manual status: manual pending
Final manual evidence: Real Codex six-child capacity and user workflow acceptance unobserved.

## Stage context

Objective: Recommend a ceiling of six child agents excluding Lead, while normally selecting two to three and expanding only for independent ready work.
Scope: Recommended config, canonical role-routing policy, workflow summaries and paired public documentation. No installation, global settings change, commit, push, model change or scheduler.
Owners: Lead readiness/integration; team-docs-maintainer instruction and public-doc writer; team-backend-engineer config writer; team-tester this packet and tests; team-reviewer independent semantic review.
Structural alignment: Existing config/Skills/docs boundaries adequate; no Blueprint amendment, new architecture authority or refactor required.
Test data/environment/cleanup: PowerShell 7; generated narrow configuration fixtures in one unique system-temp directory, verified exact parent/name before deletion; source inspected read-only. No credentials or real user-home writes. Runtime tests require an explicitly authorized isolated Codex session.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| AC-01 | Recommended fragment present | Read actual agents table | Ceiling6; Lead excluded by documented semantics, not counted by this test | happy |
| AC-02 | Small bounded task | Assign required roles in sequence | Typically2–3 when useful, not a forced minimum or bypass of Tester/review | happy |
| AC-03 | Medium/large independent work | Explain outputs, ready dependencies and ownership before more than3 children | Medium3–4 or large4–6 allowed within actual capacity; one production writer remains default | alternate |
| AC-04 | Host limit lower or spawn rejected | Inspect actual capacity and preserve available work | Respect host limit, stage dependent tasks; no generic fallback or forced6 | edge |
| AC-05 | Dependent work or conflicting writers | Evaluate readiness and shared files | Sequence blocked work and preserve ownership; numeric ceiling not permission to conflict | edge |
| AC-06 | Public README/config updated | Inspect paired languages and packaging | Both explain optional manual merge and distinguish ceiling from actual loaded capacity | happy |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | required | Narrow plain-section/integer reader guards false numeric evidence. |
| integration | required | Actual recommended fragment and docs/package validators assessed. |
| contract/API | required | Numeric recommendation plus semantic ownership/capacity contract review. |
| E2E | required | Real Codex scenarios for every manual case remain planned pending environment. |
| regression | required | Detect retained old3 and protect bilingual/package/install conventions. |
| manual | required | User verifies adaptive delegation and live capacity, not static token counts. |
| component/UI | not applicable | No application UI change. |
| accessibility | not applicable | No controls or accessibility behavior changed. |
| visual regression | not applicable | No rendered interface changed. |
| performance/load | conditional | No measured speed/token claim; future telemetry needed for comparisons. |
| security | required | No global writes; narrow read-only source check and exact temp cleanup. |
| compatibility | required | Native package and fake-home installation checks remain applicable. |
| data migration/rollback | not applicable | No installed-state migration or deployment. |
| resilience/recovery | required | Lower/rejected host capacity handled in semantic/runtime plan. |
| exploratory/usability | required | Independent policy walkthrough evaluates practical task sizing. |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Recommended agents ceiling 6 | Old cap persists or decoy parsed | integration | test-first | tests/test-agent-concurrency.ps1 AC-01 | Pre-writer pwsh -NoProfile -File tests/test-agent-concurrency.ps1 failed: Recommended agents ceiling must be6; observed3; owned fixture removed | After config owner update, same focused command exit 0: actual source 6, reader edge cases passed, hash unchanged and owned fixture removed | Focused rerun exit 0; no production refactor, only explanatory comment/error spacing | not applicable | Tester | passing |
| Adaptive independence/capacity/ownership rules | Overparallelization or bypassed roles | E2E | manual-or-environmental | AC-02 through AC-05 | not applicable | Independent semantic review complete, no material findings; runtime checks pending | no refactor expected | Instructions are not runtime-enforced; current session cannot prove six concurrent children; static string assertions cannot prove compliance | Reviewer / user | manual pending |
| Public-language and package compatibility | Conflicting setup or broken discovery | regression | test-after | AC-06 existing bilingual/native/fake-home suites | not applicable | Final coherent source: docs/native validators, bilingual suite, isolated test-validate and fake-home test-install-user exit 0 | Final coherent-source reruns exit 0; no production refactor | Existing suites already cover observable document/package contracts; wording reviewed semantically after edit rather than fabricated pre-edit Red | Tester | passing |

## Automated test and E2E plan

Entrypoints: tests/test-agent-concurrency.ps1; scripts/validate.ps1; scripts/validate-docs.ps1 -ProjectRoot .; tests/test-bilingual-docs.ps1; tests/test-validate.ps1; tests/test-install-user.ps1; skills/team-core/scripts/stage-verification.ps1 -Action Validate -ProjectRoot . -StageSlug adaptive-concurrency. All fixture suites use isolated owned roots, not real installation.

### Execution and observation choices
| Case / test ID | Execution entrypoint and real boundary | Runner / command | Observation mode and rationale | Retained browser / visual checkpoints | Evidence / drill-down / gaps |
| --- | --- | --- | --- | --- | --- |
| AC-01 | Source plain configuration fragment read-only | tests/test-agent-concurrency.ps1 | Summary and named failure; numeric value and hash asserted | None; no UI | Narrow reader is not full TOML parser or resolved Codex config |
| AC-02 through AC-05 | Real Codex task delegation, dependencies and ownership | Controlled workflow walkthrough in authorized session | Inspect selector/handle evidence and work contract; no repeated screenshot cost | None; native agent actions | Runtime pending; source semantic review is substitute not E2E pass |
| AC-06 | Actual public pairs and disposable package/fake home | Existing bilingual/native/install suites | Summary-first and full failure output when needed | Source-language parity reviewed; no UI | Doesn't prove global config merge or loaded runtime capacity |

### Manual-to-automated coverage mapping
| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| AC-01 | Runtime.AC-01 isolated session manual merge and observed ceiling semantics | Focused source numeric test | planned | Real loading and six-child support unobserved; no automation exception accepted |
| AC-02 | Runtime.AC-02 small task with named writer, Tester preparation and independent review in sequence | Independent source semantic walkthrough | manual pending | Future Agent compliance unobserved |
| AC-03 | Runtime.AC-03 more than3 independent ready outputs with explicit ownership and justification | Semantic review of canonical policy | manual pending | This host cannot establish six slots; no automatic passing coverage |
| AC-04 | Runtime.AC-04 reduced-capacity/rejected spawn, no unsupported fallback | Current real rejection observed but full response flow pending | manual pending | Capacity unknown; source-config value does not override host |
| AC-05 | Runtime.AC-05 unresolved input and shared-file writers are sequenced | Semantic conflict walkthrough | manual pending | No unsafe runtime conflict injection; no exception accepted |
| AC-06 | Runtime.AC-06 setup documentation points to optional manual merge; source review plus package install into fake home | Existing doc/package suites | Automated compatibility checks passing; runtime/user acceptance pending | User setup acceptance remains pending; real installation not authorized |

## Human verification script
### Preparation
1. Use a disposable project and separate explicitly authorized Codex configuration/home; do not alter personal global config. Record source revision and actual host limitations. Cleanup only exact owned fixtures.
### Happy path
1. AC-01 and AC-06: inspect fragment and both READMEs, optionally merge in isolated configuration. Expected:6 excludes Lead; installer does not silently merge; languages match and loaded capacity is verified separately.
2. AC-02: run a small bounded change. Expected: only useful roles active, Tester plans before writer and Reviewer after coherent pass;2–3 is guidance, not required simultaneous count.
3. AC-03: request independent ready read-heavy outputs in a host that supports more than3 children. Expected: Lead gives readiness/output/ownership reasoning before expansion; no forced6 or multiple production writers by default.
### Recommended edge cases
1. AC-04: use a lower-capacity host or observe a rejected spawn. Expected: respects observed capacity and named-role rules, stages remaining work, no silent generic substitution.
2. AC-05: provide tasks with unresolved shared inputs or overlapping file writes. Expected: dependent tasks wait and shared ownership is assigned, despite ceiling6.
3. AC-06: inspect bilingual setup warnings and test fake-home installation. Expected: optional fragment not a claim of loaded configuration, no actual home residue.
### Result
Observations: manual pending. Preserve this active canonical packet until user verifies or explicitly defers.

## Verification record

Planning before production: numeric test-first covers actual source fragment; semantic compliance stays manual/environmental. Narrow reader self-cases guard decoy keys and missing/duplicate/unsupported values; this is not a scheduler or TOML validator. Every independent scenario has purpose and expected-result comments, backed by observable assertions. No runtime6 or token improvement claimed.

Invocation evidence so far: /root/concurrency_tester selected team-tester, packet/test owner; /root/concurrency_docs selected team-docs-maintainer, instruction/public-doc owner. A team-backend-engineer spawn attempt for concurrency_config was rejected with agent thread limit reached and returned no ID; it is not a created agent. Same named-role retry later created /root/concurrency_config with selector team-backend-engineer after another planning turn ended; no alternative or relabeling. Catalog advertises four slots including Lead, but rejection prevents inferring actual available capacity. Returned handles do not independently confirm model/effort or loaded identity; unknown. No child recursion.

Actual pre-implementation Red: tests/test-agent-concurrency.ps1 reached its actual-source ceiling assertion after fixture parser cases passed, observed3 rather than6 and failed. Source hash equality checked before this failure; finally verified owned root absent and printed cleanup confirmation. Schema2 stage packet validation passed with final manual status pending before writers. Config change and final Green remain pending Lead GO.

Focused Green after Lead GO and backend config completion: tests/test-agent-concurrency.ps1 exit 0. The reader observed the actual agents ceiling 6, accepted section-separated decoys/commented integer, preserved old-value observation, rejected six missing/duplicate/unsupported fragments, and verified source hash unchanged. Exact owned temp root absence was asserted in finally. Test comments and the numeric assertion were inspected together: overview and helper contracts explain limitations, each scenario states its purpose and observable expectation, parameterized rows identify individual outcomes; no exemption or comment gap found. Spacing-only comment/error improvements do not change assertions. Full bilingual/package/fake-home checks still await coherent Docs Maintainer completion; runtime six-child compliance and user acceptance remain pending.

Lead comment/assertion reconciliation found missing-table rejection was described but not independently exercised. Tester added a seventh named fixture, an unrelated table containing ceiling 6 with no agents table, and reran the focused suite exit 0 with cleanup. This closes the explanation gap without changing production or fabricating an additional pre-implementation Red.

Final coherent-source independent Tester checks: tests/test-agent-concurrency.ps1 exit 0 with owned fixture removed; scripts/validate-docs.ps1 -ProjectRoot . exit 0; tests/test-bilingual-docs.ps1 exit 0 with all targeted drift cases rejected and isolated fixture removed; scripts/validate.ps1 exit 0; tests/test-validate.ps1 session 1714 exit 0 with isolated validation root removed; tests/test-install-user.ps1 session 7613 exit 0 with isolated install root removed. Exact fake-home root absence independently confirmed after completion. Installer test was inspected: every install/update call supplies temporary CodexHome and AgentsHome, verifies packaged hashes/receipt and managed update, preserves conflicts/backups and asserts WhatIf nonmutation. No real installation or global configuration change performed. Existing Git-ignore permission warnings were nonfatal; no personal Git configuration was changed.

Final test-comment self-check: tests/test-agent-concurrency.ps1 file overview and helper contracts document scope, supported fragment and fail behavior; every independent test block explains scenario and expected result, including each of seven named rejection fixtures. Numeric assertion, source hash and exact cleanup match explanations. The one-line recommended-config change is trivial declarative data: surrounding guidance already explains manual merge and model boundaries, so no added per-constant documentation template is needed. No production scripts or untouched historical test helpers rewritten. Runtime six-child execution and adaptive Agent compliance cannot be inferred from these checks; all manual cases remain pending.

Final actual task roster reconciled by Lead after Tester handoff: /root/concurrency_tester selected team-tester, packet/test owner and independent isolated verification, complete; /root/concurrency_docs selected team-docs-maintainer, canonical policy/workflow summaries and paired public docs, complete; /root/concurrency_config selected team-backend-engineer, bounded recommended-config writer, complete; /root/concurrency_reviewer selected team-reviewer, independent read-only semantic review, complete. Original concurrency_config team-backend-engineer spawn attempt failed with agent thread limit reached and no returned ID; later same named-role retry succeeded, not a generic fallback. No child recursion. Selectors establish requested profiles, not independently loaded identities/models/effort; all unreported identity metadata remain unknown. No runtime or user pass claimed.

Lead close reconciliation: named owners, pre-writer packet/readiness and actual Red, independent Tester Green/regression checks and independent Reviewer review all match the bounded contract. Reviewer found no material defects after small, medium/large independent, low/unknown capacity, bounded same-role retry, missing-role, dependent-input/shared-file/fixture and review-only walkthroughs. Reviewer independently reran focused configuration, source bilingual and native checks successfully; these are source/fixture observations, not runtime E2E. English/Chinese changed setup and operating passages and the new release item convey equivalent facts; historical English releases are unchanged. The optional first-time manual-merge clarification was not required because the linked fragment already supplies instructions. Source model settings are unchanged, and no installation, global setting, Git commit or push occurred. Lead inspected the final file placement, comments/assertions, source diff and evidence, then refreshed only this task's documentation readiness. Other scoped assessments may be stale and are not re-certified. Real six-child execution, future Agent compliance and user acceptance remain manual pending; retain this active packet.
