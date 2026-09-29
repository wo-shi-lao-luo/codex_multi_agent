# Verification: optional OpenSpec integration

Packet schema version: 2
Stage slug: openspec-integration
Contract status: active
Final manual status: manual pending
Final manual evidence:

## Stage context

- Objective: Add a pinned external OpenSpec boundary without replacing the kit Lead or default workflow.
- Scope: CLI adapter, local traceability, shared safety helpers, Skill routing, package validation and tests. Architecture boundaries are recorded in docs/architecture.md, Optional specification boundary. Existing stage validation gains a read-only canonical PacketPath option; no source reorganization.
- Environment and cleanup: PowerShell 7 on Windows; OpenSpec 1.13.2 in an isolated temporary npm prefix, with telemetry disabled for child CLI calls. Tests use unique temporary projects and finally cleanup. No global installation, target-project adoption, commit or push is part of this review.
- Authorization: Maintainer approved the thin-adapter design and requested implementation on a new branch. Real user acceptance of this implementation remains pending.

## Use-case map

| Case | Preconditions | Steps | Expected behavior | Happy / alternate / edge |
| --- | --- | --- | --- | --- |
| CASE-001 | No project marker | Doctor, then explicit Enable | Doctor creates nothing; Enable alone adds local integration files | happy |
| CASE-002 | Enabled project and agreed native artifacts | Link scenarios/tasks to a filled stage packet; Validate | Native and kit validation pass; one evidence source | happy |
| CASE-003 | Tasks done but user acceptance pending | Archive | Reject before archive writes | edge |
| CASE-004 | Baseline or delta changed | Validate; explicit Reconcile after reassessment | Reject stale evidence; require renewed close review | alternate |
| CASE-005 | CLI missing, incompatible, malformed or hung | Run adapter operations | Clear failure, no silent fallback or installation | edge |
| CASE-006 | Upstream archive partially fails | Inspect current state and recovery copy | Preserve old specs and current failure state; block retry | edge |
| CASE-007 | Pinned real CLI | Add, modify and retire a capability | Upstream owns merges; no competing Skills installed | happy |

## Coverage-category decisions

| Category | Decision | Reason |
| --- | --- | --- |
| unit | required | Path guards, ID links, stale fingerprints and closing conditions. |
| integration | required | Adapter, stage validator and installed package resources. |
| contract/API | required | Pinned CLI version, JSON output, command failure and schema profile. |
| E2E | required | Actual local CLI lifecycle; not a live model-quality benchmark. |
| regression | required | Existing stage, blueprint, installer, package and feedback suites. |
| manual | required | Maintainer reviews discoverability, workflow fit and supported limits. |
| component/UI | not applicable | No interface component is changed. |
| accessibility | not applicable | No rendered interface is changed. |
| visual regression | not applicable | No rendered interface is changed. |
| performance/load | not applicable | Bounded local document operations; no server load contract. |
| security | required | No shell interpolation, traversal rejection, no automatic downloads or global configuration writes. |
| compatibility | required | Pinned upstream and native schema; default non-adopter regression tests. |
| data migration/rollback | required | Native spec merge and retained recovery copy; no automatic rollback of user data. |
| resilience/recovery | required | Timeout, partial failure and repeat-archive behavior. |
| exploratory/usability | conditional | Maintainer may choose a later live agent/project trial; not claimed here. |

## TDD behavior matrix

| Behavior | Risk | Coverage category | Track | Test identity | Red evidence | Green evidence | Refactor verification | Alternative evidence or exception reason | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CASE-001 through CASE-006 adapter and evidence boundary | Premature close or unintended project writes | integration | test-first | tests/test-openspec.ps1 initial contract cases | Initial run failed because openspec-adapter.ps1 did not exist, before implementation | Initial contract suite and pinned CLI run passed | Expanded suite rerun after safety changes | none | Lead | passing |
| CASE-004 additional reconciliation and task cases | Stale or incomplete evidence hidden | regression | test-after | tests/test-openspec.ps1 expanded cases | not applicable | Expanded suite passed | Rerun after final changes | Added during interface hardening after the initial implementation; explicit mutation tests exercise failure behavior | Lead | passing |
| CASE-007 native lifecycle including modification and removal | False integration claim based only on a double | E2E | test-after | tests/test-openspec.ps1 -OpenSpecEntry trusted pinned CLI | not applicable | See final verification run recorded below | Final pinned-CLI rerun | Externally owned CLI tested after thin transport was available; no model correctness claim | Lead | passing |
| Package and default-workflow compatibility | Break existing users | regression | test-after | test-validate, test-install-user, test-stage-verification, test-project-blueprint, test-feedback-runtime | not applicable | Existing suites passed | Final validation and relevant reruns | Existing regression tests reused; new distribution omission checks added | Lead | passing |
| Maintainer workflow review | Technically valid but inconvenient integration | manual | manual-or-environmental | Steps below | not applicable | pending user review | not applicable | User-only review; no fabricated acceptance | Maintainer | manual pending |

## Automated test and E2E plan

Run scripts/validate.ps1, all existing tests, and tests/test-openspec.ps1. The optional real-CLI run takes the absolute path to an already-installed trusted 1.13.2 bin/openspec.js. It performs all writes in unique temporary projects; the suite never downloads a dependency. CLI-double tests exercise nonzero exit, invalid JSON, wrong version, timeout, custom templates and partial archive failure. Actual-CLI tests cover add/modify/remove, pending manual acceptance, archived packets and custom-config preservation.

Comment self-check: new runtime files and the test file have scope overviews; nontrivial helpers explain contracts and side effects; each scenario block states its observable expected result. Declarative JSON/YAML entries use surrounding schema documentation. This is a self-review, not an independent-agent review.

## Human verification script

### Preparation

1. Review this branch without installing it. Read README's optional-integration section and team-core/references/openspec-integration.md. Leave your current global Codex installation unchanged.
2. To reproduce automated checks, use PowerShell 7 at the repository root. The default tests need Node.js but no installed OpenSpec. Only request the optional real-CLI run if you choose to provide a trusted pinned installation.

### Happy path

1. Run `./tests/test-openspec.ps1`.
   Expected result: contract tests pass; output states whether a real CLI was exercised; no temporary project is retained.
2. Read the team-dev integration paragraph and association example.
   Expected result: one Lead, one task list and one set of test results; no extra agent roles or automatic installation.
3. Optionally run the same suite with `-OpenSpecEntry` pointing to a trusted OpenSpec 1.13.2 entrypoint.
   Expected result: real add/modify/retirement archive assertions pass; your actual project and global Skills remain unchanged.

### Recommended edge cases

1. Review the suite's manual-pending and partial-failure cases.
   Expected result: pending acceptance prevents writes; partial failure preserves a recovery snapshot and blocks replay.
2. Review limitations for custom schema, stores, RENAMED requirements and canonical packet paths.
   Expected result: unsupported profiles stop rather than silently rewrite an existing project. Decide whether this initial scope fits your projects.
3. Review the Reconcile contract.
   Expected result: refreshing a snapshot requires reassessment evidence and clears the previous close-review claim; it does not make user testing pass.

### Result

- Maintainer observations: pending.
- Final automated run (2026-09-29): scripts/validate.ps1; tests/test-validate.ps1; tests/test-install-user.ps1; tests/test-stage-verification.ps1; tests/test-project-blueprint.ps1; tests/test-feedback-runtime.ps1; tests/test-openspec.ps1, both offline-double and actual OpenSpec 1.13.2 modes: all passed. Six edited Skills passed skill-creator's quick validator with UTF-8 decoding. git diff --check passed.
- Cleanup: isolated project fixtures were removed by their suites. The temporary upstream installation, npm/pip caches and isolated PyYAML dependency used for Skill validation were removed. No actual Codex installation was changed.
- No stable release, commit, push or actual user installation is implied by these test results.
