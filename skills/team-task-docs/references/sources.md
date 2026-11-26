# Research and design choices

These sources informed the authoring and lifecycle choices. Project requirements and the Kit's existing verification contracts govern execution. Use the bundled templates during normal work.

| Source | Adopted practice |
| --- | --- |
| [Agent Skills format](https://agentskills.io/specification) | Put the trigger and workflow in a concise entry point. Load the authoring resources on demand. |
| [Superpowers writing plans](https://github.com/obra/superpowers/blob/main/skills/writing-plans/SKILL.md), [GitHub Spec Kit plan](https://github.com/github/spec-kit/blob/main/templates/plan-template.md) and [task template](https://github.com/github/spec-kit/blob/main/templates/tasks-template.md) | Bind the plan to the specification and project structure. Give work items concrete outcomes, dependencies, and checks. Keep the Kit's existing approval and TDD rules. |
| [Shape Up pitch](https://basecamp.com/shapeup/1.5-chapter-06) | Start with the problem, bound the scope, and surface difficult choices before delivery. |
| [arc42](https://arc42.org/overview/) and [C4](https://c4model.com/diagrams) | Choose relevant views. Show component ownership and a representative runtime flow at the depth needed for review. |
| [ISO test documentation](https://www.iso.org/standard/79429.html), [Google testing layers](https://testing.googleblog.com/2015/04/just-say-no-to-more-end-to-end-tests.html), and [Playwright user-visible behavior](https://playwright.dev/docs/best-practices) | Plan expected results and evidence at useful boundaries. Reserve browser assertions for observable user behavior and use faster tests for broader deterministic coverage. The Agent-first rehearsal and user-only acceptance are Kit rules. |
| [OpenSpec lifecycle](https://github.com/Fission-AI/OpenSpec/blob/main/docs/concepts.md), [Docs as Code](https://www.writethedocs.org/guide/docs-as-code/), and [Microsoft ADR guidance](https://learn.microsoft.com/en-us/azure/well-architected/architect-role/architecture-decision-record) | Apply confirmed additions, replacements and removals to the current docs. Use the same scoped diff and review as implementation. Preserve significant decisions and their successor links separately from general project guidance. |
