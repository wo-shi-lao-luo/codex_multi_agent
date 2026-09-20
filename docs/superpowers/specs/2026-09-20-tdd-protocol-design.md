# TDD protocol design

## Status

Approved design awaiting implementation-plan review.

## Objective

Turn the existing Test & Acceptance Contract into a proportionate, auditable TDD protocol for explicit engineering workflows. The protocol makes behavior-first testing the default for deterministic changes without pretending that all UI, exploratory, or external-system work can follow strict unit-test-first TDD.

## Non-goals

- Do not impose a universal line-coverage percentage.
- Do not require a particular language, test framework, CI provider, or hosted service.
- Do not force automated tests where the only reliable evidence is human verification or a controlled external environment.
- Do not change ordinary non-workflow prompts into mandatory multi-agent work.

## Design choice

Adopt a three-track decision for each material behavior in a `$team-dev` stage packet:

| Track | When it applies | Required evidence |
| --- | --- | --- |
| `test-first` | Behavior is deterministic and a practical automated test can observe it | Named test and Red command/result before production implementation; Green command/result after implementation; relevant post-refactor rerun or `not needed` rationale |
| `test-after` | Automated coverage is useful, but test-first is impractical for a documented, task-specific reason | Reason, smallest reliable substitute evidence, and final automated result |
| `manual-or-environmental` | UI, third-party, exploratory, unsafe, or nondeterministic behavior cannot be reliably automated in the available environment | Reason, E2E/contract/manual plan, environment prerequisites, and human or controlled-environment result |

`test-after` is an exception, not a convenience label. It must identify why a practical Red test cannot reasonably precede implementation. The Lead and `team-reviewer` must treat an unexplained exception as a verification gap.

## Lifecycle

```text
Discover test capabilities and risks
  -> establish use-case map and per-behavior TDD track
  -> prove Red where test-first applies
  -> implement smallest behavior change
  -> prove Green
  -> refactor only with relevant tests rerun
  -> reconcile automated and human evidence
  -> validate packet and retain active / archive on an explicit manual outcome
```

For an automatable bug, `$team-debug` first captures a minimal failing regression test or a documented reason it cannot do so. The repair is not complete merely because the symptom is no longer observed once.

## Stage verification packet

The target project continues to own one Git-tracked packet per stage, normally at `docs/verification/active/<stage-slug>.md`. It is the source of truth for the stage; no duplicate final summary is introduced.

The template gains these fixed sections and controlled fields:

1. **Protocol metadata**: a single authoritative `Final manual status` field, contract status, and packet schema version.
2. **Behavior-to-evidence matrix**: one row per material behavior or risk, including TDD track, test identity, Red evidence, Green evidence, refactor verification, owner, and exception rationale.
3. **Test environment and cleanup**: commands, fixtures, data ownership, teardown, and secrets-safe constraints.
4. **Human verification script**: preparation, numbered happy path, recommended edge cases, expected evidence, cleanup, and the single final manual status.

Controlled final manual statuses are `manual pending`, `manually verified`, `failed`, and `deferred by user`. Only the unique final field controls archival. Historical observations may mention earlier outcomes but must not influence state parsing.

## Validation and error handling

`stage-verification.ps1` gains a `Validate` action in addition to `Initialize` and `Archive`.

Validation checks that the packet has exactly one authoritative final manual-status field, required sections, a recognized track for every matrix row, a reason for every non-`test-first` row, and the applicable Red/Green/refactor fields for every `test-first` row. It reports actionable failures without editing the packet.

Archive first validates the packet, then permits a move only when the authoritative final manual status is `manually verified` or `deferred by user`. It must reject malformed packets, pending or failed manual verification, duplicate destinations, and packets whose only qualifying text is a historical observation.

The protocol distinguishes:

- **planned**: a test or check is not yet implemented;
- **written**: the test exists but is not yet proven passing;
- **failing as intended**: Red evidence exists for a `test-first` behavior;
- **passing**: a command or observed result supports the check;
- **exception accepted**: a documented, explicitly accepted risk remains.

An inability to create or validate the packet blocks an unqualified implementation-complete claim. It does not authorize fabricating test evidence.

## Workflow responsibilities

| Workflow or role | Added responsibility |
| --- | --- |
| `$team-plan` | Produce a preliminary behavior-to-test mapping, identify likely tracks, test entrypoints, and unknown environment constraints. |
| `$team-dev` Lead | Create and validate the packet before writers start; enforce the track decision; reconcile every row at close. |
| `team-tester` | Own matrix quality, test-layer selection, Red/Green evidence, E2E feasibility, and the human script. |
| Production owner | Write the assigned tests and behavior change in the agreed order; report actual commands and outcomes. |
| `$team-debug` | Require reproduction-first regression evidence when practical and route the repair through the same track rules. |
| `$team-review` and `team-reviewer` | Audit behavior-to-test traceability, exceptions, Red/Green evidence, and unaddressed regression risk. |
| `testing-engineering` | Treat test-first classification, evidence quality, and smallest-observable-layer selection as first-class test design work. |

## Toolkit implementation boundaries

The implementation should be limited to these source areas:

- `skills/team-core/references/`: add a focused `tdd-protocol.md`; align the current Test & Acceptance Contract with it.
- `skills/team-core/scripts/stage-verification.ps1`: add template fields, packet validation, robust unique-status parsing, and archive preflight.
- `skills/team-dev`, `skills/team-plan`, `skills/team-debug`, `skills/team-review`, and `skills/testing-engineering`: reference and enforce the protocol at their appropriate lifecycle point.
- `scripts/validate.ps1`: require the protocol and stage script in the distributable package.
- `tests/`: add isolated, cleanup-verified tests for packet initialization, validation, state transitions, archive rejection, and archive success.
- Existing design documentation: correct the prior test-first specification's implementation status and align its manual-status vocabulary.

No target-project test framework scaffolding, CI configuration, or remote service is added by this kit. Each target project's contract selects its own smallest suitable test command.

## Verification strategy

The toolkit change is accepted when:

1. Static validation rejects a missing protocol, missing script, or workflow that omits its required protocol reference.
2. Isolated script tests prove that a template initializes with controlled fields, invalid and incomplete packets fail validation, and archive cannot be triggered by historical status text.
3. Isolated script tests prove a valid, manually verified packet archives exactly once and temporary test files are removed.
4. Installer/update tests prove the new reference and script are installed byte-for-byte with the rest of the kit.
5. A later real `$team-dev` task confirms that the visible workflow creates the packet before production code and records actual evidence rather than retrospective assertions.

## Release scope

This is a substantial extension of the existing testing and acceptance capability, so it is a minor-version change under the repository policy. The implementation plan determines the exact release number after its final scope is fixed.
