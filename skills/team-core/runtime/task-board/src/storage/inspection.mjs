/** Inspect closed backups only through private copies; SQLite never opens the caller's source file. */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createHash, randomUUID } from 'node:crypto';
import { Transform } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { inspectPath } from './paths.mjs';
import { connectMaintenance, verifyDatabase, verifyMaintenanceDatabase } from './connection.mjs';
import { StorageError } from './errors.mjs';

const FAMILY = ['', '-wal', '-shm', '-journal'];

/** Stream a source fingerprint; memory use is independent of backup size. */
async function fingerprint(file, maximum) {
  const hash = createHash('sha256');
  let bytes = 0;
  for await (const chunk of fs.createReadStream(file)) {
    bytes += chunk.length;
    if (bytes > maximum) throw new StorageError('CONFLICT', 'Backup source grew during fingerprinting.');
    hash.update(chunk);
  }
  if (bytes !== maximum) throw new StorageError('CONFLICT', 'Backup source shrank during fingerprinting.');
  return hash.digest('hex');
}

/** A standalone source cannot depend on SQLite sidecars; never remove or open such a family. */
function standalone(file) {
  inspectPath(file);
  const stat = fs.lstatSync(file);
  if (!stat.isFile() || FAMILY.slice(1).some((suffix) => fs.existsSync(file + suffix))) {
    throw new StorageError('CONFLICT', 'Inspection requires a standalone closed backup file.');
  }
  return stat;
}

/** Remove only this invocation's verified private directory and its exact inspection-file family. */
function cleanScratch(root, directory, identity) {
  const stat = fs.lstatSync(directory);
  if (stat.isSymbolicLink() || stat.dev !== identity.dev || stat.ino !== identity.ino
      || path.dirname(directory) !== root || fs.realpathSync(directory) !== directory) {
    throw new StorageError('RECOVERY_REQUIRED', 'Inspection cleanup could not verify its private directory.');
  }
  const names = new Set(FAMILY.map((suffix) => `inspection.sqlite${suffix}`));
  const entries = fs.readdirSync(directory);
  if (entries.some((name) => !names.has(name))) {
    throw new StorageError('RECOVERY_REQUIRED', 'Unknown private inspection entries were preserved.');
  }
  for (const name of entries) {
    const file = path.join(directory, name);
    const entry = fs.lstatSync(file);
    if (!entry.isFile() || entry.isSymbolicLink() || entry.nlink > 1) {
      throw new StorageError('RECOVERY_REQUIRED', 'Inspection cleanup refused an unexpected file type.');
    }
    fs.unlinkSync(file);
  }
  fs.rmdirSync(directory);
}

/** Copy and prove source stability, validate privately, then close/clean on success or any rejection.
 * Modes request POSIX-private access; Windows inherits account temp-directory ACLs, not same-user isolation.
 * Process termination can leave a random scratch directory; no automatic scan or source-sidecar cleanup runs.
 */
export async function inspectBackup(file, projectRoot, callback, { currentOnly = false, boardId } = {}) {
  const initial = standalone(file);
  const originalHash = await fingerprint(file, initial.size);
  const root = fs.realpathSync(os.tmpdir());
  const directory = fs.realpathSync(fs.mkdtempSync(path.join(root, `task-board-inspect-${randomUUID()}-`)));
  const identity = fs.lstatSync(directory);
  let db;
  try {
    fs.chmodSync(directory, 0o700);
    const copied = path.join(directory, 'inspection.sqlite');
    const copiedHash = createHash('sha256');
    let bytes = 0;
    const copy = new Transform({
      transform(chunk, encoding, done) {
        bytes += chunk.length;
        if (bytes > initial.size) {
          done(new StorageError('CONFLICT', 'Backup source grew during inspection.'));
          return;
        }
        copiedHash.update(chunk);
        done(null, chunk);
      },
    });
    await pipeline(fs.createReadStream(file), copy,
      fs.createWriteStream(copied, { flags: 'wx', mode: 0o600 }));
    const after = standalone(file);
    if (bytes !== initial.size || after.dev !== initial.dev || after.ino !== initial.ino
        || after.size !== initial.size || copiedHash.digest('hex') !== originalHash
        || await fingerprint(file, initial.size) !== originalHash) {
      throw new StorageError('CONFLICT', 'Backup source changed while creating its inspection copy.');
    }
    db = connectMaintenance(copied, true);
    const board = currentOnly ? verifyDatabase(db, projectRoot)
      : verifyMaintenanceDatabase(db, projectRoot);
    if (boardId && board.boardId !== boardId) {
      throw new StorageError('PROJECT_MISMATCH', 'Backup belongs to a different board.');
    }
    const rows = db.prepare('PRAGMA integrity_check').all();
    if (rows.length !== 1 || Object.values(rows[0])[0] !== 'ok') {
      throw new StorageError('RECOVERY_REQUIRED', 'Backup full integrity verification failed.');
    }
    const result = await callback(db, board);
    standalone(file);
    if (await fingerprint(file, initial.size) !== originalHash) {
      throw new StorageError('CONFLICT', 'Backup source changed during inspection.');
    }
    return result;
  } finally {
    try { db?.close(); }
    finally { cleanScratch(root, directory, identity); }
  }
}
