/** A Lead can park one task for a human step and collect its result without accepting the task. */
import { createHash } from 'node:crypto';
import { BoardError } from '../domain/errors.mjs';

const kinds = new Set(['verification', 'test', 'operation']);
export const waitingForAgentPhase = 'waiting-for-agent';
const agentOperations = new Set([
  'approve', 'grant', 'claim', 'report', 'submit', 'block', 'transfer', 'return', 'accept',
  'request-manual-acceptance',
  'record-dispatch',
]);

function requireValue(condition, code, message) {
  if (!condition) throw new BoardError(code, message);
}

function boundedText(value, limit, multiline = true) {
  const controls = multiline ? /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/ : /[\u0000-\u001f\u007f]/;
  return typeof value === 'string' && value.length <= limit && !controls.test(value) &&
    /[\p{L}\p{N}\p{P}\p{S}]/u.test(value);
}

/** Browser-bound operations share the same bounded task identity. */
export function validDashboardTaskId(id) {
  return typeof id === 'string' && id.trim().length > 0 &&
    Buffer.byteLength(id, 'utf8') <= 4096 && !/[\u0000-\u001f\u007f]/.test(id);
}

/** Keep the browser result and stored result on one bounded plain-text contract. */
export function validHumanStepResult(value) {
  return boundedText(value, 2000);
}

/** Validate and trim the checklist shared by final acceptance and intermediate human work. */
export function normalizeHumanChecklist(guide) {
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

function currentHumanStep(board, task) {
  const step = task?.humanStep;
  return step && !task.archived && task.state !== 'canceled' && step.generation === board.generation &&
    step.inputRevision === task.inputRevision && step.executionRevision === task.executionRevision
    ? step : null;
}

/** A task waiting for a human result is never ready for Agent execution. */
export function hasPendingHumanStep(board, task) {
  return currentHumanStep(board, task)?.state === 'pending';
}

/** Initial calls and historical receipts share the same Agent-side execution hold. */
export function requireHumanStepCleared(tx, operation, input) {
  if (!agentOperations.has(operation) || typeof input.taskId !== 'string' ||
    operation === 'record-dispatch' && input.status !== 'planned') {
    return;
  }
  requireValue(!hasPendingHumanStep(tx.board, tx.tasks.get(input.taskId)), 'CONFLICT',
    'Receive the pending human step result before advancing this task.');
}

function retainsOwnership(tx, task) {
  const owned = { taskId: task.id, active: true };
  return tx.assignments.list(owned).length > 0 || tx.reservations.list(owned).length > 0;
}

/** Park a task at the Lead's exact observed revision, retaining grants, assignments and resources. */
export function requestHumanStep(tx, task, input) {
  requireValue(validDashboardTaskId(task?.id), 'INVALID_INPUT',
    'This task ID cannot be used for a browser human step.');
  requireValue(tx.board.sessionProfile, 'CONFLICT', 'A human step requires a session Board.');
  requireValue(!task.archived && ['planned', 'open', 'running', 'blocked'].includes(task.state),
    'CONFLICT', 'This task cannot be parked for a human step.');
  requireValue(Number.isSafeInteger(task.inputRevision) && task.inputRevision > 0 &&
    Number.isSafeInteger(task.executionRevision) && task.executionRevision > 0,
    'DEPENDENCY_BLOCKED', 'Human steps require a known execution contract.');
  requireValue(!hasPendingHumanStep(tx.board, task), 'CONFLICT', 'A human step is already pending.');
  requireValue(kinds.has(input.kind) && boundedText(input.assignee, 160, false) &&
    boundedText(input.instruction, 2000) && boundedText(input.expected, 2000), 'INVALID_INPUT',
    'A human step requires its kind, assignee, instruction and expected observation.');
  const owned = retainsOwnership(tx, task);
  requireValue(!(owned || task.state === 'running') ||
    input.writesStopped === true && input.processStopped === true, 'RECOVERY_REQUIRED',
    'Confirm that Agent writes and related processes have stopped before parking the task.');
  const guide = normalizeHumanChecklist(input.guide);
  requireValue(input.resultPrompt === undefined || boundedText(input.resultPrompt, 500, false),
    'INVALID_INPUT', 'Result instructions must be a short line of text.');
  requireValue(input.kind !== 'verification' || guide && input.resultPrompt !== undefined, 'INVALID_INPUT',
    'Human verification requires a checklist and instructions for what to record.');

  const step = {
    state: 'pending', requestOperationId: input.operationId, generation: tx.board.generation,
    inputRevision: task.inputRevision, executionRevision: task.executionRevision, kind: input.kind,
    assignee: input.assignee.trim(), instruction: input.instruction.trim(), expected: input.expected.trim(),
    ...(guide ? { guide } : {}),
    ...(input.resultPrompt === undefined ? {} : { resultPrompt: input.resultPrompt.trim() }),
  };
  if (owned || task.state === 'running') task.state = 'blocked';
  task.humanStep = step;
  tx.audit('human-step-requested', { taskId: task.id, actorId: input.actorId,
    kind: step.kind, assignee: step.assignee, instruction: step.instruction, expected: step.expected,
    ...(guide ? { guide } : {}),
    ...(step.resultPrompt ? { resultPrompt: step.resultPrompt } : {}) });
  tx.change('human-step-requested', { taskId: task.id });
}

/** A Lead retry must still refer to its outstanding step for this material contract. */
export function replayHumanStepRequest(tx, input) {
  const task = tx.tasks.get(input.taskId);
  requireValue(hasPendingHumanStep(tx.board, task) &&
    task.humanStep.requestOperationId === input.operationId, 'CONFLICT',
    'The requested human step is no longer current.');
}

/** Record the actual result only; neither a pass nor a resumed executor is inferred. */
export function completeHumanStep(tx, input) {
  const task = tx.tasks.get(input.taskId);
  requireValue(!tx.board.recoveryRequired && task?.taskRevision === input.taskRevision &&
    hasPendingHumanStep(tx.board, task), 'CONFLICT', 'The pending human step is no longer current.');
  requireValue(validHumanStepResult(input.result), 'INVALID_INPUT', 'A human step result is required.');
  const result = input.result.trim();
  const requestOperationId = task.humanStep.requestOperationId;
  task.humanStep = { ...task.humanStep, state: 'completed', result };
  if (retainsOwnership(tx, task)) task.state = 'blocked';
  else if (task.state === 'blocked' && !task.blocker && !task.questionHold && !task.needsReconcile &&
    !task.cleanupPending && task.inputValid) {
    task.state = task.approvalRevision > 0 ? 'open' : 'planned';
  }
  if (!task.blocker && !task.questionHold && !task.needsReconcile) task.phase = waitingForAgentPhase;
  task.taskRevision++;
  tx.tasks.put(task);
  tx.audit('human-step-completed', { taskId: task.id, requestOperationId,
    source: 'local-dashboard', result });
  tx.change('human-step-completed', { taskId: task.id });
  return { requestOperationId };
}

/** Exact response-loss replay is valid only while the same observed result still applies. */
export function replayHumanStepResult(tx, input, receipt) {
  const step = currentHumanStep(tx.board, tx.tasks.get(input.taskId));
  requireValue(!tx.board.recoveryRequired && step?.state === 'completed' &&
    step.requestOperationId === receipt.requestOperationId && step.result === input.result.trim(),
    'CONFLICT', 'The human step result is no longer current.');
}

/** Expose instructions and the exact actionable task revision, without board authority metadata. */
export function humanStepView(board, task) {
  const step = currentHumanStep(board, task);
  if (!step) return null;
  const { state, kind, assignee, instruction, expected, generation, guide, resultPrompt, result } = step;
  const stepKey = createHash('sha256')
    .update(JSON.stringify([generation, task.id, step.requestOperationId])).digest('hex');
  return { state, kind, assignee, instruction, expected, generation, stepKey,
    taskRevision: task.taskRevision,
    ...(guide ? { guide } : {}),
    ...(resultPrompt ? { resultPrompt } : {}),
    ...(state === 'completed' ? { result } : {}) };
}
