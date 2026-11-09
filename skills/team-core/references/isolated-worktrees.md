# On-demand isolated worktrees

Use this guidance when the Lead chooses separate checkouts for parallel production writers or explicitly registers linked worktrees as execution workspaces under the [task coordination contract](task-coordination.md#executor-identity-lead-inline-work-and-registered-workspaces). Ordinary child agents share the task filesystem by default. A queue is optional and is not a prerequisite; worktree binding is per checkout and must be explicit. Board registration does not itself grant write authority or transfer task ownership.

## Plan and bind

- Give each parallel production writer a managed worktree and branch, using the host's supported worktree operation. Reuse a suitable existing checkout when possible. Bind the writer to the exact checkout path, branch, task, and one pinned common base commit before any writes. Confirm the checkout ancestry and inspect dirty/untracked state; never assume caller changes were copied. Unexpected state or unsupported binding means stop and use a safe sequential workflow.
- Require a clean pinned base and agreed dependencies/API before parallel edits. Assign one owner to each shared API, schema, migration, generated client, lockfile, and concrete path. Parallelize only independent packages with disjoint write paths and resources; separate checkouts do not grant overlapping path ownership.
- If the optional Board uses these checkouts as execution workspaces, register only verified linked worktrees from the same Git common directory and bind every claim to the registry snapshot. This supplements the handoff binding; it does not change this guide's freeze, review, or integration requirements. See the [workspace protocol](task-coordination.md#executor-identity-lead-inline-work-and-registered-workspaces).
- Allocate ports, databases, caches, environment files, credentials, and generated/build outputs separately when concurrent work could collide. A worktree provides a separate checkout, index and working files; refs and commit objects live in shared Git metadata. It is not a security sandbox or container, and permissions/resources may remain shared.
- Keep read-only research and review in the existing checkout. Do not create a worktree for those roles.

## Freeze and hand off

Before submission, stop the writer and any process it started that can still write. Freeze the exact commit and report its checkout, branch, commit SHA, pinned base SHA, changed paths, unresolved dirty/untracked paths, dependencies, and commands/results actually observed. Do not claim tests or checks that did not run. A worktree or branch label alone is not evidence of checkout binding.

The handoff is local and PR-like: it does not authorize push, external PR creation, installation, or a commit beyond the Lead's specific task authority. The Lead reviews each submitted commit against the pinned base and its complete incoming history before integration.

## Integrate and recover

- The Lead integrates only into the named integration checkout/branch after review and required gates. Before each integration, compare its actual target HEAD and incoming history with the pinned base and any earlier integrations; do not assume the original common base is still current. Ensure affected target paths are ready and clean. Preserve unrelated dirty work by using a suitable separate integration checkout; if affected paths are dirty or target state is uncertain, stop and resolve the state before integrating. Integrate commits in dependency order, one at a time. Do not assume a clean merge proves semantic compatibility.
- On conflict, unexpected files, or uncertain ancestry, stop the affected integration and preserve all refs and changes for recovery. Escalate substantive choices. Do not force-overwrite, reset, autostash, or use a destructive abort.
- Run due verification against the actual integrated snapshot. Any changed input invalidates affected earlier evidence; report the integrated revision and refreshed results.
- Archive or remove a managed worktree only after acceptance, recoverable commits, and evidence are established, and after checking for needed ignored artifacts. Use the host's supported archive/cleanup operation; do not manually delete its directory.

If host isolation, exact binding, or resource separation cannot be established, continue sequentially without silently sharing concurrent writers. No runtime isolation, automatic scheduler, merge, or token-saving guarantee is implied.
