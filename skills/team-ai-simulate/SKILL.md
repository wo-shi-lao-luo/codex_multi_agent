---
name: team-ai-simulate
description: Prototype and evaluate a bounded AI agent or AI workflow locally with controlled cases, explicit context, mock tools, and recorded inputs and outputs before deciding whether to engineer it.
---

# Team AI simulation


## When to activate

Activate only on explicit requests to simulate, prototype, or exercise an AI agent/workflow; this is not generic simulation or an ordinary development stage. For a standalone product fix, use the [small-task test rule](../team-core/references/test-acceptance-contract.md#tier-selection-reuse-and-resource-limits), not AI simulation. A passing prototype does not authorize production implementation.

Read the shared [execution contract](../team-core/references/execution-contract.md), [role routing](../team-core/references/role-routing.md), [handoff format](../team-core/references/handoff-format.md), [AI simulation contract](../team-core/references/ai-simulation.md), and [AI evaluation contract](../team-core/references/ai-evaluation.md) in full. Before actor calls, establish the bounded flow, purpose, target versus simulation model, context and call limits; preflight the exact selected `team-ai-simulation-actor-basic` or `team-ai-simulation-actor-advanced` and `team-ai-tester` roles against the active catalog. The AI Tester owns scenario coverage and independent scoring; the Lead owns orchestration and mock results. Preserve applicable packet requirements and never silently substitute an unavailable role.

For material unresolved AI design choices, the Lead may request a bounded read-only proposal from `team-ai-architect`; it is not required for every simulation. Use `team-architect` for software-wide structure and cross-module boundaries. The Lead coordinates both scopes and resolves shared contracts before any implementation role begins.

The Lead owns flow/context assembly, routing, mock responses and definition ownership. The actor answers only approved packets; it does not orchestrate children, edit production files, change its rules or certify itself. The AI Tester does not edit definitions or use the actor context to score its behavior. Keep expected criteria/scoring outside the actor packet, while acknowledging that shared files and native threads are not a security boundary.

Use the AI simulation contract's profile-selection rule: basic when the distinction is unclear, advanced only when justified. Pause for user-approved proxy if the exact target is unavailable; never silently downgrade or treat proxy pass as target acceptance.

The [AI simulation contract](../team-core/references/ai-simulation.md) owns requested-versus-actual model identity, TOML precedence and proxy evidence; keep unknown runtime metadata unknown and never infer it from a source profile.

Use the AI simulation contract's `docs/ai-workflows/<flow>/` source conventions and bounded local run folder. It owns definition fields, helper lifecycle (`Validate`, `InitializeRun`, `RecordCall`, `Status`), evidence integrity, and retention; the helper records but does not run models, stop inference, prove host inputs, or approve outcomes.

The simulation contract owns context modes, fresh-context behavior, call budgets and case planning. Follow it in full; a fresh thread does not remove host instructions/shared-file access, so never claim isolation or exact API-request reproduction.

Keep only synthetic, redacted inputs and observed outputs; leave unavailable actual model, effort, time or usage unknown, and never log hidden chain-of-thought.

The simulation contract owns source/run locations, `Protect`/`Check`, conflict handling and retention. Keep the existing stage packet as the concise acceptance summary; never untrack automatically or clean data outside the task-owned retention decision.

An accepted simulation only supports a behavior-prototype decision. It does not authorize production implementation. Engineering requires a separate user decision and `$team-dev`; route prompt, context, model, tool protocol, workflow state and AI-runtime logic to `team-ai-engineer`, with the normal test and independent-review roles. Use `backend-engineering` for generic APIs, authorization, service infrastructure or jobs, and declare non-overlapping ownership when both roles are needed. Prefer the approved workflow/prompt source as the single source of truth and turn accepted cases into runtime regression tests during engineering.

## Return paths

- Missing evidence, ambiguous acceptance, failed calls, exhausted capacity, or unavailable roles → follow the full AI-simulation and role-routing contracts; pause affected work, preserve attempts, and never extend budgets or substitute silently.
- Prototype accepted and user chooses implementation → hand off to `$team-dev` as a separately authorized stage; the prototype pass itself is not approval.

## Output contract

Return the flow revision; declared case coverage and calls completed; the AI Tester's independent assessment; requested versus host-confirmed model metadata; context mode and supplied-packet/host-context limits; mock versus real boundary; remaining call budget and thread-capacity limits; evidence and source-drift status; cleanup/retention status; and any decision needed. Distinguish prototype evidence from target-model/runtime acceptance and point to the stage packet for the authoritative project result. Include the actual child roster and selector/handle evidence using the handoff format; do not claim that an intact helper ledger means behavioral acceptance.
