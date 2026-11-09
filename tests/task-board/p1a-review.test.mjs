// P1a reviewer regressions: late relative to original implementation, test-first for repair attempt1.
import test from 'node:test';
import assert from 'node:assert/strict';
import { domainFixture } from './domain-fixture.mjs';

// A reconciled/resubmitted consumer must bind the fresh freeze and be invalidated on its next change.
test('P1A.review.repeatedInputInvalidation', () => {
  const f = domainFixture();
  f.add('producer');
  f.add('consumer', [{ taskId: 'producer', gate: 'frozen-submission' }]);
  const producer = f.claim('producer');
  f.submit(producer.owner);
  const consumer = f.claim('consumer');
  f.run('return', { taskId: 'producer', evidenceRefs: ['fixture/review#repair'] });
  f.submit(producer.owner);
  f.confirm('consumer');
  assert.throws(() => f.submit(consumer.owner),
    error => error.code === 'STALE_ASSIGNMENT' || error.code === 'DEPENDENCY_BLOCKED');
  const transferred = f.run('transfer', { taskId: 'consumer', newWorkerId: 'first-worker',
    newClaimToken: '76'.repeat(32),
    expectedApprovalRevision: f.tx.tasks.get('consumer').approvalRevision,
    writesStopped: true, processStopped: true, handoffRefs: ['fixture/handoff#new-input'] });
  f.submit({ ...consumer.owner, assignmentId: transferred.assignment.id,
    claimToken: '76'.repeat(32) });
  f.run('accept', { taskId: 'consumer', gatesSatisfied: true,
    evidenceRefs: ['fixture/review#accepted-current'] });
  assert.equal(f.tx.tasks.get('consumer').resultValid, true);
  f.run('return', { taskId: 'producer', evidenceRefs: ['fixture/review#next-repair'] });
  assert.equal(f.tx.tasks.get('consumer').state, 'closed', 'Historical completion preserved');
  assert.equal(f.tx.tasks.get('consumer').resultValid, false,
    'Newly consumed evidence must invalidate when that exact fresh upstream gate changes');
});

// Withdrawal of approval is an authority boundary: reconciled input alone cannot authorize transfer.
test('P1A.review.zeroApprovalCannotTransfer', () => {
  const f = domainFixture();
  f.add('work');
  f.claim('work');
  f.run('amend', { taskId: 'work', patch: { outcome: 'Changed approved contract' } });
  f.confirm('work');
  const task = f.tx.tasks.get('work');
  assert.equal(task.approvalRevision, 0);
  assert.throws(() => f.run('grant', { taskId: 'work', workerId: 'second-worker',
    approvalRevision: 0 }), error => error.code === 'UNAUTHORIZED');
  // A malformed legacy grant fixture must not bypass the independent transfer approval guard.
  f.tx.grants.put({ id: JSON.stringify(['work', 'second-worker']), taskId: 'work',
    workerId: 'second-worker', approvalRevision: 0, revoked: false });
  assert.throws(() => f.run('transfer', { taskId: 'work', newWorkerId: 'second-worker',
    newClaimToken: '65'.repeat(32), expectedApprovalRevision: 0,
    writesStopped: true, processStopped: true, handoffRefs: ['fixture/handoff#unapproved'] }),
  error => error.code === 'UNAUTHORIZED' || error.code === 'DEPENDENCY_BLOCKED');
});

// Current assignment identity/local revision cannot revive a receipt whose consumed inputs went stale.
test('P1A.review.invalidInputReceiptRejected', () => {
  const f = domainFixture();
  f.add('producer');
  f.add('consumer', [{ taskId: 'producer', gate: 'frozen-submission' }]);
  const producer = f.claim('producer');
  f.submit(producer.owner);
  const consumer = f.claim('consumer');
  const boundInput = f.tx.tasks.get('consumer').inputRevision;
  f.run('return', { taskId: 'producer', evidenceRefs: ['fixture/review#invalidate'] });
  const invalid = f.tx.tasks.get('consumer');
  assert.equal(invalid.inputRevision, boundInput);
  assert.equal(invalid.inputValid, false);
  assert.equal(invalid.needsReconcile, true);
  assert.throws(() => f.replay(consumer),
    error => error.code === 'STALE_ASSIGNMENT' || error.code === 'DEPENDENCY_BLOCKED');
});


// Immutable historical bindings survive a later allocation consuming a different upstream revision.
test('P1A.review.immutableConsumptionHistory', () => {
  const f = domainFixture();
  f.add('producer');
  f.add('consumer', [{ taskId: 'producer', gate: 'frozen-submission' }]);
  const producer = f.claim('producer');
  f.submit(producer.owner);
  const consumed = f.tx.tasks.get('producer');
  const consumer = f.claim('consumer');
  f.submit(consumer.owner);
  const oldAssignmentId = consumer.result.assignment.id;
  const oldSubmissionId = f.tx.submissions.list({ taskId: 'consumer' })[0].id;
  const expected = [{ taskId: 'producer', gate: 'frozen-submission',
    inputRevision: consumed.inputRevision, gateRevision: consumed.freezeRevision,
    workspaceBindings: [{ workspaceId: 'main', workspaceRevision: 1,
      root: f.tx.board.projectRoot, repositoryIdentity: null,
      checkoutIdentity: f.tx.board.workspaces[0].checkoutIdentity }] }];
  assert.deepEqual(f.tx.assignments.get(oldAssignmentId).inputBindings, expected);
  assert.deepEqual(f.tx.submissions.get(oldSubmissionId).inputBindings, expected);
  const oldEpoch = f.tx.assignments.get(oldAssignmentId).executionRevision;
  assert.equal(oldEpoch, f.tx.tasks.get('consumer').executionRevision);
  f.run('return', { taskId: 'producer', evidenceRefs: ['fixture/review#new-input'] });
  f.submit(producer.owner);
  f.confirm('consumer');
  const moved = f.run('transfer', { taskId: 'consumer', newWorkerId: 'first-worker',
    newClaimToken: '87'.repeat(32),
    expectedApprovalRevision: f.tx.tasks.get('consumer').approvalRevision,
    writesStopped: true, processStopped: true, handoffRefs: ['fixture/handoff#new-allocation'] });
  assert.deepEqual(f.tx.assignments.get(oldAssignmentId).inputBindings, expected);
  assert.deepEqual(f.tx.submissions.get(oldSubmissionId).inputBindings, expected);
  const fresh = f.tx.assignments.get(moved.assignment.id);
  assert.ok(fresh.executionRevision > oldEpoch);
  assert.deepEqual(fresh.inputBindings, [{ ...expected[0],
    gateRevision: f.tx.tasks.get('producer').freezeRevision }]);
});

// Action-specific guard: applicable frozen evidence remains acceptable after safe resource release.
test('P1A.review.releasedFreezeAccepts', () => {
  const f = domainFixture();
  f.add('work');
  const owner = f.claim('work');
  f.submit(owner.owner);
  f.run('release', { taskId: 'work', writesStopped: true, processStopped: true });
  assert.equal(f.tx.assignments.list({ taskId: 'work', active: true }).length, 0);
  const accepted = f.run('accept', { taskId: 'work', gatesSatisfied: true,
    evidenceRefs: ['fixture/review#applicable-frozen-evidence'] });
  assert.equal(accepted.task.state, 'closed');
  assert.equal(accepted.task.resultValid, true);
});

// Missing historical epoch is unknown, not implicit execution1; only explicit reconcile may proceed.
test('P1A.review.unknownEpochFailsClosed', () => {
  const f = domainFixture();
  f.add('work');
  const owner = f.claim('work');
  f.submit(owner.owner);
  const historical = f.tx.tasks.get('work');
  delete historical.executionRevision;
  f.tx.tasks.put(historical);
  assert.throws(() => f.run('accept', { taskId: 'work', gatesSatisfied: true,
    evidenceRefs: ['fixture/review#cannot-adopt-unknown'] }),
  error => error.code === 'DEPENDENCY_BLOCKED');
  assert.equal(f.tx.tasks.get('work').executionRevision, undefined);
  f.confirm('work');
  assert.ok(Number.isSafeInteger(f.tx.tasks.get('work').executionRevision));
  assert.equal(f.tx.tasks.get('work').resultValid, false);
  assert.ok(f.tx.submissions.list({ taskId: 'work' }).every(item => !item.freezeValid));
});

// Repair round2 continuity: phase/task CAS advancement alone cannot revoke an unchanged claim receipt.
test('P1A.review.normalReceiptContinuity.claimAfterSubmit', () => {
  const f = domainFixture();
  f.add('work');
  const claimed = f.claim('work');
  f.submit(claimed.owner);
  const before = f.tx.tasks.get('work');
  assert.equal(before.state, 'submitted');
  assert.doesNotThrow(() => f.replay(claimed));
  assert.deepEqual(f.tx.tasks.get('work'), before, 'Replay authorization performs no new work');
});

// Repair round2 continuity: accepting still-current frozen evidence preserves its submit receipt.
test('P1A.review.normalReceiptContinuity.submitAfterAccept', () => {
  const f = domainFixture();
  f.add('work');
  const claimed = f.claim('work');
  const input = f.request('submit', { ...claimed.owner, writesStopped: true, processStopped: true,
    inputRevision: 'opaque-source-snapshot', evidenceRefs: ['fixture/tests#pass'] });
  const result = f.run('submit', input);
  f.run('accept', { taskId: 'work', gatesSatisfied: true,
    evidenceRefs: ['fixture/review#accepted'] });
  const before = f.tx.tasks.get('work');
  assert.equal(before.state, 'closed');
  assert.doesNotThrow(() => f.authorize('submit', input, result));
  assert.deepEqual(f.tx.tasks.get('work'), before, 'Replay authorization preserves current state');
});
