# Generated artifact Git protection

Use this contract when a Team workflow creates Kit-owned local artifacts inside a target Git repository. It provides narrow ignore-rule protection and an audit of the actual index; it does not make Git staging impossible or promise universal prevention.

## Profiles and lifecycle

The helper is `scripts/generated-artifacts.ps1` in the installed `team-core` Skill package. It takes `-Action Protect` or `-Action Check`, `-ProjectRoot`, and `-Profile Documentation`, `OpenSpec`, or `Work`. `Work` also requires one exact repository-relative `-WorkPath` such as `_work/<boundedtask>`; the path must be a single task slug under `_work` and no longer than 86 characters.

Run `Protect` before creating local temporary or generated output in the selected scope. It adds only the narrow Kit-owned ignore rules needed for that profile. A repeated call is safe. With `Work`, the path is explicitly bounded; an existing effective positive ignore for that exact scope may be reused. If existing rules make the scope uncertain, protection stops and leaves user rules unchanged.

Run `Protect` again for every applicable scope before a planned commit or handoff, then run `Check`. `Check` reads ignore policy and the Git index independently: a tracked local artifact remains a finding even when a matching ignore rule exists. `Check` is an audit only; it does not add ignore rules, stage files, or remove paths from the index.

| Profile | Use for | Retention boundary |
| --- | --- | --- |
| `Documentation` | The whole `<DocsRoot>/governance/reviews/` subtree, the exact `<DocsRoot>/governance/documentation.json` and `<DocsRoot>/governance/doc-index.md` files, `.documentation.lock`, `.pending.json`, and atomic temporary siblings with an exact 32-character lowercase hexadecimal token before `.tmp` | The governance runtime bundle stays on disk in the current checkout but is not shared through Git. This does not ignore the whole `governance/` directory: user-authored governance documents, PRDs, agent instructions, Blueprint, active and archived verification packets, native specs and archives, references, and selected reproducibility evidence remain versionable. No general `*.tmp` rule is added. |
| `OpenSpec` | `openspec/.team-recovery/` and `openspec/.team-archive.lock` | Native specs and archives remain versionable; external OpenSpec files and project content are not hidden. Recovery files are retained locally when needed after failure. |
| `Work` | Temporary output owned by one bounded task | Protect only the exact `-WorkPath`; do not use a broad work, coverage, image, or cache pattern. |

`Protect` appends missing anchored rules to `ProjectRoot/.gitignore` only. It preserves existing file content, a UTF-8 BOM, and the file's line-ending style; a `.gitignore` that is not valid UTF-8 is rejected without changes. It never edits a parent repository's ignore file. Relevant project ignore files are checked for effective negation rules that could expose the bounded output.

For `Documentation`, the local runtime bundle is exactly the whole `<DocsRoot>/governance/reviews/` subtree and the `<DocsRoot>/governance/documentation.json` and `<DocsRoot>/governance/doc-index.md` files, in addition to lock, pending and exact temporary residue. Other files under `governance/` are not broadly ignored.

Local retention is not the same as Git tracking. Feedback and deployment runtime data belongs outside the project. A file being ignored or retained locally does not mean it was deleted, archived by decision, or removed from Git history. The governance runtime bundle does not transfer to a fresh checkout; assess the available documents locally and establish its own adoption/review state where applicable. Do not infer readiness from another checkout's records.

## Result and conflict handling

Successful calls return JSON with `schemaVersion: 1`, `action` (`protect` or `check`), `profile`, `git`, `status`, `rulesAdded`, `violations`, and `decisionRequired`. `status` is `protected`, `clean`, `violations`, or `not-git`. Each violation contains `path` and `reason`, where the reason is `indexed-local-artifact` or `explicit-include-policy`; an explicit-include violation may also include its matching `pattern` for diagnosis.

`Check` reports violations as structured output and leaves files and the index untouched. A `clean` result means no indexed local artifacts or conflicting explicit includes were found; it does not prove that all required ignore rules exist. Run `Protect` before relying on `Check`. `Protect` fails with `ARTIFACTS` before changing `.gitignore` when a tracked local artifact or explicit include conflicts with the protection. Path, Git, or required-dependency errors also fail instead of silently broadening the scope. Inspect the reported path and ask the user how to handle the conflict; never automatically untrack it.

When the project path is not a Git worktree, the helper reports `git: false` and `status: not-git`. It does not initialize Git or create an ignore file. If Git is initialized later, protect the relevant scopes before the first staging operation.

For example:

```powershell
pwsh -NoProfile -File skills/team-core/scripts/generated-artifacts.ps1 `
  -Action Protect -ProjectRoot . -Profile Documentation

pwsh -NoProfile -File skills/team-core/scripts/generated-artifacts.ps1 `
  -Action Protect -ProjectRoot . -Profile Work -WorkPath _work/generated-artifacts

pwsh -NoProfile -File skills/team-core/scripts/generated-artifacts.ps1 `
  -Action Check -ProjectRoot . -Profile Documentation
```

## Limits

The helper does not write the Git index, stage or commit files, install hooks, or run a background watcher. It cannot stop a person or tool from manually staging a path, including with `git add -f`. Recheck the actual index with `Check` before an authorized commit or handoff. Read-only discovery and review commands do not edit ignore policy; callers that are authorized to generate local artifacts must protect their scope before writing.
