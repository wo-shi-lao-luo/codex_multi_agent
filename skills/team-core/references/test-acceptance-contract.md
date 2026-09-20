# Test & Acceptance Contract

Before any `$team-dev` writer starts, create one Git-tracked stage packet in the target repository. Reuse an existing repository QA convention; otherwise initialize `docs/verification/active/<stage-slug>.md` with `scripts/stage-verification.ps1`. Apply the companion [TDD protocol](tdd-protocol.md) to decide the evidence track for every material behavior.

The packet must contain stage context, use cases with happy and edge paths, test data and cleanup, coverage matrix, automated test/E2E plan, and numbered human verification steps. Assess unit, integration, contract/API, E2E, regression, and manual coverage for every stage; assess component/UI, accessibility, visual regression, performance/load, security, compatibility, data migration/rollback, resilience/recovery, and exploratory/usability when material. Every category is `required`, `conditional`, or `not applicable` with a reason.

For deterministic behavior, write a failing practical automated test before implementation and use red-green-refactor. Otherwise record why strict TDD is not practical and define the smallest reliable alternative. Do not invent line-coverage targets.

At close, reconcile each row as `planned`, `written`, `failing as intended`, `passing`, `manual pending`, `manually verified`, or `exception accepted`. Never mark human-only checks passed without user evidence. Run `stage-verification.ps1 -Action Validate` before handoff. Archive only when the packet's unique `Final manual status` is `manually verified` or `deferred by user`; otherwise keep the packet active and link it in the Handoff.
