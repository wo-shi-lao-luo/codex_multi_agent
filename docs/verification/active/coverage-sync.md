# Verification: Manual and automated coverage synchronization

Packet schema version: 2
Stage slug: coverage-sync
Contract status: implemented; focused automated checks passed; real-workflow acceptance pending
Final manual status: manual pending
Final manual evidence:

## Stage context

Objective: E2E plans include every manual test scenario, and user-added samples/requirements update E2E plus applicable other layers without false pass claims.
Scope: shared acceptance contract, relevant Skill entrypoints, initializer template and isolated tests. Lead owns the bounded implementation and verification; no subagents. No new parser schema, automatic background watcher, UI or structural refactor. Scoped readiness: docs/governance/reviews/coverage-sync.md. Fixtures use unique system-temporary directories; cleanup is verified. No live installation or external service.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| CS-01 | Initialize a stage | Inspect plan mapping and human case fields | New packet exposes scenario-to-E2E/other-layer/status/gap fields | happy |
| CS-02 | User adds a manual case or requirement | Preserve case; assess automation and affected assertions | Include E2E scenario and applicable other layers; refresh affected evidence | edge |
| CS-03 | Aesthetic/safety/environment limit | Assess equivalent automated evidence | Retain scenario and gap; ask user before accepting exception; no false pass | edge |
| CS-04 | Existing schema2 packet | Validate and try archive while manual pending | Legacy packet remains valid; archive remains blocked | alternate |
| CS-05 | Ambiguous or new product scope | Check source decision and dependencies | Ask user before intent/scope changes; retain prior evidence | edge |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No new algorithm or public runtime API. |
| integration | required | Initialize/Validate/Archive sequence exercises local packet lifecycle. |
| contract/API | required | Generated mapping fields and legacy schema2 acceptance. |
| E2E | required | Local packet-lifecycle suite plus planned real-agent scenarios. |
| regression | required | Existing parser, manual authority and archival protections retained. |
| manual | required | Human reviews instruction semantics and real workflow behavior. |
| component/UI | not applicable | No UI code. |
| accessibility | not applicable | No rendered controls. |
| visual regression | not applicable | No visual artifact. |
| performance/load | not applicable | No material load change. |
| security | conditional | Preserve user authority, environment limits and redaction. |
| compatibility | required | Retain schema2 and existing packets. |
| data migration/rollback | not applicable | No persisted schema migration. |
| resilience/recovery | conditional | Invalid/unfinished evidence cannot authorize archive. |
| exploratory/usability | required | Reader can reconcile added manual cases with test plans. |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Initialize mapping artifact | Missing traceability fields | contract/API | test-first | tests/test-stage-verification.ps1 coverage-sync scenario | Initial run failed before template edit: Initialize did not emit a fillable manual-to-automated mapping table; fixture removed | Suite exit0 after template edit; mapping columns and fillable row verified | Relevant rerun exit0; no production-code refactor | not applicable | Lead | passing |
| Retain legacy lifecycle | New table breaks schema2 or manual authority | regression | test-after | tests/test-stage-verification.ps1 legacy and sync fixtures | not applicable | Suite exit0; added case retained byte-for-byte by Validate, pending Archive rejected and active packet retained; legacy Validate/Archive preserved | Same suite passed; no parser/schema refactor | Existing parser is unchanged; preserved lifecycle and new filled-fixture regression, no fabricated prior Red | Lead | passing |
| Actual agent synchronization | User additions silently omitted or exceptions treated passing | manual | manual-or-environmental | AgentCoverageSync.M02 and M03 | not applicable | manual pending | not needed | Instructions require runtime observation; static template tests cannot prove future agent actions | Lead / user | manual pending |

## Automated test and E2E plan

Observed initial Red before template edits: tests/test-stage-verification.ps1 failed with `Initialize did not emit a fillable manual-to-automated mapping table.` Its unique fixture was removed. After integration the same suite exited0 with `Stage verification tests passed.` and cleanup confirmation. tests/test-validate.ps1, tests/test-documentation.ps1 and fake-home tests/test-install-user.ps1 also exited0 and removed their fixtures. Package validation and diff check passed. Skill creator's supplementary Python quick_validate helper could not run because Python is unavailable on PATH; native package validation checks Skill metadata/routing, not semantic compliance. No dependency or actual installation was added.

The mapping-field test observes the initializer's artifact contract. Lifecycle regression preserves later-authored mappings and pending manual authority; it does not implement or certify a semantic inclusion validator. Real-agent cases M02/M03 remain manual pending.

### Manual-to-automated coverage mapping
| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| M01: generated mapping and authority | tests/test-stage-verification.ps1: initialize mapping, fill manual/E2E links, Validate, reject pending archive | contract/lifecycle regressions in the same suite | automated passing; user check pending | Artifact shape is observable; semantics require review |
| M02: add double-submit manual scenario | AgentCoverageSync.M02: real-agent task preserves conditions/results and updates E2E plan/assertions | Evaluate component, unit, integration and regression tests in disposable target project | manual pending | Real-agent acceptance is not automated by this package suite |
| M03: unautomatable or ambiguous requirement | AgentCoverageSync.M03: retain entry, request exception/scope decision, do not claim passing | Static source inspection; task-specific substitute requires user decision | manual pending | No approved automation exception or product-scope decision presumed |

## Human verification script
### Preparation
1. Use a disposable target project with a draft packet and record environment/cleanup.
### Happy path
1. M01: initialize a packet, fill mapped manual and automated scenarios and inspect its generated fields.
   Expected result: scenario IDs, checkpoints, other-layer decisions, status/evidence and gap fields are available; pending manual acceptance blocks archive.
### Recommended edge cases
1. M02: add a manual double-submit case after earlier tests passed.
   Expected result: E2E includes the same conditions/results, applicable lower-layer tests are assessed/updated and only affected results are refreshed; a unit-only test is not an E2E substitute.
2. M03: add a visual-only check or ambiguous new requirement.
   Expected result: scenario remains listed; Agent asks for exception/intent/scope decisions instead of silently excluding it or editing archived acceptance.
### Result
Observations: manual pending. Remove any manual disposable fixtures after recording results.

## Comment self-check

Inspected the diff for stage-verification.ps1, test-stage-verification.ps1 and documentation.ps1. New file overviews explain lifecycle responsibilities/limits; each new independent test block explains scenario and observable expected outcomes, and assertions cover its stated field shape, read-only preservation and pending-archive rejection. Existing parser/functions are unchanged; no new public interface requires documentation. The Kit version scalar has matching source/release metadata. No in-scope comment gap was found. Semantic source self-review checked new manual cases, reused lower-layer evidence, visual exceptions, ambiguous/scope-changing input and archived-stage follow-ups; future runtime results remain unverified. No subagents were called.
