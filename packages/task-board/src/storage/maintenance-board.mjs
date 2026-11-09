/** Restricted maintenance facade: diagnostics and durable sessions for explicitly known formats only. */
import fs from 'node:fs';
import { boardPaths } from './paths.mjs';
import {
  connectMaintenance, connectMaintenanceWriter, verifyMaintenanceDatabase,
  readMetadata,
} from './connection.mjs';
import {
  authorize, checkRevision, requireQuiescence, receipt, commitRecord,
  publicMaintenance, maintenanceTransaction, availableBytes,
} from './maintenance-protocol.mjs';
import { checkMigration, migrateTwoToThree, migrateThreeToFour } from './migration.mjs';
import { StorageError, storageFailure } from './errors.mjs';
import { previewVacuum } from './vacuum-plan.mjs';
import {
  prepareVacuum, vacuum, publicPending, prepareResolution, resolveMaintenanceOperation,
} from './vacuum.mjs';
import { assertSession } from './session.mjs';

/** Describe actual schema/cursors without returning credential hashes or raw stored board metadata. */
function publicStatus(board) {
  return {
    schemaVersion: board.schemaVersion, boardId: board.boardId, generation: board.generation,
    boardRevision: board.boardRevision, eventSeq: board.eventSeq,
    maintenance: publicMaintenance(board),
    pendingOperation: publicPending(board),
  };
}

/** Validate entry without changing storage, so rejected requests cannot even upgrade journal mode. */
function prepareEnter(db, board, options) {
  authorize(board, options, false);
  if (options.request.generation !== board.generation) {
    throw new StorageError('STALE_GENERATION', 'The board generation has changed.');
  }
  if (board.maintenance?.active) {
    authorize(board, options);
    const previous = receipt(db, options, 'enter-maintenance');
    if (previous) return previous;
    throw new StorageError('MAINTENANCE_REQUIRED', 'An explicit maintenance session is already active.');
  }
  // Session IDs cannot be resurrected after exit to regain access to an earlier migration receipt.
  const used = db.prepare(`SELECT 1 FROM operation_receipts
      WHERE json_extract(payload, '$.operation') = 'enter-maintenance'
      AND json_extract(payload, '$.result.maintenance.id') = ? LIMIT 1`).get(options.maintenanceId);
  if (used) throw new StorageError('UNAUTHORIZED', 'An ended maintenance session cannot be reused.');
  if (receipt(db, options, 'enter-maintenance')) {
    throw new StorageError('UNAUTHORIZED', 'An ended maintenance operation cannot be replayed.');
  }
  checkRevision(board, options);
  requireQuiescence(db, options);
  return undefined;
}

/** Start a uniquely named session only after rechecking eligibility inside its write transaction. */
function enter(db, options) {
  return maintenanceTransaction(db, (board) => {
    const previous = prepareEnter(db, board, options);
    if (previous) return previous;
    board.maintenance = {
      id: options.maintenanceId, tokenHash: options.maintenanceTokenHash, ownerId: options.leadId,
      enteredAt: new Date().toISOString(), active: true,
      stopEvidenceRefs: options.quiescence.evidenceRefs,
    };
    return commitRecord(db, board, options, 'enter-maintenance', {
      maintenance: publicMaintenance(board),
    });
  });
}

/** Validate exit without persistent effects; replay also requires the still-active session. */
function prepareExit(db, board, options) {
  authorize(board, options);
  if (board.maintenance.pendingOperation) {
    throw new StorageError('MAINTENANCE_REQUIRED', 'Resolve the pending physical operation before exit.');
  }
  const previous = receipt(db, options, 'exit-maintenance');
  if (previous) return previous;
  checkRevision(board, options);
  requireQuiescence(db, options);
  return undefined;
}

/** End only the currently authorized session; historical receipts never reactivate or bypass it. */
function exit(db, options) {
  return maintenanceTransaction(db, (board) => {
    const previous = prepareExit(db, board, options);
    if (previous) return previous;
    board.maintenance = null;
    return commitRecord(db, board, options, 'exit-maintenance', { maintenance: null });
  });
}

/** Open known historical/current schemas only for fixed operations, without a schema override. */
export function openMaintenanceBoard({ projectRoot, boardPath, sessionKey }) {
  const paths = boardPaths(projectRoot, boardPath);
  let db;
  try {
    db = connectMaintenance(paths.file, true);
    assertSession(verifyMaintenanceDatabase(db, paths.projectRoot), sessionKey);
  } catch (error) {
    db?.close();
    throw storageFailure(error);
  }
  let busy = false;
  let closed = false;
  const assertAvailable = () => {
    if (closed) throw new StorageError('CONFLICT', 'Maintenance connection is closed.');
    if (busy) throw new StorageError('BUSY', 'This maintenance connection already has an operation.');
    assertSession(readMetadata(db), sessionKey);
  };
  /** Keep diagnostics permanently read-only; acquire a short-lived writer only for approved work. */
  const withWriter = (prepare, action) => {
    assertAvailable();
    const guardedPrepare = (connection, board) => {
      assertSession(board, sessionKey);
      return prepare(connection, board);
    };
    const previous = maintenanceTransaction(db, (board) => guardedPrepare(db, board), false);
    if (previous) return previous;
    // Repeat identity and authorization on the new connection before WAL, then again in the action lock.
    const writer = connectMaintenanceWriter(paths.file, paths.projectRoot, guardedPrepare);
    try {
      const result = action(writer);
      if (result && typeof result.then === 'function') {
        busy = true;
        return result.finally(() => {
          writer.close();
          busy = false;
        });
      }
      writer.close();
      return result;
    } catch (error) {
      writer.close();
      throw error;
    }
  };
  return {
    /** Read actual durable maintenance state in one short snapshot; never return credential material. */
    status() {
      assertAvailable();
      return maintenanceTransaction(db, publicStatus, false);
    },
    /** Check SQLite and observed storage metrics; unavailable filesystem measurements stay unknown. */
    diagnose({ level = 'quick' } = {}) {
      assertAvailable();
      if (level !== 'quick' && level !== 'full') {
        throw new StorageError('INVALID_INPUT', 'Diagnostic level must be quick or full.');
      }
      return maintenanceTransaction(db, (board) => {
        const rows = db.prepare(`PRAGMA ${level === 'full' ? 'integrity_check' : 'quick_check'}`).all();
        const integrity = rows.length === 1 && Object.values(rows[0])[0] === 'ok' ? 'ok' : 'failed';
        return {
          ...publicStatus(board), level, integrity,
          foreignKeys: db.prepare('PRAGMA foreign_key_check').all().length ? 'failed' : 'ok',
          sqliteVersion: db.prepare('SELECT sqlite_version() AS version').get().version,
          space: {
            databaseBytes: fs.statSync(paths.file).size,
            walBytes: fs.existsSync(`${paths.file}-wal`) ? fs.statSync(`${paths.file}-wal`).size : 0,
            freeBytes: availableBytes(paths.directory),
          },
        };
      }, false);
    },
    /** Authenticate and durably enter maintenance with explicit stopped-writer evidence. */
    enter(options) {
      return withWriter((connection, board) => prepareEnter(connection, board, options),
        (writer) => enter(writer, options));
    },
    /** Authenticate and durably exit maintenance without reviving invalid historical evidence. */
    exit(options) {
      return withWriter((connection, board) => prepareExit(connection, board, options),
        (writer) => exit(writer, options));
    },
    /** Perform one explicit version step; the maintenance session survives generation rotation. */
    async migrate(options) {
      return withWriter((connection, board) => checkMigration(connection, paths, board, options),
        (writer) => (options.fromVersion === 3 ? migrateThreeToFour : migrateTwoToThree)
          (writer, paths, options));
    },
    /** Authenticate and validate a stable VACUUM plan; fresh space/time observations remain unsigned. */
    async previewVacuum(options) {
      assertAvailable();
      busy = true;
      try { return await previewVacuum(db, paths, options); }
      finally { busy = false; }
    },
    /** Commit a durable start, execute VACUUM without a transaction, and record its verified outcome. */
    async vacuum(options) {
      return withWriter((connection, board) => prepareVacuum(connection, board, options),
        (writer) => vacuum(writer, paths, options));
    },
    /** Explicitly retire a stopped owner's unknown attempt; this never asserts physical completion. */
    async resolveMaintenanceOperation(options) {
      return withWriter((connection, board) => prepareResolution(connection, board, options),
        (writer) => resolveMaintenanceOperation(writer, options));
    },
    /** Close this connection; the durable session survives and blocks ordinary writers until exit. */
    close() {
      assertAvailable();
      db.close();
      closed = true;
    },
  };
}
