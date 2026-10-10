# Feedback recording

## Purpose and boundary

The supported primary workflows (`team-dev`, `team-plan`, `team-debug`, and `team-review`) may create a small, local run record after their normal user-facing handoff is prepared. When Team is selected explicitly or by task matching, it may select one of these supported workflows and record at most one result under that existing workflow value at final close; it does not add a `team` value. Integrated debug/review phases are not separate closes. Consultation and standalone special adapters, including `team-ai-simulate`, do not call this runtime. The record is evidence for improving this kit; it is not a source-code backup, task tracker, background service, or substitute for the user-facing handoff.

A supported primary workflow may participate through its direct entry or when selected by the Team entry, explicitly or through task matching. Unsupported standalone adapters do not participate. Do not create a record for ordinary conversations or consultations, and do not silently introduce a project-local file, Git change, connector, or external request. If feedback recording is unavailable, treat that as a nonblocking reporting risk; it does not authorize arbitrary home/configuration/install writes.

## Record only minimal, redacted facts

The runtime accepts a JSON payload with these required fields:

```text
schemaVersion: 1
workflow: team-dev | team-plan | team-debug | team-review
objective: concise, non-sensitive task summary
projectPathDigest: redacted label or one-way digest; never an absolute path
acceptanceChecks: array of concise checks
verification: array of { check, result, evidence }
status: passed | completed_with_risk | blocked | failed
rework: { count, reasons }
remainingRisks: array of concise risks
```

Use check names and outcome summaries rather than raw terminal output. Do not include code, logs, tokens, credentials, customer data, or a complete conversation. The optional `candidateSignals` array contains only `{ key, category, summary }` values.

## Close procedure

After preparing the normal Handoff:

1. Create the minimal JSON payload in a safe system-temporary file.
2. Call the installed `scripts/feedback-runtime.ps1` with `-Action Record -InputPath <temp file>`.
3. Remove the temporary input file after the call, whether it succeeds or fails.
4. Mention only a concise recording result in the final Handoff when it is material.

If recording cannot run, preserve the normal task result. Add `Local feedback record unavailable` as a remaining risk; do not retry business work, treat verification as failed, or expose a local filesystem path unless the user asks.

## Candidate interpretation

The runtime automatically derives candidates from failed or unavailable verification, two or more rework passes, remaining risks, and a blocked or failed status. Add an explicit candidate only when the workflow found a distinct, reusable process issue.

Candidates are observations, not automatic rules. They remain `candidate` until the user confirms them. A confirmed item may later become a Skill revision, an acceptance case, a backlog item, or a rejected item with rationale.

## Retention and cleanup

The runtime keeps active runs for 90 days, archives older runs during a later workflow close, and only previews archived runs older than 180 days. Permanent deletion requires a direct user request and both `-DeleteArchived` and `-ConfirmDeletion`; no workflow close may pass those switches.
