/** Explicit backed-up 2→3 and 3→4 transitions preserve old evidence as historical unknowns. */
import { randomUUID } from 'node:crypto';
import { verifyMaintenanceDatabase, verifyDatabase } from './connection.mjs';
import { repositories } from './repositories.mjs';
import { backupMaintenanceDatabase } from './maintenance.mjs';
import {
  authorize, checkRevision, requireQuiescence, receipt, commitRecord,
  maintenanceTransaction, diskPreflight,
} from './maintenance-protocol.mjs';
import { StorageError } from './errors.mjs';
import { initializeMainWorkspace } from './workspaces.mjs';
import { normalizeWorkspaceScope, normalizeScope, scopeResourceKey }
  from '../domain/workspace-scope.mjs';

/** Rebuild current path contracts using the same physical namespace as new schema-4 tasks.
 * Named resources remain board-global. Historical reservations are immutable allocation evidence.
 */
function rebuildPathResources(tx, task, previous) {
  const scope = task.scope;
  if (!Array.isArray(scope?.read) || !Array.isArray(scope?.write)) {
    throw new StorageError('UNSAFE_PATH', 'Legacy task requires an explicit valid scope.');
  }
  const resources = [];
  for (const [values, mode] of [[scope.read, 'shared'], [scope.write, 'exclusive']]) {
    for (const value of values) {
      const normalized = normalizeWorkspaceScope(tx, task, value, normalizeScope);
      resources.push({ id: randomUUID(), taskId: task.id, kind: 'path',
        key: scopeResourceKey(tx, task, normalized), mode });
    }
  }
  // Validate every declaration before replacing current rows; the enclosing transaction is atomic.
  for (const resource of previous ?? []) tx.taskResources.remove(resource.id);
  for (const resource of resources) tx.taskResources.put(resource);
  return resources.length;
}

/** Validate current authority before replay; this route never permits ordinary stale-generation work. */
export function checkMigration(db, paths, board, options) {
  authorize(board, options);
  if (!((options.fromVersion === 2 && options.toVersion === 3)
      || (options.fromVersion === 3 && options.toVersion === 4))) {
    throw new StorageError('UNSUPPORTED_SCHEMA', 'Only explicit 2 to 3 and 3 to 4 migrations are supported.');
  }
  const previous = receipt(db, options, 'migrate');
  if (previous) return previous;
  checkRevision(board, options);
  requireQuiescence(db, options);
  verifyMaintenanceDatabase(db, paths.projectRoot);
  if (board.schemaVersion !== options.fromVersion) {
    throw new StorageError('UNSUPPORTED_SCHEMA', 'Migration requires the exact requested source schema.');
  }
  return undefined;
}

/** Preserve evidence, source, lifecycle and repair history; unknown revisions cannot unlock work. */
export function invalidateLegacy(db) {
  const repos = repositories(db, () => {});
  const needsReconcileTaskIds = [];
  const revokedGrantIds = [];
  for (const task of repos.tasks.list()) {
    repos.tasks.put({
      ...task, inputRevision: null, freezeRevision: null, resultRevision: null,
      executionRevision: null, inputValid: false, resultValid: false, needsReconcile: true,
    });
    needsReconcileTaskIds.push(task.id);
  }
  for (const submission of repos.submissions.list()) {
    repos.submissions.put({
      ...submission, boundTaskInputRevision: null, freezeRevision: null,
      executionRevision: null, inputBindings: null, freezeValid: false,
    });
  }
  for (const assignment of repos.assignments.list()) {
    repos.assignments.put({
      ...assignment, boundTaskInputRevision: null, executionRevision: null, inputBindings: null,
    });
  }
  for (const dependency of repos.dependencies.list()) {
    repos.dependencies.put({ ...dependency, consumedRevision: null, consumedInputRevision: null });
  }
  for (const grant of repos.grants.list()) {
    repos.grants.put({ ...grant, revoked: true });
    revokedGrantIds.push(grant.id);
  }
  return { needsReconcileTaskIds, revokedGrantIds };
}

/** Back up outside the write lock, then repeat every identity/CAS/holder check inside the commit lock. */
export async function migrateTwoToThree(db, paths, options) {
  const previous = maintenanceTransaction(db, (board) => checkMigration(db, paths, board, options));
  if (previous) return previous;
  if (typeof options.backupPath !== 'string' || !options.backupPath) {
    throw new StorageError('INVALID_INPUT', 'Migration requires an explicit backup destination.');
  }
  diskPreflight(paths, options.backupPath);
  const backup = await backupMaintenanceDatabase(db, paths, options.backupPath);
  return maintenanceTransaction(db, (board) => {
    const replay = checkMigration(db, paths, board, options);
    if (replay) return replay;
    if (backup.boardId !== board.boardId || backup.generation !== board.generation
        || backup.boardRevision !== board.boardRevision || backup.eventSeq !== board.eventSeq) {
      throw new StorageError('CONFLICT', 'The validated backup does not match the locked board revision.');
    }
    // Free space is observation, not reservation; failure here leaves the valid recovery point intact.
    diskPreflight(paths, options.backupPath);
    const invalidated = invalidateLegacy(db);
    board.schemaVersion = 3;
    board.generation = randomUUID();
    board.replayFloor = board.eventSeq + 1;
    db.exec('PRAGMA user_version = 3;');
    const result = { fromVersion: 2, toVersion: 3, backup, ...invalidated };
    const envelope = commitRecord(db, board, options, 'migrate', result);
    // These checks execute before COMMIT, so either the entire migration passes or format 2 survives.
    verifyMaintenanceDatabase(db, paths.projectRoot);
    const integrity = db.prepare('PRAGMA integrity_check').all();
    if (integrity.length !== 1 || Object.values(integrity[0])[0] !== 'ok') {
      throw new StorageError('RECOVERY_REQUIRED', 'Post-migration full integrity verification failed.');
    }
    return envelope;
  });
}

/** Preserve allocation/history facts but do not promote pre-identity evidence into new authority. */
export function invalidateThree(db, board) {
  const repos = repositories(db, () => {});
  board.workspaces = [initializeMainWorkspace(board.projectRoot)];
  const tx = { board, ...repos };
  const previousPaths = new Map();
  for (const resource of repos.taskResources.list()) {
    if (resource.kind !== 'path') continue;
    const items = previousPaths.get(resource.taskId) ?? [];
    items.push(resource);
    previousPaths.set(resource.taskId, items);
  }
  let rebuiltPathResourceCount = 0;
  const needsReconcileTaskIds = [];
  const revokedGrantIds = [];
  for (const task of repos.tasks.list()) {
    const migrated = { ...task, workspaceId: 'main', resultValid: false,
      needsReconcile: true, actualExecutor: null, requiredSkills: [], responsibilities: [],
      allowLeadInline: false, acceptancePolicy: { requiredChecks: [] }, verification: null };
    rebuiltPathResourceCount += rebuildPathResources(tx, migrated, previousPaths.get(task.id));
    repos.tasks.put(migrated);
    needsReconcileTaskIds.push(task.id);
  }
  for (const submission of repos.submissions.list()) {
    repos.submissions.put({ ...submission, freezeValid: false,
      actualExecutor: null, executorKey: null });
  }
  for (const assignment of repos.assignments.list()) {
    repos.assignments.put({ ...assignment, actualExecutor: null, executorKey: null });
  }
  for (const worker of repos.workers.list()) {
    repos.workers.put({ ...worker, principal: null, runtimeIdentity: null, executorKey: null });
  }
  for (const grant of repos.grants.list()) {
    repos.grants.put({ ...grant, revoked: true });
    revokedGrantIds.push(grant.id);
  }
  return { needsReconcileTaskIds, revokedGrantIds, rebuiltPathResourceCount };
}

/** Back up before locking; all schema, identity, quiescence and backup checks repeat under lock. */
export async function migrateThreeToFour(db, paths, options) {
  const previous = maintenanceTransaction(db, board => checkMigration(db, paths, board, options));
  if (previous) return previous;
  if (typeof options.backupPath !== 'string' || !options.backupPath) {
    throw new StorageError('INVALID_INPUT', 'Migration requires an explicit backup destination.');
  }
  diskPreflight(paths, options.backupPath);
  const backup = await backupMaintenanceDatabase(db, paths, options.backupPath);
  return maintenanceTransaction(db, board => {
    const replay = checkMigration(db, paths, board, options);
    if (replay) return replay;
    if (backup.boardId !== board.boardId || backup.generation !== board.generation
        || backup.boardRevision !== board.boardRevision || backup.eventSeq !== board.eventSeq) {
      throw new StorageError('CONFLICT', 'The backup does not match the locked board revision.');
    }
    diskPreflight(paths, options.backupPath);
    const invalidated = invalidateThree(db, board);
    board.schemaVersion = 4;
    board.generation = randomUUID();
    board.replayFloor = board.eventSeq + 1;
    db.exec('PRAGMA user_version = 4;');
    const envelope = commitRecord(db, board, options, 'migrate',
      { fromVersion: 3, toVersion: 4, backup, ...invalidated });
    verifyDatabase(db, paths.projectRoot);
    const integrity = db.prepare('PRAGMA integrity_check').all();
    if (integrity.length !== 1 || Object.values(integrity[0])[0] !== 'ok') {
      throw new StorageError('RECOVERY_REQUIRED', 'Post-migration full integrity verification failed.');
    }
    return envelope;
  });
}
