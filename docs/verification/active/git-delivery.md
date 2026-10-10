# Verification: Git delivery checker

Packet schema version: 2
Stage slug: git-delivery
Contract status: ready
Final manual status: manual pending
Final manual evidence: Actual host availability, agent policy judgment and user acceptance pending.

## Stage context
- Objective: reusable bounded Git delivery readiness facts and conditional checker routing.
- Scope, environment, test data, and cleanup: Tester owns this packet and tests/test-git-delivery.ps1. Real disposable Git repositories under one unique OS temporary root; hash all fixture files including index, refs and objects before/after checker invocation. Cleanup only verified owned temporary root. No real homes, repository index/ref writes, network, hooks or policy commands.
- Readiness: Lead assessed approved design, root AGENTS.md, architecture and shared contracts sufficient; no applicable PRD or structural refactor. Historical policy3 evidence does not certify this task. Helper readiness is not agent semantic acceptance or execution permission.
- Boundary: helper schemaVersion 1; status ready-for-review/blocked/needs-user-decision, exits 0/1/2. Exact remaining JSON fields agreed with writer before assertions. This is ordinary deterministic Kit testing, not application AI evaluation.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| GD01 | Staged clean content and unstaged whitespace | Commit check | Exact HEAD/index evidence; actual index governs result | happy / edge |
| GD02 | Missing base, invalid ref, detached or unborn HEAD | Operation check | Missing context asks decision; invalid explicit refs block | edge |
| GD03 | Diverged target and explicit outgoing boundary | Push, PR and Merge checks | Push uses supplied boundary; PR uses appropriate merge-base; exact pins retained | alternate |
| GD04 | Staged whitespace, conflicts or canonical local artifacts; unknown Work scope | Check | Known defects block; unknown exact Work ownership asks decision; no repair or policy write | edge |
| GD05 | Unicode, spaces and tab paths; malicious hook/config metadata | Check and byte snapshot | Exact paths preserved, all bytes/index/refs unchanged, no hook/network execution | edge |
| GD06 | Completed source package | Profile/route/resource assertions | Discoverable exact role and conditional source routing | happy |
| GD07 | Existing branch policy, missing optional policy, unavailable new role | Native workflow walkthrough | Agent interprets existing policy; critical ambiguity asks; absence alone does not fail; no automatic policy write | alternate / edge |
| GD08 | Previous release base, target current HEAD or another commit | Release check | Historical range remains inspectable; wrong release target asks decision | edge |
| GD09 | Local promisor fixture with missing baseline blob and local upload-pack sentinel | Check without transport | Partial clone asks before object hydration; no new bytes or marker | security edge |
| GD10 | Final corrected helper source | One fresh fake-home install | Four delivery payloads and receipt hashes equal final source | packaging |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | Exercise public helper rather than private implementation. |
| integration | required | Real Git index, commits and divergence. |
| contract/API | required | JSON schema, exit status, argument context and source routing. |
| E2E | required | Complete local helper invocation; native agent workflow pending. |
| regression | required | Affected helper and package validators at frozen checkpoint. |
| manual | required | Agent policy judgment and actual host availability. |
| component/UI | not applicable | No UI. |
| accessibility | not applicable | No UI. |
| visual regression | not applicable | No rendered artifact. |
| performance/load | not applicable | Bounded local read-only checks; no performance claim. |
| security | required | No Git writes, hooks, network or arbitrary policy execution. |
| compatibility | required | PowerShell 7 and unusual filenames. |
| data migration/rollback | not applicable | No persisted-data migration or installation. |
| resilience/recovery | required | Invalid/missing context and conflict results. |
| exploratory/usability | conditional | Source walkthrough now; eligible host later. |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| GD01 public helper availability | Missing reusable boundary | contract/API | test-first | test-git-delivery.ps1 -RedOnly | 2026-10-10 exit1: GD01 missing public helper before production GO | Frozen complete focused command exit0 | No production refactor; final expanded suite passed after fixture alignment | none | Tester | passing |
| GD01-05 deterministic facts | Wrong scope or mutation | integration | test-after | test-git-delivery.ps1 -HelperOnly | not applicable | Final corrected helper exit0: 33 invocations with full byte preservation | Expanded relevant suite rerun after Release/promisor corrections | Minimal missing-helper Red precedes writer GO; additional field-specific assertions follow frozen schema in parallel and cannot claim retrospective Red | Tester | passing |
| GD06 source contract | Missing distribution or unconditional route | regression | test-after | test-git-delivery.ps1 | not applicable | Copied validator accepted intact/restored source; rejected 12 omissions/routes/profile drifts | Same complete frozen command exit0 | Exact source resources and routes finalized by writer; real copied validator exercises distribution guards | Tester | passing |
| GD07 native policy workflow | Source mistaken for loaded capability | manual | manual-or-environmental | Native.GD07 | not applicable | pending | not applicable | New role not present in active catalog; no real installation authorized. Source walkthrough is narrower substitute | Lead / Reviewer | manual pending |
| GD08 release boundary | Historical release range lost or wrong target approved | integration | test-after | test-git-delivery.ps1 -ReleaseOnly and -HelperOnly | not applicable | Baseline exit1 target-base-mismatch; final -HelperOnly exit0 with exact range and release-target-head-mismatch assertions | Included final expanded 33-helper run | Late Lead/Reviewer case after first implementation; preserve actual failed baseline, do not relabel retrospective TDD Red | Tester | passing |
| GD09 promisor safety | Lazy fetch writes objects or starts transport | security | test-after | test-git-delivery.ps1 -GitSafetyOnly and -HelperOnly | not applicable | Final -HelperOnly exit0: unsupported-partial-clone, incomplete=true, absent marker/object and unchanged bytes | Included final expanded 33-helper run | Independent review identified late transport risk; owned local-only missing-object fixture avoids any external network | Tester | passing |
| GD10 final payload bytes | First installer evidence predates helper correction | compatibility | test-after | test-git-delivery.ps1 -InstallCopyOnly | not applicable | Final isolated actual-source copy command exit0, four asset/receipt SHA256 checks | Final reference/helper hashes rechecked equal after proof | Full installer suite already passed before late helper corrections; one targeted final-byte proof avoids repeating unrelated manager scenarios | Tester | passing |

## Automated test and E2E plan
- Commands: pwsh -NoProfile -File tests/test-git-delivery.ps1; skills/team-core/scripts/stage-verification.ps1 -Action Validate -ProjectRoot . -StageSlug git-delivery; scripts/validate.ps1 and required bilingual checks at complete-pass checkpoint. Existing convention is standalone PowerShell assertion scripts with real unique Git fixtures. No formatter configuration discovered; use shared readability conventions and helper Plan before close.
- Fast public helper checks first; broader package/distribution and independent review after source freeze. Forecast unknown, no paid services. Deferred owner Tester: GD01-06 flush at handoff; native GD07 owner Lead flush on eligible authorized fresh host. No planned check is a pass.

### Execution and observation choices
| Case / test ID | Execution entrypoint and real boundary | Runner / command | Observation mode and rationale | Retained browser / visual checkpoints | Evidence / drill-down / gaps |
| --- | --- | --- | --- | --- | --- |
| GD01-05 | Real Git helper with owned repositories | test-git-delivery.ps1 -HelperOnly | JSON, exact exit and full byte snapshot; cheap deterministic real boundary | not applicable | final exit0, 33 invocations |
| GD06 | Source distribution | test-git-delivery.ps1 and copied validate.ps1 | Exact bounded profile/resource/route observations | not applicable | exit0, intact/restored and 12 negative guards |
| GD07 | Actual native checker workflow | Human script below | Role invocation and policy decision evidence | not applicable | Host unavailable; pending |
| GD08-09 | Corrected public helper in isolated local Git repositories | test-git-delivery.ps1 -HelperOnly or targeted flags | JSON, exact pins and full byte snapshot | not applicable | final exit0, late fixes verified |
| GD10 | Final source installer payload | test-git-delivery.ps1 -InstallCopyOnly | Four source/installed/receipt SHA256 checks | not applicable | final exit0, isolated actual-source copy |

### Manual-to-automated coverage mapping
| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| GD01-05 | Helper invocation: pins, index scope, missing/invalid context, conflicts, whitespace/artifacts, exact paths and no writes | Real Git integration and byte hashes | passing: final 33 invocations exit0 | Windows forbids tab/newline filenames; those conditional Unix branches remain unexecuted; no native semantic claim |
| GD06 | Source role/Skill/route packaging | Profile/resource guards and copied package validation | passing: 12 negative guard checks plus intact/restored exit0 | Native catalog requires separate observation |
| GD07 | Native.GD07: existing policy, absent optional policy, ambiguous target, unavailable role | GD02 missing context plus source walkthrough only | manual pending | Agent judgment and loaded role cannot be automated here; no accepted exception |
| GD08 | Release previous-base to explicit target HEAD; alternate target != HEAD asks | Public helper integration | passing; baseline failure corrected and expanded suite exit0 | Semantic release/version policy stays native/manual |
| GD09 | Local promisor and missing object; no transport marker or hydration | Public helper integration, complete byte manifests | passing; expanded suite exit0 | No external remote used |
| GD10 | One fresh final source copy into fake homes; four delivery asset/receipt hashes | Existing full installer suite already passed | passing; final targeted proof exit0 | No real installation |

## Human verification script
### Preparation
1. Use disposable Git repositories only. Native checks require independently authorized installation and an eligible fresh session; record actual role selector and observed host availability. Do not infer loading from source files.
### Happy path
1. GD01-06: run the focused script and package validation. Expected result: assertions pass, exact pins and staged scope observed, owned fixtures removed.
2. GD07: request a bounded delivery check with existing branch/release rules and clear target. Expected result: agent interprets relevant existing documents and reports operation-specific semantic judgment with actual evidence; helper ready-for-review alone is not final pass.
3. GD08-09: run -HelperOnly or the targeted -ReleaseOnly/-GitSafetyOnly modes. Expected result: the previous release base remains distinct from target HEAD; an alternate target asks decision; a promisor repository stops before local transport or object hydration with unchanged bytes.
4. GD10: run -InstallCopyOnly after final helper freeze. Expected result: four delivery assets and receipt hashes match final source in disposable fake homes; fixtures removed, no actual installation.
### Recommended edge cases
1. GD01-05: run scripted missing/invalid refs, diverged branches, unstaged whitespace, staged artifacts/conflicts and unusual filenames. Expected result: exact structured decisions and byte preservation.
2. GD07: omit docs/delivery-policy.md while existing rules suffice; then provide materially ambiguous target/branch policy. Expected result: absence alone does not fail; ambiguity asks user, optional policy proposal requires approval, no policy written automatically.
3. GD07: attempt role selection on a host lacking the new role. Expected result: disclose missing capability and request scoped direction; no silent fallback or runtime availability claim.
### Result
- Observations and cleanup: scripted helper/package/fake-home checks passed with owned fixtures removed; native policy workflow and user acceptance remain pending. Keep packet active until explicit authoritative manual outcome.

## Verification and invocation record
- Tester handle /root/delivery_tests; Lead selected team-tester. Resolved model identity unknown. No children spawned. Own only test script and canonical packet; writer owns production.
- Preimplementation packet Validate exit0; minimal Red command pwsh -NoProfile -File tests/test-git-delivery.ps1 -RedOnly exit1, exact missing-helper assertion. Frozen schema agreed: snapshot head/branch/unborn/indexIdentity/baseRef/baseCommit/targetBranch/targetCommit/mergeBase; changes staged/unstaged/untracked/outgoing/intermediateCommits; checks conflicts/whitespace/generatedArtifacts/freshness; inspectionRequired/findings/decisionRequired/limits.
- Capabilities used: testing-engineering for coverage/TDD; workspace-hygiene and team-core references for placement, acceptance, comments/readability; local PowerShell, Git and patch tools for isolated tests; collaboration messaging for interface/ownership coordination. No connector or external service.
- Actual Lead-created roster: /root/delivery_writer selected team-backend-engineer, nine production files frozen for first complete pass; /root/delivery_tests selected team-tester, tests and packet; /root/delivery_docs selected team-docs-maintainer, public pairs/folder guide/architecture; /root/delivery_review selected team-reviewer, independent review and source forward-use exercises pending. Resolved models unknown; source profiles do not establish runtime identities. No documented close operation is available and no slot release is claimed.
- Formatter Plan for exact owned test file returned needs-selection with no configPaths; no formatter/configuration discovered or installed. Shared readability self-check applies. AST parsing passed; no test lines exceed 120 characters. Each case includes scenario/expected-result explanation; helper contracts document arguments, return/failure and fixture-only side effects.
- Lead attempted optional official Skill creator quick_validate.py after the new Skill existed: exit1 ModuleNotFoundError yaml. No dependency installed and no retry planned. Package/frontmatter/resource/link guards and semantic source review are narrower available checks, not a creator-validator pass.
- Frozen complete command: pwsh -NoProfile -File tests/test-git-delivery.ps1 exit0, "Git delivery checks passed: 30 read-only invocations." Each invocation checked full file SHA256 manifests including worktree, index, refs, logs, objects and config. Exact-owned-root cleanup completed. Covered leak-then-delete vs cleanup-only outgoing commits, staged-vs-unstaged whitespace, Unicode/space/dash names, malformed/missing boundaries, divergence, initial/detached HEAD, conflicts, canonical artifact vs formal evidence, unknown Work ownership, hook/policy/configured filter/textconv/external-diff/fsmonitor sentinels, Install preview and >1MiB incomplete source snapshot. Twelve copied-validator negative checks covered four missing assets, five unlinked routes and three model/effort/sandbox drifts; intact/restored package accepted.
- Frozen SHA256 identities: helper 4E3D232DCF3FC48802A4A36A93D500CFC886EAAECE46BF89068B7F78F7D843EA; profile 465B4EC34FC117CB8AC2A7DD9C07B6274AE9C0832A4187870A7504E857D41DB5; Skill 5E1A67027423C2BD0FFB54B5B81FEBDB02E0E3728CC854B3559EAFFD7E245AFB; reference BCAB435351E44355B8423584C70A1EFAB9629281803E83CEC6E40C33279B2E1F; test 48ADBD166926A27925032DA8A2FAA7D11A5EDC179D0A029BE1D1CCBED31945AF. Helper hash rechecked unchanged after execution.
- Execution history: initial sandbox run could not initialize fixture Git config; same scoped command retried with reviewed permissions. Two developmental runs then stopped at test-context clarifications (PR requires explicit base and target; generic Work ownership asks decision), corrected before the complete frozen run. No product repair or blanket full-suite reuse claim. Final temporary fixtures are disjoint from fake-home installation fixtures.
- Package provenance: authoritative VERSION remains 1.0.7; new work is Unreleased. Formatter Plan reports preexisting hardcoded 1.0.6 metadata; Lead confirmed this is unrelated baseline provenance drift, not this task's version change. Fake-home receipt version 1.0.7 identifies a version only; source digest identifies actual package bytes.
- Full fake-home installer command pwsh -NoProfile -File tests/test-install-user.ps1 passed exit0 and explicitly reported isolated directory removed. Dynamic whole-package file/Skill discovery, source/installed bytes, complete receipt entry/hash map, WhatIf no changes, managed update and conflict/backup preservation all passed. PackageDigest 370222263caf9897c452f8e6c1c42acac4151d9ccf11fb4979e73aeb7e50223f, kitVersion 1.0.7. This evidence predates late Release/promisor helper fixes and is retained as scoped installation-manager evidence; GD10 will establish final corrected payload bytes.
- Late finding GD08 observed -ReleaseOnly exit1: valid historical base and current target HEAD yielded needs-user-decision target-base-mismatch and empty outgoing range. Full fixture bytes remained unchanged. Lead/Reviewer directed bounded correction and local-promisor safety GD09; final source-dependent helper evidence will be refreshed after freeze. Existing first-pass 30-case result is historical provenance, not acceptance of the corrected source or newly added cases.
- Final corrected helper command pwsh -NoProfile -File tests/test-git-delivery.ps1 -HelperOnly passed exit0 with 33 read-only invocations. GD08 accepts prior-release base to explicit target HEAD and returns exact release-target-head-mismatch for another target. GD09 returns unsupported-partial-clone with limits.incomplete=true before local transport/object hydration; missing blob and sentinel remain absent. Every fixture byte manifest stayed equal; owned cleanup completed. Host PowerShell 7.6.5, Git 2.55.0.windows.3. Helper SHA256 before/after BC658C57A404D952B27A6A9F06441AB46B2488DE62FD8E7288C56F313CF2708D; final reference 6067AB1C6FB663340350802479E5991D7CD7ADA26FCAA1FF4A3C5E1CEC87214D.
- Final GD10 command pwsh -NoProfile -File tests/test-git-delivery.ps1 -InstallCopyOnly passed exit0. Actual-source controlled copy includes agents, skills, scripts, config, VERSION, changelog pair and validator-linked formatter guide/packet. It excludes unrelated local work/runtime trees; no file contents or validator rules were invented or relaxed. One fresh fake-home installation proved all four delivery source/installed/receipt hashes equal; packageDigest c1ca6a4d94d6cd9b89656969994d4323dbb85e76416cde6494fb8eb40d8a44c6. Exact owned fixture cleanup completed. Final test SHA256 A42E31F14BE68B238419193AF8035762F56EEE79C7FA2DA6AD54A45EA8995E99; AST clean and no lines over 120 characters. The GD10 source-copy setup changed after the final helper run began; helper assertions/fixtures were unchanged, so that exact relevant evidence is reused without repeating 33 cases.
- Unrelated-source limitation: direct-root GD10 failed before installation because _work/github-promotion/workflow-source/docs/first-task.md linked to absent ../README.md. This is another owner's concurrent local work outside this task; no repair/delete was made. Lead approved the isolated-source substitute. Current real-root validation cannot be inferred from the copied-package result.
- Reuse: first-pass 12 negative package guards remain valid for their unchanged observations (required four resource identities, five link targets, model/effort/sandbox values and validator SHA256 07D3305883BDB63D8F809074FFDCE5F1A0D904D9F98D8220C8F13BAFE2AF5446). Helper/reference prose/implementation changed, but those selected discovery assertions did not; final copied installer ran the unchanged validator against corrected source. The full fake-home manager suite is historical scoped manager evidence; GD10 proves final asset bytes. Native/manual judgment remains pending.
- Final independent Reviewer handoff: no material findings; partial-clone safety, historical Release base and explicit prohibition of unguarded Git-object-read fallback resolved against final frozen helper/reference identities. Forward-use observations are source exercises, not actual new-role/native acceptance.
- Final Docs handoff: README.md, README.zh-CN.md, CHANGELOG.md, CHANGELOG.zh-CN.md, FOLDER_STRUCTURE.md and docs/architecture.md complete and frozen. scripts/validate-docs.ps1 -ProjectRoot . exit0; tests/test-bilingual-docs.ps1 exit0; both complete document pairs semantically reviewed. Matching three-item Unreleased sections; VERSION 1.0.7 and historical release records untouched. These results are Docs-reported evidence, not a duplicate Tester execution.
- Final actual roster: /root/delivery_writer, selected team-backend-engineer, production/helper/profile/Skill/routes/reference clarification complete and frozen; /root/delivery_tests, selected team-tester, assigned test/packet complete and frozen after final Validate; /root/delivery_docs, selected team-docs-maintainer, public pairs/navigation complete and frozen; /root/delivery_review, selected team-reviewer, independent review complete with no remaining material findings. Resolved runtime roles/models remain unknown/not independently reported. No Tester-created children or active owned background processes. No documented close operation and no capacity-release claim.
- Close: final packet Validate exit0 with Final manual status manual pending; packet remains active. Lead retains final documentation-governance refresh and Git hygiene. No production/test changes or additional broad reruns are required by this Tester handoff; any newly changed relevant source reopens affected evidence.
