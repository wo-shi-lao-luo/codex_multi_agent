# Documentation governance

## Activation and authority

Apply before team planning or implementation, and after material documentation/implementation changes. A project without a trusted record gets an initial scoped assessment; an existing marker never proves that any task was reviewed. Ordinary Codex conversations have no background watcher. Small clear tasks may be assessed by the Lead; use `team-docs-maintainer` for substantial inventories and repeated checks.

Default all new development documentation to `docs/`. Product requirements belong in `docs/PRD/`; preserve existing repository conventions and index equivalent existing sources rather than moving them merely to adopt this kit. Only create category directories when the task needs them. Information may live in a PRD, approved user decision, API definition or existing architecture/test document; the existence of a particular template is not a readiness requirement.

## Document responsibility and placement

Assign each edited document a purpose and source-of-truth responsibility, not just a path. In repositories that use a root `README.md` as the project entrypoint, keep it focused on stable purpose, onboarding, setup/configuration, basic commands, user-relevant limitations and navigation. It may carry a brief current-status summary with a link to its authoritative record, but it is not a per-run results log, test-count ledger, diagnostic-progress journal or workflow diary. Preserve an established repository convention when its README serves another explicit purpose.

Put stage/task acceptance results and evidence in the existing stage packet; development chronology, decisions and investigation notes in the existing development record; detailed reproducible test procedures in the existing test guide; and documentation inventory/readiness assessments in `docs/governance/`. Reuse the repository's equivalent existing records and conventions. Do not create a fixed set of document categories or move technical content wholesale just because it appears in a README. Avoid competing copies: keep a concise useful summary and link where needed, while the designated record remains authoritative.

Use `<docsRoot>/governance/documentation.json` for schema/policy versions, the executing Kit version, document inventory and review references; `<docsRoot>/governance/doc-index.md` for human navigation; and `<docsRoot>/governance/reviews/<scope>.json` and `.md` for one current task/stage assessment. Prior system-owned assessments may be preserved under `<docsRoot>/governance/reviews/archive/`. This metadata, index and complete reviews subtree form a local runtime bundle: the Kit keeps them on disk but defaults them out of Git. This does not ignore all of `governance/`; user-authored governance documents remain project evidence. The default `docsRoot` is `docs`; an explicitly chosen existing documentation root may be configured. Keep PRDs under `<docsRoot>/PRD` and historical material under `<docsRoot>/legacy`. Store only repository-relative paths. Never publish runtime receipts or local home paths as project evidence.

Separate information authority from observed implementation. An active applicable PRD constrains scope, behavior and acceptance. A draft/reference/historical PRD is not automatically authoritative. Multiple PRDs require applicability and precedence evidence, not a latest-file-wins rule. Explicit new user decisions may amend a PRD: record the decision and affected scope, then reconcile design/tasks/tests. OpenSpec remains the opted-in specification authority; discover and resolve PRD/spec conflicts rather than declaring an automatic override or creating a second task list. Blueprint owns architecture and stage packets own test results.

Target-project `AGENTS.md`, `AGENTS.override.md`, and configured equivalent instruction files describe durable agent working guidance. `$team-plan` and `$team-dev` assess applicable coverage at task start, on first entry to a relevant module, and when relevant rule/command/convention evidence changes. When that evidence shows a material gap affecting the task, the Lead proposes a bounded correction to the user even without an explicit instruction-file request; absence, length, or age alone is not a gap. The [project-rules contract](project-rules.md) defines discovery, approval, deduplication and upkeep; generic document-maintenance permission does not include permission to write target instruction files. No background monitor or automatic editing is provided.

## Cross-document consistency

Compare claims by topic, scope, audience, conditions and version. Multiple links to one destination do not establish duplicated content. Classify apparent repetition before changing it:

- **Redundant detailed definitions:** where equivalent normative detail has a clear existing authority, retain that detail there and replace only the redundant passage in an assigned secondary document with a useful summary and specific reference. Preserve audience context, examples and exceptions that add meaning.
- **Complementary guidance:** keep distinct conditions, roles, audiences and exceptions; clarify each passage's scope and cross-reference related detail instead of collapsing it.
- **Conflicting claims:** when statements disagree under the same topic and conditions, report both locations and exact claims with scope, evidence, impact and the competing authority sources. Use the existing `conflict` or `ambiguous` finding as appropriate, preserve the disputed originals, and follow the ambiguity rule below. A newer, longer or repeated statement is not automatically authoritative.
- **Legitimate repetition:** retain navigation links, concise entrypoint summaries, bilingual counterparts, historical records and task evidence where they serve their readers or preserve history. Their presence alone is not a defect.

Determine authority for the specific claim and scope from existing versioned sources or confirmed user decisions; do not assign one document blanket authority over unrelated topics. Applicable PRDs govern intended product behavior, Blueprint governs architecture, API contracts govern interface expectations, and stage packets govern their acceptance evidence. Code and configuration show observed behavior, not necessarily approved intent. Ignored local indexes and governance metadata may help navigate or track evidence but cannot establish authority or become its sole record. Similarity, hashes and repeated phrasing can identify candidates for review; they cannot establish semantic equivalence, conflict or permission to remove content. Do not add a parallel authority registry or a new finding kind for ordinary deduplication.

The Docs Maintainer reports competing claims, conditions, source evidence, impact, options and any needed decision to the Lead. The Lead obtains focused code/configuration facts from Explorer, architecture judgments from Architect and acceptance interpretation from Tester as needed; the Docs Maintainer does not spawn or message those roles directly. The Lead may apply already confirmed authority and user decisions. If intended meaning or precedence remains disputed, ask the user with a recommendation; specialist agreement is not approval. Pause only dependent work while preserving independent authorized work.

Consolidating passages within an assigned document does not authorize deleting, moving or archiving a whole document; changing confirmed user intent or historical/acceptance evidence; or editing an instruction file without existing user approval for that bounded path and rules. Other authorized, evidence-backed document maintenance remains within its assigned scope. Cross-owner work still requires a bounded Lead assignment.

## Existing-project adoption

1. Read project instructions and existing documentation conventions. Scan configured document roots plus explicit external-to-docs repository documents. Include attachments, inaccessible references and nontext sources in the assessment; hashing a file is not reading it. Exclude credentials, dependencies and generated output. Report omitted/unsupported sources and inventory boundaries.
2. Explorer supplies focused code evidence (entrypoints, relevant modules/interfaces/data, tests and commands); the Lead may do this directly for a small task. The docs maintainer does not duplicate broad code discovery. Architect evaluates architectural gaps and Tester assesses acceptance/test sufficiency through the Lead.
3. Distinguish current observed implementation, confirmed intent and unknowns. Never generate intended requirements by treating every current behavior as correct. Discover only the requested scope; uninspected modules remain uninspected. Source restructuring requires the existing explicit refactor approval.
4. Classify each discovered document by category, lifecycle, authority and applicability. A document can be unrelated to this task while remaining active elsewhere. Establish a scoped review, with source locations, missing information, affected work and proposed next steps. Record confirmed decisions for reuse.
5. Reuse adequate documents; fill factual gaps from verified evidence, not invention. Questions that determine business intent, precedence, archive suitability or material design choices require user decisions before dependent edits.

## Readiness assessment

Assess requirements, architecture, interfaces/data, UI/UX, runtime/development, testing/acceptance and security/migration information as required, conditional or not applicable, with task-specific reasons. These are information dimensions, not mandatory document types. Consider outcomes/non-goals, happy/failure paths and business rules, module placement, external contracts, applicable UI states, reproducible run/test conditions and observable acceptance.

Every finding states source evidence, impact/affected work, the missing/conflicting information, recommended options and a question when user choice is required. For a cross-document conflict, identify the competing passages and the conditions in which they disagree. Distinguish absent, unread, inaccessible and not applicable. Never claim coverage from summaries of documents that were not actually read. Ready means the requested scope has sufficient reviewed information; partial means explicitly named independent work can proceed; blocked means dependent implementation waits. No document check establishes tested correctness or human acceptance.

**Ambiguity rule:** do not choose a winner, silently rewrite, merge, move or archive disputed material. Ask the user with evidence, options and a recommendation. Preserve the originals and mark the affected work pending. A timeout or no response is not a decision. Independent authorized work may proceed, and routine unambiguous index/link maintenance needs no repeated approval. Record an actual user's decision and scope before marking an ambiguous finding resolved; nonempty evidence cannot authenticate that decision.

## Legacy handling

Use `<docsRoot>/legacy/` for documents confirmed superseded or no longer applicable, never as a catch-all for material unrelated to this task. Historical decisions can remain useful and need not be archived solely by age. Before an authorized unambiguous move, inspect references, establish replacement/retained value, record original path, reason and replacement, preserve bytes and update links/indexes. If uncertain, ask and leave the document in place. Do not delete material or automatically archive based on a filename, hash, scan result or PRD date. The runtime deliberately has no command that decides or performs legacy moves.

Historical files remain inventoried as historical, not current authority. Validate current references into legacy: historical context may be valid, dependency on an obsolete requirement needs reassessment.

## Changes and closure

Before each start, inspect the marker, policy version, task scope/wording and underlying review. New/modified/deleted docs, authority/applicability changes, or changed declared code/API dependencies require impact assessment. New docs are classified before reuse. Whole-inventory fingerprints are conservative: an unrelated addition can mark a review stale; the Lead can re-read the delta, record why it is unrelated and reuse unaffected evidence in a fresh assessment. Never update hashes merely to obtain a pass.

The policy version changes when checking requirements change. Kit/model changes alone do not invalidate an otherwise current review. Metadata schema changes need explicit migration; malformed state is not permission to reset ownership. Track absent expected dependencies as absent so their later creation invalidates evidence. Unknown unlisted code changes cannot be detected: reviewers must select sufficient dependencies, preferably stable interface/schema sources.

At handoff, reconcile implemented behavior with applicable PRDs and confirmed decisions, update affected factual documentation, and reassess invalidated evidence. Writers receive the review path/scope plus PRD, Blueprint and stage-packet references; they do not inherit authority from a bare marker. User manual testing remains in stage packets. Keep one current assessment per scope, retaining history only outside the current review pointers.

When authorized to edit documentation, inspect the relevant surrounding and linked documents as needed. If that work exposes an evidence-backed outdated, inaccurate, misplaced or duplicative active passage, correct it promptly within the assigned document ownership and update affected links/indexes. Keep corrections bounded to the supported facts; preserve historical value and user-authored acceptance evidence. Do not turn this into a repository-wide cleanup or history rewrite, move/archive whole documents, change confirmed user intent, or infer intent from implementation. If a correction crosses an unassigned owner boundary, report it to the Lead and obtain a bounded assignment first. Read-only reviews report defects without editing. Ambiguous intent, conflicting authorities or a disputed move/archive still require the user's decision under the ambiguity rule above.

Before adding a detailed rule, locate the existing document responsible for that topic and update or reference it rather than creating a competing definition. Run semantic consistency checks during scoped adoption, when relevant documents are added or changed, when a material implementation change affects documented claims, at task closure, or when an authorized edit reveals a related defect. Recheck the affected sources, links, indexes and declared dependencies after reconciliation. These triggers call for task-scoped review, not a full-repository semantic sweep for every small task or a background watcher. An inventory, hash refresh or prior review does not by itself establish that document meanings were reconciled.

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

Scan/Status/Validate are read-only and never edit Git ignore policy. Before Initialize or RecordReview writes local governance files or temporary siblings, the runtime protects its exact local-artifact paths; the marker, index and reviews remain on disk in the current checkout but are not shared through Git. User-authored governance documentation and other formal project evidence remain versionable. See the [generated-artifact Git protection contract](generated-artifacts.md) for the exact local bundle, preservation boundaries and Git-index checks. Apart from the narrow protection update to the project's `.gitignore`, Initialize creates only the governance index/marker; existing docs and source are untouched. RecordReview consumes a Lead-reviewed authored assessment, checks structure and fingerprints, and writes the assessment/index/marker. It does not read semantic intent, certify approval or automatically mark anything ready. A fresh checkout does not inherit another checkout's governance adoption or readiness state; scan its available documents and establish local state/review as applicable. Resolve unsupported or ambiguous input rather than changing product documents to pass. Keep authored inputs in the project's established working area, not alongside current deliverables, and do not scan credentials.

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
