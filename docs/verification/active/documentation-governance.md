# Verification: documentation governance

Packet schema version: 2
Stage slug: documentation-governance
Contract status: implemented; automated checks passed; human acceptance pending
Final manual status: manual pending
Final manual evidence:

## Stage context

Objective: implement version 0.9.0 task-scoped documentation adoption, review and change detection using the confirmed user design. Default documentation lives under docs; applicable active PRDs constrain development; ambiguity requires the user's decision; optional category folders are not prerequisites.

Scope: documentation runtime and contract/routing, one docs maintainer, package validation and isolated behavioral tests. Architecture is the existing docs/architecture.md Documentation governance boundary: DOC-RUNTIME, DOC-CONTRACT, DOC-ROUTING and DOC-TEST. This is an equivalent manually reviewed architecture reference; no new Blueprint schema migration or source refactor is authorized or needed. The tester owns tests/test-documentation.ps1 and this packet; Lead owns integration, role routing and package alignment.

Environment and cleanup: PowerShell 7, unique generated temporary projects named codex-doc-test-<guid>, fixture PRD, historical docs and source only. Finally validates the exact temporary path and removes it. No global installation, credentials, external service or network is required. Original project source/docs remain unchanged by adoption commands; runtime writes are limited to fixture governance metadata.

Applicable requirement source: the user's approved conversation decisions and skills/team-core/references/documentation-governance.md. This Kit has no applicable product PRD or enabled OpenSpec project. Its own development evidence uses existing docs/architecture.md and this stage packet; post-implementation adoption provides a runtime example without treating that marker as a review.

## Use-case map

| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| DOC-01 | Existing docs and code, no governance | Scan, Initialize, Validate | Read-only discovery; initialization preserves existing content; bare marker is UNCHECKED | happy / edge |
| DOC-02 | Complete authored scoped review | RecordReview; validate same and different task | Same scope/task reuses inspected evidence; different task is stale | happy / alternate |
| DOC-03 | Reviewed project | Add, modify or delete docs; modify declared source | Each change invalidates the review until actual reassessment is recorded | edge |
| DOC-04 | Pending ambiguity affects login | Record ready, then partial; validate styles and login | Ready is refused; only listed independent styles can proceed | edge |
| DOC-05 | Current PRD and legacy docs | Omit PRD inspection or assign legacy authority | Unread applicable PRD cannot support ready; historical material cannot become current authority | edge |
| DOC-06 | Saved review | Change policy version or edit report | Prior result is stale or tampered, not assumed supervised | edge |
| DOC-07 | Unsafe input path or malformed state | Request traversal; corrupt JSON | Fail closed; do not reset metadata or write outside root | edge |
| DOC-08 | All scenarios | Complete or fail tests | Temporary fixture tree is removed and actual installation is untouched | happy / edge |

## Coverage-category decisions

| Category | Decision | Reason |
| --- | --- | --- |
| unit | required | Public commands observe path, state and readiness guards without exporting internal helpers. |
| integration | required | Review persistence, inventory, source dependencies and human report interact. |
| contract/API | required | JSON authored-input/state and CLI errors must remain explicit and fail closed. |
| E2E | required | Local command workflow covers discover, adopt, review, validate and re-review. |
| regression | required | Existing stage/package/install and OpenSpec behavior must continue working. |
| manual | required | Semantic sufficiency, user decision authenticity and real workflow acceptance require human review. |
| component/UI | not applicable | No rendered UI changes. |
| accessibility | not applicable | No interface changes requiring accessibility checks. |
| visual regression | not applicable | No visual artifact or frontend implementation. |
| performance/load | conditional | Small deterministic fixtures cover correctness; large-repository scanning cost is not certified. |
| security | required | Traversal/corrupted metadata must not write outside project or invent ownership. |
| compatibility | required | Existing project layout and historical docs must survive adoption; Kit-only upgrades do not invalidate policy. |
| data migration/rollback | conditional | No prior documentation state schema exists; unknown schemas are refused rather than migrated. |
| resilience/recovery | conditional | Invalid state must fail closed; storage/power-loss recovery is outside this release's certified scope. |
| exploratory/usability | required | Human walkthrough checks clear report findings, applicability and actionable questions. |

## TDD behavior matrix

| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DOC-01 adoption and bare-marker refusal | False readiness or destructive onboarding | integration | test-first | tests/test-documentation.ps1 adoption scenarios | Initial actual suite invocation failed because skills/team-core/scripts/documentation.ps1 did not exist; fixture cleanup completed | 2026-09-30 final focused suite exit 0; adoption assertions passed | Same final suite passed after runtime hardening; no source refactor | Initial command absence is the observed suite Red; individual downstream guards were not reached | Tester / runtime writer | passing |
| DOC-02 scoped authored review | Unreviewed task inherits authority | contract/API | test-first | tests/test-documentation.ps1 scope/task scenarios | Same initial missing-command Red; this downstream assertion was authored before runtime but not individually reached | 2026-09-30 final focused suite exit 0; scope/task assertions passed | Same final suite passed after runtime hardening; no source refactor | No claim of individually observed semantic failure | Tester / runtime writer | passing |
| DOC-03 document/source invalidation | Changed evidence retains stale pass | regression | test-first | tests/test-documentation.ps1 delta scenarios | Same initial missing-command Red; downstream cases were not reached | 2026-09-30 final focused suite exit 0; freshness assertions passed | Same final suite passed after runtime hardening; no source refactor | No retrospective individual Red claim | Tester / runtime writer | passing |
| DOC-04 ambiguity and independent partial work | Silent decision or dependent work proceeds | contract/API | test-first | tests/test-documentation.ps1 readiness scenarios | Same initial missing-command Red; downstream cases were not reached | 2026-09-30 final focused suite exit 0; readiness assertions passed | Same final suite passed after runtime hardening; no source refactor | No retrospective individual Red claim | Tester / runtime writer | passing |
| DOC-05 PRD/legacy authority | Unread or historical intent governs work | integration | test-first | tests/test-documentation.ps1 PRD and legacy scenarios | Same initial missing-command Red; downstream cases were not reached | 2026-09-30 final focused suite exit 0; authority assertions passed | Same final suite passed after runtime hardening; no source refactor | Dedicated legacy authority assertion was extended during hardening as test-after | Tester / runtime writer | passing |
| DOC-06 changed policy or report | Metadata bypasses re-review | regression | test-first | tests/test-documentation.ps1 stale policy/report scenarios | Same initial missing-command Red; downstream cases were not reached | 2026-09-30 final focused suite exit 0; policy/report assertions passed | Same final suite passed after runtime hardening; no source refactor | No retrospective individual Red claim | Tester / runtime writer | passing |
| DOC-07 unsafe/corrupted metadata | Outside-root writes or false reset | security | test-first | tests/test-documentation.ps1 path/state scenarios | Same initial missing-command Red; downstream cases were not reached | 2026-09-30 final focused suite exit 0; path/state assertions passed | Same final suite passed after runtime hardening; no source refactor | No retrospective individual Red claim | Tester / runtime writer | passing |
| Additional hardening guards | Readiness bypass, lost history or external edits erased | compatibility | test-after | tests/test-documentation.ps1 classification, history, multi-scope, absent dependencies, provenance and junction scenarios | not applicable | 2026-09-30 final focused suite exit 0; all added assertions passed | Final rerun after applicability/dependency fixes passed | Added during runtime implementation after the initial suite Red; public-command assertions establish final evidence, not fabricated initial failures | Tester / runtime writer | passing |
| Semantic review and authentic user decision | Structural checks mistaken for correctness | manual | manual-or-environmental | Human script below | not applicable | pending human inspection | no source refactor | Script checks structure/freshness only; user acceptance and meaning require inspection | Lead / user | manual pending |

## Automated test and E2E plan

Initial actual Red: tests/test-documentation.ps1 was authored before the production runtime. Running it failed because documentation.ps1 was absent; the generated isolated project was cleaned. This establishes a command-workflow Red, not individually executed downstream behavior failures.

Test-after hardening added while the writer implemented the runtime: preservation of source/historical content; omitted classifications/categories; historical authority and ambiguous severity bypass; independent partial overlap; missing dependency later creation or directory substitution; previous assessment archival; stale second scope; explicit unrelated PRD; unavailable attachment applicability; policy-independent Kit provenance; report overwrite protection and escaped pointers; Windows junction refusal. These are distinct scenario blocks with expected-result comments. Script syntax parsed before engine availability. Focused suites passed after initial engine and applicability/dependency fixes; the final tests/test-documentation.ps1 rerun on 2026-09-30 exited 0, including existing source deletion/directory substitution followed by a fresh replacement-file review. Output confirmed Documentation tests passed and Isolated documentation directory removed.

Run tests/test-documentation.ps1 after the engine lands; send any precise failure to its writer, then record actual Green. Extend meaningful guard tests during hardening as test-after, not retroactive TDD. Reuse existing tests/test-validate.ps1, tests/test-stage-verification.ps1 and tests/test-install-user.ps1 for integration regression as needed; Lead records commands/results. Validate this packet before implementation and again at handoff using skills/team-core/scripts/stage-verification.ps1 -Action Validate -ProjectRoot <repository> -StageSlug documentation-governance. Fixtures use explicit scenario and expected-result comments. A single final broad pass suffices unless subsequent edits invalidate it.

Actual integration evidence reported by the Lead on 2026-09-30: tests/test-deployment.ps1 passed isolated upgrade/downgrade, recovery, Git targeting, ownership and cleanup; tests/test-stage-verification.ps1, tests/test-project-blueprint.ps1, tests/test-feedback-runtime.ps1 and tests/test-openspec.ps1 passed (OpenSpec offline CLI doubles). These existing suites do not constitute documentation-runtime Green. No real installation or user acceptance was performed.

Package validation and tests/test-validate.ps1 also passed. The initial tests/test-install-user.ps1 attempt stopped with PACKAGE: Source changed while staging while concurrent writers changed source; its temporary root was removed. This correctly enforced package consistency. The Lead reran tests/test-install-user.ps1 after source stability: exit 0, isolated directory removed. The interrupted attempt is not recorded as successful installation evidence.

Independent instructions review identified a delegated-role collision: team-doc-check originally could be read as appointing a docs maintainer who then performs Lead orchestration. The Lead resolved this by explicitly separating main Lead and delegated maintainer modes; delegated roles neither spawn further children nor authorize a development start. This is a review finding resolved in workflow instructions, not an executable proof of future agent behavior.

Final independent reviewer report: no outstanding material findings at the frozen implementation revision. Applicability, dependency shape, delegated role and duplicate validator corrections were inspected. Automated checks cannot authenticate user approval, confirm actual semantic reading or certify every large-repository environment; these remain stated limits.

The Kit's own docs/governance adoption example will be recorded retrospectively after implementation and final document stabilization. No claim is made that a new runtime review passed before its runtime existed; the preimplementation contract was the approved design, existing architecture and validated stage packet.

## Human verification script

### Preparation

1. Create a disposable project containing a short docs/PRD/product.md, an existing source module and a historical document in docs/legacy. Record their original bytes. Use the documented CLI in a fresh project workflow; no real user installation is needed.
   Expected result: the fixture starts without governance metadata; optional docs category directories are absent.

### Happy path

1. Run discovery and initialization, inspect docs/governance/doc-index.md and documentation.json.
   Expected result: documents are indexed and tracking exists; original documents/source are unchanged; task readiness is still unchecked.
2. Ask the docs maintainer/Lead to inspect the scoped PRD and source evidence, author a review and validate the same task.
   Expected result: the report describes actual read scope, exclusions, PRD applicability, all information-category decisions and source evidence; only this task is ready.
3. Complete bounded development, reconcile any changed documentation and record reassessment.
   Expected result: the task uses the current review; test acceptance remains in the stage packet rather than duplicated in the governance marker.

### Recommended edge cases

1. Add a new proposal document or change a declared source dependency, then validate the old review.
   Expected result: stale evidence is reported; new material is classified/read as relevant or explicitly unrelated before reuse.
2. Supply contradictory PRD timeout requirements and request development.
   Expected result: the original documents remain untouched; the Agent shows evidence, options and recommendation, asks the user and pauses affected work. An independent permitted task can proceed.
3. Request archive of a document whose validity is uncertain.
   Expected result: the Agent asks how to handle it; no automatic move to legacy occurs. After a confirmed decision, relevant references and archive reasons are maintained.
4. Use an unread attachment, draft PRD or unrelated active PRD.
   Expected result: the report accurately distinguishes unavailable/read/unrelated and records applicability; no filename/date-only authority decision.

### Result

Observations: manual checks are pending. Automated evidence cannot mark user acceptance complete. Remove the disposable fixture after recording actual findings; keep this current packet until the user verifies or explicitly defers manual acceptance.

## Comment self-check

Inspected final tests/test-documentation.ps1: file purpose/boundary overview and fixture/review helper contracts are present; every independent scenario block has nearby scenario and observable expected-result explanations, including attachment, archive, multi-scope, dependency-shape and junction cases. Comment promises match assertions and actual passing evidence. Small obvious Assert helper is explained by its direct failure behavior rather than a redundant template; no generated/vendor code or untouched historical test backfill is in scope. No remaining owned comment gap was identified.
