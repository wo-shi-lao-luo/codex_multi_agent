# Verification: Explicit Work directory policy reuse

Packet schema version: 2
Stage slug: work-ignore-policy
Contract status: active
Final manual status: manual pending
Final manual evidence: Native user workflow acceptance remains unobserved; isolated public-helper results are recorded separately.

## Stage context

Objective: Consolidate this repository's per-task ignore entries to one user-approved /_work/ rule and make the existing Work helper reuse an effective positive literal directory policy covering _work, without broadening task ownership or automatic ignore writes.
Scope/authority: approved repository .gitignore policy, FOLDER_STRUCTURE.md explanation, generated-artifacts shared contract/helper and bounded tests only. No new design authority, schema, VERSION, public README/changelog, AGENTS, installation, network or model calls. Keep prior architecture-migration and unrelated changes intact; existing _work files remain on disk. Exact WorkPath stays mandatory; other projects receive only precise task rules automatically.
Ownership: Lead coordinates; new team-backend-engineer owns runtime/documentation/.gitignore; reused /root/migration_tests team-tester owns this packet and tests/test-generated-artifacts.ps1 additions; reused team-reviewer independently reviews after freeze. Model identity unknown; no children created by Tester. docs/architecture.md remains the in-place architecture baseline.
Conventions/data: PowerShell 7 public CLI, real GUID-owned OS-temp Git repositories, existing Fixture/Git/Reject helpers, scenario/expected-result comments and code-readability.md. Add a focused Work-policy switch to existing suite to avoid unrelated documentation/clone scenarios. No configured formatter; maintain readable existing style. Runtime source hash captured per batch. Test Git init/staging only inside exact owned fixtures; no actual repository index mutation. Absolute temp-parent/prefix validation and finally cleanup preserve source/user files. Forecast unknown; no budget inferred.

## Use-case map

| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| WI-01 | User-authored /_work/, _work/, nested project /nested/_work/, or ancestor basename _work/ rule effective for nested project | Protect exact populated task, empty task and future task; repeat; inspect JSON and bytes | protected with no rulesAdded, byte-identical policy, no child ignore created, output retained | happy / alternate |
| WI-02 | No broad project rule | Protect empty exact task, add output and sibling; stage fixture; repeat | Only exact task rule appended; sibling stays stageable; existing precise/nested reuse and uncertain populated scope retained | regression / edge |
| WI-03 | Exact task artifact force-staged despite broad ignore | Check and Protect; compare policy/index/artifact hashes | Check reports indexed-local-artifact for exact task; Protect rejects without changes | edge |
| WI-04 | Broad directory policy plus effective or inactive user include in task/ancestor/child policy | Check and Protect; compare byte fingerprints | explicit-include-policy remains visible; reject without overriding policy or index | edge |
| WI-05 | Broad policy with tracked/include conflict in sibling task only | Protect/Check selected exact task | Sibling remains outside selected ownership/audit; selected scope protected with no broad automatic rule | edge |
| WI-06 | User/global/info excludes, wildcard or descendant-only policy, invalid broad WorkPath | Exercise missing exact ownership/default policy and path rejection | Global/info/wildcard and deeper child basename matches cannot prove full task coverage; exact WorkPath remains required | edge |
| WI-07 | Frozen approved repository policy/source | Inspect exact ignore diff, existing _work inventory and helper contract | One /_work/ rule replaces task rules; other ignore policy and existing artifacts retained; docs reflect task ownership distinction | manual / regression |

## Coverage-category decisions

| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | Git's effective policy is observed through the public helper, not private implementation matching. |
| integration | required | Real Git ignore/index outcomes and helper JSON. |
| contract/API | required | Existing result schema, exact WorkPath, no rulesAdded on reused policy. |
| E2E | required | Scripted complete Protect/output/stage/Check paths cover WI-01..06; native user acceptance remains separate. |
| regression | required | Precise default, tracked/index and include safety retained. |
| manual | required | Repository policy diff, retained artifacts, authoritative docs and final user acceptance. |
| component/UI | not applicable | No UI. |
| accessibility | not applicable | No UI. |
| visual regression | not applicable | No rendered output. |
| performance/load | not applicable | No performance claim or changed costly subsystem. |
| security | required | Global-policy distrust, exact ownership, nonmutation and safe fixture cleanup. |
| compatibility | required | Nested roots, anchored/unanchored literal directory rules, existing JSON/precise defaults. |
| data migration/rollback | not applicable | Ignore consolidation does not move/delete/untrack data. |
| resilience/recovery | required | Conflicts reject before writes; repeated Protect safe. |
| exploratory/usability | conditional | Source review checks distinction between broad existing policy and bounded task ownership. |

## TDD behavior matrix

| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Existing literal broad Work policy reuse WI-01 | Populated task incorrectly rejected or exact rules appended redundantly | integration / contract/API | test-first | tests/test-generated-artifacts.ps1 -WorkPolicyOnly | Scoped escalation exited 1 on complete /_work/ plus populated _work/task fixture; helper ARTIFACTS Nonempty WorkPath ownership is uncertain | Same focused command exited 0 after bounded correction on runtime SHA256 29EE59BCA25B206441F7DC4D7DAC70B18EAA5798F6729FCBDBCC2CE83E34803B | Final focused run includes repeated policy reuse, bytes/source preservation and exact cleanup; no production refactor | Runtime writer held until actual Red reported; original Git-init environment denial is not Red | Tester | passing |
| Preserved scope/index/include boundaries WI-02..06 | Broad policy turns into broad ownership or bypasses conflict checks | regression / security | test-after | tests/test-generated-artifacts.ps1 -WorkPolicyOnly; -NestedWorkOnly | not applicable | Both commands exited 0 including child partial-coverage negatives and unchanged precise default | Source hashes preserved; rejection fingerprints include policy/output/Git index/config; exact temporary fixtures removed | Existing safety behavior already present; affected cases checked without fabricated individual Reds | Tester | passing |
| Repository consolidation and authority WI-07 | Unrelated ignore entries or retained artifacts lost | manual / compatibility | manual-or-environmental | Source.WI-07; Native.WI-07 | not applicable | Source check exited 0: one root Work rule and all 42 captured existing files unchanged; docs aligned | no data move/refactor | Exact repository diff and existing _work fingerprints are source evidence; human/native acceptance unobserved | Tester / Lead / user | manual pending |

## Automated test and E2E plan

WAIT Lead GO before test edits. After GO add focused -WorkPolicyOnly path and stable WI cases using existing fixtures. Run against unchanged runtime: expected practical Red is ARTIFACTS nonempty ownership rejection for /_work/ with exact populated WorkPath, not setup failure. Notify Lead before implementation owner starts runtime edits; never retrospectively claim Red. After runtime freeze run focused Green, -NestedWorkOnly precise ancestor regression, package validator and assigned test/helper AST. Expand only on specific failure/scope change; no prior large unrelated suite or installation needed. Preserve byte/index checks and assert exact fixture cleanup and source hash preservation.

| Manual case / requirement ID | E2E scenario / checkpoints | Other layers / evidence | Status / gap |
| --- | --- | --- | --- |
| WI-01 | ScriptE2E.WI-01: actual Protect on populated/empty/future tasks, repeated JSON rulesAdded and byte equality | focused public CLI assertions | executed/passing for isolated helper conditions |
| WI-02 | ScriptE2E.WI-02: default Protect, output+ sibling, fixture git add; exact/ancestor reuse | precise-rule and nested regression assertions | executed/passing for isolated helper conditions |
| WI-03/04 | ScriptE2E.WI-03/04: force-staged task and include conflict; Check finding, Protect rejection, untouched bytes/index | negative public CLI assertions | executed/passing for isolated helper conditions |
| WI-05/06 | ScriptE2E.WI-05/06: sibling conflict, global/info/wildcard/descendant conditions, invalid WorkPath rejection | scope/path assertions | executed/passing for isolated helper conditions |
| WI-07 | Native.WI-07: user observes approved repo ignore/retention policy and exact task protection workflow | Source.WI-07 diff, artifact inventory/fingerprints and docs review | source verified; native/user acceptance pending |

Deferred WI-07 owner user/Lead, manual pending; trigger separately authorized native user workflow observation, flush before claiming human acceptance. Scripted E2E may prove only declared isolated CLI conditions, not future native agent behavior. No exception accepted.

## Human verification script

1. Review approved final diff: exactly one /_work/ in repository .gitignore, old task rules removed, other ignores untouched; existing _work paths/bytes retained. WI-07 expected: policy consolidation alone, no deletion/untracking.
2. WI-01/02: in authorized disposable repo compare existing broad literal policy vs no such policy. Use exact WorkPath on existing and future tasks and repeat. Expected: existing broad policy reused byte-exactly; default helper appends only exact rule.
3. WI-03/04: stage an exact task file with force or declare task include. Expected: Check finding and Protect rejection with index/policy/output unchanged.
4. WI-05/06: leave tracked/included sibling task, global excludes or wildcard-only policy, then select exact task and test invalid broad WorkPath. Expected: sibling is outside owned scope; global policy is not trusted and broad task path rejected. Clean only owned fixtures.
5. Record direct user observation/deferral here before changing final manual status or archiving; automated evidence cannot fabricate human acceptance.

## Verification record

Preimplementation discovery read generated-artifacts.md and entire helper, inspected existing Git fixture helpers, precise/nested Work cases, conflict/index checks, suite selectors and cleanup, plus current .gitignore/FOLDER_STRUCTURE. Current runtime only reuses matching literal rule when its covered directory equals exact task; broad /_work/ coverage therefore leaves missing precise rule and populated task fails ownership check. An ancestor basename _work/ can be Git-effective for a nested project while naive source-directory resolution identifies ancestor/_work; test this specific literal case without demanding a generic Git pattern parser. These are source predictions only until named Red executes. No tests/runtime/docs/.gitignore edits yet; only this canonical packet created. Prior architecture-migration changes preserved. Lead protected its exact scratch _work/work-ignore-policy using unchanged runtime; writer will fold that rule into approved root policy. Before batch capture relevant prior dirty source hashes excluding owned testfile, and verify no source changes during frozen-source execution. Preimplementation packet Validate exited 0 with manual pending.

After Lead GO, added -WorkPolicyOnly and six scenario groups in tests/test-generated-artifacts.ps1 using existing real disposable Git fixtures. Protected-source hashes include prior migration test/validator/reference, .gitignore/FOLDER_STRUCTURE/docs architecture, helper and all skills/agents/config files, excluding this owned testfile. Runtime writes held until Red. First un-escalated command begun 2026-10-08T20:58:47.6202781+08:00 exited 1 at fixture git init because sandbox denied owned temporary .git/config write; setup failed before behavior and is not intended Red. Approved scoped escalation of the same command then exited 1 at unchanged helper line 260: ARTIFACTS Nonempty WorkPath ownership is uncertain without its exact existing ignore rule. Complete first fixture contains /_work/ and retained _work/task/existing.txt. This actual WI-01 Red was reported before Lead authorized runtime implementation. No actual repository index write, model call, installation or network operation occurred. Assigned test AST exited 0. Cleanup subsequently strengthened to exact temp parent plus invocation prefix and absence assertion; scenario/assertion behavior retained. Current tests wait runtime freeze before Green. Capture of 42 existing repository _work files hashes will assess retention after approved policy consolidation; capture is in tool-session memory, not a new durable private manifest.

Lead added a bounded WI-06 safety requirement before Green: a child _work/task/inner/.gitignore basename _work/ or _work/task/.gitignore basename task/ ignores only a deeper actual output while leaving the selected task/probe unprotected. Both parameter rows must reject without mutation; an actual deeper match cannot justify whole-task policy reuse. This extends the existing negative group, not a new general ignore parser or fabricated additional preimplementation Red.

First Green against frozen runtime SHA256 05ECD833043A207C745B5DABBF7B22BB1067E60774C3B2155757ADB59F6D0B28 exited 1 on the first complete WI-01 fixture: helper rejected broad literal policy as nonempty ownership uncertainty. Source fingerprints preserved and exact fixture cleanup passed. Focused read-only diagnosis: Work's switch emits one String, and new `$probes[0]` comparison selects its first character `_` rather than full synthetic probe. A local PowerShell scalar check confirmed type String and indexedFirst `_`. Returned defect to runtime owner via Lead; no production repair by Tester or blind retry. Coverage remains unverified until refreeze and rerun.

Runtime owner made the one bounded scalar correction `$probes[0]` to `@($probes)[0]` and refroze SHA256 29EE59BCA25B206441F7DC4D7DAC70B18EAA5798F6729FCBDBCC2CE83E34803B. Same scoped escalated focused test then exited 0: anchored/unanchored root, nested path and ancestor basename rules reused for populated/empty/future/repeated tasks with no rulesAdded or policy/output changes; current/future fixture output stayed unstaged. Default exact-task append and sibling stageability retained. Force-staged selected artifact and effective/inactive task includes produced findings/refusal with fixture bytes/index/config unchanged. Sibling tracked/include risk did not expand ownership. Global/info/wildcard/ancestor-only and descendant-only false scope rejected; missing/broad WorkPath rejected. Protected source hashes unchanged; exact temporary fixture removed. Existing scoped `-NestedWorkOnly` exited 0; fresh package validator and helper/test AST checks exited 0. No unrelated broad suite or installation ran.

Same-issue correction history: one failed implementation verification for WI-01, followed by local scalar diagnosis, one bounded correction and passing rerun. Git-init sandbox setup denial and expected TDD Red are excluded from failed repair count. No extension granted/used; no external research needed because controlled local evidence established the defect. No processes remain owned by Tester.

WI-07 source check exited 0: exactly one /_work/ rule and no remaining task Work rules; all 42 captured existing _work files retained with identical hashes. Lead independently reported 41 pre-task files unchanged, no tracked _work entries and diff hygiene passed; the extra captured file is current readiness scratch. Contract Profiles and lifecycle now describes effective in-repository literal exact task/immediate _work reuse, retained exact WorkPath/index/include audits, no global/info/wildcard trust and no broader cleanup/index authority. FOLDER_STRUCTURE explains repository-local work placement and root policy retention. These rules were written to skills/team-core/references/generated-artifacts.md and FOLDER_STRUCTURE.md, not merely conversation memory; no SKILL.md file changed for this task.

Comment/readability self-check: new function/group comments state public-boundary responsibility and each WI scenario/expected result; exceptional descendant-only parameter rows explain partial coverage. Assertions check claimed rulesAdded, source/output/policy/index byte invariants, findings, refusals and cleanup. Existing scenario purpose retained; no formatter configured, readable grouping/literals and assigned AST checked. Cleanup changed only to stricter exact parent and absence assertion. All runtime files remained with backend owner.

Actual current roster reported by Lead: /root/work_ignore_runtime selected team-backend-engineer; original /root/migration_tests selected team-tester reused for test/packet; original /root/migration_review selected team-reviewer reused for independent review after freeze. Catalog exposes required exact roles; returned role identity/model unknown. No historical unrelated reuse or Tester children. Reviewer conclusion pending its handoff; Lead owns final roster/readiness. Completed status does not establish capacity release; no supported close operation exposed. Lead reported local feedback record unavailable due existing home-write permission limit, not retried this turn; no native/user acceptance claimed. Packet remains active with final manual pending.

Lead close: independent /root/migration_review reviewed the frozen helper, scoped docs/policy and final tests/evidence; no unresolved material findings, no suite rerun or file edits. All three current children handed off with ownership ended and no owned processes; host-resolved role/model and slot release remain unknown, with no supported close operation available. Lead read the reconciled packet and preserves prior architecture-migration changes, the pending native/manual gap and the unavailable local feedback record. Only this task's readiness scratch will be removed after final scoped review refresh; the 41 pre-task Work files remain retained. No commit, push, installation or release requested/performed.
