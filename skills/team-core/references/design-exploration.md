# Risk-proportional design exploration

## Purpose and scope

`$team-plan` and `$team-dev` use this contract to decide how much design exploration a task needs before work is assigned or implementation starts. The Lead makes the depth decision; this reference is not a new workflow entrypoint, runtime gate, PRD, Blueprint, or second task list. Apply it to task-relevant design decisions, not ordinary explanations or every Team interaction.

Judge depth from **material risk and uncertainty**, not task size, file count, line count, or whether an AI model is involved. A narrow change can need deeper design when it changes a public contract, data/security boundary, migration, recovery behavior, or user-visible acceptance. A larger but already specified change may need only a light check.

| Depth | Use when | Required result |
| --- | --- | --- |
| Light check | The requested behavior and acceptance are clear; relevant decisions are already accepted; the change fits an understood module/interface; no material unresolved boundary or risk is exposed. | Briefly state why the existing contract is enough, verify task/module fit and applicable checks, and continue without manufacturing alternatives or repeating approval. |
| Full exploration | A consequential requirement, module/interface/data boundary, failure/recovery behavior, compatibility/security/migration concern, acceptance rule, or existing-structure fit remains materially uncertain, or relevant new evidence invalidates an accepted decision. A cross-boundary/new-capability task alone is not a reason for full exploration when its contracts and consequences are already clear and accepted. | Gather bounded facts, compare meaningful approaches where they exist, identify the recommendation and open decisions, then return to Contract/readiness before dependent implementation. |

If it is unclear whether uncertainty is material, state the concrete consequence that could change and perform the smallest useful fact check. Do not equate “more discussion” with better design. Use no numeric score or forced alternatives quota.

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

The Lead retains coordination and decision authority. Children report back to the Lead; they do not independently ask the user, authorize implementation, resolve conflicting requirements, or spawn their own design team.

## Bounded role responsibilities

- **Explorer** supplies focused repository facts, existing conventions, interfaces, tests and evidence through the Lead. Do not ask Explorer to decide architecture or repeat a reliable inventory.
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
6. Readiness: what is settled, what evidence/check is still missing, which work is blocked, and which explicitly independent work may proceed.

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
