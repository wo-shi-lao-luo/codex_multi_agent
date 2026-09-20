# Execution contract

This contract gives team workflows a shared execution shape. It is a harness for producing evidence-backed engineering work, not a replacement for repository instructions or domain expertise.

## Apply the minimum complete path

Every task moves through these stages:

```text
Context → Discover → Contract → Execute → Verify → Handoff
```

For a small, clear task, the Lead may combine Context, Discover, and Contract in one short pass. It must still establish the intended outcome, relevant repository facts, acceptance checks, and verification approach before claiming completion.

## 1. Context

**Input:** user request and applicable project instructions.

**Output:** a concise task record containing the intended outcome, constraints, known acceptance checks, and open questions.

**Exit:** the Lead can state what success means, or reports the missing decision that prevents safe progress.

## 2. Discover

**Input:** task record and repository.

**Output:** evidence about the relevant files, existing conventions, test or verification entrypoints, dependencies, and material risks.

**Exit:** the team has enough repository facts to choose an approach. If uncertainty remains material, assign a bounded investigation rather than treating an assumption as fact.

## 3. Contract

For new applications, multi-stage work or material boundary changes, apply the [Project Blueprint contract](project-blueprint.md) before the stage contract. Discover existing code before adopting a baseline. Existing-code structural refactoring requires explicit user approval; declining it preserves the baseline with recorded constraints. Map each stage to modules and file responsibilities, and review that mapping against the final diff.

**Input:** task record and discovery evidence.

**Output:** a work contract with:

- acceptance checks;
- affected boundary or API/data contract, if any;
- named owner for each changed area;
- verification to run after the work;
- rollout, recovery, or compatibility considerations when material.

**Exit:** each writer has bounded ownership and no two writers are assigned the same shared contract.

## 4. Execute

**Input:** approved work contract.

**Output:** the bounded implementation, investigation result, or review result requested by the Lead.

**Exit:** the assigned work is complete enough for independent verification. A newly discovered scope change returns to Contract; it is not silently absorbed into the current assignment.

## 5. Verify

**Input:** completed work and the verification plan.

**Output:** actual verification evidence: commands and results, inspected behavior, or a clear account of why a planned check could not run.

**Exit:** acceptance checks have evidence, or the remaining gap is explicitly recorded as a risk for the Lead to decide.

## 6. Handoff

**Input:** completed and verified bounded work.

**Output:** the shared [handoff format](handoff-format.md): Result, Evidence, Risks, and Next step. Writers add changed files and verification; reviewers rank material findings by impact.

**Exit:** the Lead can integrate the result, request a focused follow-up, or close the task without reconstructing the child agent's reasoning.

## Return paths

- Missing repository facts or conflicting observations → return to **Discover**.
- New compatibility, ownership, or scope concern → return to **Contract**.
- Failed or incomplete verification → return to **Execute** with the evidence.
- A decision only the user can make → hand off the decision with options and pause the affected work.

## Workflow adapters

Every `team-*` workflow Skill that applies this contract should state:

1. when it activates and what is out of scope;
2. which stages it owns or delegates;
3. its required evidence and handoff output;
4. which return paths apply to its task type.

Domain Skills add the standards needed inside Discover, Contract, Execute, and Verify. They do not redefine the common lifecycle.
