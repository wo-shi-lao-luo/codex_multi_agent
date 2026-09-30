# Documentation governance

## Activation and authority

Apply before team planning or implementation, and after material documentation/implementation changes. A project without a trusted record gets an initial scoped assessment; an existing marker never proves that any task was reviewed. Ordinary Codex conversations have no background watcher. Small clear tasks may be assessed by the Lead; use `team-docs-maintainer` for substantial inventories and repeated checks.

Default all new development documentation to `docs/`. Product requirements belong in `docs/PRD/`; preserve existing repository conventions and index equivalent existing sources rather than moving them merely to adopt this kit. Only create category directories when the task needs them. Information may live in a PRD, approved user decision, API definition or existing architecture/test document; the existence of a particular template is not a readiness requirement.

Use `docs/governance/documentation.json` for schema/policy versions, the executing Kit version, document inventory and review references; `doc-index.md` for human navigation; `reviews/<scope>.json` and `.md` for one current task/stage assessment. Prior system-owned assessments may be preserved under `reviews/archive/`. The default `docsRoot` is `docs`; an explicitly chosen existing documentation root may be configured. Keep PRDs under `<docsRoot>/PRD` and historical material under `<docsRoot>/legacy`. Store only repository-relative paths. Never publish runtime receipts or local home paths as project evidence.

Separate information authority from observed implementation. An active applicable PRD constrains scope, behavior and acceptance. A draft/reference/historical PRD is not automatically authoritative. Multiple PRDs require applicability and precedence evidence, not a latest-file-wins rule. Explicit new user decisions may amend a PRD: record the decision and affected scope, then reconcile design/tasks/tests. OpenSpec remains the opted-in specification authority; discover and resolve PRD/spec conflicts rather than declaring an automatic override or creating a second task list. Blueprint owns architecture and stage packets own test results.

## Existing-project adoption

1. Read project instructions and existing documentation conventions. Scan configured document roots plus explicit external-to-docs repository documents. Include attachments, inaccessible references and nontext sources in the assessment; hashing a file is not reading it. Exclude credentials, dependencies and generated output. Report omitted/unsupported sources and inventory boundaries.
2. Explorer supplies focused code evidence (entrypoints, relevant modules/interfaces/data, tests and commands); the Lead may do this directly for a small task. The docs maintainer does not duplicate broad code discovery. Architect evaluates architectural gaps and Tester assesses acceptance/test sufficiency through the Lead.
3. Distinguish current observed implementation, confirmed intent and unknowns. Never generate intended requirements by treating every current behavior as correct. Discover only the requested scope; uninspected modules remain uninspected. Source restructuring requires the existing explicit refactor approval.
4. Classify each discovered document by category, lifecycle, authority and applicability. A document can be unrelated to this task while remaining active elsewhere. Establish a scoped review, with source locations, missing information, affected work and proposed next steps. Record confirmed decisions for reuse.
5. Reuse adequate documents; fill factual gaps from verified evidence, not invention. Questions that determine business intent, precedence, archive suitability or material design choices require user decisions before dependent edits.

## Readiness assessment

Assess requirements, architecture, interfaces/data, UI/UX, runtime/development, testing/acceptance and security/migration information as required, conditional or not applicable, with task-specific reasons. These are information dimensions, not mandatory document types. Consider outcomes/non-goals, happy/failure paths and business rules, module placement, external contracts, applicable UI states, reproducible run/test conditions and observable acceptance.

Every finding states source evidence, impact/affected work, the missing/conflicting information, recommended options and a question when user choice is required. Distinguish absent, unread, inaccessible and not applicable. Never claim coverage from summaries of documents that were not actually read. Ready means the requested scope has sufficient reviewed information; partial means explicitly named independent work can proceed; blocked means dependent implementation waits. No document check establishes tested correctness or human acceptance.

**Ambiguity rule:** do not choose a winner, silently rewrite, merge, move or archive disputed material. Ask the user with evidence, options and a recommendation. Preserve the originals and mark the affected work pending. A timeout or no response is not a decision. Independent authorized work may proceed, and routine unambiguous index/link maintenance needs no repeated approval. Record an actual user's decision and scope before marking an ambiguous finding resolved; nonempty evidence cannot authenticate that decision.

## Legacy handling

Use `<docsRoot>/legacy/` for documents confirmed superseded or no longer applicable, never as a catch-all for material unrelated to this task. Historical decisions can remain useful and need not be archived solely by age. Before an authorized unambiguous move, inspect references, establish replacement/retained value, record original path, reason and replacement, preserve bytes and update links/indexes. If uncertain, ask and leave the document in place. Do not delete material or automatically archive based on a filename, hash, scan result or PRD date. The runtime deliberately has no command that decides or performs legacy moves.

Historical files remain inventoried as historical, not current authority. Validate current references into legacy: historical context may be valid, dependency on an obsolete requirement needs reassessment.

## Changes and closure

Before each start, inspect the marker, policy version, task scope/wording and underlying review. New/modified/deleted docs, authority/applicability changes, or changed declared code/API dependencies require impact assessment. New docs are classified before reuse. Whole-inventory fingerprints are conservative: an unrelated addition can mark a review stale; the Lead can re-read the delta, record why it is unrelated and reuse unaffected evidence in a fresh assessment. Never update hashes merely to obtain a pass.

The policy version changes when checking requirements change. Kit/model changes alone do not invalidate an otherwise current review. Metadata schema changes need explicit migration; malformed state is not permission to reset ownership. Track absent expected dependencies as absent so their later creation invalidates evidence. Unknown unlisted code changes cannot be detected: reviewers must select sufficient dependencies, preferably stable interface/schema sources.

At handoff, reconcile implemented behavior with applicable PRDs and confirmed decisions, update affected factual documentation, and reassess invalidated evidence. Writers receive the review path/scope plus PRD, Blueprint and stage-packet references; they do not inherit authority from a bare marker. User manual testing remains in stage packets. Keep one current assessment per scope, retaining history only outside the current review pointers.

## Runtime and authored review

PowerShell 7 is required. Use `../scripts/documentation.ps1`:

```powershell
./documentation.ps1 -Action Scan -ProjectRoot <project>
./documentation.ps1 -Action Initialize -ProjectRoot <project>
./documentation.ps1 -Action RecordReview -ProjectRoot <project> -ReviewInput <repository-relative-json>
./documentation.ps1 -Action Validate -ProjectRoot <project> -Scope <slug> -Task '<current task wording>'
# Partial review can permit only an explicitly listed, unblocked work item.
./documentation.ps1 -Action Validate -ProjectRoot <project> -Scope <slug> -Task '<current task wording>' -WorkItem <id>
./documentation.ps1 -Action Status -ProjectRoot <project>
```

Scan/Status/Validate are read-only. Initialize creates only the governance index/marker; existing docs and source are untouched. RecordReview consumes a Lead-reviewed authored assessment, checks structure and fingerprints, and writes the assessment/index/marker. It does not read semantic intent, certify approval or automatically mark anything ready. Resolve unsupported or ambiguous input rather than changing product documents to pass. Keep authored inputs in the project's established working area, not alongside current deliverables, and do not scan credentials.

Use `-DocsRoot <repository-relative-directory>` for an equivalent existing documentation root, including on subsequent calls. Initialize (or an unadopted Scan) accepts `-AdditionalPaths <repository-relative-paths>` for documents elsewhere in the repository; the marker retains that inventory configuration after adoption. Selector/configuration mismatches and unsupported schemas require inspection, not silent reset. Stop external writers before publishing records: the local lock coordinates this runtime, not editors. An interrupted transaction leaves a pending marker and fails closed; automated hard-interruption recovery is not provided or certified in this release.

Review input schema 1:

```json
{
  "schemaVersion": 1,
  "scope": "login",
  "task": "Add login",
  "outcome": "ready",
  "summary": "Scoped assessment and inspected boundaries.",
  "documents": [
    {"path":"docs/PRD/product.md","category":"requirements","lifecycle":"active","authority":"prd","disposition":"read","reason":"Applicable confirmed PRD; sections reviewed."}
  ],
  "dependencies": ["src/login.ts"],
  "evidence": ["user: confirmed login goal", "src/login.ts: current implementation"],
  "findings": [],
  "runnableWork": ["login"],
  "coverage": [
    {"category":"requirements","decision":"required","reason":"Task changes login behavior.","evidence":["docs/PRD/product.md: login scope"]}
  ],
  "report": "# Login review\n\nActual inspection, limitations, decisions and recommendations."
}
```

The example abbreviates coverage: actual input needs all seven categories `requirements`, `architecture`, `interfaces-data`, `ui-ux`, `runtime`, `testing-acceptance`, `security-migration`. Category is one of those values or `reference`. Lifecycle is `active`, `draft`, `reference`, `historical`; authority is `prd`, `supporting`, `reference`. Disposition is `read`, `unrelated`, `historical`, `unavailable`; each needs a reason. Optional `applicability` is `applicable` or `unrelated`; an unavailable source defaults to applicable. Explicitly unrelated unavailable material may remain unavailable without blocking an independent task, with a concrete reason and report discussion. Applicable unavailable material blocks ready and needs an affected-work finding for partial/blocked reviews. Classify every inventoried document, not just read ones. PRDs used as authority must be active and read; historical files cannot be current authority. Unrelated/unavailable PRDs need explicit applicability/conflict discussion in the report, not presumed exclusion.

A finding has `id`, `kind` (`ambiguous`, `conflict`, `missing`, `unavailable`), `severity` (`blocking`, `nonblocking`), `affectedWork` IDs, `evidence`, `question`, `recommendation`, and `resolution` with `state` (`pending`, `resolved`) and evidence. Pending ambiguous/conflict decisions are blocking for their affected work. Resolved decisions name actual user evidence; factual missing-information fixes name inspected evidence. Ready has no unresolved blocker; partial lists independent runnable IDs disjoint from blockers; blocked has a concrete blocker. Findings remain in the report even after resolution. Only the Lead authorizes the overall start.
