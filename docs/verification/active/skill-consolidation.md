# Verification: Skill procedure consolidation

Packet schema version: 2
Stage slug: skill-consolidation
Contract status: active
Final manual status: manual pending
Final manual evidence: No installed-profile/runtime behavior or user acceptance observed.

## Stage context

Objective: Shorten duplicated procedural prose in twelve Skill entrypoints while preserving canonical authority and safety; clarify targeted small-task/bug testing in the existing shared test contract.
Scope: team-dev/plan/review/debug/doc-check/project-rules/testing-engineering/code-review/backend-engineering/database-engineering/frontend-engineering/team-ai-simulate and test-acceptance-contract.md. Tester owns only this packet; Docs owns normative edits, Lead owns readiness/integration and independent Reviewer owns review. Preserve prior dirty test-checkpoints changes; HEAD is not the preimplementation baseline. No helper/schema/model/version/install change.
Conventions: existing PowerShell package/link and schema2 packet validators. No brittle prose-regex tests, new framework or model simulation; prompt semantics need complete source/reference inspection. Plan established before writer START; wait frozen-source GO before final checks.
Data/cleanup: local source only, no fixtures or temporary files planned; no network, paid action, homes/global-config write, child spawning or commit. Lead has already applied workspace/artifact governance. This packet is the sole formal verification/manual record for this task, not a new manual framework.
Measured preimplementation baseline: ReadAllText().Length of all sixteen current skills/*/SKILL.md files totals 111086 characters; team-dev 18347. Confirmed independently before writer START, including prior dirty checkpoint wording. Characters are not tokens or measured model savings.

## Use-case map

| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| SC-01 | Cheap standalone bug with known narrow impact | Follow compact entrypoint and targeted test guidance | Practical reproduction/affected regression plus relevant smoke close this bounded task when due evidence passes; no automatic costly unrelated suite or skipped required gate | happy |
| SC-02 | Several small fixes form a batch | Run affected checks per fix and integration checkpoint | Each fix retains its regression; batch integration flushes relevant deferred evidence before reliance/acceptance | alternate |
| SC-03 | Security/shared/data/unknown impact or required fresh gate | Apply canonical expansion/authority | Risk/freshness overrides cheap default; no inferred budget, paid action or reuse exception | edge |
| SC-04 | UI, OpenSpec or simulation condition changes applicability | Follow explicit conditional routes | Applicable UI/visual/spec rules read and retained; non-applicable paths not forced; simulation remains explicit, bounded and separate from engineering/acceptance | edge |
| SC-05 | Named role missing, instruction edit, repair threshold or manual/TDD status | Follow canonical guard and handoff | No generic substitution/implicit approval/fabricated Red or manual pass; repair identity and evidence retained; planned work never counts passing | edge |
| SC-06 | Compact Skill links selected shared references | Read selected authority fully and resolve conditions | Entrypoint remains usable; whole selected instructions read, references resolve and no duplicated competing authority or weakened scope emerges | happy / edge |

## Coverage-category decisions

| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No algorithm; keyword matching cannot prove prompt semantics. |
| integration | required | Existing package validator observes distributable local routing. |
| contract/API | required | Inspect canonical-vs-entrypoint contract; no product API. |
| E2E | required | Real installed Codex use SC-01 through SC-06 remains pending. |
| regression | required | Semantic guard preservation and prior checkpoint compatibility. |
| manual | required | User confirms actual behavior, separate from source review. |
| component/UI | conditional | SC-04 retains UI obligations if actual task has visible UI; this task has no product UI. |
| accessibility | conditional | Retain applicable UI/a11y rules; no rendered controls changed here. |
| visual regression | conditional | Preserve rendered inspection authority; no visual artifact authored here. |
| performance/load | conditional | Entry character sizes measured; runtime/token savings unknown and not claimed. |
| security | required | Authorization, high-risk expansion and paid/budget boundaries preserved. |
| compatibility | required | Existing role/Skill names and canonical routes remain coherent. |
| data migration/rollback | not applicable | No storage/helper/install migration. |
| resilience/recovery | required | Repair thresholds/failure history and dependent-work blocking survive consolidation. |
| exploratory/usability | required | Compact entrypoints still expose triggers, boundaries and complete selected authority. |

## TDD behavior matrix

| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Small-task and batch checks SC-01/SC-02 | Over-testing or weakened completion evidence | E2E / regression | manual-or-environmental | Semantic.SC-01/SC-02; ConsolidationE2E.SC-01/SC-02 | not applicable | Source walkthrough complete; actual E2E unexecuted | No executable refactor | Source walkthrough is smallest credible observation; runtime adherence unavailable, no model simulation needed | Tester / user | manual pending |
| Canonical condition/guard preservation SC-03 through SC-06 | Lost authority, safety or full selected reads | security / contract/API | manual-or-environmental | Semantic.SC-03 through SC-06; ConsolidationE2E.SC-03 through SC-06 | not applicable | Complete entrypoint/relevant canonical source inspection | No executable refactor | Source semantics cannot establish loaded-agent behavior; native observations remain pending | Tester / user | manual pending |
| Package/link and stage integrity | Missing resource or malformed evidence | integration / compatibility | test-after | scripts/validate.ps1; stage-verification.ps1 Validate; diff hygiene | not applicable | Frozen-source package/link and diff checks exit0; packet valid | Helpers/schema unchanged | Existing validator covers final authored routing; no new algorithm justifies retrospective Red | Tester | passing |

## Automated test and E2E plan

After Lead GO: run package/link validator once on frozen source; scoped diff hygiene and packet Validate; read all twelve changed Skills and their selected shared authorities in full, checking conditions and observable decision outcomes for SC-01 through SC-06. Compare current source entry sizes with measured working-tree baseline using same ReadAllText method. No full deployment/docs-policy/stage suite or public-pair suite unless relevant inputs change. Forecast unknown, no user hard budget inferred. Read concise command result first; drill down failures. Browser/API/model simulation supplies no meaningful source-instruction evidence here.

| Manual case / requirement ID | E2E scenario and checkpoints | Other layer / source observation | Status / gap |
| --- | --- | --- | --- |
| SC-01 | ConsolidationE2E.SC-01: narrow bug reproduction, affected regressions/smoke and due gates | Full small-task contract and selected Skills | planned; actual native behavior pending |
| SC-02 | ConsolidationE2E.SC-02: multiple fixes retain per-fix regressions; batch checkpoint flush | Full tier/checkpoint/reference inspection | planned; actual native behavior pending |
| SC-03 | ConsolidationE2E.SC-03: high-risk/unknown/freshness override without authority expansion | Canonical security/reuse/budget review | planned; actual native behavior pending |
| SC-04 | ConsolidationE2E.SC-04: applicable UI/spec path retained, uninvoked simulation stays uninvoked | Full conditional reference review | planned; actual native behavior pending |
| SC-05 | ConsolidationE2E.SC-05: missing role, approval/TDD/manual/repair guards | Full selected safety/acceptance references | planned; actual native behavior pending |
| SC-06 | ConsolidationE2E.SC-06: choose relevant canonical source, read all selected instructions and complete scope | Existing package links plus full-source walkthrough | planned; actual native behavior pending |

## Human verification script

1. Preparation: use separately authorized installed source in disposable local project; record exact revision/instructions and synthetic inputs. No installation is performed in this source task.
2. SC-01: request a known narrow standalone bug. Expected: focused reproduction/regressions and relevant smoke support bounded completion; no automatic unrelated costly test or waived gate.
3. SC-02: request a related batch of small fixes. Expected: each regression retained, batch integration checks and named due evidence flushed before reliance/acceptance.
4. SC-03: introduce high-risk/unknown-impact or required fresh CI condition. Expected: appropriate early expansion, truthful evidence and unchanged budgets/authority.
5. SC-04: compare UI/non-UI, enabled/unenabled OpenSpec and uninvoked simulation tasks. Expected: only applicable complete shared instructions govern; UI/spec acceptance not lost and simulation not implicit.
6. SC-05: present unavailable named role, unapproved instruction edit, pending human result and repair threshold. Expected: exact existing guard/return path, no fabricated approval/pass/Red or reset history.
7. SC-06: follow compact routes. Expected: all selected instructions read completely, canonical authority clear, local resources resolvable and task-specific guidance retained.
8. Record user observations here; delete only any exact owned disposable fixture. Final manual status stays pending without actual user evidence or explicit deferral.

## Verification record

Preimplementation plan validated before writer START. Fresh frozen-source `pwsh -NoProfile -File scripts/validate.ps1` exit0 (package and local resource routing); `git diff --check` exit0. Nonfatal LF/CRLF warnings reflect Git conversion, not a failed check. Packet Validate exit0 before handoff. No test code/formatter changes; scenario purpose/expected-result explanations preserved. Earlier checkpoint dirty changes remain outside this task's rewrite ownership; prior task results are not a fresh consolidation pass. No fixture/temp file, full suite, model simulation, real installation or runtime/token-savings/manual-acceptance claim.

Semantic inspection read all twelve final Skill files completely and relevant canonical authorities, including full test/acceptance, TDD, execution/templates, role/handoff/ownership, repair, documentation/project-rules, design, UI, specification/Blueprint and AI-simulation contracts. SC-01: practical reproduction, affected regression and required real UI/integration evidence remain; standalone handoff is explicitly due so no absent-stage indefinite deferral. SC-02: per-fix targeted evidence survives batching; agreed batch feature scope flushes affected acceptance checks. SC-03: shared/security/data/unknown-impact and required fresh gates still expand checks, with existing reuse/budget constraints intact. SC-04: UI/spec/Blueprint paths stay conditional; real rendered observations, opted-in spec authority and explicit simulation/proxy/context budgets remain in their complete authorities. SC-05: exact named-role preflight/Lead-only approval/independent review, instruction/refactor approval, manual-only archive, TDD tracks and repair history survive concise routing; no invented runtime guard. SC-06: shortened routes explicitly require selected full-reference reads and preserve domain contracts, ownership and return paths. Multiple contextual links do not replace canonical detail or create competing authority. No material semantic mismatch found in inspected scope. These are source decisions, not executed Codex E2E; every mapped native scenario remains manual pending.

Optional quick_validate.py remains unavailable from the earlier reachable current-environment evidence: bundled Python cannot import yaml. No repeated twelve-directory failures or dependency install. Native package validation gives narrower metadata/link evidence; it is not a substitute pass for that optional helper.

### Written rule and entry-size ledger

All rows are edits written to repository Skill files, not merely conversation context. Canonical addition is written in `skills/team-core/references/test-acceptance-contract.md`, section `Tier selection, reuse, and resource limits`, standalone-small-change/batch paragraph. Existing shared authorities retain normative details; entrypoint sections below route to them.

| Skill file | Relevant section/rule written | Before characters | After characters |
| --- | --- | --- | --- |
| skills/team-dev/SKILL.md | Establish the work; Verify and close; full selected-reference routing and small-task rule | 18347 | 14004 |
| skills/team-plan/SKILL.md | Build the plan; conditional authority/full reads and small-task planning | 10415 | 9214 |
| skills/team-review/SKILL.md | Establish coverage; full-authority review and targeted small-task evidence | 8910 | 7780 |
| skills/team-debug/SKILL.md | Investigate; full guard/reference reads and practical small-task reproduction | 5635 | 5925 |
| skills/team-doc-check/SKILL.md | Assess and maintain; governance/authority consolidation and small-change test route | 6829 | 6250 |
| skills/team-project-rules/SKILL.md | Workflow; full project authority and small-change test rule | 5570 | 5325 |
| skills/testing-engineering/SKILL.md | Discover the test surface; complete shared reads and targeted/checkpoint test decisions | 7228 | 7330 |
| skills/code-review/SKILL.md | Establish scope/Evaluate findings; complete contracts and targeted small-fix review | 3861 | 4313 |
| skills/backend-engineering/SKILL.md | Execute and verify; full comments/readability and small-task affected checks | 3548 | 3370 |
| skills/database-engineering/SKILL.md | Execute and verify; full code rules, narrow validation plus data-risk expansion | 3840 | 3553 |
| skills/frontend-engineering/SKILL.md | Establish/Execute and verify; conditional UI/Blueprint reads and real-boundary small-fix evidence | 4826 | 4718 |
| skills/team-ai-simulate/SKILL.md | When to activate/Return paths; complete simulation authority, explicit-only/proxy/host/budget limits and retained Tester definition/scoring boundary | 8877 | 5470 |

Measured by the same ReadAllText().Length method before writer START and after the final focused correction: all sixteen Skill entries 111086 → 100452 characters, reduction10634; team-dev 18347 → 14004, reduction4343. Counts include unchanged entries and prior checkpoint edits, not Git HEAD as a substitute baseline. Some entries grew while total shortened. These are source character measurements, not token or model/runtime cost measurements. Broader reference reading cost and actual runtime remain unmeasured.

Invocation ledger: Lead reused `/root/install_guide_docs` originally selected exact `team-docs-maintainer` (normative writer and focused correction complete/frozen), `/root/install_guide_tests` originally selected exact `team-tester` (packet and post-freeze checks complete), and `/root/install_guide_review` originally selected exact `team-reviewer` (independent read-only review and focused resolution complete). Active exact role definitions available; runtime role/model/effort unknown. No new creation/retry/fallback or Tester child; documented host Close absent, no slot-release claim. All current-task child write/process ownership has ended or been transferred independently of thread closure; Lead owns final factual packet/readiness/protection reconciliation. No Tester network, installation or commit.

### Independent review and final reconciliation

Reviewer found one P2: consolidation removed the unique simulation Tester restriction on definition edits and scoring through actor context, but no equivalent clause existed in the shared authority. The original named writer restored that sentence in `skills/team-ai-simulate/SKILL.md` near Lead/Tester ownership; no other source was changed in that follow-up. Reviewer inspected the correction and reported no remaining material finding across all twelve Skills and the acceptance addition. The domain small-task routes remain conditional; no demonstrated unnecessary full-reference load or production-repair authorization was inferred from them.

Lead reran final package validation and diff hygiene after the correction; both exited 0. Final metrics above include the restored restriction. Comparison against the actual preimplementation source snapshot confirms exactly twelve Skill entries changed, and the only shared-reference delta in this task is the approved small-task paragraph in the acceptance contract. Earlier checkpoint text and the execution-template edits remain intact; models/profiles, helper algorithms, schemas, public language pairs and version are unchanged. Lead factual closure edits follow Tester's frozen ownership transfer. Native E2E/manual behavior and actual cost savings remain pending; this packet is active, not archived. Local scoped readiness uses the existing documentation-governance runtime and is not user manual acceptance.
