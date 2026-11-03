# Approved constraint continuity

Use this contract to carry a confirmed user or project constraint through a Team task. It applies to ordinary feature work, additions, small changes, debugging and repairs. It does not make every task a full-documentation exercise: read the sources that govern the task and the changed boundary, then carry only the constraints that apply.

## Authority and evidence classes

Keep these kinds of evidence distinct in the Work contract, bounded child context, implementation decisions, tests, review and handoff:

| Class | What it establishes | How to use it |
| --- | --- | --- |
| Confirmed intent | An applicable active PRD/specification, explicit user decision, or existing approved policy establishes the intended behavior and its scope. | Preserve its conditions, limits and approved exceptions. If two applicable authorities conflict, do not choose a winner by age, repetition or convenience. |
| Observed behavior | Inspected source, configuration, tests, command output or a reproducible run establishes what the current system does. | Describe it as current behavior. Do not turn a defect, workaround, test expectation or implementation pattern into new intent. |
| Proposal | A design, recommendation, candidate fix or requested decision has not yet been accepted. | Label it proposed and identify who may decide. Do not implement it as though confirmed. |
| Unknown | The source, behavior, applicability, access or result has not been established. | Keep the gap visible and request focused evidence. Do not fill it with a plausible assumption or a newer local description. |

Authority is topic- and scope-specific. An active applicable product requirement constrains behavior and acceptance; adopted native specifications keep their established authority; architecture and interface documents govern their own boundaries; stage packets and issue records keep task evidence and acceptance. Project instructions govern durable agent working practices but cannot grant authority beyond their scope. Code and tests are evidence of implementation, not approval to change intent. Use the [documentation governance contract](documentation-governance.md#cross-document-consistency) to distinguish complementary statements, legitimate repetition and actual conflicts.

Keep actor packets inside their separate simulation boundary: an AI simulation actor receives only its bounded case input and allowed mock-tool context. Do not pass design discussion, other cases, scoring rubrics or grading criteria to the actor; those belong to the Lead/evaluator side of that workflow. A read-only consultation, documentation assessment or review returns findings and recommendations only. It does not authorize automatic edits to the source, document set, map or policy; a separate bounded write assignment is required.

## Carry constraints through the work

At each stage, supply the next owner with the applicable source and the concrete rule, not merely “follow the requirements.” Reuse the existing Work contract, stage packet, issue record or handoff; do not make a new file for each message or tiny adjustment.

| Stage | Input and action | Return and exit condition |
| --- | --- | --- |
| Readiness | Read the task-relevant instruction chain, active applicable requirements/specification, architecture/interfaces and existing task evidence. Identify source path and revision, applicability, non-goals, exceptions, forbidden paths and unresolved claims. | Record confirmed constraints separately from observed behavior, proposals and unknowns. If the intended behavior or precedence is materially disputed, present exact claims, scope, impact and options to the Lead/user; pause only dependent work. |
| Design | Give the proposer the task outcome, applicable authority, relevant source references, affected boundary, constraints and accepted decisions. Compare proposals against those inputs, including failure/fallback behavior. | Return a proposal that states what it preserves, changes, assumes and leaves unknown. A specialist recommendation or internally consistent design does not amend user intent. |
| Child assignment | Pass a bounded context: goal, applicable requirement/specification revision, non-goals, affected module, relevant approved constraints and exceptions, source links, known implementation facts, unknowns, acceptance evidence and the exact shared guide needed. | The child returns evidence against that assignment. Do not assume another thread inherits the parent's conversation or installed Skill context. Keep unrelated policy and personal/private source content out of the packet. |
| Implementation and wiring | Trace the approved rule to the actual entrypoint, caller, composition/wiring point, configuration and relevant success, failure and fallback paths. Keep adjacent behavior inside the approved scope; do not use a new abstraction, default or fallback to bypass the rule. | Report implemented versus planned behavior and any path not exercised. If new evidence shows a conflict or a needed exception, preserve the current work and return the dependent decision to the Lead/user before proceeding. |
| Tests and acceptance | Map each applicable constraint and material exception to a scenario, expected result and observable boundary. Tests may show implementation behavior; do not treat a green test, fixture, static match or test author agreement as approval of intent. Keep human acceptance and environment-dependent checks distinct. | Record planned, implemented, executed and passing states separately; identify missing cases, inputs and manual acceptance. A case does not become accepted merely because an automated assertion exists. |
| Independent review | Trace confirmed intent through the current source, the actual wiring/caller, implementation, relevant tests and recorded evidence. Inspect changed assumptions and fallback paths, not just symbols or names. | Report missed, changed or unverified constraints with source and impact. Review does not authorize an edit or resolve a disputed requirement. |
| Handoff and close | Carry the current outcome, accepted decisions, source references, changed paths, evidence freshness, unresolved risks, pending acceptance and next owner/checkpoint. Reconcile source-linked development guidance when reusable facts or constraints changed. | State completed, incomplete, canceled, superseded and pending work distinctly. Keep user acceptance pending until there is actual user evidence; retain the existing work history and stable references. |

If a boundary changes or a source changes during work, reassess only the affected constraints and dependent work. Do not restart satisfied gates without a changed input, and do not let a stale snapshot support a current claim.

## Small changes, additions and debugging

Small size does not remove a relevant constraint. For a new endpoint, command or file, check whether an existing approved limit applies to the new surface, entrypoint, side effect or fallback before treating it as an exception. For a small local fix, inspect the relevant authority and changed boundary; do not force a full repository inventory when the scope is already known.

Debugging distinguishes a suspected cause from a confirmed fact and retains the same issue identity and authorized budget through handoffs. A debug investigation does not authorize a repair. An ordinary request to fix an unknown-cause bug does not create extra diagnostic rounds. Follow the [repair and diagnosis loop guard](repair-loop-guard.md) for issue identity, attempts, budgets, pause and resume gates; use [outcome-based handoffs](agent-handoffs.md) to carry the same issue forward without resetting its history.

## Conflict and exception procedure

When a newer document, source pattern, test, role recommendation or proposed abstraction appears to contradict confirmed intent:

1. Quote or summarize both claims precisely and cite their source paths/revisions and applicability conditions.
2. State which work depends on the decision, what evidence is observed, and what remains proposed or unknown.
3. Offer the viable options and a recommendation to the Lead. The Lead obtains the user decision when authority or intended behavior is unsettled.
4. Preserve the disputed source and existing history. Pause only work that relies on choosing between the claims; continue independent authorized work.
5. Record the actual decision and affected scope in the existing Work/decision record, then update downstream design, implementation plan, tests and source-linked guidance as assigned.

An approved exception is bounded to its stated rule, scope and conditions. It does not create a general exception for similar code or future tasks. No child, test, repository convention or local AGENTS edit can grant permission to access a forbidden path, expand a budget, override higher-priority instructions, or perform an unapproved external, installation, Git or destructive action.

## Worked examples

### New capability under a confirmed SDK boundary

An active requirement says application requests must pass through SDK `A`. Existing code sends requests through `A`; a proposed feature adds a provider adapter for provider `B`. Provider identity and SDK/execution path are separate facts: supporting provider `B` does not itself violate the rule if the adapter still sends requests through `A`.

- Record the execution-path requirement as confirmed intent and the existing call as observed implementation. Record provider `B` as an implementation choice only where the requirement does not constrain provider identity.
- Check the actual call path and test boundary. A test that exercises provider `B` through SDK `A` is compatible; a direct provider API call that bypasses `A` conflicts. Test labels alone do not reveal which path ran.
- If the proposed entrypoint bypasses `A`, the Lead presents that actual conflict and its effect, then continues independent work while the user decides whether to preserve `A` or approve a bounded exception. If the abstraction leaves `A` in place, no exception is needed merely because the provider or interface is new.
- Give the implementer and Tester the exact requirement reference and scenario; have review trace the actual call path, not just a test fixture label.

### Debugging a constrained but small defect

A failure occurs in a tiny helper under a confirmed rule that forbids network access. Reproduce it using the local fixture and record the observed failure separately from hypotheses. Keep the same issue and failure history if the first fix fails. Do not add a network lookup merely because it seems quickest; if external evidence is needed, apply the existing repair guard and ask for any authority the lookup requires. Fix authorization remains separate from debug authorization.

### Local documentation appears to approve a broader behavior

A newer module note says “provider-neutral,” while an applicable PRD explicitly requires provider `P`. Do not infer an SDK restriction from the provider requirement. A provider-neutral interface can still call `P`; by itself, that abstraction does not authorize provider `Q`. If a separate applicable authority also requires SDK `A`, assess that execution-path rule independently: calls to provider `P` through `A` can satisfy both constraints, while a direct provider endpoint that bypasses `A` conflicts with the separate SDK rule. If no such SDK authority exists, do not invent one. Record only an actual incompatibility with its precise sources and ask the Lead/user; continue unrelated work and pause only dependent work. After a decision, amend only assigned documents and preserve the old decision's history.

## Discovery and limits

Follow the [Agent development documentation and source-map contract](agent-documentation.md) when a project maintains source-linked development guidance under `docs/agent/` or an existing equivalent. It specifies conditional document placement, selective triggers and read-only Inspect evidence; it does not add a global Codex SDK mandate, make a target application's runtime load these instructions, or turn hashes into semantic approval.
