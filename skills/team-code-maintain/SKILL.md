---
name: team-code-maintain
description: Route direct code-formatting and readability requests to the bounded named maintainer, or coordinate a safe post-freeze formatting transfer. Does not implement behavior changes.
---

# Team code maintenance

Use this Lead adapter when a user directly requests a formatting/readability pass or when an authorized code task needs a separate, completed-owner formatting transfer. Read the shared [code-readability contract](../team-core/references/code-readability.md). This is not an alternate route for feature implementation, behavior changes, or broad cleanup.

## When to activate

Use for a direct request to format or improve code readability, including a natural-language request routed here, or when the Lead assigns a bounded formatting transfer after the original writer freezes its files. Use the shared [execution contract](../team-core/references/execution-contract.md), [role-routing rules](../team-core/references/role-routing.md), [file ownership contract](../team-core/references/file-ownership.md), [handoff format](../team-core/references/handoff-format.md), and [execution templates](../team-core/references/execution-templates.md) for named-role selection, exact ownership, and evidence. Do not use for feature work or when the original writer is still editing.

## Route the request

1. Establish the exact user-authorized files and whether the request is direct formatting-only work or a transfer within a material code task. Do not infer permission to touch adjacent files.
2. For a transfer, wait until the original writer has finished and explicitly frozen those files. Assign one writer at a time; do not overlap edits.
3. Check the active tool role catalog and select the exact `team-code-maintainer` role. Resolve the shared readability contract to its installed/source location and supply that location or its contents to the child alongside the exact paths, project formatter/configuration if known, relevant context, and proportionate checks. Do not ask the child to resolve the relative reference against the target business repository or the agent-profile directory; Skills and profiles use separate package/install roots. The source profile requests GPT-6 Luna / medium; do not infer the resolved runtime model from that file.
4. If the named role is unavailable, explain the limitation and leave the formatting request unperformed unless the user approves a specific next step. Do not silently substitute the Lead, `default`, or another role.

## Use the formatter helper

For supported formatters, invoke the installed `team-core/scripts/format-code.ps1` with the exact `ProjectRoot` and literal repository-relative `-Files`. Start with `-Action Plan` (the default); inspect the reported formatter, configuration paths and per-file result before execution. Plan reads bounded source/configuration metadata but does not start child processes or evaluate configuration code. `Check` and `Apply` run the formatter; trusted JavaScript configuration/plugins or the imported PowerShell module may execute. Both require explicit `-TrustTooling`; `Apply` additionally requires `-AllowWrite`. These switches carry existing tool trust and bounded write authority; they do not create approval, expand authorized paths or provide a sandbox. Do not ask the user to repeat an already established approval for each run. Follow the portable [formatter tool reference](../team-core/references/formatter-tool.md) for exact adapter/configuration limits, trust boundaries, status and exit-code semantics.

Use `Formatter Auto` only when the detected configuration/dependency evidence is unambiguous. Prettier can be resolved from a local project package; Ruff and Biome require an explicit native executable path; PowerShell requires a PSScriptAnalyzer module manifest path. The supported explicit choices are `Prettier`, `Ruff`, `PowerShell`, and `Biome`. Never replace an existing project formatter such as Black or go fmt just because the helper has no adapter for it. Missing tools, conflicts, unsupported configuration/native commands and unsafe paths return to the Lead for a decision; do not install, download, run a package script, or guess a fallback. An explicit `-ToolPath` does not establish trust. Use the shared [code-readability contract](../team-core/references/code-readability.md) for the assigned behavior and scope.

## Bound the work

The maintainer follows the project's existing formatter and configuration first. If none applies, use 100 characters as a line-length target and treat lines beyond 120 as a review signal, not a hard limit. Preserve semantically meaningful long strings, URLs, parser data, snapshots, generated/vendor content, and existing per-test purpose/expected-result explanations under the shared contract.

Formatting maintenance may improve indentation, line wrapping, grouping, and whitespace, but must not rename symbols, move code, extract helpers, change APIs, control flow, strings, architecture, or behavior. Return only questionable changes to the Lead and original domain owner; safe independent formatting may continue within the assignment.

For a direct nonbehavioral request, run `Check`, apply only after the explicit write acknowledgement, inspect the exact diff and run a final `Check` after any Agent follow-up edits. Close with the formatter/check results; do not require the full `$team-dev` lifecycle. A clean formatter result is not proof of readability or semantics. For a completed-owner transfer inside material feature work, preserve the task's existing Tester and Reviewer assignments. The maintainer freezes changes before the planned final tests and existing independent review; do not add another Reviewer cycle solely for formatting.

## Output contract

Report Result, Evidence, Risks, and Next step. Include exact files inspected/changed, formatter and checks run with outcomes, any skipped or unsafe item, and confirmation that no maintenance-scope behavior change was made. For any delegated work, reconcile the actual selector, returned handle, known role/model evidence, and final status using the existing Work/Verification record and shared [handoff format](../team-core/references/handoff-format.md); do not create a duplicate invocation ledger. For transferred work, return the frozen diff and checks to the Lead; the Lead owns the original task's remaining verification and final handoff.
