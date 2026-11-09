// CASE-03/16 execution-time filesystem revalidation; authored while production is changing, not run yet.
import test from 'node:test';
import assert from 'node:assert/strict';
import { link, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fixture, secret } from './helpers.mjs';

// The scope is valid and prospective at add-time; only later does an owned physical alias appear.
async function setup(t) {
  const f = await fixture(t);
  await f.worker('w1');
  await f.worker('w2');
  await f.task('work', 'src/prospective.mjs');
  await f.grant('w1', 'work');
  await f.grant('w2', 'work');
  return f;
}

async function createAlias(f) {
  const seed = join(f.project, 'owned-seed.mjs');
  await writeFile(seed, 'export const ownedFixture = true;\n');
  await link(seed, join(f.project, 'src', 'prospective.mjs'));
}

// A scope which became a hard link after approval cannot acquire its first assignment/reservations.
test('PathRevalidation.claimRejectsLaterHardLink', async t => {
  const f = await setup(t);
  await createAlias(f);
  // Late test-after projection assertion: the same unsafe scope cannot appear Ready either.
  const ready = await f.ok('ready');
  assert.ok(!ready.result.tasks.some(task => task.id === 'work'));
  const before = (await f.ok('inspect')).result;
  assert.equal(before.tasks.find(task => task.id === 'work').readiness, 'blocked');
  const claimed = await f.claim('w1', 'work');
  assert.equal(claimed.code, 2, JSON.stringify(claimed.reply));
  assert.equal(claimed.reply.error.code, 'UNSAFE_PATH');
  assert.deepEqual((await f.ok('inspect')).result, before);
});

// A stopped transfer must not replace an existing owner when a scope now aliases another file.
test('PathRevalidation.transferRejectsLaterHardLink', async t => {
  const f = await setup(t);
  const claimed = await f.claim('w1', 'work');
  assert.equal(claimed.code, 0);
  await createAlias(f);
  // Late test-after projection assertion: the same unsafe scope cannot appear Ready either.
  const ready = await f.ok('ready');
  assert.ok(!ready.result.tasks.some(task => task.id === 'work'));
  const before = (await f.ok('inspect')).result;
  assert.equal(before.tasks.find(task => task.id === 'work').readiness, 'blocked');
  const current = before.tasks.find(task => task.id === 'work');
  const transferred = await f.raw('transfer', { taskId: 'work', taskRevision: current.taskRevision,
    reason: 'Stopped handoff still needs actual path validation', newWorkerId: 'w2',
    newClaimToken: secret(), expectedApprovalRevision: current.approvalRevision,
    writesStopped: true, processStopped: true, handoffRefs: ['fixture/handoff#stopped'] });
  assert.equal(transferred.code, 2, JSON.stringify(transferred.reply));
  assert.equal(transferred.reply.error.code, 'UNSAFE_PATH');
  assert.deepEqual((await f.ok('inspect')).result, before);
});

// Valid nonexistent scopes remain usable; revalidation must not require a file to exist prematurely.
test('PathRevalidation.unchangedProspectiveControl', async t => {
  const f = await setup(t);
  const claimed = await f.claim('w1', 'work');
  assert.equal(claimed.code, 0);
  const current = claimed.reply.result.task;
  const transferred = await f.ok('transfer', { taskId: 'work', taskRevision: current.taskRevision,
    reason: 'Legitimate unchanged prospective scope', newWorkerId: 'w2', newClaimToken: secret(),
    expectedApprovalRevision: current.approvalRevision, writesStopped: true, processStopped: true,
    handoffRefs: ['fixture/handoff#valid'] });
  const after = (await f.ok('inspect')).result;
  assert.equal(after.assignments.filter(assignment => assignment.active).length, 1);
  assert.equal(transferred.result.assignment.workerId, 'w2');
  assert.ok(after.reservations.filter(reservation => reservation.active)
    .every(reservation => reservation.assignmentId === transferred.result.assignment.id));
});
