---
name: team-delivery-check
description: Check Git delivery readiness for a planned commit, push, pull request, merge, release or installation source. Activate explicitly or when delivery intent is clear; ordinary edits and code review alone do not activate it.
---

# Team delivery check

Use the shared [execution contract](../team-core/references/execution-contract.md)
proportionately for Discover → Verify → Handoff; no implementation lifecycle is
required for this read-only assessment.

## When to activate

Act as the Lead adapter for a read-only delivery assessment. Read the shared
[Git delivery contract](../team-core/references/git-delivery.md) in full. It owns
operation scope, policy decisions, freshness and the distinction between mechanical
evidence and semantic readiness. Installation execution remains with the existing
installation guide and its separately authorized deployment preview.

Use [role routing](../team-core/references/role-routing.md) to check the active
catalog for the exact `team-delivery-checker` role before assigning its bounded
assessment. A source TOML or installed receipt does not prove this session exposes
the role. If unavailable, disclose the runtime testing limitation and ask the Lead
for the specific next step; do not silently substitute a generic agent or the Lead.

Supply the operation, exact project root, user intent/authorization, local base and
target identities, applicable policy sources and existing verification/review
evidence. The checker reads and reports; the Lead retains policy proposals and any
separately authorized Git action. Do not activate a full implementation lifecycle
merely to check delivery, and do not add a delivery gate to every code edit.

## Output contract

Return `pass`, `blocked` or `needs-user-decision` with scope, snapshot identity,
policy/evidence inspected, findings and the smallest next step. A pass permits only
the requested readiness conclusion; it is not permission to execute delivery.
Include the actual role invocation and capability-use disclosure in the Lead's
normal handoff. Read-only consultation without a usable scope returns a precise
missing-context decision, not an invented branch or policy.
