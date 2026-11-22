# Development Plan — <outcome>

Use the project language. Keep existing task IDs and links. Replace prompts with evidence or a scoped unknown. Include conditional sections only when the change needs them.

## Outcome and scope

- State the desired user or operational result and the problem that makes it necessary.
- Link the authoritative requirement, confirmed constraints, System Design, and Test Plan or stage packets. Name explicit exclusions and scope/budget limits that affect the plan.
- Identify the inspected baseline and any decision that must be resolved before dependent work begins.

## Implementation order

| Work item | Owner or responsibility | Prerequisites | Deliverable and affected boundary | Verification due and case IDs |
| --- | --- | --- | --- | --- |
| <ID> | <Who owns the result> | <Decision, contract or earlier item> | <One observable increment and relevant module paths> | <How to observe it and where the acceptance case lives> |

Name the capability and evidence available from the baseline or preceding work at each milestone. If a check spans milestones, state the distinct assertion that can run at each and link the full case. Sequence shared contracts before dependent implementation. Use independent batches only where inputs and write ownership are clear. If a tracker or native task file already owns the list, link its work items and explain sequence or decisions here.

## Checkpoints and handoff

- Identify fast checks during iteration, the first usable integrated chain, and the stage or feature ready for acceptance. Link the Agent E2E and human validation steps instead of copying them.
- For material migrations or rollout, state the order, prerequisites, rollback or recovery condition, and which downstream behavior must remain supported.
- When a critical premise affects feasibility or scope, link the early probe and name the decisions or work that depend on it. State the independently supported work if its evidence is pending.
- At a workspace transfer, use the [receiving check](../SKILL.md#receive-the-document-set) for each authority, including any Git-ignored test plan.
- List likely long-term docs affected by the actual change. Confirm the final updates at handoff.

## Review readiness

Check each promised result against a work item and an observable acceptance case. Show the decisions that still need the user, plus the independently ready portion if any.
