# AI record and replay testing

Use this guidance when an application Agent or Workflow crosses a backend boundary and live AI calls are costly or variable. It complements, but does not relax, the stage packet, TDD, E2E/manual mapping, risk gates or repository-required checks in the [Test & Acceptance Contract](test-acceptance-contract.md).

## Separate the evidence

Plan deterministic business tests before implementation where practical. They should exercise validation, authorization, state changes, persistence, error handling and side-effect controls without depending on model output.

Use distinct evidence for these questions:

| Evidence | Question answered |
| --- | --- |
| Unit and integration/API tests | Does application logic handle valid, invalid and exceptional values correctly? |
| Agent/Workflow behavior cases | Does this AI implementation perform the required task and honor its context, tool and output rules? |
| Contract tests | Do caller, adapter and implementation agree on the declared meanings and capabilities? |
| Live integrated scenario | Does the current real application path connect the components and produce the expected user-visible/business outcome? |
| Replay test | Does the real consumer/backend path handle a previously observed boundary interaction correctly under this test setup? |
| Browser/manual checks | Does the user-facing flow and its distinct UI, visual or human-judgment behavior work? |

The boundary between business backend and AI capability is the default record/replay seam. Keep requests flowing through the real application and adapter/consumer processing; substitute only the AI implementation at that seam. If adapter parsing of raw provider data is a material risk, add a focused raw-response fixture for that adapter. Do not duplicate raw and normalized fixtures without a distinct assertion.

## Record once, assert by purpose

Before a live run, define the scenario, initial state, expected outcomes, permitted side effects, environment and budget. During one representative real integrated scenario, capture the agreed boundary interaction. That run can support separate protocol, Agent/Workflow and backend assertions when each assertion observes its own contract. If the same execution already proves the complete agreed application path, do not make a second live call only to collect duplicate evidence.

An AI-only run followed by replay through the backend is not a live end-to-end run. It can verify backend handling of that recorded result, while a separate small live integrated set verifies actual wiring. One successful trace does not establish behavior across failure paths or nondeterministic runs.

Record only fields needed to reproduce the boundary: capability/contract revision, relevant request/context/state, response or ordered events, initial conditions, relevant implementation/prompt/model configuration revisions when known, environment, outcome and provenance. Mark unavailable model identity, usage and cost as unknown. The record says what was observed; it does not prove that observation is correct.

Set expected assertions from approved requirements before evaluating the output. Preserve failures and unexpected observations. A qualified Tester evaluates behavior independently; never auto-update a golden/fixture from the latest output to make a check pass. Prefer assertions on required structure, business meaning, allowed/forbidden effects and state over exact prose where wording is not the requirement.

## Make replay deterministic and safe

- Match the request and all contract-relevant context/state fields, plus interaction order for multi-event or tool-driven flows. Normalize only explicitly irrelevant values such as generated IDs or timestamps; document that normalization.
- A missing or mismatched replay case fails clearly. Never fall back to a real model call, paid operation or live external service.
- Replay must pass the captured response/events through the real parsing, validation and business handling under test. Direct database insertion bypasses that evidence boundary.
- Use isolated test state and test doubles for external tools. Block network egress and real side effects in replay mode. Ensure setup/cleanup cannot touch user or production data.
- Include synthetic adversarial cases for malformed/missing fields, refused or unsafe actions, duplicate/out-of-order events, timeout, cancellation, tool failure and partial completion when relevant. Happy-path traces alone are insufficient.
- Make live, record, replay and synthetic modes explicit in test configuration. Do not let request parameters silently enable test mode in a deployed product.

## Curate and retain evidence

Prefer synthetic inputs. Before storage, exclude secrets, credentials, private conversations, unnecessary personal data and hidden chain-of-thought. Raw or unreviewed traces stay in the exact task-owned ignored Work directory protected by the existing generated-artifact contract. Curated, redacted, useful regression fixtures may live in the project's normal test fixture location and be versioned.

Keep the stage packet as the result authority and map each applicable case to its test/evidence IDs. Do not turn raw traces into a README journal or maintain duplicate copies of runtime prompts, schemas or business cases. Retain diagnostics through the agreed acceptance/diagnosis need, then clean only task-owned temporary material; preserve evidence needed to explain a failure.

## Reuse and invalidation

Replaying a fixture against changed backend code creates a new backend test result; it does not reuse the old pass. A fixture from an old AI implementation remains useful for backend regression but does not show that a changed prompt, context policy, model or Agent/Workflow still behaves correctly.

Reassess only affected evidence when relevant inputs change:

| Change | Recheck |
| --- | --- |
| Business handling | Replay applicable fixtures through changed consumer logic and run affected deterministic tests. |
| Adapter parsing or translation | Test raw/normalized contract mapping and affected integration behavior; use live evidence when the transport boundary is material. |
| Prompt, context, tools, workflow or model | Rerun affected AI behavior cases and verify output contract; old fixtures continue to test backend handling only. |
| Whole Agent/Workflow replacement | Run the shared contract and behavior cases on the candidate, then representative live integration. |
| Contract or approved requirement | Reassess affected fixtures, assertions and test-layer mapping before relying on prior results. |

Use [`templates/ai-capability/record-replay-plan.md`](../templates/ai-capability/record-replay-plan.md) when the stage packet needs a compact plan for this seam. The packet remains the place for test status, results, manual steps and acceptance.
