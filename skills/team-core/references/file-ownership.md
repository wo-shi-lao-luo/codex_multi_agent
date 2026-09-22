# File ownership

1. The Lead declares ownership before parallel writers start.
2. A shared API contract, schema, migration, generated client, or lockfile has one named owner.
3. Frontend and backend writers do not edit the same contract in parallel.
4. The Database Specialist owns schema and migration changes; the Backend Engineer owns application usage after the contract is agreed.
5. Use a worktree when two writers need separate branches. Do not create worktrees for read-only agents.
6. A reviewer never rewrites the implementation unless the Lead explicitly assigns a follow-up fix.
7. For UI work, one owner integrates each page/flow. Explicitly assign shared layout, tokens and styles needed for coherent delivery; coordinate scope changes through the Lead rather than editing another writer's files or accumulating local overrides.
