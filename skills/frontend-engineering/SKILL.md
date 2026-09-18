---
name: frontend-engineering
description: Build or review frontend code using an evidence-backed workflow for component boundaries, client state, accessibility, responsive behavior, and browser performance.
---

# Frontend engineering

Use this Skill for material client-side work. Apply the shared [execution contract](../team-core/references/execution-contract.md) and [execution templates](../team-core/references/execution-templates.md) so frontend quality is defined by observable behavior, not only implementation detail.

## When to activate

Use for UI components, client state, user flows, accessibility, responsive behavior, browser performance, or frontend API consumption.

Do not use to introduce a state library, UI library, analytics, client-side secret, or design-system replacement without a project need and user authorization. Route material API or data-contract changes through the Lead and `team-backend-engineer`.

## Discover the interaction surface

1. Identify the framework, design system, component conventions, state patterns, and existing test or browser-verification tools.
2. Trace the user-observable path: entry point, data source, loading, empty, error, success, mutation feedback, and recovery behavior.
3. Inspect accessibility and responsive conventions already used nearby: semantic controls, keyboard behavior, focus management, accessible names, and supported viewport expectations.

## Establish the frontend work contract

Before implementation, define:

```text
User outcome and observable acceptance checks
Component and client-state boundary
API contract consumed or changed
States and feedback: loading, empty, error, success, mutation
Accessibility and responsive expectations
Verification path and representative device or interaction coverage
```

Prefer simple composition and existing project patterns. Keep API contracts explicit; a client workaround is not a substitute for an unresolved backend contract.

## Execute and verify

Implement only the assigned client boundary. Verify the changed interaction through the narrowest meaningful layer: existing component tests, user-observable browser behavior, keyboard navigation, responsive checks, or targeted performance evidence when performance is the stated risk.

Create a Verification record with checks performed, results, evidence, and any unavailable browser or device coverage. Do not call an interaction complete solely because it renders in one state.

## Return paths

- An API response, error state, or mutation contract is unclear → return to the Work contract and coordinate with the Lead or `team-backend-engineer`.
- An accessibility or responsive failure appears → return to Execute with the observed behavior and affected interaction.
- Required browser, device, or authenticated state is unavailable → record the gap and the smallest practical substitute check.

## Output contract

Report changed components or client boundaries, states covered, accessibility and responsive checks, commands or observed behavior, API coordination, and remaining risks.
