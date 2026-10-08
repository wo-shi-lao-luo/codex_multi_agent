# Verification: AI capability contracts and record/replay guidance

Packet schema version: 2
Stage slug: ai-capability-contracts
Contract status: active
Final manual status: manual pending
Final manual evidence: No native target-project use, real AI invocation or human acceptance has been observed.

## Stage context

Objective: Guide target projects to isolate replaceable Agent/Workflow implementations behind task-appropriate capability contracts and reuse real-run evidence safely through recording/replay.
Scope: shared references, lightweight templates and discovery routes only; no universal runtime, new Agent, version change, installation, external API or Git mutation. Baseline HEAD d52283a; existing docs/architecture.md is adequate. No refactor, PRD or OpenSpec initialization required.
Ownership: Docs owns normative resources and Skill routes; Tester owns this packet, tests/test-ai-capability-contracts.ps1 and narrow scripts/validate.ps1 guards; Lead owns readiness, local work protection and final reconciliation after Tester freeze. Existing agent/TOML profiles remain unchanged. Preserve concurrent edits.
Conventions: PowerShell command-boundary tests, isolated fixtures, package validator and existing fake-home installer tests. No formatter configuration applies; follow nearby script conventions and code-readability.md. Each independent test states scenario and expected result.
Environment/data/cleanup: synthetic data only, no credentials, network, paid calls or actual Codex-home/config changes. Tests copy only source package inputs into a GUID-named OS-temp root and clean that exact root in finally after validating its absolute parent/prefix. No existing user material is removed.

## Use-case map

| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| AC-01 | Complete instruction payload | Validate package and routes | Both references/templates and their intended entrypoints are discoverable | happy |
| AC-02 | Disposable package copy | Remove a required resource and validate | Reject missing resource with explicit distribution failure | edge |
| AC-03 | Disposable copy has all resources | Replace required link with a valid unrelated link | Reject lost intended route, not merely broken Markdown | edge |
| AC-04 | Frozen equivalent source copy | Run validator, compare hashes | Accept package without mutating inputs | happy |
| AC-05 | Fake homes only | Run existing isolated installer suite | New payload distributed through existing dynamic map; homes/conflicts remain isolated and fixtures cleaned | happy |
| AC-06 | Target project has an AI capability and two implementations | Plan replacement and internal model change | Business backend depends on capability contract; model changes remain AI-layer duties; incompatible state is not silently reused | happy / edge |
| AC-07 | Synthetic real-run record and safe test environment | Plan recording, review and offline replay including unmatched input/failure | Assertions precede recording; replay validates real consumer path, fails closed without live fallback, isolates effects, preserves provenance and limits conclusions | happy / edge |
| AC-08 | Existing coupled project or explicit-only simulator | Inspect and propose bounded adoption | Reuse adequate seams; obtain approval for refactor; simulation is not live evidence or implied authorization | alternate / edge |

## Coverage-category decisions

| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No production AI runtime or pure business algorithm added. |
| integration | required | Package validation and isolated installer exercise real distribution boundary. |
| contract/API | required | Review capability/recording contract; no live product API exists in this Kit. |
| E2E | required | Native target-project AC-06 through AC-08 planned below; environmental and unexecuted. |
| regression | required | Missing resources and lost discovery routes must be rejected; existing installation boundaries retained. |
| manual | required | Source semantic walkthrough plus separate future user workflow acceptance. |
| component/UI | not applicable | No rendered UI changed. |
| accessibility | not applicable | No controls changed. |
| visual regression | not applicable | No visual output requirement. |
| performance/load | conditional | Comparable telemetry required before any savings claim; unavailable here. |
| security | required | No live fallback, privacy, scoped cleanup, external effects and authorization reviewed. |
| compatibility | required | Project-specific contracts/state migration and old evidence applicability reviewed. |
| data migration/rollback | not applicable | No runtime storage/deployment change; guidance forbids implicit state migration. |
| resilience/recovery | required | Failure records, partial/repeated events, cancellation and replay mismatch guidance reviewed. |
| exploratory/usability | required | Assess lightweight adoption and semantic clarity without forced generic infrastructure. |

## TDD behavior matrix

| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Distribution and fail-closed routing AC-01 through AC-04 | Missing instructions silently shipped | integration / regression | test-first | tests/test-ai-capability-contracts.ps1 | Old validator accepted lost team-core capability link after complete fixture passed; command exit1 | Same command exit0 after narrow guards: eight lost routes and four missing resources rejected | No production refactor; restored source accepted and fingerprint unchanged | deterministic command-boundary observation | Tester | passing |
| Isolated install AC-05 | Added payload missing from installed package | integration | test-after | tests/test-install-user.ps1 | not applicable | Escalated fake-home suite exit0; all current payload hashes and receipt entries matched | existing test unchanged | Existing dynamic package-map suite verifies finalized payload; no installer algorithm changes | Tester | passing |
| Replaceable AI boundary AC-06 | Model details leak into backend; incompatible implementation/state silently accepted | compatibility / E2E | manual-or-environmental | Semantic.AC-06; NativeE2E.AC-06 | not applicable | Frozen source walkthrough coherent; native E2E unexecuted | no runtime refactor | Instruction adherence requires actual native project observation; source inspection is only substitute | Tester / user | manual pending |
| Evidence reuse and safety AC-07 | Wrong baseline, unsafe replay, false acceptance or unmeasured savings | security / E2E | manual-or-environmental | Semantic.AC-07; NativeE2E.AC-07 | not applicable | Frozen source walkthrough coherent; native E2E unexecuted | no runtime refactor | No live API or product runtime authorized; inspect explicit decisions then retain future environment gate | Tester / user | manual pending |
| Existing-project adoption and simulation boundary AC-08 | Unapproved refactor or simulated evidence mislabeled live | regression / E2E | manual-or-environmental | Semantic.AC-08; NativeE2E.AC-08 | not applicable | Frozen source walkthrough coherent; native E2E unexecuted | no runtime refactor | Native implementation adherence remains unobserved; synthetic source review cannot prove it | Tester / user | manual pending |

## Automated test and E2E plan

Before normative writer START: validate this plan using stage-verification.ps1 Validate. Wait for Lead GO before test edits/execution. After GO, observe practical Red of new guard regression before adding guards; freeze tests/guards, then run Green after normative writer freezes payload. Relevant fast batch: new test, scripts/validate.ps1, scoped git diff --check and packet validation. One due handoff integration batch: existing tests/test-install-user.ps1 in fake homes. Expansion only if fixture/runner/schema/install behavior changes or failures show wider impact. Time/compute/token forecast unknown; no hard budget inferred.

| Manual case / requirement ID | E2E scenario and checkpoints | Other layers / source evidence | Status / gap |
| --- | --- | --- | --- |
| AC-06 | NativeE2E.AC-06: project intake, capability contract, second compatible implementation, internal model change and incompatible active-state decision | Semantic.AC-06; structural entrypoint checks | planned; native environment unavailable |
| AC-07 | NativeE2E.AC-07: predetermined assertions, actual connected run, sanitized record, reviewed fixture, consumer replay, mismatch/failure/effect checkpoints, separate conclusions | Semantic.AC-07; no artificial runtime mock engine | planned; real run/cost/human evidence unavailable |
| AC-08 | NativeE2E.AC-08: existing-code inspection, retained good seam, proposed coupled-code refactor approval, explicit simulation/live distinction | Semantic.AC-08 | planned; user decisions must not be simulated |

Deferred native checks: user/Lead owns AC-06 through AC-08; status manual pending; trigger is separately authorized disposable target-project use with source instructions actually loaded; flush condition is observed checkpoints before that future project's acceptance. This instruction-source handoff makes no runtime adherence claim. Unavailable measured savings remains unknown.

## Human verification script

1. Preparation: separately authorize native target-project use, identify loaded source revision, use synthetic data and disposable resources, and declare any external-call budget. This task does not install or call an API.
2. AC-06 happy path: ask for an AI feature with two interchangeable implementations. Expected: backend-facing project contract stays independent of frameworks/models; optional capabilities and failures explicit. Edge: propose replacing a running stateful workflow. Expected: compatibility/migration decision surfaced, no silent state reuse.
3. AC-07 happy path: define expected behavior before one authorized connected run; inspect record and resulting backend state. Expected: multiple assertions can reuse the same run without treating one success as universal coverage. Review/desensitize sample, then replay it through actual consumer processing. Expected: no real AI call or external effect. Edge: unmatched request, bad output, duplicate/partial events. Expected: fail closed or explicit defensive behavior, never live fallback or auto-updated success baseline. Inspect provenance and changed-implementation conclusion limits.
4. AC-08 happy path: use existing adequate boundary. Expected: reuse it without new framework. Edge: expose coupling or mention simulator without explicit invocation. Expected: bounded refactor proposal waits for approval; no implicit simulation or simulated/live evidence substitution.
5. Record actual results here; clean only owned disposable resources. Keep final manual status pending unless observed user evidence or explicit deferral exists; do not archive pending packet.

## Verification record

Preimplementation packet validated exit0 before normative writer START. After Lead GO and first normative freeze, `pwsh -NoProfile -File tests/test-ai-capability-contracts.ps1` produced actual Red: complete fixture was accepted, but old validator accepted the lost `skills/team-core/SKILL.md` capability route even though its replacement remained a valid Markdown link. The test exited1 for that gap. Earlier fixture setup failures from missing public-doc/config dependencies were corrected and are not Red evidence. Narrow guards were added afterward. Green same command exited0, rejected all eight lost routes and four missing references/templates with precise diagnostics, accepted restored source, confirmed fingerprints unchanged and removed the owned fixture. Fresh `pwsh -NoProfile -File scripts/validate.ps1`, assigned PowerShell AST parsing and scoped diff hygiene passed. No broad suite or earlier result relabeled a fresh pass.

Existing `tests/test-install-user.ps1` sandbox execution was blocked by an existing .NET file Move permission limitation and its finally cleanup succeeded. This is an environment failure, not TDD Red or an AI payload defect. The authorized escalation rerun used only temporary fake homes and exited0: every current payload file's installed hash and receipt entry matched the dynamic source map, WhatIf did not mutate files, managed update passed, conflicting customization was preserved without Force, and Force preserved a backup before replacement in the fake home. Its owned temporary directory was removed. Package digest was `cb4abdc076c41aafb02b944151bca4b060bf6904bf29c9f91008efb57a5d39af`; this is isolated distribution evidence, not actual installation or loading. No global-config authority inferred.

Semantic walkthrough AC-06: backend capability ownership, AI-internal model changes, semantically compatible adapter, required/optional capabilities, business authorization and in-flight state binding are explicit. AC-07: predeclared assertions, independent assessment, failed-record retention, selected seam, real consumer processing, mismatch fail-closed behavior, isolated effects, privacy, provenance, new backend results and changed-AI evidence limits are explicit. Normalized replay does not independently validate raw provider parsing; focused raw-response fixtures cover that boundary when material. A shared live trace supports only assertions that actually observe their own requirements; no hidden internal-path proof inferred. AC-08: reuse adequate existing seams; refactor approval and separate explicit prototype simulation retained. These are inspected source decisions, not executed native E2E or human acceptance. No runtime/cost claim.

Comment/readability self-check: new test file has purpose/boundary overview, helper responsibilities, scenario/expected explanations for each independent block and identifiable parameterized rows. Assertions match those explanations; mutation bytes restored and exact temporary cleanup guarded. Narrow validator block documents structural limits. No repository formatter configuration applies; assigned PowerShell parses and manual layout review passed, meaningful route strings preserved. Optional Skill validator prerequisite check by Lead failed with missing Python yaml; no dependency installed, optional validation remains unavailable rather than passing.

Skill change ledger (all actually written to source files by Docs, not conversation-only): `skills/ai-engineering/SKILL.md` / `## When to activate` adds conditional capability and record/replay routes; `skills/backend-engineering/SKILL.md` / introductory guidance before `## When to activate` adds conditional capability boundary; `skills/testing-engineering/SKILL.md` / introductory guidance before `## When to activate` adds conditional record/replay route and evidence limit; `skills/team-core/SKILL.md` / `# Team core` adds conditional AI routing paragraph. Detailed authority lives only in the two new references with the two lightweight templates, not copied rules across entrypoints. Test & Acceptance efficient-execution and AI-simulation evidence-separation pointers route to those authorities.

Invocation ledger: Lead reports exact selector `team-docs-maintainer` for `/root/ai_contract_docs` (complete, normative files frozen), `team-tester` for `/root/ai_contract_tests` (verification complete, assigned files frozen), and `team-reviewer` for `/root/ai_contract_review` (complete, independent read-only review). Returned task handles recorded; host-resolved role/model/effort unknown, not inferred from source profiles. No failed spawn or Tester child. No documented host Close operation available; no slot-release claim. Write ownership ends independently at freeze; Lead owns final roster and readiness reconciliation.

Independent review: Reviewer inspected the finalized instruction resources, conditional routes, narrow validator guards, test scenarios and packet evidence. No material P1/P2 findings remained; independent diff hygiene passed. Reviewer did not repeat Tester runs, modify source, invoke an external API or install the Kit. Lead reconciled this record after both owners froze their files. Native target-project behavior, human acceptance and measured savings remain unverified; final manual status stays manual pending.
