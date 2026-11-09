/** One short SQLite transaction commits domain state, receipts, audit, and transport cursors together. */
import { readMetadata, writeMetadata } from './connection.mjs';
import { repositories } from './repositories.mjs';
import { StorageError, storageFailure } from './errors.mjs';

/** Run a synchronous domain callback; no host actions or asynchronous work may enter this boundary. */
export function transactOperation(
  db, { request, requestHash, operation, authorizeReplay, authorizeContext }, callback, hooks = {},
) {
  if (!request?.operationId || !/^[a-f0-9]{64}$/i.test(requestHash) || !operation) {
    throw new StorageError('INVALID_INPUT', 'Operation identity and SHA256 request hash are required.');
  }
  let active = false;
  let committed = false;
  try {
    db.exec('BEGIN IMMEDIATE');
    active = true;
    const board = readMetadata(db);
    // Current session context is required even when this operation ID has a historical receipt.
    authorizeContext?.(board);
    // Existing connections must observe durable maintenance before either mutation or receipt replay.
    if (board.maintenance?.active) {
      throw new StorageError('MAINTENANCE_REQUIRED', 'The board is in explicit maintenance mode.');
    }
    // Generation precedes replay: a restored board must never replay an old successful claim.
    if (request.generation !== board.generation) {
      throw new StorageError('STALE_GENERATION', 'Board generation has changed.');
    }
    const receipt = db.prepare('SELECT * FROM operation_receipts WHERE id = ?')
      .get(request.operationId);
    if (receipt) {
      if (receipt.request_hash !== requestHash) {
        throw new StorageError('IDEMPOTENCY_MISMATCH', 'Operation ID was used for another request.');
      }
      const envelope = JSON.parse(receipt.payload);
      // Revoked credentials cannot retrieve an earlier successful assignment after transfer/release.
      const authorization = authorizeReplay?.({ board, ...repositories(db) }, envelope);
      if (authorization && typeof authorization.then === 'function') {
        throw new StorageError('INVALID_INPUT', 'Replay authorization must be synchronous.');
      }
      db.exec('COMMIT');
      active = false;
      return envelope;
    }
    const audits = [];
    const changes = [];
    const assertWritable = () => {
      if (!active) throw new StorageError('CONFLICT', 'The operation transaction has ended.');
    };
    const tx = {
      board,
      ...repositories(db, assertWritable),
      /** Append required work history independently of the disposable transport log. */
      audit(type, data) { assertWritable(); audits.push({ type, data }); },
      /** Queue a committed transport event; delivery happens only after this transaction exits. */
      change(type, data) { assertWritable(); changes.push({ type, data }); },
    };
    const result = callback(tx);
    if (result && typeof result.then === 'function') {
      throw new StorageError('INVALID_INPUT', 'Operation callbacks must be synchronous.');
    }
    board.boardRevision += 1;
    board.updatedAt = new Date().toISOString();
    if (!audits.length) audits.push({ type: operation, data: { actorId: request.actorId } });
    if (!changes.length) changes.push({ type: operation, data: {} });
    for (const item of audits) {
      db.prepare('INSERT INTO audit_events(operation_id, type, payload) VALUES (?, ?, ?)')
        .run(request.operationId, item.type, JSON.stringify({ ...item, at: board.updatedAt }));
    }
    for (const item of changes) {
      board.eventSeq += 1;
      const event = {
        ...item, eventSeq: board.eventSeq, boardRevision: board.boardRevision,
        generation: board.generation, operationId: request.operationId, at: board.updatedAt,
      };
      db.prepare('INSERT INTO change_events(sequence, generation, type, payload) VALUES (?, ?, ?, ?)')
        .run(board.eventSeq, board.generation, item.type, JSON.stringify(event));
    }
    writeMetadata(db, board);
    const envelope = {
      schemaVersion: 1, operation, ok: true, boardId: board.boardId,
      generation: board.generation, boardRevision: board.boardRevision,
      eventSeq: board.eventSeq, result: result ?? null,
    };
    db.prepare(`INSERT INTO operation_receipts(id, request_hash, generation, payload)
      VALUES (?, ?, ?, ?)`).run(
      request.operationId, requestHash, board.generation, JSON.stringify(envelope),
    );
    // Only controlled test children supply hooks; neither hook is exposed by the CLI.
    hooks.beforeCommit?.();
    db.exec('COMMIT');
    active = false;
    committed = true;
    hooks.afterCommit?.();
    return envelope;
  } catch (error) {
    if (active && !committed) {
      try { db.exec('ROLLBACK'); } catch { /* Preserve the original failure and database evidence. */ }
    }
    active = false;
    throw storageFailure(error);
  }
}
