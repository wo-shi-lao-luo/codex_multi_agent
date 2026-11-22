# System Design — <outcome>

Use the project language. Present the smallest set of views needed to understand the change. Link the Project Blueprint and applicable decisions or contracts for established behavior and structure.

## Problem, baseline and constraints

- State the expected behavior and evidence for the current path. Identify the affected modules, external integrations, and responsibilities. Label observed behavior, confirmed requirements, proposed changes, and unknowns.
- State quality or compatibility constraints in observable terms where they change the design.

## Proposed system and key flows

- Show the changed module or service boundaries, ownership, placement, and what existing code or platform capabilities the solution reuses.
- For each material flow, walk a concrete, representative input through the real entry point to its observable result. Give the relevant starting records, state, and versions. At each material handoff, identify who acts, what data or evidence they read, what they decide, and what they pass to the next participant. Link the outcomes to the corresponding acceptance case IDs.
- Use runtime diagrams by default for flows involving material cross-component handoffs, persistent writes, asynchronous work, or AI tool calls. Choose the number of diagrams by tracing the data. Give a distinct flow its own view when its entry point, records read or written, responsible component, or observable result materially changes the path. Show approval, conflicts, cancellation, and retries as branches of the same transaction where they share its path. Link to a shared flow at the handoff when another diagram already explains it. A small, straightforward flow can show its entry, data, and result in a few lines.
- Choose the diagram by the design question. Use the [System Design diagram guide](../references/system-design-diagrams.md) for selection, labels, and examples. Use the project's notation or Mermaid. Give each diagram a title and purpose. In each runtime view and its explanation, follow the same concrete input to the observable result.
- For a write, identify who authorizes and validates it, where it commits, what signal allows the UI or caller to report success, and what can be read back on reopening or reloading. For complex writes and workflows, trace a material failure, concurrency, cancellation, retry, or recovery branch that changes the outcome. Show who handles it, what state remains, and what the user or caller sees.
- When more than one durable effect can survive an interruption independently, add a short recovery table or equivalent labeled view. Follow the same operation across the meaningful persistence and acknowledgment boundaries. For each surviving state show the readback proof, user-visible status and action, original or new request identity, permitted effects, and success criterion. Connect the outcomes to case variants in the Test Plan. Apply the [backcheck](../SKILL.md#backcheck-the-document-set) to distinguish deliberate scope selection from incomplete execution.
- Record affected interface semantics, data and migration behavior, security and approval boundaries, compatibility and rollback as applicable. Link precise contracts and code locations.

## Choices and evidence

| Decision | Considered options and meaningful tradeoff | Supporting evidence or remaining uncertainty |
| --- | --- | --- |
| <Decision> | <Why the selected approach fits the confirmed constraints> | <Observed path, primary versioned source, probe, or unresolved premise> |

Verify the current integration and version where a third-party capability is a premise. Surface what the project must still implement. A critical unknown keeps the dependent design conditional.

## Review readiness

Check that the design explains existing and proposed behavior together, the Plan assigns each changed boundary, and the Test Plan can observe the material state or user outcome. Record material differences from an approved design for scoped re-review.
