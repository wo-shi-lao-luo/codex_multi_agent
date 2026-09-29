# Optional specification lifecycle

## Activation and authority

Check for `openspec/team-integration.json` before team planning/development/review. Without it, retain the existing kit workflow; the presence of an `openspec/` directory alone is not consent to adopt or rewrite it. Ask before enabling the adapter, installing a dependency or migrating an existing schema. If enabled but invalid/unavailable, stop the affected spec-backed work and explain the error; never silently create a second specification system.

The Lead remains the only execution coordinator. Do not run OpenSpec's apply Skill alongside team-dev, import another agent team, or install competing command Skills. Read [the integration contract](openspec-integration.md) for executable operations and the supported version/profile.

## One authority per artifact

| Information | Authority |
| --- | --- |
| Current agreed behavior | `openspec/specs/` |
| Proposed behavior additions, modifications and removals | The active change's delta specs |
| Global module/file responsibilities | Existing Project Blueprint |
| Change-specific technical decisions | Change `design.md`, referencing rather than copying the blueprint |
| Implementation tasks and progress | Change `tasks.md`; no second task list in the Work contract |
| Test design, observations and human acceptance | Existing stage packets |
| Requirement/scenario/task/packet associations | Change `verification.json`; no copied test results |

Specs describe agreed behavior, not proof that code meets it. Source/tests remain observed implementation evidence. Resolve disagreements explicitly rather than automatically treating either a defect or an outdated document as the intended requirement.

## Plan and develop

1. Discover only relevant code, current specs and active changes. For an existing project with no baseline, distinguish observed behavior, user-approved intent and unknowns; establish only the capability needed for this change. Do not generate a speculative whole-project spec or refactor code as part of adoption.
2. Prepare one change for a coherent outcome. Obtain native instructions for proposal/specs/design/tasks, retain the full user goal and UI brief, and apply the existing blueprint gate. Approval of a specification is not authorization to restructure existing code.
3. Give every requirement and scenario a stable ID in its native heading; retain the entire unchanged scenario set for modified requirements. Review existing regression checks explicitly for modifications/removals. New intended behavior must not be invented from implementation convenience.
4. Keep one task list with unique numeric task IDs. Every task, including infrastructure work, maps to relevant behavior verification. A change can span multiple stage packets; stage boundaries do not define production modules.
5. Before implementation, initialize the association index after the documents are agreed. Fill its links to actual CASE IDs in both the use-case map and TDD behavior matrix. Run adapter Validate; it runs native strict spec validation and kit traceability/stage validation. Do not let a successful document validator substitute for requirement-quality review.
6. Use existing owners, TDD tracks, rendered UI inspection, comment checks and evidence collection. Writers receive the relevant change path, requirement/scenario IDs, blueprint revision, task IDs and packet path. The Lead checks task boxes only after the assigned work and verification are done.

## Changes during execution

Snapshots bind the baseline specs, delta specs, configuration, proposal, design and task wording. Checking a task box does not change this contract. Any other contract change invalidates previous associations conservatively, including another change updating the main specs.

When stale: review the actual difference, seek user decisions for new intent/scope, revise affected links and tests, mark invalidated passing/manual observations pending, rerun affected verification, then explicitly Reconcile with evidence. Reconcile clears close-review evidence; a fresh semantic review is required. Never refresh hashes merely to make validation pass. Approval authenticity and test semantics cannot be established by hashes or nonempty text.

## Verify and close

The Tester checks assertions against requirements, not only that IDs exist. The Reviewer checks intent → design → task → implementation → test consistency, unsupported assumptions, removed behavior and stale evidence. Record a specific review reference or summary in the index; do not self-certify an unperformed review.

Run CloseCheck after all task work. Every linked packet must be valid, all its behavior rows complete, and its final manual status either `manually verified` or `deferred by user`, backed by real user evidence. The existing manual-pending rule is unchanged. Explicit deferral is not a claim that manual testing passed.

Stop concurrent writers before Archive; its confirmation switch attests that the Lead checked closure and has authority to archive, not that the user performed tests. Keep the OpenSpec change active while manual acceptance is pending. Archive stage packets through the existing stage script and update links, then archive the change. The adapter also accepts links to active but accepted packets; it does not move packets itself. Never treat a failed/ambiguous archive as success or automatically retry it.

No document-only checker establishes product correctness, security or visual readiness. Small nonbehavior/documentation-only work may use the native kit workflow with an explicit applicability reason; do not create fake requirements solely to satisfy this adapter.
