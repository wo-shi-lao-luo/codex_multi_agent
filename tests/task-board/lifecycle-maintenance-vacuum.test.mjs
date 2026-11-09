// Real maintenance VACUUM outcomes; child-only fault barriers never change production interfaces.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import { mkdir, mkdtemp, readFile, rm } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { initializeBoard, openMaintenanceBoard } from '../../packages/task-board/src/storage/index.mjs';

const leadTokenHash = '73'.repeat(32);
// Hash full semantic requests, or a caller-supplied unsigned preview plan, without dropping nested data.
function digest(options) {
  const canonical = value => Array.isArray(value) ? value.map(canonical)
    : value && typeof value === 'object'
      ? Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])]))
      : value;
  const { requestHash, ...semantic } = options;
  return createHash('sha256').update(JSON.stringify(canonical(semantic))).digest('hex');
}

// Own a real strict3 board, authenticated maintenance session and matching prestart backup.
async function fixture(t) {
  const parent = resolve('_work/task-board/test-fixtures');
  await mkdir(parent, { recursive: true });
  const projectRoot = await mkdtemp(join(parent, 'lifecycle-maintenance-vacuum-'));
  const boardPath = join(projectRoot, 'board');
  const board = initializeBoard({ projectRoot, boardPath, leadId: 'lead', leadTokenHash });
  const maintenance = openMaintenanceBoard({ projectRoot, boardPath });
  const children = [];
  t.after(async () => {
    for (const child of children) {
      if (child.exitCode === null && child.signalCode === null) {
        const closed = new Promise(done => child.once('close', done));
        child.kill();
        await closed;
      }
    }
    maintenance.close();
    board.close();
    await rm(projectRoot, { recursive: true, force: true });
  });
  for (const method of ['previewVacuum', 'vacuum', 'resolveMaintenanceOperation']) {
    assert.equal(typeof maintenance[method], 'function', `Missing maintenance capability: ${method}`);
  }
  let sequence = 0;
  const quiescence = { writersStopped: true, servicesStopped: true,
    evidenceRefs: ['fixture/stop#owned-board'] };
  const session = { maintenanceId: 'vacuum-fixture-session',
    maintenanceTokenHash: '84'.repeat(32) };
  function options(extra = {}) {
    const status = maintenance.status();
    const value = { request: { operationId: `vacuum-${++sequence}`, actorId: 'lead',
      generation: status.generation, expectedBoardRevision: status.boardRevision },
    leadId: 'lead', leadTokenHash, ...session, ...extra };
    return { ...value, requestHash: digest(value) };
  }
  await maintenance.enter(options({ quiescence }));
  const backup = await board.backup(join(projectRoot, 'pre-vacuum.sqlite'));
  const input = { backupPath: backup.path, expectedBackupSha256: backup.sha256,
    windowApprovalRef: 'fixture/window#explicit', quiescence, policyVersion: 1 };
  const preview = await maintenance.previewVacuum(options(input));
  assert.equal(preview.previewHash, digest(preview.plan));
  return { projectRoot, boardPath, board, maintenance, children, options, input, preview, backup };
}

// Spawn only this fixture's child, wait for a real SQL boundary, then terminate that child alone.
async function interrupt(f, phase, options) {
  const child = spawn(process.execPath, [resolve('tests/task-board/lifecycle-maintenance-vacuum-child.mjs')],
    { stdio: ['pipe', 'pipe', 'pipe'] });
  f.children.push(child);
  let output = '';
  let errors = '';
  await new Promise((done, reject) => {
    const timer = setTimeout(() => reject(new Error(`Owned child barrier timeout: ${errors}`)), 10000);
    child.stdout.on('data', bytes => {
      output += bytes;
      if (output.includes('VACUUM_BARRIER')) { clearTimeout(timer); done(); }
    });
    child.stderr.on('data', bytes => { errors += bytes; });
    child.once('error', error => { clearTimeout(timer); reject(error); });
    child.once('close', () => {
      clearTimeout(timer);
      if (!output.includes('VACUUM_BARRIER')) reject(new Error(`Child exited early: ${errors}`));
    });
    child.stdin.end(JSON.stringify({ projectRoot: f.projectRoot, boardPath: f.boardPath,
      options, phase }));
  });
  const stopped = new Promise(done => child.once('close', done));
  child.kill();
  await stopped;
  return child.pid;
}

// Scenario: approved maintenance executes real VACUUM and retries its completed request.
// Expected: durable completed receipt, N→N+2 cursors, no second execution or task/backup changes.
test('vacuum.actualCompletion', async t => {
  const f = await fixture(t);
  const before = f.board.snapshot();
  const backup = await readFile(f.backup.path);
  const options = f.options({ ...f.input, previewHash: f.preview.previewHash });
  const result = await f.maintenance.vacuum(options);
  assert.equal(result.ok, true);
  assert.equal(result.result.outcome, 'completed');
  assert.equal(result.result.receiptCommitted, true);
  assert.equal(result.boardRevision, before.board.boardRevision + 2);
  assert.equal(result.eventSeq, before.eventSeq + 2);
  assert.equal(f.maintenance.status().pendingOperation, null);
  assert.deepEqual(f.board.snapshot().tasks, before.tasks);
  assert.deepEqual(await readFile(f.backup.path), backup);
  assert.deepEqual(await f.maintenance.vacuum(options), result);
});

// Scenario: owned child stops before SQL or after real SQL returns, before final receipt.
// Expected: both boundaries remain unknown; same operation cannot rerun and exit cannot bypass it.
test('vacuum.durableUnknown', async t => {
  for (const phase of ['before', 'after']) {
    const f = await fixture(t);
    const options = f.options({ ...f.input, previewHash: f.preview.previewHash });
    const before = f.maintenance.status();
    await interrupt(f, phase, options);
    const pending = f.maintenance.status().pendingOperation;
    assert.equal(pending.operationId, options.request.operationId);
    assert.equal(pending.outcome, 'unknown');
    assert.equal(pending.startedBoardRevision, before.boardRevision + 1);
    await assert.rejects(async () => f.maintenance.vacuum(options),
      error => error.code === 'RECOVERY_REQUIRED');
    await assert.rejects(async () => f.maintenance.exit(f.options({ quiescence: f.input.quiescence })),
      error => error.code === 'MAINTENANCE_REQUIRED');
  }
});

// Scenario: after owned child termination, explicitly abandon the unknown physical result.
// Expected: matching stopped-process evidence is required; old operation stays retired after resolve.
test('vacuum.explicitUnknownResolution', async t => {
  const f = await fixture(t);
  const options = f.options({ ...f.input, previewHash: f.preview.previewHash });
  const pid = await interrupt(f, 'after', options);
  const pending = f.maintenance.status().pendingOperation;
  assert.equal(pending.owner.pid, pid);
  const resolveInput = { pendingOperationId: pending.operationId, decision: 'abandon-unknown',
    processObservation: { ...pending.owner, stopped: true,
      evidenceRefs: ['fixture/process#owned-child-close'] },
    integrityEvidenceRefs: ['fixture/integrity#explicit-observation'] };
  const before = f.maintenance.status();
  await assert.rejects(async () => f.maintenance.resolveMaintenanceOperation(f.options({
    ...resolveInput, processObservation: { ...resolveInput.processObservation, instanceId: 'wrong' },
  })));
  assert.deepEqual(f.maintenance.status(), before);
  const result = await f.maintenance.resolveMaintenanceOperation(f.options(resolveInput));
  assert.equal(result.result.outcome, 'unknown-abandoned');
  assert.equal(result.result.physicalEffect, 'unknown');
  assert.equal(f.maintenance.status().pendingOperation, null);
  await assert.rejects(async () => f.maintenance.vacuum(options),
    error => error.code === 'OPERATION_RETIRED');
  await f.maintenance.exit(f.options({ quiescence: f.input.quiescence }));
});

// Scenario: privileged previews/execute encounter wrong Lead, stale revision or altered backup pin.
// Expected: reject before durable start, preserving the exact board snapshot and closed backup.
test('vacuum.authorizationRevisionAndBackupDenial', async t => {
  const f = await fixture(t);
  const before = f.board.snapshot();
  const source = await readFile(f.backup.path);
  for (const patch of [{ leadTokenHash: '00'.repeat(32) },
    { expectedBackupSha256: '00'.repeat(32) }]) {
    await assert.rejects(async () => f.maintenance.previewVacuum(f.options({ ...f.input, ...patch })),
      error => error.code === (patch.leadTokenHash ? 'UNAUTHORIZED' : 'CONFLICT'));
    assert.deepEqual(f.board.snapshot(), before);
  }
  const stale = f.options({ ...f.input, previewHash: f.preview.previewHash });
  stale.request.expectedBoardRevision--;
  stale.requestHash = digest(stale);
  await assert.rejects(async () => f.maintenance.vacuum(stale), error => error.code === 'CONFLICT');
  assert.deepEqual(f.board.snapshot(), before);
  assert.deepEqual(await readFile(f.backup.path), source);
});

// Scenario: an otherwise valid plan sees unavailable or zero free space at execution time.
// Expected: no durable start; changing observations and preview IDs do not change the stable hash.
test('vacuum.spaceRecheckBeforeStart', async t => {
  const f = await fixture(t);
  const before = f.board.snapshot();
  const original = fs.statfsSync;
  try {
    for (const unavailable of [true, false]) {
      fs.statfsSync = (...args) => {
        if (unavailable) throw new Error('Controlled unavailable space observation');
        return { ...original(...args), bavail: 0, bfree: 0 };
      };
      const preview = await f.maintenance.previewVacuum(f.options(f.input));
      assert.equal(preview.previewHash, f.preview.previewHash);
      assert.equal(preview.observations.spaceSufficient, false);
      await assert.rejects(async () => f.maintenance.vacuum(f.options({ ...f.input,
        previewHash: preview.previewHash })), error => error.code === 'MAINTENANCE_REQUIRED');
      assert.deepEqual(f.board.snapshot(), before);
    }
  } finally { fs.statfsSync = original; }
});

// Scenario: a real second SQLite writer makes the owned child's actual VACUUM return BUSY.
// Expected: observed failure gets a durable failed receipt; identical retry executes no second SQL.
test('vacuum.observedSqlFailureReceipt', async t => {
  const f = await fixture(t);
  const options = f.options({ ...f.input, previewHash: f.preview.previewHash });
  const child = spawn(process.execPath, [resolve('tests/task-board/lifecycle-maintenance-vacuum-child.mjs')],
    { stdio: ['pipe', 'pipe', 'pipe'] });
  f.children.push(child);
  let output = '';
  let errors = '';
  child.stdout.on('data', bytes => { output += bytes; });
  child.stderr.on('data', bytes => { errors += bytes; });
  const code = await new Promise((done, reject) => {
    const timer = setTimeout(() => reject(new Error(`Owned BUSY child timeout: ${errors}`)), 15000);
    child.once('error', error => { clearTimeout(timer); reject(error); });
    child.once('close', value => { clearTimeout(timer); done(value); });
    child.stdin.end(JSON.stringify({ projectRoot: f.projectRoot, boardPath: f.boardPath,
      options, phase: 'observed-busy' }));
  });
  assert.equal(code, 0, errors);
  const response = JSON.parse(output);
  assert.equal(response.result.ok, false);
  assert.equal(response.result.result.outcome, 'failed');
  assert.equal(response.result.result.physicalEffect, 'sqlite-error-observed');
  assert.equal(response.result.result.receiptCommitted, true);
  assert.deepEqual(response.replay, response.result);
  assert.equal(response.vacuumCalls, 1);
  assert.equal(f.maintenance.status().pendingOperation, null);
});
