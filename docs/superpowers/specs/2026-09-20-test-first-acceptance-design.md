# Test-first acceptance design

## Status

Approved design. Implementation has not started.

## Objective

Make every explicit `$team-dev` development stage begin with a proportionate, written Test & Acceptance Contract and end by reconciling actual evidence against that same contract. The workflow must produce a persistent, Git-tracked human verification document for every stage, whether or not the user immediately performs manual verification.

This is broader than narrow red-green-refactor TDD. It combines behavior-first automated testing, E2E readiness, and a human-operable acceptance script. TDD remains required where deterministic automated tests are practical; it is not faked for exploratory, UI-heavy, or externally dependent work.

## Lifecycle

```text
Context and Discover
  -> Test & Acceptance Contract
  -> Execute (red-green-refactor where appropriate)
  -> automated verification reconciliation
  -> manual verification pending or verified
  -> archive the completed stage packet
```

The Test & Acceptance Contract is a gate before implementation begins. The Lead may scale it down for a small, clear change, but cannot omit it. If the repository has no viable test entrypoint, the contract records that gap and assigns the smallest practical harness or substitute verification before the work closes.

## Stage verification packet

For every development stage, `$team-dev` creates one Markdown packet in the target repository:

```text
docs/verification/active/<stage-slug>.md
```

It is part of the target project's tracked work. The packet is updated in place as work proceeds; it is never replaced by a separate final-delivery summary.

After automated work completes and the user has either completed or explicitly deferred manual verification, the packet moves to:

```text
docs/verification/archive/<date>_<stage-slug>.md
```

The archived packet is the one durable evidence record for that stage. If the repository already has an equivalent verification or QA documentation convention, use that convention instead of creating a parallel hierarchy. The Lead must state the chosen location in the Work contract.

## Packet contents

### 1. Stage context

- objective and scope;
- affected boundary, user role, or system behavior;
- constraints and required environments;
- test-data setup and cleanup requirements;
- explicit out-of-scope behavior.

### 2. Use-case map

For every material behavior, record the preconditions, happy path, alternate path where material, and recommended edge or failure cases. A case is phrased in observable behavior, not implementation internals.

### 3. Coverage matrix

Each row maps a behavior to evidence:

```text
Behavior | Risk | Automated layer | Test/E2E scenario | Manual scenario | Owner | Status | Evidence
```

`Automated layer` is one of unit, integration, E2E, or not practical. `Status` is one of `planned`, `written`, `passing`, `manual pending`, `manually verified`, or `exception accepted`. A line-coverage percentage is optional repository evidence, never a substitute for behavior coverage or an invented target.

### 4. Automated-test and E2E plan

Record the test entrypoints, fixtures, test data, environment prerequisites, commands, and expected evidence. E2E is required only for material user journeys or integration risks that lower-level testing cannot establish. The contract explicitly identifies cases that are unsafe, nondeterministic, externally owned, or otherwise unsuitable for automation.

### 5. Human verification script

The script must be directly executable by a human and include:

- environment, account, data, and cleanup preparation;
- numbered happy-path steps and expected result after every meaningful action;
- recommended edge, error, permission, empty-state, or recovery checks;
- observable failure symptoms and information to capture;
- final outcome field: `manual pending`, `passed`, `failed`, or `deferred by user`.

The agent must never mark a human-only check as passed. A user-reported result may update it.

## Team responsibilities

- The Lead owns creating the contract before writers begin and reconciling it before close.
- `team-explorer` discovers existing test tooling, conventions, data setup, and environment constraints.
- `team-tester` owns the coverage matrix, test design, test implementation where assigned, E2E feasibility, and the human verification script.
- The production-code owner implements the feature and the tests assigned in the Work contract; test ownership stays explicit to avoid parallel edits to shared tests.
- `team-reviewer` checks the final diff against the coverage matrix and reports missing behavior coverage as a material finding.

## Completion gates

Before declaring automated development complete, the Lead must account for every coverage row:

- `passing` requires actual command or observed execution evidence;
- `not practical` requires a reason and a manual or alternative check;
- a skipped required test requires an explicit risk or user-approved exception;
- manual checks remain `manual pending` until the user supplies a result.

The normal workflow handoff summarizes coverage status and links the active or archived packet. The existing local feedback record captures only redacted aggregate signals; it does not copy the packet, source code, or manual-test details.

## Error handling and safety

- Failure to create the packet blocks implementation because the contract gate is unmet.
- Failure to update a packet after implementation is a visible verification gap and blocks an unqualified completion claim.
- Moving the packet to archive happens only after its final status is recorded. If manual verification is pending, it may remain active until the user chooses to defer it; the handoff makes that status explicit.
- The workflow must respect repository instructions, existing documentation conventions, secrets policies, and test-environment safety constraints.

## Verification of this toolkit change

- Static validation confirms every relevant workflow and shared reference exposes the Test & Acceptance Contract.
- Isolated tests verify required packet fields, allowed status transitions, archive behavior, and rejection of unsafe or incomplete packets.
- Installer/update tests confirm all supporting Skill resources are packaged.
- Manual Codex acceptance verifies that an explicit `$team-dev` invocation creates an initial packet before implementation and reconciles it at close.

