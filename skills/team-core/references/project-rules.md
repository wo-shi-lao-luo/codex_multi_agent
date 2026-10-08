# Project rules and AGENTS.md lifecycle

## Purpose and authority

Use this contract when a user asks the kit to help write, review, adopt, or maintain target-project instruction files, and during the `$team-plan`/`$team-dev` coverage checkpoints described below even when the task does not mention them. These files provide concise, durable working guidance for agents in that project. They do not replace the Codex system/developer instructions, an applicable product requirement, an architecture source, or the current task and stage evidence.

Keep responsibilities distinct:

- An applicable active PRD/specification states what the product should do.
- Architecture documentation states the durable structure and boundaries.
- `AGENTS.md` states how agents should work in the repository: where to find authoritative material, verified commands and conventions, relevant safety boundaries, and how to validate changes.
- Work records and stage packets state what this task changes and how its acceptance will be checked; they hold task-specific results and manual evidence.

Do not copy an entire PRD, architecture document, harness workflow, or test journal into `AGENTS.md`. Link to authoritative documents for detail. Keep always-loaded instructions short and broadly useful; task-specific instructions belong with the task. Never write a rule that claims the project policy can override higher-priority Codex instructions, grants new permissions, or makes an agent's own file edit evidence of user approval.

## Discovery and effective candidates

At the start of `$team-plan`/`$team-dev`, inspect the applicable instruction chain for the task's current working directory. When work first enters another relevant module, recheck the root-to-that-module chain; when relevant rules, commands, conventions, or their evidence change, reassess the affected guidance before relying on it. Keep each check bounded to the actual task/module; the helper is not recursive and this is not a background watcher or global hook. A direct instruction-file request uses the same process.

Have the Lead establish the target project, working directory, task scope, applicable project instructions, documentation conventions, and existing governance review. Use Explorer through the Lead for bounded repository facts such as entrypoints, actual modules, dependency/configuration sources, CI workflows, and commands. The Docs Maintainer does not perform duplicate broad code discovery or infer intended policy from implementation defects.

Use the read-only [candidate-discovery helper](../scripts/project-rules.ps1) to enumerate instruction-file candidates for a repository-relative working directory. Its `-ProjectRoot`, `-WorkingDirectory` (default `.`), `-FallbackNames` (default empty), and `-MaxBytes` (default `32768`) inputs select the bounded project scope; fallback names are explicit inputs and default to none. The helper reports candidate paths and metadata; it does not output instruction contents, interpret policy, draft text, or establish that the host loaded a candidate. `totalSelectedBytes` is a source-byte diagnostic against the supplied limit; the actual combined runtime limit, truncation, and loading state remain unknown unless observed. Read the actual applicable files separately. Inspect the project root through the task's working directory, including root-to-directory instructions, with `AGENTS.override.md` precedence over `AGENTS.md` and explicitly configured fallback names at each directory. Include every candidate in the helper's `dependencyPaths`, including absent and shadowed paths, when those candidates affect the review. Dependencies and hashes do not prove that a file's contents were read or that its policy is current. Do not recursively inventory unrelated descendants or read global Codex configuration as part of this helper.

Invoke the installed bundle's `team-core/scripts/project-rules.ps1` with the target repository root and a repository-relative `-WorkingDirectory`; supply fallback names only when the target project has explicitly configured them. Do not copy machine-specific installation paths into public project evidence.

The host's applicable global Codex instructions remain in force but are outside this project's generated deliverable. Do not edit them or claim that static inspection of project files proves the effective runtime instruction set. Newly created or modified files may not enter an already-running session's context; report runtime loading as unknown unless observed. Never promise a mid-session reload.

## Assess the project before drafting

For a new project, use only the confirmed purpose, approved requirements, chosen stack and verified setup/build/test sources available so far. Rules about future modules or commands must be labelled planned or deferred, not stated as existing facts. Keep the first file small and expand it when the repository gains stable conventions.

For an existing project, read the applicable current instructions and inspect the relevant codebase boundaries before suggesting changes. Preserve existing rules and their ownership. Report factual drift separately from policy conflict. A code pattern or defect is not, by itself, an approved rule. Structural changes remain subject to the Project Blueprint contract and explicit refactor approval.

Classify a proposed item as one of:

- Verified repository fact, supported by a source file, CI configuration, current command output, or inspected implementation.
- Confirmed user/project policy, supported by an explicit decision or existing authoritative policy.
- Proposal or unknown, clearly marked for user review rather than presented as current truth.

Use actual repository manifests, scripts, CI, and authoritative docs for commands. Distinguish a discovered command from one actually executed and verified. Do not run destructive, deployment, paid, migration, or production commands solely to test the instruction document.

## Evidence-based proposals, decisions, and editing boundaries

Raise a proposal only when the inspected active requirements, confirmed policy, or relevant repository facts show that current guidance is missing, incorrect, conflicting, or insufficient for work in scope. File absence, short length, age, or a helper fingerprint alone is not evidence of a gap. Keep project instruction files concise and durable: link to the PRD, architecture, test guide, or other source instead of copying it; include only material needed to guide agent work. Root rules cover the repository generally. Add nested rules only for a stable, distinct boundary in a relevant module, and preserve the applicable parent-to-child instruction chain and overrides.

For an evidenced gap, the Lead tells the user the exact root or nested path, source evidence, impact on current work, a concise suggested delta, and asks whether that rules-edit scope is approved. The path may be `AGENTS.md`, `AGENTS.override.md`, or an explicitly configured fallback instruction file. A request to assess or recommend does not authorize writing. Any write to a target instruction file, including a factual/link-only correction, requires approval for its bounded path and rules; an explicit user request to create or edit a specified instruction supplies that approval. Permission to implement ordinary code does not extend to editing target instructions. A Docs Maintainer or other child reports a finding to the Lead; only the Lead consolidates and raises the proposal, so the user receives one decision request.

Before raising a proposal again, inspect reachable prior Work/governance/project-decision evidence and its underlying relevant sources. Do not repeat an unchanged proposal the user approved, declined, or deferred unless the task scope or relevant evidence has materially changed; a recorded refusal is not permission to override it later. Record the proposal, evidence, scope, and actual user decision in the existing Work/governance/project-decision record where one exists. Do not create a separate tracker or promise cross-session suppression when no durable record exists. If scope or policy is ambiguous, show evidence, impact, options, and recommendation; ask and pause only dependent work. If the user defers or declines, preserve the accepted/current constraints and continue independent authorized work.

Editing a target instruction file cannot authorize otherwise disallowed commands, access, writes, deployment, or external actions. No generated rule can enlarge the agent's authority. The absence of a project instruction file alone does not block unrelated authorized implementation and does not require every content category. Do not create empty nested instruction files or category folders to match a template.

## Content and upkeep

Choose only sections useful for this project. A concise root file commonly covers purpose and navigation; a real repository map; authoritative requirements/architecture/test links; verified setup and test commands; stable coding, testing, comments, and safety conventions; and task workflow or completion expectations. Add module-specific rules only for meaningful boundaries. Do not require every category for every project.

Prefer short contextual links over rules to read every document before every change. Separate stable repository instructions from current task scope and results. Match the active PRD and confirmed user decisions; when implementation and documented intent disagree, do not silently treat either as a new policy.

Review applicable rules when their relevant source changes: project structure, commands or CI, approved conventions, interfaces, or a user decision. Reuse only current scoped evidence. Keep review notes, approval provenance, and detailed assessment in the existing `docs/governance/` review (or established equivalent), not in `README.md` or `AGENTS.md`. Do not create a new schema, marker, or approval token for this lifecycle. An absent, changed, shadowed, or newly relevant candidate invalidates the affected review; the Lead must reread and reassess the actual content before claiming readiness.

At handoff, report the exact target instruction files inspected or changed, relevant unknown/unread sources, verified versus proposed facts, approval scope, links and checks revalidated, and whether effective host loading was observed. The Lead owns the readiness decision. A clean discovery result or matching hash alone is not semantic approval.

## Governance evidence for instruction files

Use `team-core/scripts/documentation.ps1` `Scan`, `RecordReview`, and `Validate` under the existing [documentation-governance contract](documentation-governance.md). The inventory includes root `AGENTS.md` and root `AGENTS.override.md`; the current runtime policy is version 3 with the existing review schema. This deliberate policy change makes earlier scoped reviews stale and requires reassessment before reuse. Preserve any adopted `AdditionalPaths` configuration; do not reset or reinitialize a marker to add nested instruction files.

Nested and explicitly configured fallback candidates outside that inventory remain scoped review sources: read the actual applicable content, list relevant paths (including absent candidates) in the existing review's authored `dependencies`, and describe material findings in its report. Keep the governance document inventory classified exactly as it was actually scanned; do not claim a dependency was read merely because its path or fingerprint is recorded. Include relevant manifests, CI definitions, scripts, and other inspected sources that support factual setup or command guidance in the same existing assessment.
