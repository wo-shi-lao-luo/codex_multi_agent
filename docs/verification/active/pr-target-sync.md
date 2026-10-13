# Verification: PR target synchronization

Packet schema version: 2
Stage slug: pr-target-sync
Contract status: frozen-source package validation and source-forward walkthrough complete; native/manual behavior pending
Final manual status: manual pending
Final manual evidence:

## Stage context

Objective: before creating a PR, synchronize the exact target, safely rebase the source,
preserve recovery and user authority, reassess affected evidence, and report unresolved conflicts.
Expected behavior comes from the user's approved PR fetch/rebase proposal, not the existing implementation.
Scope: instruction-only shared Git delivery contract and entrypoint reminders; no Git automation change.
Owner: /root/pr_sync_tests, selected team-tester, owns this packet only. Lead owns integration;
the writer owns normative files and the independent Reviewer owns semantic review.
No children, remote access, Git mutations, user-home changes or production edits by Tester.
Discovery: existing scripts/validate.ps1 validates actual package references/metadata;
tests/helpers/package-test.ps1 provides isolated PublicDocs copies, literal process invocation,
complete fingerprints and owned GUID-temp cleanup. The existing schema2 stage validator is reused.
Use current working-tree guidance after writer freeze. No real remote, account or product fixture is needed.
Keep temporary copies in one bounded OS-temp GUID child and delete only that owned child after checks.

## Use-case map

| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| PR-01 | Feature branch and non-default or fork PR target | Identify repository, remote, source and exact target | No assumed main/master or wrong fork target; ask on ambiguous fork/remote mapping and record resolved target | happy |
| PR-02 | Dirty files or active merge/rebase/cherry-pick | Inspect local state before synchronization | Stop dependent action without automatic stash, commit, discard or operation override | edge |
| PR-03 | Fetch unavailable or target missing | Attempt authorized exact-target refresh | Report failure; stale local target cannot satisfy PR synchronization | edge |
| PR-04 | Clean source, valid target, rebase authorized; include never-pushed source | Check project policy/shared or protected history; record recoverable original source and fetched target; rebase only when permitted | Preserve recovery point and user code; ask focused decision if policy forbids rebase or shared/protected history needs authority; inspect actual final diff; never-pushed branch uses ordinary first push, no nonexistent source-tip lease prerequisite | alternate |
| PR-05 | Rebase conflicts | Compare clear mechanical conflict with substantive or uncertain conflict | Resolve only evidenced safe choices; stop and report unresolved files, cause, preserved state and exact user decision; no bulk ours/theirs | edge |
| PR-06 | Rebase changes affected source/test inputs | Reassess verification provenance and final diff | Invalidate affected stale evidence; run scoped checks and mandatory gates, not unconditional full suite | happy |
| PR-07 | Source branch already pushed, possibly with unseen collaborator commits | Reconcile a fresh actual source-remote tip against preserved pre-rebase source, then check rewrite authority and expected remote OID | Unknown, unseen or divergent source history pauses for user decision before rewrite; separate authority plus explicit force-with-lease protects subsequent remote changes, never bare force | edge |
| PR-08 | Delivery check assigned | Distinguish checker from Git executor | Checker remains read-only; Lead executes authorized operations; push success precedes PR creation | happy |
| PR-09 | Target advances after fetch/rebase | Observe target before delivery; after at most one catch-up, fetch/observe once more | Final fetch failure or renewed target advance pauses with drift report; no next rebase, infinite loop or false synchronized claim | edge |

## Coverage-category decisions

| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No executable function changed. |
| integration | required | Actual isolated package validator exercises resource distribution. |
| contract/API | required | Source-forward review checks authority and compatible entrypoint links. |
| E2E | required | All PR cases mapped to future native controlled tasks; none executed here. |
| regression | required | Existing package validator and complete copied-byte nonmutation check. |
| manual | required | Human authority and unresolved conflict handling need observed acceptance. |
| component/UI | not applicable | No product UI changed. |
| accessibility | not applicable | No user-interface controls changed. |
| visual regression | not applicable | No rendered output changed. |
| performance/load | not applicable | No runtime speed or token-saving claim. |
| security | required | Remote write/history-rewrite authority reviewed without executing sensitive actions. |
| compatibility | required | Preserve read-only collector and existing status/role contracts. |
| data migration/rollback | conditional | Recovery source required before history change; no actual data migration. |
| resilience/recovery | required | Fetch failures, conflicts and target drift must preserve recoverable state. |
| exploratory/usability | required | Bounded walkthrough checks useful user conflict reports. |

## TDD behavior matrix

| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Package references and compatibility | Broken guidance distribution | integration | test-after | PrTargetSyncPackage.Intact | not applicable | One isolated actual package validator exit0, 159-file fingerprint unchanged; owned fixture removed | not needed; no executable refactor | Instruction-only change; reuse actual existing consumer once after source freeze | pr_sync_tests | passing |
| Safe PR synchronization decisions | Wrong target, code loss, unauthorized rewrite or stale evidence | E2E | manual-or-environmental | PrTargetSyncE2E.PR-01 through PR-09 | not applicable | planned | not needed; no executable refactor | No executable decision classifier; source-forward review now, controlled native tasks later; no live Git mutation authorized for this test | Reviewer; Lead/user for runtime | manual pending |

## Automated test and E2E plan

Before writer GO, run the existing stage Validate on this filled packet. After writer and public-document
owners freeze their source, run one actual isolated PublicDocs+config package validator using the existing
package-test helpers. Compare complete fingerprints before/after, capture validator/helper/source identity,
assert zero exit and no copied-byte changes, clean only the owned GUID-temp child and confirm absence.
No new prose-regex tests, scripted Git history exercises, browser tests, remote actions or user-home install.
The unchanged Git collector does not execute fetch/rebase and cannot prove this instruction behavior.
Forecast unknown; one post-freeze batch is due before handoff. Lead owns required bilingual checks if paired
public files change. Source walkthrough and structural checks are not native E2E execution or human acceptance.

### Manual-to-automated coverage mapping

| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| PR-01 | PrTargetSyncE2E.PR-01 exact repository/remote/target identity | Source walkthrough | planned | Native task pending |
| PR-02 | PrTargetSyncE2E.PR-02 dirty/active operation stops without mutation | Source walkthrough | planned | Native task pending |
| PR-03 | PrTargetSyncE2E.PR-03 failed fetch blocks stale-target PR | Source walkthrough | planned | No live network test |
| PR-04 | PrTargetSyncE2E.PR-04 recovery source, rebase, final diff and never-pushed ordinary first push | Source walkthrough | planned | No history rewrite test |
| PR-05 | PrTargetSyncE2E.PR-05 clear versus ambiguous conflict and report | Source walkthrough | planned | Native judgment pending |
| PR-06 | PrTargetSyncE2E.PR-06 affected evidence invalidation and scoped rerun | Source walkthrough | planned | Native task pending |
| PR-07 | PrTargetSyncE2E.PR-07 fresh actual source tip, pre-rebase ancestry reconciliation, unseen/divergent stop, rewrite authority and explicit lease | Source walkthrough; initial PR-07 judgment superseded by independent finding | planned | No remote writes authorized |
| PR-08 | PrTargetSyncE2E.PR-08 read-only checker and executor separation | Source walkthrough and package references | planned | Native routing pending |
| PR-09 | PrTargetSyncE2E.PR-09 bounded target-drift response | Source walkthrough | planned | Native task pending |

## Human verification script

### Preparation

Use final guidance in an explicitly authorized disposable repository and controlled remote fixture.
Record exact source/target revisions and initial state; do not use production branches, credentials or
uncommitted user work as fixtures. Obtain separate authority before any remote history rewrite.

### Happy path

1. PR-01/04: request a PR to a named non-default target. Expected: exact target fetch, original source
   recovery point, safe rebase, inspected final diff and recorded target revision before delivery.
   Repeat with a never-pushed feature branch: expected ordinary first push, without requiring an existing
   remote-source tip, rewrite approval or force-with-lease. Unexpected existing remote history needs reassessment.
2. PR-06/08: expose changed inputs after rebase. Expected: only affected evidence invalidated plus mandatory
   gates, checker remains read-only, executor pushes successfully before creating PR.

### Recommended edge cases

1. PR-02: present dirty files, then an active operation. Expected: preserve both and ask for required choice;
   no implicit stash/commit/discard or operation override.
   PR-01/04: also present ambiguous fork mapping, a no-rebase policy or shared/protected source history.
   Expected: focused target/policy/authority decision, no guessed target or bypass of contributor protections.
2. PR-03: make target refresh unavailable. Expected: explicit failure and no stale-target synchronized claim.
3. PR-05: present one safe mechanical and one substantive uncertain conflict. Expected: bounded safe handling,
   useful unresolved-conflict report and human decision; no blanket side selection or discarded user code.
4. PR-07: use an already-pushed branch without rewrite authority, then present a freshly observed source-remote
   tip containing collaborator commits missing from the preserved pre-rebase source. Also test divergent history
   and a remote change after capture. Expected: reconcile actual source ancestry first; unseen/divergent/unknown
   history pauses for a user decision, not automatic overwrite. Separate authority remains required; the explicit
   source-ref/OID lease protects later changes and is not proof that earlier collaborator work was included.
5. PR-09: advance target before delivery, then again after one catch-up; separately fail the final fetch.
   Expected: one catch-up maximum, explicit final bounded observation, then pause on renewed drift or unavailable
   refresh instead of another rebase or a stale synchronized claim.

### Result

Manual pending. Preserve recorded observations, restore only the owned fixture from its recovery source,
and remove only authorized disposable fixtures. These steps have not been executed by this task.

## Verification record

Coverage plan prepared before production GO. Packet validation and final checks are recorded below when run.
No retrospective Red, native workflow pass, measured saving, model identity or human acceptance is claimed.
Capabilities: testing-engineering and workspace-hygiene Skills; shared execution/TDD/acceptance/readability
references; local file/Git read-only discovery and apply_patch for this packet only. No children or external service.

Pre-GO Validate exited0 twice, including added fork ambiguity and shared/protected/no-rebase policy cases.
After Lead confirmed writer freeze, one inline PowerShell runner reused Copy-TestPackage Profile PublicDocs
with config, Get-TestFingerprint, Invoke-TestProcess and Remove-TestSandbox. Actual copied scripts/validate.ps1
exited0 with `Codex Team Kit validation passed.` Complete 159-file before/after manifest was identical.
Runtime PowerShell 7.6.5; Kit 1.0.8; observed baseline HEAD d3dba51e85c38904d803fc073ec16d112ca63d0d
with current working-tree edits, not a clean-commit claim. Snapshot aggregate SHA256:
dc824a22bb29eba79819c66f05ab44a323c31c82f788cb73238f3ae78038bb9f.
Copied canonical Git contract SHA256: 0ee6fdd581e51c37d9c98377dfe0427ed996f8353c5e2aae85738dd105005231;
entrypoint SHA256: 86ab0ff7b2c17e3108f87388c5f58120cfcee2b7f7213d62ebd45017ed256739;
actual validator SHA256: 77c254c8eb5aa136f034fddbe1634883e1f5a717c241f3eb2fd8f704343ba723;
helper SHA256: 8f6183f62774d323779fdc96dfa7be9b08ef92d1d8f48b9fe4feb0890dcbe609.
Owned OS-temp child codex-pr-target-sync-test-76b7c197edf943ee98b1efb3ee9abae3 was validated by
the cleanup helper, removed, and its absence explicitly confirmed; outer runner exited0.
Later packet evidence edits change included document bytes; this digest identifies only the tested snapshot.

Source-forward walkthrough of both frozen normative files found no material gaps across PR-01 through PR-09.
Correction: this initial statement's PR-07 judgment is superseded by independent Reviewer /root/pr_sync_review's
finding: a lease alone does not protect collaborator commits already present at initial remote-tip capture.
PR-07 final reconciliation is recorded below after the writer's fix; other scenario conclusions are unchanged.
PR-01/02: exact destination and no assumed default/fork mapping, dirty/active-operation choice.
PR-03/04: stale-target rejection, policy/ownership gate and verified durable non-overwrite recovery ref.
PR-05: safe mechanical resolution only; substantive uncertainty reports paths/cause/completed work/recovery/options/decision,
without implicit abort/reset or wholesale side selection. PR-06: inspect final contribution/history and invalidate
affected test/review inputs rather than unconditional full suite. PR-07: separate history-rewrite authority,
actual source remote expected OID and explicit ref/OID force-with-lease, stop on unknown/changed source.
PR-08: executor/checker separation and successful push before PR creation/update. PR-09: second exact-target
fetch and at most one catch-up under existing authority, then pause on further drift/material risk.
The initial PR-09 source judgment is also superseded pending clarification of the final post-catch-up
observation; its initial wording did not explicitly require that last bounded fetch.
The entrypoint's target synchronization link resolves to the actual canonical heading in the Git contract.
This is source-forward contract evidence, not executed fetch/rebase, a native Agent pass or user acceptance.

No executable runtime script changed, so no Git-delivery collector regression suite or brittle prose tests ran.
No Python validator ran: discovered python command is only the WindowsApps alias, not an available trusted
Python runtime. The actual package validator provided the applicable frontmatter/resource alternative.
No public documents changed in the frozen scope; no bilingual check required from this Tester.
No test source authored: no formatter changes or comment edits; all packet cases retain explicit purposes,
expected outcomes and manual mappings. No network, Git mutation, user-home action, child or unrelated cleanup.
Final scoped command: `pwsh -NoProfile -File skills/team-core/scripts/stage-verification.ps1 -Action Validate -ProjectRoot . -StageSlug pr-target-sync`.
Native PR-01 through PR-09 remain manual pending with Lead/user ownership, triggered by future controlled
authorized tasks before claiming runtime adherence; no automation exception or archival approval is inferred.

Focused review follow-up: original independent Reviewer found the PR-07 pre-existing-collaborator-history
gap. The original lease expectation alone protected only changes after capture, not source commits missing
from the local branch before capture. Original writer amended the contract; Tester changed PR-07 and its
manual/E2E checkpoints without erasing the initial judgment. PR-09 also gained explicit final target
observation after the single catch-up. After Lead declared final normative freeze, Tester re-read both
normative files and surrounding context. PR-07 now requires the exact source repository/ref fetch, separate
rewrite authority before rebase, and an equal/ancestor relationship from remote source tip to the preserved
pre-rebase commit; unseen/divergent history stops for an integration decision. Its lease uses the pinned
source-fetch OID and verifies no remote movement. PR-09 requires the final post-catch-up fetch, stops on
failure or renewed advancement without another rebase, and labels freshness point-in-time rather than a lock.
Entrypoint link and unchanged read-only checker/assessment authority remain correct.

No full package rerun: the focused changes are prose within the existing canonical file, with no new link,
resource, script or metadata change. The executed package snapshot/digest above is retained as prior evidence,
not relabeled as a package run over the final bytes. Validator and helper hashes remain unchanged; entrypoint
hash remains 86ab0ff7b2c17e3108f87388c5f58120cfcee2b7f7213d62ebd45017ed256739.
Intermediate focused canonical-file SHA256 was 7eb4aa8d92ae3d998c2abbead13466895b9470ce23c5fe9e8b34b07fad6829cc;
it is not the final source identity.
Native PR-07/09 execution and all user/manual acceptance remain pending; source-forward fixes do not imply
remote history rewriting was tested. No production edits or additional action authority were taken by Tester.

Final focused correction: Tester, Reviewer and Lead also identified unconditional wording in the lease paragraph
could incorrectly require an existing remote tip for a never-pushed branch. Original writer scoped this paragraph
to authorized history rewrite of an existing remote source ref and explicitly allowed an ordinary authorized
first push for never-pushed source, without rewrite permission/overwrite lease. Tester re-read that final paragraph,
confirmed PR-04 happy and PR-07 existing-source distinction, and retained the earlier PR-07 ancestry/PR-09 drift
checks. PR-04 mapping/manual steps now include ordinary first push; no new case IDs or native pass was invented.
Final reviewed canonical-file SHA256: 2797b0f7a6c8b32393b8d1c12a5a4119099d7136bf28facfc77a151a65e29359.
The prior package run remains explicitly over its original snapshot, not these revised prose bytes; no script,
link, resource or metadata change justified a duplicate package run. Final packet Validate passed exit0 with
manual pending. Tester file ownership ended after this handoff; no running process or owned temp fixture remains.
