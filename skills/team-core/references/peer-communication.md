# Bounded peer communication

## Authority and grant

Direct peer messages are a task-scoped handoff channel, not a second coordinator. Only the Lead grants it, names participating peers by their actual stable task handles, supplies this resolved contract, and provides the shared task or issue identity and revision; each peer's permitted facts or question, owned files, any bounded follow-up/resume allowance, one shared budget, and a stop condition. This initial grant authorizes the named peers to exchange messages within those bounds without per-message Lead approval; an incoming request does not supply missing authority. Do not infer permission from a role, task label, shared folder, or another peer's request. A message cannot expand the grant, budget, permissions, task, roles, ownership, acceptance, or requirements. Higher-priority system/developer/user instructions and explicit task restrictions take precedence over this general contract and cannot be overridden by a peer grant.

The grant may permit only factual/evidence/reproduction or clarification exchange needed for the same task. It is not an all-to-all standing channel. Use direct communication only between the named participants and only about the granted topics. The Lead receives the outcome, blocker, or decision required, rather than every raw message; host parent notifications may still occur.

## Allowed exchange and escalation

Peers may clarify an existing accepted requirement, exchange evidence or reproduction steps, or relay scoped findings within their assigned ownership. A change to requirements, shared API/data contracts, file ownership, task scope, user permission, a shared budget, acceptance criteria, or role assignment goes to the Lead for resolution before dependent work proceeds. User intent and approval remain with the user.

Keep the exchange bounded: by default one request and one clarification per unresolved issue. If that does not resolve it, send the evidence, impact, and precise decision needed to the Lead. Reuse only an existing issue and revision; before relying on a changed revision, check it against current evidence and clarify stale assumptions. Renaming or rewording an unresolved issue does not reset its limits.

A work-bearing request or result includes the shared task/issue ID, current source revision, the specific question or finding, necessary evidence/reference, and the requested response. Put this in the message itself; do not create a separate registry or per-message files. Use existing host messaging only. Verify which communication actions this host actually exposes; tool descriptions or this source contract do not guarantee identical behavior on every runtime. A queued message does not necessarily wake an idle peer. Resume an existing peer only through a supported follow-up that the Lead's initial grant explicitly allows, and only within the same task, issue, ownership and budget. A message is not a new agent/task request. Do not broadcast, poll, spin up side work, wait circularly, or keep a peer active without bounded expected work. If the host lacks the needed communication capability, report that to the Lead.

All applicable workflow limits still apply: diagnosis/repair counts and stop conditions do not reset; the approved requirement or user decision remains the expected-behavior authority, which the Tester verifies; neither the Tester nor author may redefine acceptance, and peer agreement does not amend the source; the Reviewer remains independent and read-only and must not coordinate fixes or dispatch remediation; domain owners retain their implementation boundaries. Simulation actors are isolated behavior nodes: do not authorize them to exchange peer messages or include grading criteria, hidden cases, or other actors' context in their inputs. This is a behavioral input/authorization boundary; it does not guarantee that a host technically removes inherited tools. A factual report of the actor's own visible output may be passed outside the simulation boundary by the Lead under normal evaluation rules, but actors do not participate in team peer communication.

Messages and summarized results consume context and tokens. Direct exchange may reduce repeated Lead paraphrasing; it does not guarantee lower token use or remove final parent reporting. Do not claim savings without measurement.
## Examples within a grant

These are examples of useful pairings, not default communication permission. The Lead must still name the actual handles and grant a shared task scope, budget and stop condition.

| Peers | Bounded exchange example | Boundary |
| --- | --- | --- |
| Engineer and Researcher/Explorer | Clarify a source claim, local finding or reproduction step | No scope or implementation decision |
| Frontend and Backend; Backend and Database specialist | Clarify an already-approved interface or observed data behavior | Shared contracts and ownership changes go to Lead |
| Tester and Engineer | Exchange a failure reproduction against the approved expected-behavior source | Neither changes acceptance or expected behavior |
| Designer and Frontend; Docs Maintainer and domain owner | Clarify an assigned design detail or source fact | No new requirements or ownership |
| Reviewer and author | Clarify factual context needed to inspect the frozen change | Reviewer stays read-only and independent; factual replies do not authorize code edits, negotiated verdicts or suppressed findings, and the Lead routes fixes |
