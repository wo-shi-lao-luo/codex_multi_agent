# Architecture and contract migration

Use this guide when a change materially migrates architecture, a business or service contract, workflow/state behavior, configuration or eligibility rules, persisted data or jobs, or compatibility and recovery behavior. It is a cross-cutting checklist for migration work, not a new architecture authority, product specification, task list, registry, runtime, Agent, or packet schema.

Do not run an exhaustive migration pass for an internal implementation or model change when approved semantics and the external contract remain unchanged. Apply the existing domain guidance, including the [AI capability contract](ai-capability-contract.md) and [record/replay testing contract](ai-record-replay-testing.md), where relevant. Reopen migration analysis only if material evidence or scope changes.

## Authorities and scope

Reuse the applicable active PRD or confirmed user decision for intended behavior, the existing API or architecture source for contract and structure, the [Project Blueprint contract](project-blueprint.md) for module boundaries and structural change, and the existing stage packet for acceptance evidence and results. This guide links those authorities; it does not replace them. Observed implementation is evidence of current behavior, not proof of approved intent.

Bound the migration to affected capabilities, data, callers, versions, and rollout paths. Distinguish confirmed facts, approved decisions, and unknowns. Ask the Lead to obtain focused Explorer facts, architecture judgment, or test-acceptance judgment when the relevant evidence or decision is missing. Keep independent, authorized work separate from work blocked by a contract or user decision.

## Trace behavior into the target

For each material rule or behavior, trace:

| Old behavior or rule and source | Approved target contract or decision | Actual consumers and owner | Tests or acceptance evidence | Disposition |
| --- | --- | --- | --- | --- |

Use exact paths, sections, interface names, case IDs, or other stable references. Include relevant callers, persisted state, side effects, failure paths, and human gates. A code path or test that happens to exist does not make its behavior an approved requirement.

Preserve product invariants while replacing implementation-specific proofs, such as a role name, UI step, storage mechanism, or internal workflow shape, when that proof is no longer part of the approved contract. For each old rule, record whether it is retained, replaced by an approved target rule, kept temporarily through a compatibility bridge, or removed by an explicit user-approved decision. Do not silently treat an unrepresented rule as obsolete. If the new contract cannot express a rule that must be preserved, return to Contract with the missing semantics and affected work; do not bypass the gate or proceed as though the migration is complete.

## Check applicable migration behavior

Map only the facets that apply to this migration. Preserve the semantic distinctions that consumers rely on.

- **Contract and ownership:** required and optional capabilities; defaults; validation and authorization; proposed versus completed actions; response, error, partial-result, event, and side-effect meanings; actual consumers and accountable owners.
- **Workflow and state:** state transitions, terminal conditions, completion and review gates, cancellation, retries, duplicate or late results, locking, idempotency, and recovery. Mark inapplicable facets with a reason.
- **Questions and adoption:** which questions or approvals are required versus optional, what user adoption or confirmation means, and how adoption differs from successful validation. Preserve who can make each decision.
- **Configuration:** identify the configuration actually selected and validated, and distinguish it from values merely stored, defaulted, or displayed. Keep the selected value, validated value, and user-visible value consistent where the contract requires it.
- **Persisted state:** identify existing records, jobs, artifacts, version/revision identifiers, hashes or snapshots that can be invalidated by the change. State which evidence must be migrated, revalidated, rejected, or regenerated; do not assume old values or passes remain valid.
- **Compatibility and rollout:** define supported old/new versions, bridge behavior, ordering, retry safety, rollback or forward recovery, and the point at which old behavior can be retired when those concerns apply.

Do not invent migration behavior to fill a gap. Record the affected consumers and consequence, list viable options when they exist, and return material unresolved intent, precedence, data, or compatibility choices to the Lead for a user decision.

Use existing [role routing](role-routing.md) only when the work needs distinct evidence: Explorer supplies repository facts; Architect assesses software boundaries; assigned Developers check their implementation scope; the ordinary Tester assesses the real software chain; `team-ai-tester` handles only assigned AI behavior evaluation; Reviewer checks the migration map against the change; and Docs reports confirmed document meaning and authority. The Lead coordinates and owns decisions. These are responsibilities, not a required roster for every migration.

## Verification and evidence

Plan verification in the existing stage packet and follow the [Test & Acceptance Contract](test-acceptance-contract.md), including its test tiers, required gates, manual-to-automated mapping, and deferral rules. Use a synthetic or replay boundary fixture through the real consumer/backend path when applicable: exercise the actual storage and state handling, eligibility decision, user operation, and final outcome that the migration promises. Do not bypass that boundary with direct persistence when it would skip the behavior under review.

Keep evidence questions distinct:

- Deterministic software tests establish business rules, state transitions, persistence, eligibility, authorization, error handling, and side-effect controls.
- AI behavior evaluation establishes only the assigned AI behavior cases under the [AI evaluation contract](ai-evaluation.md).
- A live integrated or end-to-end run establishes current wiring and outcome only for the path and conditions it actually exercised.
- Replay establishes how the real consumer handles the recorded boundary interaction; it does not establish live wiring or replacement behavior by itself.

Choose layers and checkpoints according to risk and the existing test contract. Preserve repository-required checks and user manual acceptance. Keep deferred evidence visibly pending with its owner, status, concrete trigger/checkpoint, flush condition, and dependency restriction. A fixture, green component test, or completed local migration step does not by itself prove the product migration is complete.

## Close the migration

Report these outcomes separately:

- **Component complete:** the assigned component or bounded migration step is implemented.
- **Product migration complete:** approved target behavior and every required consumer/data/compatibility transition in scope are implemented, or explicitly scoped out by an approved target decision. A complete map alone is insufficient.
- **Not implemented:** name any required transition that remains outstanding and its dependency impact.
- **Implemented but unverified:** identify each completed transition whose required evidence is still due or unavailable.
- **Verified:** each due verification item has evidence at its required boundary.

For remaining deferred work, name the owner, current status, next trigger/checkpoint, flush condition, and work that must not depend on it. Keep results and human acceptance in the existing packet. Do not infer completion from a status marker, a hash, a migration script finishing, or the absence of a reported error.
