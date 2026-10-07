# Verification: Costly test checkpoints

Packet schema version: 2
Stage slug: test-checkpoints
Contract status: active
Final manual status: manual pending
Final manual evidence: New source guidance is not installed; real Codex scheduling behavior has not been observed.

## Stage context

Objective: Schedule costly relevant tests at meaningful checkpoints while preserving early risk checks, complete coverage, required fresh gates and user authority.
Scope: existing Harness testing guidance and short routes only; no new schema, scheduler, test algorithm, default simulation or actual installation. Docs/Lead own normative source and readiness; Tester owns this packet and proportionate verification only. Preserve other agents' edits.
Test conventions: existing PowerShell package validator and schema2 stage validator; existing isolated stage suite is conditional only if template/schema changes. No code unit tests or prose-keyword tests for behavioral instructions. Prepare this plan before writer START, then wait for frozen source.
Environment/data/cleanup: local PowerShell; no credentials, network/paid calls, home/config writes or child spawning. Semantic walkthrough uses synthetic conditions without executing product tests. Any necessary fixture must use one owned temporary root and remove only that root. No fixture is planned.

## Use-case map

| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| TC-01 | Low-risk local iteration with known small impact | Select immediate affected checks | Cheap relevant behavior/regression checks run during iteration; expensive unrelated coverage is not repeated automatically | happy |
| TC-02 | First usable end-to-end chain becomes available | Choose representative smoke flow | Run smoke at that integration point; observe actual connected path rather than claim a unit pass proves the chain | happy |
| TC-03 | Agreed acceptance scope is usable; relevant costly E2E is pending | Distinguish first-chain smoke from acceptance-ready checkpoint; run before downstream reliance | Costly relevant tests execute at named acceptance checkpoint before required downstream evidence is relied on; deferred checks remain visible | happy |
| TC-04 | Security/shared/data/test-config change, unknown impact, or mandatory fresh CI gate | Reassess earlier expansion | Material risk/uncertainty and mandated freshness override routine delay; reuse cannot waive a required current-revision gate | edge |
| TC-05 | Targeted regression fails and repair is authorized | Rerun reproduction and affected dependencies | Confirm repaired behavior promptly, preserve failure/repair identity and expand if remaining impact demands it | edge |
| TC-06 | Scripted browser test is cheap, non-browser suite expensive | Compare actual cost and observation boundary | Schedule by cost/risk and reliable coverage rather than classifying all browser/E2E as expensive | alternate |
| TC-07 | Deferred test unexecuted, or known test failure affects downstream work | Report supported status, blocker reason and evidence dependencies | TDD planned/manual pending is not passing; batch blocked stays separate; known failure or due required evidence blocks affected downstream reliance while independent work may proceed | edge |
| TC-08 | Suggested AI simulation, paid action or forecast beyond explicit budget | Check explicit invocation/authority and cost account | Simulation remains opt-in; checkpoint plan does not authorize paid effects, exceed budgets or claim unmeasured savings | edge |

## Coverage-category decisions

| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No production algorithm; instruction semantics are not proven by keyword assertions. |
| integration | required | Fresh package validation checks distributable routing after source freeze. |
| contract/API | required | Inspect scheduling and retained authority contracts; no product API exists. |
| E2E | required | Actual Codex scheduling TC-01 through TC-08 remains user/environment pending. |
| regression | required | Inspect preserved coverage, freshness, failure, repair and simulation rules. |
| manual | required | User observes installed strategy separately from source review. |
| component/UI | not applicable | No product UI changed; TC-06 is a future workflow condition. |
| accessibility | not applicable | No rendered controls changed. |
| visual regression | not applicable | No visual requirement changed; future UI evidence must remain intact. |
| performance/load | conditional | Savings claims require measured comparable telemetry; none is available or planned. |
| security | required | Verify early high-risk expansion and paid/budget authority boundaries. |
| compatibility | required | Existing schema2 fields/templates and helper algorithms remain unchanged. |
| data migration/rollback | not applicable | No storage migration, rollback or install operation. |
| resilience/recovery | required | Known failures/targeted repairs retain dependency and history constraints. |
| exploratory/usability | required | Check practical distinction between test cost, type and readiness checkpoint. |

## TDD behavior matrix

| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Iteration, usable chain and checkpoint TC-01 through TC-03 | Delay becomes omission or repeated expensive runs | E2E / contract/API | manual-or-environmental | Semantic.TC-01 through TC-03; CheckpointsE2E.TC-01 through TC-03 | not applicable | Source decisions inspected; native E2E unexecuted | No algorithm/refactor | Agent scheduling is environmental; frozen-source decision walkthrough is smallest substitute, not runtime E2E | Tester / user | manual pending |
| Risk/freshness, repair, cost and failure TC-04 through TC-07 | Unsafe deferral or false pass | security / regression | manual-or-environmental | Semantic.TC-04 through TC-07; CheckpointsE2E.TC-04 through TC-07 | not applicable | Source decisions inspected; native E2E unexecuted | No algorithm/refactor | Synthetic preconditions and expected decisions reviewed against final rule; actual agent adherence remains pending | Tester / user | manual pending |
| Simulation and resource authority TC-08 | Implicit expensive simulation or budget expansion | security | manual-or-environmental | Semantic.TC-08; CheckpointsE2E.TC-08 | not applicable | Explicit invocation/budget source rules inspected | No algorithm/refactor | No simulation/live external operation authorized; actual adherence remains environmental | Tester / user | manual pending |
| Package and packet consistency | Broken routing or malformed evidence | integration / compatibility | test-after | scripts/validate.ps1; stage-verification.ps1 Validate | not applicable | Fresh package and packet checks exit0 | No helper template/schema change | Existing command contracts validate final source/packet; no new executable behavior justifies fabricated Red | Tester | passing |

## Automated test and E2E plan

After Lead GO on frozen normative source: execute `pwsh -NoProfile -File scripts/validate.ps1`; inspect full changed rules/routes and actual diff for TC-01 through TC-08; run scoped `git diff --check`; validate this packet. Fast CLI summary then failure drill-down is the adequate entrypoint. Browser/API has no meaningful product UI to observe here. Runtime/cost forecast unknown; no hard budget inferred. Do not run full deployment or documentation-policy suites; stage lifecycle suite only if template/schema inputs actually change. Public-pair checks are conditional if Docs/Lead change those pairs; avoid duplicate shared runs and record owner evidence.

| Manual case / requirement ID | E2E scenario and checkpoints | Other layers / source evidence | Status / gap |
| --- | --- | --- | --- |
| TC-01 | CheckpointsE2E.TC-01: known low-risk change, immediate affected checks and explicit deferred work | Semantic iteration decision inspected | source inspected; native E2E pending |
| TC-02 | CheckpointsE2E.TC-02: usable chain, real connected smoke execution/result | Semantic smoke boundary inspected | source inspected; native E2E pending |
| TC-03 | CheckpointsE2E.TC-03: first-chain smoke distinct from acceptance-ready costly checks before downstream reliance | Corrected semantic checkpoint inspected | source inspected; native E2E pending |
| TC-04 | CheckpointsE2E.TC-04: high/unknown impact and fresh CI gate cause early expansion | Semantic override/reuse inspected | source inspected; native E2E pending |
| TC-05 | CheckpointsE2E.TC-05: repaired failure reruns promptly and affected risk reassessed | Semantic repair/history inspected | source inspected; native E2E pending |
| TC-06 | CheckpointsE2E.TC-06: cheap scripted browser and expensive non-browser inputs get cost-aware selection | Semantic cost-versus-type inspected | source inspected; native E2E pending |
| TC-07 | CheckpointsE2E.TC-07: supported TDD statuses and separate batch blocked; known failure/due evidence blocks affected reliance | Corrected semantic status/dependency inspected | source inspected; native E2E pending |
| TC-08 | CheckpointsE2E.TC-08: simulation uninvoked; paid/budget threshold cannot expand by checkpoint | Semantic explicit authority inspected | source inspected; native E2E pending |

## Human verification script

1. Preparation: separately authorize installed-strategy use in a disposable project, identify exact instructions/revision and test runner, and use synthetic local data. This source task performs no install.
2. TC-01/TC-02: make a low-risk edit, then connect the first usable chain. Expected: immediate cheap affected checks and representative real-chain smoke at readiness; all deferred tests listed.
3. TC-03: reach the separate named acceptance-ready checkpoint after first-chain smoke. Expected: relevant costly E2E runs before downstream work relies on required evidence, with actual output and failures recorded.
4. TC-04/TC-05: introduce a security/unknown-impact condition or required fresh CI gate, then an authorized targeted repair. Expected: early appropriate expansion/current evidence; prompt reproduction rerun and preserved issue history.
5. TC-06/TC-07: offer cheap scripted browser and expensive non-browser checks, including a known failure or due required evidence. Expected: selection follows real cost/coverage; TDD uses planned/manual pending with separate blocker reason, batch blocked remains separate, and affected downstream reliance stops.
6. TC-08: mention simulation without invocation and an explicit budget boundary. Expected: no implicit simulation/paid action/budget expansion or unsupported savings claim.
7. Record user observations/results here; remove only owned disposable fixture data. Keep final manual status pending until actual evidence or user deferral.

## Verification record

Preimplementation plan validated before writer START. Fresh post-freeze `pwsh -NoProfile -File scripts/validate.ps1` exited0; scoped diff hygiene passed. Base HEAD was `502312b1044054ac6c259a7c23843691c69fb571`; PowerShell7.6.5. Inspected actual six-file normative diff and surrounding shared contract/routes. Only guidance and execution-templates Markdown fields changed; helper algorithms/schema and public pairs were untouched. Full deployment/documentation-policy/stage suites and bilingual regressions were not run because their inputs/behavior were not changed. No prior suite result is relabeled a fresh pass. No new fixture required.

Semantic TC-01/TC-02/TC-03: canonical rule requires relevant fast checks per iteration, real first-usable-chain API/integration plus key smoke, and named due acceptance checkpoints for costly relevant checks; complete coverage remains planned from the start, expensive tests are not automatically repeated at every stage, and due evidence blocks acceptance/archive absent explicit user exception. Existing no-forced-API and real-boundary rules remain intact. TC-04/TC-05: early high-risk, unknown-impact, failure and mandatory fresh-gate expansion remains explicit; gate freshness/reuse and repair-history constraints remain unchanged; failure plus affected dependents rerun after repair. TC-06/TC-07: actual/estimated observation cost, not browser/E2E label, determines timing; cheap scripted browser checks may run earlier, deferred ownership/IDs/status/trigger/flush are recorded, and known affected failures block dependent development while separated independent work can continue. TC-08: explicit simulation stays separate, existing paid-operation/budget authority remains controlling, telemetry absence stays unknown and no unmeasured savings is asserted. Plan/dev/test/review routes and Markdown templates consistently expose those same canonical decisions. No material source decision mismatch found.

Optional Skill helper: read-only workspace dependency locator found bundled Python, but `quick_validate.py skills/testing-engineering` exited1 before validation with `ModuleNotFoundError: No module named 'yaml'`. All changed Skill dirs share that same import prerequisite, so no duplicate failing invocations or dependency installation. This is unavailable optional validation, not a Skill defect or pass; native package validation supplies only its narrower routing/metadata evidence.

No Red, runtime E2E, savings or native profile-loading evidence claimed. No new/modified test code or formatter needed; existing test explanations preserved. Native manual scenarios remain pending, owned by user/Lead when separately authorized installed use is available; next trigger is a disposable real Codex project with this source strategy loaded, and flush condition is all case checkpoints observed before that future workflow's acceptance. This source task installs nothing. Browser/API observation is not applicable to these Markdown instructions. Packet remains active, not archived. Lead owns independent review, readiness and final protection/index checks.

Independent Reviewer identified two P2 wording gaps in the first freeze: generic deferred `blocked` could be misread as an unsupported schema2 TDD row status, and first usable-chain smoke was insufficiently distinct from acceptance-ready costly tests/downstream evidence reliance. Docs corrected only the canonical paragraphs and team-plan route. Tester reread final TC-02/TC-03/TC-07 conditions: TDD planned/manual pending and separate batch blocked now match unchanged helper enum; acceptance-ready scope is explicitly separate from linkage smoke and must run before required downstream reliance. Other scenario decisions remain unchanged. Fresh final package validation exit0 and diff hygiene passed after the corrections; final packet validation passed. Reviewer reported both findings resolved and no new material issue. Earlier source walkthrough remains bounded evidence, not runtime E2E.

Invocation ledger: Lead reused `/root/install_guide_docs` with original exact `team-docs-maintainer` selection for readiness/normative writing (source frozen, final readiness pending), `/root/install_guide_tests` with original exact `team-tester` selection for packet/post-freeze checks (complete and packet frozen), and `/root/install_guide_review` with original exact `team-reviewer` selection for independent read-only review/focused resolution (complete, both P2s resolved). All role definitions are exposed in the active catalog. Runtime role/model/effort unknown; no new spawn, role change, retry or Tester child. No host Close operation available and no slot-release claim. Lead owns final invocation/readiness reconciliation.
