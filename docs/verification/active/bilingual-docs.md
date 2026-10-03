# Verification: Bilingual repository documentation

Packet schema version: 2
Stage slug: bilingual-docs
Contract status: active
Final manual status: manual pending
Final manual evidence: User semantic translation and navigation acceptance unobserved.

## Stage context

Objective: Publish root README.zh-CN.md and CHANGELOG.zh-CN.md with reciprocal navigation and same-change synchronization, preserving English entrypoints and existing 0.9.3 source changes.
Scope: repository-only bilingual documentation, durable repository maintenance rules and read-only validator. No global translation requirement, installed runtime, commit, push or installation.
Owners: Lead integration; Docs Maintainer translations/policy; Backend validator; Tester this packet and tests; Reviewer independent review.
Environment/test data/cleanup: PowerShell 7 invokes real validator against unique system-temp synthetic repositories; no credentials or installed home writes; exact owned paths verified before removal. Packet is the sole test-result authority.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| BD-01 | Equivalent English/Chinese documents | Run repository validator and follow language links | Exit0; languages can use natural prose; commands/models/releases agree | happy |
| BD-02 | Missing/empty document or malformed code fence | Run validator | Nonzero with no source writes | edge |
| BD-03 | Changed command/flag/model/effort/link/literal | Run validator before publishing | Nonzero for unsynchronized technical fact | edge |
| BD-04 | Changed version/date/release/item or VERSION | Run validator | Nonzero for history or authoritative-release mismatch | edge |
| BD-05 | Public Chinese translation | Read both full documents and historical releases | Equivalent scope and caveats; readable Chinese; checker does not certify semantics | happy |
| BD-06 | Maintainer updates either language | Inspect repository policy and update pair | Same-change counterpart synchronization; no global target-project translation requirement | alternate |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | Real command boundary provides focused observable behavior without coupling to helpers. |
| integration | required | Files, VERSION and validator work together in isolated repository fixtures. |
| contract/API | required | Public PowerShell entrypoint has exit0/nonzero and read-only guarantees. |
| E2E | required | End-to-end CLI fixture lifecycle plus manual semantic/navigation observations. |
| regression | required | Drift rejection and idiomatic translation acceptance are preserved. |
| manual | required | Human judges translation completeness/readability and actual link navigation. |
| component/UI | not applicable | No application interface changes. |
| accessibility | not applicable | No application controls changed. |
| visual regression | not applicable | No generated visual output. |
| performance/load | not applicable | Small deterministic documentation validator, no measured token claim. |
| security | required | Read-only target and exact disposable cleanup checked. |
| compatibility | required | Existing install/runtime validation unaffected by repo-only checker. |
| data migration/rollback | not applicable | No runtime state changes or installation. |
| resilience/recovery | required | Failure does not modify documents and restored fixture passes. |
| exploratory/usability | required | Meaning/readability review beyond structured facts. |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Equivalent translated technical facts and drift rejection | Bad commands/models/history publish | contract/API | test-first | tests/test-bilingual-docs.ps1 BD-01 through BD-04 | pwsh -NoProfile -File tests/test-bilingual-docs.ps1 exit1 before implementation: Bilingual validator entrypoint does not exist; owned fixture absent after finally | Same focused suite exit0 after validator implementation; missing/empty members, 14 drifts, shared VERSION mismatch and translated-prose/layout baseline observed | Final coherent-draft focused rerun exit0; source-pair validator exit0; no production refactor | not applicable | Tester | passing |
| Read-only validation and disposable cleanup | Mutate source or installed files | security | test-after | tests/test-bilingual-docs.ps1 fixture hashes and finally cleanup | not applicable | Focused suite exit0, fixture hashes equal before/after validation, exact owned root removed | Final coherent-draft focused rerun exit0 including hashes and cleanup; no production refactor | Initial missing-entrypoint Red stops before source hash assertions; safety behavior checked once validator is available, not independently observed Red | Tester | passing |
| Native package fixture includes referenced Chinese release history | New reciprocal link breaks selective copied fixture | regression | test-first | tests/test-validate.ps1 baseline isolated package | After navigation was added, independent Tester run exit1: Baseline validation failed in an isolated package copy; cleanup completed before fixture repair | Added only CHANGELOG.zh-CN.md to selective copy list; session69646 exit0 and owned directory removed | Final coherent-source suite session57155 exit0, owned directory removed | not applicable | Tester | passing |
| Semantic translation and maintenance responsibility | Misleading translation despite equal literals | manual | manual-or-environmental | BD-05 and BD-06 semantic walkthrough | not applicable | Independent Reviewer inspected complete source pairs and scoped policies; user acceptance pending | no production refactor expected | Source review cannot establish rendered navigation or user acceptance, nor prove future Agent compliance | Reviewer / user | manual pending |

## Automated test and E2E plan

Run pwsh -NoProfile -File tests/test-bilingual-docs.ps1 before and after implementation; run scripts/validate-docs.ps1 -ProjectRoot . on final source. Existing package validator remains separate. Structured assertions cannot prove semantic translation or GitHub-rendered link navigation.

### Execution and observation choices
| Case / test ID | Execution entrypoint and real boundary | Runner / command | Observation mode and rationale | Retained browser / visual checkpoints | Evidence / drill-down / gaps |
| --- | --- | --- | --- | --- | --- |
| BD-01 through BD-04 | Real validator child process against temporary repository files | tests/test-bilingual-docs.ps1 | Concise outcomes; failed case includes validator output | No browser business UI; rendered language navigation remains manual | Red/Green recorded after actual runs |
| BD-05 and BD-06 | Actual bilingual source, repository policy and rendered navigation | Human source/render walkthrough | Compare complete meaning and caveats, not line counts | Open each language link in repository viewer | Semantic acceptance unobserved |

### Manual-to-automated coverage mapping
| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| BD-01 | CLI.BD-01 equivalent translations and reciprocal link targets | Integration fixture | passing; isolated real validator command exit0 | Rendered navigation manual pending |
| BD-02 | CLI.BD-02 every missing/empty member and malformed fence fails | Contract boundary | passing; every isolated mutation rejected | None accepted |
| BD-03 | CLI.BD-03 technical command/flag/model/effort/literal/link drift fails | Regression cases | passing; every targeted isolated mutation rejected | None accepted |
| BD-04 | CLI.BD-04 dates/versions/items/VERSION consistency | Integration and regression | passing; history and shared VERSION mismatch rejected | None accepted |
| BD-05 | SourceReview.BD-05 full translated history meaning; CLI structured comparisons supplementary | Independent semantic review | manual pending | Meaning cannot be proven by CLI; no automation exception accepted |
| BD-06 | SourceReview.BD-06 scope-specific sync rule plus simulated pair drift via CLI.BD-03 | Policy walkthrough | manual pending | Future agent compliance unobserved; no automation exception accepted |

## Human verification script
### Preparation
1. Use the reviewed source revision and local repository viewer; no install or real-home writes.
### Happy path
1. BD-01: open README.md, follow Chinese navigation, return through English; repeat CHANGELOG pair. Expected: exact intended counterpart, correct current version and complete release history.
2. BD-05: compare installation, models, limitations and all release items. Expected: Chinese conveys the same facts and caveats in readable language, not an abridged history.
### Recommended edge cases
1. BD-02: in a disposable copy remove one CN file or break a code fence. Expected: validator fails and does not repair/mutate files automatically.
2. BD-03: alter one Chinese install flag, model, effort or guide target. Expected: validation rejects each drift; restoration passes.
3. BD-04: alter historical date/item or VERSION only. Expected: inconsistency rejected, not merely pair-to-pair accepted.
4. BD-06: update either language's factual instruction, consult maintenance policy. Expected: counterpart updated in the same change; no requirement to translate target projects' other documentation.
### Result
Observations: manual pending. Remove only verified owned disposable fixtures, retain this canonical packet.

## Verification record

Lead close reconciliation: the approved task is a bounded repository documentation/tooling extension at the existing uncommitted 0.9.3, not a stable promotion. Task-input readiness and the Tester-owned stage plan were inspected and validated before writers started. Existing architecture is sufficient; no Blueprint amendment, PRD change, OpenSpec adoption or source refactor was needed. Backend owns only the read-only checker; Docs Maintainer owns the public language pairs and repository rules; Tester owns test code and the packet; Lead owns release/readiness integration. Independent Reviewer inspected all README sections and every release from 0.9.3 through 0.1.0, actual agent/config model facts, scoped maintenance rules, code comments, assertions and cleanup. Missing historical translation details, command-paragraph placement and the selective fixture defect were corrected. Final native/doc/packet checks and isolated bilingual/package suites passed in independent review; Tester also passed fake-home installation. No unresolved material review findings remain. User semantic acceptance, rendered navigation and future Agent adherence are unobserved and remain pending; this packet is not archived.

Document-purpose reconciliation: English remains the default public entrypoint; each Chinese file is one current equivalent, not a superseded version or a second results journal. Changelogs own public release history; AGENTS.md and release-versioning.md own this repository's same-change synchronization rule; the separate validator owns structural/technical comparisons, not translation certification or global installer requirements. This packet owns outcomes and manual checks; governance owns scoped readiness. Root language pairs outside the default governance inventory are explicitly reviewed and fingerprinted as dependencies. Prior efficient-test work and historical acceptance records are preserved.

Actual invocation ledger: /root/bilingual_tester selected with agent_type team-tester, planned coverage, authored tests and verified source/isolated fixtures, complete; /root/bilingual_docs selected with agent_type team-docs-maintainer, translated public pairs and wrote repository policies, complete; /root/bilingual_validator selected with agent_type team-backend-engineer, implemented the separate read-only checker, complete; /root/bilingual_reviewer selected with agent_type team-reviewer, independently reviewed source and verification, complete. These exact selectors were present in the active tool catalog. At most three children ran concurrently; no generic substitution, failed creation, retry or child recursion occurred. Returned handles establish creation but do not independently confirm loaded identity, model or effort; these remain unknown. Lead's inspection/reconciliation is separate from independent Tester and Reviewer evidence.

Plan established before production. Initial suite stopped at missing-validator assertion, so individual drift and nonmutation assertions were not yet executed; absence of the feature is the observed Red, not separate Red for every downstream check. Tester reads testing-engineering, TDD/test acceptance/comment contracts and folder guide. Exact role selector team-tester supplied by Lead; loaded runtime model/effort unknown. No children spawned. Every independent test scenario has purpose/expected-result comments; helpers describe boundary or failure behavior. Existing uncommitted efficient-test task is preserved. No semantic automation guarantee or human acceptance claimed.

Observed focused Green: tests/test-bilingual-docs.ps1 exit0 after validator implementation, before final translations. Baseline idiomatic prose and translated role labels plus extra prose blank lines accepted; all five required members independently missing/empty rejected; fourteen named technical/history/fence/navigation mutations rejected; stale anchored current release with correct historical mention rejected; shared VERSION drift rejected; input hashes unchanged; owned fixture removed. Native scripts/validate.ps1 exit0; isolated tests/test-validate.ps1 session75264 exit0 with cleanup; fake-home tests/test-install-user.ps1 session27750 exit0 with cleanup, exact owned root independently confirmed absent. Existing Git-ignore permission warnings were nonfatal; no personal Git configuration changed. Repository-only bilingual checker is not required by runtime installer. Final-source translated-document validation and post-review focused rerun pending.

Later integration regression: reciprocal CHANGELOG navigation exposed an incomplete existing selective fixture. Reviewer reported the failure and Tester independently reproduced tests/test-validate.ps1 exit1 before repair. Prior session75264 pre-navigation pass is not final-source proof. Only tests/test-validate.ps1 copy list changed to include CHANGELOG.zh-CN.md and explain why; session69646 passed exit0 afterward. Inspection of all test changelog copy references found no other selective copy list. tests/test-install-user.ps1 invokes full source directly; tests/test-deployment.ps1 builds intentionally tiny synthetic packages without public changelog, so neither needs edits. Existing tests/test-stage-verification.ps1 previous-task edits untouched. Final-source checker still reports in-progress README literal and CHANGELOG structure mismatch; no draft pass claimed.

Final coherent-source verification after Docs Maintainer completion: scripts/validate-docs.ps1 -ProjectRoot . exit0; scripts/validate.ps1 exit0; tests/test-bilingual-docs.ps1 exit0 with all drift/acceptance/nonmutation scenarios and owned cleanup; tests/test-validate.ps1 session57155 exit0 with isolated directory removed; tests/test-install-user.ps1 session74820 exit0, exact fake-home fixture independently confirmed absent. This supersedes the earlier intermediate translation mismatch without rewriting that factual timeline. Installer receipt remains kit0.9.3; it packages only managed agents/Skills, not new public CN docs or repository maintenance instructions. No actual local installation performed. Git diff --check on owned paths passed; LF/CRLF advisory only. Reviewer-requested selective-fixture repair was included before these complete reruns.

Comment self-check: tests/test-bilingual-docs.ps1 file overview explains real CLI boundary and no installed mutations; each helper documents purpose/contract; every independent scenario and parameterized mutation table explains observable expected success/failure, backed by exit-status, hash and cleanup assertions. tests/test-validate.ps1 changed only the fixture copy list and adjacent rationale, retaining existing scenario explanations/assertions. No untouched helper/interface rewrites, production edits or unsupported exemptions. Human semantic/readability/rendered-navigation acceptance and future agent policy compliance remain pending, not inferred from structured Green.
