// Explicit schema migration preserves historical unknowns before adding workspace authority.
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdir, mkdtemp, rm, readFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { createHash } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import * as storage from '../../packages/task-board/src/storage/index.mjs';
import { createLegacyBoard, legacyHash, legacyToken } from './fixtures/legacy-board.mjs';
import { invoke, secret, fixture } from './helpers.mjs';

// Hash all supplied semantic fields using the maintenance protocol's canonical ordering.
function digest(value) {
  const canonical = item => Array.isArray(item) ? item.map(canonical) :
    item && typeof item === 'object' ? Object.fromEntries(Object.keys(item).sort()
      .filter(key => key !== 'requestHash').map(key => [key, canonical(item[key])])) : item;
  return createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
}

// Build historical schema2 independently, then use real maintenance for each version transition.
async function historical(t) {
  const parent = resolve('_work/task-board/test-fixtures');
  await mkdir(parent, { recursive: true });
  const projectRoot = await mkdtemp(join(parent, 'execution-migration-'));
  let maintenance;
  t.after(async () => {
    maintenance?.close();
    await rm(projectRoot, { recursive: true, force: true });
  });
  const boardPath = join(projectRoot, 'board');
  await createLegacyBoard(projectRoot, boardPath);
  maintenance = storage.openMaintenanceBoard({ projectRoot, boardPath });
  let sequence = 0;
  const maintenanceToken = secret();
  const quiescence = { writersStopped: true, servicesStopped: true,
    evidenceRefs: ['fixture/execution-migration#stopped'] };
  const operation = extra => {
    const status = maintenance.status();
    const options = { leadId: 'lead', leadTokenHash: legacyHash,
      maintenanceId: 'execution-migration',
      maintenanceTokenHash: createHash('sha256').update(maintenanceToken).digest('hex'),
      quiescence, request: { operationId: `migration-${++sequence}`, actorId: 'lead',
        generation: status.generation, expectedBoardRevision: status.boardRevision }, ...extra };
    return { ...options, requestHash: digest(options) };
  };
  await maintenance.enter(operation({}));
  await maintenance.migrate(operation({ fromVersion: 2, toVersion: 3,
    backupPath: join(projectRoot, 'schema2.sqlite') }));
  return { projectRoot, boardPath, maintenance, operation, maintenanceToken, quiescence, close: () => {
    maintenance.close();
    maintenance = undefined;
  } };
}

// MIGRATION: 2→3 remains an explicit intermediate; 3→4 rotates generation and seeds main.
// Expected: old opaque evidence stays invalid, exact header agrees, backup remains schema3.
test('EXECUTION.migration.explicitThreeToFour', async t => {
  const f = await historical(t);
  assert.equal(f.maintenance.status().schemaVersion, 3);
  const before = f.maintenance.status();
  const backupPath = join(f.projectRoot, 'schema3.sqlite');
  const reply = await f.maintenance.migrate(f.operation({ fromVersion: 3, toVersion: 4,
    backupPath }));
  assert.equal(reply.result.toVersion, 4);
  assert.notEqual(reply.generation, before.generation);
  const current = f.maintenance.status();
  assert.equal(current.schemaVersion, 4);
  const db = new DatabaseSync(join(f.boardPath, 'board.sqlite'), { readOnly: true });
  try {
    assert.equal(db.prepare('PRAGMA user_version').get().user_version, 4);
    const board = JSON.parse(db.prepare('SELECT payload FROM boards WHERE id=1').get().payload);
    assert.equal(board.schemaVersion, 4);
    const workspaces = Array.isArray(board.workspaces) ? board.workspaces :
      Object.values(board.workspaces ?? {});
    const main = workspaces.find(item => item.id === 'main');
    assert.ok(main, 'Migration must register the existing default checkout');
    assert.equal(main.revision, 1);
    assert.equal(main.status, 'active');
    assert.ok(main.root);
    const task = JSON.parse(db.prepare('SELECT payload FROM tasks').get().payload);
    assert.equal(task.resultValid, false);
    assert.equal(task.needsReconcile, true);
    const grants = db.prepare('SELECT payload FROM grants').all();
    assert.ok(grants.every(row => JSON.parse(row.payload).revoked));
  } finally { db.close(); }
  const backupBytes = await readFile(backupPath);
  const old = new DatabaseSync(backupPath, { readOnly: true });
  try { assert.equal(old.prepare('PRAGMA user_version').get().user_version, 3); }
  finally { old.close(); }
  assert.deepEqual(await readFile(backupPath), backupBytes);
});


// MIGRATION-NEGATIVE: stale generation or wrong credentials cannot authorize schema changes.
// Expected: metadata and schema3 remain unchanged; each denied request rolls back atomically.
for (const condition of ['stale-generation', 'wrong-lead', 'missing-backup']) {
  test(`EXECUTION.migration.denialAtomicity.${condition}`, async t => {
    const f = await historical(t);
    const before = f.maintenance.status();
    let options = f.operation({ fromVersion: 3, toVersion: 4,
      backupPath: join(f.projectRoot, 'must-not-migrate.sqlite') });
    if (condition === 'stale-generation') {
      options.request.generation = 'obsolete-generation';
    } else if (condition === 'wrong-lead') {
      options.leadTokenHash = 'ff'.repeat(32);
    } else {
      delete options.backupPath;
    }
    options.requestHash = digest(options);
    await assert.rejects(() => f.maintenance.migrate(options));
    assert.deepEqual(f.maintenance.status(), before);
    assert.equal(f.maintenance.status().schemaVersion, 3);
  });
}

// MIGRATION-HEADER: contradictory metadata cannot pass the strict current opener.
// Expected: ordinary open rejects old schema3 without altering the historical database bytes.
test('EXECUTION.migration.oldSchemaOrdinaryOpenRejectedWithoutMutation', async t => {
  const f = await historical(t);
  f.close();
  const file = join(f.boardPath, 'board.sqlite');
  const checkpoint = new DatabaseSync(file);
  try { checkpoint.exec('PRAGMA wal_checkpoint(TRUNCATE)'); }
  finally { checkpoint.close(); }
  const before = await readFile(file);
  assert.throws(() => storage.openBoard({ projectRoot: f.projectRoot, boardPath: f.boardPath }),
    error => error.code === 'UNSUPPORTED_SCHEMA');
  assert.equal(digest(await readFile(file)), digest(before));
});



// RECOVERY: recover the pinned schema3 backup to a separate schema4 Board.
// Expected: source digest remains fixed, default workspace is registered, outputs need reconciliation.
test('EXECUTION.migration.restoreThreeToFourPreservesSource', async t => {
  const f = await historical(t);
  const backupPath = join(f.projectRoot, 'schema3-recovery.sqlite');
  const metadata = f.maintenance.status();
  await f.maintenance.migrate(f.operation({ fromVersion: 3, toVersion: 4, backupPath }));
  const bytes = await readFile(backupPath);
  const boardPath = join(f.projectRoot, 'restored');
  const options = { projectRoot: f.projectRoot, boardPath, backupPath,
    expectedSha256: createHash('sha256').update(bytes).digest('hex'),
    leadId: 'lead', leadTokenHash: legacyHash, request: { operationId: 'restore-schema3',
      actorId: 'lead', generation: metadata.generation,
      expectedBoardRevision: metadata.boardRevision } };
  options.requestHash = digest(options);
  const reply = await storage.restoreMigrationBackup3To4(options);
  assert.equal(reply.result.toVersion, 4);
  assert.notEqual(reply.generation, metadata.generation);
  const restored = storage.openBoard({ projectRoot: f.projectRoot, boardPath });
  try {
    assert.equal(restored.metadata().schemaVersion, 4);
    assert.equal(restored.metadata().recoveryRequired, true);
    assert.ok(restored.metadata().workspaces.some(item => item.id === 'main'));
    assert.ok(restored.snapshot().tasks.every(item => !item.resultValid));
  } finally { restored.close(); }
  assert.equal(createHash('sha256').update(await readFile(backupPath)).digest('hex'),
    options.expectedSha256);
});



// BE-03: migrated relative resource keys must conflict with new absolute physical file keys.
// Expected: either allocation order denies the second writer and preserves named resources.
for (const first of ['legacy', 'new']) {
  test(`EXECUTION.migration.legacyResourceKeysConflict.${first}First`, async t => {
    const f = await historical(t);
    const historicalReservation = { id: 'historical-path-reservation', taskId: 'legacy-task',
      assignmentId: 'legacy-assignment', active: false, kind: 'path', key: 'src/legacy.mjs',
      mode: 'exclusive', fixtureEvidence: 'Preserve exact inactive history' };
    const fixtureDb = new DatabaseSync(join(f.boardPath, 'board.sqlite'));
    try {
      const task = JSON.parse(fixtureDb.prepare('SELECT payload FROM tasks').get().payload);
      task.state = 'planned';
      fixtureDb.prepare('UPDATE tasks SET payload=?,state=? WHERE id=?')
        .run(JSON.stringify(task), task.state, task.id);
      for (const resource of [
        { id: 'legacy-path', taskId: task.id, kind: 'path', key: 'src/legacy.mjs', mode: 'exclusive' },
        { id: 'legacy-named', taskId: task.id, kind: 'resource', key: 'compiler', mode: 'exclusive' },
      ]) {
        fixtureDb.prepare('INSERT INTO task_resources(id,payload,taskId) VALUES(?,?,?)')
          .run(resource.id, JSON.stringify(resource), resource.taskId);
      }
      fixtureDb.prepare('INSERT INTO reservations(id,payload,taskId,assignmentId,active) VALUES(?,?,?,?,?)')
        .run(historicalReservation.id, JSON.stringify(historicalReservation), 'legacy-task',
          'legacy-assignment', 0);
    } finally { fixtureDb.close(); }
    const migrated = await f.maintenance.migrate(f.operation({ fromVersion: 3, toVersion: 4,
      backupPath: join(f.projectRoot, 'old3-resources.sqlite') }));
    await f.maintenance.exit(f.operation({}));
    f.close();
    let sequence = 0;
    const raw = (operation, payload = {}) => invoke(f.projectRoot, f.boardPath, operation,
      { operationId: `resource-migration-${++sequence}`, actorId: 'lead', leadToken: legacyToken,
        generation: migrated.generation, ...payload });
    const ok = async (operation, payload) => {
      const response = await raw(operation, payload);
      assert.equal(response.code, 0, `${operation}: ${JSON.stringify(response.reply)}`);
      return response.reply;
    };
    let legacy = (await ok('show', { taskId: 'legacy-task' })).result.task;
    await ok('reconcile', { taskId: legacy.id, taskRevision: legacy.taskRevision,
      expectedInputRevision: legacy.inputRevision, decision: 'confirm', reason: 'Confirm migrated input',
      sourceObservation: { available: true, revision: 'fixture-current',
        evidenceRefs: ['fixture/source#current'] } });
    legacy = (await ok('show', { taskId: legacy.id })).result.task;
    await ok('approve', { taskId: legacy.id, taskRevision: legacy.taskRevision });
    await ok('add', { task: { id: 'new-task', title: 'new-task', outcome: 'Same physical output',
      sourceRefs: ['fixture/work#new'], acceptanceRefs: ['fixture/accept#new'],
      eligibleRoles: ['backend'], scope: { read: [], write: ['src/legacy.mjs'] },
      resources: [], dependencies: [] } });
    await ok('approve', { taskId: 'new-task', taskRevision: 1 });
    const requests = {};
    for (const [label, taskId] of [['legacy', 'legacy-task'], ['new', 'new-task']]) {
      const workerToken = secret();
      await ok('register', { worker: { id: label, hostId: `fixture-${label}`, role: 'backend',
        mode: 'direct', capabilities: ['write'], workerToken } });
      const task = (await ok('show', { taskId })).result.task;
      await ok('grant', { taskId, workerId: label, approvalRevision: task.approvalRevision });
      requests[label] = { taskId, taskRevision: task.taskRevision, actorId: label,
        workerToken, claimToken: secret() };
    }
    const claimed = await raw('claim', requests[first]);
    assert.equal(claimed.code, 0, JSON.stringify(claimed.reply));
    const before = (await ok('inspect')).result;
    const second = first === 'legacy' ? 'new' : 'legacy';
    const denied = await raw('claim', requests[second]);
    assert.equal(denied.reply.error?.code, 'SCOPE_CONFLICT', JSON.stringify(denied.reply));
    assert.deepEqual((await ok('inspect')).result, before);
    const db = new DatabaseSync(join(f.boardPath, 'board.sqlite'), { readOnly: true });
    try {
      const resources = db.prepare('SELECT payload FROM task_resources WHERE taskId=?')
        .all('legacy-task').map(row => JSON.parse(row.payload));
      assert.deepEqual(resources.find(item => item.kind === 'resource'),
        { id: 'legacy-named', taskId: 'legacy-task', kind: 'resource', key: 'compiler', mode: 'exclusive' });
      const history = db.prepare('SELECT payload FROM reservations WHERE id=?')
        .get(historicalReservation.id).payload;
      assert.equal(history, JSON.stringify(historicalReservation));
    } finally { db.close(); }
  });
}



// BE-03-ROLLBACK: unsafe historical scopes must abort canonical resource migration atomically.
// Expected: no schema transition or partial task/resource rewrite after path escape rejection.
test('EXECUTION.migration.unsafeHistoricalScopeRollsBack', async t => {
  const f = await historical(t);
  const db = new DatabaseSync(join(f.boardPath, 'board.sqlite'));
  try {
    const task = JSON.parse(db.prepare('SELECT payload FROM tasks').get().payload);
    task.scope.write = ['../escaped.mjs'];
    db.prepare('UPDATE tasks SET payload=? WHERE id=?').run(JSON.stringify(task), task.id);
  } finally { db.close(); }
  const before = f.maintenance.status();
  await assert.rejects(() => f.maintenance.migrate(f.operation({ fromVersion: 3, toVersion: 4,
    backupPath: join(f.projectRoot, 'unsafe-scope-backup.sqlite') })),
    error => ['UNSAFE_PATH', 'INVALID_INPUT'].includes(error.code));
  assert.deepEqual(f.maintenance.status(), before);
  assert.equal(f.maintenance.status().schemaVersion, 3);
  const after = new DatabaseSync(join(f.boardPath, 'board.sqlite'), { readOnly: true });
  try {
    const task = JSON.parse(after.prepare('SELECT payload FROM tasks').get().payload);
    assert.deepEqual(task.scope.write, ['../escaped.mjs']);
    assert.equal(after.prepare('PRAGMA user_version').get().user_version, 3);
  } finally { after.close(); }
});


// LEGACY-HOLD: an unexplained active relative reservation cannot be guessed into a safe new key.
// Expected: new allocation requires recovery; it never repairs or silently bypasses the old holder.
test('EXECUTION.migration.activeRelativeHoldRequiresRecovery', async t => {
  const f = await fixture(t);
  await f.worker('holder');
  await f.worker('next');
  await f.task('held', 'src/shared.mjs');
  await f.task('next', 'src/shared.mjs');
  await f.grant('holder', 'held');
  await f.grant('next', 'next');
  assert.equal((await f.claim('holder', 'held')).code, 0);
  const db = new DatabaseSync(join(f.board, 'board.sqlite'));
  try {
    const row = db.prepare('SELECT id,payload FROM reservations WHERE active=1').get();
    const held = JSON.parse(row.payload);
    held.key = 'src/shared.mjs';
    db.prepare('UPDATE reservations SET payload=? WHERE id=?').run(JSON.stringify(held), row.id);
  } finally { db.close(); }
  const before = (await f.ok('inspect')).result;
  const denied = await f.claim('next', 'next');
  assert.equal(denied.reply.error?.code, 'RECOVERY_REQUIRED', JSON.stringify(denied.reply));
  assert.deepEqual((await f.ok('inspect')).result, before);
});


// BE-04-MIGRATE: the user-facing CLI must route the explicit3→4 step, not only the storage API.
// Expected: unsupported pairs are unchanged; genuine3 input migrates through authenticated session.
test('EXECUTION.migration.cliThreeToFourLifecycle', async t => {
  const f = await historical(t);
  const status = f.maintenance.status();
  f.close();
  const common = { actorId: 'lead', leadToken: legacyToken, generation: status.generation,
    expectedBoardRevision: status.boardRevision, maintenanceId: 'execution-migration',
    maintenanceToken: f.maintenanceToken, quiescence: f.quiescence };
  const invalid = await invoke(f.projectRoot, f.boardPath, 'migrate', { ...common,
    operationId: 'unsupported-step', fromVersion: 3, toVersion: 5,
    backupPath: join(f.projectRoot, 'unsupported.sqlite') });
  assert.equal(invalid.reply.error?.code, 'UNSUPPORTED_SCHEMA');
  const unchanged = await invoke(f.projectRoot, f.boardPath, 'maintenance-status', {});
  assert.equal(unchanged.reply.result.boardRevision, status.boardRevision);
  const migrated = await invoke(f.projectRoot, f.boardPath, 'migrate', { ...common,
    operationId: 'cli3-to4', fromVersion: 3, toVersion: 4,
    backupPath: join(f.projectRoot, 'cli3-backup.sqlite') });
  assert.equal(migrated.code, 0, JSON.stringify(migrated.reply));
  assert.equal(migrated.reply.result.toVersion, 4);
  const exited = await invoke(f.projectRoot, f.boardPath, 'exit-maintenance', { ...common,
    operationId: 'cli4-exit', generation: migrated.reply.generation,
    expectedBoardRevision: migrated.reply.boardRevision });
  assert.equal(exited.code, 0, JSON.stringify(exited.reply));
  const inspected = await invoke(f.projectRoot, f.boardPath, 'inspect', {
    actorId: 'lead', leadToken: legacyToken, generation: migrated.reply.generation });
  assert.equal(inspected.code, 0, JSON.stringify(inspected.reply));
});

// BE-04-RESTORE: the public recovery operation must publish a separate reconciliable schema4 Board.
// Expected: genuine3 backup stays byte-identical while actual CLI restores current target metadata.
test('EXECUTION.migration.cliRestoreThreeToFourLifecycle', async t => {
  const f = await historical(t);
  const status = f.maintenance.status();
  const backupPath = join(f.projectRoot, 'restore-cli-source3.sqlite');
  await f.maintenance.migrate(f.operation({ fromVersion: 3, toVersion: 4, backupPath }));
  f.close();
  const before = await readFile(backupPath);
  const target = join(f.projectRoot, 'cli-restored4');
  const restored = await invoke(f.projectRoot, target, 'restore-migration-backup-3-to-4', {
    operationId: 'cli-restore3-to4', actorId: 'lead', leadToken: legacyToken,
    generation: status.generation, expectedBoardRevision: status.boardRevision, backupPath,
    expectedSha256: createHash('sha256').update(before).digest('hex') });
  assert.equal(restored.code, 0, JSON.stringify(restored.reply));
  assert.equal(restored.reply.result.toVersion, 4);
  const inspected = await invoke(f.projectRoot, target, 'inspect', { actorId: 'lead',
    leadToken: legacyToken, generation: restored.reply.generation });
  assert.equal(inspected.code, 0, JSON.stringify(inspected.reply));
  assert.equal(createHash('sha256').update(await readFile(backupPath)).digest('hex'),
    createHash('sha256').update(before).digest('hex'));
});
