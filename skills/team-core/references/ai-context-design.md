# Application AI context design

Use when a model call depends on prior turns, retrieved records, upstream workflow output, memory, summaries, tool results or persisted state. Context is an input contract: define who selects and assembles each field, when it is assembled, and what the receiver may infer from it.

## Map fields before choosing retention

For each call/node, make a compact matrix. The context owner selects, writes, compresses or isolates fields for that specific node; define both the scoped input it receives and the validated output fields it hands downstream. Do not assume every node receives a blanket transcript or the prior node's full response.

| Field | Source/owner | Selected or written when | Size/retention | Missing, stale or invalid behavior |
| --- | --- | --- | --- | --- |
| Current input | Request boundary | At each call | Current request only | Validate or stop |
| Prior turns | Conversation store/assembler | Before dialogue call | Declared recent/full/none policy and cap | Start fresh, clarify, or stop |
| Retrieved evidence | Retrieval layer | Per query/node | Relevant records with IDs/revision | Report insufficient evidence; do not fabricate |
| Upstream output | Prior workflow node | At handoff | Named fields, schema and provenance | Reject invalid/missing dependency |
| Summary/memory | Named summarizer/store | Declared trigger | Source range, timestamp/version and cap | Regenerate from allowed source or stop |
| State/tool results | Application/tool boundary | After validated transition/action | Minimal fields needed next | Reconcile outcome; never assume success |

Choose stateless calls when prior context is unnecessary; explicit dialogue history for conversational continuity; bounded workflow fields for known handoffs; and persistence only where the product requires it. Do not call an interaction stateless while hidden history or durable memory still reaches the model.

## Assign assembly and lifecycle

1. Name the component that selects, writes, redacts, orders and truncates every field.
2. Set the assembly point: request entry, node transition, retrieval result, summary checkpoint or retry.
3. Define what is excluded, how size/token limits are enforced, and which fields have priority if limits are reached.
4. Define reset, expiry, deletion, cancellation, retry and recovery behavior. A retry must state whether prior turns, tool outcomes and state are replayed or rebuilt.
5. Preserve provenance for retrieved facts and summaries: source IDs/revisions, covered turn range and creation time as appropriate. Distinguish quoted/untrusted content from trusted policy.

Treat user text, retrieved pages, files and tool results as untrusted data. Delimit them and instruct the model to use them as evidence, not as authority to override policy. Enforce permissions, tenant boundaries and allowed data access before assembly; prompt wording alone is not an access control. Avoid collecting private data that the call does not need.

For truncation or context loss, define a safe outcome: ask for missing information, retrieve again from an authorized source, create a fresh context, return partial status or stop. Never silently replace omitted history with an unsupported summary. Specify who creates a summary, from which source range, when, at what size, and how stale or contradictory summaries are detected.

## Common failures

- Assuming the model sees the UI transcript, all messages, or a prior node's whole output.
- Reusing a thread after claiming excluded turns were forgotten.
- Summarizing without source range, provenance, freshness or loss behavior.
- Truncating the last part of a prompt and unknowingly dropping constraints or evidence.
- Mixing trusted instructions and retrieved/user content without a trust boundary.
- Retaining state forever or across users/cases when the contract says to reset.

## Example

Bad: “Pass the conversation and relevant records to the model; summarize if long.” No owner, selection rule, cap, provenance, reset or failure path is defined.

Good: “At each answer node, the assembler supplies the current question, the last four user/assistant turns up to the configured cap, and at most five authorized records with stable IDs and revisions. If prior history is truncated, it adds a versioned summary with its covered turn range; if that summary is absent or stale, ask the user to restate the needed detail. Retrieved text is quoted as untrusted evidence. A retry rebuilds the same declared fields and records the previous tool outcome.”

## Verify

Inspect the actual node input, not only the selector or prompt. Assert field presence/absence, order, bounds, source provenance, permission filtering, reset between cases, and missing/stale/truncated recovery. Use trace/intermediate evidence where available and outcome assertions for user-visible behavior; the simulation contract does not prove hidden host context was absent.

## Design reading

For further context-design background, see Anthropic's [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents). This is optional background and not a runtime dependency.
