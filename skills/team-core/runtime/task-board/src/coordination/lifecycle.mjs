/** Lead-controlled contract changes and ownership transitions; all calls run inside storage UOW. */
import { executorBinding, roleEligible, validateExecutionContract } from '../domain/executor.mjs';
import { normalizeWorkspaceScope, scopeResourceKey } from '../domain/workspace-scope.mjs';
import { randomUUID } from 'node:crypto';
import { compositeId } from '../domain/identity.mjs';
import { replaceDependencies, invalidateOutputs, dependenciesReady, consumeDependencies }
  from '../domain/graph.mjs';
import { currentExecutionEligibility, executionBinding, inputBindings }
  from '../domain/execution.mjs';
import { validateSourceRefs, observeSources } from '../sources/adapter.mjs';

export const lifecycleOperations = new Set([
  'amend', 'return', 'reopen', 'cancel', 'transfer', 'reconcile', 'recover',
]);

/** Invalidate credentials without claiming that the old writer stopped or releasing its holds. */
function revokeAssignments(tx, task) {
  for (const assignment of tx.assignments.list({ taskId: task.id, active: true })) {
    tx.assignments.put({ ...assignment, active: false });
  }
  task.cleanupPending = tx.reservations.list({ taskId: task.id, active: true }).length > 0;
}

/** Apply a reviewed patch; resource changes withdraw old approval and retain existing allocations. */
function amend(tx, task, input, helpers) {
  const { requireValue, normalizeScope } = helpers;
  requireValue(task.inputRevision === input.expectedInputRevision, 'CONFLICT', 'Input revision changed.');
  const patch = input.patch;
  const allowed = ['title', 'priority', 'outcome', 'sourceRefs', 'acceptanceRefs',
    'eligibleRoles', 'scope', 'resources', 'dependencies', 'requiredSkills', 'responsibilities',
    'allowLeadInline', 'workspaceId', 'acceptancePolicy', 'verification'];
  requireValue(patch && typeof patch === 'object' && !Array.isArray(patch) &&
    Object.keys(patch).every(key => allowed.includes(key)), 'INVALID_INPUT', 'Invalid amendment patch.');
  const contractChanged = Object.keys(patch).some(key => !['title', 'priority'].includes(key));
  if (patch.dependencies !== undefined) replaceDependencies(tx, task.id, patch.dependencies);
  if (patch.scope !== undefined || patch.resources !== undefined || patch.workspaceId !== undefined) {
    if (patch.workspaceId !== undefined) task.workspaceId = patch.workspaceId;
    const scope = patch.scope ?? task.scope;
    requireValue(Array.isArray(scope?.read) && Array.isArray(scope?.write),
      'INVALID_INPUT', 'Scope requires read and write arrays.');
    task.scope = {
      read: scope.read.map(value => normalizeWorkspaceScope(tx, task, value, normalizeScope)),
      write: scope.write.map(value => normalizeWorkspaceScope(tx, task, value, normalizeScope)),
    };
    const named = patch.resources ?? task.resources ?? [];
    requireValue(Array.isArray(named) && named.every(item => item.kind === 'resource' &&
      typeof item.key === 'string' && item.key && ['shared', 'exclusive'].includes(item.mode)),
      'INVALID_INPUT', 'Invalid named resources.');
    for (const resource of tx.taskResources.list({ taskId: task.id })) tx.taskResources.remove(resource.id);
    const resources = [
      ...task.scope.read.map(value => ({
        kind: 'path', key: scopeResourceKey(tx, task, value), mode: 'shared',
      })),
      ...task.scope.write.map(value => ({
        kind: 'path', key: scopeResourceKey(tx, task, value), mode: 'exclusive',
      })),
      ...named,
    ];
    for (const resource of resources) {
      tx.taskResources.put({ ...resource, id: randomUUID(), taskId: task.id });
    }
    task.resources = named;
  }
  for (const key of ['title', 'priority', 'outcome', 'sourceRefs', 'acceptanceRefs', 'eligibleRoles',
    'requiredSkills', 'responsibilities', 'allowLeadInline',
    'workspaceId', 'acceptancePolicy', 'verification']) {
    if (patch[key] !== undefined) task[key] = patch[key];
  }
  validateSourceRefs(task.sourceRefs);
  validateExecutionContract(task, tx);
  requireValue(typeof task.title === 'string' && task.title && typeof task.outcome === 'string' &&
    task.outcome && Array.isArray(task.eligibleRoles) && task.eligibleRoles.length &&
    Array.isArray(task.sourceRefs) && task.sourceRefs.length &&
    Array.isArray(task.acceptanceRefs) && task.acceptanceRefs.length,
    'INVALID_INPUT', 'Amendment must preserve the required work contract.');
  if (!contractChanged) return;
  invalidateOutputs(tx, task);
  task.inputRevision = (task.inputRevision ?? 0) + 1;
  task.executionRevision = Number.isSafeInteger(task.executionRevision) ?
    task.executionRevision + 1 : null;
  task.approvalRevision = 0;
  for (const grant of tx.grants.list({ taskId: task.id })) tx.grants.put({ ...grant, revoked: true });
  const assigned = tx.assignments.list({ taskId: task.id, active: true }).length > 0;
  task.needsReconcile = assigned;
  task.inputValid = !assigned && dependenciesReady(tx, task);
  if (assigned) task.state = 'blocked';
  else if (!['closed', 'canceled'].includes(task.state)) task.state = 'planned';
}

/** Account every restored allocation before clearing the board-wide recovery gate. */
function recover(tx, input, helpers) {
  const { requireValue } = helpers;
  requireValue(tx.board.recoveryRequired === true &&
    input.expectedBoardRevision === tx.board.boardRevision, 'CONFLICT', 'Recovery revision changed.');
  requireValue(input.externalEffectsReviewed === true && Array.isArray(input.decisions),
    'INVALID_INPUT', 'Recovery requires explicit external-effect review and allocation decisions.');
  const holders = new Set(tx.reservations.list({ active: true }).map(item => item.assignmentId));
  const allocations = tx.assignments.list().filter(item => item.active || holders.has(item.id));
  requireValue(input.decisions.length === allocations.length &&
    new Set(input.decisions.map(item => item.assignmentId)).size === allocations.length,
    'INVALID_INPUT', 'Every allocation must have exactly one recovery decision.');
  const tasks = [];
  for (const assignment of allocations) {
    const decision = input.decisions.find(item => item.assignmentId === assignment.id);
    const task = tx.tasks.get(assignment.taskId);
    requireValue(decision?.taskId === task.id && decision.taskRevision === task.taskRevision &&
      Array.isArray(decision.evidenceRefs) && decision.evidenceRefs.length &&
      ['retain-blocked', 'stopped-release'].includes(decision.disposition),
      'INVALID_INPUT', 'Recovery decision does not match the current allocation.');
    if (decision.disposition === 'stopped-release') {
      requireValue(decision.writesStopped === true && decision.processStopped === true,
        'RECOVERY_REQUIRED', 'Release requires stopped writers and processes.');
      tx.assignments.put({ ...assignment, active: false });
      for (const reservation of tx.reservations.list({ assignmentId: assignment.id, active: true })) {
        tx.reservations.put({ ...reservation, active: false });
      }
    }
    task.state = ['closed', 'canceled'].includes(task.state) ? task.state : 'blocked';
    task.cleanupPending = tx.reservations.list({ taskId: task.id, active: true }).length > 0;
    task.inputValid = false;
    task.needsReconcile = true;
    task.executionRevision = Number.isSafeInteger(task.executionRevision) ?
      task.executionRevision + 1 : null;
    task.taskRevision++;
    tx.tasks.put(task);
    tasks.push(task);
    tx.audit('recovery-allocation', { assignmentId: assignment.id, decision });
  }
  // Allocation accounting does not certify the source contracts of unassigned restored work.
  const accounted = new Set(tasks.map(task => task.id));
  for (const task of tx.tasks.list()) {
    if (accounted.has(task.id)) continue;
    task.inputValid = false;
    task.needsReconcile = true;
    task.executionRevision = Number.isSafeInteger(task.executionRevision) ?
      task.executionRevision + 1 : null;
    task.taskRevision++;
    tx.tasks.put(task);
    tasks.push(task);
  }
  tx.board.recoveryRequired = false;
  return { recovered: true, reconciliationRequired: false, tasks };
}

/** Execute a Lead lifecycle operation using shared authority, paths, tokens and eligibility helpers. */
export function lifecycle(tx, operation, input, helpers) {
  const { requireValue, taskAtRevision, tokenHash, resourcesAvailable, redact } = helpers;
  if (operation === 'recover') return recover(tx, input, helpers);
  const task = taskAtRevision(tx, input);
  requireValue(typeof input.reason === 'string' && input.reason.trim(),
    'INVALID_INPUT', 'A lifecycle reason is required.');
  let assignment;
  if (operation === 'amend') amend(tx, task, input, helpers);
  if (operation === 'return') {
    requireValue(!task.questionHold, 'QUESTION_PENDING',
      'Resolve the approval hold before returning to execution.');
    requireValue(task.state === 'submitted', 'CONFLICT', 'Return requires a submitted task.');
    const owner = tx.assignments.list({ taskId: task.id, active: true })[0];
    const held = tx.reservations.list({ taskId: task.id, active: true });
    requireValue(owner && tx.taskResources.list({ taskId: task.id }).every(resource =>
      held.some(item => item.kind === resource.kind && item.key === resource.key &&
        item.mode === resource.mode && item.assignmentId === owner.id)),
      'RESOURCE_REACQUIRE_REQUIRED', 'The old owner must regain a valid assignment and reservations.');
    requireValue(task.inputValid === true && !task.needsReconcile && dependenciesReady(tx, task),
      'DEPENDENCY_BLOCKED', 'Applicable inputs must be reconciled before returning to execution.');
    const worker = tx.workers.get(owner.workerId);
    currentExecutionEligibility(tx, task, { worker,
      grant: tx.grants.get(compositeId(task.id, owner.workerId)), record: owner,
      requireGrant: true, requireActive: true });
    invalidateOutputs(tx, task);
    task.state = 'running';
  }
  if (operation === 'reopen' || operation === 'cancel') {
    requireValue(operation === 'reopen' ? task.state === 'closed' :
      !['closed', 'canceled'].includes(task.state), 'CONFLICT', 'Invalid lifecycle transition.');
    invalidateOutputs(tx, task);
    revokeAssignments(tx, task);
    task.state = operation === 'reopen' ?
      (task.approvalRevision > 0 ? 'open' : 'planned') : 'canceled';
    if (operation === 'reopen') task.archived = false;
  }
  if (operation === 'transfer') {
    requireValue(!task.questionHold, 'QUESTION_PENDING', 'Resolve the approval hold before transfer.');
    requireValue(input.writesStopped === true && input.processStopped === true,
      'RECOVERY_REQUIRED', 'Transfer requires stopped writers and processes.');
    const worker = tx.workers.get(input.newWorkerId);
    const grant = tx.grants.get(compositeId(task.id, input.newWorkerId));
    currentExecutionEligibility(tx, task, { worker, grant, requireGrant: true });
    requireValue(worker && ['direct', 'lead-recorded', 'lead-inline'].includes(worker.mode) &&
      worker.capabilities.includes('write') &&
      roleEligible(task, worker) && grant && !grant.revoked &&
      grant.taskId === task.id && grant.workerId === worker.id &&
      grant.approvalRevision === task.approvalRevision &&
      input.expectedApprovalRevision === task.approvalRevision,
      'UNAUTHORIZED', 'The new owner requires current explicit authorization.');
    requireValue(!['closed', 'canceled', 'planned'].includes(task.state) && task.inputValid &&
      !task.needsReconcile && dependenciesReady(tx, task) && resourcesAvailable(tx, task) &&
      input.handoffRefs?.length, 'DEPENDENCY_BLOCKED', 'Handoff inputs and resources must be applicable.');
    revokeAssignments(tx, task);
    assignment = { id: randomUUID(), taskId: task.id, workerId: worker.id, active: true,
      tokenHash: tokenHash(input.newClaimToken), generation: tx.board.generation,
      ...executorBinding(worker, { actorId: input.actorId }),
      actualExecutor: executorBinding(worker, { actorId: input.actorId }), ...executionBinding(tx, task) };
    tx.assignments.put(assignment);
    for (const old of tx.reservations.list({ taskId: task.id, active: true })) {
      tx.reservations.put({ ...old, active: false });
    }
    for (const resource of tx.taskResources.list({ taskId: task.id })) {
      tx.reservations.put({ ...resource, id: randomUUID(), assignmentId: assignment.id, active: true });
    }
    consumeDependencies(tx, task);
    if (task.state === 'submitted') invalidateOutputs(tx, task);
    task.state = 'running';
    task.cleanupPending = false;
  }
  if (operation === 'reconcile') {
    requireValue(task.inputRevision === input.expectedInputRevision, 'CONFLICT', 'Input revision changed.');
    requireValue(['confirm', 'amend'].includes(input.decision), 'INVALID_INPUT', 'Invalid reconciliation decision.');
    let typed = task.sourceRefs.some(ref => typeof ref !== 'string');
    // A requested amendment can introduce typed mappings. Observe the amended contract, never a
    // caller-supplied availability/revision assertion, before clearing any reconciliation hold.
    if (input.decision === 'amend') amend(tx, task, input, helpers);
    typed ||= task.sourceRefs.some(ref => typeof ref !== 'string');
    const observation = typed ? observeSources(tx, task) : input.sourceObservation;
    if (typed && !['unchanged', 'declared-unverified'].includes(observation.status)) {
      // This is a durable negative observation. Throwing here would roll back output invalidation
      // and leave downstream evidence usable, so return an explicit successful blocked receipt.
      invalidateOutputs(tx, task);
      task.inputRevision++;
      task.executionRevision = Number.isSafeInteger(task.executionRevision) ?
        task.executionRevision + 1 : null;
      task.inputValid = false;
      task.needsReconcile = true;
      task.sourceObservation = observation;
      if (task.state === 'running') task.state = 'blocked';
      task.taskRevision++;
      tx.tasks.put(task);
      tx.audit('reconcile', { taskId: task.id, actorId: input.actorId, reason: input.reason,
        sourceObservation: observation, blocked: true });
      return { task, reconciled: false, blocked: true, observation };
    }
    if (!typed) {
      requireValue(observation?.available === true && typeof observation.revision === 'string' &&
        observation.revision.trim() && Array.isArray(observation.evidenceRefs) &&
        observation.evidenceRefs.length, 'SOURCE_UNAVAILABLE', 'Lead source declaration is required.');
    }
    if (input.decision === 'confirm' || typed) {
      requireValue((input.decision === 'amend' || !input.patch) && dependenciesReady(tx, task), 'DEPENDENCY_BLOCKED',
        'Confirmation cannot replace changed contracts or revive obsolete dependencies.');
      if (!Number.isSafeInteger(task.executionRevision) || task.executionRevision < 1) {
        // Unknown legacy execution history is retained as invalid evidence, never adopted as current.
        invalidateOutputs(tx, task);
      }
      task.inputRevision ??= 1;
      task.resultRevision ??= 0;
      task.freezeRevision ??= 0;
      task.executionRevision ??= 1;
      task.inputValid = true;
      task.needsReconcile = false;
      task.sourceObservation = typed ? { ...observation, boundInputRevision: task.inputRevision } : observation;
      // Confirmation records intended inputs; only a fresh allocation may consume this new binding.
      task.intendedInputBindings = inputBindings(tx, task);
      if (!tx.assignments.list({ taskId: task.id, active: true }).length &&
        !['closed', 'canceled'].includes(task.state)) {
        task.state = typed && task.approvalRevision > 0 ? 'open' : 'planned';
      }
    }
  }
  task.taskRevision++;
  tx.tasks.put(task);
  tx.audit(operation, { taskId: task.id, actorId: input.actorId, reason: input.reason,
    inputRevision: task.inputRevision, resultRevision: task.resultRevision,
    freezeRevision: task.freezeRevision, evidenceRefs: input.evidenceRefs ?? [],
    handoffRefs: input.handoffRefs ?? [], sourceObservation: operation === 'reconcile' ?
      task.sourceObservation ?? input.sourceObservation ?? null : input.sourceObservation ?? null });
  return assignment ? { task, assignment: redact(assignment) } : { task };
}
