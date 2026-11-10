// Audit regressions exercise real domain eligibility and isolated SQLite transaction rollback.
import test from 'node:test';
import assert from 'node:assert/strict';
import { writeFileSync, mkdtempSync, mkdirSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { domainFixture } from './domain-fixture.mjs';
import { observeSources } from '../../packages/task-board/src/sources/adapter.mjs';
import { initializeBoard } from '../../packages/task-board/src/storage/index.mjs';

for (const boundary of ['claim', 'submit']) {
  // Scenario: A's typed source changes after B freezes evidence consuming A; C consumes B's freeze.
  // Expected: C can execute with current lineage, but claim/submit rejects the changed ancestor.
  test(`Audit.frozenLineage.${boundary}`, () => {
    const f = domainFixture();
    f.add('ancestor');
    const sourcePath = join(f.tx.board.projectRoot, 'WORK.md');
    writeFileSync(sourcePath, '# Original contract\n');
    const ref = { schemaVersion: 1, kind: 'work', path: 'WORK.md', nativeTaskId: 'a' };
    const candidate = observeSources(f.tx, { ...f.tx.tasks.get('ancestor'), sourceRefs: [ref] });
    f.run('amend', { taskId: 'ancestor', patch: { sourceRefs: [
      { ...ref, expectedRevision: candidate.checkedRefs[0].actualRevision },
    ] } });
    f.run('approve', { taskId: 'ancestor' });
    f.confirm('ancestor');
    const ancestor = f.claim('ancestor');
    f.submit(ancestor.owner);
    f.add('intermediate', [{ taskId: 'ancestor', gate: 'frozen-submission' }]);
    const intermediate = f.claim('intermediate');
    f.submit(intermediate.owner);
    f.add('consumer', [{ taskId: 'intermediate', gate: 'frozen-submission' }]);
    const consumer = boundary === 'submit' ? f.claim('consumer') : undefined;
    const stateBefore = f.tx.tasks.get('consumer').state;
    writeFileSync(sourcePath, '# Changed ancestor contract\n');
    assert.throws(() => boundary === 'claim' ? f.claim('consumer') : f.submit(consumer.owner),
      error => error.code === 'DEPENDENCY_BLOCKED');
    assert.equal(f.tx.tasks.get('consumer').state, stateBefore);
    assert.equal(f.tx.submissions.list({ taskId: 'consumer' }).length, 0);
  });
}

for (const repository of ['workers', 'submissions']) {
  // Scenario: a live or historical table reaches 10,000 rows and a multi-write operation adds one.
  // Expected: updates remain legal; overflow rolls back all writes/events/receipt and snapshot works.
  test(`Audit.rowLimit.${repository}`, t => {
    const parent = resolve('_work/task-board/test-fixtures');
    mkdirSync(parent, { recursive: true });
    const projectRoot = mkdtempSync(join(parent, 'audit-cap-'));
    const board = initializeBoard({ projectRoot, boardPath: join(projectRoot, 'board'),
      leadId: 'lead', leadTokenHash: '11'.repeat(32) });
    t.after(() => {
      board.close();
      rmSync(projectRoot, { recursive: true, force: true });
    });
    const generation = board.metadata().generation;
    const options = id => ({ request: { operationId: id, generation, actorId: 'lead' },
      requestHash: '22'.repeat(32), operation: 'fixture-cap' });
    const record = id => repository === 'workers' ? { id } :
      { id, taskId: 'task', assignmentId: 'assignment', taskRevision: 1 };
    board.transactOperation(options('fill'), tx => {
      if (repository === 'submissions') {
        tx.tasks.put({ id: 'task', taskRevision: 1, state: 'submitted' });
        tx.workers.put({ id: 'worker' });
        tx.assignments.put({ id: 'assignment', taskId: 'task', workerId: 'worker', active: false });
      }
      for (let index = 0; index < 10000; index++) tx[repository].put(record(`row-${index}`));
    });
    board.transactOperation(options('update'), tx => {
      tx[repository].put({ ...record('row-0'), marker: 'allowed-update' });
      assert.equal(tx[repository].list({ marker: 'allowed-update' }).length, 1);
    });
    const before = board.snapshot();
    const metadata = board.metadata();
    const overflow = options('overflow');
    assert.throws(() => board.transactOperation(overflow, tx => {
      tx[repository].put({ ...record('row-0'), marker: 'must-rollback' });
      tx.audit('must-rollback', { taskId: 'cap-probe' });
      tx.change('must-rollback', {});
      tx[repository].put(record('overflow-row'));
    }), error => error.code === 'LIMIT_EXCEEDED');
    assert.deepEqual(board.snapshot(), before);
    assert.deepEqual(board.metadata(), metadata);
    assert.deepEqual(board.history({ taskId: 'cap-probe' }).items, []);
    // Reusing the rejected identity must run its callback, proving no success receipt survived.
    let called = false;
    board.transactOperation(overflow, () => { called = true; });
    assert.equal(called, true);
  });
}
