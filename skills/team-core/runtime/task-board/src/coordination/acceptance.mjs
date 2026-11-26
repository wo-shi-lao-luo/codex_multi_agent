/** Acceptance rules shared by the Lead CLI and the narrow local human confirmation flow. */
import { BoardError } from '../domain/errors.mjs';
import { currentExecutionEligibility, executionBinding } from '../domain/execution.mjs';
import { consumableResult, dependenciesReady } from '../domain/graph.mjs';
import { requireIndependentChecks } from './execution-evidence.mjs';

export const legacyManualAcceptancePhase = 'awaiting-manual-acceptance';

/** Keep the Lead preparation and bounded HTTP request on the same task ID contract. */
export function validManualConfirmationTaskId(id) {
  return typeof id === 'string' && id.trim().length > 0 &&
    Buffer.byteLength(id, 'utf8') <= 4096 && !/[\u0000-\u001f\u007f]/.test(id);
}

function requireValue(condition, code, message) {
  if (!condition) throw new BoardError(code, message);
}

/** Resolve the actual freeze and current technical gates before preparing or accepting an outcome. */
export function acceptanceEvidence(tx, task, input) {
  requireValue(Number.isSafeInteger(task.executionRevision) && task.executionRevision > 0,
    'DEPENDENCY_BLOCKED', 'Unknown execution format requires explicit reconciliation.');
  requireValue(consumableResult(tx, task), 'QUESTION_PENDING',
    'Resolve the approval obligations of this result and its consumed inputs before accepting.');
  requireValue(task.state === 'submitted' && input.gatesSatisfied === true &&
    input.evidenceRefs?.length && task.inputValid && !task.needsReconcile &&
    dependenciesReady(tx, task), 'CONFLICT',
    'Acceptance requires current submitted evidence and satisfied gates.');
  const submission = tx.submissions.list({ taskId: task.id }).find(item =>
    item.freezeValid && item.freezeRevision === task.freezeRevision);
  requireValue(submission, 'DEPENDENCY_BLOCKED', 'Current immutable frozen evidence is required.');
  currentExecutionEligibility(tx, task, { record: submission });
  return { submission, checkBindings: requireIndependentChecks(tx, task, submission,
    input.checkResults) };
}

/** Record the accepted result in the current transaction, preserving its originating submitter. */
export function recordAcceptance(tx, task, input, validated, confirmation) {
  const { submission, checkBindings } = validated;
  task.state = 'closed';
  task.resultRevision++;
  task.resultValid = true;
  task.acceptanceEvidence = input.evidenceRefs;
  task.acceptedResult = { resultRevision: task.resultRevision, submissionId: submission.id,
    checkBindings, ...executionBinding(tx, task), ...(confirmation ? { confirmation } : {}) };
  tx.audit('accepted-result', { taskId: task.id, inputRevision: task.inputRevision,
    resultRevision: task.resultRevision, evidenceRefs: input.evidenceRefs,
    acceptedResult: task.acceptedResult });
}

function requireManualCandidate(tx, task) {
  requireValue(!tx.board.maintenance?.active && !tx.board.recoveryRequired, 'CONFLICT',
    'Board maintenance or recovery is active.');
  requireValue(task && task.state === 'submitted' && !task.archived, 'CONFLICT',
    'Human confirmation requires a current submitted task.');
}

/** Store a short, human-readable checklist beside the exact prepared result. */
function normalizeManualGuide(guide) {
  if (guide === undefined) return undefined;
  const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
  const validText = (value, limit) => typeof value === 'string' && value.trim().length > 0 &&
    value.length <= limit && !/[\u0000-\u001f\u007f]/.test(value);
  requireValue(object(guide) && Object.keys(guide).every(key => ['setup', 'steps'].includes(key)) &&
    Array.isArray(guide.steps) && guide.steps.length > 0 && guide.steps.length <= 8 &&
    (guide.setup === undefined || validText(guide.setup, 500)),
  'INVALID_INPUT', 'Manual guide requires one to eight steps and optional setup text.');
  for (const step of guide.steps) {
    requireValue(object(step) && Object.keys(step).length === 2 &&
      validText(step.action, 300) && validText(step.expected, 300),
    'INVALID_INPUT', 'Each manual step requires a short action and expected result.');
  }
  return {
    ...(guide.setup === undefined ? {} : { setup: guide.setup.trim() }),
    steps: guide.steps.map(step => ({ action: step.action.trim(), expected: step.expected.trim() })),
  };
}

/** The authenticated Lead reserves the human gate for this precise submitted result. */
export function requestManualAcceptance(tx, task, input) {
  requireValue(validManualConfirmationTaskId(task?.id), 'INVALID_INPUT',
    'This task ID cannot be used for browser confirmation.');
  requireManualCandidate(tx, task);
  requireValue(Array.isArray(input.evidenceRefs) && input.evidenceRefs.length > 0 &&
    input.evidenceRefs.every(ref => typeof ref === 'string' && ref.trim()), 'INVALID_INPUT',
    'Human confirmation requires explicit acceptance evidence references.');
  const validated = acceptanceEvidence(tx, task, { ...input, gatesSatisfied: true });
  requireValue(tx.board.sessionProfile, 'CONFLICT', 'Human confirmation requires a session Board.');
  const guide = normalizeManualGuide(input.guide);
  const checkResults = (input.checkResults ?? []).map(({ checkId, taskId, submissionId }) =>
    ({ checkId, taskId, submissionId }));
  task.manualAcceptance = {
    operationId: input.operationId, generation: tx.board.generation,
    submissionId: validated.submission.id, evidenceRefs: input.evidenceRefs, checkResults,
    ...(guide ? { guide } : {}),
  };
  tx.audit('manual-acceptance-requested', { taskId: task.id, actorId: input.actorId,
    submissionId: validated.submission.id });
  tx.change('manual-acceptance-requested', { taskId: task.id });
}

/** Revalidate the persisted Lead authorization and its exact current result. */
export function preparedManualAcceptance(tx, task) {
  requireManualCandidate(tx, task);
  const request = task.manualAcceptance;
  requireValue(request && request.generation === tx.board.generation, 'CONFLICT',
    'No manual confirmation is prepared for this Board generation.');
  const input = { evidenceRefs: request.evidenceRefs, checkResults: request.checkResults,
    gatesSatisfied: true };
  const validated = acceptanceEvidence(tx, task, input);
  requireValue(request.submissionId === validated.submission.id, 'CONFLICT',
    'The prepared submission was superseded.');
  return { input, validated };
}

/** The browser gets one operation scoped to a prepared result and no Lead credentials. */
export function confirmManualAcceptance(tx, input) {
  const task = tx.tasks.get(input.taskId);
  requireValue(task?.taskRevision === input.taskRevision, 'CONFLICT', 'Task revision changed.');
  const { input: acceptance, validated } = preparedManualAcceptance(tx, task);
  // A successful user decision records acceptance. It does not imply stopped resource holders.
  recordAcceptance(tx, task, acceptance, validated, { source: 'local-dashboard',
    requestOperationId: task.manualAcceptance.operationId });
  task.taskRevision++;
  tx.tasks.put(task);
  tx.change('manual-confirmation', { taskId: task.id });
  return { resultRevision: task.resultRevision, submissionId: validated.submission.id };
}

/** An exact HTTP retry succeeds only while that same confirmed result is still current. */
export function replayManualAcceptance(tx, input, result) {
  const task = tx.tasks.get(input.taskId);
  requireValue(!tx.board.recoveryRequired && task?.state === 'closed' && !task.archived &&
    task.resultRevision === result.resultRevision &&
    task.acceptedResult?.submissionId === result.submissionId &&
    task.acceptedResult.confirmation?.source === 'local-dashboard' && consumableResult(tx, task),
    'CONFLICT', 'The confirmed result is no longer current.');
}

/** Show legacy requests for manual work as waiting without giving them acceptance authority. */
export function manualConfirmationView(tx, task) {
  if (task.archived || task.state === 'closed' || task.state === 'canceled') return null;
  if (task.state === 'submitted' && task.manualAcceptance) {
    try {
      preparedManualAcceptance(tx, task);
      const guide = normalizeManualGuide(task.manualAcceptance.guide);
      return { state: 'ready', taskRevision: task.taskRevision, generation: tx.board.generation,
        ...(guide ? { guide } : {}) };
    } catch (error) {
      if (!(error instanceof BoardError)) throw error;
      return { state: 'waiting-for-submission' };
    }
  }
  return task.phase === legacyManualAcceptancePhase ? { state: 'waiting-for-submission' } : null;
}
