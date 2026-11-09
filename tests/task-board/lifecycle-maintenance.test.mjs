// B3/B4 real-storage retention contracts. Controlled UOW setup is not business/CLI acceptance.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, mkdtemp, rm } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { initializeBoard, openBoard } from '../../packages/task-board/src/storage/index.mjs';
import { createLegacyBoard } from './fixtures/legacy-board.mjs';

const leadHash = '43'.repeat(32);

// Hash the complete semantic options with only the top-level digest omitted.
function digest(options) {
  const canonical = value => Array.isArray(value) ? value.map(canonical)
    : value && typeof value === 'object'
      ? Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])]))
      : value;
  const { requestHash, ...semantic } = options;
  return createHash('sha256').update(JSON.stringify(canonical(semantic))).digest('hex');
}

// Every fixture owns its directory and connection; assertions never use a mock storage facade.
async function fixture(t, methods) {
  const parent = resolve('_work/task-board/test-fixtures');
  await mkdir(parent, { recursive: true });
  const projectRoot = await mkdtemp(join(parent, 'lifecycle-maintenance-'));
  let board;
  t.after(async () => {
    board?.close();
    await rm(projectRoot, { recursive: true, force: true });
  });
  board = initializeBoard({ projectRoot, boardPath: join(projectRoot, 'board'),
    leadId: 'lead', leadTokenHash: leadHash });
  for (const method of methods) {
    assert.equal(typeof board[method], 'function', `Missing B3/B4 storage capability: ${method}`);
  }
  let sequence = 0;
  let seedOptions;
  function options(extra = {}) {
    const metadata = board.metadata();
    const value = { request: { operationId: `lifecycle-${++sequence}`, actorId: 'lead',
      generation: metadata.generation, expectedBoardRevision: metadata.boardRevision },
    leadId: 'lead', leadTokenHash: leadHash, ...extra };
    return { ...value, requestHash: digest(value) };
  }
  function arrange(records, setup = () => {}) {
    seedOptions = { ...options(), operation: 'controlled-retention-fixture' };
    return board.transactOperation(seedOptions, tx => {
      for (const task of records) tx.tasks.put(task);
      setup(tx);
      tx.audit('fixture-history', { taskId: records[0].id, evidenceRefs: ['fixture/evidence#kept'] });
      return { fixture: true };
    });
  }
  function classify(taskId) {
    return { taskId, decision: 'logical-archive-safe',
      evidenceRefs: ['fixture/classification#visibility-only'],
      observedBoardRevision: board.metadata().boardRevision };
  }
  return { board, projectRoot, options, arrange, classify,
    replaySeed: () => board.transactOperation(seedOptions, () => {
      assert.fail('An existing receipt must prevent fixture mutation from executing again');
    }) };
}

// A closed task has opaque source evidence, requiring explicit bounded classification.
function closed(id, extra = {}) {
  return { id, state: 'closed', taskRevision: 7, inputRevision: 4, executionRevision: 2,
    resultRevision: 3, freezeRevision: 5, inputValid: true, resultValid: true,
    freezeValid: true, repairAttempts: 0, sourceRefs: ['opaque:fixture-source'],
    acceptanceRefs: ['opaque:fixture-acceptance'], ...extra };
}

// Compare business fields while allowing only the contracted visibility/revision mutation.
function business(task) {
  const { archived, taskRevision, ...facts } = task;
  return facts;
}

// Scenario: explicitly classified closed task is archived then restored.
// Expected: visibility/revision alone change; historical receipt replay and audit survive.
test('lifecycle.archivePreservesFacts', async t => {
  const f = await fixture(t, ['previewArchive', 'archive']);
  const seeded = f.arrange([closed('eligible')]);
  const before = f.board.snapshot();
  const history = f.board.history({ taskId: 'eligible' }).items;
  for (const action of ['archive', 'unarchive']) {
    const request = { taskIds: ['eligible'], action,
      classificationRefs: [f.classify('eligible')] };
    const preview = f.board.previewArchive(request);
    assert.deepEqual(preview.eligibleTaskIds, ['eligible']);
    assert.deepEqual(preview.protected, []);
    const { previewHash, ...unsignedPlan } = preview;
    assert.equal(previewHash, digest(unsignedPlan));
    const result = await f.board.archive(f.options({ ...request,
      previewHash: preview.previewHash, approvalRef: 'fixture/approval#visibility' }));
    assert.equal(result.ok, true);
    const current = f.board.snapshot().tasks.find(task => task.id === 'eligible');
    assert.equal(current.archived, action === 'archive');
    assert.equal(current.taskRevision, action === 'archive' ? 8 : 9);
    assert.deepEqual(business(current), business(before.tasks[0]));
  }
  assert.deepEqual(f.board.history({ taskId: 'eligible' }).items.slice(0, history.length), history);
  assert.deepEqual(f.board.snapshot().dependencies, before.dependencies);
  assert.deepEqual(f.replaySeed(), seeded);
});

// Scenario: current bounded classifications accompany known hard references or gates.
// Expected: each named hard reason survives classification and execution rejects atomically.
test('lifecycle.hardProtectionCannotBeClassifiedAway', async t => {
  const cases = [
    { id: 'manual', fields: { manualPending: true }, reason: 'MANUAL_GATE' },
    { id: 'cleanup', fields: { cleanupPending: true }, reason: 'CLEANUP_PENDING' },
    { id: 'dependency', reason: 'DEPENDENCY_REFERENCE', setup(tx) {
      tx.dependencies.put({ id: 'edge', taskId: 'other', dependsOnTaskId: 'target',
        gate: 'accepted-result' });
    } },
    { id: 'evidence', reason: 'EVIDENCE_REFERENCE', setup(tx) {
      tx.tasks.put(closed('other', { intendedInputBindings: [{ taskId: 'target' }] }));
    } },
    { id: 'unknown-dispatch', reason: 'UNKNOWN_DISPATCH', setup(tx) {
      tx.board.dispatchAttempts = [{ taskId: 'target', status: 'unknown' }];
    } },
    { id: 'pending-question', reason: 'PENDING_QUESTION', setup(tx) {
      tx.workers.put({ id: 'worker' });
      tx.assignments.put({ id: 'old-assignment', taskId: 'target', workerId: 'worker', active: false });
      tx.questions.put({ id: 'question', taskId: 'target', assignmentId: 'old-assignment' });
    } },
  ];
  for (const scenario of cases) {
    const f = await fixture(t, ['previewArchive', 'archive']);
    f.arrange([closed('target', scenario.fields), closed('other')], scenario.setup);
    const input = { taskIds: ['target'], action: 'archive',
      classificationRefs: [f.classify('target')] };
    const before = f.board.snapshot();
    const preview = f.board.previewArchive(input);
    assert.ok(preview.protected[0].reasons.includes(scenario.reason), scenario.id);
    assert.deepEqual(preview.eligibleTaskIds, []);
    await assert.rejects(async () => f.board.archive(f.options({ ...input,
      previewHash: preview.previewHash, approvalRef: 'fixture/approval#hard-protection' })),
    error => error.code === 'PROTECTED');
    assert.deepEqual(f.board.snapshot(), before, scenario.id);
  }
});

// Scenario: a plan becomes stale; an old receipt is replayed with changed semantics or bad auth.
// Expected: no mutation on denial; identical currently authorized retry returns its committed result.
test('lifecycle.stalePlanAndFullSemanticReplay', async t => {
  const f = await fixture(t, ['previewArchive', 'archive']);
  f.arrange([closed('target')]);
  const input = { taskIds: ['target'], action: 'archive',
    classificationRefs: [f.classify('target')] };
  const preview = f.board.previewArchive(input);
  const stale = f.options({ ...input, previewHash: preview.previewHash, approvalRef: 'fixture/a#one' });
  f.arrange([closed('unrelated', { state: 'running' })]);
  let before = f.board.snapshot();
  await assert.rejects(async () => f.board.archive(stale), error => error.code === 'CONFLICT');
  assert.deepEqual(f.board.snapshot(), before);
  input.classificationRefs = [f.classify('target')];
  const fresh = f.board.previewArchive(input);
  const options = f.options({ ...input, previewHash: fresh.previewHash,
    approvalRef: 'fixture/a#one' });
  const committed = await f.board.archive(options);
  assert.deepEqual(await f.board.archive(options), committed);
  before = f.board.snapshot();
  for (const patch of [{ approvalRef: 'fixture/a#changed' }, { previewHash: '00'.repeat(32) }]) {
    const changed = { ...options, ...patch };
    changed.requestHash = digest(changed);
    await assert.rejects(async () => f.board.archive(changed),
      error => error.code === 'IDEMPOTENCY_MISMATCH');
    assert.deepEqual(f.board.snapshot(), before);
  }
});

// Scenario: current maintenance is active, or a genuine schema2 database is opened normally.
// Expected: lightweight mutations still respect maintenance; old schema cannot obtain write APIs.
test('lifecycle.schemaAndMaintenanceWriteGates', async t => {
  const f = await fixture(t, ['previewArchive', 'archive']);
  f.arrange([closed('target')], tx => { tx.board.maintenance = { active: true }; });
  const input = { taskIds: ['target'], action: 'archive',
    classificationRefs: [f.classify('target')] };
  const preview = f.board.previewArchive(input);
  const before = f.board.snapshot();
  await assert.rejects(async () => f.board.archive(f.options({ ...input,
    previewHash: preview.previewHash, approvalRef: 'fixture/a#maintenance' })),
  error => error.code === 'MAINTENANCE_REQUIRED');
  assert.deepEqual(f.board.snapshot(), before);
  const boardPath = join(f.projectRoot, 'legacy');
  await createLegacyBoard(f.projectRoot, boardPath);
  assert.throws(() => openBoard({ projectRoot: f.projectRoot, boardPath }),
    error => error.code === 'UNSUPPORTED_SCHEMA');
});

// Scenario: unknown references and running/hold/repair facts cannot be bypassed by a plan.
// Expected: previews protect targets; stale plan and bad credentials preserve all durable facts.
test('lifecycle.protectedAndDenied', async t => {
  const f = await fixture(t, ['previewArchive', 'archive', 'previewPrune']);
  f.arrange([closed('unknown'), closed('running', { state: 'running' }),
    closed('hold', { questionHold: true }), closed('repair', { repairAttempts: 1 })]);
  const before = f.board.snapshot();
  const unknown = f.board.previewArchive({ taskIds: ['unknown'], action: 'archive' });
  assert.equal(unknown.protected[0].taskId, 'unknown');
  assert.ok(unknown.protected[0].reasons.includes('UNKNOWN_REFERENCE'));
  for (const taskId of ['running', 'hold', 'repair']) {
    const preview = f.board.previewArchive({ taskIds: [taskId], action: 'archive',
      classificationRefs: [f.classify(taskId)] });
    assert.equal(preview.eligibleTaskIds.length, 0);
    assert.equal(preview.protected[0].taskId, taskId);
  }
  assert.deepEqual(f.board.snapshot(), before, 'Preview must be read-only');
  const input = { taskIds: ['unknown'], action: 'archive',
    classificationRefs: [f.classify('unknown')] };
  const preview = f.board.previewArchive(input);
  for (const patch of [{ leadTokenHash: '00'.repeat(32) }, { previewHash: '00'.repeat(32) }]) {
    const options = f.options({ ...input, previewHash: preview.previewHash,
      approvalRef: 'fixture/approval#visibility', ...patch });
    await assert.rejects(async () => f.board.archive(options),
      error => error.code === (patch.leadTokenHash ? 'UNAUTHORIZED' : 'CONFLICT'));
    assert.deepEqual(f.board.snapshot(), before);
  }
  const physical = f.board.previewPrune({ target: 'tasks', taskIds: ['unknown'] });
  assert.equal(physical.supported, false);
  assert.ok(physical.protected[0].reasons.includes('TASK_PHYSICAL_PRUNE_UNSUPPORTED'));
});

// Scenario: an explicitly approved replay-log prefix is pruned while business history remains.
// Expected: exact event IDs vanish, floor advances, old cursors reset and old receipts still replay.
test('lifecycle.pruneRetainsHistory', async t => {
  const f = await fixture(t, ['previewPrune', 'applyPrune']);
  const seeded = f.arrange([closed('history')]);
  const before = f.board.snapshot();
  const history = f.board.history({ taskId: 'history' }).items;
  const input = { target: 'change-events', throughEventSeq: before.eventSeq,
    retentionApprovalRef: 'fixture/retention#exact-window' };
  const preview = f.board.previewPrune(input);
  assert.deepEqual(preview.eventSeqs, [before.eventSeq]);
  assert.equal(preview.newReplayFloor, before.eventSeq);
  const { previewHash, ...unsignedPlan } = preview;
  assert.equal(previewHash, digest(unsignedPlan));
  assert.deepEqual(f.board.snapshot(), before);
  const options = f.options({ ...input, previewHash: preview.previewHash,
    approvalRef: 'fixture/approval#prefix' });
  const pruned = await f.board.applyPrune(options);
  assert.deepEqual(pruned.result.deletedEventSeqs, preview.eventSeqs);
  assert.equal(f.board.metadata().replayFloor, before.eventSeq);
  assert.deepEqual(f.board.snapshot().tasks, before.tasks);
  assert.deepEqual(f.board.history({ taskId: 'history' }).items.slice(0, history.length), history);
  const cursor = { generation: before.board.generation, eventSeq: 0 };
  assert.equal(f.board.eventsAfter(cursor).reset, true);
  const replay = f.board.eventsAfter({ ...cursor, eventSeq: before.eventSeq });
  assert.equal(replay.reset, false);
  assert.deepEqual(replay.events.map(event => event.eventSeq), [pruned.eventSeq]);
  assert.deepEqual(await f.board.applyPrune(options), pruned);
  assert.deepEqual(f.replaySeed(), seeded);
});
