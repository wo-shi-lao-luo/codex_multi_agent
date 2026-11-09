/** SQLite runtime gates and verified connection settings; opening never initializes a missing board. */
import fs from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { APPLICATION_ID, SCHEMA_VERSION } from './schema.mjs';
import { StorageError, storageFailure } from './errors.mjs';
import { validateSessionProfile } from '../domain/session.mjs';

const pragma = (db, name) => Object.values(db.prepare(`PRAGMA ${name}`).get())[0];

/** Open the pinned runtime with bounded lock waiting and safe per-connection configuration. */
export function connect(file, readOnly = false, initializing = false, beforePersistentChange) {
  return createConnection(file, readOnly, initializing ? 'initialize' : 'current', beforePersistentChange);
}

/** Restricted maintenance opener accepts only historical 2/3 and current 4 formats. */
export function connectMaintenance(file, readOnly = false) {
  return createConnection(file, readOnly, 'maintenance');
}

/** Authenticate a verified maintenance write before any persistent journal configuration changes. */
export function connectMaintenanceWriter(file, projectRoot, validate) {
  return createConnection(file, false, 'maintenance', (db) => {
    const board = verifyMaintenanceDatabase(db, projectRoot);
    validate(db, board);
  });
}

/** Apply the same runtime/configuration gates to both explicit supported routes. */
function createConnection(file, readOnly, route, beforePersistentChange) {
  const [major, minor] = process.versions.node.split('.').map(Number);
  if (major !== 26 || minor < 13) {
    throw new StorageError('UNSUPPORTED_RUNTIME', 'Task board requires Node.js 26.13 or later in 26.x.');
  }
  if (!fs.existsSync(file)) throw new StorageError('NOT_INITIALIZED', 'Board does not exist.');
  const db = new DatabaseSync(file, { readOnly, enableForeignKeyConstraints: true });
  try {
    // Inspect compatibility before WAL can change an existing file's journal mode.
    const version = pragma(db, 'user_version');
    const knownVersion = route === 'maintenance' ? [2, 3, SCHEMA_VERSION].includes(version)
      : version === SCHEMA_VERSION;
    if (route !== 'initialize' && (!knownVersion
        || pragma(db, 'application_id') !== APPLICATION_ID)) {
      throw new StorageError('UNSUPPORTED_SCHEMA', 'Unknown board schema; no changes were made.');
    }
    const sqliteVersion = db.prepare('SELECT sqlite_version() AS version').get().version;
    const [sqliteMajor, sqliteMinor] = sqliteVersion.split('.').map(Number);
    if (sqliteMajor < 3 || (sqliteMajor === 3 && sqliteMinor < 54)) {
      throw new StorageError('UNSUPPORTED_RUNTIME', 'SQLite 3.54.0 or later is required.');
    }
    db.exec('PRAGMA busy_timeout = 5000; PRAGMA foreign_keys = ON; PRAGMA synchronous = FULL;');
    beforePersistentChange?.(db);
    if (!readOnly) db.exec('PRAGMA journal_mode = WAL; PRAGMA wal_autocheckpoint = 1000;');
    // Maintenance diagnostics accept known DELETE-mode images without upgrading their journal.
    const requiresWal = !(readOnly && route === 'maintenance');
    if (pragma(db, 'foreign_keys') !== 1 || pragma(db, 'synchronous') !== 2
        || pragma(db, 'busy_timeout') !== 5000
        || (requiresWal && String(pragma(db, 'journal_mode')).toLowerCase() !== 'wal')) {
      throw new StorageError('RECOVERY_REQUIRED', 'SQLite configuration readback failed.');
    }
    if (readOnly) db.exec('PRAGMA query_only = ON;');
    return db;
  } catch (error) {
    db.close();
    throw storageFailure(error);
  }
}

/** Reject incompatible or damaged state before exposing any repository or mutation. */
export function verifyDatabase(db, projectRoot) {
  return verifyFormat(db, projectRoot, false);
}

/** Verify only explicitly supported maintenance formats, never arbitrary versions. */
export function verifyMaintenanceDatabase(db, projectRoot) {
  return verifyFormat(db, projectRoot, true);
}

/** Check integrity and exact metadata/header agreement before exposing board identity. */
function verifyFormat(db, projectRoot, maintenance) {
  const version = pragma(db, 'user_version');
  const knownVersion = maintenance ? [2, 3, SCHEMA_VERSION].includes(version)
    : version === SCHEMA_VERSION;
  if (!knownVersion
      || pragma(db, 'application_id') !== APPLICATION_ID) {
    throw new StorageError('UNSUPPORTED_SCHEMA', 'Unknown board schema; no changes were made.');
  }
  if (pragma(db, 'quick_check') !== 'ok' || db.prepare('PRAGMA foreign_key_check').all().length) {
    throw new StorageError('RECOVERY_REQUIRED', 'Board integrity verification failed.');
  }
  const board = readMetadata(db);
  if (board.schemaVersion !== version || board.projectRoot !== projectRoot) {
    throw new StorageError('PROJECT_MISMATCH', 'Board is bound to a different project or schema.');
  }
  return board;
}

/** Read fresh metadata inside the caller's transaction, or as one standalone SQLite statement. */
export function readMetadata(db) {
  const row = db.prepare('SELECT payload FROM boards WHERE id = 1').get();
  if (!row) throw new StorageError('RECOVERY_REQUIRED', 'Board metadata is missing.');
  const board = JSON.parse(row.payload);
  if (board.sessionProfile !== undefined) validateSessionProfile(board.sessionProfile);
  return board;
}

/** Persist metadata only as part of an enclosing write transaction. */
export function writeMetadata(db, board) {
  db.prepare('UPDATE boards SET payload = ? WHERE id = 1').run(JSON.stringify(board));
}
