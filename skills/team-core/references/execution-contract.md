# Execution contract

For bounded same-task factual/evidence communication between existing child peers, apply the Lead-granted [peer communication contract](peer-communication.md). The grant does not change the Lead's task, permission, ownership, acceptance or integration authority.

This contract gives team workflows a shared execution shape. It is a harness for producing evidence-backed engineering work, not a replacement for repository instructions or domain expertise.

Ordinary child agents share the task filesystem. When the Lead chooses separate checkouts for parallel production writers, apply the conditional [isolated worktree guidance](isolated-worktrees.md); it does not alter this lifecycle or authorize Git delivery.

## Apply the minimum complete path

Every task moves through these stages:

```text
Context → Discover → Contract → Execute → Verify → Handoff
```

For a small, clear task, the Lead may combine Context, Discover, and Contract in one short pass. It must still establish the intended outcome, relevant repository facts, acceptance checks, and verification approach before claiming completion.

## Risk-proportional light path

Choose the execution mode after a brief, bounded source or contract lookup when needed to understand the likely boundary; an unread file alone is not material uncertainty. Use the light path when the desired outcome is clear, the affected boundary is understood, changes are reversible, and available evidence supports low impact. This includes bounded low-risk application changes such as a small feature, simple wiring, or configuration relocation, as well as factual documentation, confirmed release metadata, and isolated ordinary fixes. Assess the actual behavior, dependencies, reversibility, and evidence rather than file count, module count, directory, or keywords. A light task may be completed by the Lead or one fitting named specialist; it does not require a separate Tester or Reviewer by default. An explicit user request for independent review or multiple roles, existing project obligations, and required gates still apply; invoking `$team` or `$team-dev` alone is not such a request.

Use the standard path when material risk or uncertainty remains after that lookup. Actual changes to harness policy/Skill behavior, routing or permissions, API contracts, security, persisted data/migrations, shared core, dependencies, or build/test infrastructure retain applicable standard-path roles and gates; changing a file or category name alone does not establish that such behavior changed. Judge semantics and consequential risk: formatting or relocating configuration while preserving its invariants may remain light, while real authorization, key handling, call semantics, or unknown side effects require assessment and may require the standard path. If risk emerges, upgrade only affected dependent work, preserve edits and evidence, and obtain only authority newly required by the expanded scope; role unavailability or capacity never justifies downgrading.

Before using this shortcut to propose a repair, including a first or small fix, and whenever its strategy materially changes, apply the [repair decision check](repair-loop-guard.md#repair-decision-check). This concise check does not make persistent retry thresholds apply to every small repair or require full design exploration; the guard's attempt and debug budgets remain separate.

For eligible work, the Lead or one fitting named specialist may own the implementation and scoped verification without a forced separate implementer, Tester, or Reviewer. Start with a concise outcome, necessary work, scope/risk, acceptance, and checks note; use existing records when they fit. Include only work necessary to deliver the outcome and satisfy applicable obligations. Do not silently absorb unrelated unfinished work or independent enhancements; record suggestions separately without turning them into approval questions unless they affect the accepted scope. Do not force a full document inventory or governance runtime scan, a stage-packet schema, extra process files, or the feedback runtime. Still read relevant docs, applicable PRDs and instructions; respect adopted project rules and any existing stage, spec, manual-guide or E2E artifact obligations. Standalone manual verification requested or required by the repository keeps its human guide and E2E mapping in the existing convention.

When independent work, roles, checks, or process steps accumulate, reassess whether the next action resolves a real unmet risk or provides needed evidence; omit redundant work that does neither. This does not cancel healthy long-running operations, replace a required gate, or create a universal time limit.

The light path still preserves any confirmed constraint that governs the changed boundary and records the current outcome, evidence and pending acceptance in the smallest existing task record. For factual documentation or a small fix, inspect relevant authorities and changed sources only; do not create a full source map or outcome file unless the project already uses one or cross-owner continuity needs a durable portable record. Apply [approved constraint continuity](approved-constraints.md) selectively and [outcome-based handoffs](agent-handoffs.md) without adding a second task list.

Eligible code changes still follow applicable domain Skills, code-comment and readability contracts, practical regression checks, and TDD where deterministic behavior has a practical test. Record concise TDD evidence in the existing suitable work/check record; strict deterministic behavior still needs a real pre-change Red when practical. Expand checks to broader dependencies or suites only when actual impact, uncertainty, or a repository/user gate requires them, not because of file count or role count. Browser, desktop, build, or packaging checks are required when the changed boundary or an existing gate needs that evidence, including when changed files affect packaged resources or loading paths. A Lead or writer self-check is not independent evidence, and no UI or real-boundary pass is inferred without observing it. Material work retains its packet and required independent review/evaluation gates; role count follows actual parallel need and evidence independence. Standard-path serial Lead responsibility is described below.

Delivery checks are also risk-proportional. For an authorized routine commit, push, or PR with a known, non-material outgoing scope, the Lead may perform a scoped self-check and label it non-independent; a delivery-check child is not unconditional. Use the named independent checker when the user requests independent checking or when outgoing scope is material/complex, release execution or installation-source assessment is involved, or merge/rebase risk is material. Preserve the exact requested operation, inspect relevant intermediate history as well as the final diff for leaks, establish source freshness, and keep read-only assessment separate from authority to execute Git/install actions. Reuse only reachable evidence whose inputs and scope still match; a narrow semantic/document review is not a substitute for an independent review that did not occur. Do not add a generic evidence cache or framework.

## Responsibilities and complete obligations

For noneligible code-changing `$team-dev` work, the Lead performs serial workflow responsibilities by default: own implementation, prepare the coverage/TDD plan and packet, implement, and run required checks as explicitly labeled self-check evidence. Use a separate named implementation or Tester child when parallel work has a demonstrated benefit from independent boundaries, ready inputs, reduced context-switching, or a genuine independent evidence requirement; role names describe responsibilities and do not require separate process identities. Keep test-file ownership separate from production-code ownership whenever work is delegated. Preserve every required independent gate: a Lead self-check is not independent Tester evidence, and every material implementation still receives an independent `team-reviewer` review after the writer's complete pass. `team-tester` remains the general role when independent test execution/evaluation is required; `team-ai-tester` may fill that role when application AI behavior evaluation is primary. Apply the [AI evaluation contract](ai-evaluation.md) for that specialist's scope. Follow [role routing](role-routing.md) for mixed scopes, one canonical packet owner and when distinct software-level coverage needs a second Tester. Risk, unfamiliar boundaries and materiality determine checks and evidence, not a mandatory number of roles. See the [risk-proportional light path](#risk-proportional-light-path) for its separate reduction in process obligations.

Outside the light path, task size may shorten the record and reduce the number of roles, but does not remove applicable lifecycle checks. The Lead establishes task-doc sufficiency and active PRD authority; applies Blueprint only when its contract's conditions are met; creates or reuses the required stage packet and establishes TDD/coverage decisions; checks applicable manual, E2E and other test layers; applies code-comment and relevant domain/UI requirements; verifies actual outcomes; and reports remaining gaps. These serial duties may be performed by the Lead; named roles are used for independent gates or justified parallel work. Do not require every document category or test layer when the applicable contract marks it conditional or unnecessary.

Implementation roles are not required for pure consultation, read-only investigation, planning or review workflows. Team workflows still follow this contract proportionately. A `$team-debug` investigation may use bounded diagnostic reproduction and controlled experiments under its current contract, but that does not authorize a production repair; any authorized code repair enters the `$team-dev` implementation path. Ordinary application scripts and configuration follow their domain; behavior-changing Skills, policies or agent-routing/configuration that govern the harness are implementation work, not trivial prose. Truly nonbehavior typo/format corrections may remain Lead-owned.

An explicit `$team-code-maintain` request is a bounded formatting/readability workflow, not a substitute for material code implementation. It routes to the exact `team-code-maintainer` role under the [code-readability contract](code-readability.md), using the project's formatter and proportionate scoped checks. It does not require the full `$team-dev` path for formatting-only work. When formatting is transferred from a completed code-writing task, the original writer must first freeze the assigned files; the task's existing Tester and independent Reviewer gates remain in force.

The Lead may carry out serial implementation, test-planning and verification responsibilities without a separate user-approved exception; the standard path still requires applicable packets, checks and evidence. Describe Lead-run checks as self-check and never represent them as independent role evidence. Spawn a named role only where it has a concrete independent or parallel purpose, such as a required independent reviewer/evaluator, disjoint work that can proceed concurrently, or a demonstrated context or cost benefit. A required independent gate remains independent when the Lead owns other responsibilities; if no suitable independent role is available, pause that gate and report the limitation rather than self-certifying or inventing a role.

At start, briefly record task type/risk, applicable standards, intended named roles/ownership and planned checks. At close, reconcile them with actual role-selector/handle evidence, completed checks, outcomes and gaps in the existing Work/Verification record or stage packet. These are inspectable workflow obligations, not an unbypassable runtime gate.

## Migration batches and progress

For substantial migrations that repeat changes across modules, source and tests, establish the existing source, typecheck, runtime and test baseline when relevant. Pilot one representative real module through its test and entry/load chain before batching independent modules. Preserve runtime paths and approved semantics. Diagnose shared config, type or import-root causes before treating a cascade of downstream errors as separate failures; attribute issues as pre-existing, newly introduced or unknown when evidence permits. After the pilot, group genuinely independent local batches and checkpoints. Treat test code and harness migration as implementation workload with an explicit owner and exact file scope; it is not test execution, and must not be dumped wholesale on the Tester. Route root causes to the fitting owner. This migration workflow does not apply to every small edit or require an exhaustive architecture migration.

For these migrations and other delegated work with meaningful multi-phase effort, the Lead and child maintain proportionate progress evidence in the existing Work/Verification record or packet: expected output and next checkpoint, estimate or `unknown`, then actual phase, completed delta/result, remaining work and coarse cause evidence. The child proactively reports at the first batch and when a material blocker, workload mismatch or lack of convergence appears. Exact Lead inquiry triggers and response actions are in [role routing](role-routing.md#lead-progress-inquiries). Reviews may be useful before all work finishes when their input is stable; later changes require retesting and rereview of affected scope, not automatic repetition of unaffected suites or reviews.

## 1. Context

**Input:** user request and applicable project instructions.

**Output:** a concise task record containing the intended outcome, constraints, known acceptance checks, and open questions.

**Exit:** the Lead can state what success means, or reports the missing decision that prevents safe progress.

## 2. Discover

**Input:** task record and repository.

**Output:** evidence about the relevant files, existing conventions, test or verification entrypoints, dependencies, and material risks.

**Exit:** the team has enough repository facts to choose an approach. If uncertainty remains material, assign a bounded investigation rather than treating an assumption as fact.

## 3. Contract

In `$team-plan` and `$team-dev`, apply [risk-proportional design exploration](design-exploration.md) before assigning work or implementation: decide whether a light check is sufficient or material risk/uncertainty requires fuller exploration. Use the Lead-owned context, role and return-path limits there; task size alone never decides design depth. A full exploration does not add an approval gate for already accepted decisions or replace existing approval authority.

Apply [documentation governance](documentation-governance.md). Eligible light work reads relevant docs, PRDs and instructions and rechecks evidence affected by its edits; it does not require a full inventory or governance runtime scan. Other work assesses task-specific sufficiency before implementation, adopts unchecked existing projects, classifies changed docs and rechecks stale evidence. Respect active applicable PRDs, preserve optional document categories, and ask the user before resolving substantive ambiguity. Lead owns readiness; only explicitly independent authorized work proceeds under a partial review. Carry confirmed constraints through readiness, design, child context, actual wiring/fallback, tests, review and handoff using [approved constraint continuity](approved-constraints.md); small changes and debugging still preserve applicable constraints. When a project uses source-linked Agent guidance, follow [Agent documentation](agent-documentation.md) without turning an Inspect delta into an automatic whole-project stop. Read-only consultation and review report findings; they do not update the source map or document set without a separate bounded write assignment.

At task start and when work first enters another relevant module, inspect applicable target-project instruction coverage under the [project-rules contract](project-rules.md). Reassess when relevant rule, command, convention, or source evidence changes. Surface only material, evidenced gaps affecting this task; the Lead gives the user the exact path, evidence, impact, suggested delta, and approval question, even if instructions were not mentioned. Every write to a target instruction file requires user approval for its bounded path/rules; ordinary code-work authorization is insufficient. Reuse reachable prior decisions and don't repeat an unchanged approved, declined, or deferred proposal unless the relevant evidence or scope materially changes. This is a workflow checkpoint, not a background watcher or automatic edit.

For every documentation path in the Work contract, state its content purpose/source-of-truth responsibility and allowed scope. Follow [file ownership](file-ownership.md): when authorized content edits reveal evidence-backed defects in relevant active docs, correct them within that assigned boundary and recheck affected links/indexes. Route cross-owner fixes to the Lead for a bounded assignment; do not let this become broad cleanup or rewrite history. Review the actual documentation diff for placement, factual accuracy, duplication and alignment with its assigned purpose. Read-only assessments report issues without making repairs; substantive ambiguity remains subject to the user's decision. At close, pause, transfer or redesign, reconcile the existing outcome record and evidence using [outcome-based handoffs](agent-handoffs.md); do not create a competing task list or count superseded work as completed.

When a task includes persistent diagnosis or repair, declare its mode, issue identity, existing history, allowed budget, and stop condition in the Work contract before another attempt. Apply the [repair and diagnosis loop guard](repair-loop-guard.md) across roles and handoffs; do not start another retry until its retrospective or pause gate is satisfied.

For new applications, multi-stage work or material boundary changes, apply the [Project Blueprint contract](project-blueprint.md) before the stage contract. Discover existing code before adopting a baseline. Existing-code structural refactoring requires explicit user approval; declining it preserves the baseline with recorded constraints. Map each stage to modules and file responsibilities, and review that mapping against the final diff.

For a material architecture, contract, workflow/state, configuration/eligibility, persisted-data/job, or compatibility migration, also use the conditional [architecture and contract migration guide](architecture-migration.md). Record its applicability and trace-map location in the Work/Verification record; an unchanged internal/model-only swap does not require an exhaustive migration pass.

**Input:** task record and discovery evidence.

**Output:** a work contract with:

- acceptance checks;
- affected boundary or API/data contract, if any;
- named owner for each changed area;
- verification to run after the work;
- rollout, recovery, or compatibility considerations when material.

**Exit:** each writer has bounded ownership and no two writers are assigned the same shared contract.

Apply the [default Board activation checkpoint](task-coordination.md#default-activation-checkpoint) at task start and before dependent dispatch when work expands into sustained multi-Agent collaboration. Independent ready packages may be assigned to multiple instances under the [task coordination contract](task-coordination.md); direct work without a Board follows its explicit exemptions or safe degradation path. This does not relax the single-owner rule for shared contracts or concrete paths, nor the exact-path freeze and transfer requirements.

Apply [role routing](role-routing.md) before delegation: verify needed named roles in the active tool catalog, select them explicitly, and record expected versus available profiles. Missing roles require a user decision before an alternative; task labels are not role selection.

## 4. Execute

For code changes, apply the [code comment contract](code-comments.md) and the [code-readability contract](code-readability.md) while implementing and updating affected explanations. Follow existing formatter configuration and preserve behavior during formatting-only work.

**Input:** approved work contract.

**Output:** the bounded implementation, investigation result, or review result requested by the Lead.

**Exit:** the assigned work is complete enough for independent verification. A newly discovered scope change returns to Contract; it is not silently absorbed into the current assignment.

For documentation changes, apply the assigned document purpose while editing. Inspect relevant connected documents and repair clear, evidenced defects that are within the assignment; send cross-owner or ambiguous findings back through the Contract/decision path instead of silently expanding scope.

## 5. Verify

Include the code comment and readability contracts' writer self-checks and, when review is assigned, semantic review of comments and readability. Record inspected scope and outcome; automated checks alone do not establish documentation correctness or semantic equivalence.

**Input:** completed work and the verification plan.

**Output:** actual verification evidence: commands and results, inspected behavior, or a clear account of why a planned check could not run.

**Exit:** acceptance checks have evidence, or the remaining gap is explicitly recorded as a risk for the Lead to decide.

Reconcile the invocation ledger against actual role-selector arguments, returned agent handles and available identity evidence. Disclose deviations and unknown models rather than inferring runtime identity from source configuration.

## 6. Handoff

**Input:** completed and verified bounded work.

**Output:** the shared [handoff format](handoff-format.md): Result, Evidence, Risks, and Next step. Writers add changed files and verification; reviewers rank material findings by impact. Reconcile the current outcome, retained history and next owner under [outcome-based handoffs](agent-handoffs.md), including pending manual acceptance and invalidated evidence.

**Exit:** the Lead can integrate the result, request a focused follow-up, or close the task without reconstructing the child agent's reasoning.

The Lead's final response must include the actual child-agent roster from the handoff format, including created failed/interrupted agents and retries, or explicitly state that no children were used. Separate failed creation attempts from created agents.

## Return paths

- Missing repository facts or conflicting observations → return to **Discover**.
- New compatibility, ownership, or scope concern → return to **Contract**.
- Failed or incomplete verification → return to **Execute** with the evidence.
- A decision only the user can make → hand off the decision with options and pause the affected work.
- Repeated failure or unproductive diagnosis → check the [repair and diagnosis loop guard](repair-loop-guard.md) before another attempt; pause with its evidence-led report when a limit or earlier decision gate is reached.

## Workflow adapters

Every `team-*` workflow Skill that applies this contract should state:

1. when it activates and what is out of scope;
2. which stages it owns or delegates;
3. its required evidence and handoff output;
4. which return paths apply to its task type.

Domain Skills add the standards needed inside Discover, Contract, Execute, and Verify. They do not redefine the common lifecycle.

The `$team` entry, explicitly invoked or task-matched to engineering work, selects or composes these existing adapters under [workflow routing](workflow-routing.md). Selection does not require a second user command and does not waive the selected adapter's entry conditions, stages, evidence, roles, or approvals. Do not create a new lifecycle or reset accepted decisions or task history.
