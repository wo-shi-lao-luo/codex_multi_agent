# AI workflow and agent simulation contract

This contract governs optional, local prototyping of an AI agent or workflow before a separate decision to engineer it. It defines evidence and boundaries; it is not a general workflow engine and does not call a model itself.

Application implementation may separately define a replaceable Agent/Workflow capability and record/replay tests under the [AI capability contract](ai-capability-contract.md) and [AI record/replay testing contract](ai-record-replay-testing.md). Simulation traces remain prototype evidence; they are not recordings of a real product integration run.

## Where artifacts belong

In a target project, keep reusable, synthetic workflow material under `docs/ai-workflows/<flow>/`:

```text
docs/ai-workflows/<flow>/
  definition.json
  context-policy.md
  prompts/...
docs/verification/active/<stage>.md
_work/ai-sim-<task>/runs/<run-id>/
```

Preserve established target-project conventions when equivalent authoritative locations already exist. The definition is the authoritative location for cases and expected criteria; prompts and rules are separate Markdown sources. These files may be versioned, must not contain real secrets, and should identify their revisions. The active stage packet is the concise acceptance summary. Raw run evidence belongs only under the exact ignored Work path; it is not a README journal or a replacement for acceptance evidence.

Before creating run data, protect the exact path, for example:

```powershell
$projectRoot = '<target-project-root>'
$kitCoreScripts = '<installed-team-core-scripts-directory>'
& (Join-Path $kitCoreScripts 'generated-artifacts.ps1') -Action Protect -ProjectRoot $projectRoot -Profile Work -WorkPath '_work/ai-sim-example'
```

For a target project, resolve both scripts from the installed `team-core/scripts` Skill directory and pass the target project's root. `./skills/team-core/scripts` applies only when the Kit source repository itself is the project root. The helper also checks the Work boundary when initializing. Before handoff or an authorized commit, run `Protect` again and then `Check` for that same path. A tracked-file or explicit include-rule conflict requires user direction; do not untrack files automatically. If an existing local run is found after protection is missing or changed, stop and ask before modifying ignore policy or the data. Ignore policy cannot prevent manual forced staging.

## Definition contract

Start from [`templates/ai-simulation/definition.json`](../templates/ai-simulation/definition.json) in the installed `team-core` package and adapt it into the target project's workflow folder. Paths in a target definition are repository-relative. The `definition.json` is a schema-by-example contract consumed by `scripts/ai-simulation.ps1`; it is not a Codex instruction file and does not cause the host to load prompts automatically. The context-policy, rule and prompt references must be UTF-8 Markdown files (`.md`); source snapshots are bounded to 1 MiB each and 8 MiB total.

The top-level shape is:

| Property | Meaning |
| --- | --- |
| `schemaVersion` | Definition contract version; currently `1`. |
| `flowId`, `revision` | Stable flow identity and the revision under evaluation. |
| `contextPolicyPath` | Repository-relative context contract. |
| `rules` | Repository-relative governing product/business rule files. |
| `nodes` | Bounded model/agent nodes, each with prompt, context policy and allowed mock tools. |
| `cases` | Synthetic input and expected criteria held out of the actor packet. |
| `models.target` | Intended production model and provider. |
| `models.simulation` | Run-level requested actor model/effort plus `proxy` or `same-model` relationship. This describes the selected actor for this run; it does not select or override a role. |
| `budget` | Maximum recorded calls globally, per case, and maximum bytes per record. |

Nodes declare `kind` as `model` or `agent` and a `context.mode` of `stateless`, `dialogue`, `workflow-node`, or `agent`. `historyPolicy` is `none`, `recent`, `summary`, or `full`; also declare `maxHistoryTurns`, `upstreamFields`, `stateFields`, `resetBetweenCases` and `retryPolicy` (`fresh` or `same-context`). For summary mode, pass the chosen summary and no raw history; for recent/full, pass only the contracted number of turns and no duplicate summary. `none` passes neither. Stateless mode requires `historyPolicy: none`, zero history turns, and empty upstream/state/tool allowlists: send only fixed instructions and current case input. Workflow-node mode cannot retain dialogue history; it sends only named upstream fields and permitted state. Dialogue and agent modes explicitly name allowed history, state/memory fields, and tools. Reset cases as declared; never retain hidden prior case content to imitate excluded context. Use `same-context` retries only when the live native history exactly matches the declared retained context; when prior turns are excluded, create a fresh non-forked context for each call/retry rather than asking a reused thread to forget.

The Lead assembles each actor packet deliberately. In particular, expected criteria remain outside it. Each call record includes `suppliedInput` (`mode`, `instructions`, `currentInput`, `history`, `summary`, `upstream`, `state`, and `toolResults`), `stateBefore`, `stateAfter`, `observedOutput`, Lead-authored `routing`, and `actualMetadata`. The actor may return `observedOutput.status` of `completed`, `error`, or `stopped`, a JSON `response`, an optional error string (required for `error` status), and structured `mockToolRequests` (`name` and JSON-object `arguments`). The Lead controls routing and returns only defined mock results (`toolResults`, each with `name` and JSON `result`); no live tool or production side effect is implied. Include failed and stopped calls in the budget and evidence.

`context-policy.md` is the explanatory authority for assembly behavior and must name the owner that creates summaries, the triggering point, permitted source material, truncation/size limits and reset behavior. For each allowed context field, state the fallback when it is missing, malformed, oversized, stale or lost, including whether to stop, retry with a fresh context or ask for a decision. Specify how retries treat prior state and when the flow stops; a retry is a new recorded call and consumes budget. The helper checks declared field names and history bounds but cannot create or validate the semantic correctness of a summary, enforce runtime size limits before actor invocation, or determine a safe recovery path.

## Context and host boundaries

| Mode | Packet contents for the node |
| --- | --- |
| `stateless` | Node instructions and current input only; no prior history, summary, upstream fields or state. |
| `dialogue` | Instructions, current input and only the declared history policy (`none`, `recent`, `summary`, or `full`) within its cap. |
| `workflow-node` | Node instructions, current input, explicitly selected upstream fields and allowed state. |
| `agent` | Agent role/instructions, current input, explicitly retained history or state/memory fields, and the declared mock-tool interface/results. |

When a call excludes previous native turns, use a fresh, non-forked actor context for that call. A truncated-history or summary packet cannot be simulated reliably by reusing a native thread that still contains the omitted messages and asking it to forget. A fresh thread does not remove host base instructions or shared-filesystem access; Codex thread contexts are not secure or blind-test isolation. The helper records the supplied packet, not a signed receipt of everything the host supplied. It cannot prove that hidden instructions, tool availability or other host context were absent.

A definition's `requestedModel` is the run-level profile the Lead selected; it is not a runtime override. Codex custom-agent TOML `model` and `model_reasoning_effort` take precedence over spawn-time model overrides; see the [official subagent configuration guide](https://learn.chatgpt.com/docs/agent-configuration/subagents). Select a named profile first, then set the definition's requested model/effort and relationship to match that profile. Record host-confirmed actual identity separately. Source TOML is not proof that the active session loaded that model/effort.

Choose a profile for the target model family/tier and the test purpose. `team-ai-simulation-actor-basic` is the default when a meaningful distinction is absent or unclear; `team-ai-simulation-actor-advanced` is for cases that specifically call for that profile. Do not choose the stronger profile just to make a case pass. If the target requires exact identity and no available named role matches it, pause or ask the user to approve a proxy before proceeding; never silently downgrade. A proxy pass is not target-model equivalence or acceptance. To compare profiles, run separate frozen runs/definitions with the same cases and record the profile difference; do not add unsupported per-node model overrides. Do not claim exact API request/parameter reproduction, model-call cost reductions, or complete runtime fidelity.

Fresh contexts consume real subagent/thread capacity. A call budget is not a concurrency guarantee. Respect the active host limit; if the run cannot provide fresh context as specified, pause the affected case or revise the contract with the user rather than silently reusing a contaminated thread or selecting a generic agent.

## Evidence helper

Use `skills/team-core/scripts/ai-simulation.ps1` from the source repo, or its installed `team-core/scripts/` copy in a target project. It supports:

```text
-Action Validate|InitializeRun|RecordCall|Status
-ProjectRoot <root>
-DefinitionPath <repository-relative-json>
[-WorkPath _work/ai-sim-<slug>]
[-RunId <slug>]
[-CallInput <repository-relative-json>]
```

- `Validate` checks the definition, bounded identifiers, references and budget without writing. It accepts at most 100 nodes and 100 cases, 1–1,000 calls globally, 1–global calls per case, 1 KiB–1 MiB per call record, and at most 8 MiB of declared source snapshots.
- `InitializeRun` creates a new run under the selected exact Work path, captures immutable source snapshots and hashes for the definition and referenced material, and refuses to replace an existing run ID.
- `RecordCall` validates one supplied call against the frozen definition and run. It publishes a non-replaceable call record and advances a mutable terminal head under an exclusive writer lock, checking order/reference/budget/size constraints. Record failed and stopped attempts too. If a write is interrupted between record publication and head advancement, later operations stop on inconsistent evidence; they do not auto-repair, replenish budget or discard a record. Check the remaining budget before the model call; this post-call helper cannot prevent inference that already happened.
- `Status` checks the frozen sources, call records and terminal head; reports counts, remaining budget, per-case use, unknown actual-model count and source drift; and detects missing/corrupt/partial data. A healthy ledger or complete call count is not an acceptance decision.

Each call record includes run/call/case/node IDs and sequence, the supplied instructions/current input/selected history/summary/upstream/state/tool results, before/after state, observed response or mock request/error/stop, Lead-authored next-node routing and reason, and actual runtime metadata. Set actual model, effort, evidence, elapsed time, or usage to `null`/unknown when host evidence is unavailable; identity values require evidence, elapsed time must be nonnegative, and usage is an observed JSON object or `null`. Never infer zero token use, a model identity, or a complete request from source TOML. `assessmentScope` remains `prototype`; the actor cannot turn its answer into a pass.

The frozen manifest, non-replaceable call records and mutable terminal head are local integrity evidence, not cryptographic proof of what the model saw or who approved the run. A hash chain can detect some accidental changes but is not a tamper-proof signature. The strict UTF-8 JSON reader rejects duplicate/case-ambiguous keys, preserves JSON strings without date coercion, and accepts numbers only as `Int64` or exactly representable .NET `Decimal`; values outside Decimal range/scale, or requiring rounding/underflow, are rejected before writing. Numeric tokens are bounded to 128 characters and exponents to ±1,000. JSON number formatting may normalize, so the evidence preserves semantic values rather than original input bytes. Do not record hidden chain-of-thought, credentials, private user data, or unredacted production conversations. Prefer synthetic cases. Shared files prevent a guarantee that criteria are inaccessible to the actor even when they are omitted from its packet. Retain raw traces through acceptance or diagnosis, then remove only artifacts owned by this task under the agreed retention decision.

Before resuming an interrupted run, reconcile the recorded call count with reachable native actor-call history. `Status` counts only records; a call may have happened before the matching `RecordCall` was written. If any attempted call is missing or cannot be established, do not assume its budget remains unused or reset the budget; pause and present the evidence for a user decision. Never auto-repair or skip an inconsistent record/head pair. If an existing nonempty Work path is not protected, initialization pauses instead of changing ignore policy or adopting/deleting its contents; request user direction.

## Evaluation and engineering handoff

Plan case coverage, expected criteria, independent scoring, mock success/failure responses, bounded repeats, call limits, and stop rules before actor calls. Include representative happy paths, edge conditions, malformed outputs, missing context/state, tool errors, retries, handoff and termination behavior as applicable. Keep grading data outside the actor packet; describe shared-filesystem limitations when blinding cannot be enforced. Repeat model runs only when variability is relevant and the user-approved call budget supports it.

After simulation, report prototype observations separately from unresolved judgments and acceptance. Engineering production behavior is a separate user decision. Once authorized, use `$team-dev`, route AI-specific prompt/context/state/model/tool/routing behavior to `team-ai-engineer`, and use `team-ai-tester` for AI scenario coverage and independent scoring under the [AI evaluation contract](ai-evaluation.md). Retain ordinary `team-tester` coverage for helper/package behavior and distinct software assertions, plus independent `team-reviewer` review when required. Convert useful synthetic scenarios into appropriate application tests; the prototype helper is not a runtime workflow engine or production test adapter.
