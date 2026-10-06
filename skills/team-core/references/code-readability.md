# Code readability contract

Apply when authoring or reviewing assigned code and when a user requests a bounded formatting/readability pass. The presentation guidance applies to every codewriter and tester working on authorized feature changes. The no-behavior-change boundary applies only to formatting-only maintenance; it does not restrict the original domain owner's authorized feature implementation. This contract supplements the [code comment contract](code-comments.md); it does not reduce its interface or test-explanation requirements.

## Readable delivery

- Follow the target project’s formatter and configuration first. Do not replace, reconfigure, or introduce a formatter as part of a readability pass.
- When no project formatter or width rule applies, aim for lines no longer than 100 characters. A line over 120 characters is a review signal, not a hard limit. Keep a longer line when wrapping would obscure meaning or alter a semantic value.
- Arrange code in logical paragraphs and keep related steps together. Do not squeeze independent statements onto one line. Wrap calls, parameter lists, object literals, JSX, and nested expressions when that makes their structure easier to follow; avoid dense nested ternaries. Use whitespace to make structure visible, not to meet empty-line quotas.
- Choose descriptive names for new or changed code. A formatting-only maintainer does not rename existing symbols; a rename is a separate code change owned by the original domain role.
- Preserve every applicable comment and explanation, including each test case’s purpose and expected result. Update an explanation only when an authorized behavior change makes it inaccurate; formatting alone does not waive the comment contract.

Generated and vendor files are outside a readability pass unless the Lead explicitly assigns a source generator or a specific generated output. Do not reformat snapshots or serialized fixtures when doing so changes their asserted representation. Do not split, normalize, or otherwise alter meaningful strings, URLs, whitespace-sensitive data, or other literals to satisfy line length. Keep intentionally single-line TOML instruction strings intact when wrapping would change their required representation; their length alone is not a reason to rewrite them. If a safe layout cannot be achieved without changing semantics, keep the code and report the limitation.

## Bounded formatting maintenance

The Lead may route an explicit user request for code formatting/readability to `team-code-maintainer`. The same role may receive an already-authorized set of files from a completed code-writing task after the original writer has finished and frozen them. Never allow concurrent writers on transferred files. The Lead supplies the exact paths, task context, formatter/check commands, and any relevant acceptance notes.

Use the installed `team-core/scripts/format-code.ps1` helper for supported project formatters when it can handle the exact assigned files. Begin with `-Action Plan` (the default) and review the selected formatter, configuration paths and per-file status. Plan reads bounded source/configuration metadata but does not start child processes or evaluate configuration code. `Check` and `Apply` run the selected formatter; native JavaScript configuration/plugins or the imported PowerShell module may execute. For both actions, the caller must explicitly pass `-TrustTooling`; `Apply` also requires `-AllowWrite`. These switches carry the caller's existing trust and write authority; they do not create approval, sandbox the formatter or authorize files outside the assignment. Do not request a redundant approval for a known tool and already-authorized exact files. Pass only literal repository-relative file paths in `-Files`, rooted at the stated `-ProjectRoot`. See the portable [formatter tool reference](formatter-tool.md) for the action interface, adapter limits, result codes and failure behavior.

The helper supports `Auto`, `Prettier`, `Ruff`, `PowerShell`, and `Biome`. Auto uses the nearest applicable configuration/dependency evidence. Conflicting evidence, missing tools, unsupported configuration, or unsupported native project commands are reported for a caller decision. Keep the project's existing formatter authoritative, including tools the adapter does not support; do not substitute a different formatter. Do not install or download tools, invoke package scripts, widen the file list, or bypass native ignore/configuration behavior. An explicit `-ToolPath` identifies a local tool but does not make it trusted. If the helper cannot safely handle the project setup, use the project's existing command only after the caller has approved that tooling, or return the limitation to the Lead.

For code delivery, run the selected formatter through `Check`, and use `Apply` only when the exact files and write are already authorized. Review the resulting diff, then have the assigned codewriter or maintainer inspect remaining readability issues. If the Agent makes any further edits, run `Check` again. A clean formatter check is mechanical evidence; it does not establish readability or semantic correctness. Respect the helper's documented input-size, encoding, line-ending, process, and failure limits. The trusted process is not an OS sandbox and may have side effects outside the selected files. In particular, sequential Apply can report a partial write if a later file write fails; no atomic rollback is promised.

The maintainer may apply configured formatting and safe layout changes within those paths. It must not rename or move code, extract helpers, change APIs, alter control flow or strings, change architecture, or otherwise change behavior. This maintenance boundary does not prohibit feature changes assigned to the original domain owner. If a maintenance request crosses the formatting boundary, return only the affected item to the Lead and original domain owner; leave other safe assigned formatting complete when independent.

For a direct formatting-only request, run the project formatter and proportionate scoped checks. Do not force the full `$team-dev` lifecycle or claim a behavior test from formatting checks. For a transfer within a material code task, the Lead retains the task’s existing Tester and Reviewer gates: the maintainer freezes its edits before the planned final tests and the existing independent review. Do not add a second Reviewer cycle solely for formatting.

`team-code-maintain` is a Lead adapter for those direct requests and bounded transfers; it is not recursive child context. The Lead assigns this contract and the exact file scope to the selected role. If `team-code-maintainer` is unavailable in the active role catalog, report that limitation and ask for a specific next step; do not silently use the Lead or a generic role as substitute.

## Writer self-check

Every codewriter and tester checks the assigned delivery against the presentation and comment requirements above. For a formatting-only maintenance pass, additionally inspect the actual diff and confirm that:

- the project’s existing formatter/configuration was used where available;
- layout, logical grouping, JSX and names are readable without artificial whitespace quotas;
- meaningful literals, generated/vendor content, snapshots, tests, and existing comments were preserved within the stated scope;
- no rename, extraction, API, control-flow, string, architecture, or other behavior change slipped into the formatting pass; and
- only the assigned formatter and proportionate checks were run, with outcomes and any unsafe/unavailable cases reported.

The Lead reconciles this self-check with the existing Work or Verification record. Formatting checks do not prove native role identity, human acceptance, or semantic equivalence beyond the inspected diff and applicable project checks.
