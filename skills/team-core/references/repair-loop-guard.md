# Repair and diagnosis loop guard

Use this contract whenever a Team workflow is investigating or repairing a persistent failure. It bounds ineffective repetition while allowing healthy long-running work. It is an instruction contract: it does not provide a clock, runtime counter, or guaranteed interruption. The Lead owns issue identity, budget checks, continuity across children and handoffs, and the decision to pause.

## Identify and preserve an issue

Track an issue by the **acceptance behavior, relevant conditions, and observed deviation**. A different file, proposed fix, agent, model, task label, or error wording does not create a new issue or reset its history when the original acceptance still fails. If an error message changes but the same acceptance remains unmet, retain the issue identity unless evidence shows a genuinely different behavior or condition.

When a fix is verified and a distinct regression then appears, record a linked issue; the overall task is not complete while the new regression remains. If the original failure recurs, reopen it with its prior history. When root-cause linkage is uncertain, mark issues as possibly related and preserve both records until evidence or a user decision supports merging or splitting them.

Carry the issue summary, prior attempts/rounds, outcomes, and decision history in the existing Work/Verification record, stage packet, or Debug hypothesis ledger. Reuse the relevant project record; do not create a separate diary or sensitive log store. At a handoff or resumed session, recover available history before continuing. If history is missing, do not assume a zero count: disclose the uncertainty and ask for direction when it could change whether another attempt is allowed.

## Count attempts and choose the authorized mode

One **repair attempt** is a bounded change intended to satisfy the tracked acceptance, followed by the planned verification. Count it as a failed repair only when verification is complete and the original acceptance still fails, or when the attempt introduces a regression that prevents that acceptance. A tool invocation, code edit, expected TDD Red, or still-running healthy check is not by itself a failed repair. Record verification that is incomplete, timed out, or blocked as such; do not relabel it passing or use it to erase history.

For ordinary development repairs:

- After two completed failed repairs of the same issue, perform an evidence retrospective before authorizing another attempt. Summarize what changed, what verification showed, which hypotheses were ruled out, and what genuinely new basis supports continuing. Do not simply repeat the prior approach.
- After three completed failed repairs, pause that issue and ask the user before another repair, even if the third attempt exposed a promising clue.

An explicit user request for debugging/investigation (including `$team-debug`), or the user's approval of a proposed debug mode, authorizes a bounded **diagnostic** allocation: at most six purposeful investigation rounds, with a mid-review after round three. A diagnostic round is a planned, discriminating check or controlled experiment that can support, reject, or narrow a hypothesis; repeated commands count as one round only when they are repetitions within the same predeclared experiment for the same hypothesis. Independent hypotheses/checks cannot be bundled to evade the limit, and an experiment cannot remain open after its result is available. After round six, pause for user direction if the cause is not established. Three consecutive completed diagnostic rounds that add no useful evidence and do not narrow the issue trigger an earlier pause. A genuine evidence-based narrowing resets only this consecutive-stall count; it never resets repair history or the six-round allocation. Establishing a cause ends diagnosis but does not grant unlimited repair attempts.

Do not silently convert failed development repairs into debug mode or grant six additional rounds because repair is difficult. Debug allocation authorizes investigation, not production repair. A proposed repair still needs its normal implementation authorization. If debugging and a repair are both authorized in one segment, state one bounded combined plan with explicit diagnostic and repair limits and a stop condition; do not stack independent allowances. Switching mode after earlier work requires the user decision to specify the remaining or newly approved bounded allocation. Keep all prior counts and evidence.

An explicit budget supplied by the user governs. A general request to continue, a promising clue, a new agent, or a new session does not replenish an exhausted budget. Ask for a bounded next segment with scope, strategy, allowance, and stop condition before resuming.

## Pause early for decisions and handle long operations by evidence

Ask the user before spending a numeric allowance when intent or acceptance is materially ambiguous, essential access/environment or an external decision is unavailable, a step crosses granted authority, or continuation risks data loss, unsafe effects, or material scope expansion. First perform safe checks already within the authorization; never request a secret in chat. Do not consume retries merely to reach a threshold.

There is no universal elapsed-time cutoff. For a long test, build, migration, or other expected operation, state its purpose, expected progress evidence, and suitable checkpoints in the existing Work contract or packet. At a checkpoint, inspect available status, completed work, logs, or results. If evidence shows healthy progress, report the checkpoint as needed and continue within the authorized task/budget. If health cannot be established, progress materially diverges from the plan, or the operation requires an unapproved restart/retry/termination, pause and ask. Never kill or restart an operation solely because of elapsed time when doing so could be unsafe. Healthy long tests and intentional TDD Red are not failed repairs.

## Required pause report and bounded resume

Before asking the user to decide, gather safe evidence already available and provide a concise report in the existing work record or handoff. Include:

1. **Issue and impact:** acceptance behavior, relevant conditions, reproduction, expected versus observed result, affected work, and current code/test/process state.
2. **History and trigger:** selected mode, repair-failure and diagnostic-round counts, useful-evidence/stall history, prior user budgets/decisions, why the guard or immediate decision point applies, and what remains paused.
3. **Evidence and causes:** confirmed observations and ruled-out causes with evidence; then plausible causes ranked with the mechanism by which each could produce the symptom, supporting/contrary evidence, confidence, and unknowns. Distinguish fact from hypothesis. Consider requirements/design, code/architecture, test/tool behavior, and local/external environment as relevant; do not force a root cause or present an untested guess as fact.
4. **Human input needed:** the smallest specific decision, information, environment action, or authority needed, why the Agent cannot safely/effectively determine it, and what that input would let the team check. Do not ask the user to repeat evidence the Agent can safely collect or disclose credentials.
5. **Recommendation and stop condition:** a preferred bounded next strategy plus meaningful alternatives, each with scope and expected evidence; state the proposed allowance/checkpoint and when to stop again.
6. **Preservation:** identify retained edits, test results/artifacts, and any running operation. Keep them available for review; do not automatically roll back, delete tests, weaken acceptance, or claim success.

Pause the affected diagnosis or repair until the user decides. Silence is not consent. Already-authorized, genuinely independent work may continue only if it does not depend on or extend the paused issue. On approval, resume only within the user's bounded decision, preserve prior history, and stop at its allowance or condition. These requirements make the workflow inspectable; they do not guarantee that a host runtime will interrupt a nonresponsive Agent.
