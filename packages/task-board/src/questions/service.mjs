/** Current-assignment questions, immutable answers and notification state; no host messaging is sent. */
import { randomUUID, createHash } from 'node:crypto';
import { currentExecutionEligibility, executionBinding } from '../domain/execution.mjs';
import { compositeId } from '../domain/identity.mjs';
import { BoardError } from '../domain/errors.mjs';

export const questionOperations = new Set(['ask', 'answer', 'ack-answer', 'ack-inbox']);

function requireValue(value, code, message) {
  if (!value) throw new BoardError(code, message);
}

/** Effective state is derived once for inbox, snapshot, task holds and backpressure. */
export function questionState(tx, question) {
  const assignment = tx.assignments.get(question.assignmentId);
  const task = tx.tasks.get(question.taskId);
  if (!assignment?.active || assignment.generation !== tx.board.generation ||
    !task || ['closed', 'canceled'].includes(task.state)) return 'stale';
  try { currentExecutionEligibility(tx, task, { record: question, allowApprovalHold: true }); }
  catch { return 'stale'; }
  if (!question.answerRevision) return 'pending';
  const answer = tx.answers.get(compositeId(question.id, question.answerRevision));
  if (!answer) return 'stale';
  if (answer.decision !== 'clarify') return 'approval-pending';
  return question.appliedAnswerRevision === question.answerRevision ? 'applied' : 'answered';
}

/** Nonterminal includes answered-but-unapplied and approval holds, without duplicating counters. */
export function effectivePending(tx, taskId) {
  return tx.questions.list(taskId ? { taskId } : {}).filter(question =>
    ['pending', 'answered', 'approval-pending'].includes(questionState(tx, question)) ||
    tx.tasks.get(question.taskId)?.questionHold?.questionId === question.id);
}

/** An approval decision is blocking even when the original clarification was informational. */
export function blocksExecution(tx, question) {
  return question.blocking || questionState(tx, question) === 'approval-pending' ||
    tx.tasks.get(question.taskId)?.questionHold?.questionId === question.id;
}

/** Return the explicitly persisted policy, falling back only to this feature's documented default. */
export function questionPolicy(board) {
  return { pendingThreshold: board.questionPolicy?.pendingThreshold ?? 10 };
}

/** New work pauses under unresolved decision pressure; existing owners can still report and ask. */
export function assertNoBackpressure(tx) {
  requireValue(effectivePending(tx).length < questionPolicy(tx.board).pendingThreshold,
    'QUESTION_BACKPRESSURE', 'Resolve the pending question inbox before assigning new work.');
}

/** Enforce exact current assignment identity and credential using the ordinary execution contract. */
function currentOwner(tx, input, worker, authenticate, allowSubmitted = false) {
  const assignment = tx.assignments.get(input.assignmentId);
  requireValue(worker && assignment?.active && assignment.workerId === worker.id &&
    assignment.taskId === input.taskId && assignment.generation === tx.board.generation,
    'STALE_ASSIGNMENT', 'A current matching assignment is required.');
  authenticate(input.claimToken, assignment.tokenHash);
  const task = tx.tasks.get(input.taskId);
  requireValue(['running', 'blocked'].includes(task.state) || allowSubmitted && task.state === 'submitted', 'CONFLICT',
    'Questions belong to a currently executing work package.');
  currentExecutionEligibility(tx, task, { worker,
    grant: tx.grants.get(compositeId(task.id, worker.id)), record: assignment,
    requireGrant: true, requireActive: true, allowApprovalHold: true });
  return { task, assignment };
}

/** Apply one question mutation inside the normal receipt transaction, with no external side effects. */
export function questionMutation(tx, operation, input, worker, helpers) {
  const { authenticate, provenance } = helpers;
  if (operation === 'ack-inbox') {
    requireValue(tx.board.questionNotification?.batchId === input.notificationBatchId,
      'CONFLICT', 'Notification batch changed.');
    tx.board.questionNotification.acknowledged = true;
    return { notification: notification(tx) };
  }
  if (operation === 'ask') {
    const { task, assignment } = currentOwner(tx, input, worker, authenticate);
    requireValue(task.taskRevision === input.taskRevision, 'CONFLICT', 'Task revision changed.');
    requireValue(typeof input.step === 'string' && input.step.trim() && input.step.length <= 120 &&
      typeof input.question === 'string' && input.question.trim() && input.question.length <= 1000 &&
      Array.isArray(input.checkedRefs) && input.checkedRefs.length <= 10 &&
      input.checkedRefs.every(value => typeof value === 'string' && value.length <= 280) &&
      Array.isArray(input.options ?? []) && (input.options ?? []).length <= 3 &&
      (input.options ?? []).every(value => typeof value === 'string' && value.length <= 280) &&
      typeof input.impact === 'string' && input.impact.length <= 280 &&
      (input.recommendation === undefined || typeof input.recommendation === 'string' &&
        input.recommendation.length <= 280), 'INVALID_INPUT', 'Question exceeds the compact contract.');
    const fingerprint = createHash('sha256').update(JSON.stringify([
      task.id, assignment.id, task.executionRevision, task.inputRevision,
      input.step.trim().replace(/\s+/g, ' '), input.question.trim().replace(/\s+/g, ' '),
    ])).digest('hex');
    const pending = effectivePending(tx).find(question => question.assignmentId === assignment.id);
    if (pending) {
      requireValue(pending.fingerprint === fingerprint, 'QUESTION_PENDING',
        'Resolve the current assignment question before opening another thread.');
      return { question: projectQuestion(tx, pending), deduplicated: true };
    }
    const question = { id: randomUUID(), taskId: task.id, assignmentId: assignment.id,
      workerId: worker.id, fingerprint, step: input.step, question: input.question,
      checkedRefs: input.checkedRefs, options: input.options ?? [],
      recommendation: input.recommendation ?? '', impact: input.impact,
      blocking: input.blocking === true, questionRevision: 1, answerRevision: 0,
      appliedAnswerRevision: null, ...executionBinding(tx, task), ...provenance };
    tx.questions.put(question);
    if (question.blocking) {
      task.state = 'blocked';
      task.blocker = `Question ${question.id}: ${question.step}`;
      task.taskRevision++;
      tx.tasks.put(task);
    }
    let firstHint;
    if (!tx.board.questionNotification || tx.board.questionNotification.acknowledged) {
      tx.board.questionNotification = { batchId: randomUUID(), acknowledged: false,
        firstQuestionId: question.id };
      const state = notification(tx);
      firstHint = { batchId: state.batchId, count: state.pendingCount, firstQuestionId: question.id };
    }
    tx.audit('ask', { taskId: task.id, questionId: question.id, ...provenance });
    return { question: projectQuestion(tx, question), deduplicated: false,
      ...(firstHint ? { firstHint } : {}) };
  }
  const question = tx.questions.get(input.questionId);
  requireValue(question, 'NOT_FOUND', 'Question does not exist.');
  const heldTask = tx.tasks.get(question.taskId);
  const holdsApproval = heldTask.questionHold?.questionId === question.id;
  requireValue(questionState(tx, question) !== 'stale' || operation === 'answer' && holdsApproval,
    'STALE_ASSIGNMENT',
    'Question belongs to obsolete execution inputs.');
  requireValue(question.questionRevision === input.questionRevision &&
    question.answerRevision === input.answerRevision, 'CONFLICT', 'Question or answer revision changed.');
  if (operation === 'answer') {
    const answer = input.answer;
    requireValue(answer && typeof answer.text === 'string' && answer.text.trim() &&
      answer.text.length <= 2000 && ['clarify', 'needs-approval', 'scope-change'].includes(answer.decision) &&
      Array.isArray(answer.evidenceRefs) && answer.evidenceRefs.length > 0 &&
      answer.evidenceRefs.length <= 10, 'INVALID_INPUT', 'A bounded answer with evidence is required.');
    const previous = tx.answers.get(compositeId(question.id, question.answerRevision));
    if (previous && previous.decision !== 'clarify' && answer.decision === 'clarify') {
      requireValue(Array.isArray(answer.authorizationEvidenceRefs) &&
        answer.authorizationEvidenceRefs.length > 0, 'UNAUTHORIZED',
        'Resolving an approval hold requires explicit authorization evidence.');
      if (holdsApproval) {
        if (heldTask.questionHold.requiresScopeChange || heldTask.questionHold.decision === 'scope-change') {
          requireValue(heldTask.inputRevision > (heldTask.questionHold.scopeBoundTaskInputRevision ??
            heldTask.questionHold.boundTaskInputRevision),
            'UNAUTHORIZED', 'Scope resolution requires the existing contract amendment chain.');
        }
        const authorized = tx.grants.list({ taskId: heldTask.id }).some(grant => {
          try {
            currentExecutionEligibility(tx, heldTask,
              { worker: tx.workers.get(grant.workerId), grant, requireGrant: true,
                allowApprovalHold: true });
            return true;
          } catch { return false; }
        });
        requireValue(authorized, 'UNAUTHORIZED',
          'Resolving approval requires current reconciled input, approval and an explicit grant.');
        heldTask.questionHold = null;
        heldTask.taskRevision++;
        tx.tasks.put(heldTask);
      }
    }
    question.answerRevision++;
    tx.answers.put({ id: compositeId(question.id, question.answerRevision), questionId: question.id,
      taskId: question.taskId, generation: tx.board.generation,
      resolvedHold: holdsApproval && answer.decision === 'clarify',
      answerRevision: question.answerRevision, text: answer.text, decision: answer.decision,
      evidenceRefs: answer.evidenceRefs, authorizationEvidenceRefs: answer.authorizationEvidenceRefs ?? [],
      ...executionBinding(tx, tx.tasks.get(question.taskId)), ...provenance });
    question.appliedAnswerRevision = null;
    if (answer.decision !== 'clarify') {
      const task = tx.tasks.get(question.taskId);
      // Answers can add an execution hold, but cannot perform Return/Reopen on frozen/history states.
      if (['running', 'blocked'].includes(task.state)) task.state = 'blocked';
      task.blocker = `Approval decision ${question.id} remains unresolved.`;
      task.questionHold = { questionId: question.id, answerRevision: question.answerRevision,
        decision: answer.decision,
        requiresScopeChange: task.questionHold?.requiresScopeChange === true ||
          task.questionHold?.decision === 'scope-change' || answer.decision === 'scope-change',
        scopeBoundTaskInputRevision: task.questionHold?.scopeBoundTaskInputRevision ??
          (task.questionHold?.decision === 'scope-change' ? task.questionHold.boundTaskInputRevision :
            answer.decision === 'scope-change' ? task.inputRevision : null),
        boundTaskInputRevision: task.questionHold?.decision === 'scope-change' &&
          answer.decision === 'scope-change' ? task.questionHold.boundTaskInputRevision : task.inputRevision };
      task.taskRevision++;
      tx.tasks.put(task);
    }
  } else if (operation === 'ack-answer') {
    requireValue(input.taskId === undefined || input.taskId === question.taskId,
      'QUESTION_SCOPE_MISMATCH', 'Question belongs to another task.');
    currentOwner(tx, { ...input, taskId: question.taskId }, worker, authenticate, true);
    requireValue(input.assignmentId === question.assignmentId, 'STALE_ASSIGNMENT',
      'Answer belongs to another assignment.');
    requireValue(typeof input.applied === 'boolean' && Array.isArray(input.evidenceRefs) &&
      input.evidenceRefs.length > 0 && question.answerRevision > 0,
      'INVALID_INPUT', 'Answer application requires evidence.');
    question.appliedAnswerRevision = input.applied ? question.answerRevision : null;
  }
  question.questionRevision++;
  tx.questions.put(question);
  tx.audit(operation, { taskId: question.taskId, questionId: question.id,
    answerRevision: question.answerRevision, ...provenance });
  return { question: projectQuestion(tx, question) };
}

/** Public state is derived from current ownership and input bindings, never a stale cached label. */
export function projectQuestion(tx, question) {
  return { ...question, state: questionState(tx, question),
    approvalPending: tx.tasks.get(question.taskId)?.questionHold?.questionId === question.id };
}

/** Notification counts are projections; reading them never consumes a batch or sends a message. */
export function notification(tx) {
  return { batchId: tx.board.questionNotification?.batchId ?? null,
    acknowledged: tx.board.questionNotification?.acknowledged ?? true,
    pendingCount: effectivePending(tx).length };
}
