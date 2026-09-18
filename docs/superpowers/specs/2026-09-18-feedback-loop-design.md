# Feedback loop and workflow acceptance design

## Status

Approved design. Implementation has not started.

## Objective

Capture small, useful acceptance evidence from the explicit `team-*` workflows, then turn recurring real-project signals into user-approved Skill improvements and regression cases. The mechanism must remain local, inspectable, and clean: it must not create files in a business repository, add a background service, send data externally, or modify Skills without user approval.

## Scope and limits

- Covered entrypoints: `$team-dev`, `$team-plan`, `$team-debug`, and `$team-review`.
- Only a workflow that was explicitly entered produces an automatic run record. Ordinary Codex conversations are deliberately outside the scope; there is no reliable global completion hook.
- Recording failure must never block or invalidate the business task. The final handoff reports that the record could not be written.
- The feature stores no source-code copies, full conversations, credentials, or raw command output. It stores only the minimal evidence needed to improve the toolkit.
- This is not a scheduler, issue tracker, connector, global hook, or automatic Git workflow.

## Approaches considered

1. Conversation-only summaries: no durable history; rejected because it cannot form a feedback loop.
2. Workflow-integrated local records: selected. It is portable across Codex Desktop and CLI, does not require a daemon, and stays out of user projects.
3. A global listener or agent proxy: rejected for now because it requires a background process or deeper product integration and increases permission, reliability, and maintenance risk.

## Local storage lifecycle

The default feedback home is owned by the installed kit, not by a project:

```text
<AgentsHome>\codex-multi-agent\
  runs/        # active, minimal per-workflow records
  feedback/    # candidates and user-confirmed improvements
  archive/     # aged run records and closed feedback entries
```

`<AgentsHome>` is the user-level Agents directory configured during installation. The runtime resolves the feedback home from that value and creates only the needed directories.

Retention is deliberately conservative:

1. A run stays active for 90 days and may participate in normal summaries.
2. On a later workflow close, a run older than 90 days moves to `archive/`.
3. An archived run older than 180 days is only presented in a cleanup preview. Permanent deletion requires explicit user confirmation.
4. Failure traces used for short-term diagnosis are not promoted into the long-term feedback store; after analysis they follow the same preview-and-confirm deletion rule.

There is no timed background cleanup. Lifecycle maintenance occurs only at a workflow close or when the user explicitly requests it.

## Data model

Each workflow close creates one schema-versioned run record. The format should be JSON so scripts can validate, deduplicate, and summarize it deterministically.

Required fields:

```text
schemaVersion, id, recordedAt, workflow, projectPathDigest,
objective, acceptanceChecks, verification,
status, rework, remainingRisks, feedbackCandidateIds
```

`projectPathDigest` is a stable local digest or redacted project label, never a source snapshot. `verification` records command labels and outcome categories rather than raw terminal output. `rework` stores a count and bounded reason categories. The allowed statuses are `passed`, `completed_with_risk`, `blocked`, and `failed`.

Feedback candidates are separate records. They contain a normalized signal key, category, first/last observed times, count, linked run IDs, a concise evidence summary, and a state:

```text
candidate -> confirmed -> applied | rejected
```

Only a user confirmation moves a candidate to `confirmed`. Only confirmed items may create a Skill change, a regression case, or a backlog item.

## Workflow adapters

The common close action belongs in `team-core`; each workflow supplies its own facts.

| Workflow | Record focus | Candidate signals |
| --- | --- | --- |
| `$team-dev` | acceptance checks, build/test result, review disposition | failed verification, missing evidence, repeated rework |
| `$team-plan` | repository evidence, unresolved decisions, plan verification | missing material fact, unworkable dependency or decision |
| `$team-debug` | symptom, discriminating evidence, confidence, fix verification plan | no reproduction, unproven root cause, external blocker |
| `$team-review` | scope, evidence-backed findings, uncovered risks | high-impact finding, missing critical coverage |

At close, the Lead attempts the following in order:

1. Create the normal user-facing handoff.
2. Build the minimal workflow-specific run payload.
3. Ask the local runtime to validate and atomically write the payload.
4. Derive normalized candidate signals and merge them by signal key.
5. Report only a concise recording result in the handoff; do not expose the feedback store unless relevant.

The normal Handoff is authoritative. A local recording error adds a risk note but never causes the workflow to retry business work or claim that verification failed.

## User feedback interaction

Objective signals are captured automatically: failed checks, absent verification evidence, repeated rework, carried risks, and unproven investigation conclusions. Subjective feedback is optional and low-friction. At a meaningful task close or an anomalous run, the Lead may ask one short question such as: “这次流程是否顺手？若不顺，请说最影响的一点。”

No answer is interpreted as no additional feedback, not as satisfaction or failure. Subjective feedback becomes a candidate, never an automatic rule change.

## From feedback to acceptance cases

The runtime aggregates matching candidates rather than creating unbounded duplicates. When the user confirms a candidate, the toolkit converts it into exactly one of:

- a Skill-rule improvement;
- an acceptance/evaluation case with trigger, expected behavior, deterministic evidence check, and source candidate ID;
- a backlog item; or
- a rejected record with rationale.

An acceptance case has an explicit source and can therefore be reviewed, retired, or updated as the workflow changes. Unconfirmed candidate data does not change the test suite.

## Implementation components

1. An installed `team-core` runtime script that validates, atomically writes, aggregates, previews lifecycle maintenance, and requires confirmation for permanent deletion.
2. Shared `team-core` references defining the close payload and failure semantics.
3. Small adapters in each of the four explicit `team-*` Skills.
4. Installer and updater support for the runtime and feedback-home configuration, retaining existing receipt, conflict, backup, and `-WhatIf` safeguards.
5. Documentation covering storage location, fields, privacy boundary, retention, review, and cleanup.
6. Isolated tests that use only temporary directories and remove them after completion.

## Acceptance and verification plan

- Every supported `team-*` workflow can emit a schema-valid minimal record.
- Candidate aggregation merges equivalent signals without losing run linkage.
- A recording failure does not block a workflow close.
- The runtime never writes inside the business repository used by a run.
- Runs older than 90 days are archived on maintenance; any deletion requires preview plus explicit confirmation.
- Installation, update, `-WhatIf`, conflict detection, and backup behavior remain safe.
- Tests cover schema rejection, state transitions, deduplication, archive preview, explicit-deletion gate, recording failure, and cleanup of all test-only files.

## Risks and mitigations

- **Skill adherence is model-mediated.** Explicit workflow entrypoints and a mandatory close section make the behavior predictable, but cannot create an invisible global hook. The record itself is evidence, so missed writes are observable.
- **Feedback can be noisy.** Candidate state and user confirmation prevent observations from becoming rules automatically.
- **Local data can accumulate.** Minimal records, aggregation, 90-day archive, and confirmation-gated deletion constrain growth without silent loss.
- **A user may use only normal prompts.** This is intentional: the feedback loop guarantees coverage only when the explicit engineering harness is requested.
