/** Validated SQLite backup publication and new-target recovery; online replacement is unsupported. */
import fs from 'node:fs';
import path from 'node:path';
import { randomUUID, createHash } from 'node:crypto';
import { backup } from 'node:sqlite';
import {
  connect, connectMaintenance, readMetadata, verifyDatabase, verifyMaintenanceDatabase, writeMetadata,
} from './connection.mjs';
import { inspectPath, reserveDatabase, boardPaths } from './paths.mjs';
import { repositories } from './repositories.mjs';
import { StorageError, storageFailure } from './errors.mjs';
import { inspectBackup } from './inspection.mjs';
import { assertSession } from './session.mjs';

/** Require an explicit new local file inside this project, excluding the live database family. */
function destinationPath(projectRoot, destination, liveFile) {
  const target = inspectPath(path.resolve(projectRoot, destination));
  const relative = path.relative(projectRoot, target);
  if (!relative || relative === '..' || relative.startsWith(`..${path.sep}`)
      || path.isAbsolute(relative) || target === liveFile || target.startsWith(`${liveFile}-`)) {
    throw new StorageError('UNSAFE_PATH', 'Backup destination must be a new project-local file.');
  }
  fs.mkdirSync(path.dirname(target), { recursive: true });
  for (const suffix of ['', '-wal', '-shm', '-journal']) {
    if (fs.existsSync(target + suffix)) {
      throw new StorageError('CONFLICT', 'Backup destination or reserved sidecar exists.');
    }
  }
  return target;
}

/** Publish a closed, validated stage without replacing a prior recovery point. */
export function publish(stage, target) {
  // Reserve a previously absent name first. Rename replaces only our empty placeholder;
  // interruption can leave an invalid placeholder but cannot overwrite an older recovery point.
  reserveDatabase(target);
  fs.renameSync(stage, target);
}

/** Create an online-consistent copy, validate its contents, then publish the independent file. */
export async function backupDatabase(db, paths, destination) {
  return verifiedBackup(db, paths, destination, false);
}

/** Back up an explicitly supported maintenance format without broadening ordinary board opening. */
export async function backupMaintenanceDatabase(db, paths, destination) {
  return verifiedBackup(db, paths, destination, true);
}

/** Validate the complete staged image before publishing; only maintenance can copy schema 2. */
async function verifiedBackup(db, paths, destination, maintenance) {
  const target = destinationPath(paths.projectRoot, destination, paths.file);
  const stage = `${target}.${randomUUID()}.pending`;
  try {
    await backup(db, stage);
    const copy = maintenance ? connectMaintenance(stage) : connect(stage);
    let board;
    try {
      board = maintenance ? verifyMaintenanceDatabase(copy, paths.projectRoot)
        : verifyDatabase(copy, paths.projectRoot);
      const integrity = copy.prepare('PRAGMA integrity_check').all();
      if (integrity.length !== 1 || Object.values(integrity[0])[0] !== 'ok') {
        throw new StorageError('RECOVERY_REQUIRED', 'Backup full integrity verification failed.');
      }
      copy.exec('PRAGMA wal_checkpoint(TRUNCATE);');
    } finally { copy.close(); }
    publish(stage, target);
    return {
      path: target, sha256: await fileDigest(target),
      boardId: board.boardId, generation: board.generation,
      boardRevision: board.boardRevision, eventSeq: board.eventSeq,
    };
  } catch (error) {
    // Failed stages remain evidence; an earlier published backup is never overwritten.
    throw storageFailure(error);
  }
}

/** Stream the closed backup image into its manifest digest without buffering the whole database. */
async function fileDigest(file) {
  const digest = createHash('sha256');
  for await (const chunk of fs.createReadStream(file)) digest.update(chunk);
  return digest.digest('hex');
}

/** Restore only into a brand-new board directory; caller coordinates all real in-flight writers. */
export async function restoreDatabase({
  projectRoot, boardPath, backupPath, leadId, leadTokenHash, sessionKey,
}) {
  // Authenticate against the independent validated recovery point before creating the target path.
  const canonicalRoot = fs.realpathSync(inspectPath(projectRoot));
  const sourcePath = inspectPath(path.resolve(canonicalRoot, backupPath));
  const sourceRelative = path.relative(canonicalRoot, sourcePath);
  if (!sourceRelative || sourceRelative === '..' || sourceRelative.startsWith(`..${path.sep}`)
      || path.isAbsolute(sourceRelative)) {
    throw new StorageError('UNSAFE_PATH', 'Recovery point must be inside the bound project.');
  }
  const { paths, stage } = await inspectBackup(sourcePath, canonicalRoot, async (source, metadata) => {
    assertSession(metadata, sessionKey);
    if (!leadId || !leadTokenHash || metadata.leadId !== leadId
        || metadata.leadTokenHash !== leadTokenHash) {
      throw new StorageError('UNAUTHORIZED', 'Recovery requires the backup coordinator credential.');
    }
    const targetPaths = boardPaths(projectRoot, boardPath, true);
    for (const suffix of ['', '-wal', '-shm', '-journal']) {
      if (fs.existsSync(targetPaths.file + suffix)) {
        throw new StorageError('CONFLICT', 'Restore never replaces an existing board.');
      }
    }
    const targetStage = `${targetPaths.file}.${randomUUID()}.pending`;
    await backup(source, targetStage);
    return { paths: targetPaths, stage: targetStage };
  }, { currentOnly: true });
  const restored = connect(stage);
  try {
    verifyDatabase(restored, paths.projectRoot);
    restored.exec('BEGIN IMMEDIATE');
    const board = readMetadata(restored);
    const oldGeneration = board.generation;
    board.generation = randomUUID();
    board.boardRevision += 1;
    board.eventSeq += 1;
    board.replayFloor = board.eventSeq;
    board.updatedAt = new Date().toISOString();
    board.recoveryRequired = true;
    // A recovered generation requires a new explicit session; copied session/pending authority is obsolete.
    board.maintenance = null;
    const repos = repositories(restored, () => {});
    // Old worker credentials/grants cannot resume writes. Resource facts survive for reconciliation.
    for (const worker of repos.workers.list()) repos.workers.put({ ...worker, tokenHash: '' });
    restored.exec('DELETE FROM grants;');
    const assignments = repos.assignments.list();
    const activeTaskIds = new Set(assignments.filter((item) => item.active).map((item) => item.taskId));
    for (const assignment of assignments) {
      repos.assignments.put({ ...assignment, tokenHash: '' });
    }
    for (const task of repos.tasks.list()) {
      repos.tasks.put({
        ...task, resultValid: false,
        cleanupPending: activeTaskIds.has(task.id),
      });
    }
    for (const submission of repos.submissions.list()) {
      repos.submissions.put({ ...submission, freezeValid: false });
    }
    const event = {
      type: 'restored', data: { oldGeneration }, generation: board.generation,
      eventSeq: board.eventSeq, boardRevision: board.boardRevision, at: board.updatedAt,
    };
    restored.prepare(`INSERT INTO change_events(sequence, generation, type, payload)
      VALUES (?, ?, ?, ?)`).run(board.eventSeq, board.generation, event.type, JSON.stringify(event));
    restored.prepare(`INSERT INTO audit_events(operation_id, type, payload)
      VALUES (?, ?, ?)`).run(`restore:${board.generation}`, 'restored', JSON.stringify(event));
    writeMetadata(restored, board);
    restored.exec('COMMIT');
    verifyDatabase(restored, paths.projectRoot);
    restored.exec('PRAGMA wal_checkpoint(TRUNCATE);');
  } catch (error) {
    try { restored.exec('ROLLBACK'); } catch { /* Preserve staged recovery evidence. */ }
    throw storageFailure(error);
  } finally { restored.close(); }
  publish(stage, paths.file);
  return paths;
}
