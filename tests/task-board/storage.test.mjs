// Recovery tests use production storage, actual SQLite backup and externally killed child processes.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdir, mkdtemp, rm, readFile, access } from 'node:fs/promises';
import { DatabaseSync } from 'node:sqlite';
import { resolve, join } from 'node:path';
import { createHash } from 'node:crypto';
import { atomicMutation } from './atomic-fixture.mjs';

async function storageFixture(t) {
  const storage = await import('../../packages/task-board/src/storage/index.mjs');
  const parent = resolve('_work/task-board/test-fixtures');
  await mkdir(parent, { recursive: true });
  const projectRoot = await mkdtemp(join(parent, 'storage-'));
  t.after(() => rm(projectRoot, { recursive: true, force: true }));
  const boardPath = join(projectRoot, 'board');
  const board = storage.initializeBoard({ projectRoot, boardPath, leadId: 'lead',
    leadTokenHash: createHash('sha256').update('fixture-lead').digest('hex') });
  const metadata = board.metadata();
  board.close();
  return { ...storage, projectRoot, boardPath, metadata };
}

async function killAtBarrier(f, stage) {
  const child = spawn(process.execPath, [resolve('tests/task-board/crash-child.mjs'),
    f.projectRoot, f.boardPath, stage, f.metadata.generation],
  { stdio: ['ignore', 'pipe', 'pipe'] });
  let output = '';
  let errors = '';
  child.stderr.on('data', data => { errors += data; });
  let timer;
  try {
    await new Promise((done, reject) => {
      timer = setTimeout(() => reject(new Error(`Barrier timeout: ${errors}`)), 10000);
      child.stdout.on('data', data => {
        output += data;
        if (output.includes('COMMIT_BARRIER\n')) done();
      });
      child.on('error', reject);
      child.on('exit', code => reject(new Error(`Child exited before kill: ${code}: ${errors}`)));
    });
  } finally {
    clearTimeout(timer);
    const exited = new Promise(done => child.once('close', done));
    child.kill();
    await exited;
  }
}

for (const stage of ['beforeCommit', 'afterCommit']) {
  // CASE-08: a real kill must yield an entirely absent or committed receipt/event mutation.
  test(`P0.crashReplay.${stage}`, async t => {
    const f = await storageFixture(t);
    await killAtBarrier(f, stage);
    const board = f.openBoard({ projectRoot: f.projectRoot, boardPath: f.boardPath });
    try {
      const metadata = board.metadata();
      const committed = stage === 'afterCommit';
      const snapshot = board.snapshot();
      for (const key of ['tasks', 'assignments', 'reservations']) {
        assert.equal(snapshot[key].length, committed ? 1 : 0, key + ' atomicity');
      }
      assert.equal(metadata.boardRevision, f.metadata.boardRevision + (committed ? 1 : 0));
      assert.equal(metadata.eventSeq, f.metadata.eventSeq + (committed ? 1 : 0));
      const request = { operationId: 'crash-operation', actorId: 'lead',
        generation: f.metadata.generation };
      const requestHash = createHash('sha256').update(JSON.stringify(request)).digest('hex');
      let callbacks = 0;
      const apply = () => board.transactOperation({ request, requestHash,
        operation: 'fixture-change' }, tx => {
        callbacks++;
        return atomicMutation(tx);
      });
      const first = apply();
      const replay = apply();
      assert.deepEqual(replay, first);
      assert.equal(callbacks, committed ? 0 : 1);
      assert.equal(board.metadata().eventSeq, f.metadata.eventSeq + 1);
      assert.throws(() => board.transactOperation({ request,
        requestHash: '00'.repeat(32), operation: 'fixture-change' }, () => ({})));
    } finally { board.close(); }
  });
}

// CASE-26: a validated SQLite backup restores consistent state with a different generation.
test('P0.backupRestore', async t => {
  const f = await storageFixture(t);
  const board = f.openBoard({ projectRoot: f.projectRoot, boardPath: f.boardPath });
  const backupPath = join(f.projectRoot, 'verified-backup.sqlite');
  const request = { operationId: 'pre-restore-operation', actorId: 'lead',
    generation: f.metadata.generation };
  const requestHash = createHash('sha256').update(JSON.stringify(request)).digest('hex');
  board.transactOperation({ request, requestHash, operation: 'fixture-receipt' },
    () => ({ marker: 'old-generation-receipt' }));
  let backedUp;
  try {
    backedUp = board.metadata();
    await board.backup(backupPath);
    board.transactOperation({ request: { ...request, operationId: 'after-backup' },
      requestHash: '22'.repeat(32), operation: 'later-change' }, atomicMutation);
  } finally { board.close(); }
  const restored = await f.restoreBoard({ projectRoot: f.projectRoot,
    leadId: 'lead', leadTokenHash: createHash('sha256').update('fixture-lead').digest('hex'),
    boardPath: join(f.projectRoot, 'restored'), backupPath });
  try {
    assert.notEqual(restored.metadata().generation, f.metadata.generation);
    assert.equal(restored.snapshot().tasks.length, 0, 'Backup excluded later mutation');
    // The confirmed restore contract creates exactly one new-generation audited change.
    assert.equal(restored.metadata().boardRevision, backedUp.boardRevision + 1);
    assert.equal(restored.metadata().eventSeq, backedUp.eventSeq + 1);
    // The identical historical receipt must not bypass generation validation after restore.
    assert.throws(() => restored.transactOperation({ request, requestHash,
      operation: 'fixture-receipt' }, () => ({ forbidden: true })),
    error => error.code === 'STALE_GENERATION');
    assert.throws(() => restored.transactOperation({
      request: { operationId: 'stale', generation: f.metadata.generation, actorId: 'lead' },
      requestHash: '11'.repeat(32), operation: 'stale-write',
    }, () => ({ forbidden: true })), error => error.code === 'STALE_GENERATION');
  } finally { restored.close(); }
});








// P0 schema repair regression: controlled old experimental v1 cannot open or restore as v2.
// Only this private fixture is edited with PRAGMA; production writes always use the application.
test('P0.oldExperimentalSchemaRejected', async t => {
  const f = await storageFixture(t);
  const file = join(f.boardPath, 'board.sqlite');
  const db = new DatabaseSync(file);
  try { db.exec('PRAGMA user_version=1'); } finally { db.close(); }
  const before = await readFile(file);
  assert.throws(() => f.openBoard({ projectRoot: f.projectRoot, boardPath: f.boardPath }),
    error => error.code === 'UNSUPPORTED_SCHEMA');
  const restoredPath = join(f.projectRoot, 'must-not-restore');
  await assert.rejects(() => f.restoreBoard({ projectRoot: f.projectRoot,
    boardPath: restoredPath, backupPath: file, leadId: 'lead',
    leadTokenHash: createHash('sha256').update('fixture-lead').digest('hex') }),
  error => error.code === 'UNSUPPORTED_SCHEMA');
  assert.deepEqual(await readFile(file), before, 'Unknown schema source must remain intact');
  await assert.rejects(access(join(restoredPath, 'board.sqlite')), { code: 'ENOENT' });
});
