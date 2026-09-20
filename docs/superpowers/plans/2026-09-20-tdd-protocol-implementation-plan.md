# TDD protocol implementation plan

## Status

Implementation plan awaiting user approval.

## Scope and acceptance checks

Implement the approved [TDD protocol design](../specs/2026-09-20-tdd-protocol-design.md) without adding a framework-specific runner, CI service, or target-project scaffolding.

Acceptance checks:

1. An explicit `$team-dev` workflow requires a tracked, validated stage packet before writers begin.
2. Each material behavior records one of `test-first`, `test-after`, or `manual-or-environmental`, with the required evidence or rationale.
3. The packet has exactly one authoritative final manual-status field; archival uses only that field.
4. Packet validation rejects incomplete TDD evidence, malformed states, and unsafe archive requests without modifying the packet.
5. `$team-plan`, `$team-debug`, `$team-review`, and `testing-engineering` apply the protocol at their respective lifecycle points.
6. Package validation, isolated runtime tests, installation tests, documentation, and release metadata agree.

## Ordered implementation tasks

### 1. Define the shared, framework-neutral contract

**Owner:** Lead / `team-tester`.

Create `skills/team-core/references/tdd-protocol.md` as the single normative reference for:

- the three TDD tracks and their decision criteria;
- a behavior-to-evidence matrix with stable columns;
- allowable evidence states and their meanings;
- Red, Green, and post-refactor evidence requirements;
- documented exceptions and risk acceptance;
- test-data, environment, cleanup, and secrets-safety rules;
- use by plan, development, debugging, and review workflows.

Revise `test-acceptance-contract.md` to defer TDD-specific rules to this protocol while retaining the broader coverage categories, test layers, and human-acceptance requirement. This prevents two competing sources of truth.

**Verification:** Markdown local links resolve; protocol has no contradictory status vocabulary; static validation requires the new reference.

### 2. Make the packet structured and safely validated

**Owner:** `team-tester`.

Extend `skills/team-core/scripts/stage-verification.ps1`:

- `Initialize` writes a schema-versioned packet with exactly one `Final manual status` field and the required protocol sections.
- Add `Validate`, which reads only and reports all detected structural errors before returning non-zero.
- Parse fixed headings and the unique final field rather than searching arbitrary status phrases across the document.
- Validate matrix rows: recognized track, mandatory exception rationale for non-test-first rows, and Red/Green/refactor evidence fields for test-first rows once their status reaches completion.
- `Archive` calls validation first, then permits only `manually verified` or `deferred by user`, refuses duplicate destinations, and never edits source content before a safe move.

The packet stays Markdown for human usability; the script uses deliberately constrained heading and table conventions instead of introducing a second metadata file.

**Verification:** isolated test cases prove initialization; pending, failed, ambiguous, historical-only, malformed, and incomplete packets are rejected; a valid packet archives exactly once.

### 3. Integrate lifecycle rules into the Skills

**Owner:** Lead / workflow maintainers.

Update these precise Skill sections:

- `skills/team-dev/SKILL.md` — `## Establish the work` requires discovery of test entrypoints and TDD-track selection before writers; `## Verify and close` requires packet validation and row-by-row evidence reconciliation.
- `skills/team-plan/SKILL.md` — `## Build the plan` requires preliminary behavior-to-test mapping, prospective tracks, and stated test-environment unknowns.
- `skills/team-debug/SKILL.md` — `## Investigate` requires a minimal failing regression reproduction where practical; its handoff identifies the applicable track for repair implementation.
- `skills/team-review/SKILL.md` — `## Establish coverage` and `## Output contract` add an auditable TDD review: behavior traceability, unsupported exceptions, Red/Green evidence, and regression gaps.
- `skills/testing-engineering/SKILL.md` — `## Build a test contract` adds track selection, smallest observable test layer, and evidence-quality criteria.
- `skills/team-core/SKILL.md` — document `tdd-protocol.md` and the stage-packet `Validate` lifecycle.

Keep workflow behavior opt-in: ordinary prompts and non-explicit workflows do not receive mandatory packet creation.

**Verification:** package validation checks each required workflow reference and expected phrase; Markdown links resolve.

### 4. Correct and align user-facing documentation

**Owner:** Lead.

Update:

- the earlier test-first design status to show that its initial implementation shipped in `0.3.1`, then link its successor protocol design;
- any old `passed` manual-status wording to the canonical controlled vocabulary;
- `README.md` with a concise statement of TDD evidence support and the explicit-workflow boundary;
- `FOLDER_STRUCTURE.md` only for the new `docs/superpowers/plans/` location.

Do not include a machine-specific directory in any public document.

**Verification:** repository-wide search finds no obsolete implementation-status claim or conflicting final manual-status vocabulary in active protocol documents.

### 5. Add test coverage for the distributable kit

**Owner:** `team-tester`.

Add `tests/test-stage-verification.ps1`, using a uniquely named system temporary target project and a cleanup guard patterned after existing tests.

Test matrix:

| Scenario | Expected evidence |
| --- | --- |
| Initialize | packet has all required headings, metadata, and final status field |
| Baseline draft | Validate rejects incomplete matrix and pending evidence |
| Test-first completion | Validate accepts Red, Green, refactor, and required test metadata |
| Non-test-first | Validate requires a specific rationale and alternative evidence |
| Historical qualifying text | Archive rejects when the authoritative final status is pending or failed |
| Manual pending / failed | Archive rejects without moving the packet |
| Verified / deferred | Archive succeeds once and writes one dated target |
| Duplicate archive target | Archive rejects without overwriting |
| Cleanup | all temporary test roots are removed |

Extend `scripts/validate.ps1` to require `tdd-protocol.md`, `stage-verification.ps1`, and the workflow references. Extend `tests/test-validate.ps1` with a negative case proving missing protocol requirements fail.

**Verification:** run `validate.ps1`, `test-validate.ps1`, `test-stage-verification.ps1`, `test-install-user.ps1`, and the existing feedback-runtime test.

### 6. Package, release, and local installation

**Owner:** Lead.

Choose the release number after implementation scope is complete. The approved design classifies this as a minor-version release because it substantially extends the existing testing capability; update `VERSION`, `CHANGELOG.md`, and `README.md` consistently.

Run all checks before committing. After review of the final diff, use the existing updater to install the exact tested source package into local Codex; report whether restart is needed for Skill discovery. Push only when explicitly requested or already authorized.

**Verification:** package test verifies byte-for-byte installation of the new reference and script; installation receipt reports the final version.

## Dependencies and sequencing

Tasks 1 and 2 establish the contract and parser boundary. Task 3 depends on their stable wording. Tasks 4 and 5 may proceed after Task 2, but Task 5 must be complete before any version change or installation. Task 6 is last.

## Risks and handling

| Risk | Handling |
| --- | --- |
| Markdown parsing becomes ambiguous | Constrain a small set of canonical headings, a unique final field, and table columns; reject ambiguity instead of guessing. |
| TDD becomes bureaucratic for UI/external work | Keep explicit non-test-first tracks with mandatory, concrete rationale and alternative evidence. |
| Agents write retrospective Red claims | Require named test identity and command/result evidence, then have review audit traceability. |
| Existing target repositories have their own QA convention | Retain the existing convention where present; require equivalent controlled fields and validation evidence. |
| Test tooling is unavailable | Record the limitation, choose the smallest credible alternative, and preserve the unresolved risk rather than claiming passing automation. |

## Planned verification commands

```powershell
.\scripts\validate.ps1
.\tests\test-validate.ps1
.\tests\test-stage-verification.ps1
.\tests\test-install-user.ps1
.\tests\test-feedback-runtime.ps1
```
