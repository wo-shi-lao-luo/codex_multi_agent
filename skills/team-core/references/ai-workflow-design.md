# Application AI workflow design

Use this guide when an application task introduces or materially changes a model-driven behavior. It helps choose the execution shape; it does not prescribe a framework or authorize a production change. Apply only the other AI design guides relevant to the chosen boundary. Keep approved product intent in its existing PRD/contract and results in the existing stage packet.

## Choose the simplest sufficient shape

Start from the user-visible outcome, deterministic rules, side effects and uncertainty. Prefer ordinary code whenever rules are known and testable. Add a model call only for a bounded judgment or generation task that benefits from language/model capability.

| Shape | Use when | Keep explicit |
| --- | --- | --- |
| Deterministic code | Rules and outcomes are known; model judgment adds no value | Inputs, validation, errors and side effects |
| Single model call | One bounded request can produce a useful result | Instruction, input, output contract, limits and fallback |
| Fixed workflow | The sequence and branches are known in advance | Node contracts, transitions, shared state and stop conditions |
| Tool-using agent | The next step depends on model judgment over available actions | Narrow tool set, authority checks, observations, budget and termination |
| Multi-agent workflow | Distinct roles need independent context/ownership or parallel work materially reduces risk/time | Role boundaries, shared contract, handoff schema, merge owner, limits and global stop |

Do not split a single call into nodes or agents merely to make the design look modular. Split when a boundary has distinct instructions, access, context, failure handling, parallel ownership or independently useful verification. Each split adds orchestration, latency, cost, state and failure modes; explain which concrete risk or benefit justifies it.

## Design the contract before the wiring

1. State the approved goal, non-goals and behavior that must remain deterministic.
2. Name the chosen shape and why simpler shapes are insufficient.
3. Define each call/node/agent's input, output, responsibility, authority, context, tools and error behavior. Use the instruction, context and tool guides as applicable.
4. For multi-step work, define routing, ownership of shared state, retry limits, cancellation, termination and partial-result handling. A handoff names the recipient, required fields and who integrates or rejects the result.
5. Trace the proposal into the authoritative implementation source and actual assembly/call path; identify observable evidence before implementation.

Parallel agents need non-overlapping owned outputs or a named integration owner and an agreed interface. A coordinator that cannot end, reconcile failures, or decide what happens after a partial handoff is incomplete. Keep human approval and external side effects at an explicit application boundary.

## Common failures

- Choosing an autonomous agent where deterministic validation plus one call is enough.
- Splitting work without separate authority, context, ownership or verification.
- Treating a planned node diagram as proof the runtime assembles or routes that way.
- Letting each node invent its own schema, retries, or completion meaning.
- Omitting cancellation, repeated failure, incomplete output and exhausted-budget behavior.
- Treating a successful prototype, source profile, or stage marker as production acceptance.

## Example

Bad: “Use three agents to research, draft and approve every answer.” The roles, access, merge policy, approval authority and stopping rule are unspecified.

Good: “Validate the request in code; use one model call to draft a response from the selected records; require a reviewer call only for the named high-impact category. Both calls receive versioned input/output schemas. Application code enforces access and final approval; the workflow stops on missing records, invalid output, cancellation or one bounded retry.”

## Verify the design

Review a trace from approved behavior to authoritative prompt/workflow source, runtime assembly/call path, and focused evidence. Confirm each split has a reason, every node can stop, partial/error outcomes are handled, side effects stay behind application authorization, and evaluation covers the actual chosen shape. Use the existing capability, record/replay, simulation and evaluation contracts where relevant; do not duplicate their schemas or stage results.

## Design reading

For further background, see Anthropic's [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents) and Google's [Choose a design pattern for your agentic AI system](https://docs.cloud.google.com/architecture/choose-design-pattern-agentic-ai-system?hl=en). These are optional design sources, not required network dependencies.
