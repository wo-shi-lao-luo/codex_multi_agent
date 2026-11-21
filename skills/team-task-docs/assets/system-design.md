# System Design — <outcome>

Use the project language. Present the smallest set of views needed to understand the change. Link the Project Blueprint and applicable decisions or contracts for established behavior and structure.

## Problem, baseline and constraints

- State the expected behavior and evidence for the current path. Identify the affected modules, external integrations, and responsibilities. Label observed behavior, confirmed requirements, proposed changes, and unknowns.
- State quality or compatibility constraints in observable terms where they change the design.

## Proposed system and key flows

- Show the changed module or service boundaries, ownership, placement, and what existing code or platform capabilities the solution reuses. Show a diagram only where it makes the flow easier to inspect.
- Walk a representative request or user action through the real entry point, interface and state changes to its observable result. Add the material failure, cancellation, retry, or recovery path. Identify who owns effects and failure handling.
- Record affected interface semantics, data and migration behavior, security and approval boundaries, compatibility and rollback as applicable. Link precise contracts, code locations, and corresponding acceptance case IDs.

## Choices and evidence

| Decision | Considered options and meaningful tradeoff | Supporting evidence or remaining uncertainty |
| --- | --- | --- |
| <Decision> | <Why the selected approach fits the confirmed constraints> | <Observed path, primary versioned source, probe, or unresolved premise> |

Verify the current integration and version where a third-party capability is a premise. Surface what the project must still implement. A critical unknown keeps the dependent design conditional.

## Review readiness

Check that the design explains existing and proposed behavior together, the Plan assigns each changed boundary, and the Test Plan can observe the material state or user outcome. Record material differences from an approved design for scoped re-review.
