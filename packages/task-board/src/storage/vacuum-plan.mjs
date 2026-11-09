/** Privileged VACUUM preflight: stable approval plan is separate from changing filesystem observations. */
import fs from 'node:fs';
import { planDigest } from '../maintenance/protection.mjs';
import { authorize, checkRevision, requireQuiescence, maintenanceTransaction, availableBytes }
  from './maintenance-protocol.mjs';
import { artifactPath, inspectArtifact, verifyDigest } from './physical-protocol.mjs';
import { inspectBackup } from './inspection.mjs';
import { StorageError } from './errors.mjs';
import { repositories } from './repositories.mjs';
import { SCHEMA_VERSION } from './schema.mjs';

/** Hash all semantic options, omitting only the top-level supplied request digest. */
export function vacuumDigest(options) {
  const { requestHash, ...semantic } = options;
  return planDigest(semantic);
}

/** Current session supplies authority; neither a backup nor a public status grants permission. */
export function authorizeVacuum(board, options) {
  authorize(board, options, true, vacuumDigest);
  if (board.schemaVersion !== SCHEMA_VERSION) {
    throw new StorageError('UNSUPPORTED_SCHEMA', 'VACUUM requires the current schema.');
  }
  if (options.request.generation !== board.generation) {
    throw new StorageError('STALE_GENERATION', 'The maintenance generation has changed.');
  }
}

/** Unknown holder flags, cleanup obligations and unknown dispatch outcomes cannot establish idle state. */
export function requireVacuumQuiescence(db, board, options) {
  requireQuiescence(db, options);
  const repos = repositories(db);
  if (repos.assignments.list().some((item) => item.active !== false)
      || repos.reservations.list().some((item) => item.active !== false)
      || repos.tasks.list().some((item) => item.cleanupPending)
      || (board.dispatchAttempts ?? []).some((item) => item.status === 'unknown')) {
    throw new StorageError('MAINTENANCE_REQUIRED', 'Business holder or cleanup state is not confirmed idle.');
  }
}

/** Observe actual free space; size/time observations do not participate in the approved plan digest. */
export function vacuumSpace(paths, backupPath) {
  const databaseBytes = fs.statSync(paths.file).size;
  const walBytes = fs.existsSync(`${paths.file}-wal`) ? fs.statSync(`${paths.file}-wal`).size : 0;
  const backupBytes = fs.statSync(backupPath).size;
  const reserveBytes = 1024 * 1024;
  const requiredBytes = 2 * databaseBytes + backupBytes + walBytes + reserveBytes;
  const freeBytes = availableBytes(paths.directory);
  const spaceSufficient = Number.isSafeInteger(requiredBytes)
    && freeBytes !== 'unknown' && freeBytes >= requiredBytes;
  return {
    databaseBytes, walBytes, backupBytes, reserveBytes, requiredBytes, freeBytes,
    observedAt: new Date().toISOString(), spaceSufficient,
    blockedReasons: spaceSufficient ? [] : ['SPACE_UNAVAILABLE_OR_INSUFFICIENT'],
  };
}

/** Fail before durable start when a fresh space observation cannot support the approved operation. */
export function requireVacuumSpace(observation) {
  if (!observation.spaceSufficient) {
    throw new StorageError(
      'MAINTENANCE_REQUIRED', 'VACUUM space is insufficient or unavailable.', observation,
    );
  }
}

/** Prepare one privileged read-only plan, validating the closed source through private scratch only. */
export async function previewVacuum(db, paths, options) {
  const board = maintenanceTransaction(db, (current) => {
    authorizeVacuum(current, options);
    checkRevision(current, options);
    if (current.maintenance.pendingOperation) {
      throw new StorageError('MAINTENANCE_REQUIRED', 'Resolve the pending physical operation first.');
    }
    requireVacuumQuiescence(db, current, options);
    return current;
  }, false);
  if (options.policyVersion !== 1 || typeof options.windowApprovalRef !== 'string'
      || !options.windowApprovalRef.trim()) {
    throw new StorageError('INVALID_INPUT', 'VACUUM requires policy version 1 and an approved window.');
  }
  const backupPath = artifactPath(paths, options.backupPath);
  inspectArtifact(backupPath, true);
  await verifyDigest(backupPath, options.expectedBackupSha256);
  await inspectBackup(backupPath, paths.projectRoot, (copy, backup) => {
    if (backup.schemaVersion !== SCHEMA_VERSION || backup.boardId !== board.boardId
        || backup.generation !== board.generation || backup.boardRevision !== board.boardRevision
        || backup.eventSeq !== board.eventSeq || backup.leadId !== board.leadId
        || backup.leadTokenHash !== board.leadTokenHash
        || backup.maintenance?.id !== board.maintenance.id
        || backup.maintenance?.tokenHash !== board.maintenance.tokenHash) {
      throw new StorageError('CONFLICT', 'Recovery point does not match the authorized maintenance state.');
    }
  }, { currentOnly: true });
  await verifyDigest(backupPath, options.expectedBackupSha256);
  maintenanceTransaction(db, (current) => {
    authorizeVacuum(current, options);
    checkRevision(current, options);
    requireVacuumQuiescence(db, current, options);
    if (current.maintenance.pendingOperation) {
      throw new StorageError('MAINTENANCE_REQUIRED', 'A physical operation became pending.');
    }
  }, false);
  const plan = {
    policyVersion: 1, boardId: board.boardId, generation: board.generation,
    expectedRevision: board.boardRevision, maintenanceId: board.maintenance.id,
    backupPath, expectedBackupSha256: options.expectedBackupSha256,
    windowApprovalRef: options.windowApprovalRef,
    quiescence: {
      writersStopped: true, servicesStopped: true,
      evidenceRefs: options.quiescence.evidenceRefs,
    },
  };
  return { plan, previewHash: planDigest(plan), observations: vacuumSpace(paths, backupPath) };
}
