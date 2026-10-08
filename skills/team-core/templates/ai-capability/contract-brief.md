# AI capability contract brief

Adapt this outline in the target project's authoritative API/architecture location. Remove inapplicable headings and link to runtime-owned prompts/schemas instead of copying them.

## Capability and owner

- Capability ID/name:
- Business caller and owner:
- AI implementation boundary (Agent, Workflow, or other):
- Existing contract/source of truth:

## Contract revision and behavior

- Revision and required/optional capabilities:
- Input, validation and permitted context:
- Result shape and business meaning:
- State/context owner, retention/reset and in-flight implementation binding:
- Events/streaming, if applicable:
- Errors, timeout, cancellation, retry and partial-result behavior:
- Tools, approvals and side-effect owner:
- Unsupported-capability and compatibility behavior:

## Replacement and verification

- What can change inside the AI implementation, including model changes:
- What must remain stable for the business caller:
- Contract/behavior cases and evidence location:
- Known limits, unknowns or approval decisions:
