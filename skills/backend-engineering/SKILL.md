---
name: backend-engineering
description: Build or review backend code using an evidence-backed workflow for API contracts, validation, authorization, service boundaries, integrations, jobs, and error behavior.
---

# Backend engineering

Use this Skill for material server-side work. Read the shared [execution contract](../team-core/references/execution-contract.md) and [execution templates](../team-core/references/execution-templates.md) in full when establishing the Work contract so service behavior, compatibility, and verification are explicit.

When a backend consumes a replaceable Agent/Workflow capability, read the shared [AI capability contract](../team-core/references/ai-capability-contract.md) and agree the boundary with the AI owner. Keep business validation, authorization, persistence and side-effect decisions in their assigned application layer.


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

Read the [code comment](../team-core/references/code-comments.md) and [code readability](../team-core/references/code-readability.md) contracts in full for assigned code/tests. Follow layered comment and per-test explanation requirements, project formatting, and the formatting-only freeze boundary; record self-check outcomes and gaps. Review-only work reports without editing.

Implement the assigned boundary using repository conventions. For a standalone small fix, use the [small-task test rule](../team-core/references/test-acceptance-contract.md#tier-selection-reuse-and-resource-limits) for affected checks and the due handoff; risk/gates still control expansion. Verify the adequate success and material failure paths; include `team-database-specialist` when work reaches the data layer.

Create a Verification record with commands and outcomes, integration evidence, unavailable checks, and remaining operational risk.

## Return paths

- An input, authorization, response, or consumer contract is unclear → return to the Work contract before changing behavior.
- A migration, query, transaction, or data repair becomes material → establish database ownership and use `database-engineering`.
- A failed integration or unavailable dependency prevents verification → report the precise boundary, observed evidence, and smallest next diagnostic step.

## Output contract

Report changed service boundaries, validation and authorization behavior, compatibility considerations, verification evidence, data coordination, and remaining risks.
