// P1a contract tests are authored before production GO; each group owns an isolated real CLI chain.
import test from 'node:test';
import assert from 'node:assert/strict';
import { join } from 'node:path';
import { fixture, invoke, secret, assertRedacted } from './helpers.mjs';

// Read the current task CAS separately from immutable input/result/freeze revision oracles.
async function task(f, id) {
  return (await f.ok('show', { taskId: id })).result.task;
}

// Arrange a real authorized claim; caller keeps the credential for subsequent lifecycle requests.
async function claim(f, id, worker = 'w1') {
  await f.grant(worker, id);
  const current = await task(f, id);
  const claimToken = secret();
  const reply = await f.ok('claim', { actorId: worker, workerToken: f.workers[worker],
    taskId: id, taskRevision: current.taskRevision, claimToken });
  return { actorId: worker, workerToken: f.workers[worker], claimToken,
    assignmentId: reply.result.assignment.id };
}

// Submit with real stopped declarations; this asserts protocol facts, not native-host compliance.
async function submit(f, id, owner) {
  const current = await task(f, id);
  await f.ok('submit', { ...owner, taskId: id, taskRevision: current.taskRevision,
    writesStopped: true, processStopped: true, inputRevision: `fixture-source-${id}`,
    evidenceRefs: [`fixture/tests#${id}`] });
}

// Group 1 / CASE-04/06: cosmetic input stability, graph validation and CAS rejection are atomic.
test('P1A.graphCas', async t => {
  const f = await fixture(t);
  await f.task('a');
  await f.task('b');
  const original = await task(f, 'a');
  const amended = await f.ok('amend', { taskId: 'a', taskRevision: original.taskRevision,
    expectedInputRevision: 1, reason: 'Clarify title only', patch: { title: 'Clearer title' } });
  assert.equal(amended.result.task.inputRevision, 1);
  assert.equal(amended.result.task.taskRevision, original.taskRevision + 1);
  const before = (await f.ok('inspect')).result;
  assert.equal(before.schemaVersion, 1, 'Public snapshot uses protocol version 1');
  const stale = await f.raw('amend', { taskId: 'a', taskRevision: original.taskRevision,
    expectedInputRevision: 1, reason: 'Stale edit', patch: { outcome: 'Must not apply' } });
  assert.equal(stale.reply.error.code, 'CONFLICT');
  const missing = await f.raw('amend', { taskId: 'a',
    taskRevision: amended.result.task.taskRevision, expectedInputRevision: 1,
    reason: 'Missing dependency', patch: { dependencies: [
      { taskId: 'missing', gate: 'accepted-result' },
    ] } });
  assert.equal(missing.code, 2);
  assert.deepEqual((await f.ok('inspect')).result, before);
  const linked = await f.ok('amend', { taskId: 'a',
    taskRevision: amended.result.task.taskRevision, expectedInputRevision: 1,
    reason: 'Consume b', patch: { dependencies: [{ taskId: 'b', gate: 'accepted-result' }] } });
  assert.equal(linked.result.task.inputRevision, 2);
  const cycleBefore = (await f.ok('inspect')).result;
  const b = await task(f, 'b');
  const cycle = await f.raw('amend', { taskId: 'b', taskRevision: b.taskRevision,
    expectedInputRevision: 1, reason: 'Cycle must fail',
    patch: { dependencies: [{ taskId: 'a', gate: 'accepted-result' }] } });
  assert.equal(cycle.code, 2);
  assert.deepEqual((await f.ok('inspect')).result, cycleBefore);
});

// Group 2 / CASE-30/32: return invalidates consumed freeze and accepted descendants, not history.
test('P1A.outputInvalidation', async t => {
  const f = await fixture(t);
  await f.worker('w1');
  await f.worker('reviewer');
  await f.task('writer');
  await f.task('review', 'src/review.mjs', [{ taskId: 'writer', gate: 'frozen-submission' }]);
  await f.task('consumer', 'src/consumer.mjs', [{ taskId: 'review', gate: 'accepted-result' }]);
  await f.task('unrelated');
  const owner = await claim(f, 'writer');
  await submit(f, 'writer', owner);
  const reviewer = await claim(f, 'review', 'reviewer');
  await submit(f, 'review', reviewer);
  let current = await task(f, 'review');
  await f.ok('accept', { taskId: 'review', taskRevision: current.taskRevision,
    evidenceRefs: ['fixture/review#pass'], gatesSatisfied: true });
  const unrelated = await task(f, 'unrelated');
  current = await task(f, 'writer');
  await f.ok('return', { taskId: 'writer', taskRevision: current.taskRevision,
    reason: 'Repair implementation', evidenceRefs: ['fixture/review#finding'] });
  const returned = await task(f, 'writer');
  assert.equal(returned.state, 'running');
  assert.equal(returned.inputValid, true);
  assert.equal(returned.resultValid, false);
  const review = await task(f, 'review');
  assert.equal(review.state, 'closed', 'Historical completion remains recorded');
  assert.equal(review.resultValid, false, 'Consumed obsolete freeze invalidates old review result');
  assert.deepEqual(await task(f, 'unrelated'), unrelated);
  const ready = await f.ok('ready');
  assert.ok(!ready.result.tasks.some(item => item.id === 'consumer'));
  const beforeProgress = await task(f, 'writer');
  await f.ok('report', { ...owner, taskId: 'writer', taskRevision: returned.taskRevision,
    phase: 'repair', progress: 'Working on applicable input' });
  const afterProgress = await task(f, 'writer');
  assert.equal(afterProgress.inputRevision, beforeProgress.inputRevision);
  assert.equal(afterProgress.resultRevision, beforeProgress.resultRevision);
  // Producer can produce a fresh freeze despite old result invalidity; no automatic evidence revival.
  await submit(f, 'writer', owner);
  assert.equal((await task(f, 'review')).resultValid, false);
  const submissions = (await f.ok('show', { taskId: 'writer' })).result.submissions;
  const valid = submissions.filter(item => item.freezeValid);
  assert.equal(valid.length, 1);
  const invalid = submissions.filter(item => !item.freezeValid);
  assert.ok(invalid.length >= 1);
  assert.ok(invalid.every(item => item.freezeRevision < valid[0].freezeRevision));
});

// Group 3 / CASE-06: stop-unknown transfer fails unchanged; safe transfer swaps ownership atomically.
test('P1A.safeTransfer', async t => {
  const f = await fixture(t);
  await f.worker('w1');
  await f.worker('w2');
  await f.task('owned');
  const old = await claim(f, 'owned');
  await f.grant('w2', 'owned');
  const current = await task(f, 'owned');
  const payload = { taskId: 'owned', taskRevision: current.taskRevision,
    reason: 'Bounded handoff', newWorkerId: 'w2', newClaimToken: secret(),
    expectedApprovalRevision: current.approvalRevision, handoffRefs: ['fixture/handoff#owned'],
    writesStopped: false, processStopped: false };
  const before = (await f.ok('inspect')).result;
  assert.equal(before.schemaVersion, 1, 'Public snapshot uses protocol version 1');
  const denied = await f.raw('transfer', payload);
  assert.equal(denied.reply.error.code, 'RECOVERY_REQUIRED');
  assert.deepEqual((await f.ok('inspect')).result, before);
  const moved = await f.ok('transfer', { ...payload, writesStopped: true, processStopped: true });
  const state = (await f.ok('inspect')).result;
  assert.equal(state.assignments.filter(item => item.active).length, 1);
  assert.equal(moved.result.assignment.workerId, 'w2');
  assert.ok(state.reservations.filter(item => item.active)
    .every(item => item.assignmentId === moved.result.assignment.id));
  assertRedacted(moved, [f.leadToken, ...Object.values(f.workers), old.claimToken,
    payload.newClaimToken]);
  const stale = await f.raw('report', { ...old, taskId: 'owned',
    taskRevision: moved.result.task.taskRevision, phase: 'stale', progress: 'Denied' });
  assert.equal(stale.reply.error.code, 'STALE_ASSIGNMENT');
  const canceled = await f.ok('cancel', { taskId: 'owned',
    taskRevision: moved.result.task.taskRevision, reason: 'Stop this work' });
  assert.equal(canceled.result.task.state, 'canceled');
  assert.equal(canceled.result.task.cleanupPending, true);
  const held = (await f.ok('inspect')).result;
  assert.ok(held.reservations.some(item => item.active));
});

// Group 4 / CASE-09/14/18: observed-source statements and complete recovery accounting fail closed.
test('P1A.explicitReconcile', async t => {
  const f = await fixture(t);
  await f.worker('w1');
  await f.task('one');
  await f.task('two');
  await claim(f, 'one');
  await claim(f, 'two');
  const current = await task(f, 'one');
  const before = (await f.ok('inspect')).result;
  assert.equal(before.schemaVersion, 1, 'Public snapshot uses protocol version 1');
  const unavailable = await f.raw('reconcile', { taskId: 'one',
    taskRevision: current.taskRevision, expectedInputRevision: 1,
    reason: 'Source unavailable', decision: 'confirm', sourceRefs: ['opaque:original'],
    sourceObservation: { available: false } });
  assert.equal(unavailable.reply.error.code, 'SOURCE_UNAVAILABLE');
  assert.deepEqual((await f.ok('inspect')).result, before);
  const backupPath = join(f.project, 'p1a-recovery.sqlite');
  await f.ok('backup', { destination: backupPath });
  const restoredPath = join(f.project, 'restored');
  const restored = await invoke(f.project, restoredPath, 'restore', { actorId: 'lead',
    leadToken: f.leadToken, backupPath, maintenanceApproved: true,
    writesStopped: true, processStopped: true });
  assert.equal(restored.code, 0);
  const state = (await invoke(f.project, restoredPath, 'inspect', {
    actorId: 'lead', leadToken: f.leadToken, generation: restored.reply.generation })).reply.result;
  const assignments = state.assignments.filter(item => item.active);
  assert.equal(assignments.length, 2);
  const decisions = assignments.map(item => ({ taskId: item.taskId,
    taskRevision: state.tasks.find(value => value.id === item.taskId).taskRevision,
    assignmentId: item.id, disposition: 'retain-blocked',
    evidenceRefs: ['fixture/recovery#unknown-process'] }));
  const recover = data => invoke(f.project, restoredPath, 'recover', {
    operationId: data.operationId, actorId: 'lead', leadToken: f.leadToken,
    generation: state.generation, expectedBoardRevision: state.revision,
    externalEffectsReviewed: true, ...data });
  const omitted = await recover({ operationId: 'omit-holder', decisions: decisions.slice(0, 1) });
  assert.equal(omitted.code, 2);
  assert.deepEqual((await invoke(f.project, restoredPath, 'inspect', {
    actorId: 'lead', leadToken: f.leadToken, generation: restored.reply.generation })).reply.result, state);
  const accounted = await recover({ operationId: 'account-all', decisions });
  assert.equal(accounted.code, 0);
  assert.equal(accounted.reply.result.recovered, true);
  const final = (await invoke(f.project, restoredPath, 'inspect', {
    actorId: 'lead', leadToken: f.leadToken, generation: restored.reply.generation })).reply.result;
  assert.equal(final.recoveryRequired, false);
  assert.equal(final.reservations.filter(item => item.active).length,
    state.reservations.filter(item => item.active).length);
  assert.ok(final.tasks.every(item => item.state === 'blocked'));
});


// Late P1a negative coverage: released writer cannot return to execution without reacquiring holds.
// This is test-after relative to initial Red; no unreachable original assertion is claimed executed.
test('P1A.outputReleasedReturnDenied', async t => {
  const f = await fixture(t);
  await f.worker('w1');
  await f.task('writer');
  const owner = await claim(f, 'writer');
  await submit(f, 'writer', owner);
  let current = await task(f, 'writer');
  await f.ok('release', { taskId: 'writer', taskRevision: current.taskRevision,
    writesStopped: true, processStopped: true });
  current = await task(f, 'writer');
  const before = (await f.ok('inspect')).result;
  assert.equal(before.schemaVersion, 1, 'Public snapshot uses protocol version 1');
  const returned = await f.raw('return', { taskId: 'writer', taskRevision: current.taskRevision,
    reason: 'Cannot reuse released owner', evidenceRefs: ['fixture/review#finding'] });
  assert.equal(returned.reply.error.code, 'RESOURCE_REACQUIRE_REQUIRED');
  assert.deepEqual((await f.ok('inspect')).result, before);
});

// Late P1a source coverage: an explicit Lead observation confirms input, never old output/freeze.
// Opaque source reference strings are not treated as automatically verified files.
test('P1A.reconcileObservationDoesNotReviveEvidence', async t => {
  const f = await fixture(t);
  await f.worker('w1');
  await f.task('writer');
  const owner = await claim(f, 'writer');
  await submit(f, 'writer', owner);
  let current = await task(f, 'writer');
  const amended = await f.ok('amend', { taskId: 'writer', taskRevision: current.taskRevision,
    expectedInputRevision: current.inputRevision, reason: 'Changed applicable outcome',
    patch: { outcome: 'Changed scoped contract' } });
  current = amended.result.task;
  const reconciled = await f.ok('reconcile', { taskId: 'writer', taskRevision: current.taskRevision,
    expectedInputRevision: current.inputRevision, reason: 'Lead observed applicable source',
    decision: 'confirm', sourceRefs: current.sourceRefs,
    sourceObservation: { available: true, revision: 'fixture-observation-v2',
      evidenceRefs: ['fixture/observed#source'] } });
  assert.equal(reconciled.result.task.inputValid, true);
  assert.equal(reconciled.result.task.needsReconcile, false);
  assert.equal(reconciled.result.task.resultValid, false);
  const submissions = (await f.ok('show', { taskId: 'writer' })).result.submissions;
  assert.ok(submissions.length > 0);
  assert.ok(submissions.every(item => item.freezeValid === false));
});
