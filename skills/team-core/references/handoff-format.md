# Handoff format

Every child agent returns a concise handoff:

- **Result:** conclusion or completed bounded work.
- **Evidence:** files, commands, tests, or observations supporting it.
- **Risks:** unresolved assumptions, conflicts, or required decisions.
- **Next step:** the smallest useful action for the Lead.

Writers add changed files and verification performed. Reviewers rank findings by impact and include file references.

For applicable UI work, follow the [UI delivery contract](ui-quality.md): include the brief/baseline reference, functional results, separate visual status, final-page route/viewport/state evidence, fixes and remaining gaps. Agent visual checks do not imply user approval.
