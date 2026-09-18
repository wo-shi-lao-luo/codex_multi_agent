---
name: database-engineering
description: Design, implement, or review schema, migrations, SQL, indexes, transactions, and data changes using an evidence-backed safety workflow.
---

# Database engineering

Use this Skill for material data-layer work. Apply the shared [execution contract](../team-core/references/execution-contract.md) and [execution templates](../team-core/references/execution-templates.md) to turn database safety requirements into an inspectable change path.

## When to activate

Use for schema or migration changes, data backfills or repair, non-trivial SQL, transaction boundaries, indexes, query plans, or changes that may affect availability, correctness, or recoverability.

Do not use for a purely application-layer change with no material database behavior. Do not treat a destructive operation as routine maintenance.

## Discover before changing data

1. Identify the database engine, schema source of truth, migration conventions, deployment order, and available representative environment.
2. Record the affected data contract: readers and writers, nullability or default assumptions, expected volume, sensitive data, and compatibility window.
3. Inspect existing query and index patterns when performance or locking is material. Distinguish measured evidence from an assumption.

## Establish the database work contract

Before execution, produce a Work contract that includes:

```text
Forward migration or data-change behavior
Application rollout and compatibility order
Rollback or recovery method
Backfill, locking, and performance considerations
Verification queries or observable post-change behavior
Owner for schema, migration, and application contract
```

Use parameterized queries and least-privilege access. A forward-only migration is acceptable only when the recovery path is explicit.

## Execute and verify

Run the narrowest safe validation available: migration against a representative environment, targeted query checks, application compatibility checks, or a documented dry run. For a data mutation, preserve enough evidence to account for rows or records affected and to support recovery.

Create a Verification record with the migration or query run, result, evidence, and remaining operational risk. If a planned environment or query-plan check is unavailable, state the limitation instead of presenting an unmeasured claim as fact.

## Return paths

- An incompatible reader or writer, unexpected data shape, or locking concern → return to the Work contract and revise rollout order.
- A failed migration or verification query → stop the rollout path, preserve evidence, and apply the declared recovery method or escalate.
- A destructive data action without explicit authorization or recovery path → pause and request direction.

## Output contract

Report the affected contract, forward path, recovery path, checks performed and results, row or data accounting when relevant, and remaining risk. Coordinate application usage with `team-backend-engineer`; the database owner retains schema and migration ownership.
