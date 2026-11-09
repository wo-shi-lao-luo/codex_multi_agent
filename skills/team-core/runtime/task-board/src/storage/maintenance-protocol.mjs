/** Maintenance identity, authorization and durable receipts; no raw caller credentials are persisted. */
import fs from 'node:fs';
import path from 'node:path';
import { createHash, timingSafeEqual } from 'node:crypto';
import { readMetadata, writeMetadata } from './connection.mjs';
import { repositories } from './repositories.mjs';
import { inspectPath } from './paths.mjs';
import { StorageError, storageFailure } from './errors.mjs';

/** Canonical maintenance digest covers every semantic option; arrays retain caller ordering. */
export function semanticDigest(options) {
  const canonical = (value) => {
    if (Array.isArray(value)) return value.map(canonical);
    if (value && typeof value === 'object') {
      return Object.fromEntries(Object.keys(value).sort().filter((key) => key !== 'requestHash')
        .map((key) => [key, canonical(value[key])]));
    }
    return value;
  };
  try {
    return createHash('sha256').update(JSON.stringify(canonical(options))).digest('hex');
  } catch {
    throw new StorageError('INVALID_INPUT', 'Maintenance options must be JSON-serializable.');
  }
}

const matches = (left, right) => {
  if (typeof left !== 'string' || typeof right !== 'string') return false;
  const leftBytes = Buffer.from(left);
  const rightBytes = Buffer.from(right);
  return leftBytes.length === rightBytes.length && timingSafeEqual(leftBytes, rightBytes);
};

/** Authenticate current Lead and active session before exposing any persisted success receipt. */
export function authorize(board, options, requireSession = true, digest = semanticDigest) {
  if (!options || typeof options !== 'object' || Array.isArray(options)) {
    throw new StorageError('INVALID_INPUT', 'Maintenance options must be an object.');
  }
  if (board.leadId !== options.leadId || options.request?.actorId !== board.leadId
      || !matches(board.leadTokenHash, options.leadTokenHash)) {
    throw new StorageError('UNAUTHORIZED', 'Current coordinator authorization is required.');
  }
  if (requireSession && (!board.maintenance?.active
      || board.maintenance.id !== options.maintenanceId
      || !matches(board.maintenance.tokenHash, options.maintenanceTokenHash))) {
    throw new StorageError('UNAUTHORIZED', 'The active maintenance session credential is required.');
  }
  if (!options.request?.operationId || typeof options.request.operationId !== 'string'
      || !Number.isSafeInteger(options.request.expectedBoardRevision)
      || options.request.expectedBoardRevision < 0
      || typeof options.request.generation !== 'string'
      || !/^[a-f0-9]{64}$/i.test(options.maintenanceTokenHash ?? '')
      || typeof options.maintenanceId !== 'string' || !options.maintenanceId) {
    throw new StorageError('INVALID_INPUT', 'Maintenance identity, session and revision are required.');
  }
  if (options.requestHash !== digest(options)) {
    throw new StorageError('INVALID_INPUT', 'Maintenance hash does not cover the complete options.');
  }
}

/** Verify non-replay CAS. Migration replay alone may refer to the generation it replaced. */
export function checkRevision(board, options) {
  if (options.request.generation !== board.generation) {
    throw new StorageError('STALE_GENERATION', 'The board generation has changed.');
  }
  if (options.request.expectedBoardRevision !== board.boardRevision) {
    throw new StorageError('CONFLICT', 'The board revision has changed.');
  }
}

/** Require explicit external stop evidence and zero durable business holders; never infer process exit. */
export function requireQuiescence(db, options) {
  const evidence = options.quiescence;
  if (evidence?.writersStopped !== true || evidence.servicesStopped !== true
      || !Array.isArray(evidence.evidenceRefs) || !evidence.evidenceRefs.length
      || evidence.evidenceRefs.some((value) => typeof value !== 'string' || !value.trim())) {
    throw new StorageError('MAINTENANCE_REQUIRED', 'Stopped writers and services require evidence.');
  }
  const repos = repositories(db);
  if (repos.assignments.list({ active: true }).length || repos.reservations.list({ active: true }).length) {
    throw new StorageError(
      'MAINTENANCE_REQUIRED', 'Active assignments or reservations require safe handoff.',
    );
  }
  // Boolean inconsistencies or unknown holder state must not turn into permission to migrate.
  if (db.prepare('SELECT 1 FROM assignments WHERE active = 1 LIMIT 1').get()
      || db.prepare('SELECT 1 FROM reservations WHERE active = 1 LIMIT 1').get()) {
    throw new StorageError('MAINTENANCE_REQUIRED', 'Durable business resources remain occupied.');
  }
}

/** Return only a same-method, same-payload receipt after the caller performed current authorization. */
export function receipt(db, options, operation) {
  const row = db.prepare('SELECT request_hash, payload FROM operation_receipts WHERE id = ?')
    .get(options.request.operationId);
  if (!row) return undefined;
  const envelope = JSON.parse(row.payload);
  if (row.request_hash !== options.requestHash || envelope.operation !== operation) {
    throw new StorageError('IDEMPOTENCY_MISMATCH', 'Operation identity has a different semantic payload.');
  }
  return envelope;
}

/** Redacted state is safe for status/diagnostics and CLI envelopes; token hashes never escape. */
export function publicMaintenance(board) {
  const session = board.maintenance;
  return session?.active ? {
    id: session.id, active: true, ownerId: session.ownerId, enteredAt: session.enteredAt,
  } : null;
}

/** Append maintenance history, transport event and receipt atomically with the caller's state change. */
export function commitRecord(db, board, options, operation, result, auditData = {}) {
  board.boardRevision += 1;
  board.eventSeq += 1;
  board.updatedAt = new Date().toISOString();
  const event = {
    type: operation,
    data: { ...auditData, maintenanceId: options.maintenanceId, actorId: options.leadId },
    generation: board.generation, boardRevision: board.boardRevision, eventSeq: board.eventSeq,
    operationId: options.request.operationId, at: board.updatedAt,
  };
  db.prepare('INSERT INTO audit_events(operation_id, type, payload) VALUES (?, ?, ?)')
    .run(options.request.operationId, operation, JSON.stringify(event));
  db.prepare('INSERT INTO change_events(sequence, generation, type, payload) VALUES (?, ?, ?, ?)')
    .run(board.eventSeq, board.generation, operation, JSON.stringify(event));
  writeMetadata(db, board);
  const envelope = {
    schemaVersion: 1, operation, ok: true, boardId: board.boardId,
    generation: board.generation, boardRevision: board.boardRevision, eventSeq: board.eventSeq, result,
  };
  db.prepare(`INSERT INTO operation_receipts(id, request_hash, generation, payload)
    VALUES (?, ?, ?, ?)`).run(
    options.request.operationId, options.requestHash, board.generation, JSON.stringify(envelope),
  );
  return envelope;
}

/** Execute a bounded synchronous maintenance transaction, preserving the original failure on rollback. */
export function maintenanceTransaction(db, callback, write = true) {
  try {
    db.exec(write ? 'BEGIN IMMEDIATE' : 'BEGIN');
    const result = callback(readMetadata(db));
    db.exec('COMMIT');
    return result;
  } catch (error) {
    try { db.exec('ROLLBACK'); } catch { /* Preserve transaction evidence and the original failure. */ }
    throw storageFailure(error);
  }
}

/** Observe actual available bytes; unavailable filesystem telemetry remains explicitly unknown. */
export function availableBytes(directory) {
  try {
    const stat = fs.statfsSync(directory, { bigint: true });
    const bytes = stat.bavail * stat.bsize;
    return bytes <= BigInt(Number.MAX_SAFE_INTEGER) ? Number(bytes) : 'unknown';
  } catch { return 'unknown'; }
}

/** Conservatively budget a consistent backup and migration overhead before creating any backup file. */
export function diskPreflight(paths, backupPath) {
  const destination = inspectPath(path.resolve(paths.projectRoot, backupPath));
  const relative = path.relative(paths.projectRoot, destination);
  if (!relative || relative === '..' || relative.startsWith(`..${path.sep}`)
      || path.isAbsolute(relative) || destination === paths.file
      || destination.startsWith(`${paths.file}-`)) {
    throw new StorageError('UNSAFE_PATH', 'Migration backup must be a separate project-local file.');
  }
  let backupDirectory = path.dirname(destination);
  while (!fs.existsSync(backupDirectory)) backupDirectory = path.dirname(backupDirectory);
  const databaseBytes = fs.statSync(paths.file).size;
  const walBytes = fs.existsSync(`${paths.file}-wal`) ? fs.statSync(`${paths.file}-wal`).size : 0;
  const requiredBytes = 3 * databaseBytes + 2 * walBytes + 1024 * 1024;
  if (!Number.isSafeInteger(requiredBytes)) {
    throw new StorageError('MAINTENANCE_REQUIRED', 'Migration space budget cannot be represented safely.');
  }
  for (const directory of new Set([paths.directory, backupDirectory])) {
    const freeBytes = availableBytes(directory);
    if (freeBytes === 'unknown' || freeBytes < requiredBytes) {
      throw new StorageError(
        'MAINTENANCE_REQUIRED', 'Migration space budget is unavailable or insufficient.',
        { requiredBytes, freeBytes },
      );
    }
  }
  return { requiredBytes };
}
