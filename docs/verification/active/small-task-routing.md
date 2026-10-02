# Verification: Small-task team routing

Packet schema version: 2
Stage slug: small-task-routing
Contract status: implemented; package regressions passed; real-workflow acceptance pending
Final manual status: manual pending
Final manual evidence:

## Stage context

Objective: explicitly activated team-dev small code tasks use a named domain implementer plus Tester by default, without dropping applicable engineering checks. Lead coordinates; reduced task size changes the roster and record length, not the applicable lifecycle.
Scope: bounded instruction, routing and evidence-template corrections. No new runtime spawn API, default-role fallback, automatic activation outside team-dev, production algorithm, refactor or real installation. Scoped readiness: docs/governance/reviews/small-task-routing.md. The existing uncommitted coverage-sync stage remains separate and intact.
Ownership: Lead owns integration/release/governance; small_task_writer owns assigned instructions; small_task_tester owns this packet and proportionate verification. Before instruction writing, this packet is created and structurally validated. No test-file change is planned because prose-matching tests cannot observe actual routing compliance.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| ST-01 | Explicit team-dev; small low-risk code task | Inspect startup classification, selectors, ownership and packet before writer starts | Named domain implementer and Tester participate; Lead coordinates; applicable checks retained | happy |
| ST-02 | Single-line permission/data/deployment change | Evaluate impact rather than file count | Add Reviewer and relevant specialist when risk requires; do not call task low-risk merely because it is short | edge |
| ST-03 | Markdown correction with or without workflow-behavior impact | Contrast pure spelling/formatting with behavior-changing harness instructions; classify actual scope | Pure typo-only Lead-only may be used; behavior-changing Markdown is not exempt; lifecycle evidence and relevant validation remain | alternate |
| ST-04 | User explicitly requests/approves code Lead-only | Record approval and transferred duties; contrast ordinary directly-fix request and material no-delegation conflict | Ordinary fix request is not Lead-only authority; applicable checks remain; material independent-review conflict requires explanation/question, not self-certification | alternate |
| ST-05 | Required named role unavailable | Inspect catalog and disclose missing role | Ask user before alternative; no silent default-role or Lead fallback | edge |
| ST-06 | Workflow not explicitly active | Inspect entrypoint and project instructions | Do not imply internal routing automatically activates for every request | edge |
| ST-07 | Close after small-task implementation | Compare planned roster, actual selectors/handles, checks and evidence | Explain unknown identities/deviations and uncovered checks; no false completion | happy |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No new algorithm; prose assertions do not establish compliance. |
| integration | required | Existing package and fake-home installation suites exercise distributed instruction/reference integrity. |
| contract/API | required | Existing validator checks Skill metadata, references and package contracts. |
| E2E | required | Every manual scenario has a planned real-agent observation; package lifecycle suite covers only distribution. |
| regression | required | Preserve coverage-sync stage schema and existing package/install behavior. |
| manual | required | User observes actual routing and retained checks in controlled tasks. |
| component/UI | not applicable | No UI implementation. |
| accessibility | not applicable | No rendered controls. |
| visual regression | not applicable | No visual artifact. |
| performance/load | not applicable | No runtime/load change; team overhead is a usability observation, not a throughput claim. |
| security | conditional | Role absence and authority boundaries assessed semantically; high-risk runtime routing is planned in a disposable task without real permission changes and remains pending. |
| compatibility | required | Existing schema2 packets and installed package lifecycle remain compatible. |
| data migration/rollback | not applicable | No schema or live deployment change. |
| resilience/recovery | conditional | Missing-role handling cannot silently downgrade; runtime observation remains pending. |
| exploratory/usability | required | Concise small-task startup/close evidence remains understandable and useful. |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Instruction routing and responsibility transfer | Small-task path bypasses checks or defaults to unsupported roles | E2E | manual-or-environmental | RoutingE2E.ST-01 through ST-07 | not applicable | planned | not needed; no code refactor | Actual agent actions require runtime observation; prose/regex checks cannot prove compliance | Lead / user | manual pending |
| Package/reference compatibility | Edited distributed instructions break validation or installation | integration | test-after | tests/test-validate.ps1, tests/test-documentation.ps1 and tests/test-install-user.ps1 | not applicable | All three suites exit0; isolated fixture removal confirmed | Final coherent instruction draft tested; no runtime refactor | Instruction-only change; reuse existing lifecycle suites rather than invent wording tests or Red | small_task_tester | passing |
| Stage schema/manual authority compatibility | Routing edits weaken existing packet lifecycle | regression | test-after | tests/test-stage-verification.ps1 | not applicable | Suite exit0; isolated fixture removal confirmed | Final coherent instruction draft tested; no parser/schema refactor | Existing behavior and coverage-sync regression reused unchanged | small_task_tester | passing |

## Automated test and E2E plan

Before implementation: this filled canonical packet passed stage-verification.ps1 -Action Validate with exit0 and finalManualStatus manual pending; Lead then released the writer. After coherent draft integration: scripts/validate.ps1, tests/test-validate.ps1, tests/test-stage-verification.ps1, tests/test-documentation.ps1 and tests/test-install-user.ps1 all exited0. Every regression suite reported isolated fixture removal. Documentation session69422 and install session17443 completed exit0; separate process fixtures did not overlap ownership. Install tests used only fake homes. No real home installation, external mutation, dependencies or archived manual acceptance were performed. Supplementary Python Skill helper was unavailable on PATH as reported by Lead; native package checks passed and do not certify semantic routing.

Independent Reviewer inspected the final amended instructions across routing, lifecycle and evidence templates and reported no material findings after six semantic walks. This is source review, not successful real-agent E2E execution or user acceptance. Real-workflow scenarios ST-01 through ST-07 remain planned/manual pending unless observable runs independently establish them. No strict test-first track or retrospective Red is claimed.

Final-source rerun: after the writer clarified preflight before any child and explicit authorized Lead-owned Tester checks, scripts/validate.ps1 and tests/test-validate.ps1 again exited0; isolated validation fixture removal was confirmed. Earlier stage/documentation/fake-home installation results remain valid for their unchanged runtime/template/schema/deployment paths; final wording introduced no new runtime algorithm. No semantic review before those clarifications is represented as review of later text; Lead reconciles the independent review handoff after final source inspection. Real-agent E2E scenarios remain pending.

### Manual-to-automated coverage mapping
| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| ST-01 | RoutingE2E.ST-01: small code request; inspect named selectors, implementer/Tester ownership, pre-writer packet and required checks | Package validator and isolated install verify distribution only | planned; real runtime pending | No automated semantic routing harness; no exception accepted |
| ST-02 | RoutingE2E.ST-02: one-line authorization scenario; inspect impact classification and risk roles | Semantic source review; package tests cannot prove role judgment | planned; real runtime pending | Use a disposable simulated permission task, not production access changes |
| ST-03 | RoutingE2E.ST-03: contrast typo-only Markdown with behavior-changing harness Markdown; inspect exemption rationale and retained verification | Existing package/packet lifecycle checks; semantic effect review | planned; real runtime pending | File extension is not proof of nonbehavioral scope; no exemption from applicable checks |
| ST-04 | RoutingE2E.ST-04: contrast ordinary directly-fix with approved Lead-only; inspect duties and self-check distinction; add material high-risk no-delegation conflict | Semantic responsibility/authority review; ordinary request is not exception authority | planned; real runtime pending | Exception needs explicit task approval; material independent-review conflict requires explanation/question, not self-certified review |
| ST-05 | RoutingE2E.ST-05: controlled unavailable-role surface; inspect pause/question and absence of silent fallback | Semantic review; role availability not safely injectable through this test suite | planned; real runtime pending | Controlled runtime required; do not disable real configuration solely for this test |
| ST-06 | RoutingE2E.ST-06: plain request outside explicit workflow; inspect activation claim | Entrypoint semantic review | planned; real runtime pending | Do not equate packaging with automatic workflow activation |
| ST-07 | RoutingE2E.ST-07: close ST-01 task; compare plan, selectors, handles, identity uncertainties and check evidence | Existing packet lifecycle/manual authority regressions | planned; real runtime pending | Roster alone does not prove engineering checks completed |

## Human verification script
### Preparation
1. Use a disposable repository and available named-role catalog; do not modify a real project, permissions or global configuration. Record revision, active workflow, catalog evidence, planned scope and cleanup. Retain only redacted evidence in its task packet.
### Happy path
1. ST-01: explicitly invoke team-dev for a tiny deterministic code correction. Inspect startup, assignments and acceptance packet before implementation.
   Expected result: domain implementer plus Tester selected by named-role arguments; Lead coordinates; applicable doc/test/TDD/comment checks are assigned and evidenced.
2. ST-07: inspect its final handoff and invocation ledger.
   Expected result: actual selectors/handles reconcile with plan; unknown resolved identity is honestly unknown; gaps are not presented as completed checks.
### Recommended edge cases
1. ST-02: propose a one-line simulated authorization correction in the disposable repository.
   Expected result: risk determines Reviewer/specialist needs, not line/file count.
2. ST-03: contrast a typo-only Markdown correction with a Markdown change that alters executable harness workflow behavior.
   Expected result: justified nonbehavioral Lead-only retains relevant checks; behavior-changing harness instructions are not exempt merely because they are Markdown.
3. ST-04: issue an ordinary directly-fix request under team-dev; separately approve Lead-only for a bounded low-risk task; finally contrast a high-risk task whose no-delegation demand conflicts with material independent review.
   Expected result: ordinary fix request retains default implementer plus Tester; approved exception transfers duties and distinguishes self-check; material review conflict is explained and returned to the user for decision, not represented as independent review or safe completion.
4. ST-05: only where a controlled runtime lacks a required named role, request the bounded code task.
   Expected result: Agent asks for an alternative; does not silently select default or implement as Lead. If that runtime is unavailable, record not run.
5. ST-06: issue a plain request without activating team-dev and inspect applicable project entry instructions.
   Expected result: no claim that internal routing alone automatically activates team-dev; project activation policy remains separate.
### Result
Observations: manual pending. After observations are recorded, remove only the verified disposable test repository/fixtures; do not delete user work or rewrite archived acceptance.

## Verification record

Initial packet: structural Validate passed exit0 before writer release. Test-file edits: none made; existing behavioral package/packet/install/documentation suites were adequate for distribution and compatibility, not real-agent behavior. Code-comment check: instruction-only scope has no new production/test code; existing test-case explanations remain unchanged. UI/Blueprint: no visible UI or material module-boundary change; current project baseline retained, no refactor. All planned automated regressions passed and their fixtures were removed. Real-agent behavioral evidence remains pending; source review is not successful E2E execution or user acceptance. Final packet Validate is rerun after this evidence update.

Invocation evidence supplied by Lead: /root/small_task_writer creation used agent_type team-docs-maintainer; /root/small_task_tester creation used agent_type team-tester; /root/small_task_reviewer creation used agent_type team-reviewer. These are the current-task returned handles; unrelated earlier agents are excluded. Expected source/catalog profiles are docs6Luna/high, tester6.1Sol/medium and reviewer6.1Sol/high. Returned handles identify assignments, not independently resolved role/model/effort metadata; resolved runtime identities remain unknown. Current status: writer draft/focused fixes complete; Tester regressions and packet complete; Reviewer completed final amended-source review with no material findings through six semantic walks. These source observations do not complete runtime E2E or user acceptance. This tester spawned no children.
