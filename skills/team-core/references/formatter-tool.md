# Scoped formatter tool

Use the installed [`scripts/format-code.ps1`](../scripts/format-code.ps1) helper with the shared [code-readability contract](code-readability.md). The helper lets codewriters and `team-code-maintainer` plan and run an existing project formatter on an exact assigned file list. It is not a package manager, does not authorize semantic code changes, and cannot sandbox a formatter's side effects. The repository-facing guide and acceptance record live outside the installed Skill; this reference is the portable runtime source of truth.

## Actions and authority

Run under PowerShell 7. The caller resolves `$formatterScript` to the installed Kit helper and sets `ProjectRoot` to the target project. `Plan` is the default:

```powershell
# No action is supplied, so this performs Plan.
& $formatterScript -ProjectRoot . -Files @('src/app.ts', 'src/view.tsx') -Formatter Auto

# Check executes the selected formatter to compare its output; the helper does not apply it.
& $formatterScript -Action Check -ProjectRoot . `
  -Files @('src/app.ts', 'src/view.tsx') -Formatter Auto -TrustTooling

# Apply also requires established authority to write these exact files.
& $formatterScript -Action Apply -ProjectRoot . `
  -Files @('src/app.ts', 'src/view.tsx') -Formatter Auto -TrustTooling -AllowWrite
```

`-Files` must contain 1–100 literal repository-relative file paths. Do not pass directories, wildcards, globs, or a repository-wide scope. `-TimeoutSeconds` defaults to 30 and accepts 1–120. `-MaxFileBytes` defaults to and is capped at 1 MiB per source/config file. Combined captured stdout/stderr is capped at 4 MiB of UTF-8 output; each formatted candidate is also capped at 4 MiB.

`-TrustTooling` and `-AllowWrite` carry the caller's already-established authority. They do not create, authenticate or expand approval. An explicit user request or developer assignment may already authorize the exact file writes; do not ask for redundant confirmation on every run. Do not ask again to trust a local formatter/configuration already reviewed. Ask the Lead/user only when tooling trust, installation, formatter choice or file scope exceeds the authority already established.

`Plan` reads the bounded selected source bytes and nearby configuration/manifest metadata, checks encoding and generated-file markers, and validates only configuration shapes the helper supports. It does not start child processes or evaluate configuration code, and does not check Git's ignored-file policy. Git-ignored files are excluded during `Check`/`Apply`. When metadata outside `ProjectRoot` is relevant, the helper may use existence-only evidence; it does not read that external file's contents or emit its private absolute path. `Check` and `Apply` execute the selected formatter and use Git's ignore policy when applicable. If `ProjectRoot` is nested inside a parent Git worktree, the helper blocks with `git-policy-boundary`; set `ProjectRoot` to the containing repository root and express `-Files` relative to it, or use the existing native project command. Depending on the adapter, execution may run trusted JavaScript configuration/plugins or import local PowerShell module code. A safely imported PowerShell settings `.psd1` is read as data, but the formatter module itself executes. Trust the executable/module and the configuration/plugin code it may load before passing `-TrustTooling`. The helper and its wrapper are not an OS sandbox; a formatter can have side effects outside the exact files and those effects cannot be prevented here.

`-AllowWrite` represents authority for the exact paths already assigned. `Apply` validates and computes all formatter candidates before it starts writing, and checks source bytes before replacing each file. Formatter/preflight errors prevent candidate writes. File writes are sequential, not a multi-file transaction: a late I/O error can leave an earlier file applied, and the helper reports the possible partial write without rollback.

## Selection and supported adapters

`Auto` uses nearby project metadata and file type. A supported file extension alone does not select a formatter; selection requires applicable project evidence. For example, PowerShell configuration evidence can select the adapter, or a caller can explicitly choose `-Formatter PowerShell` with a PSScriptAnalyzer module manifest in `-ToolPath`. Conflicting formatter/configuration evidence or unsupported native behavior is surfaced for a caller decision. It does not search PATH for an arbitrary Prettier package or formatter shim. Existing project formatters remain authoritative even if unsupported; for example, detected Black is not silently replaced by Ruff. Explicit `-ToolPath` supplies a literal local executable/module path, but that path is not itself trusted.

| Formatter | Selection and tool path | Configuration boundary |
| --- | --- | --- |
| Prettier | Can be selected from nearby Prettier config or a local `node_modules/prettier` dependency and resolved through Node. An explicit `-ToolPath` can name a supported local `.js`, `.cjs` or `.mjs` entrypoint. | Native file info plus `.gitignore`/`.prettierignore` behavior is checked. JavaScript configuration/plugins may execute during Check/Apply. `package.json`/`package.yaml` formatter configuration requires the native project command. If an `.editorconfig` outside `ProjectRoot` may be inherited, use the native command unless an in-project `.editorconfig` terminates discovery with a valid global `root = true` entry. The entry must be a whole line before the first section; inline comments or `root = true` inside a section do not terminate discovery. A nonterminating in-project `.editorconfig` remains conservatively unsupported. Package scripts are never run. |
| Ruff | The file type and nearby `ruff.toml`, `.ruff.toml` or a simple `[tool.ruff]` section can select Ruff. Supply the native executable via `-ToolPath`. | Only the helper's narrow formatter-setting subset is accepted. Other Ruff tables/settings or unsupported `.ignore` policy require the native command. Existing Black policy is not replaced. |
| PowerShell | Nearby `PSScriptAnalyzerSettings.psd1` evidence can select this adapter for PowerShell files; otherwise explicitly choose `-Formatter PowerShell`. Supply the installed PSScriptAnalyzer module manifest (`.psd1`) through `-ToolPath`; a bare module name or `.psm1` is not accepted. | The fixed worker imports the trusted module and invokes `Invoke-Formatter`. `PSScriptAnalyzerSettings.psd1` is imported as data. The helper does not install the module. |
| Biome | JavaScript/TypeScript and other supported file types may select Biome from nearby configuration or package dependency evidence. Supply the native executable through `-ToolPath`. | Only strict JSON `biome.json` config without `extends`, overrides, include/ignore/files, VCS or plugins is supported. JSONC and shapes the helper cannot safely preserve require the project's native command. |

Other extensions do not automatically select an adapter. Missing tools, ambiguous configuration, unsupported configuration/native semantics, unsafe paths and preflight failures return machine-readable reasons for the caller. Do not download/install/update tools, invoke arbitrary package scripts, override native ignore behavior, or guess a substitute. When the adapter cannot reproduce the existing project command, use that native workflow only with already-established trust or ask the Lead for a bounded decision.

## Results and limits

The JSON result has `schemaVersion: 1`, `kitVersion`, `action`, `results`, `summary`, and known `limitations`. Each result includes `path`, `formatter`, `configPaths`, `status`, `reason`, `version` and `changed`. Status is one of `planned`, `clean`, `would-change`, `applied`, `excluded`, `blocked`, or `error`. Reason values are stable machine-readable codes; do not parse human wording as an API.

- Exit `0`: successful Plan/Check/Apply, including clean or explicitly excluded files.
- Exit `1`: `Check` found a difference (`would-change`).
- Exit `2`: blocked/unresolved Plan or an execution/write error; includes a possible partial Apply.

Supported file encodings are strict UTF-8 with or without BOM and BOM-marked UTF-16 little- or big-endian. UTF-32, malformed encoding and mixed line endings are rejected. Supported BOM and line-ending conventions are retained when output is written; this does not prove semantic equivalence. The helper protects code/config metadata, generated/vendor/dependency and snapshot paths and respects applicable native ignored-file policy in Check/Apply.

For normal code delivery, the developer completes the feature and comment self-check, plans and checks the exact assigned files, applies only within established write authority, inspects the diff, and reviews the remaining readability that formatting cannot judge. After any Agent edits, run Check again. Direct formatting requests go through [`team-code-maintain`](../../team-code-maintain/SKILL.md) and use the same flow. A clean formatter check does not prove code readability or correctness.
