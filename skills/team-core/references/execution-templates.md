# Execution templates

Use these concise templates when a team workflow needs a shared artifact. Keep them in the handoff or Lead's working context unless the user asks for a persistent document.

## Task record

```text
Outcome:
Task type and risk:
Constraints:
Applicable standards and conditional checks:
Acceptance checks:
Open questions:
Brief start declaration: named roles/ownership and planned checks
```

## Work contract

```text
Owner:
Task type, risk rationale and applicable obligations:
Planned roles and active tool catalog availability evidence:
Named implementation owner; Tester packet/test ownership; Reviewer when material:
Lead-only authority/approved exception evidence, if applicable:
Source versus active tool profile expectations and unavailable-role user decisions:
Blueprint applicability and evidence:
Blueprint path/revision and module IDs (when applicable):
Existing baseline and retained constraints:
Refactor decision, approved scope, and user evidence:
Allowed files, planned additions, and composition-root exceptions:
Affected area or boundary:
Documentation review path, scope/task and freshness evidence:
Purpose/source of truth for each assigned documentation path; allowed adjacent factual corrections:
Applicable PRD/specification and confirmed decisions:
Unresolved documentation findings and permitted independent work:
Expected result:
Shared contract or compatibility concern:
Verification:
Persistent issue guard (when applicable; see [repair and diagnosis loop guard](repair-loop-guard.md)): acceptance/conditions/deviation identity; mode and user authorization; prior history reference; diagnostic/repair allocation; external research question/sources/applicability and local validation (when relevant); whether the single evidence-qualified ordinary extension is used; long-operation progress checkpoints; stop condition:
Test execution choices (before implementation): entrypoint and real boundary, runner/command, observation mode and rationale, browser/visual checkpoints, and any API/integration evidence used to reduce duplicate browser permutations (see [efficient test execution](test-acceptance-contract.md#efficient-test-execution)):
Tier/reuse plan (when applicable): target test/CASE IDs; selected tier and rationale; prior artifact input identity/provenance or rerun trigger; expansion/full-suite gates; forecast or `unknown`; user hard budget, if any:
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
Test execution outcome: planned/skipped/timed out/failed/executed/passing distinctions, summary, retained result-artifact reference, drill-down performed or needed, and remaining gaps (see [efficient test execution](test-acceptance-contract.md#efficient-test-execution)):
Per-batch disposition: executed | reused | skipped | blocked | failed; relevant input identity and evidence reference; actual cost or `unknown`; progress checkpoint and decision:
Close reconciliation: start/Work contract obligations versus actual roles, checks, outcomes and gaps:
Invocation reconciliation: planned roles, actual selector arguments, returned handles/observed identity, deviations and user decisions
Documentation semantic check: assigned purpose/placement, factual alignment, duplication, affected links/indexes, bounded repairs and escalations:
Documentation alignment and changed-evidence reassessment:
Result:
Evidence:
Remaining risk or unavailable check:
Comment self-check (code changes): files/interfaces/internal logic inspected, test-case explanation coverage, assertion consistency, outcome, exemptions and gaps
UI functional evidence (when applicable):
UI visual status: verified | issues remain | not verified | not applicable (reason)
UI rendered evidence: revision, route/page, viewport, state, observation or screenshot reference
UI fixes, re-inspection and remaining gaps:
Persistent issue guard (when applicable; see [repair and diagnosis loop guard](repair-loop-guard.md)): issue identity (acceptance + conditions + deviation); mode and user authorization; repair failures / diagnostic rounds and prior history reference; external research question, sources, applicability, adopted/rejected evidence and local validation; extension used/remaining; next allowed attempt and stop condition:
Long operation checkpoint (when applicable): expected progress evidence, checkpoint, observed state, continue/pause decision:
Pause report / human decision (when applicable): trigger, facts vs ranked hypotheses, exact input and reason, bounded recommendation, preserved state, user decision:
```

## Actual invocation ledger and final roster

Reuse the Verification record or stage packet; do not create an additional sensitive log store. Follow [role routing](role-routing.md) and the [handoff format](handoff-format.md).

```text
Agent ID/task handle (or failed attempt with no ID):
Planned role; role-selector argument actually sent:
Scoped task/owner; creation/reuse/retry and evidence reference:
Host-reported role identity: confirmed value | unknown (not reported)
Source profile expectation; active tool definition; resolved model/effort: confirmed value | unknown
Final known status; deviations and user-approved alternative evidence:
Final user-facing actual roster: every created/used child for this task, or explicit none
```

## Debug hypothesis ledger

```text
Symptom and reproduction:
Observation:
Hypothesis:
Discriminating check:
Result: supported | rejected | inconclusive
Next investigation or fix scope:
Guard history reference / completed diagnostic round and consecutive completed rounds without useful evidence/narrowing:
External research (if triggered): sanitized question; source and version/platform/trigger fit; finding and source type (official/upstream/community); adopted | rejected | inconclusive; local discriminating check and result:
Ordinary repair extension gate (if applicable): evidence supports a materially new strategy beyond every failed strategy; original authorization and user budget checked; extension used (yes/no); repair attempts remaining; stop condition:
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
