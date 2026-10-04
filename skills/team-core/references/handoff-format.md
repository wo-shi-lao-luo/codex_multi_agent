# Handoff format

Every child agent returns a concise handoff:

- **Result:** conclusion or completed bounded work.
- **Evidence:** files, commands, tests, or observations supporting it.
- **Risks:** unresolved assumptions, conflicts, or required decisions.
- **Next step:** the smallest useful action for the Lead.

Writers add changed files and verification performed. Reviewers rank findings by impact and include file references.

When handing off an unresolved issue, include its acceptance behavior, conditions and observed deviation; linked/reopened issue status; repair and diagnostic history with evidence references; relevant external research question, source applicability and local validation (or why research was not done); whether the single ordinary repair extension was granted/used; active user-authorized mode/budget and next stop condition; current changes/tests/process state; pause status and any exact user decision needed. Recover missing history and disclose uncertainty before continuing. See the [repair and diagnosis loop guard](repair-loop-guard.md); a new child or session does not reset its counts or extension eligibility.

Children also report their own returned ID/task handle and any actually available role/model evidence; use `unknown` for metadata they cannot observe. Do not infer loaded identity from the assignment prompt, and do not take over the Lead's roster or spawn additional agents.

## Lead's final actual-agent roster

Every Team workflow's final user-facing response includes the actual child roster, following [role routing](role-routing.md):

For `$team-dev`, the Lead's handoff briefly reconciles the start declaration and Work contract against the actual roles, applicable lifecycle checks, verification evidence and remaining gaps. The roster shows actual calls; it does not by itself prove the workflow checks passed. Report Lead self-check separately from independent Tester/Reviewer evidence. For a material change, a user request for no delegation that conflicts with the required independent Reviewer must be returned for scoped direction, not reported as a completed review.

```text
Agent ID/task handle | role selector sent | scoped task | final known status
Host-reported identity/model (only when confirmed; otherwise unknown):
Deviations, approved alternatives and failed creation attempts (no ID):
Evidence record reference (existing Verification record/stage packet, if present):
```

Include every child created or reused for the current task, including failures, interrupted work and each created retry; do not include unrelated agents from earlier tasks. If no children were used, explicitly report `No child agents used`. Planned roles are not an actual roster. Distinguish role selection evidence from returned/observed role and resolved model; source configuration is not runtime confirmation. Keep the list concise and redacted. Do not persist private paths or raw tool transcripts just to support this list.

For applicable UI work, follow the [UI delivery contract](ui-quality.md): include the brief/baseline reference, functional results, separate visual status, final-page route/viewport/state evidence, fixes and remaining gaps. Agent visual checks do not imply user approval.
