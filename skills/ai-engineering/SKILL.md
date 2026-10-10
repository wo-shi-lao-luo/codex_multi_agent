---
name: ai-engineering
description: Design, implement, test, or review application AI agents and workflows, including prompts, context/history, model calls, tool protocols, routing, retries, and evaluation integration.
---

# AI engineering

## Choose the design guidance

Start by selecting the simplest sufficient execution shape in the shared [AI workflow design guide](../team-core/references/ai-workflow-design.md): deterministic code, one bounded call, a fixed workflow, a tool-using agent, or justified multi-agent work. Then read only the applicable detail in the shared [AI instruction design](../team-core/references/ai-instruction-design.md), [AI context design](../team-core/references/ai-context-design.md), and [AI tool design](../team-core/references/ai-tool-design.md) guides. These references are conditional design guidance, not a new runtime or a replacement for the capability, record/replay, evaluation and simulation contracts below.

A Codex development Skill or linked file is not automatically available to the target application's model. Trace approved intent to the canonical prompt/workflow source, actual runtime selection and assembly/call path, then focused observable evidence. Keep observed implementation separate from approved product intent.

## When to activate

Use this domain Skill when an authorized task designs, implements, tests, or reviews an application's AI behavior. It may route automatically when the actual task enters that domain; it does not itself authorize code changes. Read the shared [execution contract](../team-core/references/execution-contract.md) for `$team-dev` lifecycle/verification and the [AI simulation contract](../team-core/references/ai-simulation.md) only when prototype evidence is in scope.

When designing a replaceable Agent/Workflow boundary, read the [AI capability contract](../team-core/references/ai-capability-contract.md). For live application evidence and offline fixture reuse, read the [AI record/replay testing contract](../team-core/references/ai-record-replay-testing.md) with the Tester; model replacement remains inside the Agent/Workflow boundary.

If an AI replacement also materially changes cross-cutting business contracts, workflow/state, configuration or eligibility, persisted data/jobs, or compatibility, apply the conditional [architecture and contract migration guide](../team-core/references/architecture-migration.md) with the existing AI capability and test contracts. An internal prompt/model change with unchanged approved semantics remains within those AI-specific contracts and does not require an exhaustive migration pass.

For application AI behavior evaluation, route assigned evaluation cases and tests to `team-ai-tester` and apply the [AI evaluation contract](../team-core/references/ai-evaluation.md). Keep generic business, Kit-helper and packaging checks with the role selected by shared role routing.

Use alongside the relevant domain Skill when work changes an application's AI behavior. This Skill is engineering guidance; it does not activate or authorize the optional local AI simulation workflow. If AI simulation is requested, use `$team-ai-simulate`.

`team-ai-engineer` owns assigned AI-specific behavior: prompt and instruction source, model-call contracts, context/history and summary policy, workflow or agent state, tool request/result handling, routing, retries, termination, and human approval gates. For material unresolved AI design choices, the Lead may request a bounded read-only proposal from `team-ai-architect`; it is optional, not a mandatory preflight for every task. `team-architect` retains software-wide structure and cross-module boundaries, with the Lead coordinating shared contracts. Keep generic API/service/authentication/job infrastructure with `team-backend-engineer`; agree the interface and declare disjoint file ownership before parallel work. Existing Tester and Reviewer roles remain responsible for test planning/verification and independent review.

Before implementation, identify the authoritative prompt/workflow source and trace each node or agent's inputs, context retention, output schema, tool access, state transition and failure behavior. Establish the actual execution shape and define which prior turns, summary, upstream fields, memory and tool results are assembled, by whom and when. Define reset, retry, missing/oversized state, reference loss and termination behavior. Do not assume a call receives the full conversation or that a stateless call can be simulated by asking a reused thread to forget. Verify that selected instruction/reference content reaches the actual call; file presence or a design-time link is not runtime evidence.

Preserve accepted prototype scenarios as regression cases when suitable; the simulation contract's supplied-input records are not proof of the complete hidden host request. Keep product-source prompts in their existing authoritative runtime location when implementation begins, and link supporting docs instead of maintaining a competing copy. Treat model names/effort written in source profiles as requested configuration until runtime evidence confirms what actually ran. Mark unavailable telemetry unknown, not zero.

Use `$team-dev` for authorized code changes. Follow its documentation-readiness, blueprint, stage verification, TDD, comment, efficient-test and approval gates. The appropriate unit and integration tests should cover context assembly, state transitions, tool protocol, routing/retry/termination, malformed and missing outputs, and approval boundaries. Add API/service tests for broad business behavior; retain representative E2E journeys for user-visible integration and distinct client/UI risks. Do not duplicate the entire business-rule matrix in browser tests when equivalent lower-layer evidence exists. Independent review should verify that scenario assertions reflect the actual contract and that no secret or hidden chain-of-thought enters artifacts.

Apply the shared [code readability contract](../team-core/references/code-readability.md) to assigned code and tests. Follow the project formatter/configuration and preserve prompt, string, and context semantics; formatting-only transfers begin only after the original writer freezes the files.

## Output contract

For engineering handoff, separately report design completion, integration wiring and behavior verification, each with evidence or an explicit unknown. Also report the authoritative prompt/workflow source, changed AI boundaries and context contract, accepted prototype cases reused or reasons they do not apply, relevant tests/results, model identity/telemetry limits, tool and state risks, and remaining approval or rollout decisions. If assigned as the writer, list changed files and verification; do not report source model profiles as evidence of the host-resolved model.
