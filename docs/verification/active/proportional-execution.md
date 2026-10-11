# Verification: Risk-proportional execution

Packet schema version: 2
Stage slug: proportional-execution
Contract status: focused structural verification passed after source freeze; native runtime/manual acceptance pending
Final manual status: manual pending
Final manual evidence:

## Stage context

Objective: eligible, understood bounded low-risk work defaults to Lead-owned execution with explicit self-check; material and uncertain work retains named implementation, testing and independent review. This change itself alters harness behavior and uses separate writer, Tester and Reviewer.
Owner: proportional_tests owns this canonical packet and focused structural test scope; Lead owns release and integration; independent Reviewer owns source classification cases. No application AI evaluation is in scope. No new runtime delegation or packet-schema behavior is proposed.

Migration trace: execution-contract.md and team-dev previously required separate implementer/Tester and a packet for small changes, with explicit approval for Lead-only. The approved replacement permits the understood low-risk path by default (PE-01/PE-02); workflow-routing.md, role-routing.md, planning/development/testing entrypoints and evidence templates consume that rule. Material harness/authority risks retain named roles and independent review (PE-03); uncertainty reopens classification (PE-04); explicit requests/stage/manual authority stay effective (PE-05); missing capacity cannot replace eligibility (PE-06). No persisted schema/data/rollback transition or module refactor is involved. Lead/Reviewer reconcile complete consumers; this packet preserves historical/manual evidence rather than rewriting older packets.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| PE-01 | Bounded understood metadata/doc correction | Classify purpose and retained checks | Lead-owned path without separate approval or forced roles; explicit self-check | happy |
| PE-02 | Small isolated ordinary code with understood boundary | Inspect risk and verification | Lead may implement and verify proportionately; domain, comment and TDD obligations retained | happy |
| PE-03 | One-line security, API contract or harness change | Assess semantic effect | Material path despite size or extension | edge |
| PE-04 | Initially bounded work reveals uncertainty | Reassess before continuing | Return to discovery/contract and escalate roles as needed | alternate |
| PE-05 | Explicit multi-agent request or project/stage requirement | Read applicable authority | Preserve requested roles, artifact and stage obligations | alternate |
| PE-06 | Required named role unavailable | Inspect capacity and eligibility separately | Missing capacity does not authorize Lead fallback | edge |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No executable classifier or algorithm change. |
| integration | required | Existing focused Team entry package checks exercise reference consumers. |
| contract/API | required | Source route integrity and existing packet schema remain supported. |
| E2E | required | Forward real-agent scenarios PE-01 through PE-06 remain planned; source review cannot prove runtime delegation. |
| regression | required | Reuse focused Team entry checks; stage runtime is unchanged. |
| manual | required | Actual runtime decisions and user acceptance need observed evidence. |
| component/UI | not applicable | No UI. |
| accessibility | not applicable | No controls. |
| visual regression | not applicable | No visual artifact. |
| performance/load | not applicable | No measured overhead or runtime speed claim. |
| security | conditional | Source review PE-03 retains material authority boundaries; no real security changes. |
| compatibility | required | Existing entry links and packets retain compatibility. |
| data migration/rollback | not applicable | No data or schema migration. |
| resilience/recovery | conditional | PE-04 and PE-06 examine uncertainty and missing-role response semantically. |
| exploratory/usability | required | Independent bounded forward classification review. |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Routing authority discoverable through entry references | Broken navigation hides eligibility and retained safeguards | integration | test-after | tests/test-team-entry.ps1 -RoutingOnly | not applicable | Exit0; eight source edges, one intact copied-validator pass and unchanged bytes; all four incompatible modes reject | not needed; no runtime refactor | Instruction semantics lack a deterministic executable classifier; existing structural consumer checks are the smallest reliable automation | proportional_tests | passing |
| Risk classification and escalation | Low-risk path bypasses material review or explicit authority | E2E | manual-or-environmental | ProportionalE2E.PE-01 through PE-06 | not applicable | planned | not needed; no runtime refactor | Independent source classification review now; actual native runtime unavailable in structural test runner | Reviewer; Lead/user for runtime | manual pending |

## Automated test and E2E plan

Before writer release: validate this filled packet. After writer freeze: inspect routes and existing conventions, add only meaningful missing structural link checks using existing consumer, run tests/test-team-entry.ps1 -RoutingOnly and packet Validate. The focused mode checks eight actual authority-link edges, one intact copied package through its real validator, and byte-exact nonmutation; it skips unrelated negative metadata/feedback/install loops. Lead owns public bilingual checks and one isolated complete package validation; do not duplicate full validator/install/platform regressions.

Execution entrypoint: pwsh -NoProfile -File tests/test-team-entry.ps1 -RoutingOnly; observation is exit/summary with failing assertion drill-down. Estimated cost is unknown; final draft is the due checkpoint. Browser/visual checks are not applicable. Deferred PE-01 through PE-06 runtime checks belong to Lead/user; next trigger is a controlled forward task using final source, with all cases flushed before claiming native routing compliance. No runtime pass or token savings is claimed.

### Manual-to-automated coverage mapping
| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| PE-01 | ProportionalE2E.PE-01 inspect classification, roles and self-check | Structural routing plus independent source review | planned | Runtime pending |
| PE-02 | ProportionalE2E.PE-02 inspect isolated code verification and obligations | Independent source review | planned | Runtime pending |
| PE-03 | ProportionalE2E.PE-03 inspect one-line security/contract/harness routing | Independent source review | planned | No real sensitive change authorized |
| PE-04 | ProportionalE2E.PE-04 introduce uncertainty and inspect escalation | Independent source review | planned | Runtime pending |
| PE-05 | ProportionalE2E.PE-05 explicit roles/stage/manual artifact request | Independent source review | planned | Runtime pending |
| PE-06 | ProportionalE2E.PE-06 controlled unavailable-role catalog | Independent source review | planned | Do not alter real role configuration |

## Human verification script

### Preparation
Use a disposable repository and final source instructions; record actual selectors/handles and checks. No production credentials, external writes or real configuration changes.
### Happy path
1. PE-01 and PE-02: request an understood bounded metadata change and isolated ordinary code fix. Expected: Lead-owned execution records rationale, retained verification and explicit self-check without automatic schema packet or separate role approval.
### Recommended edge cases
1. PE-03: present one-line security, API contract and harness instruction changes. Expected: semantic risk selects material path rather than size.
2. PE-04: reveal uncertain coupling. Expected: return to discovery/contract and escalate.
3. PE-05: explicitly request multi-agent work and a manual artifact. Expected: preserve requested authority and artifact.
4. PE-06: observe a controlled catalog without a required role. Expected: no capacity-based eligibility or silent fallback.
### Result
Manual pending. Remove only owned disposable fixtures after evidence recording; no user acceptance inferred from source checks.

## Verification record

Final Lead integration: `/root/proportional_review`, selected with `agent_type: team-reviewer`, independently applied the six request scenarios to the frozen instructions. Confirmed metadata and the established arithmetic fix select Lead self-check; material permission/harness changes retain standard roles; uncertainty upgrades dependent work; explicit multi-agent/manual requests remain effective; capacity rejection never permits silent downgrade. One P2 finding in both README current-release overviews was corrected: stage-packet creation now explicitly applies to the standard path. A bounded follow-up review confirmed resolution and bilingual equivalence; no other material findings were reported.

After that prose-only correction, the actual-source bilingual validator passed again. The earlier bilingual regression result is reused: its test code, validator, fixed synthetic fixtures and local runtime are unchanged; it does not consume the repository README contents as fixture inputs. Package/resource and RoutingOnly evidence remains scoped to the unchanged resources, link targets, source metadata and assertions; the README correction introduces no new link or technical value. This is not a claim that every final-source byte matches an earlier package snapshot. No full suite, installation or native routing run was added. Skill Creator's Python quick validator could not start because the local Python application alias was inaccessible; the real package validator supplied frontmatter/resource validation instead. No Python/tool installation was attempted.

Final roster: `/root/proportional_writer` (`team-docs-maintainer`) completed and frozen; `/root/proportional_tests` (`team-tester`) completed and frozen; `/root/proportional_review` (`team-reviewer`) completed, P2 resolved. Role selectors and handles are call evidence; loaded identities and resolved models were not independently reported. No closure operation is exposed by this host, so completion is not claimed to release thread capacity. After Tester freeze, Lead took only this integration-record section; no test or case expectations changed. Native runtime and user manual acceptance remain pending. No Git mutation, delivery, installation, network service or feedback-home write was performed by this task.

Planning prepared and packet validated before writer release. Tester handle /root/proportional_tests; no children spawned. Actual role model identity is not independently observed. Production ownership remains separate from tests. External capabilities used: testing-engineering Skill and team-core references for coverage/TDD/readability; local PowerShell tools for read-only discovery, focused tests and packet validation; apply_patch for assigned test/packet edits. No network, installation or Git mutation.

Observed final verification after Lead's source-frozen release: `pwsh -NoProfile -File tests/test-team-entry.ps1 -RoutingOnly` exited0 and reported eight authority source edges plus one real copied-validator check with complete package bytes unchanged. Existing shared helper supplied literal-argv subprocess capture, Narrow package copy, complete fingerprint and bounded GUID-temp cleanup; final return success establishes the suite's finally cleanup succeeded. No full metadata fault/feedback/install loop ran. The early incompatible-switch guard rejected RoutingOnly with each of RedOnly, AutomaticRedOnly, GuardRedCase Policy and InstallOnly; each process exited1 with the expected conflict diagnostic before fixture creation. A preliminary RedOnly conflict invocation also returned the expected exit1; none of these are claimed as TDD Red for policy semantics.

Commands: focused mode above; four literal-argv invocations through existing Invoke-TestProcess with `-RoutingOnly` plus each conflicting mode; `pwsh -NoProfile -File skills/team-core/scripts/stage-verification.ps1 -Action Validate -ProjectRoot . -StageSlug proportional-execution` before writer release and again at handoff. No stage runtime regression rerun is needed because no stage script/schema behavior changed. Lead separately owns PublicDocs complete-package and bilingual validation; their outcomes are not duplicated as Tester execution here.

Comment/readability self-check: inspected the changed tests/test-team-entry.ps1 blocks and surrounding overview/helper contracts. PE01 explains navigation-only evidence and checks each edge plus target existence; PE02 explains real consumer/nonmutation and asserts success plus complete fingerprint before return. Early mode-conflict guard is documented; no new helper/interface or production logic was written. Existing Red/default/guard/install branches and purpose/expected-result explanations remain intact. New lines follow existing two-space PowerShell conventions. Formatter Auto Plan reported exit2, needs-selection with no formatter/config paths; no formatter Check pass is claimed, no formatter installed/configured. Layout/manual readability inspected with no remaining issue in assigned diff.

Source-level evidence remains limited: native delegation, loaded role identity, real-world classification and user acceptance are unobserved; PE-01 through PE-06 stay manual pending. Independent Reviewer supplies bounded forward source classification and Lead reconciles roster/readiness. No retrospective test-first claim, runtime routing pass, measured saving, new schema or broad report system is introduced.

Lead-reported integration evidence: PublicDocs profile including config passed one isolated actual validate.ps1 invocation, complete fingerprint equality and exact fixture cleanup; public bilingual validator and bilingual regression passed; diff whitespace check passed with line-ending warning only. These were Lead executions, not duplicated by Tester. Lead reconciles final governance after this packet freezes. Actual current-task roster supplied by Lead: /root/proportional_writer selected team-docs-maintainer, completed/frozen; /root/proportional_tests selected team-tester, focused checks complete; /root/proportional_review selected team-reviewer, independent review pending at Tester handoff. Host-reported role/model identity is not reported. No install or Git mutation occurred.
