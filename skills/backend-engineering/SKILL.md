---
name: backend-engineering
description: Build or review backend code using an evidence-backed workflow for API contracts, validation, authorization, service boundaries, integrations, jobs, and error behavior.
---

# Backend engineering

Use this Skill for material server-side work. Apply the shared [execution contract](../team-core/references/execution-contract.md) and [execution templates](../team-core/references/execution-templates.md) so service behavior, compatibility, and verification are explicit.

## When to activate

Use for APIs, services, authorization, integrations, jobs, server-side state changes, or error behavior.

Do not use to change a material schema, migration, transaction, query plan, index, or data repair without involving `team-database-specialist` and `database-engineering`.

## Discover the service surface

1. Identify the existing route, service, authorization, error, logging, and test conventions around the changed operation.
2. Trace inputs, trusted and untrusted boundaries, callers, response consumers, side effects, retry behavior, and dependencies.
3. Record compatibility concerns: public API shape, error semantics, asynchronous processing, idempotency, and observability requirements.

## Establish the backend work contract

Before implementation, define:

```text
Inputs, validation, and authorization rule
Success and error responses or side effects
Idempotency, retry, timeout, or job behavior when material
Observability and sensitive-data logging boundary
API compatibility and dependent consumers
Verification and data-layer coordination
```

Preserve compatibility unless the approved task changes the contract. Keep secrets and sensitive request or response data out of logs and error responses.

## Execute and verify

Implement the assigned boundary using repository conventions. Run focused unit, integration, contract, or job verification that demonstrates the changed success path and material failure path. Include `team-database-specialist` when the work contract reaches the data layer.

Create a Verification record with commands and outcomes, integration evidence, unavailable checks, and remaining operational risk.

## Return paths

- An input, authorization, response, or consumer contract is unclear → return to the Work contract before changing behavior.
- A migration, query, transaction, or data repair becomes material → establish database ownership and use `database-engineering`.
- A failed integration or unavailable dependency prevents verification → report the precise boundary, observed evidence, and smallest next diagnostic step.

## Output contract

Report changed service boundaries, validation and authorization behavior, compatibility considerations, verification evidence, data coordination, and remaining risks.
