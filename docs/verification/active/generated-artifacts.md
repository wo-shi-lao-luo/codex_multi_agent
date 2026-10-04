# Generated artifact Git protection

Packet schema version: 2
Stage slug: generated-artifacts
Contract status: active
Final manual status: manual pending
Final manual evidence:

## Stage context
Outcome: approved follow-up to uncommitted0.10.1 treats all <DocsRoot>/governance/reviews/ plus exact documentation.json and doc-index.md as a local runtime bundle; disk bytes retained, ordinary staging excludes it. Formal user governance guides, stage packets, Blueprint, specs, PRDs, references and user archives remain Git-visible. Earlier results below are preserved as baseline observations, not proof of the new scope.
User approval: Lead records explicit approval of narrow default Git protection and index-only removal of existing kit-owned current/historical reviews and exact generated metadata/index, with local files and Git history retained. Tester must not change the actual repository index, install, push or use network.
Work contract: backend owns helper and runtime production integration; Tester owns tests/test-generated-artifacts.ps1, minimal caller-test additions and this packet; Docs Maintainer owns release/public/canonical documentation; Lead owns integration and reconciliation; independent Reviewer reviews the completed production boundary. All writers preserve concurrent edits. No production rewrite by Tester.
Architecture: docs/architecture.md existing script module layout is adequate; no structural refactor, root AGENTS change or OpenSpec adoption. Lead/backend accepted and implemented helper API: generated-artifacts.ps1 -Action Protect or Check -ProjectRoot -DocsRoot docs -Profile Documentation or OpenSpec or Work -WorkPath exact subtree; schemaVersion1 receipts and ARTIFACTS conflict errors are the shared interface.
Documentation purpose: this packet is the sole test-result and manual-acceptance authority, not a public setup guide. Source identity and actual invocation metadata are recorded after final source freeze. Tester handle /root/artifact_git_tester; actual loaded role/model/effort unknown unless Lead reports tool evidence. No child agents spawned.
Lead-reported existing repo cleanup: 36 historical archive files removed from index, now zero tracked; all 36 local byte hashes identical and ignore confirmed. Explicitly approved index-only untracking; no history rewrite, commit or push. Tester has not independently verified that cleanup.
Data/cleanup: unique temporary Git repositories, local fixture text only; no secrets, real installations or external CLI downloads. Cleanup verifies the resolved generated root stays inside the system temp parent before deletion.

## Use-case map
| Case | Preconditions | Action | Expected result | Path |
| --- | --- | --- | --- | --- |
| CASE-GA-01 | real disposable Git repository | Protect then git add --all | exact local output omitted; durable/user evidence staged | happy lifecycle |
| CASE-GA-02 | existing BOM/CRLF/user negations | repeat Protect | original bytes preserved; second call unchanged | compatibility |
| CASE-GA-03 | nested project/custom docs with spaces | Protect then stage | exact nested local bundle omitted; user guide/sibling records stage | boundary |
| CASE-GA-04 | staged local artifact | Protect and Check | tracked risk reported; index unchanged | failure |
| CASE-GA-05 | no repository | Protect and Check | no adoption or ignore file | boundary |
| CASE-GA-06 | task work subtree | Protect and unsafe path | exact scope only; traversal rejected | security |
| CASE-GA-07 | child ignore negation | Protect and Check | conflict exposed; user rules untouched | conflict |
| CASE-GA-08 | pending recovery output | Check | ignore/index/recovery bytes retained | recovery |
| CASE-GA-09 | runtime callers, linked worktree and junction | caller lifecycle and Doctor/Scan/Validate | bundle protected before writes; retained hashes/read-only unchanged; junction rejected | integration |
| CASE-GA-10 | live Codex request | workflow follows default rule | exact owned local files excluded; durable records retained | environmental |
| CASE-GA-11 | isolated complete package plus omitted helper/entrypoint | package validation and existing negative suite | intact package passes; missing members rejected without validator null crash | release regression |
| CASE-GA-12 | real initialized scoped review | git add --all | entire local marker/index/current+archive reviews omitted; formal user guidance retained | approved follow-up |
| CASE-GA-13 | fresh local clone without ignored runtime bundle | Scan then initialize and scoped review | unadopted discovery; recreated local bundle validates without stale references | reconstruction |
| CASE-GA-14 | current review/marker/index tracked or explicitly included | Check and Protect | local-bundle risk reported; index/user rules unchanged; no automatic untracking | conflict |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | Real Git boundary is cheapest adequate observation; no production seam. |
| integration | required | Helper plus real Git index and runtime caller boundaries. |
| contract/API | required | Public PowerShell input/output and rejection contract. |
| E2E | required | Complete local script-to-Git staging lifecycle; live Codex remains pending. |
| regression | required | Preservation of durable records, readonly calls and existing suites. |
| manual | required | Human acceptance of actual Codex/default workflow. |
| component/UI | not applicable | No UI implementation. |
| accessibility | not applicable | No UI change. |
| visual regression | not applicable | No visible layout. |
| performance/load | not applicable | Bounded local filesystem/Git operations. |
| security | required | Reject escape/symlink paths and preserve user rules/index. |
| compatibility | required | Existing encoding, custom docs, spaces, nested repo/worktree. |
| data migration/rollback | required | Existing tracked artifacts never auto-untracked. |
| resilience/recovery | required | Pending state stays local and retained; nonrepo safe. |
| exploratory/usability | conditional | Live workflow reporting checked by maintainer. |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CASE-GA-01 default adoption Git boundary | accidental stage or user evidence loss | integration | test-first | tests/test-generated-artifacts.ps1 -RedOnly | pre-production exit1: documentation default protection missing; generated archive was staged | final helper957E snapshot: same -RedOnly command exit0 | final whole helper suite exit0; no structural refactor | none | Tester | passing |
| CASE-GA-02..08 helper boundaries | encoding/index/ownership loss | integration | test-after | tests/test-generated-artifacts.ps1 | not claimed | follow-up40A1 helper and D98F test full suite exit0 | complete fresh suite after follow-up classification delta exit0; no structural refactor | Initial helper lacked a callable pre-implementation boundary; follow-up changes have direct CASE12-14 Red/Green | Tester | passing |
| CASE-GA-09 runtime and worktree | late protection or readonly mutation | regression | test-after | tests/test-generated-artifacts.ps1 CASE09a-c; tests/test-openspec.ps1 CASE09d | not claimed | helper/doc/OpenSpec suites on follow-up40A1 helper and8D22 doc exit0 | fresh follow-up source runs exit0; no structural refactor | Initial API needed a callable draft; follow-up bundle scope has direct CASE12-14 Red/Green | Tester | passing |
| CASE-GA-06d nested ancestor Work rule reuse | falsely rejects already-owned nonempty work | compatibility | test-first | tests/test-generated-artifacts.ps1 -NestedWorkOnly | helper8987 exit1 ARTIFACTS uncertain ownership before bounded bug correction | helper957E exit0 same targeted command | final whole helper suite exit0; one-line path correction, no structural refactor | Post-implementation bug reproduction, not retrospective initial-stage Red | Tester | passing |
| CASE-GA-10 actual Codex flow | policy not followed in runtime | E2E | manual-or-environmental | live Codex workflow acceptance | not applicable | manual pending | not applicable | Loaded Codex workflow is outside isolated PowerShell fixture boundary | maintainer | manual pending |
| CASE-GA-11 missing-entrypoint regression | package negative suite aborts on null route read | regression | test-first | tests/test-validate.ps1 | validator5E15 exit1 null .Contains; diagnostic stack points validator182 and existing test108 before bounded guard correction | validator5166 entire negative suite exit0; copied fixture removed | full suite after existence/empty short-circuit guard fix exit0; no structural refactor | Post-implementation regression Red, not retrospective initial-stage evidence | Tester | passing |
| CASE-GA-12 entire local governance runtime bundle | current receipts leak into version control | integration | test-first | tests/test-generated-artifacts.ps1 -BundleRedOnly | helper957E before follow-up implementation exit1: marker/index/current json+md staged | same command on40A1/8D22/D98F exit0 | follow-up full helper suite exit0; no structural refactor | none | Tester | passing |
| CASE-GA-13 fresh reconstruction | ignored absent bundle leaves stale references | resilience/recovery | test-first | tests/test-generated-artifacts.ps1 -BundleCloneOnly | helper957E before follow-up implementation exit1: documentation.json leaked into fresh local clone | same command on40A1/8D22/D98F exit0; fresh Scan/reinitialization/scoped Validate executed | follow-up full helper suite exit0; no structural refactor | none | Tester | passing |
| CASE-GA-14 tracked/include expanded scope | user policy/index silently overwritten | security | test-first | tests/test-generated-artifacts.ps1 -BundleConflictOnly | helper957E before follow-up implementation exit1: tracked current review risk omitted | same command on40A1/D98F exit0; all three staged and explicit-include rows executed | follow-up full helper suite exit0; no structural refactor | none | Tester | passing |

## Automated test and E2E plan
Runner: pwsh -NoProfile -File tests/test-generated-artifacts.ps1; initial Red uses -RedOnly. Real Git fixture boundary includes helper invocation, creating local and durable files, git add --all and cached-name assertions. Summaries are read first; unexpected failure is inspected with exact assertion evidence. No browser checkpoints apply.
Tier plan: initial practical Red before runtime writes; full helper scenarios after coherent source freeze; affected documentation/OpenSpec/validate suites, then Lead-owned release full suite. No reused Green claims; forecast unknown, no user hard budget supplied. Source SHA256 identities for helper, callers, tests and package validator frozen before final runs; changed identity reopens affected results.

| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / reasons | Status and evidence | Gap / exception |
| --- | --- | --- | --- | --- |
| CASE-GA-01..03 | same IDs: real helper-to-staging lifecycle; ignore/index names and durable presence | integration bytes/encoding | final full suite passed; initial caller actual Red/Green | no exception |
| CASE-GA-04..08 | same IDs: index risk/deletion bytes; noGit/missing executable/broken metadata; empty/uncertain nonempty Work; root and nested ancestor exact rule reuse; child conflict/recovery checkpoints | contract/security/read-only hashes | final full suite passed; nested reuse actual Red/Green | no exception |
| CASE-GA-09 | caller fixture initialize/record/enable/protect then real staging; Doctor/Scan/Validate hash checks; linked worktree staging; junction no-write rejection | doc real runtime; OpenSpec adapter plus controlled CLI double | final helper, doc and OpenSpec scripts passed | upstream installed OpenSpec and full live workflow not established |
| CASE-GA-10 | live Codex ownership/default-protection decisions, full staging checkpoint and retained evidence | source walkthrough plus local script evidence | manual pending | no live E2E pass or accepted exception claimed |
| CASE-GA-11 | intact installable payload and omitted helper/entrypoint reject/restore checkpoints | package negative suite; no browser required | final native validation and full negative suite passed; actual Red/Green retained | no exception |
| CASE-GA-12 | real Initialize/RecordReview/staging; all four current-bundle path names absent; user governance guide/PRD/Blueprint/formal packet/spec names present | real Git/script integration and retained file hashes | actual follow-up Red/Green plus full-suite passing | live Codex/human acceptance pending |
| CASE-GA-13 | local no-network clone of fixture with durable docs; bundle absent; Scan unadopted, Initialize/RecordReview/Validate then staging | reconstruction/read-only integration | actual follow-up Red/Green plus full-suite passing | no exception |
| CASE-GA-14 | staged current review/marker/index and explicit includes; Check violations, Protect rejection, unchanged index and user policy hashes | security/contract integration | actual follow-up Red/Green plus full-suite passing | no automatic untracking |

## Human verification script
### Preparation
1. Use a disposable Git project and the current source revision; retain no secrets. Record exact kit-owned artifact paths and user originals before starting.
### Happy path
1. CASE-GA-12: adopt docs and record a current scoped review, then git add --all.
   Expected result: entire reviews/ subtree and exact marker/index remain on disk but absent from staging; user governance guide, PRD, Blueprint/formal packet/spec remain stageable.
2. CASE-GA-13: make a local clone of that fixture with no runtime bundle, run Scan, initialize and record/validate a new scoped review.
   Expected result: starts unadopted, recreates local state without stale missing references and keeps all recreated bundle paths local.
3. CASE-GA-01..03: adopt docs, write a current review twice, create user governance guide/stage/PRD/Blueprint/reference/spec evidence, then git add --all.
   Expected result: entire runtime reviews tree and exact marker/index remain local; all formal/user evidence remains staged; custom nested docs behave identically and user rule bytes are retained.
4. CASE-GA-10: ask a live Codex workflow to produce task-local rendered or intermediate output under the explicitly owned subtree.
   Expected result: exact narrow protection occurs before output; user sibling work and durable records remain Git-visible; reported protection names actual paths.
### Recommended edge cases
1. CASE-GA-14: pre-stage current review/marker/index or explicitly include them in a user ignore rule; run Check then Protect.
   Expected result: reports/rejects expanded local bundle conflicts without index writes, disk removal or automatic untracking; user policy bytes retained.
2. CASE-GA-04..08: stage a local artifact before protection, introduce a child negation, use noGit and unsafe paths, then run Check with pending recovery evidence.
   Expected result: tracked/conflict risks exposed without index writes or automatic untracking; no Git init; unsafe paths rejected; pending bytes retained.
3. CASE-GA-05b..06d: remove Git from the test process PATH (restore after observation), use a broken .git pointer, and try a nonempty work subtree first without protection and then with an existing exact root or ancestor rule in a nested project.
   Expected result: missing/broken Git fails before mutation; uncertain ownership requests a decision; effective exact rules are reused with byte-identical ancestor policy and no nested override.
4. CASE-GA-09: use linked worktree and readonly caller actions with existing files.
   Expected result: project-root-relative Git protection is exact; readonly actions leave all project/index/ignore bytes unchanged.
5. CASE-GA-11: validate a copied package, remove helper or a documentation entrypoint, then restore exact source bytes and validate again.
   Expected result: intact/restored payload passes; omission produces a controlled rejected result, without null dereference aborting the regression runner.
### Result
Observations: manual pending. Remove only verified owned disposable fixtures; retain the canonical packet and all user originals.

## Verification record
Approved follow-up planning before writer release: continue the existing active packet, preserve previous uncommitted changes, Tester owns only assigned tests/packet, Backend owns production classification and protection, Docs Maintainer owns public/canonical prose, Lead owns integration and actual index operations. Coverage delta is CASE12-14 plus reclassified CASE01/03/09 current-bundle assertions. Integration/contract/E2E-script/security/compatibility/recovery remain required; browser/UI/load not applicable. Live Codex/manual pending is unchanged. Lowest-cost entrypoint is real PowerShell caller plus disposable Git staging and no-network local clone. Pre-production -BundleRedOnly observes all current bundle paths through actual Initialize/RecordReview; final Green waits coherent backend freeze. All fixture commits/clones/index operations stay in the unique owned temp root; none in the actual repository or home. Changed assertions invalidate affected old Green, whose original scope/results remain historical evidence only. No production edits by Tester.
Follow-up actual Red evidence before production: helper957E -BundleRedOnly exit1 exposed all four actual caller-produced current bundle paths in Git staging; -BundleConflictOnly exit1 omitted staged current review risk; -BundleCloneOnly exit1 exposed documentation.json in the fresh no-network local clone. All were behavior assertions after successful real operations, not syntax/dependency failures. Each invocation cleaned its unique temp root. Existing packet native validation passed before writer release; these scope-specific Reds were sent to Lead. No final Green inferred from prior scope.
Follow-up actual final Green: targeted -BundleRedOnly/-BundleCloneOnly/-BundleConflictOnly each exited0 on helper40A1/documentation8D22/testD98F. The complete helper suite then passed CASE01..09,12..14, including custom nested docs/ancestor policy, linked worktree, retained local bundle hashes, formal guide/Blueprint/stage/spec staging, noGit/path/conflict preservation and fresh local clone reconstruction. Full documentation, OpenSpec and validate suites also executed and passed on this follow-up source snapshot. Documentation and validator reported isolated cleanup; helper/OpenSpec finally cleanup completed without error. No production failure occurred in follow-up verification; prior failures below belong to the earlier narrower boundary. Live Codex, actual upstream OpenSpec and human acceptance remain unobserved.

### Prior narrower boundary evidence
Planning prepared before backend production release. Packet Validate exited0. Genuine behavioral Red: pwsh -NoProfile -File tests/test-generated-artifacts.ps1 -RedOnly exited1 before backend production release, with CASE-GA-01: documentation default protection missing; generated archive was staged. This initialized current documentation runtime, wrote fixture archive, staged all files and observed the forbidden cached path. Initial harness recursion and invalid Git NUL configuration failures were corrected before this Red and do not count as behavior evidence. Every owned temp fixture was cleaned. Per-case comments explain scenarios and supported outcomes; final assertion/comment self-check completed below. No real repository index operations by Tester.

Observed implementation checks: first helper and OpenSpec attempts failed because a fresh missing ignore file yielded a null byte array and was mislabeled non-UTF8. Initial helper AFB6 snapshot changed to announced12DDE4 during that batch, so the batch cannot establish coherent final evidence. Backend fixed the empty-array initialization (8987 snapshot); helper suite including ancestor explicit include policy and later missing/brokenGit/nonemptyWork additions passed. Reviewer/Backend found a distinct nested Work source-root bug; Tester reproduced -NestedWorkOnly exit1 on8987 before the one-line source-root correction. Both -NestedWorkOnly and original -RedOnly commands exit0 on final957E helper; final complete helper suite also exited0. These distinct findings are retained; no pass was inferred from failed attempts and no production code was rewritten by Tester.

Final runtime batch: helper suite, documentation suite and OpenSpec suite each executed and passed exit0 on final957E helper. Earlier8987 passes were superseded by purposeful final-source reruns, so no reused Green claim is needed. Controlled local CLI double only; real upstream CLI exercised False. Local recovery hashes, Doctor failure nonmutation, staging exclusions and native durable spec/tasks/verification index/stage packet assertions ran. Git exclude-permission warnings were nonfatal; user Git configuration was not changed. Documentation fixture cleanup was explicitly reported; helper/OpenSpec owned cleanup completed in finally blocks. These observed script passes are not live Codex E2E or user acceptance.

Final package batch: native scripts/validate.ps1 passed on final5166 validator. Existing tests/test-validate.ps1 initially failed on missing team-doc-check entrypoint because new artifact-route validation dereferenced null at182; one diagnostic rerun captured the stack to existing test108. Backend added bounded existence/empty short-circuit guards to the two new loops; the entire unchanged negative suite then passed exit0 and reported copied-fixture cleanup. No test catches or weakens incidental exceptions to hide this bug.

Lead-reported separate adjacent/release checks: test-project-rules.ps1, test-stage-verification.ps1, test-project-blueprint.ps1, test-agent-concurrency.ps1, test-feedback-runtime.ps1 and test-deployment.ps1 exited0 with owned fixture cleanup. validate-docs.ps1 and test-bilingual-docs.ps1 passed; Lead and Docs Maintainer semantically reviewed the complete public pairs. test-install-user.ps1 passed against fake homes with VERSION0.10.1 and payload digest d5c9b3af5e481f50d34327dff4189dad5ff7be73745fe06497f8a2c7f6514466. The later validator-only guard fix did not alter installed Skill/agent payload; this is prior executed installation evidence, not a fresh installation after that script edit. Tester did not duplicate or independently authenticate these Lead runs. Lead also reports all three repository-root Protect calls succeeded and Documentation Check clean; clean audits index/include conflicts, it does not itself certify effective ignore protection. No Tester index write occurred.

### Prior narrower boundary input identities
PowerShell7.6.5, Git2.55.0.windows.3, Node25.2.1; local Windows fixtures, no external services. SHA256 values below were read before their final batches and checked again afterward; no full run is reused as proof for changed assertions.

| Source/test | SHA256 |
| --- | --- |
| skills/team-core/scripts/generated-artifacts.ps1 | 957E1E1615E9C3E3EBA10CC217EF42B5F8355C4990FEE771EF41D71FE963C522 |
| skills/team-core/scripts/documentation.ps1 | 50E07FE21508B8E98E70804CBB9D36A554E595E987AE8A93F84A9E27279F2A91 |
| skills/team-core/scripts/openspec-adapter.ps1 | 80660B9711121645DCD3349AC6EC3AB20DACF1C03EA8AC7FAE24ACB054F1F40B |
| skills/team-core/scripts/openspec-common.ps1 | 9E8ED47697C3490AA3B70697B4CCC216A7CBE50D13933BA5F92231ADDA55DD38 |
| skills/team-core/scripts/spec-traceability.ps1 | 64DC8F10AE6F64352B3363AAF99A45C7ADD900300691BB3D3A1984C760815D77 |
| scripts/validate.ps1 | 5166D375C9AF98473AD48AE76D56C7C2A882A6DEBBE99E0CA03B00C7650FC1A7 |
| tests/test-generated-artifacts.ps1 | E5CA8B55292834C367CF4FE88A42AE8F87FF6847A4520F7B4147AE38FC2680FB |
| tests/test-openspec.ps1 | C2476FE50193AB2DAB9F43A0A508EFE68ACFF719980A913D7434B0060E9A5210 |
| tests/test-documentation.ps1 | C62727D219214E68EA064371E61F254AB4DB9BB0D18531746525FC6C6473812E |
| tests/test-validate.ps1 | 66784BD18CD326888A7275D6E7D23D82EAB019616A25CE1090B711440FA92B82 |

Comment self-check: inspected the complete new helper test and owned OpenSpec/validator test diff, public fixture helpers, cleanup and all case comments. Every new independent scenario explains conditions and an assertion-supported expected outcome. CASE08 was corrected after Reviewer noted that untracked recovery output is not itself a Check violation; its comment now claims byte preservation only. Existing obvious Assert utility is unchanged in responsibility; no production interfaces were authored by Tester. No current test explanation promises an unasserted reporting outcome. Final whitespace/parser checks and packet validation are retained at handoff.

Actual invocation ledger, as reported by Lead: /root/artifact_git_runtime selected team-backend-engineer, helper/callers/validator owner, complete; /root/artifact_git_docs selected team-docs-maintainer, original selector retained across follow-ups, public/canonical docs owner, complete; /root/artifact_git_tester selected team-tester, tests and packet owner, complete; /root/artifact_git_reviewer selected team-reviewer, independent review, complete. The four exact role names were available in the active catalog. Extra concurrency beyond three was for independent frozen-input tests/documentation and read-only review with nonoverlapping ownership and Lead integration; it is not a target thread count. Loaded role/model/effort unknown, not inferred from source profiles or task handles. No child agents were spawned by Tester. Reviewer completed the first pass, was reopened for the validator guards, and Lead reports no remaining writer/review findings at closure. No creation retries or role substitutions reported.

Final owned handoff checks: all recorded source identities match current file hashes; native stage packet Validate passed with finalManualStatus manual pending; owned diff whitespace and PowerShell syntax checks passed. Formal stage evidence is retained as current durable documentation, not automatically archived or ignored.

Prior close boundary: narrower-scope automated local script/Git/package checks complete; live Codex orchestration, actual installed upstream OpenSpec and final human acceptance remained unobserved. No browser/UI checkpoint applied. The packet remained active with manual pending; no exception or archival approval was inferred. Skills used: testing-engineering for behavior/TDD/coverage; team-core for stage/role/comment/handoff contracts; workspace-hygiene for assigned-file placement and safe fixture lifecycle. Tools used: local PowerShell/Git/Node execution, apply_patch edits and team messages; no connector, network service, push or real installation by Tester.

### Approved follow-up source identities and closure
Follow-up runtime/test batches used the following changed source identities, read before execution and confirmed afterward. All other source/test identities in the prior table remained unchanged, including adapter80660B, validator5166, OpenSpec testC2476, documentation testC62727 and validator test66784. The four affected suites were executed again; prior12-suite results above are not counted as fresh follow-up passes.

| Changed source/test | Follow-up SHA256 |
| --- | --- |
| skills/team-core/scripts/generated-artifacts.ps1 | 40A1DC26F5F7C1E1A47927B53E1D0D06C4F00C70FA5D9838CC581724BA7B2AB3 |
| skills/team-core/scripts/documentation.ps1 | 8D2285A99F48E1B0F4AA943AE6D6EB5BCCFF4F53D333A23993D199F6EF76558B |
| tests/test-generated-artifacts.ps1 | D98FEF0812D0C0E77F191F6E8BF3E8FBD17CD861F74BDE552E5B223501B41CFE |

Follow-up comment/assertion self-check: all CASE12-14 standalone selectors and full-suite scenarios describe inputs and supported outcomes. Scoped review fixture helper documents authored input responsibilities; clone helper documents the real no-network source/clone/reconstruction boundary; parameterized tracked/include rows name each member and assert corresponding violation, rejected Protect, unchanged index/disk/policy as applicable. Reclassified CASE01/03/09 comments and assertions agree that current runtime bundle is local while user governance guide and formal documents stage. Expected disk retention has byte-hash assertions. No production code edited by Tester; no test or scenario silently removed. Existing OpenSpec assertions remain appropriate and ran fresh unchanged.

Follow-up workflow reconciliation: the original four named roles/handles were reused with their selectors unchanged and loaded model/effort still unknown. Tester prepared valid planning packet and all three real Reds before Backend release; Lead paused concurrent input changes for readiness publication, then reported RecordReview/Validate ready and released implementation. Backend froze the bounded classifier/probes/comment delta, Tester executed three targeted Green checks and four fresh affected suites with owned temporary fixtures. Documentation public-pair/fake-home installation gates and independent fresh review are Lead-owned; their follow-up final outcomes are pending Lead evidence at Tester handoff. No extra agent spawned by Tester and no runtime/index/home/push/install/network write by Tester.

Follow-up final manual status remains manual pending. Script/Git lifecycle evidence is passing; live Codex orchestration and real upstream CLI are not claimed. Retain this active durable packet; no automatic archive, untracking or manual acceptance inference.

### Lead follow-up integration and release gates

Fresh `tests/test-install-user.ps1` passed exit0 using only unique fake homes, with kitVersion0.10.1 and payload digest `983848346d1f84cedf197f0b2288bfb1643fb85640d7d8f866f606b25ae6f727`; its temporary installation directory was removed. Fresh `scripts/validate-docs.ps1 -ProjectRoot .` and `tests/test-bilingual-docs.ps1` passed exit0; bilingual fixtures were removed. Nine relevant public/Skill/reference input hashes captured before these gates remained byte-identical afterward. Lead read all four complete public documents and reviewed the final delta; Docs Maintainer also read the complete pairs and checked semantic equivalence and natural Chinese. No historical release record was shortened or changed. Package validation passed within the fake-home test; no actual Codex installation occurred.

Independent Reviewer inspected frozen helper40A1/documentation8D22/testD98F, exact root ignore policy, actual index, final canonical/Skill/public delta and follow-up packet. No confirmed material defect remains. Two boundaries remain explicit: native document discovery already excludes the whole governance directory, so preserving formal neighbors in Git does not add them to the supervised inventory; mismatched physical/caller DocsRoot casing on Windows was not verified. This scoped change does not claim expanded discovery or universal compatibility.

Lead captured the exact24 currently indexed generated-bundle files and removed only their index entries; every local byte hash matched immediately after untracking. All58 preexisting current/archive review files still retain their original SHA256. Native authored review publication intentionally updates its owned generated-artifacts scope, marker and index while preserving prior scope history locally. Root Documentation Protect is idempotent with rulesAdded empty, Check clean, and no indexed governance bundle. Formal neighboring governance policy and the active verification packet are not ignored. Ignore rules do not rewrite Git history, prevent forced staging, or delete local files.

Actual current-pass agent roster: `/root/artifact_git_runtime` selected `team-backend-engineer`, bounded runtime change, complete; `/root/artifact_git_docs` selected `team-docs-maintainer`, canonical/public/Skill documentation, complete; `/root/artifact_git_tester` selected `team-tester`, coverage/Red/Green/packet, complete; `/root/artifact_git_reviewer` selected `team-reviewer`, independent read-only review, complete. All four original handles were reused; no new role substitution or child creation occurred. Loaded model/effort remain unconfirmed. Main reconciles the owned staged ignore/packet snapshots and retains all prior unrelated edits. No commit, push, PR update, real installation, stable promotion or manual acceptance is part of this follow-up.
