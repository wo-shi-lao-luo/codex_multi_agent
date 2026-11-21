# Test Plan and Acceptance — <outcome or stage>

Use this authoring outline inside the repository's canonical QA document or existing stage packet. Preserve its headings, statuses, and schema. When a standard Kit packet is required and no project equivalent exists, use the [packet initializer](../../team-core/scripts/stage-verification.ps1) and fill its sections. An opted-in light task with no applicable QA artifact may use this outline directly as its sole `test-plan.md`. Keep planned scope and actual evidence in the same record.

Kit links in this template are authoring references. In the resulting project document, use valid project-relative links for sources and evidence and omit or replace the Kit links.

## Stage context and scenarios

Record the requirements source, baseline, build under test, environment, accounts or fixtures, test data, permitted effects, cleanup, scope, and assumptions. Define stable case IDs with preconditions, an observable action and result, and relevant happy, edge and failure paths. For exploratory QA, state a business goal and checkpoints and leave room for the tester to try relevant paths.

## Coverage and execution

Map each behavior to the lowest adequate automated boundary and its assertion. Assess unit, integration, contract/API, E2E, regression, manual, and risk-specific layers under the [test and acceptance contract](../../team-core/references/test-acceptance-contract.md). Use the existing TDD track for each material behavior. For each due check, identify the command or entrypoint, fixture, expected outcome, timing, and evidence. Schedule expensive flows at a usable acceptance checkpoint. For AI products, distinguish deterministic application tests, replay, AI behavior evaluation, and live integrated evidence.

| Manual case ID | Agent-first E2E path and key assertions | Other automated checks | Human checks and expected result | Actual preflight evidence or gap |
| --- | --- | --- | --- | --- |
| <ID> | <Same conditions and user-visible outcome, including planned edge cases> | <Test IDs or applicability reason> | <Starting point, numbered steps, and observable outcome> | <Build, environment, outcome, evidence or specific blocked step> |

## Human handoff and completion

Use the [Agent preflight rule](../../team-core/references/test-acceptance-contract.md#agent-preflight-before-human-validation) before handing the test to the user. For an actual browser interaction, preflight passes through the browser and checks the outcome, using a capable script or an Agent interaction. Keep distinctly human judgments explicit. Give the user practical setup, recommended steps and edge cases, the preflight result, and any blocked or manual-only check. Record human results only from the user's evidence or explicit deferral.

Check that each planned manual case has a traceable E2E case and that the planned and actual results are distinguishable. Keep one set of acceptance results. Promote reusable verification procedures to the existing test guide at handoff.
