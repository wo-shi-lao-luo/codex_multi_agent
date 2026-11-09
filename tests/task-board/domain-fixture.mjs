// In-memory relational fixture for real domain transitions, isolated from concurrently edited storage.
// Detached reads model repository behavior; no task-specific cases or hidden oracle branches exist.
import { mutate, authorizeReplay, hash } from '../../packages/task-board/src/coordination/service.mjs';
import { randomUUID } from 'node:crypto';
import { after } from 'node:test';
import { mkdirSync, mkdtempSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { initializeMainWorkspace } from '../../packages/task-board/src/storage/workspaces.mjs';

/** Create an isolated domain scenario with no arguments or external services.
 * Returns detached map-backed repositories, real mutation/replay adapters and setup helpers.
 * Callers supply ordinary task/worker fields; helpers never branch on scenario identifiers.
 */
export function domainFixture() {
  const parent = resolve('_work/task-board/test-fixtures');
  mkdirSync(parent, { recursive: true });
  const projectRoot = mkdtempSync(join(parent, 'domain-'));
  after(() => rmSync(projectRoot, { recursive: true, force: true }));
  const leadToken = '21'.repeat(32);
  const workerToken = '32'.repeat(32);
  const tx = { board: { projectRoot, workspaces: [initializeMainWorkspace(projectRoot)], leadId: 'lead',
    leadTokenHash: hash(leadToken), generation: randomUUID(), recoveryRequired: false },
    audit() {}, change() {} };
  for (const name of ['tasks', 'workers', 'grants', 'assignments', 'reservations',
    'taskResources', 'submissions', 'questions', 'answers', 'dependencies']) {
    const records = new Map();
    tx[name] = {
      get: id => records.has(id) ? structuredClone(records.get(id)) : undefined,
      list: (filter = {}) => [...records.values()]
        .filter(value => Object.entries(filter).every(([key, expected]) => value[key] === expected))
        .map(value => structuredClone(value)),
      put: record => { records.set(record.id, structuredClone(record)); return structuredClone(record); },
      remove: id => records.delete(id),
    };
  }
  function request(operation, input = {}) {
    const current = input.taskId ? tx.tasks.get(input.taskId) : undefined;
    return { operationId: randomUUID(), actorId: 'lead', leadToken,
      generation: tx.board.generation, taskRevision: current?.taskRevision,
      expectedInputRevision: current?.inputRevision, reason: 'Fixture contract transition', ...input };
  }
  const run = (operation, input) => mutate(tx, operation, request(operation, input));
  for (const id of ['first-worker', 'second-worker']) {
    run('register', { worker: { id, hostId: randomUUID(), role: 'backend',
      mode: 'direct', capabilities: ['write'], workerToken } });
  }
  function add(id, dependencies = []) {
    run('add', { task: { id, title: id, outcome: 'Bounded outcome',
      sourceRefs: ['opaque:fixture-source'], acceptanceRefs: ['opaque:fixture-acceptance'],
      eligibleRoles: ['backend'], scope: { read: [], write: [] }, resources: [], dependencies } });
    run('approve', { taskId: id });
  }
  function claim(taskId, workerId = 'first-worker') {
    const task = tx.tasks.get(taskId);
    run('grant', { taskId, workerId, approvalRevision: task.approvalRevision });
    const input = request('claim', { taskId, actorId: workerId, workerToken,
      claimToken: '54'.repeat(32) });
    const result = mutate(tx, 'claim', input);
    return { input, result, owner: { taskId, actorId: workerId, workerToken,
      claimToken: input.claimToken, assignmentId: result.assignment.id } };
  }
  function submit(owner) {
    return run('submit', { ...owner, writesStopped: true, processStopped: true,
      inputRevision: 'opaque-source-snapshot', evidenceRefs: ['fixture/tests#pass'] });
  }
  function confirm(taskId) {
    return run('reconcile', { taskId, decision: 'confirm',
      sourceRefs: tx.tasks.get(taskId).sourceRefs,
      sourceObservation: { available: true, revision: 'observed-contract',
        evidenceRefs: ['fixture/observation#applicable'] } });
  }
  return { tx, run, request, add, claim, submit, confirm,
    replay: claim => authorizeReplay(tx, 'claim', claim.input, claim.result),
    authorize: (operation, input, result) => authorizeReplay(tx, operation, input, result) };
}
