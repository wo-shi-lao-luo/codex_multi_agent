# AI capability contract

Use this contract when a project must replace an Agent or Workflow without coupling its business backend to that implementation. It defines a project-specific boundary; it is guidance for the target project's architecture, not a universal runtime interface or plugin engine.

## Ownership boundary

The business backend depends on a named capability exposed through a thin adapter. The implementation behind it may be one Agent, a multi-agent arrangement, or a Workflow. Its internal framework, model SDK, node graph, thread objects and provider response formats remain behind the AI boundary.

Model replacement is an internal Agent/Workflow change. It can affect prompts, context assembly, tools, parsing and AI behavior tests, but does not by itself change the business backend contract. Replacing the whole Agent/Workflow requires a new implementation to satisfy the same capability contract and required behavior cases.

This boundary may live in one process or across a service boundary according to the project. Preserve an adequate existing design. Do not introduce a general framework or restructure existing code solely to obtain replaceability; present an existing-code refactor for user approval. If a refactor is declined, keep work within the current structure and document the resulting constraints.

## Define the smallest useful contract

Start from a concrete business capability and its actual callers. Reuse existing API, product and architecture authorities. Record only applicable facets; mark other facets out of scope with a reason.

| Facet | Define |
| --- | --- |
| Input | Task/request, permitted business data and context, constraints, validation and size limits. |
| Result | Structured result and its business meaning, proposed actions versus completed actions, partial-result behavior. |
| Context and state | Who owns conversation/workflow state, what is carried/reset, and how a running task is bound to an implementation. |
| Events | If streaming or progress is needed: event meanings, order, terminal conditions, duplicate handling and reconnect behavior. |
| Failure and control | Timeout, cancellation, retry, idempotency, partial execution and recovery behavior. |
| Tools and effects | Available tools, approval requirements, and which layer validates and executes side effects. |
| Compatibility | Contract revision, required and optional capabilities, and behavior when a candidate does not support one. |

Specify semantics, not just matching field names. An adapter may translate implementation-specific representations but must preserve meaningful distinctions. It must not silently discard an error, approval request, partial result, event, state transition or side-effect status. If a capability is optional, callers must have an explicit supported fallback or stop behavior.

Business services retain responsibility for business authorization, validation, persistence, version checks and publishing. An AI-proposed action is not authorization to perform it. Keep provider/model identity and provider-specific request details out of the business contract unless a verified business requirement makes them observable requirements.

For long-running work, define which implementation handles an in-flight run. Pin it to the implementation/revision that started it unless the project has a tested migration contract. Do not assume another Agent/Workflow can resume opaque state from the old one.

## Work and evidence

Keep the authoritative contract in the target project's existing API or architecture location. If none fits, use a scoped AI capability document such as `docs/ai-workflows/<capability>/contract.md`. Describe behavior and ownership there; keep runtime prompt/schema definitions in their existing source files and link them instead of copying them.

Plan contract and behavior cases before implementation. The record/replay testing contract defines how to exercise the real integration boundary, record useful evidence and safely replay it. Use [`templates/ai-capability/contract-brief.md`](../templates/ai-capability/contract-brief.md) only when a concise starting outline is useful; adapt or omit sections that do not apply.

If replacing an Agent/Workflow also materially changes cross-cutting business contracts, workflow/state, configuration or eligibility, persisted data/jobs, or compatibility, apply the conditional [architecture and contract migration guide](architecture-migration.md) alongside this capability contract. An internal/model-only swap with unchanged approved semantics does not require an exhaustive migration pass.
