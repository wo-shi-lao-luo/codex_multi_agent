# Architecture

The system has three layers:

1. **Codex native executor** — creates, observes, and joins subagent threads.
2. **Custom agents** — define bounded roles, model choices, and write permissions.
3. **Skills** — provide explicit team workflows and routing rules. The internal `team-core` Skill ships shared execution, routing, ownership, and handoff references with the workflow Skills.

The main Codex thread is the Lead. It reads project instructions, decides whether parallel work materially helps, gives each child a bounded task, and consolidates outcomes. The Lead is not a separate custom agent. Team workflows use the shared execution contract: Context, Discover, Contract, Execute, Verify, and Handoff.

## Default execution

`$team-dev` starts with scope analysis. For medium and large tasks it normally uses `team-explorer` plus either `team-architect` or a targeted specialist. It then appoints one production-code writer. After implementation, `team-tester` and `team-reviewer` work independently; the Lead handles any fixes and runs the final verification.

## Data work

`team-database-specialist` owns SQL safety, schema design, migrations, indexing, query plans, transaction boundaries, and data-change rollback. It is invoked only when data-layer changes are material.

## Deliberate limits

The toolkit has no background task scheduler, no issue-tracker integration, no automatic Git push or merge, no global hook, and no recursive child orchestration. These limits keep the user-level workflow inspectable and portable across projects.
