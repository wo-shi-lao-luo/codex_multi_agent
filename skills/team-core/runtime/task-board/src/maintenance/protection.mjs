/** Pure retention planning: visibility may change, but uncertain references never authorize deletion. */
import { createHash } from 'node:crypto';
import { StorageError } from '../storage/errors.mjs';

/** Hash a canonical JSON value, preserving array order and every nested semantic field. */
export function planDigest(value) {
  const canonical = (item) => {
    if (Array.isArray(item)) return item.map(canonical);
    if (item && typeof item === 'object') {
      return Object.fromEntries(Object.keys(item).sort().map((key) => [key, canonical(item[key])]));
    }
    return item;
  };
  try { return createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex'); }
  catch { throw new StorageError('INVALID_INPUT', 'Retention input must be JSON-serializable.'); }
}

/** Validate a bounded explicit set, retaining no implicit selector such as age or current visibility. */
export function explicitTaskIds(taskIds) {
  if (!Array.isArray(taskIds) || !taskIds.length || taskIds.length > 100
      || taskIds.some((id) => typeof id !== 'string' || !id)
      || new Set(taskIds).size !== taskIds.length) {
    throw new StorageError('INVALID_INPUT', 'Provide between one and 100 unique task IDs.');
  }
  return taskIds.slice().sort();
}

/** Identity fields bind a preview to one board generation and one consistent read revision. */
export function planIdentity(board) {
  return { boardId: board.boardId, generation: board.generation, expectedRevision: board.boardRevision };
}

/** Attach the unsigned plan's digest; this is a comparison token, never approval authority. */
export function signedPlan(plan) {
  return { ...plan, previewHash: planDigest(plan) };
}

/** Determine target-specific hard protections using retained facts rather than terminal-state guesses. */
function protections(snapshot, task) {
  const reasons = new Set();
  const id = task.id;
  if (task.needsReconcile || task.inputValid !== true
      || !Number.isSafeInteger(task.taskRevision) || task.taskRevision < 1
      || !Number.isSafeInteger(task.executionRevision) || task.executionRevision < 1
      || !Number.isSafeInteger(task.inputRevision) || task.inputRevision < 1) {
    reasons.add('INPUT_RECONCILIATION');
  }
  if (!['closed', 'canceled'].includes(task.state)) reasons.add('ACTIVE_STATE');
  if (snapshot.assignments.some((item) => item.taskId === id && item.active !== false)) {
    reasons.add('ACTIVE_ASSIGNMENT');
  }
  if (snapshot.reservations.some((item) => item.taskId === id && item.active !== false)) {
    reasons.add('ACTIVE_RESERVATION');
  }
  if (task.cleanupPending) reasons.add('CLEANUP_PENDING');
  if (task.questionHold) reasons.add('QUESTION_HOLD');
  for (const question of snapshot.questions.filter((item) => item.taskId === id)) {
    const answered = Number.isSafeInteger(question.answerRevision) && question.answerRevision > 0;
    if (!answered) reasons.add('PENDING_QUESTION');
    else {
      const answer = snapshot.answers.find((item) => item.questionId === question.id
        && item.answerRevision === question.answerRevision);
      if (question.appliedAnswerRevision !== question.answerRevision || !answer) {
        reasons.add('UNAPPLIED_ANSWER');
      }
      if (answer && answer.decision !== 'clarify') reasons.add('QUESTION_HOLD');
    }
  }
  if ((snapshot.board.dispatchAttempts ?? []).some((item) => item.status === 'unknown'
      && (!item.taskId || item.taskId === id))) reasons.add('UNKNOWN_DISPATCH');
  if (task.manualPending || task.manualAcceptancePending || task.userApprovalPending
      || task.pendingManualGates?.length || task.manualGates?.some((gate) => gate.satisfied !== true)) {
    reasons.add('MANUAL_GATE');
  }
  if (task.repairAttempts > 0 || task.repairHistory?.length || task.repairPending) {
    reasons.add('REPAIR_HISTORY');
  }
  if (snapshot.dependencies.some((edge) => edge.taskId === id || edge.dependsOnTaskId === id)) {
    reasons.add('DEPENDENCY_REFERENCE');
  }
  const submissionIds = new Set(snapshot.submissions.filter((item) => item.taskId === id)
    .map((item) => item.id));
  const bindingsReference = (record) => record?.inputBindings?.some(
    (binding) => binding.taskId === id,
  );
  const evidenceReference = (record) => record?.evidenceRefs?.some(
    (ref) => submissionIds.has(ref),
  );
  if (snapshot.tasks.some((other) => other.id !== id && (
    bindingsReference(other.acceptedResult) || bindingsReference({ inputBindings: other.intendedInputBindings })
      || submissionIds.has(other.acceptedResult?.submissionId) || evidenceReference(other)))
      || snapshot.submissions.some((item) => item.taskId !== id
        && (bindingsReference(item) || evidenceReference(item)))
      || snapshot.assignments.some((item) => item.taskId !== id && bindingsReference(item))) {
    reasons.add('EVIDENCE_REFERENCE');
  }
  return reasons;
}

/** Build a reversible archive plan. Lead classification can remove only UNKNOWN_REFERENCE. */
export function archivePlan(snapshot, { taskIds, action, classificationRefs = [] } = {}) {
  const ids = explicitTaskIds(taskIds);
  if (!['archive', 'unarchive'].includes(action) || !Array.isArray(classificationRefs)
      || classificationRefs.length > ids.length) {
    throw new StorageError('INVALID_INPUT', 'Archive action or classification set is invalid.');
  }
  const classifications = new Map();
  for (const item of classificationRefs) {
    if (!item || !ids.includes(item.taskId) || classifications.has(item.taskId)
        || item.decision !== 'logical-archive-safe' || !Array.isArray(item.evidenceRefs)
        || !item.evidenceRefs.length
        || item.evidenceRefs.some((ref) => typeof ref !== 'string' || !ref.trim())
        || item.observedBoardRevision !== snapshot.board.boardRevision) {
      throw new StorageError('CONFLICT', 'Classification requires current, bounded task evidence.');
    }
    classifications.set(item.taskId, item);
  }
  const eligibleTaskIds = [];
  const protectedTasks = [];
  for (const id of ids) {
    const task = snapshot.tasks.find((item) => item.id === id);
    if (!task) {
      throw new StorageError('NOT_FOUND', 'An explicitly selected task does not exist.', { taskId: id });
    }
    const reasons = protections(snapshot, task);
    // Audit/receipt and opaque source/acceptance references are not completely mapped in this format.
    if (!classifications.has(id)) reasons.add('UNKNOWN_REFERENCE');
    if (reasons.size) protectedTasks.push({ taskId: id, reasons: [...reasons].sort() });
    else eligibleTaskIds.push(id);
  }
  return signedPlan({
    ...planIdentity(snapshot.board), action, taskIds: ids,
    classificationRefs: ids.filter((id) => classifications.has(id)).map((id) => classifications.get(id)),
    eligibleTaskIds, protected: protectedTasks,
  });
}
