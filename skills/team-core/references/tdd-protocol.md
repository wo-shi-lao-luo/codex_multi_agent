# TDD protocol

Use this protocol with the [Test & Acceptance Contract](test-acceptance-contract.md) for every explicit `$team-dev` stage. It makes behavior-first evidence the default while allowing practical alternatives when strict TDD would be unreliable or wasteful.

## Select one track per material behavior

| Track | Use when | Required record |
| --- | --- | --- |
| `test-first` | A deterministic behavior has a practical automated observation point. | Test identity, failing Red command/result before production implementation, passing Green command/result after implementation, and relevant post-refactor rerun or a concrete `not needed` rationale. |
| `test-after` | Automated coverage is valuable but a test cannot reasonably precede this implementation. | Specific reason, smallest reliable automated evidence, and final result. This is an exception, not a default. |
| `manual-or-environmental` | The behavior is UI-heavy, externally owned, unsafe, exploratory, nondeterministic, or unavailable in the test environment. | Specific reason, controlled environment/contract/E2E/manual plan, prerequisites, cleanup, and result when available. |

Never claim a Red result retrospectively. Record the named test, command, and observed failure before production implementation for every completed `test-first` behavior. After Green, rerun relevant tests following refactoring. Do not use a line-coverage percentage as a substitute for behavior evidence.

## Stage packet requirements

Use the target repository's equivalent QA convention when one exists; otherwise use `scripts/stage-verification.ps1` to create `docs/verification/active/<stage-slug>.md`. Its TDD behavior matrix maps each material behavior to risk, test layer, track, test identity, Red/Green/refactor evidence, exception rationale, owner, status, and manual evidence.

Run `stage-verification.ps1 -Action Validate` after the contract is filled and again before handoff. Validation is read-only. It rejects ambiguous packet structure, missing required fields, unsupported tracks or statuses, non-test-first rows without a concrete reason, and completed test-first rows without evidence.

## Status and exceptions

Matrix status is one of `planned`, `written`, `failing as intended`, `passing`, `manual pending`, `manually verified`, or `exception accepted`.

`exception accepted` needs a stated risk and the user or authorized maintainer who accepted it. A missing test environment is a remaining risk, not passing evidence. Keep test data, fixtures, credentials, external side effects, and cleanup within the target repository's safety rules.

The packet has exactly one `Final manual status` and one `Final manual evidence` field. Its allowed status values are `manual pending`, `manually verified`, `failed`, and `deferred by user`; every non-pending outcome names its observed result or deferral. Only `manually verified` or `deferred by user` permits archival; historical notes never change this state.

## Workflow use

- `$team-plan` identifies likely behavior-to-test mappings, tracks, test entrypoints, and environment unknowns.
- `$team-dev` creates and validates the packet before writers start, then reconciles every row before close.
- `$team-debug` captures a minimal failing regression reproduction where practical before it recommends a repair.
- `$team-review` audits behavior-to-test traceability, unsupported exceptions, Red/Green evidence, and regression gaps.
- `testing-engineering` selects the narrowest observable test layer and evaluates evidence quality.
