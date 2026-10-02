# Execution contract

This contract gives team workflows a shared execution shape. It is a harness for producing evidence-backed engineering work, not a replacement for repository instructions or domain expertise.

## Apply the minimum complete path

Every task moves through these stages:

```text
Context → Discover → Contract → Execute → Verify → Handoff
```

For a small, clear task, the Lead may combine Context, Discover, and Contract in one short pass. It must still establish the intended outcome, relevant repository facts, acceptance checks, and verification approach before claiming completion.

## Minimum team and complete obligations

For code-changing `$team-dev` work, use one named domain implementation owner and `team-tester` by default, including small bounded tasks. The Tester prepares a concise coverage and verification plan before implementation, then verifies the completed change; keep test-file ownership separate from production-code ownership. Every material implementation also receives an independent `team-reviewer` review after the writer's complete pass, regardless of task size. Risk, unfamiliar boundaries and materiality determine whether additional Explorer, Architect or domain roles are needed; do not force them when the task does not require them.

Task size may shorten the record and reduce the number of roles, but does not remove applicable lifecycle checks. The Lead still establishes task-doc sufficiency and active PRD authority; applies Blueprint only when its contract's conditions are met; creates or reuses the required stage packet and obtains TDD/coverage decisions; checks applicable manual, E2E and other test layers; applies code-comment and relevant domain/UI requirements; verifies actual outcomes; and reports remaining gaps. Do not require every document category or test layer when the applicable contract marks it conditional or unnecessary.

This implementation-role minimum does not require an implementer or Tester for pure consultation, read-only investigation, planning or review workflows. Team workflows still follow this contract proportionately. A `$team-debug` investigation may use bounded diagnostic reproduction and controlled experiments under its current contract, but that does not authorize a production repair; any authorized code repair enters the `$team-dev` implementation path. Ordinary application scripts and configuration follow their domain; behavior-changing Skills, policies or agent-routing/configuration that govern the harness are implementation work, not trivial prose. Truly nonbehavior typo/format corrections may remain Lead-owned.

Lead-only implementation requires either the user's explicit request that the Lead personally implement the change or the user's approval of a specific proposed Lead-only exception. A general request to make a change does not choose its owner. Only this approved exception replaces the separate Tester assignment: the Lead performs Tester planning and execution duties as self-check, not independent Tester evidence. A material implementation still requires independent `team-reviewer` review. If the user's no-delegation instruction conflicts with that review requirement, explain the conflict and ask for scoped direction; do not self-certify or treat an empty roster as an acceptable review. Lead-only does not waive stage evidence. If a required named role has no legitimate fit in the active catalog, pause and ask about an explicit alternative; never silently substitute a generic role or the Lead.

At start, briefly record task type/risk, applicable standards, intended named roles/ownership and planned checks. At close, reconcile them with actual role-selector/handle evidence, completed checks, outcomes and gaps in the existing Work/Verification record or stage packet. These are inspectable workflow obligations, not an unbypassable runtime gate.

## 1. Context

**Input:** user request and applicable project instructions.

**Output:** a concise task record containing the intended outcome, constraints, known acceptance checks, and open questions.

**Exit:** the Lead can state what success means, or reports the missing decision that prevents safe progress.

## 2. Discover

**Input:** task record and repository.

**Output:** evidence about the relevant files, existing conventions, test or verification entrypoints, dependencies, and material risks.

**Exit:** the team has enough repository facts to choose an approach. If uncertainty remains material, assign a bounded investigation rather than treating an assumption as fact.

## 3. Contract

Apply [documentation governance](documentation-governance.md): assess task-specific sufficiency before implementation, adopt unchecked existing projects, classify changed docs and recheck stale evidence. Respect active applicable PRDs, preserve optional document categories, and ask the user before resolving substantive ambiguity. Lead owns readiness; only explicitly independent authorized work proceeds under a partial review.

For every documentation path in the Work contract, state its content purpose/source-of-truth responsibility and allowed scope. Follow [file ownership](file-ownership.md): when authorized content edits reveal evidence-backed defects in relevant active docs, correct them within that assigned boundary and recheck affected links/indexes. Route cross-owner fixes to the Lead for a bounded assignment; do not let this become broad cleanup or rewrite history. Review the actual documentation diff for placement, factual accuracy, duplication and alignment with its assigned purpose. Read-only assessments report issues without making repairs; substantive ambiguity remains subject to the user's decision.

When a task includes persistent diagnosis or repair, declare its mode, issue identity, existing history, allowed budget, and stop condition in the Work contract before another attempt. Apply the [repair and diagnosis loop guard](repair-loop-guard.md) across roles and handoffs; do not start another retry until its retrospective or pause gate is satisfied.

For new applications, multi-stage work or material boundary changes, apply the [Project Blueprint contract](project-blueprint.md) before the stage contract. Discover existing code before adopting a baseline. Existing-code structural refactoring requires explicit user approval; declining it preserves the baseline with recorded constraints. Map each stage to modules and file responsibilities, and review that mapping against the final diff.

**Input:** task record and discovery evidence.

**Output:** a work contract with:

- acceptance checks;
- affected boundary or API/data contract, if any;
- named owner for each changed area;
- verification to run after the work;
- rollout, recovery, or compatibility considerations when material.

**Exit:** each writer has bounded ownership and no two writers are assigned the same shared contract.

Apply [role routing](role-routing.md) before delegation: verify needed named roles in the active tool catalog, select them explicitly, and record expected versus available profiles. Missing roles require a user decision before an alternative; task labels are not role selection.

## 4. Execute

For code changes, apply the [code comment contract](code-comments.md) while implementing and updating affected explanations.

**Input:** approved work contract.

**Output:** the bounded implementation, investigation result, or review result requested by the Lead.

**Exit:** the assigned work is complete enough for independent verification. A newly discovered scope change returns to Contract; it is not silently absorbed into the current assignment.

For documentation changes, apply the assigned document purpose while editing. Inspect relevant connected documents and repair clear, evidenced defects that are within the assignment; send cross-owner or ambiguous findings back through the Contract/decision path instead of silently expanding scope.

## 5. Verify

Include the code comment contract's writer self-check and, when review is assigned, semantic comment review. Record inspected scope and outcome; automated checks alone do not establish comment correctness.

**Input:** completed work and the verification plan.

**Output:** actual verification evidence: commands and results, inspected behavior, or a clear account of why a planned check could not run.

**Exit:** acceptance checks have evidence, or the remaining gap is explicitly recorded as a risk for the Lead to decide.

Reconcile the invocation ledger against actual role-selector arguments, returned agent handles and available identity evidence. Disclose deviations and unknown models rather than inferring runtime identity from source configuration.

## 6. Handoff

**Input:** completed and verified bounded work.

**Output:** the shared [handoff format](handoff-format.md): Result, Evidence, Risks, and Next step. Writers add changed files and verification; reviewers rank material findings by impact.

**Exit:** the Lead can integrate the result, request a focused follow-up, or close the task without reconstructing the child agent's reasoning.

The Lead's final response must include the actual child-agent roster from the handoff format, including created failed/interrupted agents and retries, or explicitly state that no children were used. Separate failed creation attempts from created agents.

## Return paths

- Missing repository facts or conflicting observations → return to **Discover**.
- New compatibility, ownership, or scope concern → return to **Contract**.
- Failed or incomplete verification → return to **Execute** with the evidence.
- A decision only the user can make → hand off the decision with options and pause the affected work.
- Repeated failure or unproductive diagnosis → check the [repair and diagnosis loop guard](repair-loop-guard.md) before another attempt; pause with its evidence-led report when a limit or earlier decision gate is reached.

## Workflow adapters

Every `team-*` workflow Skill that applies this contract should state:

1. when it activates and what is out of scope;
2. which stages it owns or delegates;
3. its required evidence and handoff output;
4. which return paths apply to its task type.

Domain Skills add the standards needed inside Discover, Contract, Execute, and Verify. They do not redefine the common lifecycle.
