# Verification: Documentation content placement and scoped repair

Packet schema version: 2
Stage slug: doc-content-placement
Contract status: implemented; isolated lifecycle regressions passed; real-workflow acceptance pending
Final manual status: manual pending
Final manual evidence:

## Stage context

Objective: keep README a stable project entrypoint, route changing workflow/test evidence to its existing authority, and repair related verified documentation defects encountered during authorized edits without assuming product intent or broader ownership.
Scope: instruction-only shared governance, workflow and Docs Maintainer contract changes. No runtime/schema/policy-version change, business repository edit, installation, release, commit or push. Existing DOC-CONTRACT/ROUTING boundaries remain; no Blueprint/refactor/UI change. Lead owns scoped readiness and integration; Docs Maintainer owns assigned instructions; Tester owns this packet and verification; independent Reviewer assesses the coherent draft.
Environment/test data/cleanup: existing regression suites create unique temporary projects and fake installation homes, remove them at exit, and do not use credentials or external services. Real agent E2E observation requires a separate disposable project and user-authorized scope; source interpretation does not substitute for execution.

## Use-case map
| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| DP-01 | README mixes startup/configuration with recent diagnostics and test counts | Classify each paragraph; route mutable evidence to existing stage/development records | Stable onboarding and concise useful limitations remain; README links to authoritative detail rather than duplicating logs | happy |
| DP-02 | Existing project has adequate architecture/testing/governance documents | Map information purpose before writing | Reuse existing authority and conventions; do not force every optional folder or create duplicate records | happy |
| DP-03 | Authorized edit exposes related stale command, broken link, inaccurate README summary or misplaced factual passage | Verify source and active authority; inspect references; repair within ownership | Fix verified adjacent defects promptly, including stale summaries linked to active evidence; preserve evidence, historical meaning and navigability; report changes | alternate |
| DP-04 | Discovered defect depends on unclear intent or PRD/spec precedence | Describe evidence, impact, options and recommendation | Ask user before disputed rewrites/moves; independent authorized work may continue | edge |
| DP-05 | Related defect lies in another owner's scope or unrelated documents | Notify Lead/owner; distinguish expanded scope | Coordinate bounded reassignment or report; no unilateral cross-owner edit or repository-wide cleanup | edge |
| DP-06 | Read-only diagnosis finds stale/misplaced docs | Report needed correction without editing | Content-repair rule does not override read-only authority | edge |
| DP-07 | Historical evidence or pending manual acceptance differs from current state | Preserve original evidence and status; append/link current correction in active authority | No fabricated test pass, overwritten archived acceptance or promotion of manual pending | edge |

## Coverage-category decisions
| Category | Decision | Reason |
| --- | --- | --- |
| unit | not applicable | No new algorithm; wording assertions cannot establish agent compliance. |
| integration | required | Isolated package/documentation/fake-home installation suites exercise distributed reference integrity and nonmutation. |
| contract/API | required | Native package and packet validators check resource links and compatible schemas. |
| E2E | required | All manual scenarios mapped to real-agent observations; not executed in this instruction-only source task. |
| regression | required | Preserve governance freshness, packet archival authority and installation lifecycle. |
| manual | required | Human acceptance of actual placement/repair behavior remains separate from source review. |
| component/UI | not applicable | No user interface change. |
| accessibility | not applicable | No rendered controls. |
| visual regression | not applicable | No visual artifact. |
| performance/load | not applicable | No runtime performance change. |
| security | conditional | Authority boundaries reviewed in source; real read-only behavior remains pending. |
| compatibility | required | Existing schema2 packets and installed package distribution stay compatible. |
| data migration/rollback | not applicable | No deployment, schema migration or data change. |
| resilience/recovery | conditional | Ambiguity and ownership conflicts must fail safely; runtime observation pending. |
| exploratory/usability | required | README remains usable and repair instructions proportionate. |

## TDD behavior matrix
| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Content routing and scoped repair | Evidence duplication, unsafe intent resolution or unauthorized edit | E2E | manual-or-environmental | DocPlacementE2E.DP-01 through DP-07 | not applicable | planned | not needed; no production refactor | Agent behavior requires real workflow observation; source walkthrough is only substitute evidence, not E2E pass | Lead / user | manual pending |
| Distribution and governance compatibility | Broken references or readiness lifecycle | integration | test-after | tests/test-validate.ps1, tests/test-documentation.ps1, tests/test-install-user.ps1 | not applicable | All three suites exit0; isolated fixture deletion reported | Coherent draft tested; no runtime refactor | Instruction-only change reuses behavioral suites; no retrospective Red or prose-match tests | Tester | passing |
| Stage/manual authority compatibility | Packet regression or false human acceptance | regression | test-after | tests/test-stage-verification.ps1 | not applicable | Suite exit0; isolated fixture deletion reported | Coherent draft tested; no parser/schema refactor | Existing schema and archival behavior unchanged; reuse focused regression | Tester | passing |

## Automated test and E2E plan

Before writing, validate this packet with skills/team-core/scripts/stage-verification.ps1 -Action Validate -ProjectRoot . -StageSlug doc-content-placement. After coherent draft, run scripts/validate.ps1 and isolated tests/test-validate.ps1, tests/test-stage-verification.ps1, tests/test-documentation.ps1 and tests/test-install-user.ps1. Independently interpret DP-01 through DP-07 against final instructions. Structural/lifecycle passing evidence does not prove real-agent adherence. No new wording-only tests or changed runtime policy metadata are planned.

Observed execution: initial packet Validate exited0 before writer release. After writer reported the coherent draft, scripts/validate.ps1 and all four suites above exited0; documentation process session34828 and install session5539 completed successfully. Every suite reported its unique disposable fixture removed. Installation used fake homes only; no real installed configuration or business repository was written. Existing documentation checks cover discovery/source/PRD/legacy preservation, stale changed-document/dependency evidence and policy/Kit distinctions; they do not explicitly seed README and are not proof that an agent will refrain from editing it.

Independent Tester source walkthrough: DP-01 retains stable configuration, safety, basic commands and useful brief status links; DP-02 reuses existing equivalent records and conditional categories; DP-03 evidence-backed bounded corrections cover stale active summaries without inferring intended requirements; DP-04 preserves ambiguity/user-decision authority; DP-05 routes cross-owner findings through Lead rather than widening ownership; DP-06 explicitly prohibits repairs in read-only reviews; DP-07 preserves history and user acceptance evidence while stage packets remain the test-result authority. All seven interpretations are supported by the coherent source diff. This is semantic source inspection, not real-agent E2E execution or user acceptance; every runtime mapping below remains pending.

### Manual-to-automated coverage mapping
| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| DP-01 | DocPlacementE2E.DP-01: inspect final README and authoritative stage links after mixed-content edit | Source interpretation; package checks only distribute rules | planned; runtime pending | No semantic agent runner; no exception accepted |
| DP-02 | DocPlacementE2E.DP-02: inspect reused authority and absence of forced optional folders | Documentation suite checks scoped inventories, not purpose judgment | planned; runtime pending | Actual reuse decision unobserved |
| DP-03 | DocPlacementE2E.DP-03: seed related factual stale link/command and misplaced paragraph; inspect repaired source and preserved references | Source interpretation; package reference validation is supplementary | planned; runtime pending | Source evidence cannot prove timely repair |
| DP-04 | DocPlacementE2E.DP-04: seed conflicting PRD/spec decision; inspect question and preserved originals | Existing governance ambiguity regression; semantic source review | planned; runtime pending | User decision cannot be inferred from validator |
| DP-05 | DocPlacementE2E.DP-05: assign disjoint owners; inspect coordination/report and absence of unilateral edit | Source boundary review | planned; runtime pending | Ownership behavior requires agent execution |
| DP-06 | DocPlacementE2E.DP-06: read-only diagnostic request; compare document bytes before/after | Documentation suite read-only commands; source review | planned; runtime pending | Runtime command nonmutation is not agent-edit nonmutation |
| DP-07 | DocPlacementE2E.DP-07: seed archived and manual-pending results; inspect preservation and current correction links | Existing stage authority and governance history suites | planned; runtime pending | Actual author behavior and human acceptance unobserved |

## Human verification script
### Preparation
1. Use a disposable project, the final source revision and explicit team workflow. Seed README, existing docs/stage records and disjoint ownership; no credentials/global settings. Record revision, instructions and document hashes.
### Happy path
1. DP-01: request an authorized content update in a mixed README.
   Expected result: stable onboarding remains; mutable diagnostics/results route to authority with useful README links.
2. DP-02: provide adequate existing document categories.
   Expected result: reuse conventions without duplicate authority or mandatory optional folders.
### Recommended edge cases
1. DP-03: include verified related stale command/link, inaccurate README summary linked to active evidence and misplaced factual paragraph in assigned scope.
   Expected result: bounded prompt repair with preserved factual evidence and working references.
2. DP-04: include conflicting product intent or unclear precedence.
   Expected result: evidence/options/question; original disputed text unchanged pending user decision.
3. DP-05: place a related defect in another owner's file and an unrelated defect elsewhere.
   Expected result: coordinate/reassign through Lead or report; no broad cleanup or ownership breach.
4. DP-06: issue read-only diagnosis with the same defects.
   Expected result: findings only; document bytes unchanged.
5. DP-07: include archived acceptance and current manual-pending results.
   Expected result: history and statuses retained; current corrections linked without invented passes.
### Result
Observations: manual pending. Remove only this test's verified disposable fixtures after observation; preserve user work and archived evidence.

## Verification record

Release follow-up (0.9.2): after the implementation stage below, the user explicitly authorized versioning, commit, push, real local installation and a PR. Lead synchronized VERSION, the CHANGELOG release heading, README's release reference and documentation.ps1's Kit provenance to 0.9.2; this is a patch extension, not stable promotion or a policy/schema change. Native package validation plus isolated validation, stage, documentation, fake-home installation and deployment/recovery suites all exited0 on the versioned payload. Disposable fixtures were removed. Installation preflight verified the existing 0.9.1 receipt and showed only managed-unit replacements; real deployment/publication follows the verified commit. This release-only follow-up uses no new child agents and does not change DP-01 through DP-07's pending real-workflow/manual acceptance. Code-comment self-check: the sole runtime-source change is the explicit Kit version constant; existing module/contract comments and all test code remain adequate and unchanged.

Lead close reconciliation: the named Docs Maintainer completed the assigned authoring instructions; Tester prepared and validated the plan before writer release and completed the isolated checks; independent Reviewer inspected the final actual diff and DP-01 through DP-07, reporting no material findings. Lead inspected the same source diff and final packet. README, architecture, runtime code/policy metadata and release VERSION remain unchanged; CHANGELOG records this as Unreleased. No Blueprint/refactor/UI change, mandatory document set, business-project edit, actual installation, commit or push was performed.

Assigned document purposes: documentation-governance owns content-placement and correction authority; file-ownership owns boundaries; execution-contract owns lifecycle enforcement guidance; execution-templates owns assignment/verification fields; team-core routes to the shared contract; team-doc-check applies assessment/maintenance boundaries; team-dev applies Lead assignment and close checks; team-docs-maintainer.toml supplies the bounded role instructions. Tester owns this acceptance packet, and Lead owns the scoped governance review/index. No competing authority or historical acceptance was rewritten.

Actual invocation ledger: /root/doc_placement_writer selected with agent_type team-docs-maintainer, assigned instructions and final handoff complete; /root/doc_placement_tester selected with agent_type team-tester, plan/packet/isolated verification complete; /root/doc_placement_reviewer selected with agent_type team-reviewer, independent final review complete. All three exact named roles were available in the active tool catalog before invocation. Returned handles prove creation but do not independently confirm loaded role/model/effort; resolved runtime identities remain unknown. No failed creation attempts, retries, generic-role substitutions or child spawning by these agents occurred. Unrelated prior-task agents are excluded.

Reviewer independently reran native package and packet validation, both passed, and observed STALE on the pre-implementation scoped governance review after source/packet changes. Lead refreshes its actual assessment after this final evidence integration, rather than merely updating hashes to obtain a pass. Documentation policyVersion remains 1 because this correction changes authoring/closure obligations, not readiness categories, schema or runtime validation rules; existing reviews never waive the current authoring contract. Real-agent E2E and user manual acceptance remain pending.

Initial packet structural Validate passed exit0 before writer release. Final coherent draft was inspected through its diff across documentation-governance, file-ownership, execution-contract, execution-templates, team-core, team-doc-check, team-dev and team-docs-maintainer. Seven semantic source scenarios supported; scripts/validate plus four isolated regressions passed. No production/test code edits, prose-match tests, strict test-first claims or fabricated Red. Real workflow and user acceptance remain manual pending; final structural Validate follows this evidence update. No children spawned by Tester; assigned handle /root/doc_placement_tester, tool-selected role team-tester according to Lead assignment; resolved inference model not independently confirmed. Lead supplies final invocation ledger and governs readiness. No business project, installed home or global configuration mutation performed.
