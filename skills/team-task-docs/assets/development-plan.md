# Development Plan — <outcome>

Use the project language. Keep existing task IDs and links. Replace prompts with evidence or a scoped unknown. Include conditional sections only when the change needs them.

## Outcome and scope

- State the desired user or operational result and the problem that makes it necessary.
- Link the authoritative requirement, confirmed constraints, System Design, and Test Plan or stage packets. Name explicit exclusions and scope/budget limits that affect the plan.
- Identify the inspected baseline and any decision that must be resolved before dependent work begins.

## Implementation order

| Work item | Owner or responsibility | Prerequisites | Deliverable and affected boundary | Verification and case IDs |
| --- | --- | --- | --- | --- |
| <ID> | <Who owns the result> | <Decision, contract or earlier item> | <One observable increment and relevant module paths> | <How to observe it and where the acceptance case lives> |

Sequence shared contracts before dependent implementation. Use independent batches only where inputs and write ownership are clear. If a tracker or native task file already owns the list, link its work items and explain sequence or decisions here.

## Checkpoints and handoff

- Identify fast checks during iteration, the first usable integrated chain, and the stage or feature ready for acceptance. Link the Agent E2E and human validation steps instead of copying them.
- For material migrations or rollout, state the order, prerequisites, rollback or recovery condition, and which downstream behavior must remain supported.
- List likely long-term docs affected by the actual change. Confirm the final updates at handoff.

## Review readiness

Check each promised result against a work item and an observable acceptance case. Show the decisions that still need the user, plus the independently ready portion if any.
