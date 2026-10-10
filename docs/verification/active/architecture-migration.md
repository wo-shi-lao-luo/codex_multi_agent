# Verification: Architecture migration completeness guidance

Packet schema version: 2
Stage slug: architecture-migration
Contract status: active
Final manual status: manual pending
Final manual evidence: Native workflow effectiveness and user acceptance have not been observed.

## Stage context

Objective: Add one shared architecture-migration completeness reference with conditional discovery at planning, implementation, review and testing entrypoints. Apply it to material architectural migrations, including AI boundaries, without imposing it on every small change.
Approved scope: shared guidance, minimal pointers/templates, package discovery guards and isolated regressions. No runtime, packet schema, Agent, release/version, commit/push, user installation, network or live model calls. The motivating example is unverified discussion from another project; use only synthetic examples and never access that product or publish private paths.
Architecture baseline: docs/architecture.md describes the existing in-place source-package layout. Reuse that authority; no source restructuring, new PRD or OpenSpec adoption is assumed. Root AGENTS.md applies.
Ownership: Lead coordinates accepted decisions and readiness; Docs owns normative references/Skills/templates; team-tester owns this canonical packet, tests/test-architecture-migration.ps1 and bounded scripts/validate.ps1 guards; independent team-reviewer assesses the complete source change. No children created by Tester. Returned model identity unknown; source profiles do not prove loaded identity.
Conventions: public PowerShell validator CLI; scenario/expected-result comments for every independent case; byte-restored GUID-owned system-temp fixtures. No formatter configuration found; preserve nearby readable PowerShell conventions and code-readability.md. Forecast unknown; no hard budget inferred.
Data and cleanup: copy public package dependencies into an exact owned OS-temp child, excluding private governance/superpowers history; never mutate the source during fixture tests. Compare relative file/hash fingerprints around validator calls and after restoration. Finally validate absolute temp parent and task prefix before recursive cleanup, and assert fixture absence. No repository working directory needed.

## Use-case map

| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| AM-01 | Finalized complete source copy | Run public package validator and fingerprint comparison | Shared reference and all agreed discovery routes accepted; validation changes no inputs | happy |
| AM-02 | Complete owned fixture | Remove or empty the shared reference | Reject absent/empty resource with an explicit architecture-migration diagnostic | edge |
| AM-03 | Complete owned fixture | Replace each direct migration link with a different valid existing link | Reject every lost intended route even though generic Markdown links resolve | edge |
| AM-04 | Restored fixture and unchanged preexisting package contracts | Rerun package and selected old boundary tests | Byte-exact restoration, existing capability/evaluation routes and packet schema remain supported; cleanup occurs after success or failure | happy / edge |
| AM-05 | Synthetic material backend or AI migration, then a tiny unrelated change | Walk forward from conditional entry to shared guidance | Material migration activates guidance; tiny change is assessed proportionately without mandatory migration machinery | happy / alternate |
| AM-06 | Synthetic old rule replaced by a new contract with consumers | Trace old rule, new authority, consumers and test dispositions | Retained product invariants remain tested; obsolete mechanism proof is explicitly retired/replaced with rationale, and consumers are migrated or reported open | happy / edge |
| AM-07 | Synthetic state/config/persistence/eligibility chain includes a hidden stale consumer | Inspect the full chain, including reload and negative eligibility | Configuration reaches effective decision and durable state; stale consumer or restart gap remains visible rather than passing on a new module alone | edge |
| AM-08 | New interface exists but callers/evidence remain incomplete | Inspect handoff and interrupted migration/recovery expectations | Implementation, consumer migration and verification are distinguished; gaps and applicable rollout/recovery remain explicit without runtime or live-effect claims | edge |

## Coverage-category decisions

| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No production algorithm added; discovery is observed at the public CLI boundary. |
| integration | required | Packaged resource and intended routes must be discoverable together. |
| contract/API | required | Resource/link contract plus manual interpretation of guidance; no live API. |
| E2E | required | AM-05 through AM-08 need future native forward workflow observation; source walkthrough is a limited substitute. |
| regression | required | Existing validation, capability/evaluation routing and schema2 acceptance boundary retained. |
| manual | required | Semantic source walkthrough and future user/native verification. |
| component/UI | not applicable | No UI implementation. |
| accessibility | not applicable | No UI implementation. |
| visual regression | not applicable | No rendered artifact requirement. |
| performance/load | not applicable | No runtime or measured performance claim. |
| security | required | Fixture/source isolation, bounded cleanup and no private project access or external calls. |
| compatibility | required | Existing routing and schema2 packets remain usable. |
| data migration/rollback | conditional | Guidance must assess applicability; this source change performs no data migration. |
| resilience/recovery | required | Missing resources/routes fail honestly; synthetic interrupted migration/recovery remains scoped to applicable risks. |
| exploratory/usability | required | Synthetic forward walkthrough tests discoverability and clarity without certifying native effectiveness. |

## TDD behavior matrix

| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Direct route discovery AM-01/03 | Lost intended migration guidance silently shipped | integration / contract/API | test-first | tests/test-architecture-migration.ps1 route mutations | 2026-10-08 20:38:08 +08:00: complete baseline admitted; old copied validator accepted lost team-core route and test threw Validator accepted lost migration route | Same command begun 20:38:31 +08:00 exited 0 after guards; all thirteen replacements rejected with exact diagnostics | No production refactor; same run restores bytes and rechecks valid baseline/fingerprints | Actual Red is the first lost-route assertion only; other route mutations verified after guards without fabricated individual Reds | Tester | passing |
| Required reference AM-02 | Missing or empty guidance silently shipped | integration / contract/API | test-after | tests/test-architecture-migration.ps1 resource mutations | not applicable | Same Green run exited 0; missing and whitespace reference rejected with dedicated diagnostics | Reference bytes restored; full fixture fingerprint unchanged | Route Red stops before resource cases; resource guard evidence is postimplementation mutation verification | Tester | passing |
| Existing package and restoration AM-04 | New guards break old routes or mutate fixtures/source | regression / compatibility / security | test-after | tests/test-architecture-migration.ps1; tests/test-validate.ps1; tests/test-ai-capability-contracts.ps1; tests/test-ai-evaluation.ps1 | not applicable | All four suites exited 0 against frozen changed package; each isolated fixture removed | Existing tests unchanged; new fixture fully restored and source hashes preserved | Existing suites retained; final changed validation inputs checked after narrow guards; no historical result reused as fresh | Tester | passing |
| Conditional scope AM-05 | Migration checklist imposed on trivial changes or AI-only scope | manual / E2E | manual-or-environmental | Source.AM-05; NativeE2E.AM-05 | not applicable | Synthetic source walkthrough coherent; native unexecuted | no runtime refactor | Source walkthrough cannot establish future native entry routing or interpretation | Tester / user | manual pending |
| Rule/contract/consumer trace AM-06 | New boundary exists while stale consumers or obsolete proof persist | manual / E2E | manual-or-environmental | Source.AM-06; NativeE2E.AM-06 | not applicable | Synthetic source walkthrough coherent; native unexecuted | no runtime refactor | Normative semantic completeness requires forward reasoning; keyword tests cannot prove it | Tester / user | manual pending |
| Complete state and eligibility chain AM-07 | New component pass hides stale configuration or persistence chain | manual / E2E | manual-or-environmental | Source.AM-07; NativeE2E.AM-07 | not applicable | Synthetic source walkthrough coherent; native unexecuted | no runtime refactor | Synthetic examples assess guidance only; no original product or integrated runtime is in scope | Tester / user | manual pending |
| Honest partial migration handoff AM-08 | Implemented incorrectly represented as migrated and verified | manual / E2E | manual-or-environmental | Source.AM-08; NativeE2E.AM-08 | not applicable | Synthetic source walkthrough coherent; native unexecuted | no runtime refactor | Real user acceptance and rollout/recovery require separately authorized target work | Tester / user | manual pending |

## Automated test and E2E plan

Before writer START validate this packet. Wait Lead GO before test/validator implementation. After Docs supplies complete agreed resource/routes, write CLI mutation cases and run them against a copied old validator, retaining actual command/result and order before guard edits. Expected Red is acceptance of a missing/empty resource or lost intended route. Then add only bounded resource/direct-link guards, run Green and restored baseline. Do not test normative phrasing with keywords or pretend generic link validity proves semantic completeness.

Guard plan: require a present, nonempty packaged Markdown skills/team-core/references/architecture-migration.md; require direct Markdown links from team-core, team-dev, team-plan, team-review, code-review, testing-engineering, ai-engineering and backend-engineering Skills, and agreed execution-contract, project-blueprint, test-acceptance-contract, handoff-format and ai-capability-contract references. The fixture baseline decodes finalized source as UTF-8, but the package guard does not enforce encoding. Final route list is frozen with Docs/Lead before tests. Templates use the existing authorities; avoid locking incidental template wording or introducing extra schemas.

Iteration batch: assigned test AST, focused architecture mutation suite, package validator and packet validation. First integrated guidance checkpoint: inspect actual accepted routes and forward-walk AM-05 through AM-08. Handoff batch: existing tests/test-validate.ps1, tests/test-ai-capability-contracts.ps1 and tests/test-ai-evaluation.ps1 once against frozen source; expand only for failures or broadened scope. No installation needed: existing dynamic package rules and retained references establish source layout, not installed/native behavior. If public README/changelog pairs change, Lead arranges mandated bilingual checks and semantic review. Time/interaction forecasts unknown; all planned checks remain planned until execution.

| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other layers / evidence | Status / gap |
| --- | --- | --- | --- |
| AM-05 | NativeE2E.AM-05: material non-AI and AI migration vs tiny local change; observe selected route and proportional work | Source.AM-05 plus AM-01/03 discovery assertions | planned; source reasoning does not prove native behavior |
| AM-06 | NativeE2E.AM-06: old rule/new contract/consumer trace; retained invariants vs retired mechanism tests; stale consumer surfaced | Source.AM-06; no semantic regex substitute | planned; native execution unobserved |
| AM-07 | NativeE2E.AM-07: configuration update, effective state, persistence/reload, eligibility and complete observable outcome; negative/stale path | Source.AM-07 synthetic chain | planned; no original target/runtime accessed |
| AM-08 | NativeE2E.AM-08: partial consumer migration and absent proof; applicable recovery; distinguish implemented/migrated/verified in handoff | Source.AM-08; schema2 packet Validate | planned; user acceptance remains pending |

Deferred owner: user/Lead; AM-05 through AM-08 manual pending. Trigger: separately authorized disposable target project using the changed guidance in an actually loaded native session. Flush before claiming that future workflow accepted. No exception has been accepted; no live AI evaluation artifact is produced by this Kit-only task. Application AI judging, if later authorized, belongs to team-ai-tester with disjoint assertions and this agreed packet authority or the target stage's canonical packet.

## Human verification script

1. Prepare a separately authorized disposable project and synthetic old/new architecture facts; record loaded source identity and cleanup ownership. No original product, secrets, installs or model calls are assumed.
2. AM-05: present a material backend migration, an AI boundary migration, then a tiny unrelated change. Expected: guidance reached for material cases; scope proportional and generic rather than AI-only or universal checklist.
3. AM-06: replace an old mechanism, retain a product invariant and leave one consumer stale. Expected: record old rule/new contract/consumers, preserve invariant coverage, justify obsolete-proof retirement and report stale consumer as unfinished.
4. AM-07: introduce new configuration with persistence/reload and eligibility checks, including disabled/stale/negative paths. Expected: trace all applicable chain links and observable final behavior; component success cannot hide a missing state transition or old eligibility consumer.
5. AM-08: stop after implementing the new interface while consumers or tests remain open. Expected: handoff distinguishes implemented, migrated and verified, names remaining gaps and applicable recovery; no native effectiveness or human acceptance claim.
6. Record observed results and clean only owned disposable fixtures. Keep final manual status pending until direct user evidence or explicit user deferral permits reconciliation and archival.

## Verification record

Preimplementation discovery inspected existing validator, AI evaluation mutation suite, inline stage helper/template, package architecture, shared acceptance/TDD, execution/templates, comment/readability and relevant Blueprint/capability/handoff references. Before source writer START, `./skills/team-core/scripts/stage-verification.ps1 -Action Validate -ProjectRoot . -StageSlug architecture-migration` exited 0 with finalManualStatus manual pending. Backend-engineering is included as the eighth direct-domain Skill route per Lead clarification. Lead subsequently authorized assigned tests/guards; no normative files changed by Tester.

After Lead confirmed complete Docs freeze, actual Red command `./tests/test-architecture-migration.ps1` began 2026-10-08T20:38:08.3372534+08:00 against the old copied validator. Complete source setup and baseline passed, then replacement of team-core's direct migration link by valid code-comments link was accepted; test threw `Validator accepted lost migration route: skills/team-core/SKILL.md`. Finally reported owned fixture removed and source package preserved. No guard edit preceded Red. This is first-route discovery Red only, not individual Red for resource or later route assertions.

Added present/nonempty Markdown resource and thirteen direct-route guards in scripts/validate.ps1. Same test command begun 2026-10-08T20:38:31.7161404+08:00 exited 0: all thirteen valid replacement links rejected with exact diagnostics; missing and whitespace reference rejected with dedicated diagnostics; restored baseline admitted, per-call/full-restoration fingerprints and original package hashes unchanged; exact owned temporary fixture removed. Fresh `./scripts/validate.ps1` and AST parsing of both assigned PowerShell files exited 0. Fresh `./tests/test-ai-capability-contracts.ps1`, `./tests/test-ai-evaluation.ps1` and `./tests/test-validate.ps1` each exited 0 and removed their independent fixtures. Independent batches used separate GUID-owned fixtures against the same frozen package source; all requested checks completed, no process remains owned by Tester. Final packet validation exited 0 with manual pending. No historical result reused as fresh.

Source forward walkthrough AM-05: synthetic service-contract/configuration migration reaches conditional core/planning/development/domain/testing/review pointers; equivalent AI boundary migration uses the same shared guide with retained AI-specific contracts. Tiny unrelated implementation or internal model change with unchanged approved semantics avoids exhaustive migration; material changed evidence reopens it. This is source reasoning, not observed native selection.

Source forward walkthrough AM-06: synthetic old role-name proof for a retained user authorization gate maps to approved target semantics and actual consumer owners. Source instructs retention of the product gate, explicit replaced/bridged/removed disposition for old proof, and return to Contract if required semantics cannot be expressed. A stale consumer or unrepresented rule remains unfinished rather than silently obsolete. No original project's rule was asserted as factual or accessed.

Source forward walkthrough AM-07/08: synthetic configuration selected/displayed mismatch and persisted eligibility consumer require tracing validated/effective config, state/storage, eligibility decision, user operation and final outcome through the actual consumer boundary. Reload/stale/negative conditions belong in applicable state, persistence and recovery checks; direct persistence cannot bypass behavior under review. A new interface with unmigrated consumers yields component completion plus not-implemented transitions; completed transitions with missing evidence are implemented but unverified. Product migration completion requires required transitions actually implemented or approved target exclusion, not a complete map; verified is a separate evidence claim. All NativeE2E cases and user acceptance remain manual pending.

Comment/readability self-check: owned test has file responsibility, helper contracts, scenario/expected-result comments for every independent block including parameterized routes/resource states, assertions for promised nonmutation/restoration and cleanup; validator comment explains structural evidence limit. No configured project formatter found; readable PowerShell grouping and meaningful route/diagnostic literals retained; assigned AST passed. No production implementation outside assigned validator guards changed. No child agents, installation, native/browser run, model/API call or network operation performed. Model identity remains unknown. Lead reported optional Python Skill checker unavailable through WindowsApps alias; no Python pass or dependency installation claimed, and Tester performed no additional runtime discovery.

### Written Skill rule ledger

These eight conditional pointers were actually written to repository Skill files by Docs, not retained only in conversation or memory. The normative rule body lives once in skills/team-core/references/architecture-migration.md; five shared references and the execution template contain short pointers/fields rather than duplicate authorities.

| Exact Skill file | Written section / rule |
| --- | --- |
| skills/team-core/SKILL.md | Supporting conditional paragraph: material migration discovery, existing authority and unchanged internal/model exception. |
| skills/team-dev/SKILL.md | Establish the work: apply migration guide and trace approved targets/consumers while retaining Blueprint and packet ownership. |
| skills/team-plan/SKILL.md | Build the plan: conditional old-rule/target/consumer/owner/test mapping and proportional scope. |
| skills/team-review/SKILL.md | Establish coverage: review traceability, transitions, invalidated evidence and distinct completion claims. |
| skills/code-review/SKILL.md | Establish scope and risk coverage: conditional consumer/target/evidence/claim review; unchanged internal/model exception. |
| skills/testing-engineering/SKILL.md | Build a test contract: real consumer/storage/state/eligibility/operation/outcome checks with separate software/AI/live evidence. |
| skills/ai-engineering/SKILL.md | When to activate: cross-cutting migration supplement with existing AI contracts; internal prompt/model scope remains proportional. |
| skills/backend-engineering/SKILL.md | Introductory conditional pointer: material backend contracts/state/configuration/eligibility/data/jobs/compatibility; existing authorities retained. |

### Invocation reconciliation

Lead reconciled actual exact-role selections and returned handles: /root/migration_docs team-docs-maintainer (source writer completed); /root/migration_tests team-tester (packet, tests and guards completed); /root/migration_review team-reviewer (independent review completed). Active tool catalog exposed all three roles and exact agent_type was supplied. Host-returned identity/model unknown; no historical child reuse, failed creation or substitute role. No child created by these children. No close operation exposed; completed status is not a claim of capacity release. All child write/process ownership ended; the Lead owns only final close reconciliation and readiness refresh.

### Independent review and Lead closure

Reviewer inspected the complete frozen change against f7dfa11 and reported no material findings; read-only diff hygiene passed. It inspected the actual test assertions and final evidence without redundantly rerunning the delegated suites. Its source-guided forward planning check used supplied synthetic facts, not a blind test or original-product inspection: legacy completion proof, forced pending state, optional vs persisted required questions, adoption vs validation, obsolete review revision, displayed vs selected configuration and old jobs all reached scoped consumer/owner/check mapping. Unspecified target semantics and precedence returned to Contract instead of being invented. A generic non-AI callback/state replacement activated the same map; an unchanged internal model swap retained its AI-specific checks without exhaustive migration analysis.

Lead inspected the new authority, all Skill/shared-reference/template deltas, guards and test code. Approved source guidance, distribution guards and relevant isolated regressions are complete; native effectiveness and user acceptance remain unverified. The original product was not accessed or modified. No runtime/schema/Agent, release, Git commit/push, PR or user installation was performed. README/changelog pairs were unchanged. This remains the one active schema2 packet, with final manual status pending; no acceptance exception or archival was inferred. Task-owned test fixtures were removed; only local ignored governance evidence is retained under its existing lifecycle.
