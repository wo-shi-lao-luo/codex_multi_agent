// Session binding contracts: independent hashes, real CLI/state, synthetic metadata only (no host rename).
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, mkdtemp, rm, access, writeFile, readFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { cli, invoke, secret } from './helpers.mjs';

const context = { hostId: 'test-host', mainSessionId: 'main-chat', projectId: 'project-stable' };
function expected(ids) {
  const hash = value => createHash('sha256').update(JSON.stringify(value), 'utf8').digest('hex');
  const pathHash = hash(['codex-board-session-v1', ids.hostId, ids.mainSessionId]);
  return { sessionKey: hash(['codex-board-context-v1', ids.hostId, ids.mainSessionId, ids.projectId]),
    boardPath: `_work/task-board/sessions/v1/${pathHash}` };
}
async function fixture(t) {
  const parent = resolve('_work/task-board/test-fixtures');
  await mkdir(parent, { recursive: true });
  const root = await mkdtemp(join(parent, 'session-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const token = secret();
  let sequence = 0;
  async function initialize(ids = context, names = {}) {
    const selection = expected(ids);
    const board = join(root, selection.boardPath);
    const profile = { ...ids, projectName: 'Same project', sessionName: 'Same session', ...names };
    const response = await invoke(root, selection.boardPath, 'initialize', { actorId: 'lead', leadToken: token,
      sessionProfile: profile }, { sessionKey: selection.sessionKey });
    assert.equal(response.code, 0, JSON.stringify(response.reply));
    const generation = response.reply.generation;
    const call = (operation, input = {}, key = selection.sessionKey) => invoke(root, board, operation,
      { operationId: `session-op-${++sequence}`, actorId: 'lead', leadToken: token,
        generation, ...input }, { sessionKey: key === null ? undefined : key });
    const ok = async (operation, input = {}) => {
      const result = await call(operation, input);
      assert.equal(result.code, 0, JSON.stringify(result.reply));
      return result.reply;
    };
    return { ...selection, board, profile, generation, call, ok };
  }
  return { root, token, initialize };
}

// Pure path/key routing must be independent of SQLite, root flags and label spelling.
test('Session.purePathAlgorithms', () => {
  for (const ids of [context, { ...context, mainSessionId: 'other-main' },
    { ...context, projectId: 'different-project' }]) {
    const child = spawnSync(process.execPath, ['--no-experimental-sqlite', cli, 'session-path', '--stdin'],
      { input: JSON.stringify(ids), encoding: 'utf8', timeout: 5000 });
    assert.equal(child.status, 0, child.stdout + child.stderr);
    const reply = JSON.parse(child.stdout);
    assert.equal(reply.schemaVersion, 1);
    assert.deepEqual(reply.result, expected(ids));
  }
  assert.equal(expected(context).boardPath, expected({ ...context, projectId: 'different-project' }).boardPath);
  assert.notEqual(expected(context).sessionKey, expected({ ...context, projectId: 'different-project' }).sessionKey);
});

// Equal display labels do not merge MAIN sessions; inherited MAIN context resolves the same board.
test('Session.separateMainAndInheritedChild', async t => {
  const f = await fixture(t);
  const first = await f.initialize();
  const second = await f.initialize({ ...context, mainSessionId: 'second-main' });
  assert.notEqual(first.boardPath, second.boardPath);
  const a = (await first.ok('inspect')).result;
  const b = (await second.ok('inspect')).result;
  assert.notEqual(a.boardId, b.boardId);
  assert.equal(a.sessionProfile.projectName, b.sessionProfile.projectName);
  assert.equal(a.sessionProfile.sessionName, b.sessionProfile.sessionName);
  const childSelection = expected({ ...context }); // Child inherits MAIN, never a child-agent ID.
  assert.equal(childSelection.sessionKey, first.sessionKey);
  assert.equal((await first.ok('inspect')).boardId, a.boardId);
  await access(join(first.board, 'board.sqlite'));
});

// Bound context cannot be omitted/substituted; deliberate legacy remains unbound and never adopted.
test('Session.contextGuardsAndLegacy', async t => {
  const f = await fixture(t);
  const profile = { ...context, projectName: 'Project', sessionName: 'Session' };
  const missing = await invoke(f.root, expected(context).boardPath, 'initialize',
    { actorId: 'lead', leadToken: f.token, sessionProfile: profile });
  assert.equal(missing.code, 2, JSON.stringify(missing.reply));
  assert.equal(missing.reply.error.code, 'SESSION_MISMATCH');
  await assert.rejects(access(join(f.root, expected(context).boardPath)), { code: 'ENOENT' });
  const bound = await f.initialize();
  for (const key of [null, '0'.repeat(64)]) {
    const denied = await bound.call('inspect', {}, key);
    assert.equal(denied.code, 2, JSON.stringify(denied.reply));
    assert.equal(denied.reply.error.code, 'SESSION_MISMATCH');
  }
  const legacy = join(f.root, '_work', 'legacy');
  const initialized = await invoke(f.root, legacy, 'initialize', { actorId: 'legacy-lead', leadToken: f.token });
  assert.equal(initialized.code, 0);
  const inspected = await invoke(f.root, legacy, 'inspect', { actorId: 'legacy-lead', leadToken: f.token });
  assert.equal(inspected.code, 0);
  assert.ok(!inspected.reply.result.sessionProfile);
  const adopt = await invoke(f.root, legacy, 'inspect', { actorId: 'legacy-lead', leadToken: f.token },
    { sessionKey: bound.sessionKey });
  assert.equal(adopt.reply.error.code, 'SESSION_UNBOUND');
});

// Name-only updates preserve work; authenticated no-op records no receipt and old replay cannot revert.
test('Session.nameSyncCasAndReceipts', async t => {
  const f = await fixture(t);
  const bound = await f.initialize();
  await bound.ok('add', { task: { id: 'retained-work', title: 'Work', outcome: 'Kept evidence',
    sourceRefs: ['opaque:contract'], acceptanceRefs: ['opaque:acceptance'], eligibleRoles: ['backend'],
    scope: { read: [], write: [] }, resources: [], dependencies: [] } });
  const workerToken = secret();
  await bound.ok('register', { worker: { id: 'worker', hostId: 'synthetic-child', role: 'backend',
    mode: 'direct', capabilities: ['write'], workerToken } });
  await bound.ok('approve', { taskId: 'retained-work', taskRevision: 1 });
  await bound.ok('grant', { taskId: 'retained-work', workerId: 'worker', approvalRevision: 2 });
  const claimToken = secret();
  const assigned = await bound.ok('claim', { actorId: 'worker', workerToken,
    taskId: 'retained-work', taskRevision: 2, claimToken });
  await bound.ok('submit', { actorId: 'worker', workerToken, taskId: 'retained-work',
    taskRevision: assigned.result.task.taskRevision, assignmentId: assigned.result.assignment.id,
    claimToken, writesStopped: true, processStopped: true, inputRevision: 'synthetic-input',
    evidenceRefs: ['synthetic:test-evidence'] });
  const before = (await bound.ok('inspect')).result;
  const workerNoop = await bound.call('session-sync', { actorId: 'worker',
    expectedLabelRevision: 0, projectName: 'Same project', sessionName: 'Same session' });
  assert.equal(workerNoop.reply.error.code, 'UNAUTHORIZED');
  const staleGenerationNoop = await bound.call('session-sync', { generation: 'stale-generation',
    expectedLabelRevision: 0, projectName: 'Same project', sessionName: 'Same session' });
  assert.equal(staleGenerationNoop.reply.error.code, 'STALE_GENERATION');
  const noop = await bound.ok('session-sync', { operationId: 'noop-not-reserved', expectedLabelRevision: 0,
    projectName: 'Same project', sessionName: 'Same session' });
  assert.equal(noop.result.unchanged, true);
  assert.equal(noop.result.receiptCommitted, false);
  assert.equal((await bound.ok('inspect')).result.revision, before.revision);
  const firstInput = { operationId: 'rename-one', expectedLabelRevision: 0,
    projectName: 'Renamed project', sessionName: 'Renamed session' };
  const first = await bound.ok('session-sync', firstInput);
  const afterFirst = (await bound.ok('inspect')).result;
  assert.equal(afterFirst.sessionProfile.labelRevision, 1);
  assert.equal(afterFirst.boardId, before.boardId);
  for (const key of ['tasks', 'grants', 'submissions', 'assignments']) assert.deepEqual(afterFirst[key], before[key]);
  const stale = await bound.call('session-sync', { expectedLabelRevision: 0,
    projectName: 'Stale', sessionName: 'Must not overwrite' });
  assert.equal(stale.reply.error.code, 'CONFLICT');
  const reuseNoop = await bound.ok('session-sync', { operationId: 'noop-not-reserved', expectedLabelRevision: 1,
    projectName: 'Final project', sessionName: 'Final session' });
  assert.notEqual(reuseNoop.result.receiptCommitted, false);
  const staleSameNames = await bound.call('session-sync', { expectedLabelRevision: 1,
    projectName: 'Final project', sessionName: 'Final session' });
  assert.equal(staleSameNames.reply.error.code, 'CONFLICT');
  const wrongContextReplay = await bound.call('session-sync', firstInput, '0'.repeat(64));
  assert.equal(wrongContextReplay.reply.error.code, 'SESSION_MISMATCH');
  const replay = await bound.ok('session-sync', firstInput);
  assert.deepEqual(replay, first);
  assert.equal((await bound.ok('inspect')).result.sessionProfile.projectName, 'Final project');
  const conflict = await bound.call('session-sync', { ...firstInput, projectName: 'Different payload' });
  assert.equal(conflict.code, 2);
});

// Binding survives closed backup/new-target recovery; wrong expected session cannot open either copy.
test('Session.backupRestoreBinding', async t => {
  const f = await fixture(t);
  const bound = await f.initialize();
  const original = (await bound.ok('inspect')).result;
  const backupPath = join(f.root, 'bound-backup.sqlite');
  await bound.ok('backup', { destination: backupPath });
  const rejectedPath = join(f.root, '_work', 'wrong-session-restore');
  const wrongRestore = await invoke(f.root, rejectedPath, 'restore', {
    actorId: 'lead', leadToken: f.token, backupPath, maintenanceApproved: true,
    writesStopped: true, processStopped: true }, { sessionKey: '0'.repeat(64) });
  assert.equal(wrongRestore.reply.error.code, 'SESSION_MISMATCH');
  await assert.rejects(access(join(rejectedPath, 'board.sqlite')), { code: 'ENOENT' });
  const restoredPath = join(f.root, '_work', 'restored');
  const restored = await invoke(f.root, restoredPath, 'restore', { actorId: 'lead', leadToken: f.token,
    backupPath, maintenanceApproved: true, writesStopped: true, processStopped: true },
  { sessionKey: bound.sessionKey });
  assert.equal(restored.code, 0, JSON.stringify(restored.reply));
  const state = await invoke(f.root, restoredPath, 'inspect', { actorId: 'lead', leadToken: f.token,
    generation: restored.reply.generation }, { sessionKey: bound.sessionKey });
  assert.equal(state.code, 0);
  assert.deepEqual(state.reply.result.sessionProfile, original.sessionProfile);
  assert.notEqual(state.reply.generation, bound.generation);
  const matchingMaintenance = await invoke(f.root, restoredPath, 'maintenance-status', {},
    { sessionKey: bound.sessionKey });
  assert.equal(matchingMaintenance.code, 0, JSON.stringify(matchingMaintenance.reply));
  assert.equal(matchingMaintenance.reply.result.boardId, original.boardId);
  const denied = await invoke(f.root, restoredPath, 'maintenance-status', {}, { sessionKey: '0'.repeat(64) });
  assert.equal(denied.code, 2, JSON.stringify(denied.reply));
  assert.equal(denied.reply.error.code, 'SESSION_MISMATCH');
});

// Cached controls enforce session identity without a backing snapshot read; legacy controls stay valid.
test('Session.serviceContextGuard', async t => {
  const { serve } = await import('../../packages/task-board/src/server/server.mjs');
  const { serviceStatus } = await import('../../packages/task-board/src/server/control.mjs');
  const profile = { version: 1, ...context, ...expected(context), projectName: 'Project',
    sessionName: 'Session', labelRevision: 0 };
  delete profile.boardPath;
  const token = secret();
  let reads = 0;
  const board = { snapshot: () => { reads++; return { board: { boardId: 'session-control',
    generation: 'test-generation', schemaVersion: 3, boardRevision: 0, eventSeq: 0, replayFloor: 0,
    sessionProfile: profile }, tasks: [], workers: [], assignments: [], questions: [], answers: [],
  dependencies: [], grants: [], reservations: [], submissions: [] }; }, eventsAfter: () => ({ events: [] }) };
  const service = await serve(board, { serviceControlToken: token });
  t.after(() => service.close());
  const identity = { serviceId: service.serviceId, boardId: 'session-control', generation: 'test-generation',
    port: service.port, url: service.url, serviceControlToken: token, sessionKey: profile.sessionKey };
  assert.equal((await serviceStatus(identity)).sessionKey, profile.sessionKey);
  for (const key of [null, '0'.repeat(64)]) {
    await assert.rejects(serviceStatus({ ...identity, sessionKey: key === null ? undefined : key }), { code: 'SERVICE_CONTROL_REJECTED' });
  }
  assert.equal(reads, 1);
});

// Unicode display values normalize as data, never affect path/identity; control/malformed text rejects.
test('Session.unicodeNamesAndInvalidIdentity', async t => {
  const f = await fixture(t);
  const bound = await f.initialize(context, { projectName: '  项目<script>  ', sessionName: ' e\u0301 + 会话 ' });
  const state = (await bound.ok('inspect')).result;
  assert.equal(state.sessionProfile.projectName, '项目<script>');
  assert.equal(state.sessionProfile.sessionName, 'é + 会话');
  assert.equal(state.sessionProfile.sessionKey, expected(context).sessionKey);
  for (const sessionName of ['bad\u0000name', '\ud800', 'x'.repeat(201)]) {
    const denied = await bound.call('session-sync', { expectedLabelRevision: 0,
      projectName: 'Valid', sessionName });
    assert.equal(denied.code, 2);
  }
  const invalid = await invoke(f.root, join(f.root, '_work', 'invalid-profile'), 'initialize',
    { actorId: 'lead', leadToken: f.token, sessionProfile: { ...context, hostId: '',
      projectName: 'Valid', sessionName: 'Valid' } }, { sessionKey: bound.sessionKey });
  assert.equal(invalid.code, 2);
});


// A canonical nested session directory is already covered by an effective literal ancestor policy.
test('Session.artifactNestedAncestorReuse', async t => {
  const { protectArtifacts } = await import('../../packages/task-board/src/coordination/artifact-protection.mjs');
  const f = await fixture(t);
  const initialized = spawnSync('git', ['-C', f.root, 'init', '--quiet'], { encoding: 'utf8' });
  assert.equal(initialized.status, 0, initialized.stderr);
  await writeFile(join(f.root, '.gitignore'), '/_work/\n');
  const before = await readFile(join(f.root, '.gitignore'));
  assert.doesNotThrow(() => protectArtifacts({ projectRoot: f.root,
    boardPath: expected(context).boardPath }));
  assert.deepEqual(await readFile(join(f.root, '.gitignore')), before);
});

// A new default nested session scope appends its exact digest path, never a broad sessions wildcard.
test('Session.artifactNestedExactAppend', async t => {
  const { protectArtifacts } = await import('../../packages/task-board/src/coordination/artifact-protection.mjs');
  const f = await fixture(t);
  assert.equal(spawnSync('git', ['-C', f.root, 'init', '--quiet']).status, 0);
  const scope = expected(context).boardPath;
  assert.doesNotThrow(() => protectArtifacts({ projectRoot: f.root, boardPath: scope }));
  assert.equal(await readFile(join(f.root, '.gitignore'), 'utf8'), `/${scope}/\n`);
  const ignored = spawnSync('git', ['-C', f.root, 'check-ignore', '--no-index', '--',
    `${scope}/board.sqlite`], { encoding: 'utf8' });
  assert.equal(ignored.status, 0, ignored.stderr);
});
