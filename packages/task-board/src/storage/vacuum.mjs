/** Durable VACUUM attempts: start receipt-free, execute outside SQL transactions, then record outcome. */
import fs from 'node:fs';
import { randomUUID } from 'node:crypto';
import { writeMetadata } from './connection.mjs';
import {
  checkRevision, receipt, commitRecord, maintenanceTransaction,
} from './maintenance-protocol.mjs';
import {
  authorizeVacuum, previewVacuum, vacuumSpace, requireVacuumSpace, requireVacuumQuiescence,
} from './vacuum-plan.mjs';
import { artifactPath } from './physical-protocol.mjs';
import { StorageError, storageFailure } from './errors.mjs';

// A PID alone can be reused; this identifier describes this loaded process instance, not OS liveness.
const OWNER = Object.freeze({ pid: process.pid, instanceId: randomUUID() });

/** Public status describes an unresolved attempt without exposing credential or request digests. */
export function publicPending(board) {
  const pending = board.maintenance?.pendingOperation;
  return pending ? {
    operationId: pending.operationId, kind: 'vacuum', state: 'pending', outcome: 'unknown',
    startedAt: pending.startedAt, startedBoardRevision: pending.startedBoardRevision,
    startedEventSeq: pending.startedEventSeq,
    owner: { pid: pending.owner.pid, instanceId: pending.owner.instanceId },
    backupPath: pending.backupPath,
  } : null;
}

/** Check replay before old revision CAS, while always checking current session authority first. */
export function prepareVacuum(db, board, options) {
  authorizeVacuum(board, options);
  const previous = receipt(db, options, 'vacuum');
  if (previous) {
    if (previous.result?.outcome === 'unknown-abandoned') {
      throw new StorageError('OPERATION_RETIRED', 'This unknown VACUUM attempt was explicitly retired.');
    }
    return previous;
  }
  const pending = board.maintenance.pendingOperation;
  if (pending) {
    if (pending.operationId === options.request.operationId) {
      if (pending.requestHash !== options.requestHash) {
        throw new StorageError('IDEMPOTENCY_MISMATCH', 'Pending operation has another semantic payload.');
      }
      throw new StorageError('RECOVERY_REQUIRED', 'The physical operation outcome remains unknown.', {
        operationId: pending.operationId, outcome: 'unknown', receiptCommitted: false,
      });
    }
    throw new StorageError('MAINTENANCE_REQUIRED', 'Resolve the pending physical operation first.');
  }
  checkRevision(board, options);
  requireVacuumQuiescence(db, board, options);
  return undefined;
}

/** Append a durable start without creating a success receipt before any physical effect is known. */
function start(db, board, options, preview) {
  board.boardRevision += 1;
  board.eventSeq += 1;
  board.updatedAt = new Date().toISOString();
  board.maintenance.pendingOperation = {
    operationId: options.request.operationId, requestHash: options.requestHash,
    previewHash: preview.previewHash, kind: 'vacuum', state: 'pending',
    startedAt: board.updatedAt, sourceRevision: options.request.expectedBoardRevision,
    startedBoardRevision: board.boardRevision, startedEventSeq: board.eventSeq,
    owner: OWNER, backupPath: preview.plan.backupPath, backupSha256: options.expectedBackupSha256,
    windowApprovalRef: options.windowApprovalRef,
    stopEvidenceRefs: options.quiescence.evidenceRefs, policyVersion: 1,
  };
  const event = {
    type: 'vacuum-started', at: board.updatedAt,
    data: {
      ...publicPending(board), windowApprovalRef: options.windowApprovalRef,
      stopEvidenceRefs: options.quiescence.evidenceRefs, previewHash: preview.previewHash,
    },
    generation: board.generation, boardRevision: board.boardRevision, eventSeq: board.eventSeq,
  };
  writeMetadata(db, board);
  db.prepare('INSERT INTO audit_events(operation_id, type, payload) VALUES (?, ?, ?)')
    .run(options.request.operationId, event.type, JSON.stringify(event));
  db.prepare('INSERT INTO change_events(sequence, generation, type, payload) VALUES (?, ?, ?, ?)')
    .run(board.eventSeq, board.generation, event.type, JSON.stringify(event));
  return structuredClone(board.maintenance.pendingOperation);
}

/** Verify the real current database before claiming completion or clearing a pending attempt. */
function integrity(db) {
  const rows = db.prepare('PRAGMA integrity_check').all();
  if (rows.length !== 1 || Object.values(rows[0])[0] !== 'ok'
      || db.prepare('PRAGMA foreign_key_check').all().length) {
    throw new StorageError('RECOVERY_REQUIRED', 'The current database failed integrity verification.');
  }
}

/** Execute exactly one fresh attempt; unfinished attempts cannot enter this physical call again. */
export async function vacuum(db, paths, options) {
  const previous = maintenanceTransaction(db, (board) => prepareVacuum(db, board, options), false);
  if (previous) return previous;
  const backupStat = fs.statSync(artifactPath(paths, options.backupPath));
  const preview = await previewVacuum(db, paths, options);
  if (preview.previewHash !== options.previewHash) {
    throw new StorageError('CONFLICT', 'The approved VACUUM plan has changed.');
  }
  const pending = maintenanceTransaction(db, (board) => {
    const replay = prepareVacuum(db, board, options);
    if (replay) return { replay };
    const currentBackup = fs.statSync(preview.plan.backupPath);
    if (currentBackup.dev !== backupStat.dev || currentBackup.ino !== backupStat.ino
        || currentBackup.size !== backupStat.size || currentBackup.mtimeMs !== backupStat.mtimeMs) {
      throw new StorageError('CONFLICT', 'The verified recovery point changed before durable start.');
    }
    requireVacuumSpace(vacuumSpace(paths, preview.plan.backupPath));
    return start(db, board, options, preview);
  });
  if (pending.replay) return pending.replay;
  let physicalError;
  try {
    // Deliberately outside all transactions. Test children instrument the native call, not this API.
    db.exec('VACUUM');
  } catch (error) { physicalError = storageFailure(error); }
  try {
    integrity(db);
    return maintenanceTransaction(db, (board) => {
      authorizeVacuum(board, options);
      const current = board.maintenance.pendingOperation;
      if (!current || current.operationId !== pending.operationId
          || current.requestHash !== pending.requestHash || current.owner.instanceId !== OWNER.instanceId
          || board.boardRevision !== pending.startedBoardRevision) {
        throw new StorageError('RECOVERY_REQUIRED', 'VACUUM finalization no longer owns its pending start.');
      }
      board.maintenance.pendingOperation = null;
      const result = {
        outcome: physicalError ? 'failed' : 'completed',
        physicalEffect: physicalError ? 'sqlite-error-observed' : 'vacuum-returned-success',
        receiptCommitted: true, taskStateChanged: false,
        backup: { path: pending.backupPath, sha256: pending.backupSha256 },
        observations: { before: preview.observations, after: vacuumSpace(paths, pending.backupPath) },
      };
      const envelope = commitRecord(db, board, options, 'vacuum', result, {
        outcome: result.outcome, physicalEffect: result.physicalEffect, previewHash: pending.previewHash,
      });
      if (physicalError) {
        envelope.ok = false;
        envelope.error = {
          code: physicalError.code ?? 'RECOVERY_REQUIRED', message: 'SQLite reported VACUUM failure.',
        };
        db.prepare('UPDATE operation_receipts SET payload = ? WHERE id = ?')
          .run(JSON.stringify(envelope), options.request.operationId);
      }
      return envelope;
    });
  } catch {
    throw new StorageError('RECOVERY_REQUIRED', 'VACUUM final outcome could not be recorded.', {
      operationId: pending.operationId, outcome: 'unknown', receiptCommitted: false,
    });
  }
}

/** Validate explicit stopped-owner observations; references declare evidence, never automatic OS proof. */
export function prepareResolution(db, board, options) {
  authorizeVacuum(board, options);
  const previous = receipt(db, options, 'resolve-maintenance-operation');
  if (previous) return previous;
  checkRevision(board, options);
  const pending = board.maintenance.pendingOperation;
  const observed = options.processObservation;
  const refs = (value) => Array.isArray(value) && value.length
    && value.every((item) => typeof item === 'string' && item.trim());
  if (!pending || pending.operationId !== options.pendingOperationId
      || options.request.operationId === pending.operationId
      || options.decision !== 'abandon-unknown' || observed?.stopped !== true
      || observed.pid !== pending.owner.pid || observed.instanceId !== pending.owner.instanceId
      || !refs(observed.evidenceRefs) || !refs(options.integrityEvidenceRefs)) {
    throw new StorageError(
      'RECOVERY_REQUIRED', 'Resolution requires matching stopped-owner and integrity evidence.',
    );
  }
  if (pending.owner.pid === OWNER.pid && pending.owner.instanceId === OWNER.instanceId) {
    throw new StorageError(
      'MAINTENANCE_REQUIRED', 'This process instance is still present; its attempt stays pending.',
    );
  }
  integrity(db);
  return undefined;
}

/** Retire the old operation identity without asserting whether its physical VACUUM completed. */
export function resolveMaintenanceOperation(db, options) {
  return maintenanceTransaction(db, (board) => {
    const previous = prepareResolution(db, board, options);
    if (previous) return previous;
    const pending = board.maintenance.pendingOperation;
    const tombstone = {
      schemaVersion: 1, operation: 'vacuum', ok: false, boardId: board.boardId,
      generation: board.generation, boardRevision: board.boardRevision, eventSeq: board.eventSeq,
      result: { outcome: 'unknown-abandoned', physicalEffect: 'unknown', receiptCommitted: true },
    };
    db.prepare(`INSERT INTO operation_receipts(id, request_hash, generation, payload)
      VALUES (?, ?, ?, ?)`).run(
      pending.operationId, pending.requestHash, board.generation, JSON.stringify(tombstone),
    );
    board.maintenance.pendingOperation = null;
    return commitRecord(db, board, options, 'resolve-maintenance-operation', {
      pendingOperationId: pending.operationId, outcome: 'unknown-abandoned',
      physicalEffect: 'unknown', receiptCommitted: true,
    }, {
      pendingOperationId: pending.operationId, decision: 'abandon-unknown',
      processObservation: {
        pid: options.processObservation.pid, instanceId: options.processObservation.instanceId,
        stopped: true, evidenceRefs: options.processObservation.evidenceRefs,
      },
      integrityEvidenceRefs: options.integrityEvidenceRefs,
    });
  });
}
