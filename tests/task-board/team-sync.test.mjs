// Semantic teamwork operations use real CLI/SQLite receipts, never a second task journal.
import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture, secret, assertRedacted } from './helpers.mjs';
import { help } from '../../packages/task-board/src/cli/help.mjs';

const contract = id => ({ id, title: id, outcome: 'Bounded team output',
  sourceRefs: ['fixture/work#team'], acceptanceRefs: ['fixture/accept#team'],
  eligibleRoles: ['backend'], allowLeadInline: true,
  scope: { read: [], write: [`src/${id}.mjs`] } });

test('SYNC.typedHelpDistinguishesRevisionAndRelationShapes', () => {
  const commands = help([]).result.commands;
  assert.equal(commands.find(c => c.operation === 'submit').fieldTypes.inputRevision.type, 'string');
  assert.equal(commands.find(c => c.operation === 'amend').fieldTypes.expectedInputRevision.type, 'integer');
  assert.deepEqual(Object.keys(commands.find(c => c.operation === 'accept')
    .fieldTypes.checkResults.items.properties), ['checkId', 'taskId', 'submissionId']);
  assert.deepEqual(Object.keys(commands.find(c => c.operation === 'add')
    .fieldTypes['task.dependencies'].items.properties), ['taskId', 'gate']);
});

test('SYNC.atomicPrepareAssignReportAndRevokedReplay', async t => {
  const f = await fixture(t);
  await f.ok('register', { worker: { id: 'lead', role: 'lead', mode: 'lead-inline', capabilities: ['write'] } });
  const prepare = { operationId: 'prepare-team', action: 'prepare', contractApproved: true, task: contract('team') };
  const ready = await f.ok('sync-task', prepare);
  assert.equal(ready.result.task.state, 'open');
  assert.equal(ready.result.task.inputRevision, 1);
  assert.deepEqual(await f.ok('sync-task', prepare), ready, 'Exact retry returns one receipt');
  const claimToken = secret();
  const allocation = { operationId: 'assign-team', action: 'assign', taskId: 'team', taskRevision: 2,
    approvalRevision: 2, workerId: 'lead', claimToken, approvedResponsibilities: [] };
  const assigned = await f.ok('sync-task', allocation);
  assert.equal(assigned.result.task.state, 'running');
  assert.equal(assigned.boardRevision, ready.boardRevision + 1, 'Grant and claim commit together');
  const reported = await f.ok('sync-task', { operationId: 'report-team', action: 'report',
    taskId: 'team', taskRevision: 3, workerId: 'lead', assignmentId: assigned.result.assignment.id,
    claimToken, phase: 'implementation', progress: 'First real milestone', nextCheckpoint: 'Freeze output' });
  assert.equal(reported.result.task.progress, 'First real milestone');
  assert.ok(reported.result.task.lastReportAt);
  assert.equal(reported.result.task.state, 'running');
  assertRedacted(reported, [claimToken, f.leadToken]);
  const history = (await f.ok('show', { taskId: 'team', history: true })).result.history;
  assert.deepEqual(history.items.filter(item => item.type === 'sync-task').map(item => item.data.action),
    ['prepare', 'assign', 'report'], 'Task history includes each semantic action once, despite receipt retry');
  assertRedacted(history, [claimToken, f.leadToken]);
  await f.ok('release', { taskId: 'team', taskRevision: 4, writesStopped: true, processStopped: true });
  assert.equal((await f.raw('sync-task', allocation)).reply.error.code, 'STALE_ASSIGNMENT');
  assert.equal((await f.ok('inspect')).result.tasks.length, 1);
});

test('SYNC.denialsAreAtomicAndDoNotInventWorkersOrProxyDirectReports', async t => {
  const f = await fixture(t);
  let before = (await f.ok('inspect')).result;
  assert.notEqual((await f.raw('sync-task', { action: 'prepare', task: contract('denied') })).code, 0);
  assert.deepEqual((await f.ok('inspect')).result, before);
  await f.ok('sync-task', { action: 'prepare', contractApproved: true, task: contract('team') });
  before = (await f.ok('inspect')).result;
  const payload = { action: 'assign', taskId: 'team', taskRevision: 2, approvalRevision: 2,
    workerId: 'missing', claimToken: secret() };
  assert.notEqual((await f.raw('sync-task', payload)).code, 0);
  assert.deepEqual((await f.ok('inspect')).result, before);
  await f.worker('writer');
  before = (await f.ok('inspect')).result;
  assert.notEqual((await f.raw('sync-task', { ...payload, workerId: 'writer', claimToken: 'invalid' })).code, 0);
  assert.deepEqual((await f.ok('inspect')).result, before, 'Failed claim must roll back its new grant');
  const assigned = await f.ok('sync-task', { ...payload, workerId: 'writer' });
  before = (await f.ok('inspect')).result;
  const denied = await f.raw('sync-task', { action: 'report', workerId: 'writer', taskId: 'team',
    taskRevision: 3, assignmentId: assigned.result.assignment.id, claimToken: payload.claimToken, progress: 'Forged' });
  assert.equal(denied.reply.error.code, 'UNAUTHORIZED');
  assert.deepEqual((await f.ok('inspect')).result, before);
});

test('SYNC.readonlyProxyDiagnosticNamesMissingReadCapability', async t => {
  const f = await fixture(t);
  await f.ok('register', { worker: { id: 'reader', role: 'backend', mode: 'lead-proxy',
    capabilities: [], workerToken: secret() } });
  await f.ok('sync-task', { action: 'prepare', contractApproved: true,
    task: { ...contract('team'), scope: { read: ['src'], write: [] } } });
  const denied = await f.raw('sync-task', { action: 'assign', taskId: 'team', taskRevision: 2,
    approvalRevision: 2, workerId: 'reader', claimToken: secret() });
  assert.equal(denied.reply.error.code, 'UNAUTHORIZED');
  assert.match(denied.reply.error.message, /capabilities.*read/);
});
