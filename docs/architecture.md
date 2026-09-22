# Architecture

The system has three layers:

1. **Codex native executor** — creates, observes, and joins subagent threads.
2. **Custom agents** — define bounded roles, model choices, and write permissions.
3. **Skills** — provide explicit team workflows and routing rules. The internal `team-core` Skill ships shared execution, routing, ownership, and handoff references with the workflow Skills.

The main Codex thread is the Lead. It reads project instructions, decides whether parallel work materially helps, gives each child a bounded task, and consolidates outcomes. The Lead is not a separate custom agent. Team workflows use the shared execution contract: Context, Discover, Contract, Execute, Verify, and Handoff.

## Default execution

`$team-dev` starts with scope analysis. For medium and large tasks it normally uses `team-explorer` plus either `team-architect` or a targeted specialist. It then appoints one production-code writer. After implementation, `team-tester` and `team-reviewer` work independently; the Lead handles any fixes and runs the final verification.

## UI work

For new pages and visible UI changes, the Lead passes a lightweight UI brief and names one owner for the coherent page or user flow. The owner uses frontend-design for hierarchy, styling and rendered refinement alongside frontend-engineering for implementation correctness. Small demos normally stay with one implementer; independent work may still be delegated. File boundaries must include necessary shared styles or be adjusted explicitly.

Functional tests and rendered visual inspection are separate evidence. The Lead checks the final integrated page's evidence, and missing browser access remains an explicit unverified state. Agent inspection never replaces user manual acceptance. See the [UI delivery contract](../skills/team-core/references/ui-quality.md). This workflow does not claim measured visual improvement until a matched-task comparison is actually run.

## Data work

`team-database-specialist` owns SQL safety, schema design, migrations, indexing, query plans, transaction boundaries, and data-change rollback. It is invoked only when data-layer changes are material.

## Deliberate limits

The toolkit has no background task scheduler, no issue-tracker integration, no automatic Git push or merge, no global hook, and no recursive child orchestration. These limits keep the user-level workflow inspectable and portable across projects.
