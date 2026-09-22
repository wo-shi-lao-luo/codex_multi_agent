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

## UI brief (when applicable)

Attach to the Work contract and reuse its references across stages; no separate design document is required.

```text
Audience and primary user task:
Page/flow and stage scope within the product:
Content and action priorities:
Visual baseline, existing pages/components/styles and reference paths:
Page/flow owner and authorized page/shared-style files:
Target viewports, states and core interactions:
```

## Verification record

```text
Check performed:
Result:
Evidence:
Remaining risk or unavailable check:
Comment self-check (code changes): files/interfaces/internal logic inspected, test-case explanation coverage, assertion consistency, outcome, exemptions and gaps
UI functional evidence (when applicable):
UI visual status: verified | issues remain | not verified | not applicable (reason)
UI rendered evidence: revision, route/page, viewport, state, observation or screenshot reference
UI fixes, re-inspection and remaining gaps:
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
UI review (when applicable): brief/baseline, integrated-page evidence, visual status and unobserved states
Evidence inspected:
Findings: impact, file reference, evidence
Uncovered risk:
```
