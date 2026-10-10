# Risk-proportional web engineering

Use this reference from frontend/backend implementation, testing, review, or Team development when the task has a real web client or service boundary. Select only the domain guide and checks that fit the changed behavior; this is not a new workflow or a requirement to read every linked guide.

## Baseline and risk selection

Keep the existing Work contract, role assignments, test packet, TDD choices, acceptance gates, and handoff authoritative. State the user-visible or service behavior and the narrow verification path as usual. Add depth when a concrete property could fail in a consequential way, such as real or sensitive data, exposed endpoints, authorization, persistence, retries, external side effects, concurrency, or a user-critical interaction. A demo/MVP label does not waive a risk that is actually present. Conversely, static fake-data demos and read-only pages do not inherit production service hardening, a broad audit, mandatory metrics, new dependencies, or a full suite without a task-specific reason.

| Concern | Select when | Keep the check bounded to |
| --- | --- | --- |
| Client state and data | Multiple state owners, asynchronous requests, stale results, persistence/cache, or mutations are in scope | The source of truth, derived values, relevant ordering/staleness, and affected success/error/recovery behavior. See [state and data](../../frontend-engineering/references/state-data.md). |
| Usability and performance | An interaction, responsive layout, accessibility behavior, or observed performance issue changes | The affected flow, applicable keyboard/focus/semantic behavior, supported viewport, and measured symptom if performance is a requirement. See [usability and performance](../../frontend-engineering/references/usability-performance.md). |
| Service reliability | A real API, job, integration, persisted mutation, retry, or external effect changes | Contract/error meaning, validation/authorization, bounds, retry ownership, deadlines, idempotency or partial failure only where applicable. See [service reliability](../../backend-engineering/references/service-reliability.md). |
| Security and privacy | An actual trust boundary, sensitive data, permission, or externally reachable behavior changes | The specific threat/control boundary, safe error/logging behavior, and a test that demonstrates the relevant rule; use existing project security policy. |

## Evidence and collaboration

Carry the selected risks and observable outcomes into the existing packet so the assigned Tester can choose the narrowest adequate checks and the Reviewer can inspect the same boundary. Reuse existing evidence only when its inputs still match. Expand to integration, browser, resilience, or security checks when the real boundary or an existing repository gate requires them; do not create an extra checklist, role, report, or approval stage from this reference.

Do not turn examples into stack mandates. Choose existing project patterns and tools; request a dependency, architecture, API, or authorization decision only when it is actually needed. Preserve the established domain authority and return unresolved contracts to the Lead rather than compensating with client assumptions or generic hardening.

## Further reading

- [Frontend state and data](../../frontend-engineering/references/state-data.md) and [usability/performance](../../frontend-engineering/references/usability-performance.md)
- [Backend service reliability](../../backend-engineering/references/service-reliability.md)
- [React: choosing state structure](https://react.dev/learn/choosing-the-state-structure) and [You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect) — relevant when the project uses React
- [AWS Builders' Library: timeouts, retries, and backoff with jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/) — when distributed calls/retries are in scope
- [OWASP API Security](https://owasp.org/www-project-api-security/) — when an exposed API or authorization boundary is in scope
