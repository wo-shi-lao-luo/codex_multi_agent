# Agent thread lifecycle verification

Packet schema version: 2
Stage slug: agent-thread-lifecycle
Contract status: scoped implementation verified; native close and human acceptance pending
Final manual status: manual pending
Final manual evidence:

## Stage context
- Objective: manage completed child threads through evidence-backed reuse/closure without losing results, work ownership or exact named-role gates.
- Scope: instructions in existing Team workflow/shared contracts; no host runtime, new API, role, configuration limit or release bump. Current1.0.4 and all previous documentation-consolidation changes are preserved.
- Environment/data: synthetic lifecycle snapshots and host capability descriptions under protected `_work/agent-thread-lifecycle/`; no real thread is closed by these scenarios. This session exposes list/interrupt/followup but no documented close operation, so actual closure/capacity release remains native/manual pending.
- Blueprint: no new architecture/module or code boundary. Lead supplies approved design and existing instruction responsibilities; Tester owns only this packet and controlled scenario materials. No existing packet is rewritten.
- Cleanup: retain bounded ignored scenario/evaluation evidence; any separately authorized disposable native fixture must be inspected and safely released through its actual host. No unrelated thread interruption or deletion.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| TL-01 | Session has prior child handles | Start task and reach phase/handoff/close boundaries | Inspect actual roster/capabilities at event checkpoints; no polling watcher or assumption that old completion released slots | happy |
| TL-02 | Child completed, evidence/open issues collected, writes/process ownership ended, no further need; host documents closure | Assess eligibility, invoke supported closure, inspect returned lifecycle/capacity evidence | Close only eligible thread; successful supported closure is actual lifecycle progress that may permit one bounded queued-role retry, not numeric/durable capacity proof; preserve result evidence | happy |
| TL-03 | Completed named Tester is needed next; a generic child has a similar task label | Select reuse strategy | Reuse suitable original named Tester with bounded next assignment; do not convert generic identity by prompt or close reserved-needed Tester | alternate |
| TL-04 | Child running, waiting result, reserved for review, unclear, or owns outstanding process/writes | Evaluate possible capacity cleanup | Do not close/interrupt these children merely to make room; gather handoff/end ownership first where legitimately completed | edge |
| TL-05 | Correct named Reviewer spawn rejected for capacity; host has no close tool | Inspect roster and capacity facts, keep exact-role work queued | Report unavailable release; no invented close/archive substitute, blind retry, role fallback or main-agent takeover; independent authorized work only | edge |
| TL-06 | Eligible closure fails or returns unknown release; later host supplies actual capacity/state change | Reconcile evidence before any retry | No released-slot claim or retry from failed/unknown close alone; preserve queued role and only bounded retry after qualifying actual host evidence | edge |
| TL-07 | Child result completed, another interrupted, UI task archived | Produce final roster and closeout explanation | Completion/interruption/UI/archive are not capacity proof; record separate lifecycle result, unresolved work, release unknown and exact invocation identities | edge |
| TL-08 | Completed child labels its running process handed off, but process lifetime is still child-bound or unknown | Inspect actual process independence and accepted owner before eligibility | A nominal handoff is insufficient; do not close if closure could kill or orphan useful work; safely end or verify independent accepted transfer first | edge |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No executable lifecycle algorithm added; keyword counts would not establish safe decisions |
| integration | conditional | Actual host close/list/capacity integration unavailable here; native exercise remains planned |
| contract/API | required | Check capability/role/routing instructions and package references; do not invent a close API |
| E2E | required | Plan every native workflow case; controlled decisions are a substitute probe, not achieved native E2E |
| regression | required | Existing exact-role minimum, ownership, Tester/Reviewer sequencing and capacity ceiling remain intact |
| manual | required | Host release semantics and meaningful handoff evidence require native/human observations |
| component/UI | not applicable | No product UI changes; host UI archive is explicitly not a closure substitute |
| accessibility | not applicable | No rendered interface changes |
| visual regression | not applicable | No visual feature |
| performance/load | conditional | Capacity-pressure case is planned; no unsupported live slot/token savings measured |
| security | required | Protect active/unknown/reserved work and outstanding process ownership against premature termination |
| compatibility | required | Hosts without close capability fail honestly without fallback; original child identity retained |
| data migration/rollback | not applicable | No storage, installation, schema or version migration |
| resilience/recovery | required | Failed/unknown closure and capacity rejection keep named-role work queued without blind retries |
| exploratory/usability | required | User-visible blocked/closed/reused evidence must distinguish facts from unknowns |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TL-01/02/03 lifecycle and reuse decisions | Lost evidence or premature closure | E2E | manual-or-environmental | Thread.Controlled.TL-01..03; Native.TL-01..03 | not claimed | Controlled responses adequate; TL-02 optional queued retry not elicited | Task-start source precision amended and inspected; native remains pending | Instructions are nondeterministic; no native close tool in session; actual native sequence not performed | Tester / Lead | manual pending |
| TL-04/05/06/08 unsafe cleanup and capacity recovery | Terminated live work, unsafe nominal process transfer, wrong-role fallback, fabricated capacity | security | manual-or-environmental | Thread.Controlled.TL-04..06/08; Native.TL-04..06/08 | not claimed | Controlled responses satisfy safety expectations | Final source ownership/capacity gates inspected; native remains pending | Decision probes do not execute host close, transfer processes or prove release | Tester / Lead | manual pending |
| TL-07 lifecycle evidence and unchanged gates | Completion mistaken for release or handoff ambiguity | regression | manual-or-environmental | Thread.Controlled.TL-07; Native.TL-07 | not claimed | Controlled response preserves state distinctions and unknowns | Final source/roster claim inspection | Semantic evidence reconciliation is judgment, not a string-matching test or actual capacity proof | Tester / Reviewer | manual pending |
| Shipped links and existing configuration | Missing instruction route or changed thread limit | contract/API | test-after | Package.ThreadReferences; Existing.ConcurrencyConfig | not claimed | Fresh package validator and concurrency fixture checks passed | Package validator rerun after exact task-start source amendment; unchanged concurrency inputs | Existing guards observe package/config integrity, not future tool behavior; no production algorithm added | Tester / Lead | passing |

## Automated test and E2E plan
- Postfreeze controlled evaluation: a Lead-selected existing named role reads exact fresh source instructions and only raw scenario facts, returns proposed actions and evidence. Tester scores actual response against TL cases; no expected answers in evaluator fixture. The evaluator does not close real threads or self-score.
- Fresh scoped commands after writer freeze: `scripts/validate.ps1`, `tests/test-agent-concurrency.ps1`, and `stage-verification.ps1 -Action Validate -ProjectRoot . -StageSlug agent-thread-lifecycle`. Lead coordinates changed bilingual pairs if any. No full installer/deployment suite solely for instruction edits, no mislabeled reuse of previous documentation-task results.
- Cost forecast: scoped commands seconds to a minute, conceptual evaluator unknown; checkpoint each command/returned evaluation. Native close tests require a host exposing actual documented closure and separately authorized expendable work. No polling watcher, paid operation or hard universal cutoff.
- Package/link/config checks do not establish semantic lifecycle correctness. Every manual case remains in native E2E plan with conditions and explicit expected checkpoints; unavailable actual closure is not an accepted exception or passing E2E superset.

### Manual-to-automated coverage mapping
| Manual case / requirement ID | E2E scenario and explicit checkpoints | Other applicable layers | Status/evidence | Gap / user exception |
| --- | --- | --- | --- | --- |
| TL-01 | Native.TL-01 inspect roster at task/phase/handoff/capacity rejection/close, without repeated watcher polling | Thread.Controlled.TL-01; package routes | Controlled decision adequate; exact task-start source wording clarified | Native event cadence pending |
| TL-02 | Native.TL-02 preserve handoff/issues, end ownership, close eligible child, inspect actual result/release evidence and qualifying queued retry | Thread.Controlled.TL-02; readonly source audit | Close/no-release decision adequate; optional queued retry not elicited because fixture supplied no queue; explicit source rule inspected | No actual close tool here; successful-close-to-spawn branch remains native pending |
| TL-03 | Native.TL-03 reuse named Tester handle, retain original identity and next-step ownership; leave reserved reviewer open | Thread.Controlled.TL-03; concurrency/config guard | Controlled decision adequate; this task actually reused original handles | Native resolved role/model remains unknown; reuse does not establish slot release |
| TL-04 | Native.TL-04 encounter each active/waiting/reserved/unclear/outstanding-process condition, verify no room-making termination | Thread.Controlled.TL-04; ownership review | Controlled decision adequate | Native safety observations pending |
| TL-05 | Native.TL-05 capacity rejection without close; exact-role queue retained, independent work only, no invented API/fallback | Thread.Controlled.TL-05; named-role contract review | Controlled decision adequate | No artificial real capacity exhaustion performed |
| TL-06 | Native.TL-06 failed/unknown close then actual supported host-state change; no earlier blind retry or release claim | Thread.Controlled.TL-06; failure/recovery contract review | Controlled decision adequate | Native close failure/capacity evidence pending |
| TL-07 | Native.TL-07 final actual roster distinguishes completed/interrupted/archived from closed/released and preserves gaps | Thread.Controlled.TL-07; handoff evidence review | Controlled decision adequate; actual reused roster recorded below | UI archival is not capacity evidence; user acceptance pending |
| TL-08 | Native.TL-08 inspect process lifetime and actual owner acceptance, reject nominal unsafe transfer before close | Thread.Controlled.TL-08; process/ownership boundary review | Controlled decision adequate | No real process termination performed; native lifetime evidence pending |

## Human verification script
### Preparation
1. Use an expendable task in a host with known documented list/reuse/close semantics. Record actual capabilities and limits; do not change global thread settings. Prepare completed, reserved-needed and active children plus a child with an owned background process only when safe and separately authorized.
### Happy path
1. TL-01/02: Complete a bounded child, inspect Lead handoff and phase boundary. Expected: results/checks/open issues preserved, no outstanding write/process ownership, actual host-supported close only for no-longer-needed child; release claims supported separately.
2. TL-03: Reuse a completed named Tester for the next bounded test task. Expected: original role/handle identity retained, no generic-to-named conversion, required Tester/Reviewer responsibilities remain.
### Recommended edge cases
1. TL-04: Present active, waiting-result, reserved-review, unknown-state and outstanding-process children. Expected: none terminated merely to gain capacity; incomplete handoffs clearly reported.
2. TL-05: In a safely controlled host encounter correct-role capacity rejection and no close capability. Expected: queue that exact role, report limitation, proceed only with independent authorized work; no undocumented API, main takeover or blind retries.
3. TL-06: Observe a failed/unknown supported closure result. Expected: no released-slot claim or retry from that result alone; retry only after actual supported closure/capacity/state-change evidence, retaining the same role. A supported successful close can qualify one bounded retry without a numeric free-slot field, but not a numeric/durable capacity claim. Never intentionally kill valuable work to create this condition.
4. TL-07: Inspect final report after completion, interruption or UI archive. Expected: these labels do not prove release; lifecycle, capacity, retained evidence and invocation identities remain distinct.
5. TL-08: In a safe expendable fixture inspect a completed child's claimed process handoff. Expected: before closure, verify actual accepted ownership and process independence from child termination; when either is unclear, do not close or orphan the process merely to free a slot.
### Result
- Native actual-close workflow and human acceptance pending; no real thread termination is authorized by this packet. Keep active until genuine user acceptance or explicit deferral.

## Verification record
- Existing test commands/conventions and exact source Team contracts read before planning. Narrow Work protection established before fixture creation; previous uncommitted changes preserved. No production Skill/config or older verification packet edited by Tester.
- Handle `/root/doc_consolidation_tests`, reused original selected role `team-tester`; resolved runtime role/model unknown. No child spawned. Final commands, fresh source identities and evaluation outcomes will be recorded only after writer freeze.
- Postfreeze fresh scoped checks: package validator reported passed; concurrency fixture checks reported passed with exact temporary fixture removed; packet validator exit0 with manual pending. The combined invocation exited0 in2.33s. No native lifecycle state, numeric capacity, token savings or installed-profile adherence was measured.
- Tester independently inspected the complete fresh-source evaluator response for all eight synthetic cases. TL-01 reconciles live task-owned roster and phase/capacity/closure checkpoints; TL-02 permits documented eligible close and refuses release claims; TL-03 keeps original named Tester identity and reserved Reviewer; TL-04 protects all active/waiting/reserved/unclear/outstanding-ownership children; TL-05 keeps the exact Reviewer queued with no invented close or archive/interrupt workaround; TL-06 requires meaningful host evidence before a bounded same-role retry; TL-07 keeps completion/interruption/archive/close distinct; TL-08 rejects nominal handoff of a still-child-bound job. These satisfy the elicited decision expectations, not actual host E2E or universal behavior proof.
- TL-02 optional successful-close-to-queued-spawn action was not discussed by the evaluator because its facts supplied no queued role. This is an unelicited optional branch, not a prohibited decision or an invented passing test. Fresh source explicitly permits one bounded same-role retry after successful supported close without requiring a numeric free-slot field; source inspection is separate evidence. Native execution remains pending; no forced rerun was performed just to obtain a favorable answer.
- One evidence-led source precision correction: initial shared checkpoint sentence said before spawning but omitted explicit task start for reuse-only tasks. Lead assigned Writer the exact sentence amendment; final source now says at task start and before spawning. This was a bounded instruction clarification, not a native failed repair or fabricated Red/Green. Final package validator rerun passed on this amended source; concurrency/public-pair inputs were unchanged by that sentence and their corresponding results remain applicable.
- Final source SHA256: Team Dev Skill `670948577A790CBCC0EAE240B90B583B2ED59C013DBF722D11072DCF54B42887`; role routing `3BBF32EB6088C3BEE269E6B156245486478DAE796F0ED628A89948F6C9EFB5E7`; handoff `DE22069EF27392C32E5B3771501B5F2A9BD740AA9ED09820C0914301B20AF58C`; execution templates `0E8BCBD7A0C43C4E2E6C7916C16160342C3334F829A6B8DEEA771A122CED1457`; raw synthetic facts `A5D68C236A07FCA2008AD49F2B03FBF156EB8D7ECB9EC1116A66E0EB8AC62E38`. No complete environment/input manifest or prior full-suite reuse is claimed.
- Writer reported diff check, public-doc structural validation and bilingual tests passed with fixture cleanup, complete language-pair semantic inspection and unchanged historical release sections. Optional Skill-creator Python quick-validator remains unavailable due missing PyYAML; metadata/links were inspected separately and package validation passed, without installing dependencies or claiming that optional check passed.
- No executable test code was added: scenario purposes, preconditions and expected observations are in the packet; evaluator facts deliberately omit expected answers. Existing test-case explanations/configuration were preserved; no formatter, assertion weakening or unrelated readability sweep occurred.
- Current host exposes no documented child close operation. All four task-reused child handles below were not closed; completion is not release. No real close, interruption, process termination, new spawn, install, commit or push occurred in this task. Local feedback recording was not executed under the known temporary/write constraints; no new feedback failure or business-work retry is claimed. Lead owns final readiness publication and Reviewer closure review after this packet freezes.
- Lead reported sequential Work/Documentation Protect and Check exit0, protected/clean with no added rules, violations or required decision at close. Live roster was inspected: evaluator complete; Writer, Tester and Reviewer still needed for final closure duties, so no close was attempted and no capacity release claimed. Governance publication results will not be appended after its final snapshot, avoiding self-invalidating packet edits.

### Actual task invocation roster and lifecycle
| Reused handle | Original selected role | This task responsibility | Current known lifecycle |
| --- | --- | --- | --- |
| `/root/doc_consolidation_writer` | `team-docs-maintainer` | Instructions and paired public-doc maintenance | Production complete/frozen; final readiness input pending; not closed |
| `/root/doc_consolidation_tests` | `team-tester` | Pre-GO packet, scoped verification and independent scoring | Complete and frozen after handoff; not closed |
| `/root/formatter_docs` | `team-docs-maintainer` | Read-only fresh-source synthetic decision evaluator | Completed; no native operation; not closed |
| `/root/readability_review` | `team-reviewer` | Independent source and final packet review | Source audit complete; final packet inspection pending; reserved and not closed |

Lead supplied original exact role-selector/handle evidence for these follow-up reuses. No new spawn or generic-role conversion occurred. Loaded runtime role/model metadata remains unknown; selected role and expected source/tool profile are not resolved model proof. Retained results and actual reuse do not establish any released slot.
