/** Explicit historical backup recovery into a new target; source images are never opened by SQLite. */
import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { backup } from 'node:sqlite';
import { boardPaths, inspectPath } from './paths.mjs';
import { connectMaintenance, verifyMaintenanceDatabase, verifyDatabase, writeMetadata }
  from './connection.mjs';
import { authorizePhysical, artifactPath, inspectArtifact, verifyDigest }
  from './physical-protocol.mjs';
import { inspectBackup } from './inspection.mjs';
import { invalidateLegacy, invalidateThree } from './migration.mjs';
import { repositories } from './repositories.mjs';
import { publish } from './maintenance.mjs';
import { StorageError, storageFailure } from './errors.mjs';
import { assertSession } from './session.mjs';

/** Require zero persisted legacy holders; recovery never guesses that old workers have stopped. */
function noLegacyHolders(db) {
  const repos = repositories(db);
  if (db.prepare('SELECT 1 FROM assignments WHERE active = 1 LIMIT 1').get()
      || db.prepare('SELECT 1 FROM reservations WHERE active = 1 LIMIT 1').get()
      || repos.assignments.list().some((item) => item.active !== false)
      || repos.reservations.list().some((item) => item.active !== false)) {
    throw new StorageError(
      'MAINTENANCE_REQUIRED', 'Legacy active assignments or reservations block recovery.',
    );
  }
}

/** Authenticate the closed backup before creating a target; preserve source and rejected stages. */
export async function restoreMigrationBackup2To3(options) {
  return restoreHistoricalBackup(options, 2, 3);
}

/** Recover an authenticated schema-3 backup into a new schema-4 target requiring reconciliation. */
export async function restoreMigrationBackup3To4(options) {
  return restoreHistoricalBackup(options, 3, 4);
}

/** Preserve the exact requested historical step; publication happens only after full staged checks. */
async function restoreHistoricalBackup(options, fromVersion, toVersion) {
  if (!options || typeof options !== 'object' || Array.isArray(options)) {
    throw new StorageError('INVALID_INPUT', 'Legacy recovery requires an options object.');
  }
  const projectRoot = fs.realpathSync(inspectPath(options.projectRoot));
  const sourcePath = artifactPath({ projectRoot, file: path.join(projectRoot, 'board.sqlite') },
    options.backupPath);
  inspectArtifact(sourcePath, true);
  await verifyDigest(sourcePath, options.expectedSha256);
  const { paths, stage, metadata } = await inspectBackup(sourcePath, projectRoot, async (source, board) => {
    assertSession(board, options.sessionKey);
    authorizePhysical(board, options);
    if (board.schemaVersion !== fromVersion) {
      throw new StorageError('UNSUPPORTED_SCHEMA', 'Backup does not match the requested historical format.');
    }
    if (board.boardRevision !== options.request.expectedBoardRevision) {
      throw new StorageError('CONFLICT', 'Recovery request does not match the backup revision.');
    }
    noLegacyHolders(source);
    const targetPaths = boardPaths(projectRoot, options.boardPath, true);
    inspectArtifact(targetPaths.file);
    const targetStage = `${targetPaths.file}.${randomUUID()}.pending`;
    await backup(source, targetStage);
    return { paths: targetPaths, stage: targetStage, metadata: board };
  });
  await verifyDigest(sourcePath, options.expectedSha256);
  const restored = connectMaintenance(stage);
  let board;
  try {
    restored.exec('BEGIN IMMEDIATE');
    board = verifyMaintenanceDatabase(restored, projectRoot);
    noLegacyHolders(restored);
    if (board.boardId !== metadata.boardId || board.generation !== metadata.generation
        || board.boardRevision !== metadata.boardRevision || board.eventSeq !== metadata.eventSeq) {
      throw new StorageError('CONFLICT', 'Staged recovery differs from the authenticated backup.');
    }
    if (fromVersion === 2) invalidateLegacy(restored);
    else invalidateThree(restored, board);
    const oldGeneration = board.generation;
    board.schemaVersion = toVersion;
    board.generation = randomUUID();
    board.boardRevision += 1;
    board.eventSeq += 1;
    board.replayFloor = board.eventSeq;
    board.updatedAt = new Date().toISOString();
    board.recoveryRequired = true;
    board.maintenance = null;
    restored.exec(`PRAGMA user_version = ${toVersion};`);
    const event = {
      type: 'restored-migration-backup', data: { oldGeneration, actorId: options.leadId },
      generation: board.generation, boardRevision: board.boardRevision,
      eventSeq: board.eventSeq, at: board.updatedAt,
    };
    writeMetadata(restored, board);
    restored.prepare('INSERT INTO audit_events(operation_id, type, payload) VALUES (?, ?, ?)')
      .run(options.request.operationId, event.type, JSON.stringify(event));
    restored.prepare('INSERT INTO change_events(sequence, generation, type, payload) VALUES (?, ?, ?, ?)')
      .run(board.eventSeq, board.generation, event.type, JSON.stringify(event));
    if (toVersion === 4) verifyDatabase(restored, projectRoot);
    else verifyMaintenanceDatabase(restored, projectRoot);
    const rows = restored.prepare('PRAGMA integrity_check').all();
    if (rows.length !== 1 || Object.values(rows[0])[0] !== 'ok') {
      throw new StorageError('RECOVERY_REQUIRED', 'Staged recovery integrity verification failed.');
    }
    restored.exec('COMMIT');
    const checkpoint = restored.prepare('PRAGMA wal_checkpoint(TRUNCATE)').get();
    if (checkpoint.busy || checkpoint.log !== checkpoint.checkpointed) {
      throw new StorageError('BUSY', 'Staged recovery could not complete its checkpoint.');
    }
  } catch (error) {
    try { restored.exec('ROLLBACK'); } catch { /* Preserve stage and source for explicit diagnosis. */ }
    throw storageFailure(error);
  } finally { restored.close(); }
  inspectArtifact(paths.file);
  publish(stage, paths.file);
  return {
    schemaVersion: 1, operation: `restore-migration-backup-${fromVersion}-to-${toVersion}`, ok: true,
    boardId: board.boardId, generation: board.generation,
    boardRevision: board.boardRevision, eventSeq: board.eventSeq,
    result: {
      fromVersion, toVersion, path: paths.directory, reconciliationRequired: true,
      sourceRetained: true, receiptCommitted: false,
    },
  };
}
