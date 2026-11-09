/** Shared execution eligibility. Authorization and immutable input history are separate from task CAS. */
import { roleEligible, requireWorkerScope } from './executor.mjs';
import { collectTaskWorkspaceIds, validateTaskScopes } from './workspace-scope.mjs';
import { workspaceBindings } from '../storage/workspaces.mjs';
import { BoardError } from './errors.mjs';
import { dependenciesReady } from './graph.mjs';
import { requireCurrentSources } from '../sources/adapter.mjs';

/** Capture exact current upstream contracts and gates in a deterministic, detached history value. */
export function inputBindings(tx, task) {
  return tx.dependencies.list({ taskId: task.id }).map(edge => {
    const upstream = tx.tasks.get(edge.dependsOnTaskId);
    return { taskId: edge.dependsOnTaskId, gate: edge.gate,
      inputRevision: upstream?.inputRevision ?? null,
      workspaceBindings: workspaceBindings(tx, collectTaskWorkspaceIds(upstream, tx)),
      gateRevision: edge.gate === 'accepted-result' ? upstream?.resultRevision ?? null :
        upstream?.freezeRevision ?? null };
  }).sort((a, b) => {
    if (a.taskId !== b.taskId) return a.taskId < b.taskId ? -1 : 1;
    if (a.gate !== b.gate) return a.gate < b.gate ? -1 : 1;
    return 0;
  });
}

/** Stamp new allocations/submissions only; old records must never have these bindings rewritten. */
export function executionBinding(tx, task) {
  return { workspaceBindings: workspaceBindings(tx, collectTaskWorkspaceIds(task, tx)),
    executionRevision: task.executionRevision, boundTaskInputRevision: task.inputRevision,
    approvalRevision: task.approvalRevision, inputBindings: inputBindings(tx, task) };
}

/** Validate current inputs and optional action-specific grant/record constraints.
 * Evidence acceptance intentionally does not require a live assignment or retained resources.
 * Direct/proxy transport permission belongs to the caller, so this guard can serve future adapters.
 */
export function currentExecutionEligibility(tx, task, { worker, grant, record,
  requireGrant = false, requireActive = false, allowApprovalHold = false } = {}) {
  currentAuthorization(task, { worker, grant, requireGrant });
  validateTaskScopes(tx, task);
  const currentWorkspaces = workspaceBindings(tx, collectTaskWorkspaceIds(task, tx));
  if (requireGrant && JSON.stringify(grant.workspaceBindings) !== JSON.stringify(currentWorkspaces)) {
    throw new BoardError('WORKSPACE_MISMATCH', 'Grant workspace binding is obsolete.');
  }
  requireCurrentSources(tx, task, true);
  if (!Number.isSafeInteger(task.executionRevision) || task.executionRevision < 1 ||
    !Number.isSafeInteger(task.inputRevision) || task.inputRevision < 1 ||
    !task.inputValid || task.needsReconcile || task.questionHold && !allowApprovalHold ||
    !dependenciesReady(tx, task)) {
    throw new BoardError('DEPENDENCY_BLOCKED', 'Execution inputs require explicit reconciliation.');
  }
  if (record) {
    const expected = executionBinding(tx, task);
    if (JSON.stringify(record.workspaceBindings) !== JSON.stringify(expected.workspaceBindings)) {
      throw new BoardError('WORKSPACE_MISMATCH', 'Execution workspace identity changed.');
    }
    if ((requireActive && !record.active) || record.taskId !== task.id ||
      record.executionRevision !== expected.executionRevision ||
      record.boundTaskInputRevision !== expected.boundTaskInputRevision ||
      record.approvalRevision !== expected.approvalRevision ||
      !Array.isArray(record.inputBindings) ||
      JSON.stringify(record.inputBindings) !== JSON.stringify(expected.inputBindings)) {
      throw new BoardError('STALE_ASSIGNMENT', 'This execution consumed an obsolete input binding.');
    }
  }
}

/** Preauthorization validates the approved contract and role, independent of future execution readiness. */
export function currentAuthorization(task, { worker, grant, requireGrant = false } = {}) {
  if (!task || !Number.isSafeInteger(task.approvalRevision) || task.approvalRevision <= 0) {
    throw new BoardError('UNAUTHORIZED', 'Current nonzero approval is required.');
  }
  if (worker) requireWorkerScope(task, worker);
  if (requireGrant && (!worker || !grant || grant.revoked || grant.taskId !== task.id ||
    grant.workerId !== worker.id || grant.approvalRevision !== task.approvalRevision ||
    !roleEligible(task, worker))) {
    throw new BoardError('UNAUTHORIZED', 'A current grant for this worker and task is required.');
  }
}
