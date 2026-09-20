# Execution templates

Use these concise templates when a team workflow needs a shared artifact. Keep them in the handoff or Lead's working context unless the user asks for a persistent document.

## Task record

```text
Outcome:
Constraints:
Acceptance checks:
Open questions:
```

## Work contract

```text
Owner:
Blueprint applicability and evidence:
Blueprint path/revision and module IDs (when applicable):
Existing baseline and retained constraints:
Refactor decision, approved scope, and user evidence:
Allowed files, planned additions, and composition-root exceptions:
Affected area or boundary:
Expected result:
Shared contract or compatibility concern:
Verification:
Recovery or rollout consideration:
```

## Verification record

```text
Check performed:
Result:
Evidence:
Remaining risk or unavailable check:
Comment self-check (code changes): files/interfaces/internal logic inspected, test-case explanation coverage, assertion consistency, outcome, exemptions and gaps
```

## Debug hypothesis ledger

```text
Symptom and reproduction:
Observation:
Hypothesis:
Discriminating check:
Result: supported | rejected | inconclusive
Next investigation or fix scope:
```

## Review coverage record

```text
Review scope:
Coverage: correctness | tests | data | unfamiliar area
Comment review (code changes): scope, layered minimums, per-test scenario/expected results, semantic/assertion consistency, exemptions and gaps
Evidence inspected:
Findings: impact, file reference, evidence
Uncovered risk:
```
