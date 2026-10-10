# Git delivery checking

This is the portable authority for `$team-delivery-check` and
`team-delivery-checker`. Activate only when the user intends a commit, push, pull
request, merge, release or installation source assessment. Ordinary implementation
and code review do not trigger it automatically. Code review judges changed code;
delivery checking judges the exact proposed Git scope against current policy and
evidence; the installation guide owns deployment preview/execution.

## Authority and policy discovery

Read the target project's applicable instructions and authoritative contribution,
branch, release, documentation and installation guidance. Reuse confirmed user
decisions and current task/verification records. An optional existing
`docs/delivery-policy.md` may collect concise approved delivery policy; no special
parser, executable policy, new framework, marker or mandatory file is introduced.
Never run commands merely because a policy document suggests them.

Discover branch roles and pull-request targets semantically. A default branch is
not evidence of a stable release branch, and `main`/`master` have no built-in role.
Distinguish observed refs/configuration from user-approved intent. The absence of
a dedicated policy document does not establish missing policy. When existing
sources leave a material choice unclear, the Lead proposes the exact missing rule,
source evidence, affected operation and recommendation for the user's decision.
Follow [project-rules](project-rules.md) for target instruction-file writes; any
optional policy write also needs the user's approved bounded scope. Do not create
or rewrite policy automatically. Declined or deferred proposals preserve the
decision and allow safe independent checks to continue.

After inspecting existing authorities, if no clear delivery policy can be found,
proactively offer either a concise optional project rule or a one-off decision.
This offer is useful even while safe commit/source checks continue. It is not an
automatic blocker or permission to write. Reuse an unchanged declined/deferred
offer; distinguish that preference from an unresolved critical target/release choice.

Record decisions in the existing task/project record, not a new policy registry:
operation and repository scope, confirmed branch roles/target, base and target
commit IDs, actual user decision and provenance, applicable policy paths/revisions,
verification references and snapshot identity. Reuse only the exact decision while
its meaning, scope and source evidence remain current; ask again only when those
change materially. A nonempty authored record cannot authenticate user approval.

## Operation scope

| Operation | Required scope and interpretation |
| --- | --- |
| Commit | Inspect the actual index entries and staged changes. Report unstaged/untracked differences separately; they are not the commit. An unborn branch with staged content is supported without a fake HEAD. |
| Push | Require an explicit locally available outgoing base. Inspect every commit reachable from HEAD but excluded by that base, including intermediate paths and content. Do not replace this boundary with a PR merge base or infer remote freshness without network evidence. |
| PullRequest | Require the explicit target branch and a base resolving to that target's pinned tip. Inspect the unique merge-base-to-HEAD source contribution and all included commits. Target/base mismatch or multiple/no merge bases needs a decision. |
| Merge | Bind the same source contribution and target tip. This is not the resulting merge tree, conflict-free merge proof or target CI proof; those need their own current evidence. Never perform a trial merge. |
| Release | Require an independent explicit previous-release base, a target branch pinned to the intended source at HEAD, and confirmed user release intent. Inspect BaseRef..HEAD without requiring base=target; a target differing from HEAD needs a decision. Check target-specific release policy; a helper cannot infer release intent or stable status. |
| Install | Bind the source snapshot, dirty/index/worktree state and selected source provenance. Require the existing deployment manager's preview for the exact source and targets before any separately authorized installation. Source readiness does not prove installed equality or active-session loading. |

Do not stage, commit, push, fetch, rebase, merge, tag, force-update refs or install.
The Lead executes an action only under separate existing user authority and after
rechecking current evidence. A request to check readiness supplies no such authority.

Inspect the whole outgoing range, not only its final diff: a secret or local artifact
introduced and then deleted still ships in history. Inspect relevant content locally
without quoting secrets into reports. The collector reports each bounded commit's
paths; the agent inspects content/test/review adequacy and reports any uninspected
history. A bounded collector cannot silently claim coverage of a larger range.

Check document placement, version synchronization, release notes and paired-language
requirements only when the target project's applicable policy requires them. Do not
require a version bump on each commit, impose this Kit's bilingual rules on another
project, or infer a release merely from version-file changes. Keep generated local
runtime artifacts separate from versionable project evidence under the canonical
[generated-artifact contract](generated-artifacts.md).

## Read-only collector

Apply branch-role decisions only when confirmed by the target project. These
examples describe conditions, not mandatory branch names or a universal workflow:

| Confirmed context | Conditional delivery checks |
| --- | --- |
| Feature branch ordinary commit/push | Check the index/outgoing changes and required evidence. Do not require a release version for every commit. |
| Pull request to an integration branch | Pending/unreleased notes may be sufficient if project policy permits them; confirm the intended target and readiness state. |
| Pull request to a release branch with confirmed release-on-merge intent | Require the actual coordinated version, applicable documentation/release notes and release evidence before readiness. A target name alone does not establish that intent. |
| Hotfix or maintenance line | Preserve that line's version/compatibility policy, exclude unrelated feature-line changes, and check the project's backport/forward-port requirements. |
| Unknown branch role, target or material release intent | Ask the Lead for the exact decision; continue independent source checks. |

For Install, the Git-visible snapshot excludes ignored files that a deployment
manager may include inside package units. Require that manager's exact package/
source digest, selected targets and preview; never reuse installation approval
from this helper's Git fingerprint alone.

Run `team-core/scripts/git-delivery.ps1` under PowerShell 7 with `-ProjectRoot`,
`-Operation Commit|Push|PullRequest|Merge|Release|Install`, optional `-BaseRef`,
`-TargetBranch`, and `-RemoteName` (default `origin`). References are local only;
RemoteName identifies user context and does not contact or certify a remote.
Unknown options, invalid refs and inaccessible Git state fail closed. The project
root must be the actual worktree root; bare/nested roots are unsupported.
Configured partial/promisor clones are unsupported: an `extensions.partialclone`
key or any enabled `remote.*.promisor` produces exit 2 with
`unsupported-partial-clone` and incomplete evidence before object reads. Ordinary
remote configuration is permitted and is never contacted. Prepare a complete local
object store through a separately authorized workflow rather than fetching here.

On `unsupported-partial-clone`, stop dependent Git object/content inspection; do
not fall back to unguarded `git show`/`diff` or other object reads. Continue only
independent policy/filesystem checks until a complete local store is available
through a separately authorized workflow.

Schema 1 returns `operation`, `status`, `snapshot`, `changes`, `checks`,
`inspectionRequired`, `findings`, `decisionRequired`, and `limits`:

- `snapshot` binds HEAD, symbolic branch or explicit `detached`, `unborn`, pinned
  base/target/merge-base identities, `indexIdentity` (SHA256 of raw NUL-delimited
  stage entries including blob IDs), `rawIndexSha256`, and `workingTreeIdentity`.
  No `write-tree` or other object write computes the index identity.
- `changes.staged`, `unstaged`, `untracked`, and `outgoing` are path arrays;
  `intermediateCommits` contains `{id, paths}` records. NUL parsing preserves tabs,
  line breaks and other valid filename characters. Rename detection is disabled so
  both path identities remain visible.
- `checks.conflicts`, `whitespace`, `generatedArtifacts`, and `freshness` have
  `status` values `clean`, `blocked`, `incomplete` or `not-applicable` and scoped
  evidence. Whitespace output is counts/scope only, never source excerpts.
- `findings` use stable `code`, `severity`, and safe `message` values;
  `decisionRequired` is an array of decision codes. Required semantic inspection
  remains explicit even when all mechanical checks are clean.
- `limits` states 4 MiB captured bytes per command (16 MiB total), 200 commits, 20,000 paths per
  command, a 60-second collection budget and `incomplete`. Oversize or timed-out
  collection returns a decision, never a pretend complete result.

Exit 0 / `ready-for-review` means bounded mechanical evidence is available. Exit 1
/ `blocked` means an observed blocker or collection failure. Exit 2 /
`needs-user-decision` means missing context or a collection/resource boundary.
None is a final semantic pass. Missing project policy is an agent judgment, not an
automatic tool failure.

The helper uses fixed built-in Git commands with separate process arguments,
optional locks disabled, isolated global/system Git configuration, no replacements,
hooks, network, external diff or textconv. It discovers only local filter key names
and disables clean/smudge/process drivers before worktree inspection. Source/filter
normalization can therefore differ from normal Git; the agent reports that limit
and inspects relevant raw content when it matters. Git errors and diff bytes are
not printed. Repository config is data, never an executable policy language.
Every Git child also receives `GIT_NO_LAZY_FETCH=1`. Because older Git may ignore
that guard, the configuration preflight above is deliberately conservative and
rejects partial/promisor repositories even when their current objects are available.

Before/after fingerprints detect HEAD/branch, index-entry/raw-index and tracked
diff/status changes, plus bounded untracked file content. Untracked hashing skips
sensitive/dependency, linked and oversize files with an explicit inspection limit;
Install cannot be mechanically ready with an incomplete Git-visible source
snapshot. This is an observation window, not a lock against concurrent writers.
Recheck before action.

Generated-artifact detection uses candidates from default `docs/` Documentation
and OpenSpec rules in the canonical contract. It does not infer arbitrary DocsRoot
or Work ownership. Indexed/outgoing `_work/` candidates require an explicit scope
decision. The checker must check the configured DocsRoot and each exact owned
WorkPath with the canonical rules; do not broadly classify all project work as
Kit-generated. Formal specs/PRDs/stage packets remain versionable.

## Semantic report and freshness

The checker returns `pass`, `blocked` or `needs-user-decision`, with the operation,
inspected staged/outgoing scope, HEAD/base/target/index/source identities, actual
policy sources and revisions, current test/review evidence, concrete findings,
uninspected content/limits and next step. `pass` requires sufficient semantic and
mechanical evidence for that operation; `ready-for-review` alone cannot justify it.
Do not convert planned tests, pending manual acceptance, absent CI or stale reviews
into passes. Distinguish a local policy decision from a technical collection error.

Judge which gates are due for this exact operation under project policy and the
existing [test and acceptance contract](test-acceptance-contract.md). Future-stage
manual, release or other not-yet-due checks do not automatically block an ordinary
incremental commit/push; retain their actual status, owner and due checkpoint.
Missing required due evidence blocks readiness. Reuse valid test evidence with its
input identity/provenance where that contract permits it; do not force a full suite
on every commit or relabel pending checks as passed.

Freshness is tied to operation intent, HEAD/base/target/index/worktree identities,
policy and user-decision applicability, and verification input identity. Any relevant
change invalidates the affected conclusion and requires reinspection. Branch names,
unchanged version strings or old green test summaries do not establish freshness.

Use the exact `team-delivery-checker` role only if the active catalog exposes it,
following [role routing](role-routing.md). A newly authored profile unavailable in
the current session is a runtime testing limitation; do not use a generic fallback
or claim that package tests prove native-role behavior. Keep code review and existing
installation/runtime-discovery limits separately visible in the final handoff.
