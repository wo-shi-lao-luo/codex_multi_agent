# System Design — <outcome>

Use the project language. Present the smallest set of views needed to understand the change. Link the Project Blueprint and applicable decisions or contracts for established behavior and structure.

## Problem, baseline and constraints

- State the expected behavior and evidence for the current path. Identify the affected modules, external integrations, and responsibilities. Label observed behavior, confirmed requirements, proposed changes, and unknowns.
- State quality or compatibility constraints in observable terms where they change the design.

## Proposed system and key flows

- Show the changed module or service boundaries, ownership, placement, and what existing code or platform capabilities the solution reuses.
- Walk one concrete, representative input through the real entry point to its observable result. Give the relevant starting records, state, and versions. At each material handoff, identify who acts, what data or evidence they read, what they decide, and what they pass to the next participant.
- Default to one runtime diagram for a flow involving material cross-component handoffs, persistent writes, asynchronous work, or AI tool calls. Use the project's diagram notation or Mermaid. Use a sequence diagram when order matters, a numbered flow for data transformation or routing, or a state diagram when transitions are the central decision. Label arrows with the request, data, or event and its relevant state or version. Use the same example in the diagram and any explanatory notes. A simple local read can show its entry, read, and result in a few lines.
- For a write, identify who authorizes and validates it, where it commits, what signal allows the UI or caller to report success, and what can be read back on reopening or reloading. For complex writes and workflows, trace a material failure, concurrency, cancellation, retry, or recovery branch that changes the outcome. Show who handles it, what state remains, and what the user or caller sees. Link these outcomes to the corresponding acceptance case IDs.
- Record affected interface semantics, data and migration behavior, security and approval boundaries, compatibility and rollback as applicable. Link precise contracts, code locations, and corresponding acceptance case IDs.

## Choices and evidence

| Decision | Considered options and meaningful tradeoff | Supporting evidence or remaining uncertainty |
| --- | --- | --- |
| <Decision> | <Why the selected approach fits the confirmed constraints> | <Observed path, primary versioned source, probe, or unresolved premise> |

Verify the current integration and version where a third-party capability is a premise. Surface what the project must still implement. A critical unknown keeps the dependent design conditional.

## Review readiness

Check that the design explains existing and proposed behavior together, the Plan assigns each changed boundary, and the Test Plan can observe the material state or user outcome. Record material differences from an approved design for scoped re-review.
