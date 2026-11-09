/** Current-format retention: reversible task visibility and disposable transport-prefix deletion. */
import { timingSafeEqual } from 'node:crypto';
import { archivePlan, explicitTaskIds, planDigest, planIdentity, signedPlan }
  from '../maintenance/protection.mjs';
import { StorageError } from './errors.mjs';
import { SCHEMA_VERSION } from './schema.mjs';

/** Require the current format even when called through an already-open connection. */
function currentFormat(board) {
  if (board.schemaVersion !== SCHEMA_VERSION) {
    throw new StorageError('UNSUPPORTED_SCHEMA', 'Retention operations require the current schema.');
  }
}

/** Materialize the bounded protection facts inside the caller's existing transaction. */
function protectionSnapshot(tx) {
  return {
    board: tx.board, tasks: tx.tasks.list(), assignments: tx.assignments.list(),
    reservations: tx.reservations.list(), questions: tx.questions.list(), answers: tx.answers.list(),
    dependencies: tx.dependencies.list(), submissions: tx.submissions.list(),
  };
}

/** Preview visibility changes without writing a plan registry or changing task facts. */
export function previewArchive(tx, options) {
  currentFormat(tx.board);
  return archivePlan(protectionSnapshot(tx), options);
}

/** Preview an exact transport prefix; task deletion remains explicitly unsupported. */
export function previewPrune(db, tx, options = {}) {
  currentFormat(tx.board);
  if (options.target === 'tasks') {
    return signedPlan({
      ...planIdentity(tx.board), target: 'tasks', supported: false,
      protected: explicitTaskIds(options.taskIds).map((taskId) => ({
        taskId, reasons: ['TASK_PHYSICAL_PRUNE_UNSUPPORTED'],
      })),
    });
  }
  const { throughEventSeq, retentionApprovalRef } = options;
  if (options.target !== 'change-events' || !Number.isSafeInteger(throughEventSeq)
      || throughEventSeq < 0 || throughEventSeq > tx.board.eventSeq
      || typeof retentionApprovalRef !== 'string' || !retentionApprovalRef.trim()) {
    throw new StorageError('INVALID_INPUT', 'Prune requires an exact approved transport-event prefix.');
  }
  const rows = db.prepare(`SELECT sequence FROM change_events
    WHERE sequence <= ? ORDER BY sequence LIMIT 10001`).all(throughEventSeq);
  if (rows.length > 10000) {
    throw new StorageError('LIMIT_EXCEEDED', 'Select a smaller event prefix for this prune batch.');
  }
  return signedPlan({
    ...planIdentity(tx.board), target: 'change-events', throughEventSeq, retentionApprovalRef,
    eventSeqs: rows.map((row) => row.sequence),
    newReplayFloor: Math.max(tx.board.replayFloor, throughEventSeq),
  });
}

/** Authenticate before fresh mutation or receipt replay; preview hashes never grant authority. */
function authorize(board, options) {
  currentFormat(board);
  const actual = typeof options.leadTokenHash === 'string'
    ? Buffer.from(options.leadTokenHash) : Buffer.alloc(0);
  const expected = Buffer.from(board.leadTokenHash);
  if (options.leadId !== board.leadId || options.request?.actorId !== board.leadId
      || actual.length !== expected.length || !timingSafeEqual(actual, expected)) {
    throw new StorageError('UNAUTHORIZED', 'Current coordinator authorization is required.');
  }
}

/** Validate the entire submitted semantic payload, excluding only its top-level requestHash. */
function operationOptions(options) {
  if (!options || typeof options !== 'object' || Array.isArray(options)) {
    throw new StorageError('INVALID_INPUT', 'Retention options must be an object.');
  }
  const { requestHash, ...semantic } = options;
  if (requestHash !== planDigest(semantic) || typeof options.approvalRef !== 'string'
      || !options.approvalRef.trim() || typeof options.previewHash !== 'string'
      || !Number.isSafeInteger(options.request?.expectedBoardRevision)
      || options.request.expectedBoardRevision < 0) {
    throw new StorageError(
      'INVALID_INPUT', 'Retention requires a complete digest, approval, preview and revision.',
    );
  }
}

/** Bind replay to the same method and current Lead, without rechecking the original mutated revision. */
function transactionOptions(options, operation) {
  operationOptions(options);
  return {
    request: options.request, requestHash: options.requestHash, operation,
    authorizeReplay(tx, envelope) {
      authorize(tx.board, options);
      if (envelope.operation !== operation) {
        throw new StorageError('IDEMPOTENCY_MISMATCH', 'Operation identity belongs to another method.');
      }
    },
  };
}

/** Recalculate the approved plan under the same write lock as every state/receipt/event mutation. */
function approvePlan(board, options, plan) {
  authorize(board, options);
  if (options.request.expectedBoardRevision !== board.boardRevision
      || options.previewHash !== plan.previewHash) {
    throw new StorageError('CONFLICT', 'The preview or board revision changed; obtain a fresh plan.');
  }
}

/** Apply visibility only. All selected tasks must be eligible, so a bulk archive is all-or-nothing. */
export function archive(board, options) {
  return board.transactOperation(transactionOptions(options, 'archive'), (tx) => {
    authorize(tx.board, options);
    const plan = previewArchive(tx, options);
    approvePlan(tx.board, options, plan);
    if (plan.protected.length) {
      throw new StorageError('PROTECTED', 'Selected tasks retain protected references or work.', {
        protected: plan.protected,
      });
    }
    for (const taskId of plan.taskIds) {
      const task = tx.tasks.get(taskId);
      tx.tasks.put({ ...task, archived: plan.action === 'archive', taskRevision: task.taskRevision + 1 });
      tx.audit('archive', {
        taskId, action: plan.action, actorId: options.leadId,
        previewHash: plan.previewHash, approvalRef: options.approvalRef,
        classificationRefs: plan.classificationRefs.filter((item) => item.taskId === taskId),
      });
    }
    return { action: plan.action, taskIds: plan.taskIds, previewHash: plan.previewHash };
  });
}

/** Delete transport events only; business rows, required audit history and receipts remain untouched. */
export function applyPrune(db, board, options) {
  return board.transactOperation(transactionOptions(options, 'apply-prune'), (tx) => {
    authorize(tx.board, options);
    if (options.target === 'tasks') {
      throw new StorageError('UNSUPPORTED_OPERATION', 'Physical task deletion is unsupported.');
    }
    const plan = previewPrune(db, tx, options);
    approvePlan(tx.board, options, plan);
    const result = db.prepare('DELETE FROM change_events WHERE sequence <= ?').run(plan.throughEventSeq);
    if (result.changes !== plan.eventSeqs.length) {
      throw new StorageError('CONFLICT', 'Transport prefix changed while applying the plan.');
    }
    tx.board.replayFloor = plan.newReplayFloor;
    tx.audit('apply-prune', {
      actorId: options.leadId, throughEventSeq: plan.throughEventSeq,
      previewHash: plan.previewHash, approvalRef: options.approvalRef,
      retentionApprovalRef: plan.retentionApprovalRef, deletedCount: plan.eventSeqs.length,
    });
    return {
      deletedEventSeqs: plan.eventSeqs, newReplayFloor: plan.newReplayFloor, previewHash: plan.previewHash,
    };
  });
}
