---
name: team-ai-simulate
description: Prototype and evaluate a bounded AI agent or AI workflow locally with controlled cases, explicit context, mock tools, and recorded inputs and outputs before deciding whether to engineer it.
---

# Team AI simulation

## When to activate

Activate only when the user explicitly asks to simulate, prototype, or exercise an AI agent or AI workflow design. This Skill does not cover generic non-AI workflow simulation and is not an automatic stage in ordinary software development. Do not infer authorization to turn a passing prototype into production implementation.

Read the shared [execution contract](../team-core/references/execution-contract.md), [role routing](../team-core/references/role-routing.md), [handoff format](../team-core/references/handoff-format.md), and [AI simulation contract](../team-core/references/ai-simulation.md). Before actor calls, establish the bounded flow, purpose, target versus simulation model, context and call limits; preflight the selected `team-ai-simulation-actor-basic` or `team-ai-simulation-actor-advanced` and `team-tester` roles against the active tool catalog. The Tester owns scenario coverage and independent scoring/verification; the Lead owns orchestration and mock results. Preserve the stage packet requirements of the project workflow. If a required role is unavailable or a selector fails, follow role-routing without silent substitution.

For material unresolved AI design choices, the Lead may request a bounded read-only proposal from `team-ai-architect`; it is not required for every simulation. Use `team-architect` for software-wide structure and cross-module boundaries. The Lead coordinates both scopes and resolves shared contracts before any implementation role begins.

The Lead owns the flow, context assembly, routing and mock-tool responses. Either named actor profile is a bounded behavior under test: provide only the approved per-call packet, collect its response or mock-tool request, and never let it orchestrate children, edit production files, change its own rules, or certify its own result. Keep expected criteria and independent scoring outside the actor packet. Shared files may still expose those criteria; native Codex threads are not a security boundary.

Select the actor tier for the declared target model family/tier and test purpose; do not choose the stronger profile merely to make a case pass. When a meaningful distinction is absent or unclear, default to the basic profile. Use the advanced profile only when the case specifically calls for it and the active named role is available. If the target requires an exact model identity that is unsupported, pause or ask the user to approve a proxy; never silently downgrade. A proxy pass is not target-model acceptance.

The definition's `models.simulation` is run-level requested identity and relationship metadata. It does not select or override an agent profile. Codex custom-agent TOML model/effort settings take precedence over spawn-time model overrides; see the [official subagent configuration guide](https://learn.chatgpt.com/docs/agent-configuration/subagents). Select the exact named actor role whose configured profile meets the approved purpose, then record requested identity separately from host-confirmed actual identity. Unknown actual model/effort stays unknown; source TOML is not runtime evidence.

Read the shared [AI simulation contract](../team-core/references/ai-simulation.md) and use the target project's `docs/ai-workflows/<flow>/` source conventions and the bounded local run folder it defines. A simulation definition should identify the flow revision, rules, prompts, context policy, nodes, cases, model relationship, and call budget. Run the local helper's `Validate` before simulation; `InitializeRun` freezes the inputs; append each attempted call, including failures and stops, with `RecordCall`; use `Status` to inspect integrity and drift. The helper validates records; it does not run models, stop inference already in progress, prove host inputs, or approve outcomes.

Declare each node's context mode and retention explicitly: stateless, dialogue, workflow-node, or agent. Use a fresh non-forked actor context whenever the declared packet excludes earlier native turns. Do not reuse an old conversation and ask it to forget excluded content. A fresh thread does not remove host-provided instructions or shared-file access, and capacity limits may pause a run. Do not claim isolation, exact API-request reproduction, or known model usage without host evidence.

Plan bounded cases and repetitions, representative success and failure paths, independent criteria, mock-tool outcomes, stop conditions, and a total call budget before running. Check remaining budget and available thread capacity before every call. The context policy must say who produces summaries and when; define handling for missing or oversized current input/state, absent or lost summaries, stale upstream fields, case reset, retry context, and stop/recovery behavior. Preserve the actual supplied packet and observed output, but omit secrets and unnecessary personal data. Mark unavailable actual model, effort, elapsed time, and usage as unknown; never infer them from a source profile. Do not log hidden chain-of-thought.

Keep versioned synthetic definitions, prompts, context policy, and cases in the target project's existing conventions under `docs/ai-workflows/<flow>/`. Protect the exact `_work/ai-sim-<task>/` run path with the shared Work profile before creating raw traces, and check protection again before handoff or an authorized commit. Resolve tracked-file/include-rule conflicts through the user; never untrack automatically. Keep a concise acceptance summary in the existing `docs/verification/active/<stage>.md` packet. Raw runs are local evidence and should remain until acceptance or diagnosis is complete; then clean only task-owned temporary data under the applicable retention decision.

An accepted simulation only supports a behavior-prototype decision. It does not authorize production implementation. Engineering requires a separate user decision and `$team-dev`; route prompt, context, model, tool protocol, workflow state and AI-runtime logic to `team-ai-engineer`, with the normal test and independent-review roles. Use `backend-engineering` for generic APIs, authorization, service infrastructure or jobs, and declare non-overlapping ownership when both roles are needed. Prefer the approved workflow/prompt source as the single source of truth and turn accepted cases into runtime regression tests during engineering.

## Stage ownership

The Lead owns Context, Discover, Contract, Execute coordination, Verify integration and Handoff for the simulation. It assigns `team-tester` case coverage and independent scoring before actors run; the selected basic or advanced actor answers only authorized node packets. The Lead keeps definition, prompt, case and source ownership explicit, assembles packets, supplies mock results, routes the next node, enforces call/thread budgets and integrates evidence. The Tester does not edit definitions or use the actor context to score its own behavior. This is a user-selected prototype step; normal `$team-dev` authorization and production file owners do not transfer to it.

## Return paths

- Missing source facts, rule files or existing flow context → return to Discover and request a bounded evidence lookup.
- Ambiguous expected behavior, model equivalence, privacy/retention or acceptance threshold → return to Contract and ask the user with options; do not invent the criterion.
- An incomplete/failed actor call or unsatisfied criterion → return to Execute only within the approved call/thread budget; record all attempts. Do not treat retries as free or reset task history.
- Fresh actor capacity or a required named role is unavailable → keep dependent calls paused under role-routing; do not reuse a contaminated context or silently select a generic agent.
- Prototype accepted and user chooses implementation → hand off to `$team-dev` as a separately authorized engineering stage; the prototype pass itself is not approval.

## Output contract

Return the flow revision; declared case coverage and calls completed; the Tester’s independent assessment; requested versus host-confirmed model metadata; context mode and supplied-packet/host-context limits; mock versus real boundary; remaining call budget and thread-capacity limits; evidence and source-drift status; cleanup/retention status; and any decision needed. Distinguish prototype evidence from target-model/runtime acceptance and point to the stage packet for the authoritative project result. Include the actual child roster and selector/handle evidence using the handoff format; do not claim that an intact helper ledger means behavioral acceptance.
