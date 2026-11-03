# Agent development documentation and source maps

This contract is for durable, source-linked development guidance in a target project. Use the repository's existing authoritative documents and layout first. A `docs/agent/` set is a conditional organization for guidance that agents need across tasks; it is not a required scaffold, policy registry, duplicate PRD, second task list or automatic instruction loader.

## Sources of truth and document placement

Keep each piece of information with the source that owns it. Link from an agent-oriented index rather than copying the full product or task record.

| Optional document | Purpose when needed | Keep authoritative content in |
| --- | --- | --- |
| `docs/agent/README.md` | Entry map: task and module triggers, source links, maintained scope and current versus planned/deferred guide status. | Each linked source below; the index is navigation, not approval evidence. |
| `docs/agent/constraints.md` | Concise durable cross-cutting confirmed constraints, applicable exceptions, non-goals and decision references. | Active PRD/specification, explicit user decision, security or policy document. |
| `docs/agent/architecture.md` | Stable module responsibilities, actual boundaries and links for code navigation where the project architecture source is hard to discover. | Existing Blueprint or architecture document. |
| `docs/agent/verification.md` | Where to find relevant test guides, commands and acceptance sources; useful when the repository has several distinct verification boundaries. | Existing test guide, CI/runner configuration and stage/verification packet. |
| `docs/agent/development/README.md` | Onboarding into existing setup and contribution guidance, with links and verified scope. | Root README, setup guide, contributor guide and actual project configuration. |
| `docs/agent/development/common-environment.md` | Reproducible shared environment assumptions and known limits that affect multiple modules. | Dependency manifests, setup scripts, CI and verified commands. |
| `docs/agent/development/modules/<module>.md` | A real, stable module boundary: owner, responsibilities, public interfaces, relevant constraints and paths to source/tests. Add a module subdirectory/page only when that module's complexity justifies independently maintained detail. | Source interfaces, architecture/Blueprint and existing module documentation. |
| `docs/agent/sources.json` | Portable minimal map from maintained agent-document pages to the source files whose changes should trigger inspection. | The maintained pages still derive meaning from their listed source authorities; the map is evidence about files, not authority. |
| `docs/agent/handoffs/README.md` and `docs/agent/handoffs/<outcome-id>.md` | A small index and current continuity snapshot for a coherent outcome that needs durable handoff across owners/sessions. Use one record per independently deliverable outcome, not per message, file or tweak; reuse an existing accessible Work/issue record when it serves this role. | The existing Work contract, issue/tracker and stage packet remain authoritative for task acceptance and detailed results. The handoff links them and carries only the context needed to continue. |

Create only documents that answer a real recurring discovery need. Before adding one, read the candidate's surrounding source and links; identify its audience, authority, applicability and owner; and check for an existing equivalent. Update an existing authority first. If similar passages serve different conditions or audiences, keep them complementary and link them. If detailed claims are genuinely redundant, retain detail in the topic authority and replace only the assigned secondary copy with a useful summary/reference, preserving unique examples and evidence. Split an overgrown guide only when distinct audiences, triggers or maintenance owners need independently discoverable detail; first assign each topic's authority and owner, then replace moved passages with reciprocal links and recheck every affected index/reference. Do not create empty mandatory directories, copy an entire PRD or test journal, or move an existing source only to match this example. Keep task chronology, open tasks and decisions in their existing Work/project records; keep detailed results and formal acceptance in the existing stage packet. A root README remains a stable entrypoint. `AGENTS.md` remains concise durable work guidance and is governed by the separate [project-rules contract](project-rules.md); generic documentation authority does not authorize editing a target instruction file.

For a durable handoff, keep `handoffs/README.md` as a status/navigation index and an outcome record as a concise continuation snapshot with stable source, Work, issue and packet links. Do not turn it into a competing product backlog, issue tracker or acceptance ledger. If a task/Work record is local, ignored or inaccessible to the next session, do not pretend that its contents are portable: carry only sanitized, authorized context in the versioned handoff and leave unavailable results/approval explicitly pending. For trivial work whose existing record is accessible and sufficient, link/reuse it instead of adding a handoff file.

Classify each statement as confirmed/current, observed, proposed, unknown, rejected or historical. “Planned” must not read like implemented behavior. Do not publish private absolute paths, credentials, raw conversations, unnecessary model traces or bulky test logs. Local governance metadata and ignored state are not portable authority.

## When to read and reconcile

Read only the source pages needed for the current task and the module/change boundary. Do not inject the whole `docs/agent/` tree into every task or scan it on every message. Reassess the relevant source map and source content:

- when starting a task whose scope may use the guidance;
- when first entering a relevant module or interface;
- when a relevant PRD, user decision, source, configuration, command, test or guide changes;
- before reusing a claim whose source snapshot may be stale;
- during review or handoff when a changed constraint, stable fact or reusable decision needs an assigned documentation update.

The source map detects candidate changes, not meaning or applicability. A path listed in the map is not proof that its content was read. A change outside the map cannot be inferred from map hashes; use the task scope, repository diff and known interfaces to look for relevant unlisted sources. Add or remove a mapping only after the responsible maintainer reads the candidate content and assesses its role, preserving legitimate exclusions and pending conflicts; the Lead judges task relevance and readiness. An aggregate `changed`, `unmapped` or `unknown` result is not an automatic whole-project stop: the Lead decides which paths affect the current task, pauses dependent work, and permits demonstrably unaffected authorized work to continue.

## Portable schema and Inspect command

The read-only helper reports source/document evidence. It never initializes a baseline, writes the manifest or pages, edits Git state, fetches a remote, deletes files, approves intent or certifies readiness. Use the project's installed/local copy of the Kit if available; source presence alone does not prove that a running Codex session loaded any Skill.

```powershell
pwsh -NoProfile -File <kit-root>/skills/team-core/scripts/agent-docs.ps1 `
  -Action Inspect -ProjectRoot <target-project> `
  [-ManifestPath docs/agent/sources.json]
```

`-ProjectRoot` is the target project. `-ManifestPath` is a project-relative path; if omitted, the default is always `docs/agent/sources.json`, even when `documentsRoot` names another contained equivalent directory. For an equivalent directory, pass its manifest path explicitly. The default `documentsRoot` is `docs/agent`; a configured equivalent must remain inside the project. The helper is report-only. The assigned document maintainer inspects source semantics and proposes or applies only authorized edits; the Lead owns task relevance/readiness. Human approval is required only where the existing authority requires a user decision, such as disputed intent or a bounded permission gate, not for every routine maintenance edit.

Schema version 1 has this portable form. Paths are repository-relative and use `/`; hashes are lowercase SHA-256. An intentionally absent expected source uses `exists: false` and `sha256: null`. The values below are illustrative, not a ready-to-use baseline: replace every present-file hash and Git object ID with values from the actual project snapshot only after reading and semantically reconciling the sources. Inspect does not calculate proposed map entries when the map is absent; the assigned maintainer must use bounded ordinary file-reading/hash tools after source review. No initializer or map-writing action is provided.

```json
{
  "schemaVersion": 1,
  "documentsRoot": "docs/agent",
  "gitBaseline": "0123456789abcdef0123456789abcdef01234567",
  "documents": [
    {
      "path": "docs/agent/development/common-environment.md",
      "documentSha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "sources": [
        {
          "path": "global.json",
          "exists": true,
          "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
          "anchor": null
        },
        {
          "path": "eng/Directory.Build.props",
          "exists": false,
          "sha256": null,
          "anchor": "central build props"
        }
      ]
    }
  ]
}
```

`gitBaseline` is a required property whose value is null or a full lowercase 40- or 64-character Git object ID; it is a bounded comparison point, not a moving `HEAD` reference. `anchor` is optional, inert locator text to help locate a relevant section or symbol. It is not executed, parsed as a command, or proof that the mapped source contains the stated claim. Do not add timestamps, a self-hash, tool output, duplicated policy, or a document as a source for itself or another mapped document. The manifest cannot map itself as a source or target. No mapped `docs/agent/` document may be a source in any entry.

The tool validates schema and safe contained paths, rejects unknown fields and unsupported versions, and excludes only the Kit's local governance runtime bundle (the canonical `documentation.json`, `doc-index.md`, reviews subtree, locks and tool temporary files), `_work/`, dependencies, secrets and manifest/self from source coverage. Other formal/user-authored governance documents remain eligible sources. It reports bounded hashes, relative paths, inventory additions/missing entries, document/source states, current Git delta evidence, coverage gaps, limits and safe errors. Its Git subprocesses isolate system/global configuration and disable filters, external diff/text conversion, hooks and lazy fetch; it makes no persistent Git configuration changes. Git path hints may differ from a user's usual Git status normalization (for example under Windows `core.autocrlf`), so assess actual mapped source hashes/context rather than assuming identical paths. Git path lists describe the baseline-to-current net path delta, not every intermediate commit change that was later reverted. It does not return source text, raw diffs, stderr, private root paths or full home paths.

Submodule working trees are deliberately not entered, recursed into, or queried with nested Git commands. If a parent index, `HEAD`, or usable baseline tree contains a mode-`160000` gitlink, Git comparison is incomplete: the result marks Git/overall status `unknown`, includes the `git-submodule` safe error and a gap stating that submodule working trees are uninspected, and exits `2` while retaining any mapped-file fingerprints it could safely collect. This fail-closed behavior applies to staged additions, `HEAD`-only staged removals, baseline-only gitlinks and dirty current gitlinks; do not interpret unchanged mapped hashes as a fresh submodule snapshot. Reassess the relevant submodule state through an explicitly authorized, scoped process. Git per-record comparison is bounded to 20,000 entries in addition to the existing capture and time limits.

### Result statuses and exit codes

| Exit | Overall status | Meaning and next action |
| --- | --- | --- |
| `0` | `fresh` | The declared in-scope document and source snapshots match mechanically. Read task-relevant sources before relying on their content; this is not semantic approval or proof that coverage is complete. |
| `1` | `changed` | A mapped document/source changed, an expected file is missing/present unexpectedly, or an unmapped/inventory coverage delta exists. Inspect the exact listed paths and classify their meaning before editing. |
| `2` | `unadopted` or `unknown` | The manifest is absent/empty, evidence is incomplete or unsafe, a file read failed, or the Git comparison cannot be trusted. Treat the map as insufficient for freshness; perform explicit scoped source and snapshot reassessment before relying on it. |

Unknown/incomplete state outranks changed state. Read failure is `unknown`, never interpreted as “absent.” A missing manifest is unadopted; the utility does not create one. No-Git projects and switched, rebased, unreachable or non-ancestor baselines may still yield useful bounded filesystem snapshots, but they do not establish the missing Git comparison. Perform a task-scoped source/document assessment against that snapshot; do not auto-initialize Git or demand every optional template. Pause only affected dependent work while the Lead determines whether unrelated authorized work can proceed. Partial/promisor repositories fail closed before required object reads. A move appears as a missing old path plus a new path; never auto-transfer approval to the new name. A manifest-only edit is disclosed and excluded from its own freshness decision to avoid a self-reference cycle; this exclusion does not suppress independent target document hashes, so human edits to mapped Agent pages remain visible.

Current limits are 256 KiB for the manifest, 512 mapped documents, 4,096 mapped sources, 4,096 safe inventory files, 8 MiB per hashed file, 64 MiB total hashed bytes, 4 MiB Git capture, 20,000 Git paths and 60 seconds overall. Exceeding or failing a bound produces a safe unknown/error; it is not permission to skip a source or silently widen the scan. Before/after snapshot checks detect ordinary concurrent changes, but the utility does not lock out external editors.

## Reconciliation procedure

Use one named coordinator for a given Work item and one current, explicitly assigned writer for each shared document/map. The responsible Agent/maintainer may perform routine maintenance within assigned write authority; the Lead makes the readiness judgment and user decisions remain with the user:

1. **Establish scope.** Confirm project root, exact task, current branch/worktree or filesystem snapshot, existing active task/requirements, module, accepted constraints, non-goals and relevant source paths. Keep credentials/private data out of the process and output.
2. **Read actual sources.** Inspect the current document and its mapped source passages, then relevant unlisted dependencies from the real diff/interfaces. Classify claims as confirmed intent, observed behavior, proposal or unknown. A hash match or new file does not establish semantic equivalence.
3. **Inspect the map.** Run `Inspect` and record its exit/status plus exact relevant paths. For a changed result, check source and target bytes directly. For unknown/unadopted/no-Git/unavailable-base state, take and describe an explicit scoped snapshot; keep the report unknown until the missing comparison is resolved.
4. **Resolve meaning.** Correct only evidence-backed factual drift within assigned ownership. Preserve unique context. For actual conflicting intent, preserve both claims and ask the Lead/user with source, impact, options and recommendation. Do not rewrite, merge, move or archive disputed content. The aggregate inspection result alone does not block every workstream; the Lead pauses only affected dependent work and lets demonstrably unaffected authorized work continue.
5. **Prepare a bounded update without writing.** Define the exact page/map changes, sources to re-read and expected hashes. Identify the source of truth, confirm authorization/owner, and keep unrelated entries, pending conflicts and human edits unchanged. Do not replace the whole manifest from a partial scan.
6. **Check immediately before mutation.** Re-read the expected manifest bytes and hash, plus every affected target-page and source byte/hash. Confirm branch/base and task ownership are current. If any expected value changed, stop, preserve both edits, inspect the delta and reconcile with the current owner; never overwrite by last-writer-wins. Inspect does not provide a write lock, so use the editor's bounded expected-state check where available and recheck immediately before save; if the editor cannot protect a changed file, stop and reconcile before retrying.
7. **Apply the authorized bounded update.** Write only the planned page/map changes through the approved editor workflow. Keep unresolved, unread, missing or conflicting entries at their old expected state or explicit absence so the next Inspect remains changed/unknown. Preserve a target human edit; never reset its hash just to manufacture freshness.
8. **Advance only reconciled entries.** After reading and semantically reconciling the current source, update that entry's document hash and only the corresponding source hashes. Per-entry updates may advance independently. Retain old hashes for every unresolved entry or gap.
9. **Account for the broad Git baseline.** The root `gitBaseline` summarizes a wider set of Git changes than individual source-map entries. Do not advance it until every relevant current committed, staged, unstaged and untracked delta and every coverage gap has been assessed. Keep the old root baseline while any broad delta is unexplained.
10. **Reinspect and report.** Run Inspect after authorized source/map/document changes. Report the actual output, remaining changed/unmapped/unknown paths, semantic decisions and evidence, and which entries did or did not advance. A mechanically fresh result means only that the recorded snapshot matches; it is not approval, acceptance, or proof that no relevant unlisted source exists.

### Output fields and interpretation

The JSON result is bounded evidence, not a generated document. It includes `schemaVersion`, overall `status`, `manifestSha256`, `documents`, `inventory`, `git`, `coverage`, `errors` and `limits`. Each document row reports its relative `path`, current `exists` and `sha256`, recorded `expectedSha256`, nullable `documentChanged`, row `status`, and source rows. Each source row reports `path`, `expectedExists`, current `exists`, `expectedSha256`, current `sha256` and `status`. Git evidence separates current `committed`, `staged`, `unstaged` and `untracked` paths and reports comparison `baseline`, `head` and status. The coverage object carries bounded `unmapped` paths, explicit `gaps`, and a plain-language `scope`; errors are fixed safe codes, and limits identify incomplete evidence. A null current hash can mean absent or unreadable only when read alongside `exists`, row/source status and errors; read failure is never an intentional absence.

Overall `fresh` means the declared scope matches mechanically, not that the map is complete, that sources were semantically read, or that a policy was approved. `changed` can include unmapped deltas requiring relevance assessment. `unknown` means evidence is incomplete or unsafe; useful filesystem snapshots can still guide scoped reassessment. `unadopted` means the map is absent/empty and is not created by Inspect. The helper emits one bounded JSON result and the exit codes in the table above; callers must preserve both the exit code and output instead of treating process success alone as freshness.

Review relevant guidance at task start, first entry into a relevant module, when a mapped or known dependency changes, and at review/close if reusable facts or constraints changed. Prefer updating the existing authority before adding a page. Merge truly redundant detail only when authority is clear; preserve complementary conditions, audience context, examples, historical decisions and acceptance evidence. If a document becomes stale, mark current applicability and link to the replacement; move it to `docs/legacy/` or retire it only when unambiguous, referenced value is preserved, and the move is separately authorized. Never archive by age or delete disputed material. Recheck inbound/outbound links and indexes after an authorized change.

Do not use automatic synchronization to overwrite human pages. Do not invent an approval record, update hashes merely to clear a warning, discard pending conflict state, make a source map depend on its own output, or claim the utility enforces future model behavior.

## Relationship to existing records

Use an active PRD/specification for intended product behavior, the existing architecture/Blueprint for structure, API definitions for interface expectations, the existing test guide for repeatable procedures, and the stage packet for task-specific test evidence and manual acceptance. The map links and fingerprints selected evidence; it is not another authority or acceptance record. When a task closes, pauses or transfers, update the existing task record and promote only reusable, confirmed knowledge to the relevant development page. Keep canceled/superseded work distinct from verified completion and retain stable history references under the [outcome-based handoff contract](agent-handoffs.md).
