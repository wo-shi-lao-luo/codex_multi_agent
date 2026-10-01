# Role routing

The Lead classifies a request before delegating.

| Condition | Roles |
|---|---|
| Code-changing `$team-dev` task, including a small bounded change | One exact named domain implementer plus `team-tester`; the Tester prepares the concise coverage/verification plan before implementation and verifies afterward, with non-overlapping file ownership |
| Substantial document inventory, adoption, consistency or scoped readiness | `team-docs-maintainer` using team-doc-check; Explorer supplies focused code facts, Architect/Tester judge relevant technical/acceptance gaps through Lead |
| UI, component, browser behavior, client state | One `team-frontend-engineer` owns the coherent page/flow using frontend-design and frontend-engineering; `team-explorer` first when scope is uncertain |
| API, service, auth, jobs, integration | `team-backend-engineer`; `team-architect` for cross-cutting contracts |
| Schema, migration, query plan, index, data repair, transaction | `team-database-specialist`; `team-backend-engineer` consumes the agreed contract |
| Unknown root cause | `team-explorer` plus `team-tester`; `team-architect` when causes span modules |
| Any material implementation, regardless of task size or changed-file count | `team-reviewer` independently reviews after the writer's first complete pass; add a relevant domain specialist when risk or boundary warrants it |
| Instruction-only harness/documentation edits that change team behavior | `team-docs-maintainer` as the matching writer plus `team-tester`; add `team-reviewer` when the change is material |
| Pure consultation, read-only investigation/review, or trivial nonbehavior typo/format correction | No implementation-agent minimum; use only roles required by the applicable workflow. A typo/format exception does not apply to behavior-changing Skills, policies or harness-specific agent-routing/configuration. Ordinary application scripts/configuration follow their domain. |

Do not delegate a role merely because it exists. Delegate bounded, independent work with a requested output. Classify scope and risk rather than using file count or line count as a proxy: a one-line permission, data, deployment, security, or compatibility change may be material or high risk. A `$team-debug` investigation may perform bounded diagnostic reproduction and controlled experiments under its current contract, but that does not authorize a production repair; an authorized code repair enters the `$team-dev` implementation requirements and does not bypass its roles or verification.

For code-changing `$team-dev` work, a small scope reduces the number of roles and the size of records, not the applicable workflow obligations. The default minimum is one named implementation owner and `team-tester`; do not force Explorer, Architect, multiple implementers, or document categories when they do not fit. Route scripts/configuration to an existing domain role that matches the actual scope (for example, `team-backend-engineer` for relevant server/runtime work). A behavior-changing Skill, policy, or agent-routing/configuration change to the harness is implementation work, not trivial prose; instruction-only harness content uses `team-docs-maintainer`. If no available named role legitimately fits, pause and ask the user about a specific alternative; do not invent a generic role or silently assign the Lead.

Lead-only implementation is an exception. It requires the user's explicit request that the Lead personally implement the change, or the user's approval of a specific proposed Lead-only exception. Ordinary implementation requests (for example, “do it” or “fix this”) authorize implementation but do not choose Lead-only ownership. When Lead-only is approved, the Lead assumes the writer's domain-skill, ownership, packet, TDD, test-coverage, code-comment and self-check duties. Only this approved exception replaces the separate Tester assignment; the Lead performs Tester planning and execution as self-check, not independent Tester evidence. A material implementation still requires independent `team-reviewer` review. If the user's no-delegation instruction conflicts with that review requirement, explain the conflict and ask for scoped direction; do not self-certify or treat an empty roster as an acceptable review. Lead-only does not waive any applicable stage packet or verification requirement; if a required independent role is unavailable, pause and ask instead of silently substituting the Lead.

The Lead's brief start declaration records task type and risk, applicable standards, intended named roles/ownership, and planned checks. At close, reconcile that declaration against actual selected roles, completed checks, evidence and remaining gaps. Keep both records proportionate to the task and reuse existing Work/Verification records or stage packets.

## Named-role preflight and invocation

These rules apply to explicit Team workflows, not every ordinary Codex conversation. Pure consultation and read-only planning/review/investigation do not inherit the `$team-dev` implementation-agent minimum. Team workflow use does not require an agent for every file; the minimum-team rule is scoped to code-changing `$team-dev` execution and behavior-changing harness edits. Lead-only work is not a workaround for an unavailable required role.

Before delegating, list the roles needed for this task and check their exact names against the **active session's tool role catalog**. Record that availability evidence in the Work contract. TOML files on disk, an installed receipt or the planned role map do not prove that the current session exposes those roles. Check only needed roles; do not block a small task on unused roles.

Select the exact named role through the host's supported role selector. For a spawn tool exposing `agent_type`, explicitly pass e.g. `agent_type: "team-tester"`; use an equivalent documented selector on other hosts. A `task_name` such as `tester`, role text in a prompt or copied model settings does **not** select a named role. Do not omit the selector or silently replace a required Team role with `default`, `worker` or `explorer`. Follow-up messages cannot turn a previously created generic agent into a named Team agent; retain its original identity when reusing it.

Immediately after each spawn, check the selector actually sent against the planned role and inspect available returned identity before allowing dependent work to proceed. If a needed role is unavailable, a spawn fails, the actual selector differs without prior approval (e.g. planned `team-tester` but sent `worker`), or returned evidence confirms the wrong role, pause the affected delegation and dependent work. Stop or interrupt affected active work when appropriate, preserve existing edits, and ask the user with the evidence and options: make the intended role available in a fresh session, approve a specific alternative, or defer the dependent work. Installation, configuration/model changes and reverting edits require their own authority. Independent authorized work may continue. Record the user's decision before any alternative invocation; task urgency is not fallback permission. Keep any wrongly created agent in the actual roster even when the host returned only an ID.

## Invocation evidence and reconciliation

Keep a concise invocation ledger in the existing Verification record or applicable stage packet; do not introduce a separate raw-log store. For each actual creation, record:

- planned role and scoped task/owner;
- active catalog availability evidence and the exact role-selector argument sent;
- returned agent ID/task handle and any host-reported role identity;
- source profile expectation, active tool profile and resolved model/effort **separately**, when relevant and available;
- status, retries/reuse, deviations, user decisions and an evidence reference.

The call argument proves which role was selected; a returned ID proves creation, not independently the loaded role/model. If the host supplies no role or resolved model, mark it `unknown`/`not reported`; never infer it from task labels, prompts, source TOMLs or the parent model. A source profile differing from the active tool definition is an environment discrepancy, not proof of the inference model. Disclose it; if matching that profile is a prerequisite for the task, pause dependent profile acceptance and seek direction instead of silently claiming it was loaded.

At Verify, reconcile planned roles, actual selector arguments and returned identities. A confirmed unexpected identity remains a deviation even if the result was useful. Capture each created retry/replacement as its own entry, including failed/interrupted agents; a failed spawn with no returned ID is an **attempt**, not a created agent. Reused agents keep their original ID/selection and list the additional assignment.

## Final actual-agent roster

At every Team workflow close, the Lead must show the **actually created/used** child agents in the final user-facing response using the [handoff format](handoff-format.md). Include their ID/task handle, selected role, task and final known status, plus role/model limitations or approved deviations. Include all created agents for this task, not only successful ones; distinguish failed creation attempts. If none were used, say so explicitly. Link the existing evidence record when available without exposing sensitive raw logs or exact home paths. Do not replace the roster with planned roles or merely say "the team reviewed it."

These are inspectable workflow obligations. Package validation guards discovery links/resources, not future spawn arguments or an unbypassable runtime gate. Lead and independent reviewers inspect actual call evidence; an authored ledger alone does not authenticate execution. See the official [Codex subagent configuration guide](https://learn.chatgpt.com/docs/agent-configuration/subagents) for the distinction between built-in and configured custom roles.

Apply the [UI delivery contract](ui-quality.md) to preserve the original product goal, visual baseline and final-page verification when routing UI work. Small demos normally retain one implementer; page ownership does not remove modular code or file boundaries.
