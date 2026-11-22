# Test Plan and Acceptance — <outcome or stage>

Use this authoring outline inside the repository's canonical QA document or existing stage packet. Preserve its headings, statuses, and schema. When a standard Kit packet is required and no project equivalent exists, use the [packet initializer](../../team-core/scripts/stage-verification.ps1) and fill its sections. An opted-in light task with no applicable QA artifact may use this outline directly as its sole `test-plan.md`. Keep planned scope and actual evidence in the same record.

Kit links in this template are authoring references. In the resulting project document, use valid project-relative links for sources and evidence and omit or replace the Kit links.

## Stage context and scenarios

Open with a short plain-language acceptance scenario. Name who is doing what, where they start and what problem the change should solve. Say what they need to complete and what result they must be able to see or read back for that outcome to count as success. For internal work, state the operator or consumer's successful action and observable signal. Use that outcome to select the case IDs below.

Record the requirements source, baseline, build under test, environment, accounts or fixtures, test data, permitted effects, cleanup, scope, and assumptions. Define stable case IDs with preconditions, an observable action and result, and relevant happy, edge and failure paths. For exploratory QA, state a business goal and checkpoints and leave room for the tester to try relevant paths.

## Coverage and execution

Use [risk-based case derivation](../../team-core/references/test-acceptance-contract.md#derive-cases-from-the-changed-behavior) to build the mapping from changed behavior and its affected consumers. Include automated-only cases where a business rule, integration or AI behavior matters even without a matching manual step. Use the existing coverage and TDD sections when a canonical packet applies.

| Behavior and source | Case ID and conditions | Expected result and relevant side effects | Test layer, entrypoint, fixture and required capabilities | Earliest executable checkpoint, due checkpoint and evidence |
| --- | --- | --- | --- | --- |
| <Requirement, rule, state or affected consumer> | <Normal, boundary, failure or recovery case> | <Observable result and effects that must occur or be prevented> | <Lowest adequate test, test ID, command or entrypoint, and capability source> | <Required work or baseline, earliest possible, deadline, actual result or gap> |

For material checks, use the [timing backcheck](../SKILL.md#backcheck-the-document-set) against the Plan's dependency order. Separate the independently executable assertions when a case group spans stages. Link a critical feasibility probe before any decision or work relies on it, with an owner, representative input, observable result and blocked or independent work if it cannot run. A later handoff test may retest that premise.

Assess unit, integration, contract/API, E2E, regression, manual and applicable risk-specific layers. Schedule expensive flows at a usable acceptance checkpoint. For AI products, apply the [AI coverage dimensions](../../team-core/references/ai-evaluation.md#cover-affected-ai-boundaries), showing which cases exercise application code, replay, model behavior evaluation or live integration.

Track independently observable variants inside a case group. For affected user journeys, name the normal start or navigation path, the actual handoff build and fixture, and which starting states or transitions need separate results. For a goal-based walkthrough, give the first screen or context, the user's objective and outcome checkpoints, leaving the route for the tester to choose.

When the user or project specifies a path minimum, apply the [distinct E2E path rules](../../team-core/references/test-acceptance-contract.md#distinct-e2e-paths). In the existing mapping, give each required path an ID, its distinct entry/context/state or trigger, the expected outcome, and its own status and evidence.

For conversational AI cases, apply [goal-led exploratory dialogue](../../team-core/references/ai-evaluation.md#goal-led-exploratory-dialogue). State the goal, starting context, hard checks, forbidden effects and stopping point. Let the Tester choose inputs and follow-ups. Record the actual route and score against the agreed checks, attaching sanitized conversation and business evidence.

| Manual case ID | Agent-first E2E path and key assertions | Other automated checks | Human checks and expected result | Actual preflight evidence or gap |
| --- | --- | --- | --- | --- |
| <ID> | <Same conditions and user-visible outcome, including planned edge cases> | <Test IDs or applicability reason> | <Starting point, numbered steps, and observable outcome> | <Build, environment, outcome, evidence or specific blocked step> |

## Human handoff and completion

Use the [Agent preflight rule](../../team-core/references/test-acceptance-contract.md#agent-preflight-before-human-validation) before handing the test to the user. For an actual browser interaction, preflight passes through the browser and checks the outcome, using a capable script or an Agent interaction. Keep distinctly human judgments explicit. Give the user practical setup, recommended steps and edge cases, the preflight result, and any blocked or manual-only check. Record human results only from the user's evidence or explicit deferral.

Apply the [readiness check](../../team-core/references/test-acceptance-contract.md#readiness-for-human-acceptance) to the final implementation and all required cases due at this checkpoint, including automated-only cases. Give the user the completed preflight results and any unresolved gaps. Keep one set of acceptance results. Promote reusable verification procedures to the existing test guide at handoff.
