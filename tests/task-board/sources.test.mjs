// SourceB contract tests: actual bounded source observations and durable invalidation, never caller proof.
import test from 'node:test';
import fs from 'node:fs';
import { observeSources } from '../../packages/task-board/src/sources/adapter.mjs';
import { initializeMainWorkspace } from '../../packages/task-board/src/storage/workspaces.mjs';
import assert from 'node:assert/strict';
import { writeFile, mkdir, access } from 'node:fs/promises';
import { join } from 'node:path';
import { fixture, invoke, secret } from './helpers.mjs';

async function addTyped(f, id = 'writer') {
  await writeFile(join(f.project, 'WORK.md'), '# Current work\nNative task declared by Lead.\n');
  const sourceRef = { schemaVersion: 1, kind: 'work', path: 'WORK.md', nativeTaskId: 'declared-id' };
  await f.ok('add', { task: { id, title: id, outcome: 'Current bounded result',
    sourceRefs: [sourceRef], acceptanceRefs: ['opaque:acceptance'], eligibleRoles: ['backend'],
    scope: { read: [], write: [`src/${id}.mjs`] }, resources: [], dependencies: [] } });
  return sourceRef;
}

// Read operation has no operationId or CAS; only current authenticated show-like scope.
async function check(f, taskId = 'writer') {
  const response = await invoke(f.project, f.board, 'source-check', { actorId: 'lead',
    leadToken: f.leadToken, generation: f.generation, taskId });
  assert.equal(response.code, 0, JSON.stringify(response.reply));
  return response.reply.result.observation;
}

// Actual Work fingerprint is a candidate only; query cannot create tasks, approval or execution facts.
test('SourceB.workCandidateReadOnly', async t => {
  const f = await fixture(t);
  await addTyped(f);
  const before = (await f.ok('inspect')).result;
  const observed = await check(f);
  assert.equal(observed.schemaVersion, 1);
  assert.equal(observed.status, 'unbaselined');
  assert.equal(observed.checkedRefs[0].status, 'unpinned');
  assert.match(observed.checkedRefs[0].actualRevision, /^[a-f0-9]{64}$/);
  assert.equal(observed.hasUnverifiedRefs, false);
  assert.deepEqual((await f.ok('inspect')).result, before);
});

// An unpinned typed source is not valid proof for approving execution.
test('SourceB.unpinnedCannotApprove', async t => {
  const f = await fixture(t);
  await addTyped(f);
  const denied = await f.raw('approve', { taskId: 'writer', taskRevision: 1 });
  assert.equal(denied.code, 2, JSON.stringify(denied.reply));
  const writer = (await f.ok('show', { taskId: 'writer' })).result.task;
  assert.equal(writer.state, 'planned');
  assert.equal(writer.approvalRevision, 0);
});

// Changed pinned input commits blocked state and invalidates consumed history despite forged proof.
test('SourceB.changedReconcileDurableInvalidation', async t => {
  const f = await fixture(t);
  await f.worker('w1');
  const reference = await addTyped(f);
  const candidate = await check(f);
  const pinned = { ...reference, expectedRevision: candidate.checkedRefs[0].actualRevision };
  let writer = (await f.ok('show', { taskId: 'writer' })).result.task;
  await f.ok('amend', { taskId: 'writer', taskRevision: writer.taskRevision,
    expectedInputRevision: writer.inputRevision, reason: 'Pin observed actual input',
    patch: { sourceRefs: [pinned] } });
  writer = (await f.ok('show', { taskId: 'writer' })).result.task;
  await f.ok('approve', { taskId: 'writer', taskRevision: writer.taskRevision });
  writer = (await f.ok('show', { taskId: 'writer' })).result.task;
  await f.ok('reconcile', { taskId: 'writer', taskRevision: writer.taskRevision,
    expectedInputRevision: writer.inputRevision, decision: 'confirm', reason: 'Confirm actual matched pin',
    sourceObservation: { available: true, revision: pinned.expectedRevision,
      evidenceRefs: ['fixture/source#actual'] } });
  await f.grant('w1', 'writer');
  writer = (await f.ok('show', { taskId: 'writer' })).result.task;
  const claimToken = secret();
  const claimInput = { operationId: 'typed-source-claim', actorId: 'w1',
    workerToken: f.workers.w1, taskId: 'writer', taskRevision: writer.taskRevision, claimToken };
  const claimed = await f.ok('claim', claimInput);
  const assignmentId = claimed.result.assignment.id;
  await f.ok('submit', { actorId: 'w1', workerToken: f.workers.w1, taskId: 'writer',
    taskRevision: claimed.result.task.taskRevision, assignmentId, claimToken,
    writesStopped: true, processStopped: true, inputRevision: 'opaque-evidence-snapshot',
    evidenceRefs: ['fixture/tests#writer'] });
  await f.task('review', 'src/review.mjs', [{ taskId: 'writer', gate: 'frozen-submission' }]);
  await f.grant('w1', 'review');
  const reviewerToken = secret();
  const review = await f.ok('claim', { actorId: 'w1', workerToken: f.workers.w1,
    taskId: 'review', taskRevision: 2, claimToken: reviewerToken });
  await f.ok('submit', { actorId: 'w1', workerToken: f.workers.w1, taskId: 'review',
    taskRevision: review.result.task.taskRevision, assignmentId: review.result.assignment.id,
    claimToken: reviewerToken, writesStopped: true, processStopped: true,
    inputRevision: 'opaque-review-input', evidenceRefs: ['fixture/tests#review'] });
  const submittedReview = (await f.ok('show', { taskId: 'review' })).result.task;
  await f.ok('accept', { taskId: 'review', taskRevision: submittedReview.taskRevision,
    gatesSatisfied: true, evidenceRefs: ['fixture/accepted#review'] });
  await writeFile(join(f.project, 'WORK.md'), '# Materially changed current contract\n');
  const oldReceipt = await f.raw('claim', claimInput);
  assert.equal(oldReceipt.code, 2, 'Changed actual source must deny an identical old claim receipt');
  await f.task('consumer', 'src/consumer.mjs', [{ taskId: 'review', gate: 'accepted-result' }]);
  await f.grant('w1', 'consumer');
  const consumeOld = await f.claim('w1', 'consumer');
  assert.equal(consumeOld.code, 2, 'Accepted lineage must recheck actual pinned ancestor source');
  writer = (await f.ok('show', { taskId: 'writer' })).result.task;
  const reconciled = await f.ok('reconcile', { taskId: 'writer', taskRevision: writer.taskRevision,
    expectedInputRevision: writer.inputRevision, decision: 'confirm', reason: 'Caller cannot forge proof',
    sourceObservation: { available: true, revision: pinned.expectedRevision,
      evidenceRefs: ['fixture/forged#caller-only'] } });
  assert.equal(reconciled.result.reconciled, false);
  assert.equal(reconciled.result.blocked, true);
  const snapshot = (await f.ok('inspect')).result;
  assert.equal(snapshot.tasks.find(item => item.id === 'writer').inputValid, false);
  assert.equal(snapshot.tasks.find(item => item.id === 'review').resultValid, false);
  assert.equal(snapshot.tasks.find(item => item.id === 'review').state, 'closed');
  assert.ok(snapshot.assignments.some(item => item.id === assignmentId && item.active));
  assert.ok(snapshot.reservations.some(item => item.assignmentId === assignmentId && item.active));
  assert.ok(snapshot.submissions.filter(item => item.taskId === 'writer')
    .every(item => item.freezeValid === false));
});


// Opt-in OpenSpec identity and checkbox-normalized semantics, including missing/duplicate native IDs.
test('SourceB.openSpecIdentityAndSemanticProgress', async t => {
  const f = await fixture(t);
  const change = join(f.project, 'openspec', 'changes', 'sample');
  await mkdir(change, { recursive: true });
  const tasks = join(change, 'tasks.md');
  const original = '- [ ] 1.1 Preserve semantic task wording\n';
  await writeFile(tasks, original);
  const ref = { schemaVersion: 1, kind: 'openspec', changeId: 'sample', nativeTaskId: '1.1' };
  await f.ok('add', { task: { id: 'writer', title: 'Scoped native task', outcome: 'Bounded output',
    sourceRefs: [ref], acceptanceRefs: ['opaque:accept'], eligibleRoles: ['backend'],
    scope: { read: [], write: [] }, resources: [], dependencies: [] } });
  assert.equal((await check(f)).status, 'unavailable', 'Directory presence is not opt-in');
  await writeFile(join(f.project, 'openspec', 'team-integration.json'), JSON.stringify({
    schemaVersion: 1, enabled: true, openSpecVersion: '1.13.2' }));
  await writeFile(join(f.project, 'openspec', 'config.yaml'), 'schema: spec-driven\n');
  const candidate = await check(f);
  assert.equal(candidate.status, 'unbaselined');
  const pinned = { ...ref, expectedRevision: candidate.checkedRefs[0].actualRevision };
  const writer = (await f.ok('show', { taskId: 'writer' })).result.task;
  await f.ok('amend', { taskId: 'writer', taskRevision: writer.taskRevision,
    expectedInputRevision: writer.inputRevision, reason: 'Pin semantic snapshot',
    patch: { sourceRefs: [pinned] } });
  const before = (await f.ok('inspect')).result;
  await writeFile(tasks, original.replace('[ ]', '[x]'));
  const progress = await check(f);
  assert.equal(progress.status, 'unchanged');
  assert.equal(progress.checkedRefs[0].actualRevision, pinned.expectedRevision);
  assert.deepEqual((await f.ok('inspect')).result, before, 'Checkbox read changes no queue counters');
  await writeFile(tasks, '- [ ] 1.1 Materially changed wording\n');
  assert.equal((await check(f)).status, 'changed');
  await writeFile(tasks, '- [ ] 2.1 A different native task\n');
  assert.equal((await check(f)).status, 'missing-task');
  await writeFile(tasks, original + original);
  assert.equal((await check(f)).status, 'ambiguous');
});

// Work reads fail closed on size/path bounds; opaque references/new clone never create execution facts.
test('SourceB.boundedPathsOpaqueAndMissingQueue', async t => {
  const f = await fixture(t);
  await addTyped(f);
  await writeFile(join(f.project, 'WORK.md'), Buffer.alloc(1048577, 65));
  const tooLarge = await check(f);
  assert.equal(tooLarge.status, 'unavailable');
  assert.equal(tooLarge.checkedRefs[0].reasonCode, 'SOURCE_LIMIT');
  let writer = (await f.ok('show', { taskId: 'writer' })).result.task;
  await f.ok('amend', { taskId: 'writer', taskRevision: writer.taskRevision,
    expectedInputRevision: writer.inputRevision, reason: 'Observe rejected root escape',
    patch: { sourceRefs: [{ schemaVersion: 1, kind: 'work', path: '../outside.md',
      nativeTaskId: 'declared-only' }] } });
  const unsafe = await check(f);
  assert.equal(unsafe.status, 'unavailable');
  assert.equal(unsafe.checkedRefs[0].reasonCode, 'UNSAFE_PATH');
  writer = (await f.ok('show', { taskId: 'writer' })).result.task;
  await f.ok('amend', { taskId: 'writer', taskRevision: writer.taskRevision,
    expectedInputRevision: writer.inputRevision, reason: 'Keep opaque reference unverified',
    patch: { sourceRefs: ['nonexistent:opaque-reference'] } });
  assert.equal((await check(f)).status, 'declared-unverified');
  const before = (await f.ok('inspect')).result;
  const missingBoard = join(f.project, 'missing-queue');
  const response = await invoke(f.project, missingBoard, 'source-check', { actorId: 'lead',
    leadToken: f.leadToken, taskId: 'writer' });
  assert.equal(response.reply.ok, false);
  await assert.rejects(access(missingBoard), { code: 'ENOENT' });
  assert.deepEqual((await f.ok('inspect')).result, before);
});



// Linked SourceB repair: observe actual returned IO, not just a final unavailable status label.
for (const [name, sizes] of [
  ['totalReadBudget', Array(8).fill(1048576)],
  ['partialRemainingBudget', [1048576, 1048576, 1048576, 524288, 1048576, 1048576]],
]) {
  test(`SourceB.${name}`, async t => {
    const f = await fixture(t);
    const refs = [];
    for (let index = 0; index < sizes.length; index++) {
      const path = `distinct-source-${index}.md`;
      await writeFile(join(f.project, path), Buffer.alloc(sizes[index], 65));
      refs.push({ schemaVersion: 1, kind: 'work', path, nativeTaskId: `declared-${index}` });
    }
    const context = { board: { projectRoot: f.project,
      workspaces: [initializeMainWorkspace(f.project)] },
      dependencies: { list: () => [] }, tasks: { get: () => undefined } };
    const originalRead = fs.readSync;
    let returnedBytes = 0;
    let readsAfterCap = 0;
    fs.readSync = function (...args) {
      const alreadyAtCap = returnedBytes >= 4194304;
      const count = originalRead.apply(this, args);
      returnedBytes += count;
      if (alreadyAtCap && count > 0) readsAfterCap++;
      return count;
    };
    let observed;
    try { observed = observeSources(context, { id: 'bounded-operation', sourceRefs: refs,
      workspaceId: 'main', scope: { read: [], write: [] } }); }
    finally { fs.readSync = originalRead; }
    assert.ok(returnedBytes <= 4194304,
      `Whole operation returned ${returnedBytes} bytes, exceeding its 4194304 byte read budget`);
    assert.equal(readsAfterCap, 0, 'Exhausted operation must perform no additional data reads');
    assert.equal(observed.status, 'unavailable');
    for (const ref of observed.checkedRefs.slice(4)) {
      assert.equal(ref.status, 'unavailable');
      assert.equal(ref.reasonCode, 'SOURCE_LIMIT');
    }
  });
}
