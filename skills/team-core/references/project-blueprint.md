# Project Blueprint contract

## Activation and scope

Before implementing a new application, a multi-stage initiative, or a material structural change, establish a persistent project blueprint. Reuse the repository's architecture document when equivalent; otherwise use `docs/architecture/project-blueprint.md`. A small change in an established module may cite existing structure in its Work contract instead. Assess applicability explicitly; absence of a document is not itself evidence of bad architecture.

Plan module responsibilities and dependencies for the known project scope, then assign stages to those modules. Do not invent speculative abstractions, create empty future directories, or organize production modules by stage number. A stage is a delivery slice, not the whole application.

## Adopt an existing project

The Explorer owns broad repository discovery and supplies evidence with file references; the Lead may do this directly for small tasks. The Architect evaluates module boundaries, dependency direction and structural evolution from that evidence, inspecting specific code only to resolve an architectural question. Missing evidence becomes a focused exploration request through the Lead, not duplicated broad discovery. Developers inspect their assigned modules for implementation constraints and report conflicts with the architectural assumptions.

1. Inspect repository instructions, architecture documents, entrypoints, routes, representative modules, state/data access, dependency direction, tests and build commands. Bound discovery to the relevant application and record inspected paths, baseline results, and unknowns.
2. Distinguish observed structure from proposed structure. Assess concrete symptoms: unrelated responsibilities in one file, dependency cycles, duplicated business rules, difficult test seams, or cross-module access. File length alone is not proof of a defect. Do not claim the whole project is sound from a narrow sample.
3. If the relevant structure is adequate, document it as the baseline and extend its conventions. No reorganization is needed merely to adopt the kit.
4. If problems exist, describe evidence, consequences for the requested feature, and a bounded refactoring proposal: affected files/interfaces, intended behavior preservation, characterization/regression tests, migration order, verification and recovery. Present proceeding within current structure as an alternative when feasible.
5. **Existing-code structural refactoring requires explicit user approval before execution.** Approval to add a feature or a blueprint is not approval to reorganize existing code. Record the user's decision and the approved scope. Pending approval, only independent authorized work may proceed.
6. If the user declines or defers, record `declined` or `deferred`, decision evidence, retained constraints and known risks. Adopt the actual structure as the current baseline and continue the requested feature within it. Do not repeatedly ask the same question, covertly split/move files, or describe an unimplemented target structure as current. Keep proposed improvements separate and optional. If a specific requirement cannot be satisfied under that constraint, explain that concrete conflict and ask about that requirement only.

## Blueprint contents and evolution

Record scope and major journeys; discovered baseline and test entrypoints; module IDs, responsibilities, locations and permitted dependencies; file/directory responsibilities; composition roots and permitted content; interfaces and owners; structural evolution; verification; and refactoring decision/evidence. Mark planned locations as planned. Keep one living document, updated as approved structure evolves, with a revision referenced by each stage.

Composition roots (startup, application shell, router/provider roots) normally perform bootstrapping and composition. Place feature UI, business state and requests in their owning module. Classify by actual responsibility and framework conventions, not filename alone. An existing monolithic root may be retained when refactoring is declined; document the bounded exception and constrain new work accordingly.

When new work crosses an undocumented boundary, return to Contract and update the blueprint and stage mapping before coding. Routine additions inside an agreed module may proceed within task authority. Splitting, moving or reorganizing existing code still requires the explicit refactoring approval above. The read-only architect proposes boundaries; the Lead writes the document and owns the approval record.

## Stage alignment and review

Before writers start, record blueprint path/revision, module IDs, allowed existing files, planned additions, affected roots with reasons, and amendment decision in the stage packet. Delegate these constraints with the task. At handoff, review the actual diff against this mapping and update the blueprint for implemented changes. Bind behavioral tests to the relevant module; passing tests alone do not demonstrate structural alignment.

Use `project-blueprint.ps1 -Action Initialize` or `Validate -ProjectRoot <root>`; `-BlueprintPath` accepts an alternative repository-relative path. Initialization only creates a document. Validation checks document structure and decision consistency, not architecture quality or authenticity of user approval. The Lead and reviewer must inspect the evidence. Existing equivalent documents may be adapted to these fields or reviewed manually with equivalent evidence; do not create a competing architecture source.

For canonical stage packets, supply the same `-BlueprintPath` to `stage-verification.ps1` on Initialize and Validate. Fill `Blueprint revision`, comma-separated `Blueprint modules`, `Allowed existing files`, `Planned additions`, `Composition roots affected`, and `Blueprint amendment`; use `none` with a reason when appropriate. Validation rejects missing fields, unknown modules and stale revisions. The reviewer checks actual path ownership and approval scope. A pending refactor decision permits unrelated work on the baseline, never the refactor itself. Historical packets without a blueprint remain compatible; applicability still must be assessed by the Lead for new work.
