# Role routing

The Lead classifies a request before delegating.

| Condition | Roles |
|---|---|
| One-file, low-risk, clear fix | Lead only; optionally `team-explorer` or `team-reviewer` |
| UI, component, browser behavior, client state | One `team-frontend-engineer` owns the coherent page/flow using frontend-design and frontend-engineering; `team-explorer` first when scope is uncertain |
| API, service, auth, jobs, integration | `team-backend-engineer`; `team-architect` for cross-cutting contracts |
| Schema, migration, query plan, index, data repair, transaction | `team-database-specialist`; `team-backend-engineer` consumes the agreed contract |
| Unknown root cause | `team-explorer` plus `team-tester`; `team-architect` when causes span modules |
| Any material implementation | `team-tester` and `team-reviewer` after the writer's first complete pass |

Do not delegate a role merely because it exists. Delegate bounded, independent work with a requested output.

Apply the [UI delivery contract](ui-quality.md) to preserve the original product goal, visual baseline and final-page verification when routing UI work. Small demos normally retain one implementer; page ownership does not remove modular code or file boundaries.
