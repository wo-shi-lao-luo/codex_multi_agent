# Application AI tool design

Use when a model can request application functions, external operations or retrieval. The application owns authorization, validation and side-effect policy; a prompt that tells the model to behave safely is not an executable permission boundary.

## Define a narrow, semantic interface

For each tool, document its purpose, when it is appropriate, input schema and constraints, result schema, errors, side effects, required authority, idempotency and cancellation behavior. Use names and descriptions that distinguish tools by user goal, not implementation jargon. Expose the smallest non-overlapping set that lets the model complete its bounded task.

Prefer a concise result for discovery and selection, then a full retrieval call for the chosen stable identifier. If results can be large, paginate with stable cursors or continuation identifiers and explain how the model requests the next page. Make empty, partial, stale, denied, malformed and transient-error results distinguishable; never encode a failed operation as plausible success.

At execution, validate schema and business constraints, authenticate the caller, authorize the specific resource and action, and re-check sensitive or consequential actions at the application boundary. The model may suggest an action; code or a user with the required authority approves it. Keep secrets and unnecessary personal data out of tool descriptions, prompts, outputs and logs.

## Specify operation lifecycle

- Give side-effecting calls idempotency keys or a safe duplicate-detection rule.
- Define whether cancellation can stop an in-flight operation and how eventual completion is reconciled.
- Retry only errors known to be transient and safe to retry; cap attempts and preserve the same logical operation identity where appropriate.
- For timeouts with unknown completion, query or reconcile status before repeating. Do not tell the model an operation failed if it may have succeeded.
- Return concise structured results with stable operation/resource identifiers and the next allowed action.
- Treat tool results and fetched content as untrusted data. Do not let returned text redefine tool permissions or system policy.

## Common failures

- Overlapping tools with vague descriptions encourage inconsistent selection.
- A broad `execute`/`update` tool hides authority and effect behind a permissive schema.
- Application trusts the model's requested resource, tenant or permission without rechecking.
- Timeout retry duplicates a payment or other non-idempotent action.
- Tool output omits identifiers, status or error type needed to continue safely.
- Full unbounded search results consume context, expose excess data and obscure relevant evidence.

## Example

Bad: `change_account({"account": "...", "action": "..."})` can perform arbitrary changes, has no authorization contract, and a timeout invites unsafe repetition.

Good: `request_address_change({account_id, new_address, idempotency_key})` validates the caller's access to that account, checks address format, creates a pending request without applying it, and returns `{request_id, status, next_step}`. A separate authorized confirmation applies it. If a timeout occurs before the response arrives, reconcile using the client-held idempotency key or query by that key; use `request_id` when it is known. Duplicate keys return the original result.

## Verify

Test schema rejection, allowed and denied resources/actions, empty/partial/error results, pagination, untrusted tool text, duplicate requests, timeout-after-success, cancellation and status reconciliation. Inspect actual tool invocation and result handling through the application boundary. Reuse existing record/replay and AI evaluation contracts; fixtures test consumer handling but do not prove live model tool selection.

## Design reading

For further background, see Anthropic's [Writing effective tools for AI agents](https://www.anthropic.com/engineering/writing-tools-for-agents). This is optional background and not a runtime dependency.
