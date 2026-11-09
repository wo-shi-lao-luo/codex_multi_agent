// Physical maintenance and explicit legacy-backup recovery: real SQLite, isolated project only.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, mkdtemp, readFile, rm, writeFile, copyFile, access } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import fs from 'node:fs';
import * as storage from '../../packages/task-board/src/storage/index.mjs';
import { connectMaintenance, verifyMaintenanceDatabase }
  from '../../packages/task-board/src/storage/connection.mjs';
import { repositories } from '../../packages/task-board/src/storage/repositories.mjs';
import { inspectBackup } from '../../packages/task-board/src/storage/inspection.mjs';
import { createLegacyBoard, legacyHash } from './fixtures/legacy-board.mjs';

const hash = bytes => createHash('sha256').update(bytes).digest('hex');
// Only the top-level requestHash is omitted; paths, limits and nested semantics remain bound.
function digest(options) {
  const canonical = value => Array.isArray(value) ? value.map(canonical)
    : value && typeof value === 'object'
      ? Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])]))
      : value;
  const { requestHash, ...semantic } = options;
  return hash(JSON.stringify(canonical(semantic)));
}

// Allocate one disposable project and close all registered handles before owner-scoped cleanup.
async function fixture(t) {
  const parent = resolve('_work/task-board/test-fixtures');
  await mkdir(parent, { recursive: true });
  const projectRoot = await mkdtemp(join(parent, 'lifecycle-maintenance-recovery-'));
  const handles = [];
  t.after(async () => {
    for (const handle of handles.reverse()) handle.close();
    await rm(projectRoot, { recursive: true, force: true });
  });
  const board = storage.initializeBoard({ projectRoot, boardPath: join(projectRoot, 'current'),
    leadId: 'lead', leadTokenHash: legacyHash });
  handles.push(board);
  let sequence = 0;
  function options(extra, metadata = board.metadata()) {
    const value = { request: { operationId: `recovery-${++sequence}`, actorId: 'lead',
      generation: metadata.generation, expectedBoardRevision: metadata.boardRevision },
    leadId: 'lead', leadTokenHash: legacyHash, ...extra };
    return { ...value, requestHash: digest(value) };
  }
  // Controlled business facts create real WAL frames, not mock checkpoint observations.
  const seed = { ...options({}), operation: 'fixture-seed' };
  const receipt = board.transactOperation(seed, tx => {
    tx.tasks.put({ id: 'active', taskRevision: 1, state: 'running', executionRevision: 1 });
    tx.audit('fixture-seed', { taskId: 'active', evidenceRefs: ['fixture/history#retained'] });
    return { retained: true };
  });
  return { board, projectRoot, handles, options,
    replay: () => assert.deepEqual(board.transactOperation(seed, () => assert.fail('receipt lost')),
      receipt) };
}

// Scenario: PASSIVE checkpoint observes real WAL while unrelated work is active.
// Expected: truthful counters/deferred result; business revision/history/receipt remain unchanged.
test('recovery.passiveCheckpoint', async t => {
  const f = await fixture(t);
  assert.equal(typeof f.board.checkpoint, 'function', 'Missing checkpoint storage capability');
  const before = f.board.snapshot();
  const history = f.board.history({ taskId: 'active' });
  const options = f.options({ mode: 'PASSIVE' });
  for (let attempt = 0; attempt < 2; attempt++) {
    const result = await f.board.checkpoint(options);
    assert.equal(result.operationId, options.request.operationId);
    assert.equal(result.mode, 'PASSIVE');
    assert.equal(result.receiptCommitted, false);
    assert.equal(result.businessStateChanged, false);
    assert.ok(Number.isInteger(result.logFrames));
    assert.ok(Number.isInteger(result.checkpointedFrames));
    assert.equal(result.deferred, Boolean(result.busy)
      || result.checkpointedFrames < result.logFrames);
    assert.deepEqual(f.board.snapshot(), before);
    assert.deepEqual(f.board.history({ taskId: 'active' }), history);
    f.replay();
  }
});

// Scenario: a real closed backup is compressed, verified-decompressed, then really restored.
// Expected: byte/hash equality, source retention, new-target conflicts and usable new generation.
test('recovery.gzipRoundTripThenRestore', async t => {
  const f = await fixture(t);
  assert.equal(typeof f.board.compressBackup, 'function', 'Missing compressBackup capability');
  assert.equal(typeof f.board.decompressBackup, 'function', 'Missing decompressBackup capability');
  const before = f.board.snapshot();
  const backup = await f.board.backup(join(f.projectRoot, 'source.sqlite'));
  const source = await readFile(backup.path);
  const maxUncompressedBytes = source.length * 2;
  const gzipOptions = f.options({ sourcePath: backup.path,
    destination: join(f.projectRoot, 'backup.sqlite.gz'), expectedSha256: hash(source),
    maxUncompressedBytes });
  const compressed = await f.board.compressBackup(gzipOptions);
  assert.equal(compressed.receiptCommitted, false);
  assert.equal(compressed.sourceRetained, true);
  const compressedBytes = await readFile(compressed.path);
  assert.equal(hash(compressedBytes), compressed.sha256);
  const expanded = await f.board.decompressBackup(f.options({ sourcePath: compressed.path,
    destination: join(f.projectRoot, 'expanded.sqlite'), expectedSha256: compressed.sha256,
    expectedDatabaseSha256: hash(source), maxUncompressedBytes }));
  assert.equal(expanded.receiptCommitted, false);
  assert.deepEqual(await readFile(expanded.path), source);
  assert.deepEqual(await readFile(backup.path), source);
  assert.deepEqual(f.board.snapshot(), before);
  f.replay();
  await assert.rejects(async () => f.board.compressBackup(gzipOptions),
    error => error.code === 'CONFLICT');
  const restored = await storage.restoreBoard({ projectRoot: f.projectRoot,
    boardPath: join(f.projectRoot, 'restored'), backupPath: expanded.path,
    leadId: 'lead', leadTokenHash: legacyHash });
  f.handles.push(restored);
  assert.notEqual(restored.metadata().generation, before.board.generation);
  assert.deepEqual(restored.snapshot().tasks, before.tasks.map(task => ({
    ...task, resultValid: false, cleanupPending: false,
  })));
  assert.deepEqual(restored.history({ taskId: 'active' }).items,
    f.board.history({ taskId: 'active' }).items);
});

// Scenario: migrate true schema2, exit original session, restore its schema2 backup separately.
// Expected: new generation/unknown counters/revoked grants, no inherited maintenance authority.
test('recovery.explicitLegacyBackupRestore', async t => {
  const f = await fixture(t);
  assert.equal(typeof storage.restoreMigrationBackup2To3, 'function',
    'Missing explicit schema2-backup recovery export');
  const boardPath = join(f.projectRoot, 'historical');
  const legacy = await createLegacyBoard(f.projectRoot, boardPath);
  const maintenance = storage.openMaintenanceBoard({ projectRoot: f.projectRoot, boardPath });
  f.handles.push(maintenance);
  const session = { maintenanceId: 'original-session', maintenanceTokenHash: '64'.repeat(32),
    quiescence: { writersStopped: true, servicesStopped: true,
      evidenceRefs: ['fixture/stop#isolated'] } };
  await maintenance.enter(f.options(session, maintenance.status()));
  // Migration backs up this entered state; pre-entry fixture cursors are not source cursors.
  const backupSource = maintenance.status();
  const backupPath = join(f.projectRoot, 'before-migration.sqlite');
  await maintenance.migrate(f.options({ ...session, fromVersion: 2, toVersion: 3, backupPath },
    backupSource));
  await maintenance.exit(f.options(session, maintenance.status()));
  const source = await readFile(backupPath);
  const target = join(f.projectRoot, 'legacy-restored');
  const options = f.options({ projectRoot: f.projectRoot, boardPath: target, backupPath,
    expectedSha256: hash(source) }, backupSource);
  const result = await storage.restoreMigrationBackup2To3(options);
  assert.equal(result.result.receiptCommitted, false);
  assert.equal(result.result.sourceRetained, true);
  assert.notEqual(result.generation, backupSource.generation);
  assert.equal(result.boardRevision, backupSource.boardRevision + 1);
  assert.equal(result.eventSeq, backupSource.eventSeq + 1);
  // Recovery2→3 retains historical unknown counters; current ordinary schema4 open must reject3.
  assert.throws(() => storage.openBoard({ projectRoot: f.projectRoot, boardPath: target }),
    error => error.code === 'UNSUPPORTED_SCHEMA');
  const restored = connectMaintenance(join(target, 'board.sqlite'), true);
  f.handles.push(restored);
  const rows = repositories(restored);
  const snapshot = { board: verifyMaintenanceDatabase(restored, f.projectRoot),
    tasks: rows.tasks.list(), submissions: rows.submissions.list(), grants: rows.grants.list() };
  assert.equal(snapshot.board.recoveryRequired, true);
  assert.equal(snapshot.board.replayFloor, result.eventSeq);
  assert.equal(snapshot.board.maintenance, null);
  const task = snapshot.tasks.find(item => item.id === 'legacy-task');
  assert.equal(task.state, legacy.task.state);
  assert.equal(task.repairAttempts, legacy.task.repairAttempts);
  for (const counter of ['inputRevision', 'executionRevision', 'freezeRevision', 'resultRevision']) {
    assert.equal(task[counter], null);
  }
  assert.equal(task.inputValid, false);
  assert.equal(task.resultValid, false);
  assert.equal(task.needsReconcile, true);
  assert.equal(snapshot.submissions[0].inputRevision, legacy.submission.inputRevision);
  assert.equal(snapshot.submissions[0].freezeValid, false);
  assert.equal(snapshot.grants[0].revoked, true);
  assert.deepEqual(await readFile(backupPath), source);
  const restoredMaintenance = storage.openMaintenanceBoard({ projectRoot: f.projectRoot,
    boardPath: target });
  f.handles.push(restoredMaintenance);
  await assert.rejects(async () => restoredMaintenance.exit(
    f.options(session, restoredMaintenance.status())), error => error.code === 'UNAUTHORIZED');
  await assert.rejects(async () => storage.restoreMigrationBackup2To3(options),
    error => error.code === 'CONFLICT');
});

// Scenario: wrong authority/digest, truncated gzip and oversize expansion reach physical APIs.
// Expected: rejection never publishes a target or changes source bytes, business history or receipts.
test('recovery.physicalNegativePreservation', async t => {
  const f = await fixture(t);
  const before = f.board.snapshot();
  const history = f.board.history({ taskId: 'active' });
  for (const patch of [{ leadTokenHash: '00'.repeat(32) }, { requestHash: '00'.repeat(32) }]) {
    const options = f.options({ mode: 'PASSIVE', ...patch });
    if (patch.requestHash) options.requestHash = patch.requestHash;
    await assert.rejects(async () => f.board.checkpoint(options),
      error => error.code === (patch.leadTokenHash ? 'UNAUTHORIZED' : 'INVALID_INPUT'));
  }
  const backup = await f.board.backup(join(f.projectRoot, 'negative-source.sqlite'));
  const source = await readFile(backup.path);
  const base = { sourcePath: backup.path, expectedSha256: hash(source),
    maxUncompressedBytes: source.length * 2 };
  const compressed = await f.board.compressBackup(f.options({ ...base,
    destination: join(f.projectRoot, 'negative-source.gz') }));
  const gzip = await readFile(compressed.path);
  const truncatedPath = join(f.projectRoot, 'truncated.gz');
  const truncated = gzip.subarray(0, Math.floor(gzip.length / 2));
  await writeFile(truncatedPath, truncated);
  const cases = [
    { id: 'hash', method: 'compressBackup', input: { ...base, expectedSha256: '00'.repeat(32) },
      code: 'CONFLICT' },
    { id: 'auth', method: 'compressBackup', input: { ...base, leadTokenHash: '00'.repeat(32) },
      code: 'UNAUTHORIZED' },
    { id: 'oversize', method: 'decompressBackup', input: { sourcePath: compressed.path,
      expectedSha256: hash(gzip), expectedDatabaseSha256: hash(source), maxUncompressedBytes: 1 },
      code: 'LIMIT_EXCEEDED' },
    { id: 'truncated', method: 'decompressBackup', input: { sourcePath: truncatedPath,
      expectedSha256: hash(truncated), expectedDatabaseSha256: hash(source),
      maxUncompressedBytes: source.length * 2 } },
  ];
  for (const scenario of cases) {
    const destination = join(f.projectRoot, `rejected-${scenario.id}.artifact`);
    await assert.rejects(async () => f.board[scenario.method](f.options({
      ...scenario.input, destination,
    })), error => scenario.code ? error.code === scenario.code : Boolean(error.code));
    await assert.rejects(access(destination), error => error.code === 'ENOENT');
    assert.deepEqual(await readFile(backup.path), source);
    assert.deepEqual(await readFile(compressed.path), gzip);
    assert.deepEqual(f.board.snapshot(), before);
    assert.deepEqual(f.board.history({ taskId: 'active' }), history);
    f.replay();
  }
});

// Scenario: legacy recovery sees active old holders, wrong source authority/hash or schema3 input.
// Expected: reject before publishing any target and retain the exact pinned source file.
test('recovery.legacyNegativeRoutes', async t => {
  const f = await fixture(t);
  const activePath = join(f.projectRoot, 'active-legacy');
  const legacy = await createLegacyBoard(f.projectRoot, activePath, { active: true });
  const sourceFile = join(activePath, 'board.sqlite');
  const source = await readFile(sourceFile);
  const cases = [
    { id: 'active', patch: {}, code: 'MAINTENANCE_REQUIRED' },
    { id: 'auth', patch: { leadTokenHash: '00'.repeat(32) }, code: 'UNAUTHORIZED' },
    { id: 'hash', patch: { expectedSha256: '00'.repeat(32) }, code: 'CONFLICT' },
  ];
  for (const scenario of cases) {
    // Each rejection owns a closed copy: SQLite may create read-sidecars when examining WAL input.
    // Keep failed-attempt artifacts intact rather than deleting sidecars to force another path.
    const backupPath = join(f.projectRoot, `active-legacy-${scenario.id}.sqlite`);
    await copyFile(sourceFile, backupPath);
    const boardPath = join(f.projectRoot, `legacy-rejected-${scenario.id}`);
    const options = f.options({ projectRoot: f.projectRoot, boardPath, backupPath,
      expectedSha256: hash(source), ...scenario.patch }, legacy.board);
    await assert.rejects(async () => storage.restoreMigrationBackup2To3(options),
      error => error.code === scenario.code);
    await assert.rejects(access(boardPath), error => error.code === 'ENOENT');
    assert.deepEqual(await readFile(backupPath), source);
  }
  const current = await f.board.backup(join(f.projectRoot, 'schema3-backup.sqlite'));
  const target = join(f.projectRoot, 'wrong-route');
  await assert.rejects(async () => storage.restoreMigrationBackup2To3(f.options({
    projectRoot: f.projectRoot, boardPath: target, backupPath: current.path,
    expectedSha256: current.sha256,
  })), error => error.code === 'UNSUPPORTED_SCHEMA');
  await assert.rejects(access(target), error => error.code === 'ENOENT');
});

// Regression scenario: validating a closed WAL-format source rejects active historical holders.
// Expected: observational rejection preserves main bytes and creates no source sidecars.
test('recovery.rejectedLegacySourceCreatesNoSidecars', async t => {
  const f = await fixture(t);
  const historical = join(f.projectRoot, 'sidecar-historical');
  const legacy = await createLegacyBoard(f.projectRoot, historical, { active: true });
  const backupPath = join(f.projectRoot, 'sidecar-regression-source.sqlite');
  await copyFile(join(historical, 'board.sqlite'), backupPath);
  const source = await readFile(backupPath);
  for (const suffix of ['-wal', '-shm', '-journal']) {
    await assert.rejects(access(backupPath + suffix), error => error.code === 'ENOENT');
  }
  await assert.rejects(async () => storage.restoreMigrationBackup2To3(f.options({
    projectRoot: f.projectRoot, boardPath: join(f.projectRoot, 'sidecar-rejected-target'),
    backupPath, expectedSha256: hash(source),
  }, legacy.board)), error => error.code === 'MAINTENANCE_REQUIRED');
  assert.deepEqual(await readFile(backupPath), source);
  for (const suffix of ['-wal', '-shm', '-journal']) {
    await assert.rejects(access(backupPath + suffix), error => error.code === 'ENOENT',
      `Rejected recovery must not create source${suffix}`);
  }
});

// Regression scenario: gzip conversion verifies a closed schema3 backup directly.
// Expected: verification/conversion keeps source bytes and its initially absent sidecars unchanged.
test('recovery.gzipVerificationCreatesNoSourceSidecars', async t => {
  const f = await fixture(t);
  const backup = await f.board.backup(join(f.projectRoot, 'gzip-sidecar-source.sqlite'));
  const source = await readFile(backup.path);
  for (const suffix of ['-wal', '-shm', '-journal']) {
    await assert.rejects(access(backup.path + suffix), error => error.code === 'ENOENT');
  }
  await f.board.compressBackup(f.options({ sourcePath: backup.path,
    destination: join(f.projectRoot, 'gzip-sidecar-output.gz'), expectedSha256: hash(source),
    maxUncompressedBytes: source.length * 2 }));
  assert.deepEqual(await readFile(backup.path), source);
  for (const suffix of ['-wal', '-shm', '-journal']) {
    await assert.rejects(access(backup.path + suffix), error => error.code === 'ENOENT',
      `Gzip verification must not create source${suffix}`);
  }
});

// Regression scenarios: ordinary schema3 restore succeeds or rejects incorrect Lead credentials.
// Expected: both paths preserve the closed backup's exact main bytes and absent source sidecars.
for (const authorized of [true, false]) {
  test(`recovery.normalRestoreSourceFamily.${authorized ? 'authorized' : 'wrongLead'}`, async t => {
    const f = await fixture(t);
    const backup = await f.board.backup(join(f.projectRoot, 'normal-restore-source.sqlite'));
    const source = await readFile(backup.path);
    for (const suffix of ['-wal', '-shm', '-journal']) {
      await assert.rejects(access(backup.path + suffix), error => error.code === 'ENOENT');
    }
    const options = { projectRoot: f.projectRoot, boardPath: join(f.projectRoot, 'normal-target'),
      backupPath: backup.path, leadId: 'lead',
      leadTokenHash: authorized ? legacyHash : '00'.repeat(32) };
    if (authorized) {
      const restored = await storage.restoreBoard(options);
      f.handles.push(restored);
      assert.notEqual(restored.metadata().generation, f.board.metadata().generation);
      const second = await storage.restoreBoard({ ...options,
        boardPath: join(f.projectRoot, 'normal-second-target') });
      f.handles.push(second);
      assert.notEqual(second.metadata().generation, restored.metadata().generation);
      assert.deepEqual(second.snapshot().tasks, restored.snapshot().tasks);
    } else {
      await assert.rejects(async () => storage.restoreBoard(options),
        error => error.code === 'UNAUTHORIZED');
      await assert.rejects(access(options.boardPath), error => error.code === 'ENOENT');
    }
    assert.deepEqual(await readFile(backup.path), source);
    for (const suffix of ['-wal', '-shm', '-journal']) {
      await assert.rejects(access(backup.path + suffix), error => error.code === 'ENOENT',
        `Normal restore must not create source${suffix}`);
    }
  });
}

// Scenario: private inspection rejects wrong auth or a controlled callback error.
// Expected: each actually allocated scratch directory is removed; sources and business facts survive.
test('recovery.inspectionScratchCleanupOnRejection', async t => {
  const f = await fixture(t);
  const backup = await f.board.backup(join(f.projectRoot, 'scratch-source.sqlite'));
  const source = await readFile(backup.path);
  const before = f.board.snapshot();
  const allocated = [];
  const original = fs.mkdtempSync;
  // Observe only directory identities created by these calls; never enumerate or sweep temp storage.
  fs.mkdtempSync = function(prefix, ...args) {
    const directory = original.call(this, prefix, ...args);
    if (String(prefix).includes('task-board-inspect-')) allocated.push(directory);
    return directory;
  };
  try {
    await assert.rejects(async () => storage.restoreBoard({ projectRoot: f.projectRoot,
      boardPath: join(f.projectRoot, 'scratch-auth-rejected'), backupPath: backup.path,
      leadId: 'lead', leadTokenHash: '00'.repeat(32) }), error => error.code === 'UNAUTHORIZED');
    const controlled = new Error('Controlled test callback rejection');
    await assert.rejects(async () => inspectBackup(backup.path, f.projectRoot, () => {
      throw controlled;
    }), error => error === controlled);
  } finally {
    fs.mkdtempSync = original;
  }
  assert.ok(allocated.length >= 2, 'Both rejecting calls must really allocate private inspection');
  for (const directory of allocated) {
    await assert.rejects(access(directory), error => error.code === 'ENOENT');
  }
  assert.deepEqual(await readFile(backup.path), source);
  for (const suffix of ['-wal', '-shm', '-journal']) {
    await assert.rejects(access(backup.path + suffix), error => error.code === 'ENOENT');
  }
  assert.deepEqual(f.board.snapshot(), before);
  f.replay();
});

// Regression scenario: restore a strict3 backup captured in a maintenance session that later exited.
// Expected: recovery clears that session; even using the restored generation, old session cannot exit.
test('recovery.normalRestoreRevokesOriginalMaintenanceSession', async t => {
  const f = await fixture(t);
  const original = storage.openMaintenanceBoard({ projectRoot: f.projectRoot,
    boardPath: join(f.projectRoot, 'current') });
  f.handles.push(original);
  const session = { maintenanceId: 'ended-source-session', maintenanceTokenHash: '95'.repeat(32),
    quiescence: { writersStopped: true, servicesStopped: true,
      evidenceRefs: ['fixture/stop#old-maintenance-session'] } };
  await original.enter(f.options(session, original.status()));
  const backup = await f.board.backup(join(f.projectRoot, 'active-session-backup.sqlite'));
  await original.exit(f.options(session, original.status()));
  assert.equal(original.status().maintenance, null);
  const boardPath = join(f.projectRoot, 'restored-session-probe');
  const restored = await storage.restoreBoard({ projectRoot: f.projectRoot, boardPath,
    backupPath: backup.path, leadId: 'lead', leadTokenHash: legacyHash });
  f.handles.push(restored);
  const metadata = restored.metadata();
  assert.notEqual(metadata.generation, backup.generation);
  assert.equal(metadata.recoveryRequired, true);
  const maintenance = storage.openMaintenanceBoard({ projectRoot: f.projectRoot, boardPath });
  f.handles.push(maintenance);
  // Bind the probe to the NEW generation, so a stale-generation guard cannot mask session revival.
  const request = f.options(session, maintenance.status());
  let denied;
  let accepted = false;
  try { accepted = (await maintenance.exit(request)).ok === true; }
  catch (error) { denied = error.code; }
  t.diagnostic(`Restored source-session present=${Boolean(metadata.maintenance)}, `
    + `old session exit accepted=${accepted}, denial=${denied ?? 'none'}`);
  assert.equal(metadata.maintenance, null, 'Restoration must not inherit source maintenance authority');
  assert.equal(denied, 'UNAUTHORIZED');
  assert.equal(accepted, false);
});
