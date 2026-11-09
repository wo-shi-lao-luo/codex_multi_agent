/** Public storage boundary: versioned board binding, bounded snapshots, atomic operations and recovery. */
import { randomUUID } from 'node:crypto';
import { boardPaths, reserveDatabase } from './paths.mjs';
import { connect, readMetadata, verifyDatabase } from './connection.mjs';
import { createSchema, repositoryDefinitions, SCHEMA_VERSION } from './schema.mjs';
import { repositories } from './repositories.mjs';
import { transactOperation } from './operations.mjs';
import { backupDatabase, restoreDatabase } from './maintenance.mjs';
import { StorageError, storageFailure } from './errors.mjs';
import { readHistory } from './history.mjs';
import { previewArchive, previewPrune, archive, applyPrune } from './retention.mjs';
import { authorizePhysical } from './physical-protocol.mjs';
import { convertBackup } from './compression.mjs';
import { validateSessionInitialization } from '../domain/session.mjs';
import { assertSession, syncSession } from './session.mjs';
import { initializeMainWorkspace } from './workspaces.mjs';

export { StorageError } from './errors.mjs';
export { openMaintenanceBoard } from './maintenance-board.mjs';
export { restoreMigrationBackup2To3 } from './legacy-recovery.mjs';
export { restoreMigrationBackup3To4 } from './legacy-recovery.mjs';

/** Wrap one validated connection. No operation keeps a read transaction alive across event delivery. */
function boardHandle(db, paths, { readOnly = false, testHooks = {}, sessionKey } = {}) {
  let inTransaction = false;
  return {
    /** Read fresh board identity and CAS cursors; contains local hashes, so presentation must redact. */
    metadata() {
      const board = readMetadata(db);
      assertSession(board, sessionKey);
      return board;
    },
    /** Close this connection only; persistent assignments and resources remain unchanged. */
    close() { db.close(); },
    /** Execute one synchronous consistent read; its repositories reject every write. */
    read(callback) {
      if (inTransaction) throw new StorageError('CONFLICT', 'Nested transactions are unsupported.');
      inTransaction = true;
      try {
        db.exec('BEGIN');
        const board = readMetadata(db);
        assertSession(board, sessionKey);
        const result = callback({ board, ...repositories(db) });
        if (result && typeof result.then === 'function') {
          throw new StorageError('INVALID_INPUT', 'Read callbacks must be synchronous.');
        }
        db.exec('COMMIT');
        return result;
      } catch (error) {
        try { db.exec('ROLLBACK'); } catch { /* Keep the original read failure. */ }
        throw storageFailure(error);
      } finally { inTransaction = false; }
    },
    /** Run one idempotent atomic operation; SQL remains private and hooks are test-program-only. */
    transactOperation(options, callback) {
      if (readOnly) throw new StorageError('READ_ONLY', 'This board connection is read-only.');
      if (inTransaction) throw new StorageError('CONFLICT', 'Nested transactions are unsupported.');
      inTransaction = true;
      try {
        return transactOperation(db, {
          ...options, authorizeContext: (board) => assertSession(board, sessionKey),
        }, callback, testHooks);
      }
      finally { inTransaction = false; }
    },
    /** Authenticated label-only CAS; unchanged labels do not reserve an operation receipt. */
    syncSession(options) { return syncSession(this, options); },
    /** Materialize the bounded P0 board plus its exact event cursor in one short read transaction. */
    snapshot() {
      return this.read((tx) => ({
        board: tx.board, eventSeq: tx.board.eventSeq,
        ...Object.fromEntries(Object.keys(repositoryDefinitions).map((name) => [name, tx[name].list()])),
      }));
    },
    /** Page exact task audit history with the revision actually observed in this read transaction. */
    history(options) {
      return this.read(({ board }) => readHistory(db, board, options));
    },
    /** Preview target protections and exact visibility changes without writing any state. */
    previewArchive(options) { return this.read((tx) => previewArchive(tx, options)); },
    /** Apply an approved, revision-bound logical archive/unarchive through the ordinary writer gate. */
    archive(options) { return archive(this, options); },
    /** Preview an exact disposable-event prefix, or report unsupported physical task deletion. */
    previewPrune(options) { return this.read((tx) => previewPrune(db, tx, options)); },
    /** Delete only an approved transport prefix with replay floor, audit and receipt in one commit. */
    applyPrune(options) { return applyPrune(db, this, options); },
    /** Replay bounded committed events, explicitly resetting stale generations and cursor gaps. */
    eventsAfter(cursor, limit = 100) {
      if (!Number.isSafeInteger(limit) || limit < 1 || limit > 1000
          || !Number.isSafeInteger(cursor?.eventSeq) || cursor.eventSeq < 0) {
        throw new StorageError('INVALID_INPUT', 'Event cursor and limit must be bounded integers.');
      }
      return this.read(({ board }) => {
        const reset = cursor.generation !== board.generation || cursor.eventSeq < board.replayFloor
          || cursor.eventSeq > board.eventSeq;
        const events = reset ? [] : db.prepare(`SELECT payload FROM change_events
          WHERE generation = ? AND sequence > ? ORDER BY sequence LIMIT ?`)
          .all(board.generation, cursor.eventSeq, limit).map((row) => JSON.parse(row.payload));
        return {
          reset, boardId: board.boardId, generation: board.generation,
          boardRevision: board.boardRevision, eventSeq: board.eventSeq, events,
        };
      });
    },
    /** Back up this live connection through SQLite's online backup API to a new local file. */
    backup(destinationFile) {
      if (inTransaction) throw new StorageError('CONFLICT', 'Backup requires no active callback.');
      this.metadata();
      return backupDatabase(db, paths, destinationFile);
    },
    /** Attempt PASSIVE checkpoint once; repeated IDs observe physical effects without business receipts. */
    checkpoint(options) {
      if (readOnly) throw new StorageError('READ_ONLY', 'Checkpoint requires a writable connection.');
      if (inTransaction) throw new StorageError('CONFLICT', 'Checkpoint cannot run inside a transaction.');
      authorizePhysical(this.metadata(), options);
      if (options.mode !== 'PASSIVE') {
        throw new StorageError('INVALID_INPUT', 'Only a single PASSIVE checkpoint is supported.');
      }
      const result = db.prepare('PRAGMA wal_checkpoint(PASSIVE)').get();
      return {
        operationId: options.request.operationId, mode: 'PASSIVE', busy: Boolean(result.busy),
        logFrames: result.log, checkpointedFrames: result.checkpointed,
        deferred: Boolean(result.busy) || result.checkpointed < result.log,
        receiptCommitted: false, businessStateChanged: false,
      };
    },
    /** Publish a verified closed-backup gzip without mutating the live board or deleting its source. */
    compressBackup(options) {
      const board = this.read(({ board: metadata }) => {
        authorizePhysical(metadata, options);
        return metadata;
      });
      return convertBackup(paths, board, options);
    },
    /** Expand and validate a closed gzip to a new SQLite backup, usable by its explicit restore route. */
    decompressBackup(options) {
      const board = this.read(({ board: metadata }) => {
        authorizePhysical(metadata, options);
        return metadata;
      });
      return convertBackup(paths, board, options, true);
    },
  };
}

/** Initialize a brand-new board with a hash-only Lead credential; never overwrite existing state. */
export function initializeBoard({
  projectRoot, boardPath, boardId = randomUUID(), leadId, leadTokenHash, sessionProfile, sessionKey,
}) {
  const profile = validateSessionInitialization({ sessionProfile, sessionKey, boardPath });
  if (!leadId || !/^[a-f0-9]{64}$/i.test(leadTokenHash)) {
    throw new StorageError('INVALID_INPUT', 'Lead identity and SHA256 credential hash are required.');
  }
  const paths = boardPaths(projectRoot, boardPath, true);
  const mainWorkspace = initializeMainWorkspace(paths.projectRoot);
  reserveDatabase(paths.file);
  const db = connect(paths.file, false, true);
  try {
    db.exec('BEGIN IMMEDIATE');
    createSchema(db);
    const timestamp = new Date().toISOString();
    const board = {
      schemaVersion: SCHEMA_VERSION, boardId, generation: randomUUID(), boardRevision: 0,
      eventSeq: 0, replayFloor: 0, projectRoot: paths.projectRoot, leadId, leadTokenHash,
      createdAt: timestamp, updatedAt: timestamp,
      questionPolicy: { pendingThreshold: 10 },
      workspaces: [mainWorkspace],
      ...(profile ? { sessionProfile: profile } : {}),
    };
    db.prepare('INSERT INTO boards(id, payload) VALUES (1, ?)').run(JSON.stringify(board));
    db.exec('COMMIT');
    verifyDatabase(db, paths.projectRoot);
    return boardHandle(db, paths, { sessionKey });
  } catch (error) {
    try { db.exec('ROLLBACK'); } catch { /* Leave failed initialization intact for diagnosis. */ }
    db.close();
    throw storageFailure(error);
  }
}

/** Open only a compatible existing board bound to this checkout; corruption is never reinitialized. */
export function openBoard(options) {
  const paths = boardPaths(options.projectRoot, options.boardPath);
  let db;
  try {
    db = connect(paths.file, options.readOnly, false, (connection) => {
      assertSession(verifyDatabase(connection, paths.projectRoot), options.sessionKey);
    });
    return boardHandle(db, paths, options);
  } catch (error) {
    db?.close();
    throw storageFailure(error);
  }
}

/** Recover to a new board path with a new generation; caller must reconcile all old real writers. */
export async function restoreBoard(options) {
  const paths = await restoreDatabase(options);
  return openBoard({ projectRoot: paths.projectRoot, boardPath: paths.directory,
    sessionKey: options.sessionKey });
}
