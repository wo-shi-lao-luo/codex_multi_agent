// Count real Git subprocesses and exercise actual SQLite rollback at filesystem drift barriers.
import test from 'node:test';
import assert from 'node:assert/strict';
import cp from 'node:child_process';
import { syncBuiltinESMExports } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import { initializeBoard, openBoard } from '../../packages/task-board/src/storage/index.mjs';
import { assertWorkspaceBinding } from '../../packages/task-board/src/storage/workspaces.mjs';
import { validateTaskScopes } from '../../packages/task-board/src/domain/workspace-scope.mjs';
import { hash, mutate as domainMutation } from '../../packages/task-board/src/coordination/service.mjs';
import { sourcePath } from './helpers.mjs';

function fixture(t) {
  const parent = sourcePath('_work/task-board/test-fixtures');
  fs.mkdirSync(parent, { recursive: true });
  const projectRoot = fs.mkdtempSync(path.join(parent, 'observation-'));
  let board;
  t.after(() => { board?.close(); fs.rmSync(projectRoot, { recursive: true, force: true }); });
  cp.execFileSync('git', ['-C', projectRoot, 'init'], { stdio: 'pipe' });
  const boardPath = path.join(projectRoot, 'board');
  const created = initializeBoard({ projectRoot, boardPath, leadId: 'lead', leadTokenHash: hash('fixture') });
  const generation = created.metadata().generation;
  created.close();
  const hooks = {};
  board = openBoard({ projectRoot, boardPath, testHooks: hooks });
  let sequence = 0;
  function mutate(callback, id = `observation-${++sequence}`, authorizeReplay) {
    const request = { operationId: id, actorId: 'lead', generation };
    return board.transactOperation({ request, requestHash: hash(JSON.stringify(request)),
      operation: 'fixture-observation', authorizeReplay }, callback);
  }
  return { board, projectRoot, hooks, mutate };
}

function counted(callback) {
  const original = cp.execFileSync;
  let calls = 0;
  cp.execFileSync = function(file, ...args) {
    if (file === 'git') calls++;
    return original.call(this, file, ...args);
  };
  syncBuiltinESMExports();
  const start = performance.now();
  try { callback(); return { calls, elapsedMs: Math.round(performance.now() - start) }; }
  finally { cp.execFileSync = original; syncBuiltinESMExports(); }
}

test('WORKSPACE.scopesHaveConstantOperationBoundedGitObservation', t => {
  const f = fixture(t);
  const measurements = [];
  for (const count of [1, 10, 52]) {
    const task = { workspaceId: 'main', scope: { read: [],
      write: Array.from({ length: count }, (_, i) => `src/output-${i}`) } };
    measurements.push({ scopes: count, ...counted(() => f.mutate(tx => {
      validateTaskScopes(tx, task);
      assertWorkspaceBinding(tx);
      return {};
    })) });
  }
  t.diagnostic(JSON.stringify(measurements));
  assert.deepEqual(measurements.map(m => m.calls), [8, 8, 8], 'One initial and one final full Git check');
  assert.equal(counted(() => f.board.read(tx => {
    for (let i = 0; i < 10; i++) assertWorkspaceBinding(tx);
  })).calls, 8, 'Read context also checks initially and finally');
  assert.equal(counted(() => f.mutate(() => assert.fail('Receipt replay must not execute mutation'),
    'observation-1', tx => { for (let i = 0; i < 10; i++) assertWorkspaceBinding(tx); })).calls, 8);
  assert.equal(counted(() => f.mutate(tx => assertWorkspaceBinding(tx))).calls, 8,
    'A later operation never reuses a previous context');
});

test('WORKSPACE.realAssignmentWithAcceptedDependencyChecksEachWorkspaceTwice', t => {
  const f = fixture(t);
  const call = (operation, input = {}) => f.mutate(tx => domainMutation(tx, operation,
    { actorId: 'lead', leadToken: 'fixture', ...input }, { cwd: f.projectRoot })).result;
  call('register', { worker: { id: 'lead', role: 'lead', mode: 'lead-inline', capabilities: ['write'] } });
  const task = (id, scopes, dependencies = []) => call('sync-task', { action: 'prepare',
    contractApproved: true, task: { id, title: id, outcome: 'Output', sourceRefs: ['fixture/work'],
      acceptanceRefs: ['fixture/accept'], eligibleRoles: ['backend'], allowLeadInline: true,
      scope: { read: [], write: Array.from({ length: scopes }, (_, i) => `src/${id}-${i}`) }, dependencies } });
  task('upstream', 10);
  const token = 'ab'.repeat(32);
  const first = call('sync-task', { action: 'assign', workerId: 'lead', taskId: 'upstream',
    taskRevision: 2, approvalRevision: 2, claimToken: token });
  call('lead-inline-report', { taskId: 'upstream', taskRevision: 3, action: 'submit',
    assignmentId: first.assignment.id, claimToken: token, writesStopped: true, processStopped: true,
    inputRevision: 'sha256:upstream', evidenceRefs: ['fixture/frozen'] });
  call('accept', { taskId: 'upstream', taskRevision: 4, gatesSatisfied: true, evidenceRefs: ['fixture/accepted'] });
  call('release', { taskId: 'upstream', taskRevision: 5, writesStopped: true, processStopped: true });
  task('downstream', 52, [{ taskId: 'upstream', gate: 'accepted-result' }]);
  const measurement = counted(() => {
    const allocated = call('sync-task', { action: 'assign', workerId: 'lead', taskId: 'downstream',
      taskRevision: 2, approvalRevision: 2, claimToken: token });
    assert.equal(allocated.task.state, 'running');
    assert.equal(allocated.assignment.inputBindings[0].taskId, 'upstream');
  });
  t.diagnostic(JSON.stringify({ operation: 'assign with accepted dependency and 52 scopes', ...measurement }));
  assert.equal(measurement.calls, 8);
});

for (const barrier of ['callback', 'beforeCommit', 'read', 'replay']) {
  test(`WORKSPACE.finalDriftRollsBack.${barrier}`, t => {
    const f = fixture(t);
    if (barrier === 'replay') f.mutate(() => ({}), 'replay-drift');
    const before = f.board.metadata();
    const marker = path.join(f.projectRoot, '.git');
    const moved = path.join(f.projectRoot, 'saved-git');
    const drift = () => fs.renameSync(marker, moved);
    const inspect = tx => { assertWorkspaceBinding(tx); tx.board.fixtureTouched = true; };
    if (barrier === 'beforeCommit') f.hooks.beforeCommit = drift;
    try {
      const action = barrier === 'read' ? () => f.board.read(tx => { inspect(tx); drift(); })
        : barrier === 'replay' ? () => f.mutate(() => assert.fail('No mutation on replay'),
          'replay-drift', tx => { inspect(tx); drift(); })
          : () => f.mutate(tx => { inspect(tx); if (barrier === 'callback') drift(); });
      assert.throws(action, { code: 'WORKSPACE_MISMATCH' });
    } finally {
      delete f.hooks.beforeCommit;
      if (fs.existsSync(moved)) fs.renameSync(moved, marker);
    }
    assert.deepEqual(f.board.metadata(), before, 'No metadata or receipt commit on drift');
  });
}
