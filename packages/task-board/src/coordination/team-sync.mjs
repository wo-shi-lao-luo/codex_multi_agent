/** Finite CLI convenience actions; storage owns their single atomic receipt and rollback. */
import { BoardError } from '../domain/errors.mjs';

const requireValue = (value, code, message) => {
  if (!value) throw new BoardError(code, message);
};

/** Derive report transport from the registered executor, never caller-declared mode. */
export function reportOperation(tx, input) {
  const worker = tx.workers.get(input.workerId);
  requireValue(worker, 'UNAUTHORIZED', 'An existing observed workerId is required.');
  if (worker.id === tx.board.leadId && worker.mode === 'lead-inline') return 'lead-inline-report';
  if (worker.mode === 'lead-proxy') return 'lead-proxy-report';
  if (worker.mode === 'lead-recorded') return 'lead-record-report';
  throw new BoardError('UNAUTHORIZED', 'Direct workers must report with their own authenticated CLI transport.');
}

/** Compose existing public operations without permitting arbitrary nested mutations. */
export function syncTask(tx, input, context, mutate) {
  requireValue(['prepare', 'assign', 'report'].includes(input.action),
    'INVALID_INPUT', 'sync-task.action must be prepare, assign or report.');
  if (input.action === 'prepare') {
    requireValue(input.contractApproved === true, 'UNAUTHORIZED', 'contractApproved:true is required.');
    const added = mutate(tx, 'add', input, context);
    return mutate(tx, 'approve', { ...input, taskId: added.task.id,
      taskRevision: added.task.taskRevision }, context);
  }
  requireValue(Number.isSafeInteger(input.taskRevision) && Number.isSafeInteger(input.approvalRevision)
    || input.action === 'report' && Number.isSafeInteger(input.taskRevision),
  'INVALID_INPUT', 'Current numeric taskRevision and assignment approvalRevision are required.');
  requireValue(typeof input.workerId === 'string' && tx.workers.get(input.workerId),
    'UNAUTHORIZED', 'An existing observed workerId is required; sync-task never registers or spawns.');
  if (input.action === 'assign') {
    // Validate CAS before granting; any subsequent failure still rolls back the whole operation.
    requireValue(tx.tasks.get(input.taskId)?.taskRevision === input.taskRevision,
      'CONFLICT', 'Task revision changed.');
    mutate(tx, 'grant', input, context);
    return mutate(tx, input.workerId === tx.board.leadId ? 'lead-inline-assign' : 'assign', input, context);
  }
  return mutate(tx, reportOperation(tx, input), { ...input,
    reportedByWorkerId: input.workerId, action: 'report' }, context);
}

/** A receipt never substitutes for current authority, allocation, source or grant checks. */
export function replaySync(tx, input, result, context, authorizeReplay) {
  if (input.action === 'prepare') {
    const task = tx.tasks.get(input.task.id);
    requireValue(task?.inputRevision === result.task.inputRevision &&
      task.approvalRevision === result.task.approvalRevision, 'CONFLICT', 'Prepared contract has changed.');
    return;
  }
  if (input.action === 'assign') {
    return authorizeReplay(tx, input.workerId === tx.board.leadId ? 'lead-inline-assign' : 'assign',
      input, result, context);
  }
  requireValue(input.action === 'report', 'INVALID_INPUT', 'Unknown sync-task action.');
  return authorizeReplay(tx, reportOperation(tx, input), { ...input,
    reportedByWorkerId: input.workerId, action: 'report' }, result, context);
}
