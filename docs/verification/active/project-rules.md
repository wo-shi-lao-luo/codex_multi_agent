# Verification: target-project instruction lifecycle

Packet schema version: 2
Stage slug: project-rules
Contract status: approved implementation scope; test plan prepared before production writes
Final manual status: manual pending
Final manual evidence:

## Stage context

- Objective: help target projects inspect, propose, authorize and maintain their own AGENTS.md without conflating discovery with permission or runtime loading.
- Scope/environment: PowerShell 7 local isolated tests; no installation, network, global configuration or other real project mutation. Each test owns a uniquely named temporary root and removes only that verified target in finally.
- Existing architecture equivalent: docs/architecture.md; amend its existing documentation boundary with project-rule discovery/routing. No source restructuring or new actor required.
- Ownership: Docs Maintainer owns Skill/reference/workflow/public docs/version; Backend Engineer owns read-only project-rules.ps1, documentation.ps1 and distribution validator; Tester owns this packet, test-project-rules.ps1 and scoped test-documentation.ps1/test-validate.ps1 changes; Reviewer independently inspects integration and forward scenarios. Lead owns readiness and actual invocation reconciliation.
- Selection: deterministic public-command tests first, existing affected documentation and package suites after coherent integration, then repository bilingual/stage gates. Cost forecast unknown; no user hard budget supplied. Actual runtime adherence requires a real Codex session and remains pending.

## Use-case map

| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| CASE-PR-01 | Empty target or user-authored root instructions | Run read-only root discovery | Explicit absent/selected result; existing bytes and filesystem unchanged; loading unknown | Happy |
| CASE-PR-02 | Nested working directory; root/nested overrides and configured fallback | Inspect root-to-working-directory chain | First nonempty candidate per level; shadowed alternatives shown; unrelated descendants ignored | Edge |
| CASE-PR-03 | Traversal, excluded directory, reparse point, unsafe fallback or byte limit | Invoke boundary cases | Unsafe paths rejected; exact limit/overflow diagnosed without writes or invented loading | Edge |
| CASE-PR-04 | Adopted scoped documentation review | Introduce/change override instruction | Override inventoried; previous review stale; no automatic semantic reapproval | Regression |
| CASE-PR-05 | Disposable package copy | Remove entrypoint/helper/contract or valid routing link | Distribution validator rejects omission and accepts exact restoration | Integration |
| CASE-PR-06 | Target lacks instructions; user has not approved generation | Ask agent to assess a bounded development task | Suggest confirmed minimum draft; ask before initial write; missing template alone does not block independent work | Happy |
| CASE-PR-07 | Existing user-owned rules conflict/ambiguous; user declines changes | Ask agent to adopt/maintain rules | Preserve bytes and authority; ask affected question; continue only independent authorized work | Edge |
| CASE-PR-08 | User approves scoped factual maintenance; command absent and override present | Ask agent to refresh project instructions | Bounded diff, verify commands rather than invent, report effective candidate/loading caveat; no self-granted privileges | Alternate |
| CASE-PR-F01 | Ordinary authorized development; project lacks root rules | Inspect task-relevant evidence without a user AGENTS request | Proactively propose a useful root file with path, evidence, impact and scope; seek real approval before writing; continue independent work | Happy |
| CASE-PR-F02 | A module has genuinely different commands/boundaries from root | Inspect the scoped instruction chain and module evidence | Propose a nested rule only for the demonstrated local difference, explaining affected scope; no automatic nested creation or redundant global dump | Alternate |
| CASE-PR-F03 | User declined/deferred a prior proposal | Continue same-evidence work, then encounter materially changed module evidence | Do not repeat the unchanged proposal; only materially changed evidence justifies a bounded renewed explanation and approval question | Edge |
| CASE-PR-F04 | Existing rule contains a verified stale factual path, with no approved rule-edit scope | Discover defect during authorized source development | Propose even the factual correction for real approval before rule modification; preserve originals and independent source-work authority | Edge |
| CASE-PR-F05 | Root instructions already sufficient; no distinct local requirement | Assess a small module task | Do not demand new root/nested files or exhaustive project material; no template-only blocker or background watcher | Edge |

## Coverage-category decisions

| Category | Decision | Reason |
| --- | --- | --- |
| unit | required | Candidate precedence, relative paths, metadata and byte-bound diagnostics through public helper. |
| integration | required | Governance inventory/freshness and packaged resources/routing. |
| contract/API | required | Public PowerShell parameters and JSON result semantics; not an application HTTP API. |
| E2E | required | Complete target-project instruction authoring/maintenance sessions in CASE-PR-06 through 08; real Agent behavior pending. |
| regression | required | Existing documentation/package suites preserve readiness and installer distribution boundaries. |
| manual | required | User reviews actual bounded draft, refusal behavior and final effective-rule explanation. |
| component/UI | not applicable | No visible application UI change. |
| accessibility | not applicable | No UI or accessibility behavior changed. |
| visual regression | not applicable | No rendered output changed. |
| performance/load | not applicable | Bounded directory chain, no recursive scan or measured throughput requirement. |
| security | required | Read-only behavior, traversal/excluded/reparse safety, instruction provenance and no privilege expansion. |
| compatibility | required | Schema1 governance preserved, PowerShell7 and default root-only discovery. |
| data migration/rollback | conditional | Existing policy-version review becomes stale by design; no data migration or installation performed. |
| resilience/recovery | required | Rejection leaves disposable target state unchanged and finally cleanup succeeds. |
| exploratory/usability | conditional | User review of concise instructions and adoption explanation in real workflow. |

## TDD behavior matrix

| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Instruction-chain discovery and safety | Wrong effective source or unexpected mutation | contract/API, security | test-first | tests/test-project-rules.ps1 CASE-PR-01 through 03 | 2026-10-04 pwsh -NoProfile -File tests/test-project-rules.ps1 exited 1: missing project-rules.ps1 before production writes; fixture removed. First invocation fails, later case assertions not yet reached. | 2026-10-04 same command exited 0; all scenario blocks passed; fixture removed. | Rerun exited 0 after runtime dangling-link hardening plus dangling-junction regression; no production-code refactor. | None | Tester | passing |
| Override inventory invalidates scoped review | Stale instruction evidence reused | integration, regression | test-after | tests/test-documentation.ps1 CASE-PR-04 | None claimed | 2026-10-04 pwsh -NoProfile -File tests/test-documentation.ps1 exited 0; fixture removed. | No refactor to documentation runtime; isolated regression suite passed. | Extend existing comprehensive governance suite after helper contract integration; prior suite remains baseline. | Tester | passing |
| New package resources and routing enforced | Partial installed capability | integration | test-after | tests/test-validate.ps1 CASE-PR-05 | None claimed | 2026-10-04 pwsh -NoProfile -File tests/test-validate.ps1 exited 0; resource/route removals rejected, restoration accepted, fixture removed. | No production-code refactor; complete existing package suite passed. | Mutation checks require coherent new distributed package and actual validator contract. | Tester | passing |
| Authorization, refusal and bounded correction | Agent overwrites rules or grants itself authority | E2E, manual | manual-or-environmental | CASE-PR-06 through 08 | None claimed | pending real sessions | Not a production-code refactor | Runtime helper cannot establish semantic decisions or live loading; independent forward inspection plus user sessions required. | Lead and user | manual pending |
| Proactive evidence-based proposals and real pre-write approval | Missing useful instructions, redundant rules, unauthorized factual edits or repeated refusal nagging | E2E, manual, security | manual-or-environmental | CASE-PR-F01 through F05 | None claimed | Independent PFWD-01 through 06 semantic walkthrough inspected; real sessions pending, no achieved E2E claim. | No runtime or production-code refactor authorized | Instruction-only Agent decisions cannot be proved by keyword regex or unchanged read-only runtime; bounded semantic walkthrough plus user sessions required. | Tester, Reviewer and user | manual pending |

## Automated test and E2E plan

- Commands: pwsh -NoProfile -File tests/test-project-rules.ps1; tests/test-documentation.ps1; tests/test-validate.ps1. Main runs scripts/validate.ps1, scripts/validate-docs.ps1 -ProjectRoot ., tests/test-bilingual-docs.ps1 and stage-verification.ps1 -Action Validate -ProjectRoot . -StageSlug project-rules after integration.
- Lowest-cost boundary: real public helper and governance scripts over isolated filesystem; exact selected paths/content identities and whole fixture inventory asserted. Summary first; on failure inspect actual contract output; no screenshots or browser needed for script behavior.
- E2E-PR-06: in a disposable blank/mature target without AGENTS, ask a named workflow to inspect and propose. Check no unapproved write, fact provenance, optional project categories and independent work path.
- E2E-PR-07: use disposable user-owned root/nested rules and contradictory requirement. Decline rewrite. Check preservation, affected question and no self-authorized resolution.
- E2E-PR-08: explicitly approve only factual path/link maintenance with a nonexistent test command and root override. Check minimal diff, command unknown/discovered vs executed distinction, precedence and live-loading caveat.
- Forward review is independent semantic evidence, not executed Codex E2E or human acceptance. Keep all E2E/manual gaps visible; no user exception decision exists yet.

### Manual-to-automated coverage mapping

| Manual case / requirement ID | E2E scenario / test ID and checkpoints | Other test layers / test IDs or reasons | Status and evidence | Gap / user exception decision |
| --- | --- | --- | --- | --- |
| CASE-PR-06 | E2E-PR-06 no unapproved generation; confirmed facts; independent task | CASE-PR-01 empty/read-only runtime | manual pending | Real session not run; no exception accepted. |
| CASE-PR-07 | E2E-PR-07 refusal preserves bytes; conflicts go to user | CASE-PR-02 precedence; existing governance ambiguity tests | manual pending | Semantic Agent behavior cannot be proved by keyword checks. |
| CASE-PR-08 | E2E-PR-08 scoped approved diff; nonexistent command; overrides/loading | CASE-PR-02/03 and documentation inventory | manual pending | Full workflow execution and user evaluation required. |
| CASE-PR-F01 | E2E-PR-F01 ordinary development triggers a root proposal; path/evidence/impact/scope stated; approval before write; independent work continues | Existing helper root/read-only coverage reused only with exact input identity; semantic trigger not automated | manual pending | Real Skill session not executed; no automation exception accepted. |
| CASE-PR-F02 | E2E-PR-F02 distinct module need yields bounded nested proposal, root/override scope respected, approval before write | Existing chain precedence coverage reused; appropriateness requires semantic review | manual pending | Need judgment and actual Agent execution remain unproved. |
| CASE-PR-F03 | E2E-PR-F03 refusal suppresses unchanged repeat; material new evidence allows explained new proposal, never unapproved write | No deterministic runtime tracks conversational permission/refusal; semantic evidence only | manual pending | Real repeated-session behavior and user acceptance pending. |
| CASE-PR-F04 | E2E-PR-F04 stale path correction proposed, not written without approved scope; source work remains independent | Existing read-only runtime and scoped governance regression do not prove edit authority | manual pending | Real approval behavior pending; no fabricated runtime Red. |
| CASE-PR-F05 | E2E-PR-F05 adequate root/no local difference means no forced file or project dump; no background action | No helper behavior change; inspect final instructions semantically | manual pending | Real no-op decision pending. |

## Human verification script

### Preparation

1. Use a disposable target directory and fresh Codex session with the candidate kit explicitly loaded; retain initial instructions, source files and command config. Do not use a live business project for destructive exploration.

### Happy path

1. CASE-PR-06: request assessment in a project lacking AGENTS.md, without authorizing a write. Expected: bounded inspection and proposed contents with user question, no file write. Approve a precise initial draft; expected: concise project-specific rules, no fabricated stack/commands.
2. CASE-PR-08: approve only factual link/path correction in existing rules. Expected: minimal verified diff, user-owned policy preserved, detailed assessment under docs/governance rather than README/AGENTS logs.
3. CASE-PR-F01: ask only for ordinary development in a disposable project lacking root instructions. Expected: when useful evidence supports it, proactively explain the proposed root path, inspected evidence, effect and limited contents, then ask for real approval before writing. Declining must preserve independent authorized work.
4. CASE-PR-F02: provide a module with distinct verified commands/constraints. Expected: explain a genuinely local nested-rule proposal and its scope, not duplicate root rules or write immediately. Approve only that proposal and inspect the bounded diff.

### Recommended edge cases

1. CASE-PR-07: decline adoption and supply contradictory project rules. Expected: preserve originals, ask the exact unresolved question; missing template alone does not block independent authorized work.
2. CASE-PR-08: retain AGENTS.override.md and a nonexistent test command. Expected: report shadowing and command uncertainty; no invented successful command or claim current session automatically reloaded instructions.
3. CASE-PR-F03: decline or defer a proposal, then ask for another task with the same rule evidence. Expected: no repeated nag. Introduce a genuinely changed module boundary/requirement; expected: any renewed proposal explains the new evidence and still asks before writes.
4. CASE-PR-F04: give a stale but unapproved factual path in existing AGENTS.md. Expected: propose correction and ask before editing even though the fact is clear; maintain original bytes until real scoped approval.
5. CASE-PR-F05: use sufficient root instructions and an ordinary module with no distinct local rules. Expected: no compulsory new instruction files, full-project information dump or background monitoring.

### Result

- Record observations by CASE ID, restore/delete only disposable target files after preserving user review notes. Automated passes never update the final manual status without user evidence.

## Verification record

- Preimplementation: coverage and ownership prepared, schema2 validator passed with manual pending. Authentic Red exited 1 because helper did not exist; isolated fixture removed. Subsequent cases were not reached in that baseline run. Actual child roster is reconciled by Lead at close.
- Independent Tester: PowerShell 7.6.5; 2026-10-04 public helper suite and documentation suite each exited 0 with explicit isolated-directory removal. No network, real installation, shared mutable fixtures or external services used. Content hashes below identify the relevant executed inputs, not semantic approval.

| Completed batch | Relevant input | SHA256 |
| --- | --- | --- |
| Helper | tests/test-project-rules.ps1 | FFDBA73FE285EA7A04A4B6EF1B6F76A23EC75A0BB25C06AA341FB8D040F2E6A8 |
| Helper | skills/team-core/scripts/project-rules.ps1 | C94EC928B8F54A2F20454A0EBE8476580B5036887B0C32F5FA2489AEB0BFE34F |
| Documentation | tests/test-documentation.ps1 | A03A677A7FCBF256D37931DA32C1AF06A0A0FBFFA5A6576D2F9113DA68B29494 |
| Documentation | skills/team-core/scripts/documentation.ps1 | 53D6E80BF5B200BD10897FC6DD84BFB4DA7B2A381D3E688C35443F3655079EB9 |

- Helper and documentation runtime are self-contained and their test scripts have no other local imports. Unknown/changed relevant input invalidates only the affected batch. No result above establishes live Codex loading or human acceptance.
- Comment self-check: every new helper test scenario, documentation regression and package mutation block has scenario plus asserted expected-result explanation; test helpers have responsibility/contract comments. No generated/vendor exemptions or unexplained mandatory-comment gaps in owned changes.

### Integrated package and deployment evidence

- PowerShell 7.6.5, local Windows, fresh independent temporary fixtures; forecast unknown, no user hard budget supplied. Package, installer and deployment batches ran concurrently only after coherent source freeze, with no shared fixture mutations. Complete runner output was inspected for success/failure and safety-sensitive mutation/rollback assertions, rather than treating a listed resource as installed.
- `pwsh -NoProfile -File tests/test-validate.ps1`: exit 0. Existing regression mutants and new instruction resource/routing mutants passed; disposable copied package removed.
- `pwsh -NoProfile -File tests/test-install-user.ps1`: exit 0. Version 0.10.0 fake-home install/update checked every packaged file and receipt hash, including the new Skill/reference/helper; WhatIf unchanged; conflict preservation and forced-backup recovery passed. Fake homes and their backups removed. Observed package digest: `168b456ec0ef92613aaa1bd9fb3de0cc0c62125f7cae93b90ab78017d95024ec`.
- `pwsh -NoProfile -File tests/test-deployment.ps1`: exit 0. Existing generated-package upgrade/downgrade, new-only file/Skill removal, stable restore, ownership, fault/crash recovery, Git target, prune and cleanup passed. This checks the generic unchanged manager boundary, not a real installed 0.10.0-to-user-stable rollback. Disposable deployment directory absence additionally checked.
- The source-input aggregate was identical before/after these batches: 61 files under `agents/`, `skills/`, `scripts/`, plus `VERSION`, both changelogs and the three invoked test files; SHA256 `08EF66C98E163F7E0D41B3CC44B5DE2C521D386B5B4C8BF4F507A81D3E4FD6D3`. Recipe: sorted repository-relative path plus `=` plus uppercase SHA256 per file, joined by LF, UTF8 encoded then SHA256. This excludes process/packet output to avoid circular self-certification; repository-wide documentation link gates are Lead-owned and separately verified.
- Benign Git ignored-file permission warnings appeared in temporary install/Git-fixture checks; assertions and commands still passed. No personal configuration was read/changed to suppress the warnings, and no real installation/network was performed.

| Completed batch | Relevant input | SHA256 |
| --- | --- | --- |
| Package | tests/test-validate.ps1 | BB171839577A4DA509D78F00BA84D13C4EFEAD08666DF5D41AFC61F88DD7F68D |
| Fake-home installation | tests/test-install-user.ps1 | 41368BC9DCE69E7B7E8290F8C3434ADE8246EC586D44B242634125EE757DCAD0 |
| Deployment | tests/test-deployment.ps1 | 3A7E802AFDDFC5E72770FB9A52FEDD9A2D7602F432CB9B70C05BB3C655B551D1 |
| Deployment | scripts/deploy-user.ps1 | 37216FB6E7DB674ABA0CC61C1C07E77F3DDA0C4DA90F2D193D500A1A2E309F1F |

### Lead-owned gates and actual invocation reconciliation

- Main reported its coherent batch completed with combined shell exit 0 and success markers for `scripts/validate.ps1`, `scripts/validate-docs.ps1 -ProjectRoot .`, `tests/test-bilingual-docs.ps1` and `tests/test-stage-verification.ps1`; both test fixtures removed. Canonical project-rules stage validation reported schema2/manual pending. These are Main-run gates, not independent Tester executions or proof of translation semantics.
- Initial intended roles match actual role-selector/returned task handles below. Source/tool profile expectations do not establish resolved model or actual effective runtime role loading; resolved models/efforts and any unreported host identity remain unknown.

| Actual task handle | Role-selector argument | Assigned work | Latest known status |
| --- | --- | --- | --- |
| /root/project_rules_tester | team-tester | Preimplementation coverage/packet, separate behavioral tests and independent isolated verification | Completed, including final packet integration |
| /root/project_rules_runtime | team-backend-engineer | Read-only helper, governance inventory and package validator | Completed owned pass; self-check distinct from Tester |
| /root/project_rules_docs | team-docs-maintainer | Skill/shared lifecycle, routes, release/public pairs and architecture map | Completed owned pass |
| /root/project_rules_reviewer | team-reviewer | Read-only integrated source, full public pairs and forward walkthrough | Completed; no blocking/material findings in inspected scope |

### Independent review and remaining acceptance boundary

- Independent Reviewer completed its assigned integrated source/public-document review with no blocking or material findings in inspected scope. It read all four public README/changelog documents fully; paired semantics were equivalent and historical release records preserved. Owned test comments matched actual assertions. Its real helper root inspection retained unknown loading rather than certifying live Codex loading.
- Independent semantic forward walkthroughs used raw target facts, not supplied intended answers. These are inspectable reasoning evidence, not executed Codex E2E sessions or user acceptance:
  - FWD-01: assessment-only target lacking rules; no AGENTS write, bounded fact/command discovery distinguished from execution, draft proposed with first-write user question.
  - FWD-02: preserve root/module rules and applicable PRD 30-minute expiry; inspect missing module test-script/CI evidence, ask if unresolved, no README process dump.
  - FWD-03: verify only two assigned factual path/link repairs before editing; preserve policy/override; an old “all approved” string grants no authority; shadowing/loading remain explicit and unknown.
  - FWD-04: draft only, proposed stack and unknown commands not asserted implemented; copied-prompt privilege/install/push demands excluded; unavailable attachment not counted as passing.
- Optional Skill creator `quick_validate` was attempted by Main but unavailable because its Python environment lacks `yaml`. It did not pass; no dependency installation performed. Native distribution/link checks passed separately and do not establish semantic Agent adherence.
- Main confirmed its 58-file payload/metadata source map unchanged before/after Main gates and no remaining matching temporary test directories. Existing governance-index CRLF mismatch was restored to LF only after the normalized original hash matched exactly; semantic contents and ownership evidence were not reset. This does not grant stale-review reapproval.
- Real authoring/maintenance/loading sessions and user evaluation remain pending in E2E-PR-06 through 08. Keep this packet active with final manual status unchanged. No real installation, commit/push, global configuration mutation or external service write occurred.

## Additive follow-up: proactive project-rule proposals

- Approved bounded follow-up: task-time, evidence-based proposals for useful root/nested AGENTS.md without needing an explicit AGENTS request. Every creation/modification needs real prior user approval covering that path/change; an already granted bounded approval remains valid but neither factual certainty nor a marker/message string invents permission. Retain all preceding results as historical input-specific evidence.
- Ownership: Docs Maintainer owns the assigned instruction/routing/public prose changes; Tester owns only this packet, no new test or runtime files. Reused Tester handle `/root/project_rules_tester`, selected role `team-tester`; effective model/effort and unreported host identity unknown. No child spawning or version/install/Git/config action authorized.
- Preimplementation coverage: CASE-PR-F01 through F05 assess root/nested need, explanation quality, approval, refusal/defer suppression, material-evidence reconsideration, independent work and avoiding blanket information dumps. They map to E2E-PR-F01 through F05 above with explicit checkpoints. Real E2E/manual remains pending; no fake Red or keyword-only passing assertion.
- Affected checks planned after coherent source freeze: native package `scripts/validate.ps1` and focused `tests/test-validate.ps1` (changed distributed routing/Skill inputs justify fresh mutation coverage); paired-doc `scripts/validate-docs.ps1 -ProjectRoot .` and `tests/test-bilingual-docs.ps1`; canonical `stage-verification.ps1 -Action Validate -ProjectRoot . -StageSlug project-rules`; independent semantic source/diff/forward review. No automatic full suite for instruction-only prose. Fake-home installation is not executed for this follow-up; prior changed-payload installation results remain historical, not a current-payload pass.
- Runtime evidence reuse plan: compare exact SHA256 of the existing helper/docs runtime and their test files against the completed batch table above, plus unchanged PowerShell 7.6.5 environment/self-contained imports/fixtures. Exact identity permits retaining their original passed evidence as reused for unchanged deterministic behavior only, not passing the new proposal/approval semantics. Fake-home install/current payload evidence is historical and does not prove a modified payload was installed; unchanged generic manager/deployment evidence may be reused only with exact relevant input identity. Any relevant change/unknown identity triggers a scoped rerun, not refreshed hashes masquerading as previous passes.
- Forecast unknown; no user hard budget supplied. Use native summaries plus inspected sensitive decisions; no screenshots/browser or production seam needed. No new temporary fixtures are planned beyond existing isolated doc tests; their own finally cleanup must be confirmed.
- Follow-up execution: after Docs source-freeze GO, independent Tester ran five affected gates on 2026-10-04 using PowerShell 7.6.5. Each command independently exited 0: `pwsh -NoProfile -File scripts/validate.ps1`; `pwsh -NoProfile -File scripts/validate-docs.ps1 -ProjectRoot .`; `pwsh -NoProfile -File tests/test-bilingual-docs.ps1`; `pwsh -NoProfile -File tests/test-validate.ps1`; `pwsh -NoProfile -File skills/team-core/scripts/stage-verification.ps1 -Action Validate -ProjectRoot . -StageSlug project-rules`. The copied package and bilingual regression fixtures both explicitly removed. Semantic review remains separate; neither structural checks nor mutation tests prove the new Agent decision behavior.
- Runtime reuse actually checked: all four helper/documentation script+test hashes exactly match the earlier batch table; PowerShell 7.6.5 and self-contained dependencies unchanged. Those original executed passes are reused only for unchanged deterministic behavior, not executed again or counted as new proposal-policy passes. Generic deployment test/manager hashes also exactly match earlier evidence; no broad deployment rerun. Current changed-payload fake-home installation was not executed.
- Post-gate source/input aggregate: 64 files, comprising every file recursively under `agents/`, `skills/`, `scripts/`, plus exactly `VERSION`, `README.md`, `README.zh-CN.md`, `CHANGELOG.md`, `CHANGELOG.zh-CN.md`, `FOLDER_STRUCTURE.md`, `docs/architecture.md`, `tests/test-validate.ps1` and `tests/test-bilingual-docs.ps1`; same sorted path/hash LF+UTF8 recipe as prior aggregate, SHA256 `E4A6F19B98BDAB987785431478EE4F2959440B91051DFFEE82CFDE91EF862BCB`. This is the actually observed post-gate identity, not fabricated pre-gate telemetry. Lead separately confirmed its own 62-file source map exactly unchanged before/after gates; it already includes both named test files and is a different selection, not this 64-file aggregate. Prior 61-file payload evidence remains historical.
- Original final manual status remains pending and this packet stays active. Follow-up independent semantic review and actual roster reconciliation completed below; no new fixture files or test/production code were authored by Tester.

| Follow-up gate input | SHA256 |
| --- | --- |
| scripts/validate.ps1 | C27AE4E3D9CEA61610DE4532B60659BC60EAC6E09B8A064D41B065919D9687FC |
| scripts/validate-docs.ps1 | AF931899CA9F8F1B77930D061F724273571AA55399BCC9A759A486DA8C0244AA |
| tests/test-bilingual-docs.ps1 | 139765E52944EDBA8113D4ECC43A662E51FDF3DEA6493449E24BA616A120CDBA |
| tests/test-validate.ps1 | BB171839577A4DA509D78F00BA84D13C4EFEAD08666DF5D41AFC61F88DD7F68D |
| skills/team-core/scripts/stage-verification.ps1 | 77A4FBC626E31678B6242BFEE337D6353F67489E1956CD9FC59645652DFC12FB |

### Follow-up actual invocation ledger

The preceding four-agent roster is historical to the original implementation. This follow-up reuses the handles below; Backend was not invoked for this follow-up and is not part of its actual roster. Actual role selector is retained from creation, not inferred from a task title; effective runtime model/effort remains unknown.

| Reused task handle | Originally selected role | Follow-up responsibility | Latest known follow-up state |
| --- | --- | --- | --- |
| /root/project_rules_tester | team-tester | Additive preimplementation coverage/packet, affected gates and evidence reuse | Completed, including independent gates and final packet integration |
| /root/project_rules_docs | team-docs-maintainer | Bounded proactive-proposal/approval/refusal rules and synchronized public prose | Completed assigned frozen source pass |
| /root/project_rules_reviewer | team-reviewer | Independent semantic review and raw forward cases | Completed; no material findings in inspected scope |

All three reused handles are confirmed by Lead's actual reactivation calls. Original Reviewer completion above is not follow-up evidence. No Backend invocation or child spawning occurred for this follow-up; actual loaded model/effort remains unknown for all three.

### Follow-up independent semantic review

- Lead forwarded the independent Reviewer's actual final results. Reviewer inspected the new Skill, canonical contract, four workflow routes, execution/documentation contracts, Docs role profile, DOC-RULES architecture and folder guidance; it completely reread both README and both CHANGELOG documents. Proactive checking, specific write approval, decision deduplication and unknown loading caveats were consistent; bilingual facts/historical items aligned. `git diff --check` succeeded. Reviewer did not edit files, execute scenario commands or repeat suites. No material findings in inspected scope.
- Six independent raw-case outputs below are semantic reasoning walkthroughs, not actual target writes, commands executed, live-loaded Skill E2E or human acceptance. Their checkpoints complement the complete E2E/manual plan without turning pending acceptance into passing status.

| Forward case | Coverage correspondence | Actual observed reasoning/output |
| --- | --- | --- |
| PFWD-01 | CASE-PR-F01 | For order/API/fixture development, proposed concise root navigation to existing README/testing docs, real directories and CI's pnpm check; explained benefit and asked before creation. No first write or executed/all-business-tests claim; missing rules did not block independent development or absorb product requirements. |
| PFWD-02 | CASE-PR-F02 | Ledger's distinct database/generated-client boundary justified a packages/ledger/AGENTS.md proposal inheriting root TypeScript rules and linking package README/test. Asked before creation; no generated-client edits or generate execution merely from script discovery; independent approved query/tests continued under existing guidance. |
| PFWD-03 | CASE-PR-F03 | Continued authorized sorting repair under current order/test conventions; unchanged evidence plus earlier deferral did not trigger renewed docs/testing.md proposal or renewed editing authority. |
| PFWD-04 | CASE-PR-F03 and F04 | Approved migration to packages/orders and absent old src/orders supplied materially changed evidence. Proposed only the changed directory/verified check scope and asked again; excluded previously deferred link, unapproved edits and recreating old directory. Remaining authority ambiguity paused dependent implementation only; discovery/planning stayed independent. |
| PFWD-05 | CASE-PR-F05 | Sufficient root rules and no extra local constraints made src/common/AGENTS.md unnecessary; formatter/unit work continued without a proposal based solely on missing nested file. |
| PFWD-06 | CASE-PR-F04 and existing CASE-PR-08 | Honored approval only for src/login to src/auth link, no other edits. Missing npm test plus observed CI pnpm check was not proof of login regressions; targeted inspection and a separate evidence-backed approval question preceded any test-rule change. Independent login work could continue, unknown verification was not passing. |

- Real proposal timing, refusal deduplication, scoped approval obedience and actual loading require fresh-session test execution. E2E-PR-F01 through F05 and original E2E-PR-06 through 08 remain pending; no user acceptance/automation exception was supplied.

### Tester 64-file aggregate membership

This exact post-gate set contains 8 agent files, 42 Skill files, 5 script files and the 9 explicit public/architecture/test/version inputs. Sort full paths as observed, convert each to the forward-slash repository-relative path shown, append `=` plus its uppercase SHA256, join by LF without trailing LF, encode UTF8 then SHA256. Post-gate and final capture both yielded `E4A6F19B98BDAB987785431478EE4F2959440B91051DFFEE82CFDE91EF862BCB`. This remains distinct from Lead's separately defined 62-file pre/post map. Packet/governance process outputs are excluded, so adding this evidence cannot certify itself.

```text
agents/team-architect.toml
agents/team-backend-engineer.toml
agents/team-database-specialist.toml
agents/team-docs-maintainer.toml
agents/team-explorer.toml
agents/team-frontend-engineer.toml
agents/team-reviewer.toml
agents/team-tester.toml
CHANGELOG.md
CHANGELOG.zh-CN.md
docs/architecture.md
FOLDER_STRUCTURE.md
README.md
README.zh-CN.md
scripts/deploy-user.ps1
scripts/install-user.ps1
scripts/update-user.ps1
scripts/validate-docs.ps1
scripts/validate.ps1
skills/backend-engineering/SKILL.md
skills/code-review/SKILL.md
skills/database-engineering/SKILL.md
skills/frontend-design/SKILL.md
skills/frontend-engineering/SKILL.md
skills/team-core/references/code-comments.md
skills/team-core/references/documentation-governance.md
skills/team-core/references/execution-contract.md
skills/team-core/references/execution-templates.md
skills/team-core/references/feedback-recording.md
skills/team-core/references/file-ownership.md
skills/team-core/references/handoff-format.md
skills/team-core/references/openspec-integration.md
skills/team-core/references/project-blueprint.md
skills/team-core/references/project-rules.md
skills/team-core/references/repair-loop-guard.md
skills/team-core/references/role-routing.md
skills/team-core/references/spec-lifecycle.md
skills/team-core/references/tdd-protocol.md
skills/team-core/references/test-acceptance-contract.md
skills/team-core/references/ui-quality.md
skills/team-core/scripts/documentation.ps1
skills/team-core/scripts/feedback-runtime.ps1
skills/team-core/scripts/openspec-adapter.ps1
skills/team-core/scripts/openspec-common.ps1
skills/team-core/scripts/project-blueprint.ps1
skills/team-core/scripts/project-rules.ps1
skills/team-core/scripts/spec-traceability.ps1
skills/team-core/scripts/stage-verification.ps1
skills/team-core/SKILL.md
skills/team-core/templates/openspec/config.yaml
skills/team-debug/agents/openai.yaml
skills/team-debug/SKILL.md
skills/team-dev/agents/openai.yaml
skills/team-dev/SKILL.md
skills/team-doc-check/SKILL.md
skills/team-plan/agents/openai.yaml
skills/team-plan/SKILL.md
skills/team-project-rules/SKILL.md
skills/team-review/agents/openai.yaml
skills/team-review/SKILL.md
skills/testing-engineering/SKILL.md
tests/test-bilingual-docs.ps1
tests/test-validate.ps1
VERSION
```

## Release preparation: codex/lao-luo

- On 2026-10-04 the user authorized migration of all current changes to a new branch, commit, remote publication, local installation and PR creation. Git rejects the requested double-slash branch spelling; the valid branch is `codex/lao-luo`.
- Lead removed only an extra blank line at the end of `skills/team-project-rules/SKILL.md`; instruction meaning and all preceding policy-review conclusions are unchanged. Current file SHA256 is `89893BE12294F43F9E1E0EA6FD5EE14A0AAFFDDE0338C6E9F970A41205687A48`. Earlier source aggregates/install digests remain historical, not current identity.
- The final formatted 0.10.0 package passed a fresh `tests/test-install-user.ps1` run in isolated fake homes: exit 0, install/update, preview, conflicts and backup assertions passed, fixture removed. Observed package digest: `7fc0f205fa8b77247310dfb033185f8ddd078e116775a1cfc410a29c8a744ae8`. A preliminary successful run before the EOF cleanup tested a different digest and is not used as final-package evidence.
- `scripts/validate-docs.ps1 -ProjectRoot .` and a fresh `tests/test-bilingual-docs.ps1` run each exited 0; the bilingual fixture was removed. Paired public prose did not change since the independent full-document semantic review above.
- The current real 0.9.5 installation verified before update, and the 0.10.0 installation preview found no ownership conflicts. Actual publication/installation outcome is not asserted here in advance; the deployment receipt and PR provide those later facts. No automatic stable selection or global-config change is authorized or intended.
- This release preparation used no child agents. The preceding three-role implementation/review ledger remains historical and unchanged. Real Agent E2E and final manual acceptance remain pending.
