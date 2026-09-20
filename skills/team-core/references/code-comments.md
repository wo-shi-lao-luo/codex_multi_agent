# Code comment contract

Apply when writing or reviewing code, including tests, scripts, SQL and migrations. Follow the target repository's comment language and documentation conventions. Limit changes to the assigned scope; this is not authorization for a repository-wide annotation or refactor pass.

## Layered minimum requirements

Apply these requirements to newly created code and changed units within the assigned scope. Existing adequate documentation counts; do not duplicate it. Backfill untouched historical code only within an explicitly authorized scope. Follow project instructions if they conflict and report the conflict rather than silently claiming compliance.

| Layer | Required explanation |
| --- | --- |
| File or module | Every owned file with an independent business, test or operational responsibility needs a concise overview of its purpose and place in the flow, plus responsibility boundaries when relevant. Pure re-export files, generated/vendor files and trivial declarative files may be exempt with a reason. |
| Public or cross-module interface | Functions, classes, components and hooks need purpose and usage-contract documentation even when their names are clear. Cover applicable input/output semantics, failure behavior, side effects and calling constraints; do not restate types or require empty template fields. |
| Internal business logic | Functions implementing business rules, multi-step processing, state transitions or side effects need responsibility and key-constraint explanations. Short, obvious local helpers may be exempt; internal visibility alone is not an exemption. |
| Important implementation blocks | Explain material authorization, retries, concurrency, caching, transactions, compatibility branches and ordering decisions near the code. Not every conditional needs a comment. |
| Data and constants | Explain semantics not expressed by names/types: units, ranges, null/empty behavior, sentinel values and state relationships. |

The reader should be able to use an interface without reconstructing its implementation and maintain important behavior without guessing its rationale. Interface documentation explains **what and the contract**; implementation comments explain **why**. Do not reduce this to an instruction to write only why-comments.

## Test-case explanations

Every independent test case must have a nearby comment or test-function docstring describing its purpose/scenario and observable expected result, even when the test is simple. This applies to unit, component, integration, contract, E2E and script-based tests. A descriptive test name, suite/file overview or Arrange/Act/Assert labels alone do not satisfy this requirement.

```typescript
test('rejects an expired session', async () => {
  // Scenario: a user with an expired session requests a protected resource.
  // Expected: return 401 and do not invoke the resource-reading service.
  // ...exercise the request and assert both outcomes...
});
```

- Parameterized tests may share a purpose/expected-rule comment if every row has an identifiable scenario and explicit expected value or outcome; explain exceptional rows individually. Do not duplicate identical prose for every generated instance.
- Script-based tests without test functions need explanations for each independent scenario block, not just a file header.
- Complex integration/E2E tests also need concise explanations of important action stages and checkpoints. Explain surprising fixtures, mocks or timing assumptions where relevant; do not narrate every assertion.
- Regression tests explain the behavior whose recurrence they prevent. Link an issue only when it is real and relevant; do not invent historical rationale.
- Each claimed expected outcome must be supported by assertions or explicit verification. If a comment promises both a response and absence of a side effect, check both. Do not weaken the intended expectation merely to match incomplete assertions; fix within authorized scope or report the gap. For annotation-only tasks, report required test/behavior changes separately.
- Existing skipped or pending tests still need a scenario and expected outcome when in scope; their explanation is not evidence that they ran or passed.

## Write with the implementation

- Explain non-obvious intent: business rules, boundary conditions, authorization constraints, concurrency invariants, and compatibility workarounds whose rationale cannot be understood from names and code alone.
- Use the repository's usual doc-comment format for interface documentation. A clear name does not waive the layered minimum or test-case requirements.
- Place explanations close to the relevant decision. For a workaround, state the constraint and removal condition when known; do not invent an issue link or rationale.
- Update or remove affected comments when behavior changes, including caller-facing documentation when its contract changes. Do not leave commented-out old implementations or unsupported promises about behavior.
- Prefer clear names and focused structure over explanations of confusing code. Comments do not justify unauthorized refactoring. Do not impose comments on every line/function, a comment percentage, or boilerplate on generated/vendor code; update the owned source or generator when applicable.

## Writer self-check

Before handoff, inspect the actual diff and relevant surrounding comments. Check each in-scope file, public/cross-module interface and important internal function against the layered minimum. Check each in-scope test case for a scenario and expected result, including parameterized rows and script blocks. Match comments to implementation and assertions; remove stale descriptions and commented-out old code. Resolve gaps in scope; report unavailable evidence rather than claiming a completed check.

Record inspected scope, outcome, justified exemptions and remaining gaps briefly in the existing Verification record. A no-change outcome requires existing adequate documentation or an applicable exemption; a blanket claim that code is self-explanatory cannot waive mandatory interface or test explanations. This self-check is required even without an independent reviewer. No separate comment report is required.

## Review and completion

Reviewers check the layered minimum and every in-scope test explanation, then compare important comments and interface documentation with actual behavior and assertions. A missing mandatory explanation is a contract-compliance gap, not merely a stylistic preference; cite the requirement and location. Rank misleading explanations by their concrete maintenance, contract or safety impact. Do not enforce personal phrasing preferences.

The Lead checks that writer self-check evidence exists and material findings are resolved or disclosed before claiming completion. Automated package validation checks that this contract is shipped and referenced; it cannot establish semantic comment quality. Tests, linters and comment counts do not replace this inspection.
