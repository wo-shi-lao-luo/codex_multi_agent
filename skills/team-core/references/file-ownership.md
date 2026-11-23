# File ownership

## File responsibilities and placement

Apply this check to feature work, repairs, and maintenance, including a single writer on the light path.

- **Before editing.** Identify what belongs in each material target file or module and where the changed behavior is already owned. Use relevant repository instructions, architecture notes, nearby code, and callers as evidence. Fit new logic to the existing owner and dependency direction. If a new file is needed, place it according to project conventions and make its responsibility clear.
- **While editing.** Keep entrypoints and composition files focused on wiring, and keep rules, state, and transformations with the modules that maintain them. Check shared code for new feature-specific fields, conditions, or defaults, including dependencies expressed through data or configuration. Keep related logic together when it changes for the same reason. If the appropriate location changes materially, return to the existing Contract step and obtain any approval already required for structural refactoring.
- **Before handoff.** Inspect the actual diff, including new files and any changed dependency direction. For each material addition, confirm that the file owns that behavior and that a maintainer would look there when it changes. Correct misplaced changes within the authorized scope even if tests pass. Report pre-existing or out-of-scope placement issues through the existing ownership and review process.

For a small task, the executor checks the relevant file before editing and self-checks the diff afterward. For a change spanning responsibilities, record the affected file or module roles and handoffs in the existing Work contract or Blueprint as applicable. The existing Reviewer checks material placement when independent review is due. Use the existing records and risk tier for all of these checks.

## Writer assignment and transfer

1. The Lead declares ownership before parallel writers start.
2. A shared API contract, schema, migration, generated client, or lockfile has one named owner.
3. Frontend and backend writers do not edit the same contract in parallel.
4. The Database Specialist owns schema and migration changes; the Backend Engineer owns application usage after the contract is agreed.
5. Child agents ordinarily share the task filesystem. For on-demand parallel production writers, follow [isolated worktree guidance](isolated-worktrees.md) to bind separate managed checkouts explicitly. Do not create worktrees for read-only agents.
6. A reviewer never rewrites the implementation unless the Lead explicitly assigns a follow-up fix.
7. For UI work, one owner integrates each page/flow. Explicitly assign shared layout, tokens and styles needed for coherent delivery; coordinate scope changes through the Lead rather than editing another writer's files or accumulating local overrides.
8. A docs maintainer owns only assigned documentation/index/review paths. The Lead states each assigned document's purpose and source-of-truth responsibility, not only its filename. Coordinate PRD, Blueprint and stage-packet updates with their owners; do not create duplicate authorities. While editing authorized content, inspect relevant surrounding/linked docs and correct evidenced outdated, inaccurate, misplaced or duplicated active content within the assigned boundary, preserving historical and acceptance evidence and updating affected links/indexes. Out-of-scope findings go to the Lead for a bounded assignment; read-only reviews report without editing. Ambiguous intent, authority conflicts or disputed moves/archives require a user decision before mutation. Lead records readiness and approval evidence.
9. A formatting-only transfer has one owner and exact file paths. The original codewriter must finish and freeze those files before `team-code-maintainer` edits; no concurrent writer is allowed. The maintainer returns a frozen diff and scoped checks before the task's already-planned final tests and independent review. If formatting becomes a behavior or architecture change, return that item to the Lead and original domain owner.
10. For any same-path writer transfer, verify that the previous writer and any process it started have stopped modifying the exact paths before assigning the new owner. Transfer current diff, evidence, remaining work and verification state; retain one owner for each path. Do not force-kill a process to make a transfer appear safe. Test-source or harness migration is implementation work with an explicit suitable owner and bounded paths; separate test execution and acceptance ownership remain as assigned.
