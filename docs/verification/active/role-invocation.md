# Verification: Named role invocation and actual subagent handoff

Packet schema version: 2
Stage slug: role-invocation
Contract status: implemented; focused automated checks passed; manual acceptance pending
Final manual status: manual pending
Final manual evidence:


## Stage context

Objective: explicit `$team-*` work invokes the intended named subagent role and discloses every actually called subagent in final handoff, including failures or retries. A task label or prompt does not select a role.

Scope: shared role routing, handoff instructions, team entrypoints, package validator, isolated validator tests, and this packet. Lead owns production; tester owns `tests/test-validate.ps1` and this packet. Existing `docs/architecture.md` and approved user requirements are adequate; no Blueprint refactor or OpenSpec integration applies. Lead's task review is `docs/governance/reviews/role-invocation.md`.

Environment: PowerShell 7 copies the package into a unique temporary fixture, mutates it, restores it, and finally verifies/removes the exact directory. No real installation, global settings, or network. The active invocation chose `agent_type=team-tester`; source profile is GPT-6.1 Sol/medium, while active tool metadata advertises GPT-6 Sol/medium. Runtime loaded model is unknown. A confirmed role mismatch blocks dependent work; missing returned identity remains unknown.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| ROLE-01 | Named specialist available | Preflight and spawn explicit named role | Record expected, selected, returned/unknown role, agent ID, task and status | happy |
| ROLE-02 | Task label says `team-tester`, selected role generic | Compare plan and actual spawn | Immediately pause dependent work, preserve the wrong agent ID, report mismatch and ask user before a substitution | edge |
| ROLE-03 | Named role unavailable | Preflight and consider substitution | Ask user before different role; pause affected delegation | edge |
| ROLE-04 | Child failed then retried | Reconcile attempts | Final handoff retains both actual agents, statuses and IDs | edge |
| ROLE-05 | No child invoked | Close workflow | Explicitly state no subagents called | alternate |
| ROLE-06 | Valid role link replaced by another valid link | Validate isolated package | Reject missing route for each required entrypoint | regression |
| ROLE-07 | Shared handoff contract removed | Validate isolated package | Reject missing contract; restore and pass | regression |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No exported role selector or isolated algorithm is added. |
| integration | required | Package validator checks bundled entrypoint contracts. |
| contract/API | required | Each team workflow must retain role routing and shared handoff guidance. |
| E2E | conditional | Real multi-agent trial is needed to observe future spawn choices. |
| regression | required | A valid replacement Markdown link must not hide lost role routing. |
| manual | required | User checks preflight, substitution pause and final audit. |
| component/UI | not applicable | No interface changed. |
| accessibility | not applicable | No rendered interaction changed. |
| visual regression | not applicable | No visual artifact changed. |
| performance/load | not applicable | Static instructions and package guards have no material load path. |
| security | conditional | Misleading role/model claims affect audit; manual honesty checks apply. |
| compatibility | required | Existing bundle layout and source role profiles remain valid. |
| data migration/rollback | not applicable | No persisted data format changes. |
| resilience/recovery | conditional | Failed/retried attempts must remain visible; runtime crash recovery is outside scope. |
| exploratory/usability | required | Reader can reconstruct who actually did what from handoff. |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Required role routes | Missing named role contract hides behind valid link | contract/API | test-first | `tests/test-validate.ps1` role route mutations | 2026-09-30 initial suite exit 1: validator accepted removed team-dev route; fixture cleaned | 2026-09-30 focused suite exit 0; all six route mutations rejected; fixture cleaned | Final rerun after Lead edit exited 0 | Package guard cannot prove future calls | Tester / Lead | passing |
| Shared handoff contract | Actual agent audit instruction omitted | regression | test-after | `tests/test-validate.ps1` missing handoff contract | not applicable | 2026-09-30 focused suite exit 0; missing contract rejected; fixture cleaned | Final rerun after Lead edit exited 0 | Existing baseline validator already required this file; new assertion verifies preservation without claiming a new Red | Tester / Lead | passing |
| Actual named invocation and roster | Prompt-only selection or omitted failed agent | manual | manual-or-environmental | Human script below | not applicable | manual pending | no refactor | Static tests cannot inspect future agent calls or authenticate runtime identity | Lead / user | manual pending |

## Automated test and E2E plan

Initial Red before production edits: `tests/test-validate.ps1` exited 1 with `Validation accepted missing named-role routing in team-dev.` The validator passed that mutated copy; its exact temporary fixture was removed. Downstream route and handoff assertions were authored but not reached, so no individual Red is claimed. After Lead integration, the same suite exited 0 with `Validation tests passed.` and `Isolated validation directory removed.` All six required Team entrypoint mutations were rejected; the missing handoff file was rejected and restoration passed. The handoff assertion is test-after preservation coverage because the existing validator already required that file. Lead's additional regression runs `tests/test-stage-verification.ps1`, `tests/test-documentation.ps1`, and fake-home `tests/test-install-user.ps1` each exited 0 and cleaned their temporary fixtures. Static tests cannot certify future spawn choices; use the manual steps below.

## Human verification script
### Preparation

1. Choose a disposable bounded development task; inspect available named role metadata and record planned role plus source profile.
   Expected result: role availability is known; source/model metadata is not treated as proof of loaded runtime model.

### Happy path

1. Assign a bounded specialist task and explicitly choose that named `agent_type` at spawn.
   Expected result: selection matches plan; a prompt or task label alone is insufficient.
2. Wait for the child and close the workflow.
   Expected result: final handoff lists actual role selection, ID, task and status; returned role/model is reported if exposed or marked unknown.
3. Complete a small team workflow with no children.
   Expected result: final handoff explicitly says no subagents were called.

### Recommended edge cases

1. Make an intended role unavailable before delegation.
   Expected result: affected task pauses for user approval before substitution; there is no silent generic fallback.
2. Let a child fail, then retry with a second child.
   Expected result: both actual attempts and statuses remain in the final roster.
3. Give a generic worker a task name mentioning `team-reviewer`.
   Expected result: the Lead immediately pauses its dependent work, preserves the wrong agent ID and selected generic role in the record, reports the mismatch, and obtains the user's decision before any substitution. The task name is not mistaken for role selection.
4. Compare source role profile with different tool-advertised model metadata.
   Expected result: source and tool evidence are distinguished; actual loaded model remains unknown absent a returned proof. Confirmed role mismatch blocks dependent work.

### Result

Observations: manual verification pending. Current task's actual subagent roster:

| Agent ID | Explicit selected role | Assigned task | Status | Returned resolved identity/model |
| --- | --- | --- | --- | --- |
| `/root/role_checks` | `team-tester` | Isolated role-route tests and this packet | completed | unknown / unknown |
| `/root/role_review` | `team-reviewer` | Independent workflow review | completed | unknown / unknown |

The spawn responses returned handles/task names but did not establish resolved runtime role or loaded model. Active tool definitions advertise GPT-6 Sol/medium for tester and GPT-6 Sol/high for reviewer; source TOMLs specify GPT-6.1 Sol at the same efforts. This source/session difference is disclosed, not certified as a fallback or exact-profile match. No failed or retried child occurred in this scoped task. The independent reviewer checked five hypothetical cases; after Lead strengthened the immediate wrong-selector pause, reviewer validation and diff check exited 0 with no remaining material finding. No extra child was spawned for those cases. Clean any future manual disposable fixture after recording observations.

## Comment self-check

Inspected `tests/test-validate.ps1` after the Green run: file overview still explains the isolated package boundary; each new scenario block states scenario and observable expected result. The role mutation asserts route existence and validator rejection, and restoration passes; the handoff removal asserts rejection and restoration. Comments match assertions and results. No owned comment gap remains.
