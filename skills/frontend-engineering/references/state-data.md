# Frontend state and data boundaries

Use these checks only for the state, request, persistence, or mutation behavior affected by the task. Keep the existing frontend work contract and stage packet authoritative; this guide adds no state library or test layer.

## State ownership

- Identify the existing source of truth for each changed value. Keep local view state, shared client state, URL state, server-owned data, and persisted user data distinct where the application already distinguishes them.
- Derive values from their authoritative inputs when practical instead of maintaining duplicate state that can drift. Add another owner only for a concrete lifecycle or interaction need.
- Respect the project's existing framework and state conventions. Do not add a store, cache, synchronization abstraction, or persistence mechanism solely to follow an example.

## Asynchronous data

For affected asynchronous behavior, inspect the ordering and lifecycle that can actually occur: repeated input, navigation/unmount, overlapping requests, retries, or a response arriving after newer state. Prevent stale results from replacing current data where that race is possible. Give loading, empty, error, and success states meanings consistent with the API contract; preserve useful prior data only when that is an intentional existing behavior.

For cached or persisted data, establish its actual scope, identity, freshness/invalidation behavior, and privacy boundary before changing it. Do not assume that a client cache is harmless for user-specific or permission-dependent data. Keep secrets and sensitive information out of browser storage, URLs, logs, and user-visible errors according to project policy.

When account, tenant, permission, or session identity can change, check whether old requests or cached values can cross that boundary; account switching and sign-out are useful invalidation cases when supported by the app. Do not add identity-scoped cache machinery to a page that has no such state.

## Mutations and recovery

For a changed mutation, make the user-visible pending/success/failure state match what is known about the server outcome. An optimistic update may be shown as provisional when that is intentional and clear; it is not proof that the server committed. On failure, roll back or reconcile with authoritative data as the existing interaction requires. Retries, deduplication, and idempotency are conditional tools: do not retry a non-idempotent action blindly. Cover a relevant rejection, timeout, duplicate-submit, or recovery path when that risk exists.

Prefer focused evidence: a deterministic state/interaction test for the affected transition, plus the existing rendered or integration check when the behavior depends on the actual page or service. Component tests do not replace a required integrated-page inspection.

## References

- [React: choosing the state structure](https://react.dev/learn/choosing-the-state-structure) and [You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect) are React-specific guidance, not framework-independent mandates.
- Use the existing [UI delivery contract](../../team-core/references/ui-quality.md) for applicable page, interaction, and rendered evidence requirements.
