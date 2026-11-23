# Risk-proportional design exploration

## Purpose and scope

`$team-plan` and `$team-dev` use this contract to decide how much design exploration a task needs before work is assigned or implementation starts. The Lead makes the depth decision; this reference is not a new workflow entrypoint, runtime gate, PRD, Blueprint, or second task list. Apply it to task-relevant design decisions, not ordinary explanations or every Team interaction.

Judge depth from **material risk and uncertainty**, not task size, file count, line count, or whether an AI model is involved. A narrow change can need deeper design when it changes a public contract, data/security boundary, migration, recovery behavior, or user-visible acceptance. A larger but already specified change may need only a light check.

| Depth | Use when | Required result |
| --- | --- | --- |
| Light check | The requested behavior and acceptance are clear; relevant decisions are already accepted; the change fits an understood module/interface; no material unresolved boundary or risk is exposed. | Briefly state why the existing contract is enough, verify task/module fit and applicable checks, and continue without manufacturing alternatives or repeating approval. |
| Full exploration | A consequential requirement, module/interface/data boundary, failure/recovery behavior, compatibility/security/migration concern, acceptance rule, or existing-structure fit remains materially uncertain, or relevant new evidence invalidates an accepted decision. A cross-boundary/new-capability task alone is not a reason for full exploration when its contracts and consequences are already clear and accepted. | Gather bounded facts, compare meaningful approaches where they exist, identify the recommendation and open decisions, then return to Contract/readiness before dependent implementation. |

If it is unclear whether uncertainty is material, state the concrete consequence that could change and perform the smallest useful fact check. Do not equate “more discussion” with better design. Use no numeric score or forced alternatives quota.

Repair proposals have a separate concise decision check in the [repair and diagnosis loop guard](repair-loop-guard.md#repair-decision-check), including first and small fixes. Apply it before proposing or materially changing a repair strategy; it does not turn every repair into full design exploration or add a design-approval gate for an evidence-based general fix.

## System fit and behavior

Explain how the proposed behavior works within the existing system before breaking it into implementation tasks. Trace a representative user or system trigger through the relevant existing and new components to its observable outcome. Identify responsibilities, actual callers, dependency direction, data and state ownership, and how changes or side effects propagate. Cover applicable authorization, update/delete behavior, failure, cancellation and recovery paths. State which existing mechanisms are reused, extended, kept alongside the new behavior or replaced, and which product invariants and consumers must remain supported. Affected-file lists and component diagrams alone do not explain that interaction.

For each material mechanism, explain how it achieves the goal and why it fits the current architecture. Compare real alternatives when they exist, including suitable existing capabilities under [reuse and third-party guidance](reuse-and-third-party.md). Keep structural ownership in the existing Blueprint and material old-to-new behavior mapping under [architecture and contract migration](architecture-migration.md); do not duplicate those authorities. Apply this check proportionately: a light check may cite an established flow and describe its bounded delta instead of producing a full system inventory or reopening accepted decisions.

## Critical premises and technical evidence

Distinguish a **critical design premise** from a deferrable implementation detail. A premise is critical when a contrary finding would change feasibility, the main technical approach, an interface or ownership boundary, required permissions, or state/lifecycle semantics. Local implementation choices within established contracts, and later optimization measurements that do not determine feasibility, may remain in the implementation plan with their applicable verification checkpoint. Unbuilt business behavior is a proposed implementation, not something that must already exist before it can be designed.

Before declaring an affected design decision ready for implementation, the Lead must resolve its critical factual premises with the smallest sufficient reliable evidence. Start from the actual repository call path and selected dependency/runtime version, reuse still-applicable verified evidence, and consult the relevant official documentation, source or version-specific protocol when needed. If those do not establish a consequential behavior, use a bounded capability check or minimal experiment within existing authority. Documentation silence alone does not establish that a capability is absent; distinguish unsupported, unverified and verified behavior. Do not install a dependency, spend on a service, call a real model or run full E2E merely to satisfy this checkpoint; obtain any additional authority actually needed.

Assess evidence needs for each material technical choice. Use [external research](external-research.md) when external evidence is needed: official documentation for supported behavior, source/protocol/tests for implementation semantics, and original research for research claims. Check applicability, versions, conditions and limitations. Papers, popularity and citations alone do not establish project suitability. There is no mandatory network search, paper quota, benchmark, or extra Researcher/Architect for every design. Keep research bounded to the decision it can change.

At the design decision itself, retain the chosen mechanism and rationale, its system interaction, evidence references and applicable version/conditions, known limitations, and remaining project verification. Separate native or third-party capability that can be reused from application behavior that must be added. State what the evidence establishes: documentation, source/protocol inspection, a local synthetic probe, live integration and model behavior have different scopes. A passing capability probe does not establish unimplemented business logic, production readiness or model quality. Use the existing design/Work/Blueprint record, not a separate evidence registry or mandatory new document schema.

If a role reports a critical premise as unknown or conflicting, its handoff names the affected conclusion, consequence and smallest useful next check. The Lead owns the dependency judgment and returns the affected work to Discover; listing that premise as a future P0 task or generic risk does not make the dependent design decision-ready. If evidence cannot be obtained, present an explicitly conditional candidate with its assumptions and affected work pending, and continue only independently supported parts. A user-owned product or compatibility choice still requires the existing decision path. Keep feasibility investigation separate from tests that verify the later implementation, and recheck prior evidence only when its relevant inputs, versions, conditions or scope change.

## Design and plan backcheck

After forming or materially revising a formal design or implementation plan, backcheck the current draft before handoff, including an in-chat deliverable. The Lead may perform this check; delegated authors check their own formal proposals before returning them. Scale depth to risk and changed scope. A simple, sufficiently evidenced task may use a brief check of its delta and established contracts. Headings, keywords, links and case IDs are not evidence that the design works.

Use the applicable lenses below, tracing actual meaning and behavior:

1. **Goal and authority → proposal:** compare the current draft with confirmed user goals, constraints and non-goals. Find omissions, narrowed outcomes, unapproved additions and proposals presented as accepted decisions. Preserve the distinction between a model's proposed intent and trusted user authorization, including any required continuity across turns or handoffs.
2. **Representative journey → system:** trace entry, existing/new modules, data, authorization and state, side effects, receipts/events and the visible outcome through actual consumers and relevant current contracts. For new components, mark their paths and behavior as planned. Check task/resource ownership and necessary failure/recovery branches; ensure evidence, review/confirmation states and their effects reach the applicable read/write paths. Do not infer that a UI card or isolated new tool updates every existing consumer. Distinguish requested, applied, denied and unknown outcomes; a missing receipt alone does not prove an operation never ran.
3. **Key promise → evidence:** apply the critical-premise check above to versions, capabilities, current code and retained constraints. Identify contradictions between the proposed behavior and existing validation, permissions or lifecycle. Separate verified platform support, integration still to build, and behavior still to validate; do not claim end-to-end completion from a lower-level capability check.
4. **Design → plan and acceptance:** map each material behavior to a bounded task, owner, dependencies and observable verification. Check dependency cycles, vague catch-all work, omitted existing call paths or result projections, and feasibility investigation disguised as a future implementation task. An unresolved critical premise cannot be cleared by merely adding a task to investigate it later.
5. **Implementer → contract:** identify gaps that would let two reasonable implementers produce different product behavior. Leave local technical choices within established contracts to the implementer. Return unresolved scope, authorization or data/behavior semantics to the appropriate Contract or user-decision path; do not fill them by inventing permission, changing prompts in place of enforcement, weakening acceptance, or treating an author's preference as user approval.

Record the checked scope, conclusion, actual evidence, resulting revisions and remaining decisions in the existing design, plan, Work or verification record. Distinguish Lead/author self-check from an actual independent review and retain unavailable or failed role calls as gaps, never passes. Select independent review only when the applicable risk contract or a concrete independent judgment requires it; this checkpoint does not mandate another Agent, research, papers, model calls, packaging or full E2E for every plan. A missing required independent gate remains pending without stopping independently authorized work.

Judge readiness by the supported slice: keep unresolved core contracts or premises pending for their dependent work, and identify independently supported parts that may proceed. Do not give a blanket green light to a mixed-readiness document or escalate every implementation detail to user approval. After corrections, recheck the affected conclusions and dependencies; reuse unaffected evidence and stop when due checks are satisfied. Preserve existing investigation/repair limits and remaining gaps rather than creating an unlimited full-document review loop or a second task system. Source-forward checks of these instructions do not prove native Agent adherence.

## Lead-owned context and reference handoff

Before requesting a design proposal or scoped child check, the Lead supplies the task-relevant context:

- the overall user goal and bounded task scope;
- the applicable active PRD and revision, if any;
- the applicable approved design or Blueprint path and revision, if any;
- accepted user decisions and their scope, plus explicit non-goals;
- relevant constraints, repository evidence and current baseline;
- known assumptions, unresolved questions and missing evidence;
- the applicable shared contract/reference and what the child is expected to return.

Include only relevant context; distinguish confirmed facts, user decisions, observations, assumptions and unknowns. Do not send a PRD as authority when it is draft, historical, or outside the task's applicability. Do not assume a child inherits the Lead's conversation or has access to an installed Skill/reference: explicitly supply the applicable reference or its resolved installed location when the assignment depends on it. Agent TOMLs and Skills may install into separate roots, so do not rely on a repository-relative path from an agent profile.

The Lead retains coordination and decision authority. Factual evidence and reproduction details may pass directly between peers only under the Lead's explicit same-task grant and the [peer communication contract](peer-communication.md). Children do not independently ask the user, authorize implementation, resolve conflicting requirements, or spawn their own design team.

## Bounded role responsibilities

- **Explorer** supplies focused repository facts, existing conventions, interfaces, tests and evidence. Under an explicit peer grant, it may give those facts directly to the named recipient; architectural judgments still return to the Lead. Do not ask Explorer to decide architecture or repeat a reliable inventory.
- **`team-architect`** provides a read-only software-architecture proposal when module boundaries, composition, interfaces or structural evolution are materially uncertain. The Lead supplies sufficient repository evidence; request only bounded additional exploration when needed.
- **`team-ai-architect`** provides a read-only AI-domain proposal when prompt/context/model/tool/routing/state or AI-specific evaluation choices are material. Overall software architecture remains with `team-architect`.
- **Implementation owners and Tester** may make scoped light checks against the accepted design and assigned boundaries. If evidence reveals a new material design gap, stop the affected work and return it to the Lead for Contract; do not silently redesign or turn a light check into broad independent architecture work.
- **Bounded simulation actors** remain exempt. They act only on the supplied behavior-test packet and must not receive this contract, architecture discussion, other cases, or grading criteria as part of that runtime packet. The Lead keeps design coordination outside simulation calls.

Do not invoke every role by default. The Lead selects only roles that address a concrete uncertainty, following shared role-routing and named-role preflight.

## Proposal and decision record

For full exploration, return a concise proposal that separates:

1. **Observed facts** with source paths/evidence from **assumptions** and unknowns.
2. The current/as-is baseline from any proposed target. For existing structure, describe only task-relevant evidence; do not infer defects from age or file length.
3. **Meaningful alternatives** and their trade-offs when real options exist. Recommend one with a reason; do not force three options or invent an artificial alternative.
4. Affected modules, ownership, files, interfaces/data, errors/failure paths, compatibility, acceptance and recovery, to the extent the task makes them relevant.
5. Exact unresolved user decisions, why they matter, viable options and a recommendation. If no material decision remains, say so.
6. Readiness: what is settled, which critical premises have supporting evidence, what evidence/check is still missing, which conclusions and work remain conditional or blocked, and which explicitly independent work may proceed. Include the applicable system-fit and decision evidence above; keep details with the decision rather than only in future tasks.

The Lead records accepted decisions, applicable source revisions, design depth and rationale in the existing Work contract, Blueprint, OpenSpec change (only when opted in), or stage packet as appropriate. Reuse the authoritative record; do not create a competing PRD, Blueprint, planning document or implementation task list merely to preserve this conversation.

## Approval, reuse and return paths

- Preserve active PRD/OpenSpec authority and all existing user approval requirements. Recommendations are not user decisions.
- Do not resolve substantive ambiguity on the user's behalf. Present the exact question and recommendation, then pause only the dependent work. Independent work can continue only when already authorized and demonstrably unaffected.
- Existing-code structural refactoring still requires explicit user approval for its bounded scope. If declined or deferred, record the decision and retained constraints, use the actual baseline, and continue the authorized task within it where feasible.
- Do not add an approval gate for a decision the user already made and that still applies. Reuse accepted decisions while their scope and supporting evidence remain current.
- Reopen only affected decisions/boundaries when relevant new evidence, requirements, or scope changes. Do not repeat the entire exploration because unrelated files or facts changed.
- Keep exploration bounded: after a sufficient fact check or proposal, return to Contract/readiness. Do not start an endless ideation loop or expand scope without authority. Exploration does not reset or expand existing repair/debug budgets; diagnostic checks conducted under debug remain subject to the existing guard.
- If later implementation reveals an unanticipated material boundary or invalid assumption, stop only affected assignments and return to Contract. Do not bypass the approved design or silently grow the file scope.

Full exploration does not itself approve code changes, target `AGENTS.md` edits, a refactor, test exceptions, resource spending, a commit, or an external operation. Apply their existing authorization gates. Design readiness is not test passage or user acceptance.
