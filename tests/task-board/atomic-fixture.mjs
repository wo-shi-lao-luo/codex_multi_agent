// Storage atomicity fixture: related task, owner, reservation and event change together.
// Authorization is separately exercised through the real CLI scenarios, never bypassed there.
export function atomicMutation(tx) {
  tx.workers.put({ id: 'crash-worker', role: 'backend' });
  tx.tasks.put({ id: 'crash-task', taskRevision: 1, state: 'running' });
  tx.assignments.put({ id: 'crash-assignment', taskId: 'crash-task',
    workerId: 'crash-worker', active: true });
  tx.reservations.put({ id: 'crash-reservation', taskId: 'crash-task',
    assignmentId: 'crash-assignment', kind: 'file', key: 'src/crash.mjs',
    mode: 'exclusive', active: true });
  tx.change('fixture-change', { entityId: 'crash-fixture' });
  return { marker: 'once' };
}
