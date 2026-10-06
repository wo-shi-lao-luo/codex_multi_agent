# File ownership

1. The Lead declares ownership before parallel writers start.
2. A shared API contract, schema, migration, generated client, or lockfile has one named owner.
3. Frontend and backend writers do not edit the same contract in parallel.
4. The Database Specialist owns schema and migration changes; the Backend Engineer owns application usage after the contract is agreed.
5. Use a worktree when two writers need separate branches. Do not create worktrees for read-only agents.
6. A reviewer never rewrites the implementation unless the Lead explicitly assigns a follow-up fix.
7. For UI work, one owner integrates each page/flow. Explicitly assign shared layout, tokens and styles needed for coherent delivery; coordinate scope changes through the Lead rather than editing another writer's files or accumulating local overrides.
8. A docs maintainer owns only assigned documentation/index/review paths. The Lead states each assigned document's purpose and source-of-truth responsibility, not only its filename. Coordinate PRD, Blueprint and stage-packet updates with their owners; do not create duplicate authorities. While editing authorized content, inspect relevant surrounding/linked docs and correct evidenced outdated, inaccurate, misplaced or duplicated active content within the assigned boundary, preserving historical and acceptance evidence and updating affected links/indexes. Out-of-scope findings go to the Lead for a bounded assignment; read-only reviews report without editing. Ambiguous intent, authority conflicts or disputed moves/archives require a user decision before mutation. Lead records readiness and approval evidence.
9. A formatting-only transfer has one owner and exact file paths. The original codewriter must finish and freeze those files before `team-code-maintainer` edits; no concurrent writer is allowed. The maintainer returns a frozen diff and scoped checks before the task's already-planned final tests and independent review. If formatting becomes a behavior or architecture change, return that item to the Lead and original domain owner.
