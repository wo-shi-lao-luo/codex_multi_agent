/** Role-neutral coordination rules. Storage owns SQL; every mutation runs in one short unit of work. */
import { createHash, randomUUID, timingSafeEqual } from 'node:crypto';
import path from 'node:path';
import { BoardError } from '../domain/errors.mjs';
import { compositeId } from '../domain/identity.mjs';
import { dependenciesReady, consumeDependencies, consumableResult } from '../domain/graph.mjs';
import { lifecycle, lifecycleOperations } from './lifecycle.mjs';
import { currentExecutionEligibility, currentAuthorization, executionBinding } from '../domain/execution.mjs';
import { questionOperations, questionMutation, effectivePending, projectQuestion, questionPolicy,
  assertNoBackpressure } from '../questions/service.mjs';
import { blocksExecution } from '../questions/service.mjs';
import { recordDispatch, dispatchUnknown } from './dispatch.mjs';
import { compactQuery, readiness, snapshotContext } from './projection.mjs';
import { validateSourceRefs, requireCurrentSources, observeSources, resetSourceObservation }
  from '../sources/adapter.mjs';
import { executorIdentity, executorBinding, roleEligible, validateExecutionContract,
  requireWorkerScope } from '../domain/executor.mjs';
import { requireIndependentChecks } from './execution-evidence.mjs';
import { assertWorkspaceBinding, verifyWorkspaceRoot, workspaceBindings, MAX_WORKSPACES }
  from '../storage/workspaces.mjs';
import { collectTaskWorkspaceIds, normalizeWorkspaceScope, scopeResourceKey, requireExecutionCwd,
  normalizeScope, canonicalPhysicalPathKey } from '../domain/workspace-scope.mjs';
import { validateSessionProfile } from '../domain/session.mjs';

/** Produce a one-way credential/request digest; callers never persist the raw credential. */
export const hash = value => createHash('sha256').update(value).digest('hex');

/** Public projections remove authentication material at every nesting level. */
export function redact(value) {
  if (Array.isArray(value)) return value.map(redact);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(Object.entries(value)
    .filter(([key]) => !/token|secret/i.test(key)).map(([key, item]) => [key, redact(item)]));
}

/** Caller-generated credentials must have at least 32 bytes of encoded material. */
export function tokenHash(value) {
  requireValue(typeof value === 'string' && /^[a-fA-F0-9]{64,}$/.test(value),
    'INVALID_INPUT', 'Credential must contain at least 32 bytes encoded as hex.');
  return hash(value);
}

function requireValue(condition, code, message) {
  if (!condition) throw new BoardError(code, message);
}

function authenticate(supplied, expected) {
  const actual = hash(typeof supplied === 'string' ? supplied : '');
  requireValue(typeof expected === 'string' && expected.length === actual.length &&
    timingSafeEqual(Buffer.from(actual), Buffer.from(expected)), 'UNAUTHORIZED', 'Invalid credential.');
}

/** Fresh inline claims and receipt replays require the same explicitly approved task revision. */
function requireInlineApproval(tx, input) {
  requireValue(tx.tasks.get(input.taskId)?.approvalRevision === input.approvalRevision,
    'UNAUTHORIZED', 'Inline assignment requires the exact approved revision.');
}

/** A historical success receipt cannot reauthorize a revoked actor or released assignment. */
export function authorizeReplay(tx, operation, input, result, context = {}) {
  resetSourceObservation(tx);
  let worker = authority(tx, input,
    !['claim', 'submit', 'report', 'block', 'ask', 'ack-answer'].includes(operation));
  if (['lead-inline-assign', 'lead-inline-report'].includes(operation)) {
    worker = tx.workers.get(tx.board.leadId);
    requireValue(worker?.mode === 'lead-inline', 'UNAUTHORIZED', 'Registered inline Lead required.');
    if (operation === 'lead-inline-assign') {
      requireInlineApproval(tx, input);
    }
    operation = operation === 'lead-inline-assign' ? 'claim' : input.action;
  }
  if (operation === 'assign' || ['lead-proxy-report', 'lead-record-report'].includes(operation) ||
    input.actorId === tx.board.leadId && input.reportedByWorkerId &&
      ['ask', 'ack-answer'].includes(operation)) {
    worker = tx.workers.get(operation === 'assign' ? input.workerId : input.reportedByWorkerId);
    requireValue(worker, 'STALE_ASSIGNMENT', 'The actual registered reporter no longer exists.');
    operation = operation === 'assign' ? 'claim' :
      ['lead-proxy-report', 'lead-record-report'].includes(operation) ? input.action : operation;
  }
  if (operation === 'grant') {
    const task = tx.tasks.get(input.taskId);
    const registered = tx.workers.get(input.workerId);
    workspaceBindings(tx, collectTaskWorkspaceIds(task, tx));
    currentAuthorization(task, { worker: registered,
      grant: tx.grants.get(compositeId(input.taskId, input.workerId)), requireGrant: true });
    return;
  }
  if (operation === 'transfer') {
    const assignment = tx.assignments.get(result.assignment?.id);
    requireValue(assignment?.active && assignment.generation === tx.board.generation,
      'STALE_ASSIGNMENT', 'Transferred allocation is no longer current.');
    authenticate(input.newClaimToken, assignment.tokenHash);
    const task = tx.tasks.get(assignment.taskId);
    currentExecutionEligibility(tx, task, { worker: tx.workers.get(assignment.workerId),
      grant: tx.grants.get(compositeId(task.id, assignment.workerId)),
      record: assignment, requireGrant: true, requireActive: true });
    return;
  }
  if (operation === 'workspace-register') {
    assertWorkspaceBinding(tx, input.workspace.id);
    return;
  }
  if (operation === 'accept') {
    const task = tx.tasks.get(input.taskId);
    const evidence = tx.submissions.get(result.task.acceptedResult?.submissionId);
    requireValue(task?.resultValid && consumableResult(tx, task) &&
      task.resultRevision === result.task.resultRevision &&
      evidence?.freezeValid, 'DEPENDENCY_BLOCKED', 'The accepted result is no longer current.');
    currentExecutionEligibility(tx, task, { record: evidence });
    requireIndependentChecks(tx, task, evidence, input.checkResults);
    return;
  }
  if (input.actorId === tx.board.leadId && !input.reportedByWorkerId &&
    ['ask', 'ack-answer'].includes(operation)) worker = tx.workers.get(tx.board.leadId);
  if (['ask', 'ack-answer', 'answer'].includes(operation)) {
    const question = tx.questions.get(input.questionId ?? result.question?.id);
    if (operation === 'answer' && question?.answerRevision === result.question.answerRevision) {
      const answer = tx.answers.get(compositeId(question.id, question.answerRevision));
      if (answer?.resolvedHold && answer.generation === tx.board.generation) {
        // Clearing the old hold may itself make that old thread stale. Its immutable resolution
        // remains replayable while current identity and material contract bindings still match.
        currentExecutionEligibility(tx, tx.tasks.get(question.taskId), { record: answer });
        return;
      }
    }
    requireValue(question && projectQuestion(tx, question).state !== 'stale',
      'STALE_ASSIGNMENT', 'The question execution is no longer current.');
    if (operation !== 'ask') {
      requireValue(question.answerRevision === result.question.answerRevision,
        'CONFLICT', 'The historical answer has been superseded.');
    }
    if (operation === 'answer') return;
  }
  if (!['claim', 'submit', 'report', 'block', 'ask', 'ack-answer'].includes(operation)) return;
  const id = operation === 'claim' ? result.assignment?.id : input.assignmentId;
  const assignment = tx.assignments.get(id);
  requireValue(assignment?.active && assignment.workerId === worker?.id &&
    assignment.generation === tx.board.generation &&
    assignment.boundTaskInputRevision === tx.tasks.get(assignment.taskId)?.inputRevision,
    'STALE_ASSIGNMENT',
    'The original assignment is no longer current.');
  authenticate(input.claimToken, assignment.tokenHash);
  const task = tx.tasks.get(assignment.taskId);
  if (worker?.mode === 'direct') requireExecutionCwd(tx, task, context.cwd);
  // A receipt describes historical success. Later phases do not revoke a still-current allocation;
  // current credentials and immutable input bindings below remain the replay authority boundary.
  currentExecutionEligibility(tx, task, { worker,
    grant: tx.grants.get(compositeId(task.id, worker.id)), record: assignment,
    requireGrant: true, requireActive: true,
    allowApprovalHold: ['ask', 'ack-answer'].includes(operation) });
}

/** Authorize the real actor; a proxy report is permitted only through the current Lead. */
function authority(tx, input, leadOnly = false) {
  if (input.actorId === tx.board.leadId) {
    authenticate(input.leadToken, tx.board.leadTokenHash);
    return null;
  }
  requireValue(!leadOnly, 'UNAUTHORIZED', 'Lead authority is required.');
  const worker = tx.workers.get(input.actorId);
  requireValue(worker && worker.mode === 'direct' && worker.capabilities.includes('write'),
    'UNAUTHORIZED', 'A registered direct writer is required.');
  authenticate(input.workerToken, worker.tokenHash);
  return worker;
}


function overlaps(a, b) {
  if (process.platform === 'win32') {
    a = a.toLowerCase();
    b = b.toLowerCase();
  }
  return a === b || a.startsWith(`${b}/`) || b.startsWith(`${a}/`);
}

/** Dependency readiness distinguishes frozen input from accepted results. */
function dependencyReady(tx, task) {
  return dependenciesReady(tx, task);
}

/** Check current reservations under the same write lock as assignment creation. */
function resourcesAvailable(tx, task) {
  // Filesystem aliases can appear after approval. Reuse the exact scope validator before any
  // reservation acquisition or stopped-owner transfer; prospective nonexistent leaves remain valid.
  for (const value of [...task.scope.read, ...task.scope.write]) {
    requireValue(JSON.stringify(normalizeWorkspaceScope(tx, task, value, normalizeScope)) === JSON.stringify(value),
      'UNSAFE_PATH', 'Stored scope no longer resolves to its approved canonical path.');
  }
  const requested = tx.taskResources.list({ taskId: task.id });
  const held = tx.reservations.list({ active: true });
  const expectedPaths = [
    ...task.scope.read.map(value => ({ key: scopeResourceKey(tx, task, value), mode: 'shared' })),
    ...task.scope.write.map(value => ({ key: scopeResourceKey(tx, task, value), mode: 'exclusive' })),
  ];
  const pathRows = requested.filter(resource => resource.kind === 'path')
    .map(resource => ({ key: resource.key, mode: resource.mode }));
  const ordered = values => values.map(value => JSON.stringify(value)).sort();
  // Legacy relative rows cannot bypass canonical reservations. Retained active holds are never
  // rebuilt from a potentially amended task scope; recovery must account for them explicitly.
  requireValue(JSON.stringify(ordered(pathRows)) === JSON.stringify(ordered(expectedPaths)) &&
    held.every(resource => resource.kind !== 'path' || typeof resource.key === 'string' &&
      path.isAbsolute(resource.key) && resource.key === canonicalPhysicalPathKey(resource.key)),
    'RECOVERY_REQUIRED', 'Resource keys require explicit canonical reconciliation.');
  return !requested.some(resource => held.some(reservation =>
    reservation.taskId !== task.id && resource.kind === reservation.kind &&
    (resource.kind === 'path' ? overlaps(resource.key, reservation.key) :
      resource.key === reservation.key) &&
    (resource.mode === 'exclusive' || reservation.mode === 'exclusive')));
}

/** Enforce per-task compare-and-swap inside the write transaction, independent of board traffic. */
function taskAtRevision(tx, input) {
  const task = tx.tasks.get(input.taskId);
  requireValue(task, 'NOT_FOUND', 'Task does not exist.');
  requireValue(task.taskRevision === input.taskRevision, 'CONFLICT', 'Task revision changed.');
  return task;
}

/** Apply a single authorized operation; receipt/event/board CAS are handled by storage. */
export function mutate(tx, operation, input, context = {}) {
  resetSourceObservation(tx);
  requireValue(!Object.hasOwn(input, 'lastReportAt'), 'INVALID_INPUT', 'Report time is server-owned.');
  const leadOnly = !['claim', 'submit', 'report', 'block', 'ask', 'ack-answer'].includes(operation);
  let worker = authority(tx, input, leadOnly);
  const provenance = { actorId: input.actorId };
  if (input.actorId === tx.board.leadId && ['ask', 'ack-answer'].includes(operation) && !input.reportedByWorkerId) {
    worker = tx.workers.get(tx.board.leadId) ?? null;
  }
  if (['lead-inline-assign', 'lead-inline-report'].includes(operation)) {
    authority(tx, input, true);
    worker = tx.workers.get(tx.board.leadId);
    requireValue(worker?.mode === 'lead-inline', 'UNAUTHORIZED', 'Registered inline Lead required.');
    if (operation === 'lead-inline-assign') requireInlineApproval(tx, input);
    if (operation === 'lead-inline-report') {
      requireValue(['report', 'block', 'submit'].includes(input.action), 'INVALID_INPUT', 'Unknown inline action.');
    }
    operation = operation === 'lead-inline-assign' ? 'claim' : input.action;
  }
  if (operation === 'assign' || ['lead-proxy-report', 'lead-record-report'].includes(operation) ||
    input.actorId === tx.board.leadId && input.reportedByWorkerId &&
      ['ask', 'ack-answer'].includes(operation)) {
    authority(tx, input, true);
    worker = tx.workers.get(operation === 'assign' ? input.workerId : input.reportedByWorkerId);
    requireValue(worker, 'UNAUTHORIZED', 'The actual registered worker is required.');
    const task = tx.tasks.get(input.taskId);
    if (worker.mode === 'lead-proxy') {
      requireValue(operation !== 'lead-record-report', 'UNAUTHORIZED', 'Proxy workers require proxy transport.');
      requireValue(task && task.scope.write.length === 0 && worker.capabilities.includes('read'),
        'UNAUTHORIZED', 'Read-only proxy work cannot have a write scope.');
    } else if (worker.mode === 'lead-recorded') {
      requireValue(operation !== 'lead-proxy-report', 'UNAUTHORIZED', 'Recorded workers require recorded transport.');
      requireValue(worker.capabilities.includes('write') &&
        (operation === 'assign' || input.reportEvidenceRefs?.length),
        'UNAUTHORIZED', 'Recorded work requires observed permission and report evidence.');
      provenance.reportEvidenceRefs = input.reportEvidenceRefs ?? [];
    } else {
      requireValue(operation === 'assign' && worker.mode === 'direct' &&
        worker.capabilities.includes('write'), 'UNAUTHORIZED',
      'Proxy transport requires a proxy worker; direct assignments require observed write capability.');
    }
    Object.assign(provenance, { proxyWriterId: input.actorId, reportedByWorkerId: worker.id,
      reportedByRole: worker.role, reportedByHostId: worker.hostId });
    if (operation === 'assign') operation = 'claim';
    else if (['lead-proxy-report', 'lead-record-report'].includes(operation)) {
      requireValue(['report', 'block', 'submit'].includes(input.action),
        'INVALID_INPUT', 'Unknown proxy report action.');
      operation = input.action;
    }
  }
  if (worker?.mode === 'direct' && ['claim', 'submit', 'report', 'block', 'ask', 'ack-answer'].includes(operation)) {
    requireExecutionCwd(tx, tx.tasks.get(input.taskId), context.cwd);
  }
  const result = mutateAuthorized(tx, operation, input, worker, provenance);
  if (provenance.reportedByWorkerId) {
    tx.audit('proxy-report', { taskId: input.taskId, ...provenance });
  }
  return result;
}

/** Apply already authenticated actor context; only the wrapper chooses proxy transport. */
function mutateAuthorized(tx, operation, input, worker, provenance) {
  requireValue(!tx.board.recoveryRequired || operation === 'recover', 'RECOVERY_REQUIRED',
    'Restored state requires explicit reconciliation before any new coordination writes.');
  if (questionOperations.has(operation)) {
    return questionMutation(tx, operation, input, worker, { authenticate, provenance });
  }
  if (operation === 'record-dispatch') return recordDispatch(tx, input);
  if (lifecycleOperations.has(operation)) {
    return lifecycle(tx, operation, input, { requireValue, taskAtRevision, tokenHash,
      normalizeScope, resourcesAvailable, redact });
  }
  if (operation === 'workspace-register') {
    const item = input.workspace;
    requireValue(item && typeof item.id === 'string' && /^[a-z][a-z0-9-]{0,63}$/.test(item.id) &&
      typeof item.root === 'string', 'INVALID_INPUT', 'Workspace ID and root required.');
    requireValue(!tx.board.workspaces.some(record => record.id === item.id) &&
      tx.board.workspaces.length < MAX_WORKSPACES, 'CONFLICT', 'Workspace exists or registry is full.');
    const workspace = { id: item.id, revision: 1, status: 'active',
      ...verifyWorkspaceRoot(tx.board.projectRoot, item.root) };
    tx.board.workspaces.push(workspace);
    return { workspace };
  }
  if (operation === 'register') {
    const item = input.worker;
    requireValue(item && item.id && item.role &&
      ['direct', 'lead-proxy', 'lead-recorded', 'lead-inline'].includes(item.mode) && Array.isArray(item.capabilities),
      'INVALID_INPUT', 'Worker identity and observed permissions are required.');
    requireValue(!tx.workers.get(item.id), 'CONFLICT', 'Worker already exists.');
    requireValue(item.mode !== 'lead-inline' || item.id === tx.board.leadId && item.role === 'lead',
      'UNAUTHORIZED', 'Inline identity must be the real Lead.');
    const readonly = ['team-reviewer', 'team-architect', 'team-ai-architect',
      'team-ai-simulation-actor-basic', 'team-ai-simulation-actor-advanced',
    'team-explorer', 'team-delivery-checker'];
    requireValue(!readonly.includes(item.role) || !item.capabilities.includes('write'),
      'UNAUTHORIZED', 'Registered role cannot acquire production write permission.');
    const record = { ...executorIdentity(item), id: item.id, hostId: item.hostId, role: item.role,
      mode: item.mode, capabilities: item.capabilities };
    tx.workers.put({ ...record, tokenHash: ['lead-inline', 'lead-recorded'].includes(item.mode) ?
      null : tokenHash(item.workerToken) });
    return { worker: redact(record) };
  }
  if (operation === 'add') {
    const item = input.task;
    requireValue(item?.allowLeadInline === undefined || typeof item.allowLeadInline === 'boolean',
      'INVALID_INPUT', 'Inline opt-in must be boolean.');
    requireValue(item && item.id && item.title && item.outcome && item.sourceRefs?.length &&
      item.acceptanceRefs?.length && item.eligibleRoles?.length,
      'INVALID_INPUT', 'Task identity, outcome, source, acceptance and roles are required.');
    requireValue(!tx.tasks.get(item.id), 'CONFLICT', 'Task already exists.');
    validateSourceRefs(item.sourceRefs);
    requireValue(Array.isArray(item.scope?.write ?? []) && Array.isArray(item.scope?.read ?? []) &&
      Array.isArray(item.resources ?? []) && Array.isArray(item.dependencies ?? []) &&
      Array.isArray(item.eligibleRoles) && Array.isArray(item.sourceRefs) &&
      Array.isArray(item.acceptanceRefs), 'INVALID_INPUT', 'Task lists must be arrays.');
    const write = (item.scope?.write ?? []).map(value => normalizeWorkspaceScope(tx, item, value, normalizeScope));
    const read = (item.scope?.read ?? []).map(value =>
      normalizeWorkspaceScope(tx, item, value, normalizeScope));
    const task = { id: item.id, title: item.title, outcome: item.outcome,
      sourceRefs: item.sourceRefs, acceptanceRefs: item.acceptanceRefs,
      requiredSkills: item.requiredSkills ?? [], responsibilities: item.responsibilities ?? [],
      allowLeadInline: item.allowLeadInline === true, workspaceId: item.workspaceId ?? 'main',
      acceptancePolicy: item.acceptancePolicy ?? { requiredChecks: [] }, verification: item.verification ?? null,
      eligibleRoles: item.eligibleRoles, priority: item.priority ?? 0,
      scope: { read, write }, state: 'planned', phase: 'planned',
      taskRevision: 1, approvalRevision: 0, inputRevision: 1, inputValid: true,
      resultRevision: 0, resultValid: false, freezeRevision: 0,
      needsReconcile: false, cleanupPending: false, resources: item.resources ?? [],
      executionRevision: 1 };
    workspaceBindings(tx, collectTaskWorkspaceIds(task, tx));
    for (const edge of item.dependencies ?? []) {
      requireValue(['accepted-result', 'frozen-submission'].includes(edge.gate) &&
        edge.taskId !== item.id && tx.tasks.get(edge.taskId),
        'INVALID_INPUT', 'Dependency must reference an existing task and a supported gate.');
    }
    tx.tasks.put(task);
    for (const edge of item.dependencies ?? []) {
      tx.dependencies.put({ id: compositeId(item.id, edge.taskId), taskId: item.id,
        dependsOnTaskId: edge.taskId, gate: edge.gate });
    }
    validateExecutionContract(task, tx);
    const resources = [
      ...read.map(value => ({ kind: 'path', key: scopeResourceKey(tx, task, value), mode: 'shared' })),
      ...write.map(value => ({ kind: 'path', key: scopeResourceKey(tx, task, value), mode: 'exclusive' })),
    ];
    for (const resource of item.resources ?? []) {
      requireValue(resource.kind === 'resource' && typeof resource.key === 'string' &&
        resource.key.length > 0 && ['shared', 'exclusive'].includes(resource.mode),
        'INVALID_INPUT', 'Invalid named resource.');
      resources.push(resource);
    }
    for (const resource of resources) {
      tx.taskResources.put({ ...resource, id: randomUUID(), taskId: item.id });
    }
    return { task };
  }
  if (operation === 'grant') {
    const task = tx.tasks.get(input.taskId);
    const registered = tx.workers.get(input.workerId);
    requireValue(task && registered && task.approvalRevision === input.approvalRevision &&
      roleEligible(task, registered), 'UNAUTHORIZED', 'Grant scope is not applicable.');
    requireValue(!task.scope.write.length || registered.capabilities.includes('write') &&
      registered.mode !== 'lead-proxy', 'UNAUTHORIZED', 'Worker cannot receive production write scope.');
    requireWorkerScope(task, registered);
    currentAuthorization(task);
    requireCurrentSources(tx, task);
    const approvedResponsibilities = input.approvedResponsibilities ?? task.responsibilities ?? [];
    requireValue(Array.isArray(approvedResponsibilities) && approvedResponsibilities.every(value =>
      (task.responsibilities ?? []).includes(value)), 'UNAUTHORIZED', 'Responsibilities exceed task contract.');
    requireValue(input.executionMode === undefined || input.executionMode === registered.mode,
      'UNAUTHORIZED', 'Grant mode differs from registered executor.');
    const grant = { executionMode: registered.mode, approvedResponsibilities,
      workspaceBindings: workspaceBindings(tx, collectTaskWorkspaceIds(task, tx)), id: compositeId(input.taskId, input.workerId), taskId: input.taskId,
      workerId: input.workerId, approvalRevision: input.approvalRevision, revoked: false };
    tx.grants.put(grant);
    return { grant };
  }
  const task = taskAtRevision(tx, input);
  if (operation === 'approve') {
    requireCurrentSources(tx, task);
    requireValue(task.state === 'planned', 'CONFLICT', 'Only planned tasks can be approved.');
    requireValue(task.inputValid && !task.needsReconcile, 'DEPENDENCY_BLOCKED',
      'Task input must be reconciled before approval.');
    requireValue(Number.isSafeInteger(task.executionRevision) && task.executionRevision > 0,
      'DEPENDENCY_BLOCKED', 'Unknown execution format requires explicit reconciliation.');
    task.state = 'open';
    task.approvalRevision = task.taskRevision + 1;
  } else if (operation === 'claim') {
    requireValue(worker, 'UNAUTHORIZED', 'Claim requires the registered worker.');
    const grant = tx.grants.get(compositeId(task.id, worker.id));
    requireValue(grant && !grant.revoked && grant.taskId === task.id && grant.workerId === worker.id &&
      grant.approvalRevision === task.approvalRevision &&
      roleEligible(task, worker), 'UNAUTHORIZED', 'No current grant for this task.');
    requireValue(task.state === 'open' && !tx.assignments.list({ taskId: task.id, active: true }).length,
      'CONFLICT', 'Task already has an owner or is not open.');
    requireValue(task.inputValid && !task.needsReconcile && !task.cleanupPending,
      'DEPENDENCY_BLOCKED', 'Task inputs or ownership cleanup are unresolved.');
    currentExecutionEligibility(tx, task, { worker, grant, requireGrant: true });
    assertNoBackpressure(tx);
    requireValue(!task.questionHold, 'QUESTION_PENDING', 'Resolve the persistent approval hold first.');
    requireValue(!dispatchUnknown(tx, worker, task), 'RECOVERY_REQUIRED',
      'Resolve the related unknown dispatch before assigning a new owner.');
    requireValue(dependencyReady(tx, task), 'DEPENDENCY_BLOCKED', 'Required input is not ready.');
    requireValue(resourcesAvailable(tx, task), 'SCOPE_CONFLICT', 'A resource is reserved.');
    const assignment = { id: randomUUID(), taskId: task.id, workerId: worker.id, active: true,
      tokenHash: tokenHash(input.claimToken), approvalRevision: task.approvalRevision,
      generation: tx.board.generation, ...executorBinding(worker, provenance),
      actualExecutor: executorBinding(worker, provenance), ...executionBinding(tx, task) };
    tx.assignments.put(assignment);
    consumeDependencies(tx, task);
    for (const resource of tx.taskResources.list({ taskId: task.id })) {
      tx.reservations.put({ ...resource, id: randomUUID(), assignmentId: assignment.id, active: true });
    }
    task.state = 'running';
    task.phase = 'running';
    task.taskRevision++;
    tx.tasks.put(task);
    return { task, assignment: redact(assignment) };
  } else if (['submit', 'report', 'block'].includes(operation)) {
    const assignment = tx.assignments.get(input.assignmentId);
    requireValue(assignment?.active && assignment.taskId === task.id &&
      assignment.workerId === worker?.id && assignment.generation === tx.board.generation,
      'STALE_ASSIGNMENT', 'Assignment is no longer current.');
    authenticate(input.claimToken, assignment.tokenHash);
    requireValue(['running', 'blocked'].includes(task.state), 'CONFLICT', 'Task is not executing.');
    if (operation === 'submit') {
      requireValue(!task.verification || task.scope.write.length === 0 ||
        worker.capabilities.includes('write'), 'UNAUTHORIZED', 'Verification cannot elevate write permission.');
      requireValue(!effectivePending(tx, task.id).some(question => blocksExecution(tx, question)),
        'QUESTION_PENDING', 'Resolve the blocking current-task decision before submitting.');
      currentExecutionEligibility(tx, task, { worker,
        grant: tx.grants.get(compositeId(task.id, worker.id)), record: assignment,
        requireGrant: true, requireActive: true });
      requireValue(task.inputValid && !task.needsReconcile &&
        assignment.boundTaskInputRevision === task.inputRevision && dependencyReady(tx, task),
        'DEPENDENCY_BLOCKED', 'Submission input is no longer applicable.');
      requireValue(input.evidenceRefs?.length && typeof input.inputRevision === 'string',
        'INVALID_INPUT', 'Submission requires evidence and immutable input revision.');
      for (const old of tx.submissions.list({ taskId: task.id })) {
        if (old.freezeValid) tx.submissions.put({ ...old, freezeValid: false });
      }
      task.freezeRevision++;
      tx.submissions.put({ id: randomUUID(), taskId: task.id, assignmentId: assignment.id,
        actualExecutor: { ...structuredClone(assignment.actualExecutor), provenance: structuredClone(provenance) },
        executorKey: assignment.executorKey, workspaceBindings: assignment.workspaceBindings,
        taskRevision: task.taskRevision + 1, evidenceRefs: input.evidenceRefs,
        inputRevision: input.inputRevision,
        ...structuredClone({ executionRevision: assignment.executionRevision,
          boundTaskInputRevision: assignment.boundTaskInputRevision,
          approvalRevision: assignment.approvalRevision, inputBindings: assignment.inputBindings }),
        freezeRevision: task.freezeRevision, writesStopped: input.writesStopped === true,
        processStopped: input.processStopped === true,
        freezeValid: input.writesStopped === true && input.processStopped === true });
      task.state = 'submitted';
      task.phase = 'submitted';
      task.cleanupPending = true;
    } else {
      task.lastReportAt = new Date().toISOString();
      if (operation === 'block') {
        requireValue(typeof input.blocker === 'string' && input.blocker.trim(),
          'INVALID_INPUT', 'A concrete blocker is required.');
      }
      let applicable = true;
      try {
        currentExecutionEligibility(tx, task, { worker,
          grant: tx.grants.get(compositeId(task.id, worker.id)), record: assignment,
          requireGrant: true, requireActive: true });
      } catch (error) {
        if (!(error instanceof BoardError)) throw error;
        applicable = false;
      }
      // Progress may describe invalid input, but cannot silently resume a reconciliation hold.
      requireValue(operation === 'block' ||
        !effectivePending(tx, task.id).some(question => blocksExecution(tx, question)),
        'QUESTION_PENDING', 'A current task decision still blocks execution.');
      task.state = operation === 'block' || !applicable ?
        'blocked' : 'running';
      task.phase = input.phase ?? task.phase;
      task.progress = input.progress ?? '';
      task.blocker = input.blocker ?? null;
      if (input.nextCheckpoint !== undefined) {
        requireValue(typeof input.nextCheckpoint === 'string' && input.nextCheckpoint.length <= 280,
          'INVALID_INPUT', 'Next checkpoint must be a compact summary.');
        task.nextCheckpoint = input.nextCheckpoint;
      }
    }
  } else if (operation === 'accept') {
    // An unknown execution epoch is reconciliation failure, distinct from pending decisions.
    requireValue(Number.isSafeInteger(task.executionRevision) && task.executionRevision > 0,
      'DEPENDENCY_BLOCKED', 'Unknown execution format requires explicit reconciliation.');
    requireValue(consumableResult(tx, task), 'QUESTION_PENDING',
      'Resolve the approval obligations of this result and its consumed inputs before accepting.');
    requireValue(task.state === 'submitted' && input.gatesSatisfied === true &&
      input.evidenceRefs?.length && task.inputValid && !task.needsReconcile &&
      dependencyReady(tx, task),
      'CONFLICT', 'Acceptance requires current submitted evidence and satisfied gates.');
    const evidence = tx.submissions.list({ taskId: task.id }).find(item =>
      item.freezeValid && item.freezeRevision === task.freezeRevision);
    requireValue(evidence, 'DEPENDENCY_BLOCKED', 'Current immutable frozen evidence is required.');
    currentExecutionEligibility(tx, task, { record: evidence });
    const checkBindings = requireIndependentChecks(tx, task, evidence, input.checkResults);
    task.state = 'closed';
    task.resultRevision++;
    task.resultValid = true;
    task.acceptanceEvidence = input.evidenceRefs;
    task.acceptedResult = { resultRevision: task.resultRevision, submissionId: evidence.id, checkBindings,
      ...executionBinding(tx, task) };
    tx.audit('accepted-result', { taskId: task.id, inputRevision: task.inputRevision,
      resultRevision: task.resultRevision, evidenceRefs: input.evidenceRefs,
      acceptedResult: task.acceptedResult });
  } else if (operation === 'release') {
    requireValue(input.writesStopped === true && input.processStopped === true,
      'RECOVERY_REQUIRED', 'Confirm all writers and processes stopped before release.');
    for (const assignment of tx.assignments.list({ taskId: task.id, active: true })) {
      tx.assignments.put({ ...assignment, active: false });
    }
    for (const reservation of tx.reservations.list({ taskId: task.id, active: true })) {
      tx.reservations.put({ ...reservation, active: false });
    }
    if (['running', 'blocked'].includes(task.state)) {
      task.state = task.approvalRevision > 0 ? 'open' : 'planned';
    }
    task.cleanupPending = false;
  } else {
    throw new BoardError('UNKNOWN_OPERATION', 'Unsupported operation.');
  }
  task.taskRevision++;
  tx.tasks.put(task);
  return { task };
}

/** Project a consistent storage snapshot into bounded public lists without credentials. */
export function publicSnapshot(snapshot, { includeArchived = false } = {}) {
  const { board, ...lists } = snapshot;
  const tx = snapshotContext(snapshot);
  return redact({ ...lists,
    tasks: lists.tasks.filter(task => includeArchived || task.archived !== true)
      .map(task => ({ ...task, ...readiness(tx, task, resourcesAvailable) })),
    questions: lists.questions.map(question => projectQuestion(tx, question)),
    questionPolicy: questionPolicy(board), schemaVersion: 1, databaseSchemaVersion: board.schemaVersion,
    boardId: board.boardId, generation: board.generation,
    revision: board.boardRevision, eventSeq: board.eventSeq, replayFloor: board.replayFloor,
    sessionProfile: board.sessionProfile === undefined ? undefined : validateSessionProfile(board.sessionProfile),
    recoveryRequired: board.recoveryRequired === true,
    maintenance: board.maintenance ? { id: board.maintenance.id, active: board.maintenance.active,
      ownerId: board.maintenance.ownerId, enteredAt: board.maintenance.enteredAt } : null });
}

/** Read operations share the same dependency/resource rules as mutation-time claim checks. */
export function query(tx, operation, input) {
  resetSourceObservation(tx);
  let worker;
  if (input.actorId !== tx.board.leadId) {
    worker = tx.workers.get(input.actorId);
    requireValue(worker && worker.capabilities.some(capability => ['read', 'write'].includes(capability)),
      'UNAUTHORIZED', 'A registered reader is required.');
    authenticate(input.workerToken, worker.tokenHash);
  } else authority(tx, input, true);
  if (operation === 'workspaces') return { workspaces: tx.board.workspaces.map(item => assertWorkspaceBinding(tx, item.id)) };
  if (operation === 'inbox') {
    requireValue(!worker, 'UNAUTHORIZED', 'The Lead owns the question inbox.');
    return redact(compactQuery(tx, operation, input, null, resourcesAvailable));
  }
  if (operation === 'show' || operation === 'source-check') {
    const task = tx.tasks.get(input.taskId);
    requireValue(task, 'NOT_FOUND', 'Task does not exist.');
    if (worker) {
      const own = tx.assignments.list({ workerId: worker.id, active: true }).map(item => item.taskId);
      requireValue(own.includes(task.id) || own.some(id => tx.dependencies.list({ taskId: id })
        .some(edge => edge.dependsOnTaskId === task.id)), 'UNAUTHORIZED', 'Task is outside current context.');
    }
    if (operation === 'source-check') {
      return { taskId: task.id, taskRevision: task.taskRevision, inputRevision: task.inputRevision,
        observation: observeSources(tx, task) };
    }
    return { task: { ...task, ...readiness(tx, task, resourcesAvailable, worker) },
      assignment: redact(tx.assignments.list({ taskId: task.id, active: true })[0] ?? null),
      submissions: tx.submissions.list({ taskId: task.id }).slice(-20) };
  }
  return redact(compactQuery(tx, operation, input, worker, resourcesAvailable));
}
