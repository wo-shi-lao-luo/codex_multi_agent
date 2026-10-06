# Verification: Task-scoped design exploration

Packet schema version: 2
Stage slug: design-exploration
Contract status: ready
Final manual status: manual pending
Final manual evidence:


## Stage context
- Objective: integrate proportional design exploration into existing team-plan/team-dev, not a new planner/runtime or global automatic activation. Implemented source version is 1.0.1 against baseline b671330 (1.0.0); the maintenance update does not authorize installation, commit or stable promotion.
- Scope, environment, test data, and cleanup: synthetic requirements/accepted decisions and existing Work/Blueprint/OpenSpec examples; PowerShell 7, disposable package copies/fake homes, no real user data/API/network. Guarded finally cleanup checks exact owned temporary locations. No new roles, model assignments, runtime schemas or application production changes; assigned developer_instructions/profile contents and package guards do change. Simulation actors excluded.
- Start declaration/ownership: Lead owns global goal, applicable PRD/accepted decisions, scope/evidence, readiness and user decisions; Docs writer owns assigned instruction/reference/public changes; Backend owns package link/resource guards and kitVersion literals only; Tester owns this packet/tests; independent Reviewer follows coherent writer pass. sourceProfiles model/effort values describe configured expectations only, not host-confirmed inference identity; resolved model/effort unknown. No extra Architect/Explorer invocation required merely to implement this bounded rule.
- Coverage principle: installed resource bytes/mandatory links are deterministic package evidence; semantic routing/approval/readiness decisions require review and real native sessions. Do not use regex to claim architectural quality or Agent adherence.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| DE-01 | source package | omit reference, unlink required routes, restore; install fake home | reject structural omissions, restore clean validation and installed bytes | happy / edge |
| DE-02 | clear bounded change with approved decisions | enter team-plan/dev | lightweight depth with no redundant approval or forced options quota | happy |
| DE-03 | material uncertain interface/AI/scope | assess depth; brief scoped children | full exploration using global goal/PRD/accepted decisions/evidence and applicable reference | happy |
| DE-04 | child assignments | Explorer facts; architects readonly proposals; scoped developer/Tester light checks | meaningful alternatives/evidence within ownership, no production implementation or simulation actors | edge |
| DE-05 | ambiguous substantive choice or already approved detail | compare alternatives and decision authority | ask user on material ambiguity; preserve accepted details without redundant gate; no auto commit | edge |
| DE-06 | exploration reached readiness; later material change | close, then reopen changed scope | existing Work/Blueprint/OpenSpec remains authoritative; reopen only affected boundary, no competing system | edge |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | instruction-only decisions lack executable pure rule boundary |
| integration | required | mandatory reference/routes and fake-home propagation |
| contract/API | not applicable | no new JSON/API/runtime interface |
| E2E | required | native plan/dev depth and authority workflow remains pending |
| regression | required | existing package/installation compatibility and approved-detail fast path |
| manual | required | contextual decisions and user-only authority |
| component/UI | not applicable | no visible UI |
| accessibility | not applicable | no UI |
| visual regression | not applicable | no rendering |
| performance/load | conditional | proportional lightweight path checked qualitatively; no measured token savings |
| security | required | decision authority, readonly/scoped exploration and no unauthorized writes |
| compatibility | required | existing roles/records and installer payload |
| data migration/rollback | not applicable | no new data schema or deployment manager behavior |
| resilience/recovery | required | readiness closes and material change reopens affected scope |
| exploratory/usability | required | meaningful options/depth decisions require native observations |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Shared reference and mandatory local-link packaging | missing installed instructions | integration | test-first | DE-01 test-design-exploration and test-validate -DesignExplorationOnly | Before writer GO: missing shared reference exit 1; copied real validator accepted missing reference, new guard test exit 1 | frozen1.0.1 source payload and full validator suites exit0, including all four unlinked-prose mutations | full validator suite passed | none | Tester | passing |
| Existing fake-home propagation | installed resource differs from source | compatibility | test-after | DE-01 test-install-user | not applicable | frozen1.0.1 isolated fake-home suite exit0; dynamic map verifies installed bytes against source | existing installation preservation/conflict regression passed | mature installer hash harness extended after initial resource Red, not a fabricated full-installer Red | Tester | passing |
| Patch release format and helper metadata remain aligned | old exact version assertion blocks normal patch upgrades | compatibility | test-after | tests/test-ai-simulation.ps1 | not applicable | frozen1.0.1 full helper suite exit0, manifest kitVersion equals VERSION | existing context/budget/integrity/raw-Git regression passed | authorized bounded removal of obsolete release equality; preserve supported version format, role defaults and manifest-versus-VERSION integration; no retrospective Red claimed | Tester | passing |
| Depth, global brief and bounded role work | shallow isolated child decisions or forced exhaustive exploration | E2E | manual-or-environmental | Native.DE-02 through Native.DE-04 | not applicable | native session pending | no code refactor | contextual Agent decisions not enforced by the package validator; semantic review is substitute evidence only | Reviewer / user | manual pending |
| User authority and readiness/reopening | unapproved implementation or repeated gates/competing records | security | manual-or-environmental | Native.DE-05 Native.DE-06 | not applicable | native session pending | no code refactor | user decisions/staleness depend on real task context; no invented regex certification | Reviewer / user | manual pending |

Assess unit, integration, contract/API, E2E, regression, manual, component/UI, accessibility, visual regression, performance/load, security, compatibility, data migration/rollback, resilience/recovery, and exploratory/usability.

## Automated test and E2E plan
- Commands, fixtures, environment, cleanup, and TDD exceptions: after full source freeze run tests/test-design-exploration.ps1, tests/test-validate.ps1, tests/test-install-user.ps1 and tests/test-ai-simulation.ps1 using independent disposable fixtures. The simulator suite is rerun for kitVersion literal/version-format integration only, not proof of design exploration; remove its obsolete exact1.0.0 assertion while preserving supported release format and manifest equality. Main owns public/document/native stage validation; no actual install/commit. Estimate/cost unknown; no explicit new user budget. Broaden only if changed boundary justifies it; prior simulator results do not establish this workflow.
- Choose the lowest-observation-cost adequate entrypoint, runner, and observation mode per case. Retain full trusted result artifacts, inspect summaries first, and drill down for failures, ambiguity, unexpected behavior, or material/safety-sensitive risk.
- API/integration scenarios generally cover broader business permutations at a declared real application boundary; browser checks retain representative complete journeys and distinct UI/client/front-end-back-end risks. Record evidence and rationale for reduced duplicate browser permutations. Do not treat mocks, direct model calls, or narrow endpoint checks as a complete user journey.
- Include every manual scenario/requirement in the E2E plan with equivalent conditions, expected results and explicit checkpoints; list gaps without treating plans/exceptions as passing.
- On encountered user-added/changed manual cases, update E2E and applicable other-layer tests/assertions, reopen affected evidence and rerun; ask on ambiguity, expanded scope or automation exceptions. Preserve archived acceptance with a follow-up stage.

### Execution and observation choices
| Case / test ID | Execution entrypoint and real boundary | Runner / command | Observation mode and rationale | Retained browser / visual checkpoints | Evidence / drill-down / gaps |
| --- | --- | --- | --- | --- | --- |
| DE-01 | actual source/package validator/installer | new narrow payload test + existing validator and install suites | exact paths/links/bytes, no semantic phrase scoring | none | source presence and guard Red observed; frozen source, full validator and fake-home suites exit0 |
| DE-02 through DE-06 | full native Team plan/dev execution | authorized synthetic disposable session | inspect brief, selectors, options/evidence, user requests and readiness records | none | source semantic walkthrough first; native behavior unexecuted |

### Manual-to-automated coverage mapping
| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| DE-01 | Native.DE-01 load installed Team entrypoints and resolve shared reference | package omission/route/hash assertions | planned | installation test not native loading proof |
| DE-02 | Native.DE-02 approved small change, inspect lightweight path/no repeated gate | independent source review | manual pending | actual routing unobserved |
| DE-03 | Native.DE-03 uncertain API/AI/scope, inspect full global brief and explicit reference request | independent source review | manual pending | actual child context unobserved |
| DE-04 | Native.DE-04a uncertain checkout API: inspect factual Explorer, readonly architect, bounded developer/Tester proposals; no quota/no simulation actor. Native.DE-04b make the assigned reference/evidence inaccessible: child identifies the missing input, requests an accessible excerpt or clarification, and does not invent facts or claim inherited context | source role/ownership review | manual pending | source defaults do not prove invoked roles or unavailable-input handling |
| DE-05 | Native.DE-05a PRD leaves payment retry behavior unresolved: ask user before selecting semantics; already accepted button label needs no repeated gate. Native.DE-05b user declines a proposed module refactor: continue approved work as-is with documented constraints, no unauthorized restructuring or auto commit | authority walkthrough | manual pending | user acceptance/refactor refusal cannot be synthesized |
| DE-06 | Native.DE-06a reach readiness for approved checkout boundary, then change only payment API timeout: affected boundary reopens in existing records; unrelated accepted UI stays closed. Native.DE-06b after refactor refusal, carry the as-is constraint into reopened work rather than silently reviving the declined refactor | readiness/record walkthrough | manual pending | no background monitor or native execution observed |

## Human verification script
### Preparation
1. Use an authorized disposable project/session with synthetic PRD, global goal, accepted decisions, scope/evidence and existing Work/Blueprint/OpenSpec conventions. No external service or sensitive data. Record source revision and actual role selectors; leave unavailable runtime model identity unknown.
2. Native DE-01 prerequisites: separately approve installing/reloading the revised Team Skills in the disposable session. Actual native load is not exercised by fake-home hash checks; until that session exists retain the explicit manual-first gap and do not infer entrypoint activation from file presence.
### Happy path
1. DE-01: invoke installed team-plan/dev in that authorized session and inspect resolution/read of the shared design-exploration reference.
   Expected result: current entrypoint loads the actual packaged local reference and explicitly requests applicable child reads. Record actual load evidence/selector/brief; missing environment remains pending, not a simulated pass.
1. DE-02: request a clear approved small change through team-plan/dev.
   Expected result: lightweight assessment, preserved accepted details, ordinary required engineering flow without redundant user gate or artificial option count.
2. DE-03/DE-04: provide an uncertain API or AI workflow boundary; inspect child requests/responses.
   Expected result: global goal/PRD/decisions/scope/evidence and applicable shared reference explicitly supplied; scoped factual/proposal/light checks, meaningful options; no production implementation or simulation actor role.
### Recommended edge cases
1. DE-01: remove/unlink shared instructions in a disposable package, then restore/install to fake homes.
   Expected result: structural failure then exact installed byte equality, no real installation.
2. DE-04b: in the synthetic checkout project, assign a child a shared reference and API evidence, then make those supplied resources unavailable to that child.
   Expected result: identify the missing input and request an accessible excerpt or clarification; do not fabricate API facts, silently substitute assumptions, or assert the child inherited the full Lead discussion. Retain the observed request as the Native.DE-04b checkpoint.
3. DE-05a: leave payment retry semantics unresolved in the synthetic PRD while the checkout button label is already approved.
   Expected result: ask the user about the consequential retry choice, preserve the accepted label without another gate, and do not auto commit. Record both the decision request and approved-detail fast path.
4. DE-05b: present a proposal to split the checkout module, then have the user explicitly decline the refactor and authorize the bounded change on the existing structure.
   Expected result: continue as-is with the approved structural constraints recorded; do not restructure or insist on an already declined design. The user response and constrained plan are the native checkpoints.
5. DE-06a/DE-06b: after checkout readiness closes, change only the payment API timeout while keeping the approved UI and declined-refactor decision unchanged.
   Expected result: reopen only the affected payment boundary in existing Work/Blueprint/OpenSpec records, preserve the closed UI decision and as-is constraint, and do not revive the declined refactor or create a competing governance system. Record the bounded reopened scope and retained decisions.
### Result
- Observations and cleanup: native/user checks pending; keep active packet until user verifies or explicitly defers. Clean only owned synthetic fixture data; preserve actual project documents/history.

## Verification and invocation record

- Planning: canonical packet and six cases prepared before instruction writer GO; source-presence and missing-resource guard Red actually observed. Source/path checks cannot establish semantic exploration or native actor/model execution.
- Comments: new test explains scenario and limited expected evidence; existing installer dynamic hash assertions reused for propagation. No unrelated test rewrite.
- Actual task roster fields for Lead closeout: task handle; role selector; responsibility; creation/reuse/status; source/active expected profile; host-confirmed identity or unknown; deviation/approval. Current actual Tester handle /root/simulation_tests, selected team-tester, reused and verification completed, source profile gpt-6.1-sol/medium; host-confirmed model/effort unknown. Lead owns other actual handles and final reconciliation; no child spawned by Tester.

### Frozen 1.0.1 verification evidence

| Actual command | Exit | Evidence / scope |
| --- | --- | --- |
| pwsh -NoProfile -File tests/test-design-exploration.ps1 | 0 | shared nonempty UTF-8 payload exists; not native Agent behavior |
| pwsh -NoProfile -File tests/test-validate.ps1 | 0 | missing-reference and all four actual-link removal mutations rejected, restored payload accepted; full existing guard regressions |
| pwsh -NoProfile -File tests/test-install-user.ps1 | 0 | isolated fake-home complete source/installed-byte map, preservation/conflict cases, receipt kitVersion1.0.1; packageDigest13357cd7da24b8a10eaa836961f128f9d4f68f90d4af015b610b21aaa5368d6b |
| pwsh -NoProfile -File tests/test-ai-simulation.ps1 | 0 | supported VERSION format and manifest equality1.0.1; existing local context/budget/integrity/trace regressions, not native AI or exploration decisions |

- Runtime PowerShell7.6.5. All four suites executed once after both production writers froze. The three writable suites used separate owned temporary copies/fake homes under the OS temporary directory; guarded finally removal confirmed. Installer fixture independently absent afterward. No real Codex-home installation, model/API/network calls, extra delegation or commit.
- Frozen relevant-input identity excludes this result packet and governance output: 89 files (all agents/skills/scripts/tests files, VERSION and complete README/CHANGELOG pairs), sorted relative paths and SHA256 values hashed as UTF-8 newline-separated entries. Before and after digest identical: c7e6e7fb68f7ec196d4c40fcc734a79898dda1145fc26b92cadee1a02429346d.
- Helper SHA256 a99aace6a1bdb417a08642ab7ddb2733f9b6a622eba1c2465b376fdcee0767d7; package validator SHA256 a9411518cf9ea04d98fec05f3bc9345914f8b61582a933057c9368ef076bb335. Test source SHA256: test-design-exploration1d9c07178ef0bd1079caab19e6db4e113dc9499209afcee993ccd52b2fc56b06; test-validate c1510d75270eb0582d8e91720d514bc22188faf83f427159361d10d83c02e61b; test-install-user fb99d70a6ceef4c8fc56633af13fc6556ea0509972770a5ee01f8919d5c90cfe; test-ai-simulation9385c35fa351266fccf75f0ee1ff93df66e595124ee934ac632b1d57097ac613.
- Comment self-check: new independent scenario comments state intent, expected result and limits; package guard mutations exercise the real validator, not semantic phrase matching. Installer reuses complete payload equality. Simulator change preserves prior behavior assertions and documents release-format expectation.
- Main-reported independent checks: scripts/validate.ps1, scripts/validate-docs.ps1 -ProjectRoot ., and tests/test-bilingual-docs.ps1 each exit0. tests/test-project-rules.ps1 first hit a sandbox junction-permission failure exit1; the unchanged-source isolated retry exit0 and removed its owned fixture. tests/test-documentation.ps1 first hit a sandbox atomic-move denial exit1; the unchanged-source isolated retry exit0 and removed its owned fixture. These permission retries are environmental, not product repairs. No live installation or global configuration changes occurred.
- Optional skill quick_validate unavailable: system Python alias could not launch; bundled Python lacks PyYAML. No dependency installed and no equivalent-pass claim; native package/frontmatter guards provide narrower structural evidence.
- Native.DE-01 through Native.DE-06 (including unavailable-input, refactor-declined and bounded-reopen subscenarios) remain unexecuted/manual pending. Package checks and independent source review do not substitute for user acceptance or prove actual child inference identity.

### Lead closeout and actual child roster

| Actual handle | Explicit role selector | Assigned responsibility | Invocation / final status | Resolved model / effort |
| --- | --- | --- | --- | --- |
| /root/simulation_skills_docs | team-docs-maintainer | shared design reference, workflow and Architect instructions, version and public document pairs | reused / completed | unknown / unknown |
| /root/simulation_runtime | team-backend-engineer | real package resource/link guards and three embedded kitVersion literals | reused / completed | unknown / unknown |
| /root/simulation_tests | team-tester | test-first structural guards, isolated regression batch and canonical packet | reused / completed | unknown / unknown |
| /root/simulation_review | team-reviewer | independent actual-diff, authority and full bilingual semantic review | reused / completed | unknown / unknown |

- All four handles retain their previously explicitly selected named roles. Source and available-role profiles were checked; configured model/effort is not host-confirmed inference identity. No role fallback, additional child creation or child recursion occurred in this task.
- Independent review found no material issue. The Reviewer parsed eight changed/new PowerShell files without errors and reviewed the complete final README/CHANGELOG pairs, links, technical values, caveats and preserved history. Main and Reviewer diff-whitespace checks passed.
- Four read-only source-guided walkthroughs covered an approved CSV fix, uncertain asynchronous export recovery, a declined module refactor and a bounded actor packet. These provide semantic source evidence only: they did not execute native Agents or establish adherence, quality improvements or token savings.
- Optional feedback recording applies only to explicitly invoked Team workflows; no personal feedback store was updated for this ordinary source-maintenance request. Source changes and test evidence are retained here. No commit, push, PR or actual installation was performed.
- Acceptance remains manual pending. Keep this single current packet active until the user verifies or explicitly defers native checks; do not archive it as accepted merely because structural checks pass.
