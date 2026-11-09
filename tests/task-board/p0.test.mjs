// Each scenario asserts persisted business outcomes through the actual production CLI.
import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture, assertRedacted, invoke } from './helpers.mjs';
import { join } from 'node:path';

// CASE-02: authorized processes race; only one may obtain the approved assignment.
test('P0.atomicClaim', async t => {
  const f = await fixture(t);
  await f.worker('w1');
  await f.worker('w2');
  await f.task('t1');
  await f.grant('w1', 't1');
  await f.grant('w2', 't1');
  const results = await Promise.all([f.claim('w1', 't1'), f.claim('w2', 't1')]);
  assert.equal(results.filter(r => r.code === 0 && r.reply.ok).length, 1);
  assert.equal(results.filter(r => r.code === 2 && !r.reply.ok).length, 1,
    JSON.stringify(results));
  const state = await f.ok('show', { taskId: 't1' });
  assert.equal(state.result.task.state, 'running');
  const winning = results.find(r => r.code === 0).reply.result.assignment;
  assert.equal(state.result.assignment.id, winning.id);
  assert.ok(['w1', 'w2'].includes(state.result.assignment.workerId));
  const snapshot = await f.ok('inspect');
  assert.equal(snapshot.result.assignments.filter(a => a.active && a.taskId === 't1').length, 1);
  assert.ok(snapshot.result.reservations.some(r => r.active && r.assignmentId === winning.id));
  assertRedacted(snapshot, [f.leadToken, ...Object.values(f.workers)]);
});

// CASE-03/12: bad roles and absent grants cannot claim; file overlap retains one owner.
test('P0.authorityResources', async t => {
  const f = await fixture(t);
  await f.worker('w1');
  await f.worker('w2');
  await f.worker('reviewer', 'reviewer');
  await f.task('t1', 'src/shared.mjs');
  await f.task('t2', 'src/shared.mjs');
  const ungranted = await f.claim('w1', 't1');
  assert.equal(ungranted.code, 2);
  const wrongRole = await f.raw('grant', { workerId: 'reviewer', taskId: 't1',
    approvalRevision: 2 });
  assert.equal(wrongRole.code, 2);
  assert.equal(wrongRole.reply.error.code, 'UNAUTHORIZED');
  const unchanged = await f.ok('show', { taskId: 't1' });
  assert.equal(unchanged.result.assignment, null);
  await f.grant('w1', 't1');
  await f.grant('w2', 't2');
  assert.equal((await f.claim('w1', 't1')).code, 0);
  const conflicting = await f.claim('w2', 't2');
  assert.equal(conflicting.code, 2);
  assert.equal(conflicting.reply.error.code, 'SCOPE_CONFLICT');
});

// CASE-04/05/30: freeze submission unlocks only freeze-gated work; acceptance gates wait.
test('P0.acceptanceGate', async t => {
  const f = await fixture(t);
  await f.worker('w1');
  await f.task('t1');
  await f.task('accepted', 'src/accepted.mjs', [{ taskId: 't1', gate: 'accepted-result' }]);
  await f.task('frozen', 'src/frozen.mjs', [{ taskId: 't1', gate: 'frozen-submission' }]);
  // P2 global readiness additionally requires a current eligible grant for each candidate.
  await f.grant('w1', 'accepted');
  await f.grant('w1', 'frozen');
  await f.grant('w1', 't1');
  const before = await f.ok('ready');
  assert.ok(!before.result.tasks.some(task => task.id === 'accepted'));
  assert.ok(!before.result.tasks.some(task => task.id === 'frozen'));
  const claimToken = 'ab'.repeat(32);
  const claim = await f.ok('claim', { actorId: 'w1', workerToken: f.workers.w1,
    taskId: 't1', taskRevision: 2, claimToken });
  const assignmentId = claim.result.assignment.id;
  await f.ok('submit', { actorId: 'w1', workerToken: f.workers.w1, taskId: 't1',
    taskRevision: 3, assignmentId, claimToken, writesStopped: true, processStopped: true,
    inputRevision: 'fixture-input-v1', evidenceRefs: ['fixture/test#pass'] });
  const submitted = await f.ok('show', { taskId: 't1' });
  assert.equal(submitted.result.task.state, 'submitted');
  const frozen = await f.ok('ready');
  assert.ok(frozen.result.tasks.some(task => task.id === 'frozen'));
  assert.ok(!frozen.result.tasks.some(task => task.id === 'accepted'));
  await f.ok('accept', { taskId: 't1', taskRevision: 4,
    evidenceRefs: ['fixture/review#pass'], gatesSatisfied: true });
  const accepted = await f.ok('ready');
  assert.ok(accepted.result.tasks.some(task => task.id === 'accepted'));
});

// CASE-07: a committed request replays identically; reusing its ID for new data is denied.
test('P0.operationReplay', async t => {
  const f = await fixture(t);
  const payload = { operationId: 'registration-replay', worker: { id: 'w1',
    hostId: 'fixture-host', role: 'backend', mode: 'direct', capabilities: ['write'],
    workerToken: 'cd'.repeat(32) } };
  const first = await f.raw('register', payload);
  assert.equal(first.code, 0);
  const replay = await f.raw('register', payload);
  assert.equal(replay.code, 0);
  assert.deepEqual(replay.reply, first.reply);
  assertRedacted(replay, [f.leadToken, payload.worker.workerToken]);
  const mismatch = await f.raw('register', { ...payload,
    worker: { ...payload.worker, hostId: 'different-host' } });
  assert.equal(mismatch.code, 2);
  assert.equal(mismatch.reply.ok, false);
});



// CASE-06/07: an old successful claim receipt cannot restore authority after safe release.
test('P0.revokedClaimReplay', async t => {
  const f = await fixture(t);
  await f.worker('w1');
  await f.task('t1');
  await f.grant('w1', 't1');
  const payload = { operationId: 'replayed-claim', actorId: 'w1',
    workerToken: f.workers.w1, taskId: 't1', taskRevision: 2, claimToken: 'ef'.repeat(32) };
  const claimed = await f.raw('claim', payload);
  assert.equal(claimed.code, 0);
  const current = await f.raw('claim', payload);
  assert.equal(current.code, 0, 'Current assignment permits identical receipt replay');
  assert.deepEqual(current.reply, claimed.reply);
  assertRedacted(current, [f.leadToken, f.workers.w1, payload.claimToken]);
  await f.ok('release', { taskId: 't1', taskRevision: 3,
    writesStopped: true, processStopped: true });
  const stale = await f.raw('claim', payload);
  assert.equal(stale.code, 2);
  assert.equal(stale.reply.error.code, 'STALE_ASSIGNMENT');
  const snapshot = await f.ok('inspect');
  assert.equal(snapshot.result.assignments.filter(a => a.active).length, 0);
  assert.equal(snapshot.result.reservations.filter(r => r.active).length, 0);
});

// P0 review fix regression: delimiter-bearing IDs must never alias another grant's scope.
// Expected: worker c remains unauthorized for task a:b despite grant(a, b:c) existing.
test('P0.review.grantCompositeCollision', async t => {
  const f = await fixture(t);
  await f.worker('b:c');
  await f.worker('c');
  await f.task('a', 'src/first.mjs');
  await f.task('a:b', 'src/second.mjs');
  await f.grant('b:c', 'a');
  const unauthorized = await f.claim('c', 'a:b');
  assert.equal(unauthorized.code, 2, 'A different task-worker pair must not inherit this grant');
  assert.equal(unauthorized.reply.error.code, 'UNAUTHORIZED');
  const unchanged = await f.ok('show', { taskId: 'a:b' });
  assert.equal(unchanged.result.assignment, null);
});

// P0 review fix regression: prospective Windows alias components must be rejected at input.
// Expected: x. and trailing-space components cannot create a second spelling of owned paths.
test('P0.review.prospectivePathAlias', async t => {
  const f = await fixture(t);
  await f.task('plain', 'src/x');
  for (const [id, path] of [['dot', 'src/x.'], ['space', 'src/x ']]) {
    const added = await f.raw('add', { task: { id, title: id, outcome: 'Safe scope',
      sourceRefs: ['fixture/work#alias'], acceptanceRefs: ['fixture/accept#alias'],
      eligibleRoles: ['backend'], scope: { read: [], write: [path] },
      resources: [], dependencies: [] } });
    assert.equal(added.code, 2, `Unsafe prospective alias ${JSON.stringify(path)} accepted`);
    assert.equal(added.reply.ok, false);
    const state = await f.ok('inspect');
    assert.ok(!state.result.tasks.some(task => task.id === id));
  }
});


// P0 review coverage: restoring live ownership preserves reservations and revokes old credentials.
// Expected: no automatic release, no new ready task, and old worker cannot report in new generation.
test('P0.restoredActiveOwnership', async t => {
  const f = await fixture(t);
  await f.worker('w1');
  await f.task('t1');
  await f.grant('w1', 't1');
  const claimToken = '12'.repeat(32);
  const claim = await f.ok('claim', { actorId: 'w1', workerToken: f.workers.w1,
    taskId: 't1', taskRevision: 2, claimToken });
  const assignmentId = claim.result.assignment.id;
  const backupPath = join(f.project, 'active-backup.sqlite');
  await f.ok('backup', { destination: backupPath });
  const restoredPath = join(f.project, 'restored-board');
  const restore = await invoke(f.project, restoredPath, 'restore', {
    actorId: 'lead', leadToken: f.leadToken, backupPath,
    maintenanceApproved: true, writesStopped: true, processStopped: true,
  });
  assert.equal(restore.code, 0, JSON.stringify(restore.reply));
  const generation = restore.reply.generation;
  assert.notEqual(generation, f.generation);
  const inspected = await invoke(f.project, restoredPath, 'inspect', {
    actorId: 'lead', leadToken: f.leadToken, generation });
  assert.equal(inspected.code, 0);
  const snapshot = inspected.reply.result;
  assert.equal(snapshot.recoveryRequired, true);
  assert.equal(snapshot.assignments.filter(a => a.active && a.id === assignmentId).length, 1);
  assert.ok(snapshot.reservations.some(r => r.active && r.assignmentId === assignmentId));
  assert.equal(snapshot.tasks.find(task => task.id === 't1').cleanupPending, true);
  assert.equal(snapshot.grants.length, 0);
  assertRedacted(snapshot, [f.leadToken, f.workers.w1, claimToken]);
  const ready = await invoke(f.project, restoredPath, 'ready', {
    actorId: 'lead', leadToken: f.leadToken, generation });
  assert.equal(ready.code, 0);
  assert.deepEqual(ready.reply.result.tasks, []);
  const stale = await invoke(f.project, restoredPath, 'report', {
    operationId: 'old-worker-in-new-generation', actorId: 'w1', workerToken: f.workers.w1,
    generation, taskId: 't1', taskRevision: 3, assignmentId, claimToken,
    phase: 'running', progress: 'Must be denied',
  });
  assert.equal(stale.code, 2);
  assert.equal(stale.reply.error.code, 'UNAUTHORIZED');
});

// Related composite dependency identities must preserve both distinct edges for colon-bearing IDs.
// Expected: neither downstream task becomes ready while its own predecessor is unaccepted.
test('P0.review.dependencyCompositeCollision', async t => {
  const f = await fixture(t);
  await f.task('b:c', 'src/upstream-first.mjs');
  await f.task('c', 'src/upstream-second.mjs');
  await f.task('a', 'src/downstream-first.mjs', [{ taskId: 'b:c', gate: 'accepted-result' }]);
  await f.task('a:b', 'src/downstream-second.mjs', [{ taskId: 'c', gate: 'accepted-result' }]);
  const ready = await f.ok('ready');
  assert.ok(!ready.result.tasks.some(task => ['a', 'a:b'].includes(task.id)));
  const state = await f.ok('inspect');
  assert.equal(state.result.dependencies.filter(edge => edge.taskId === 'a').length, 1);
  assert.equal(state.result.dependencies.filter(edge => edge.taskId === 'a:b').length, 1);
});
