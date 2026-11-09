/** Manual host observations only: an attempt never creates a worker, process or assignment. */
import { BoardError } from '../domain/errors.mjs';

/** Unknown host outcomes hold related new ownership until explicitly resolved. */
export function dispatchUnknown(tx, worker, task) {
  return (tx.board.dispatchAttempts ?? []).some(attempt => attempt.status === 'unknown' &&
    attempt.role === worker.role && (!attempt.taskId || attempt.taskId === task.id));
}

/** Keep a bounded durable attempt history; resolution updates state and appends immutable audit. */
export function recordDispatch(tx, input) {
  const observation = input.capacityObservation;
  if (typeof input.attemptId !== 'string' || !input.attemptId || typeof input.role !== 'string' ||
    !['planned', 'known', 'unknown', 'failed'].includes(input.status) || !observation ||
    ![true, false, null].includes(observation.available) ||
    !Array.isArray(observation.evidenceRefs) || !observation.evidenceRefs.length ||
    !Array.isArray(input.evidenceRefs) || !input.evidenceRefs.length) {
    throw new BoardError('INVALID_INPUT', 'An explicit bounded host observation is required.');
  }
  const attempts = tx.board.dispatchAttempts ?? [];
  const existing = attempts.find(attempt => attempt.attemptId === input.attemptId);
  if (existing && (existing.role !== input.role ||
    existing.status === 'unknown' && !['known', 'failed'].includes(input.status) ||
    ['known', 'failed'].includes(existing.status))) {
    throw new BoardError('CONFLICT', 'Resolve an unknown outcome without retrying or replacing its identity.');
  }
  if (!existing && attempts.length >= 100) {
    throw new BoardError('LIMIT_EXCEEDED', 'Dispatch attempt capacity requires explicit maintenance.');
  }
  if (!existing && input.status === 'planned' && attempts.some(attempt =>
    attempt.role === input.role && attempt.status === 'unknown')) {
    throw new BoardError('RECOVERY_REQUIRED', 'Resolve the related unknown host outcome before retrying.');
  }
  if (input.status === 'known' && (!input.hostId || !input.workerId ||
    observation.available !== true)) {
    throw new BoardError('INVALID_INPUT', 'Known dispatch requires observed real host and worker identities.');
  }
  const attempt = { attemptId: input.attemptId, role: input.role, status: input.status,
    taskId: input.taskId ?? null, hostId: input.hostId ?? null, workerId: input.workerId ?? null,
    capacityObservation: observation, evidenceRefs: input.evidenceRefs };
  tx.board.dispatchAttempts = existing ? attempts.map(item => item === existing ? attempt : item) :
    [...attempts, attempt];
  tx.audit('record-dispatch', { actorId: input.actorId, attempt });
  return { attempt };
}
