import test from 'node:test';
import assert from 'node:assert/strict';
import { domainFixture } from './domain-fixture.mjs';
import { fixture, secret } from './helpers.mjs';

/** Establish an approved self-execution task through real domain operations, without SQLite. */
function inlineFixture() {
  const f = domainFixture();
  f.run('register', { worker: { id: 'lead', role: 'lead', mode: 'lead-inline',
    capabilities: ['write'] } });
  f.run('add', { task: { id: 'work', title: 'Bounded inline work', outcome: 'Approved result',
    sourceRefs: ['fixture/work'], acceptanceRefs: ['fixture/accept'], eligibleRoles: ['backend'],
    responsibilities: ['backend'], allowLeadInline: true, workspaceId: 'main',
    scope: { read: [], write: ['src/inline.mjs'] }, resources: [], dependencies: [] } });
  f.run('approve', { taskId: 'work' });
  f.run('grant', { taskId: 'work', workerId: 'lead', approvalRevision: 2,
    executionMode: 'lead-inline', approvedResponsibilities: ['backend'] });
  return f;
}

/** Snapshot every mutable repository so rejected approval cannot acquire ownership or resources. */
function snapshot(tx) {
  return structuredClone({ board: tx.board, ...Object.fromEntries(Object.entries(tx)
    .filter(([, value]) => typeof value?.list === 'function')
    .map(([name, repo]) => [name, repo.list()])) });
}

// Missing, zero, stale and unrelated approval versions must all reject before mutating domain state.
for (const revision of [undefined, 0, 1, 999]) {
  test(`InlineApproval.rejectInvalid.${revision ?? 'missing'}`, () => {
    const f = inlineFixture();
    const before = snapshot(f.tx);
    const input = f.request('lead-inline-assign', { taskId: 'work',
      ...(revision === undefined ? {} : { approvalRevision: revision }), claimToken: secret() });
    assert.throws(() => f.run('lead-inline-assign', input), error => error.code === 'UNAUTHORIZED');
    assert.deepEqual(snapshot(f.tx), before);
  });
}

// A current revision remains valid both on first assignment and when authorizing its exact receipt.
test('InlineApproval.currentAndReplay', () => {
  const f = inlineFixture();
  const input = f.request('lead-inline-assign', { taskId: 'work', approvalRevision: 2,
    claimToken: secret() });
  const result = f.run('lead-inline-assign', input);
  assert.equal(result.assignment.approvalRevision, 2);
  const before = snapshot(f.tx);
  assert.doesNotThrow(() => f.authorize('lead-inline-assign', input, result));
  assert.deepEqual(snapshot(f.tx), before);
});

// Actual CLI/SQLite: denials leave the board unchanged; a valid operation has one durable receipt.
test('InlineApproval.cliAtomicDenialAndReplay', async t => {
  const f = await fixture(t);
  await f.ok('register', { worker: { id: 'lead', role: 'lead', mode: 'lead-inline',
    capabilities: ['write'] } });
  await f.ok('add', { task: { id: 'work', title: 'Inline contract', outcome: 'Verified result',
    sourceRefs: ['fixture/work'], acceptanceRefs: ['fixture/accept'], eligibleRoles: ['backend'],
    responsibilities: ['backend'], allowLeadInline: true, scope: { read: [], write: ['src/inline.mjs'] },
    resources: [], dependencies: [] } });
  await f.ok('approve', { taskId: 'work', taskRevision: 1 });
  await f.ok('grant', { taskId: 'work', workerId: 'lead', approvalRevision: 2,
    executionMode: 'lead-inline', approvedResponsibilities: ['backend'] });
  const before = (await f.ok('inspect')).result;
  for (const revision of [undefined, 0, 1, 999]) {
    const denied = await f.raw('lead-inline-assign', { taskId: 'work', taskRevision: 2,
      ...(revision === undefined ? {} : { approvalRevision: revision }), claimToken: secret() });
    assert.equal(denied.reply.error.code, 'UNAUTHORIZED');
    assert.deepEqual((await f.ok('inspect')).result, before);
  }
  const request = { operationId: 'approved-inline-once', taskId: 'work', taskRevision: 2,
    approvalRevision: 2, claimToken: secret() };
  const first = await f.ok('lead-inline-assign', request);
  const assigned = (await f.ok('inspect')).result;
  const replay = await f.ok('lead-inline-assign', request);
  assert.deepEqual(replay, first);
  assert.deepEqual((await f.ok('inspect')).result, assigned);
});
