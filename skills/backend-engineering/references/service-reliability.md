# Backend service reliability

Select only the checks that match an affected API, job, dependency, or side effect. Existing backend/database contracts, project policy, the Work contract, and the stage packet remain authoritative. This guide does not impose production infrastructure or a generic hardening pass on isolated or fake-data work.

## Contract and trust boundary

- Name the caller, input boundary, success behavior, and error meanings affected by the change. Validate untrusted input at the owning boundary and preserve the distinction between invalid, unauthorized, unavailable, and failed outcomes when callers depend on it.
- Apply authorization to the specific object, fields, and actions being changed; do not rely on the client to enforce it. When that boundary changes, include a representative forbidden or cross-owner case if safely testable. Keep sensitive values out of logs and error responses.
- Where callers depend on it, confirm contract details such as omitted versus `null`, pagination, and whether a response means work completed or merely accepted for asynchronous processing. Do not expand a routine change into a full API review.
- Bound payloads, work, and resource consumption when the endpoint or job is externally reachable or accepts caller-controlled scale. Use existing limits and conventions; do not invent quotas without evidence or approval.
- Keep compatibility and dependent consumers visible in the existing Work and packet. Material schema/data/query changes still route through the existing database and migration contracts.

## Retries, concurrency, and partial failure

For distributed calls or asynchronous work, identify who owns retry and what time/deadline budget applies before adding retries. Avoid retry multiplication across layers. Use backoff/jitter only when transient retry is appropriate and supported by the dependency. Make non-idempotent effects safe under duplicate delivery only when the real execution model can duplicate them; use an idempotency key or equivalent contract when required. Consider concurrent updates and partial completion when those states are reachable, and define observable recovery rather than implying atomic success.

A timeout, cancellation, or lost response does not by itself prove that a remote side effect did not happen. For an operation where duplicate effects matter, verify the dependency's outcome/retry contract and choose a safe reconciliation or idempotency path rather than assuming the client can infer completion.

Do not add queues, circuit breakers, distributed locks, new metrics, or infrastructure solely because a guide mentions them. Preserve existing behavior if the relevant failure mode is not present. Surface a material dependency, data-integrity, or compatibility decision to the Lead before changing the contract.

## Verification

Choose evidence for the real boundary: focused contract/error tests, an integration check for the affected dependency, or a controlled failure/retry case when that behavior is material and safely reproducible. Do not call a unit test proof of live dependency reliability. Retain existing repository-required checks; risk-proportional selection does not waive them.

## Primary references

- [Microsoft Azure Architecture Center: API design](https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-design) for API contract considerations.
- [AWS Builders' Library: timeouts, retries, and backoff with jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/) and [making retries safe with idempotent APIs](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/) when retry or duplicate-effect behavior is in scope.
- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/) when exposed API security boundaries are affected.
