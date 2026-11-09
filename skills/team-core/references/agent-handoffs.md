# Outcome-based handoffs and work continuity

For direct factual exchange between existing child peers, use the [bounded peer communication contract](peer-communication.md); this outcome-based handoff remains authoritative for ownership, continuity and final integration.

When a parallel production writer used a separate checkout, use the [isolated worktree handoff fields and freeze/integration rules](isolated-worktrees.md). Record the exact checkout, branch, pinned base and submitted commit, changed and unresolved paths, and observed checks in the existing Work/Verification record; this does not create a second task list or alter local-only authorization.

Use this contract when Team work continues across messages, people/agents, threads, worktrees or task records. A handoff represents a coherent outcome and the context needed to act on it; it is not a transcript, child-thread count, or new task list. Keep the existing Work item, issue, stage packet or opted-in specification as the authority for its scope, decisions and acceptance.

## The portable continuation snapshot

Before continuing, reconstruct and pass only the context needed for the next bounded action:

1. **Outcome and identity:** goal, affected behavior/module and whether this is the same outcome, a related child outcome, an independent goal or a successor replacing a goal.
2. **Authority and constraints:** applicable PRD/specification/decision sources and revisions, relevant non-goals and exceptions, current task owner, permissions and user-set budgets. Keep confirmed intent separate from observed implementation, proposals and unknowns.
3. **Current work state:** relevant changed paths, branch/worktree or source snapshot, current implementation/test/review state, known failure identity and budgets, and what has already been accepted or rejected.
4. **Evidence state:** completed versus planned checks, exact evidence reference and input identity, whether evidence is still current, remaining risks and manual/user acceptance still pending.
5. **Next action:** one coherent deliverable, owner, dependencies, verification and stop/decision condition. Include relevant source links and the specific applicable shared guide; do not assume another thread inherits the current conversation.

Use the smallest existing record that can hold this state. Keep the current snapshot in the existing Work contract/stage packet or issue record; link a separate child only when it has its own independently deliverable result. Do not duplicate an OpenSpec task list, create a second issue tracker, write a file per message or tiny tweak, or preserve raw logs when a concise evidence reference is enough. When a durable, portable handoff is needed and no existing accessible record serves, use a versioned `docs/agent/handoffs/README.md` as the active-status/navigation index and one stable `docs/agent/handoffs/<outcome-id>.md` per coherent independently deliverable outcome. Update that existing outcome record at each task update, pause, close or transfer; absorb same-outcome small tweaks rather than creating new files. The index points to the current record and authority, not a second task list or acceptance-results ledger. A local ignored Work record cannot be the sole portable context for a fresh clone: include authorized sanitized continuation context and stable source references in the versioned snapshot, and mark inaccessible results or approvals pending instead of inventing them. The [handoff format](handoff-format.md) remains the concise final return contract. The current source/decision map is governed by [Agent development documentation](agent-documentation.md).

For external research, the Lead may explicitly authorize named peers to request scoped evidence directly from the existing `team-researcher`; follow the [external research contract](external-research.md). These peer messages reuse the same outcome and one shared task budget. They do not create a new owner, task allowance, permission or independent acceptance path. Keep the Lead's final handoff concise and source-linked; automatic parent notification may still occur.

## Continue, reopen, split or replace

Use the outcome and dependency relationship to decide where new work belongs:

| New event | Continuity action | Preserve and report |
| --- | --- | --- |
| A small tweak on the same target outcome | Absorb it into the existing outcome and its current task/packet. Do not open a new child or claim a separate completed outcome for each edit. | Existing constraints, owner and history; update affected files/checks and distinguish the tweak from verified acceptance. |
| Rework of the same incomplete or failed result | Continue the existing outcome. If the same acceptance failure recurs, reopen the existing issue/history rather than minting a clean issue. | Prior attempts, evidence, repair/debug counts and user-authorized budgets. A new agent, branch or method does not reset the issue or limits. |
| A useful independent deliverable discovered during work | Create/link a child outcome only when it can be verified and handed off independently. Keep its parent relationship and dependency clear. | Separate owner, scope, acceptance and evidence; parent work remains open if it depends on the child. |
| A genuinely unrelated goal | Keep it independent with its own scope and authority. Do not append it to the current packet just to reuse a thread. | No inherited acceptance or budget unless the user explicitly makes them shared. |
| An approved redesign of the same goal | Update the existing outcome's plan and source map. Compare old and new assumptions before replacing work. | What is retained, replaced and retired; links to old/new paths; invalidated evidence; new checks; residual risk and approval source. Do not present superseded evidence as current. |
| A new goal replaces the prior goal | Close the old goal only with its true state and link the successor explicitly. The successor is not a continuation that silently changes the old acceptance criteria. | Old result as complete, incomplete, canceled or superseded; new outcome, authority and acceptance independently. Superseded is not verified completion. |

If the relationship is unclear, preserve the current item and report the alternatives to the Lead. Do not merge distinct goals or split one acceptance outcome into message-sized tasks merely for bookkeeping.

## Handoff timing and status

Reconcile the same record at task close, pause, owner/thread transfer, approved redesign or goal replacement. Do not generate a separate handoff document for a trivial continuation. A user may inspect or edit agent-maintained documents; “agent-maintained” describes a maintenance responsibility, not exclusive authorship.

Report status in plain terms:

- **Completed:** the assigned outcome meets its stated checks with reachable, current evidence. State what the evidence does and does not cover.
- **Incomplete / in progress:** work or required checks remain. Name the next owner, concrete trigger/checkpoint and dependent work that must wait.
- **Paused / blocked by decision:** name the exact unresolved decision, its source claims, impact and options. Preserve current state; a timeout or no response is not an approval.
- **Canceled / superseded:** work stopped or replaced. Keep the old history and stable references; do not count it as successful completion or reuse invalid evidence.
- **Pending manual acceptance:** the implementation/check may be complete while human or native acceptance remains open. State the exact pending observation and owner; do not convert “planned,” “written” or “package passed” into accepted.

Reusable knowledge becomes development guidance only after the responsible source is confirmed, assigned and reconciled. Task-specific chronology, test outcomes and formal acceptance remain in the established task/verification record. Preserve prior user decisions and explain which newer decision changes them.

Retire continuity records deliberately. Promote confirmed reusable facts to the appropriate development authority and leave the outcome record as a concise historical pointer with its true terminal state, acceptance status and stable links. There is no age-based or TTL auto-archive/delete. A merge, move, archive or deletion needs separate applicable authorization; first preserve meaningful history, user decisions, pending manual acceptance/risks and inbound references, then update the active index and links. Canceled or superseded outcomes remain distinguishable from completed ones.

## Ownership, snapshots and concurrent writers

The Lead coordinates one current owner for each shared work item. Assign disjoint paths and dependencies before parallel work. Do not allow two writers to independently replace a shared source map, contract, packet or document. Keep each agent/thread/worktree's actual ownership and integration point explicit.

Before a transferred or delayed writer applies a change, compare its expected state to the current one: task/branch or worktree identity, relevant base/head, expected manifest/document hash and affected source/target paths. If they differ, stop and inspect the new work; preserve both sides and ask the current owner to reconcile overlaps. Do not use last-writer-wins, force-reset, silently rebase away unseen changes, or treat an idle/completed child handle as proof that writes have stopped. Transfer ownership only when edits/processes are ended or safely isolated and the receiving owner acknowledges the current evidence.

Before archiving, merging, moving or cleaning an authorized artifact, keep stable references and the useful original history; identify retained, replaced and retired paths and update links. These handoff rules do not authorize deletion, legacy moves, history rewrites or cleanup. Follow the applicable source's approval boundary and stop on disputed or uncertain material.

## Worked lifecycle examples

### Small feature tweak followed by the same failure

An implementer adds a small fallback and later adjusts the same branch condition. Fold both edits into the same outcome. The fallback test still fails under the same accepted case, so reopen the existing issue with both attempts and the original repair budget. Do not create a “new fallback bug” merely because the files or owner changed. The handoff says what changed, the latest result, the preserved history, the next discriminating check and whether any downstream work remains blocked.

### Approved redesign invalidates earlier evidence

The user approves replacing one adapter path with another. Update the existing goal and record the approving decision. List the retained contract, replaced adapter, retired path, new source links and tests invalidated by the change. Rerun only affected evidence under the existing tier/gate rules. Keep the old test result as historical evidence, not current proof; keep user acceptance pending until the new path receives the required observation.

### Goal replacement with a separate pending acceptance

A user cancels a report-generation goal and requests a different export feature. Mark the first outcome canceled or superseded with its partial work and stable references; link the new outcome as its successor, with its own acceptance checks. If the old outcome had a pending manual check, report that it was not completed. Do not copy its “ready” status or claim its artifacts passed the new goal.

### Parallel writers and a stale source map

One owner updates a module guide while another writer holds an earlier map snapshot. Before the second writer applies anything, compare the expected manifest and affected source/target hashes. If the first writer changed the guide or source, stop, read both changes and integrate with the current owner. Keep independent nonoverlapping work moving, but do not overwrite the map or advance a broad Git baseline while any listed delta or coverage gap is unexplained.

## Linked contracts

For confirmed intent and constraint propagation, use [approved constraint continuity](approved-constraints.md). For source-linked project guidance, map freshness, semantic reconciliation and Inspect limits, use [Agent development documentation](agent-documentation.md). For issue-specific diagnosis/repair counts, use the [repair and diagnosis loop guard](repair-loop-guard.md); this handoff guide preserves its history but does not redefine its thresholds.
