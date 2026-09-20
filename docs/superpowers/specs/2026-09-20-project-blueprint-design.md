# Project Blueprint design

## Status

Approved design awaiting implementation-plan review.

## Objective

Prevent a sequence of valid stage tasks from degrading a project’s overall structure. Before a multi-stage initiative begins, establish a durable, Git-tracked Project Blueprint that defines the intended module, directory, file, and ownership boundaries. Every later stage must align its changes to that blueprint or explicitly amend it before implementation.

## Problem

The current Work contract is stage-scoped. It records an affected boundary and file ownership, but it does not define the project topology or distinguish composition roots from feature implementation. File ownership prevents writers from colliding; it does not tell them where a new behavior belongs. An agent can therefore complete a stage correctly while continually extending `main.tsx`, `App.tsx`, or another visible entry file.

## Scope

Apply the Blueprint Gate to:

- a new repository or new application area;
- a user-declared multi-stage initiative;
- an existing project whose relevant structure is unclear, materially changing, or already needs decomposition.

Do not require a new blueprint for a clearly bounded bug fix or small change inside an already documented, stable module. In that case the Work contract cites existing repository structure as its evidence.

## Lifecycle

```text
Project discovery
  -> Project Blueprint Gate
  -> Blueprint approved and tracked in target repository
  -> Stage contract references blueprint modules and file boundaries
  -> implementation and TDD verification
  -> structural change? amend blueprint, then resume implementation
```

The Blueprint is project-level and long-lived. A stage verification packet is stage-level and temporary or archived. Neither replaces the other.

## Project Blueprint contract

Use a target repository’s existing architecture document if it conveys equivalent information. Otherwise create `docs/architecture/project-blueprint.md` with `project-blueprint.ps1`.

The blueprint must define:

1. **Scope and lifecycle:** intended user outcomes, major workflows, explicit out-of-scope areas, and whether this is a new project, initiative, or structural repair.
2. **System and module map:** user-facing surfaces, domain or feature modules, services, data/state boundaries, external contracts, and their dependencies.
3. **Directory and file responsibility map:** existing or planned directories, key files, what each owns, and what it must not own.
4. **Composition roots:** startup, application shell, router roots, providers, and dependency assembly points. They may compose modules but must not receive new feature UI, business state, feature requests, or feature-specific logic unless the blueprint explicitly permits it.
5. **Ownership and interfaces:** owner for shared boundaries, module APIs, public types, generated clients, schema/data boundaries, and compatibility concerns when material.
6. **Structural evolution:** the procedure for adding, moving, splitting, or retiring a module; any migration or compatibility requirements.
7. **Verification:** how an agent confirms that changes respect the map, including test and review expectations.

The template is framework-neutral. It can show framework-specific examples, but must not require React, TypeScript, a fixed `src/` layout, or a particular router.

## Stage structural alignment

Every `$team-dev` stage under a Blueprint Gate records a structural alignment block in its verification packet:

```text
Blueprint location and version:
Relevant blueprint modules:
Allowed existing files:
Planned new files/directories:
Composition roots affected: none / list and justification
Blueprint amendment required: no / yes, link and reason
```

Before writers start, the Lead validates that every assigned file belongs to one declared module. A stage may change a composition root only for startup, dependency assembly, routing, or an explicitly approved exception. A feature implementation may not use a root file merely because it is convenient.

## Structural change gate

When discovery finds that the planned implementation does not fit the Blueprint:

1. Stop before creating an ad hoc file or putting feature code in a composition root.
2. Propose the smallest Blueprint amendment: new module, ownership change, boundary split, move, or explicit temporary exception.
3. Update and validate the Blueprint.
4. Update the stage structural alignment block and resume only with the new boundary.

For a material product, compatibility, or cross-module decision, the Lead presents the amendment to the user. Small internal additions that follow established conventions do not require a separate user decision, but still update the Blueprint.

## Roles and workflow integration

| Workflow or role | Responsibility |
| --- | --- |
| `$team-plan` | Detects whether the Blueprint Gate applies; discovers existing conventions; produces the initial module and file map before ordered stage tasks. |
| `team-architect` | Owns Blueprint boundaries, shared interfaces, and material amendments. |
| `team-explorer` | Maps actual repository structure, entrypoints, nearby conventions, and decomposition risks. |
| `$team-dev` Lead | Requires a validated Blueprint before writers begin when the gate applies; creates structural alignment per stage; returns to Contract for unplanned change. |
| Production owner | Implements only the assigned Blueprint module and reports any misfit before extending a root or foreign module. |
| `team-reviewer` / `$team-review` | Audits that the diff respects module boundaries and that any Blueprint amendment matches the code. |
| `testing-engineering` | Associates test coverage with user behavior and its Blueprint module, rather than only with a currently edited file. |

## Tooling and validation

Add `skills/team-core/scripts/project-blueprint.ps1` with `Initialize` and `Validate` actions.

- `Initialize` creates a Git-tracked, human-readable template only when a target blueprint does not already exist.
- `Validate` is read-only and checks required sections, unique metadata fields, at least one module row, a directory/file responsibility map, composition-root decisions, and a structural-evolution rule.
- It does not infer a project structure, create code directories, move user files, or impose a framework layout.

Add a separate isolated test script for initialization, incomplete-blueprint rejection, valid-blueprint acceptance, unique metadata enforcement, and temporary-directory cleanup. Package validation checks the reference, script, and relevant workflow links.

## Safety and failure behavior

- An existing repository architecture convention wins over the default path, but the Work contract names the chosen source of truth.
- Failure to create or validate a required Blueprint blocks an unqualified multi-stage implementation start; it does not justify guessing a directory layout.
- The automation never reorganizes a target repository by itself. Directory creation or refactoring is normal stage work that needs explicit ownership, TDD coverage where practical, and verification.
- An absent Blueprint on an established small task is not a failure unless the Blueprint Gate applies.

## Verification of the kit change

1. Static package validation rejects a missing Blueprint reference, script, or required workflow linkage.
2. Isolated tests verify template initialization, missing-field rejection, duplicate-metadata rejection, valid acceptance, and cleanup.
3. Existing stage-verification tests demonstrate that structural alignment is required only when a Blueprint is named for the stage.
4. Installer/update tests verify that all Blueprint resources are packaged and installed.
5. A later real multi-stage project confirms a feature request is assigned to a feature module rather than silently accumulated in a composition root.

## Release scope

This is a substantial extension of the workflow harness. The final implementation is a minor-version increment under the release policy.
