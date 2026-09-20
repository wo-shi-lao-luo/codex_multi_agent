# Code comment contract

Apply when writing or reviewing code, including tests, scripts, SQL and migrations. Follow the target repository's comment language and documentation conventions. Limit changes to the assigned scope; this is not authorization for a repository-wide annotation or refactor pass.

## Write with the implementation

- Explain non-obvious intent: business rules, boundary conditions, authorization constraints, concurrency invariants, and compatibility workarounds whose rationale cannot be understood from names and code alone.
- Document public interfaces' non-obvious side effects, failure behavior, units, preconditions or ownership constraints in the repository's usual doc-comment format. Do not restate obvious types or signatures.
- Place explanations close to the relevant decision. For a workaround, state the constraint and removal condition when known; do not invent an issue link or rationale. Test comments explain surprising fixtures or timing assumptions, not each assertion.
- Update or remove affected comments when behavior changes, including caller-facing documentation when its contract changes. Do not leave commented-out old implementations or unsupported promises about behavior.
- Prefer clear names and focused structure over explanations of confusing code. Comments do not justify unauthorized refactoring. Do not impose comments on every line/function, a comment percentage, or boilerplate on generated/vendor code; update the owned source or generator when applicable.

## Writer self-check

Before handoff, inspect the actual diff and relevant surrounding comments. Check whether non-obvious decisions need explanation, whether existing and new comments match implementation and tests, and whether obsolete comments or commented-out code remain. Resolve gaps in scope; report unavailable evidence rather than claiming a completed check.

Record scope and outcome briefly in the existing Verification record. If no new comment is needed, explain that the changed code is self-explanatory or already adequately documented; do not add filler. This self-check is required even without an independent reviewer. No separate comment report is required.

## Review and completion

Reviewers compare important comments and interface documentation with actual behavior, and check for missing rationale at risky decisions. Report misleading or missing explanations with a concrete maintenance, contract or safety impact and a precise location; do not manufacture stylistic findings or enforce personal phrasing preferences.

The Lead checks that writer self-check evidence exists and material findings are resolved or disclosed before claiming completion. Automated package validation checks that this contract is shipped and referenced; it cannot establish semantic comment quality. Tests, linters and comment counts do not replace this inspection.
