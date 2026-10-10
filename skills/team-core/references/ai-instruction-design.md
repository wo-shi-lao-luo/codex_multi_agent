# Application AI instruction design

Use for instructions sent to an application's model, including system/developer messages, node prompts and tool-agent policies. Codex development Skills guide the development agent; they do not automatically become target-application instructions, tools, or runtime reference access.

## Write the executable contract

For each call, specify:

- **Task:** the bounded job and what counts as completion.
- **Inputs:** names, meaning, source and handling when missing or invalid.
- **Output:** schema or format, required fields, allowed values and failure representation.
- **Method:** useful steps or decision criteria, calibrated to the task's risk and complexity.
- **Limits:** scope, prohibited actions, uncertainty behavior, length/iteration limits and stop conditions.
- **Authority and routing:** what the model may decide, what application code/user decides, available next steps, and when to hand off or refuse.

Give concrete examples when they teach a boundary, format or difficult judgment. Match their coverage to likely cases; examples are not a universal requirement for every call, and one happy-path example does not define all behavior. Prefer a few contrasting, representative examples over a large uncurated set. Keep sensitive data and hidden reasoning out of examples and logs.

## Make references available at the call

Keep one canonical source for each instruction or policy. A link in a design document or the mere presence of a file does not mean the target runtime can retrieve it. Determine whether the runtime has an explicit skill/reference discovery interface. If it does not, the engineer must assemble the needed method or bounded excerpt into the call, or use a trusted retrieval path with a defined source, selection rule and failure behavior. Do not paste every guide, all project history or irrelevant prior turns into every request.

For each reference, state **when** it is selected, **how** it is loaded or excerpted, and what happens if it is missing, stale, malformed, too large or irrelevant. Verify that the actual call path receives the intended instruction and selected reference. A development-time Codex Skill is not target-model context unless the application explicitly supplies its content.

Separate product policy from examples and task-specific data. Resolve conflicts by source authority and version in the application, not by hoping the model will choose the right duplicate. Keep current instructions concise; put conditional depth behind references when the runtime can load it reliably.

## When the application has reusable Skills or instruction modules

Use a reusable module only when multiple tasks need a stable method or conditional expertise that is clearer to discover and load than repeating it in each prompt. Define a short trigger and non-trigger boundary, required inputs, actionable method, output/failure contract, and references it depends on. Keep trusted, reviewed content at one canonical versioned source. If the target runtime supports module discovery, map concise metadata to selected content and the minimum needed references; otherwise assemble the selected method or excerpt explicitly. Do not prescribe a provider-specific file layout, require a Skill when one bounded prompt suffices, or treat optional scripts as executable without the application's permission checks.

Verify module selection with hit, miss and overlapping-trigger cases; verify required inputs, reference availability and graceful failure. A module being present in a repository does not prove the target runtime can discover or load it.

## Common failures

- Assuming a developer Skill, repository file, or Markdown link is visible to the model.
- Repeating the same policy in prompts, code, tool descriptions and copied reference fragments that drift independently.
- Saying “be accurate” without input provenance, a decision rule, uncertainty handling or required output.
- Overfitting to examples or treating one example as a complete specification.
- Stuffing all context into every call and obscuring the applicable rule.
- Defining a safe instruction while application code still trusts model output to authorize effects.

## Example

Bad: “Follow the refund policy in `docs/refunds.md`; use tools responsibly and answer JSON.” The runtime may not load that path, the policy selection is unclear, and JSON has no schema or failure mode.

Good: “Compare the supplied facts with each applicable criterion in the supplied policy excerpt. Return `{met, unmet, unknown, evidence_ids, needs_review}`; cite record IDs for each conclusion and keep unmet criteria distinct from unknown facts. If the excerpt or cited record is absent, mark the affected criterion unknown and route it for review rather than inferring an answer. The application selects the current approved policy revision, supplies only the excerpt for this request, validates the schema and routes review-required cases to a person.” This illustrates a task-specific method, not a product policy.

## Verify

Inspect the authoritative instruction source and test the assembled call input for representative normal, ambiguous, missing-reference and conflicting-data cases. Assert selected revision/provenance, required fields and safe failure behavior; compare expected and observed behavior with the existing AI evaluation contract. Do not treat prompt text inspection alone as proof of runtime availability.

## Design reading

For further context, see Anthropic's [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents) and [Equipping agents for the real world with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills). These are optional background, not runtime dependencies.
