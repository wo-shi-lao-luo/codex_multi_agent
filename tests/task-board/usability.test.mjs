// Operational metadata is factual: report timestamps, read-only actor-visible scheduling and runtime info.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { domainFixture } from './domain-fixture.mjs';
import { cli, fixture, invoke } from './helpers.mjs';
import { query } from '../../packages/task-board/src/coordination/service.mjs';

// Only actual report/block writes a server timestamp; caller timestamps cannot forge that observation.
test('Usability.reportTimestampOwnership', () => {
  const f = domainFixture();
  f.add('work');
  const owner = f.claim('work');
  assert.ok(!f.tx.tasks.get('work').lastReportAt);
  const result = f.run('report', { ...owner.owner, phase: 'testing', progress: 'Actual report' });
  assert.equal(typeof result.task.lastReportAt, 'string');
  assert.ok(Number.isFinite(Date.parse(result.task.lastReportAt)));
  assert.throws(() => f.run('report', { ...owner.owner, phase: 'testing',
    lastReportAt: '2000-01-01T00:00:00.000Z' }), error => error.code === 'INVALID_INPUT');
  assert.equal(f.tx.tasks.get('work').lastReportAt, result.task.lastReportAt);
});

// Lead proxy report/block uses the same timestamp semantics; proxy submit is not an actual report.
test('Usability.proxyTimestampSemantics', () => {
  const f = domainFixture();
  f.run('register', { worker: { id: 'proxy', hostId: 'readonly-host', role: 'backend',
    mode: 'lead-proxy', capabilities: ['read'], workerToken: 'aa'.repeat(32) } });
  f.add('proxy-work');
  f.run('grant', { taskId: 'proxy-work', workerId: 'proxy', approvalRevision: 2 });
  const assigned = f.run('assign', { taskId: 'proxy-work', workerId: 'proxy', claimToken: 'bb'.repeat(32) });
  const owner = { taskId: 'proxy-work', assignmentId: assigned.assignment.id,
    claimToken: 'bb'.repeat(32), reportedByWorkerId: 'proxy' };
  const report = f.run('lead-proxy-report', { ...owner, action: 'block', blocker: 'Actual blocker' });
  assert.equal(typeof report.task.lastReportAt, 'string');
  const submitted = f.run('lead-proxy-report', { ...owner, action: 'submit',
    writesStopped: true, processStopped: true, inputRevision: 'current-input',
    evidenceRefs: ['fixture/proxy#submitted'] });
  assert.equal(submitted.task.lastReportAt, report.task.lastReportAt);
});

// Compact summary counts the actor-visible unarchived set before pagination, never guesses capacity.
test('Usability.schedulingBeforePagination', () => {
  const f = domainFixture();
  f.tx.board.boardRevision = 0;
  f.tx.board.eventSeq = 0;
  f.add('ready');
  f.add('waiting', [{ taskId: 'ready', gate: 'accepted-result' }]);
  f.run('grant', { taskId: 'ready', workerId: 'first-worker', approvalRevision: 2 });
  const result = query(f.tx, 'status', { actorId: 'lead', leadToken: '21'.repeat(32), limit: 1 });
  assert.equal(result.tasks.length, 1);
  assert.equal(result.scheduling.totalTasks, 2);
  assert.equal(result.scheduling.readyTasks, 1);
  assert.equal(result.scheduling.stateCounts.open, 2);
  assert.equal(result.scheduling.activeAssignments, 0);
  assert.equal(result.scheduling.unknownDispatches, 0);
  assert.equal(result.scheduling.hostCapacity, null);
  const scoped = domainFixture();
  scoped.tx.board.boardRevision = 0;
  scoped.tx.board.eventSeq = 0;
  scoped.add('mine');
  scoped.add('private');
  scoped.claim('mine');
  scoped.claim('private', 'second-worker');
  for (const [attemptId, taskId] of [['private-intent', 'private'], ['mine-intent', 'mine']]) {
    scoped.run('record-dispatch', { attemptId, taskId, status: 'unknown', role: 'backend',
      capacityObservation: { available: null, evidenceRefs: ['fixture/host#unknown'] },
      evidenceRefs: ['fixture/dispatch#unknown'] });
  }
  const worker = query(scoped.tx, 'status', { actorId: 'first-worker', workerToken: '32'.repeat(32), limit: 1 });
  assert.equal(worker.scheduling.totalTasks, 1);
  assert.equal(worker.scheduling.activeAssignments, 1);
  assert.equal(worker.scheduling.unknownDispatches, null);
  assert.ok(!JSON.stringify(worker).includes('private-intent'));
  const lead = query(scoped.tx, 'status', { actorId: 'lead', leadToken: '21'.repeat(32), limit: 1 });
  assert.equal(lead.scheduling.unknownDispatches, 2);
});

// Informational preflight works with unsupported Node and SQLite disabled, no root or database flags.
test('Usability.runtimeDoctorWithoutSqlite', async () => {
  const result = spawnSync('node', ['--no-experimental-sqlite', cli, 'runtime-doctor'],
    { encoding: 'utf8', timeout: 5000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  const reply = JSON.parse(result.stdout);
  assert.equal(reply.ok, true);
  assert.equal(reply.result.available, false);
  const [major, minor] = reply.result.nodeVersion.replace(/^v/, '').split('.').map(Number);
  const supported = major === 26 && minor >= 13;
  assert.equal(reply.result.reasonCode, supported ? 'SQLITE_UNAVAILABLE' : 'NODE_UNSUPPORTED');
  assert.equal(reply.result.sqliteVersion, null);
  assert.deepEqual(reply.result.requirements, { node: '>=26.13.0 <27', sqlite: '>=3.54.0' });
  const { assessRuntime } = await import('../../packages/task-board/src/runtime/preflight.mjs');
  for (const [version, sqlite, code] of [
    ['25.2.1', null, 'NODE_UNSUPPORTED'], ['26.12.0', '3.54.0', 'NODE_UNSUPPORTED'],
    ['26.13.0', null, 'SQLITE_UNAVAILABLE'], ['26.13.0', '3.53.0', 'SQLITE_UNSUPPORTED'],
    ['26.13.0', '3.54.0', 'READY'], ['27.0.0', '3.54.0', 'NODE_UNSUPPORTED'],
  ]) assert.equal(assessRuntime(version, sqlite).reasonCode, code);
  const supportedProbe = spawnSync(process.execPath, [cli, 'runtime-doctor'], { encoding: 'utf8' });
  assert.equal(supportedProbe.status, 0, supportedProbe.stdout + supportedProbe.stderr);
  const current = JSON.parse(supportedProbe.stdout);
  assert.equal(current.result.available, true);
  assert.equal(current.result.reasonCode, 'READY');
});

// Real CLI reopens observe committed time; exact receipt replay and label-only sync cannot invent reports.
test('Usability.durableReportReplay', async t => {
  const f = await fixture(t);
  await f.worker('w1');
  await f.task('work');
  await f.grant('w1', 'work');
  const claimToken = 'cc'.repeat(32);
  const claimed = await f.ok('claim', { actorId: 'w1', workerToken: f.workers.w1,
    taskId: 'work', taskRevision: 2, claimToken });
  const input = { operationId: 'durable-report', actorId: 'w1', workerToken: f.workers.w1,
    taskId: 'work', taskRevision: claimed.result.task.taskRevision,
    assignmentId: claimed.result.assignment.id, claimToken, phase: 'testing', progress: 'Actual report' };
  const reported = await f.ok('report', input);
  assert.equal(typeof reported.result.task.lastReportAt, 'string');
  assert.equal((await f.ok('show', { taskId: 'work' })).result.task.lastReportAt,
    reported.result.task.lastReportAt);
  assert.deepEqual(await f.ok('report', input), reported);
  const status = await f.ok('status');
  assert.equal(status.result.tasks.find(task => task.id === 'work').lastReportAt,
    reported.result.task.lastReportAt);

  // A real bound board can rename its labels without reporting any new work observation.
  const ids = { hostId: 'usability-host', mainSessionId: 'usability-main', projectId: 'usability-project' };
  const digest = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
  const board = `_work/task-board/sessions/v1/${digest(['codex-board-session-v1', ids.hostId, ids.mainSessionId])}`;
  const sessionKey = digest(['codex-board-context-v1', ids.hostId, ids.mainSessionId, ids.projectId]);
  let generation;
  let sequence = 0;
  const bound = async (operation, fields = {}) => {
    const result = await invoke(f.project, board, operation, { operationId: `labels-${++sequence}`,
      actorId: 'lead', leadToken: f.leadToken, generation, ...fields }, { sessionKey });
    assert.equal(result.code, 0, JSON.stringify(result.reply));
    return result.reply;
  };
  generation = (await bound('initialize', { sessionProfile: { ...ids,
    projectName: 'Before', sessionName: 'Work' } })).generation;
  await bound('register', { worker: { id: 'bound-worker', hostId: 'usability-child', role: 'backend',
    mode: 'direct', capabilities: ['write'], workerToken: f.workers.w1 } });
  await bound('add', { task: { id: 'bound-work', title: 'Work', outcome: 'Observed report',
    sourceRefs: ['opaque:source'], acceptanceRefs: ['opaque:acceptance'], eligibleRoles: ['backend'],
    scope: { read: [], write: [] }, resources: [], dependencies: [] } });
  await bound('approve', { taskId: 'bound-work', taskRevision: 1 });
  await bound('grant', { taskId: 'bound-work', workerId: 'bound-worker', approvalRevision: 2 });
  const owner = { actorId: 'bound-worker', workerToken: f.workers.w1, taskId: 'bound-work', claimToken };
  const allocation = await bound('claim', { ...owner, taskRevision: 2 });
  const observation = await bound('report', { ...owner, assignmentId: allocation.result.assignment.id,
    taskRevision: allocation.result.task.taskRevision, phase: 'testing', progress: 'Actual bound report' });
  await bound('session-sync', { projectName: 'After', sessionName: 'Renamed', expectedLabelRevision: 0 });
  assert.equal((await bound('show', { taskId: 'bound-work' })).result.task.lastReportAt,
    observation.result.task.lastReportAt);
});
