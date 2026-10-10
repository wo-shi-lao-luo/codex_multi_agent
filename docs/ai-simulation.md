# Local AI workflow and agent simulation

This feature lets a Codex developer prototype the behavior of an AI agent or AI workflow before deciding whether to implement it in an application. The optional `$team-ai-simulate` workflow does not cover generic non-AI workflow simulation. It uses a bounded native Codex actor, locally supplied synthetic cases, explicit context packets, and mock tool requests/results. It does not execute a general workflow engine, call product APIs, reproduce a complete raw model request, or prove how a deployed runtime behaves.

The canonical safety, context and evidence rules live in the [shared AI simulation contract](../skills/team-core/references/ai-simulation.md). The optional `$team-ai-simulate` entrypoint is explicit-only. `team-ai-tester` owns simulation scenario coverage and independent scoring; it does not edit the simulation definition or use actor context to score behavior. For application implementation, use `$team-dev` and route AI-specific behavior to `team-ai-engineer` with the [ai-engineering Skill](../skills/ai-engineering/SKILL.md); route application AI behavior evaluation to `team-ai-tester` under the [AI evaluation contract](../skills/team-core/references/ai-evaluation.md). For material AI design decisions, `team-ai-architect` can make a bounded read-only proposal; `team-architect` remains responsible for overall software structure, and the Lead coordinates the shared boundary. Simulation success is not permission to implement or evidence that a target model passed.

## Typical use

1. Agree on the flow's intended behavior and the questions the prototype should answer. Identify target model versus requested simulation model and effort, then choose the named actor profile for the declared target family/tier and test purpose. `team-ai-simulation-actor-basic` is the default when a meaningful distinction is absent or unclear. Select `team-ai-simulation-actor-advanced` only when the test specifically calls for it; never choose a stronger profile just to make a case pass. If exact target identity is required but unavailable, pause or ask the user to approve a proxy. Record one requested simulation profile per run. A multi-tier comparison uses separate frozen runs/definitions with the same cases and an explicit profile difference; do not add per-node model overrides.
2. Create or reuse the target project's `docs/ai-workflows/<flow>/` convention. Adapt [`definition.json`](../skills/team-core/templates/ai-simulation/definition.json), and add the prompt and context-policy Markdown files it references. Define a small synthetic case set and observable expected criteria. Do not place criteria in the actor packet. Preserve a single source of truth if the target project already has established AI configuration locations.
3. Declare each node's context mode and exactly what it receives. Use a fresh, non-forked context when earlier turns are excluded; do not reuse old history and ask the actor to forget. Native Codex threads can still receive host-level instructions and share files, so they do not provide secure or blind isolation.
4. Bound the work before calling the actor: cases, turns/repeats, mock tool outcomes, failure/stop behavior and total calls. Check remaining host thread capacity separately; the record budget does not reserve a live thread.
5. Resolve the installed `team-core/scripts` directory from the Skill package and set the target project root; Kit maintainers may instead use the source checkout's `skills/team-core/scripts`. Use the target project for repository-relative definitions and run evidence. Protect the exact local trace folder and validate the definition:

   ```powershell
   $projectRoot = '<target-project-root>'
   $kitCoreScripts = '<installed-team-core-scripts-directory>'
   & (Join-Path $kitCoreScripts 'generated-artifacts.ps1') -Action Protect -ProjectRoot $projectRoot -Profile Work -WorkPath '_work/ai-sim-<task>'
   & (Join-Path $kitCoreScripts 'ai-simulation.ps1') -Action Validate -ProjectRoot $projectRoot -DefinitionPath 'docs/ai-workflows/<flow>/definition.json'
   ```

   The quoted placeholders must be replaced before running the commands. For a reproducible local example, first copy the `team-core/templates/ai-simulation/definition.json` resource into the target project's `docs/ai-workflows/<flow>/` folder and create the referenced prompt and context-policy Markdown files.

6. Start a unique run, assemble each actor packet manually from the declared fields, then record every attempted call—including failures and stops. The helper records evidence but does not start actors, answer mock requests, route nodes, score cases or prevent a call that has already started. Confirm actor-role/model identity from the active host when possible; otherwise record it as unknown.

   ```powershell
   & (Join-Path $kitCoreScripts 'ai-simulation.ps1') -Action InitializeRun -ProjectRoot $projectRoot -DefinitionPath 'docs/ai-workflows/<flow>/definition.json' -WorkPath '_work/ai-sim-<task>' -RunId '<run-id>'
   & (Join-Path $kitCoreScripts 'ai-simulation.ps1') -Action RecordCall -ProjectRoot $projectRoot -DefinitionPath 'docs/ai-workflows/<flow>/definition.json' -WorkPath '_work/ai-sim-<task>' -RunId '<run-id>' -CallInput '_work/ai-sim-<task>/call-input-0001.json'
   & (Join-Path $kitCoreScripts 'ai-simulation.ps1') -Action Status -ProjectRoot $projectRoot -DefinitionPath 'docs/ai-workflows/<flow>/definition.json' -WorkPath '_work/ai-sim-<task>' -RunId '<run-id>'
   ```

   The call-input file must use the helper's complete required schema. This synthetic illustration matches the starter definition after its placeholder prompt/context files exist; replace the run/case/node IDs and contents for the actual project. It shows unknown host metadata as `null` and does not represent an actual model run:

   ```json
   {
     "schemaVersion": 1,
     "runId": "example-run",
     "callId": "call-one",
     "caseId": "clear-request",
     "nodeId": "classify-request",
     "sequence": 1,
     "suppliedInput": {
       "mode": "stateless",
       "instructions": "Classify the synthetic request using the declared prompt.",
       "currentInput": { "text": "Replace with synthetic input." },
       "history": [],
       "summary": null,
       "upstream": {},
       "state": {},
       "toolResults": []
     },
     "stateBefore": {},
     "stateAfter": {},
     "observedOutput": {
       "status": "completed",
       "response": { "category": "support" },
       "mockToolRequests": [],
       "error": null
     },
     "routing": {
       "nextNodeId": null,
       "reason": "The example contains one node; scoring remains independent."
     },
     "actualMetadata": {
       "actualModel": null,
       "actualEffort": null,
       "evidence": null,
       "elapsedMs": null,
       "usage": null
     },
     "assessmentScope": "prototype"
   }
   ```

7. Have `team-ai-tester` independently compare observations with the criteria under the [AI evaluation contract](../skills/team-core/references/ai-evaluation.md). Record the concise result in `docs/verification/active/<stage>.md`; `Status: intact` means the local evidence passed integrity checks, not that the workflow passed acceptance. The Kit's simulation-helper/package tests remain ordinary `team-tester` work. At handoff or before an authorized commit, run the installed `generated-artifacts.ps1` for Work `Protect` and `Check` against the same project/path; ask the user to resolve tracked-file/include conflicts rather than changing tracking automatically.
8. Before resuming an interrupted run, reconcile recorded calls against reachable native actor-call history. `Status` counts records only; the actor might have run before a failed `RecordCall`. If an attempt is missing or uncertain, pause and get a decision rather than assuming the budget was unused or resetting it. Keep raw traces until acceptance or diagnosis is complete, then remove only task-owned temporary data under the agreed retention decision. Carry accepted synthetic cases into real implementation tests when appropriate.

Codex custom-agent TOML `model` and `model_reasoning_effort` settings take precedence over spawn-time model overrides. Therefore, the definition's `models.simulation.requestedModel` records the profile selected for the run; it does not change the actor's configured model. See the [official Codex subagent configuration guide](https://learn.chatgpt.com/docs/agent-configuration/subagents). Store requested profile separately from host-confirmed actual identity; source TOML alone is not runtime evidence.

## Context modes

- **Stateless call:** node instructions and current input only; no earlier dialogue, summary, upstream values, carried state, or mock tools. Each call needs a fresh context.
- **Multi-turn dialogue:** the call receives the explicitly declared amount of recent history or a summary. Keep the native actor thread consistent with that policy; if it contains extra excluded turns, start a fresh context and supply only the allowed packet.
- **Workflow node:** receive only selected upstream fields and allowed state. Workflow nodes do not retain dialogue history under the current helper contract.
- **Agent:** provide the agent role, declared memory/history and mock tool interface. Make tool visibility and state transfer explicit.

All modes need a case reset policy. In the versioned `context-policy.md`, name who creates summaries, when and from what approved input; define truncation and size limits and behavior for missing/malformed/oversized current input or state, a missing/lost summary, stale upstream fields, retry state, mock errors and stop/recovery conditions. If safe behavior is unclear, stop and ask rather than silently dropping required content or inventing a fallback. The helper validates field allowlists and history bounds but does not produce summaries, enforce runtime input sizes or decide semantic recovery. Exact mode field rules and call-record fields are defined in the shared contract and helper validator.

## What the evidence proves

The helper freezes declared source snapshots, bounds records and checks references and integrity. Call records are non-replaceable; a mutable terminal head detects missing, reordered or interrupted records and blocks further writes rather than automatically repairing them. A call record contains what the Lead says was supplied, what was observed, before/after state, routing basis and any host-confirmed model/effort/usage metadata. The record is not a signed receipt of the complete host prompt: hidden host-added context remains unknown. The strict JSON reader preserves strings and supported numeric values, rejects duplicate fields, and accepts numbers only as `Int64` or exact .NET `Decimal` values within its supported range/scale; it rejects unsupported precision, underflow or exponents beyond ±1,000. Formatting may normalize. Do not log chain-of-thought, credentials, private conversations, or unnecessary personal information. Usage without host telemetry is unknown, not zero.

Local simulations are behavior prototypes, not deterministic replay guarantees, API-call fidelity, secure isolation, measured token savings or production acceptance. If target-model identity matters and the active session cannot confirm the requested named role/model, do not silently substitute a different actor. Report the gap and keep the target-model check open.
