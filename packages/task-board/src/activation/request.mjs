/** Validate public request structure without echoing values or touching project state. */
import { executorIdentity } from '../domain/executor.mjs';
export function requestIssues(request, { prepare = false } = {}) {
  const missingFields = [];
  const invalidFields = [];
  const object = value => value && typeof value === 'object' && !Array.isArray(value);
  const text = (value, name) => {
    if (value === undefined || value === null || value === '') missingFields.push(name);
    else if (typeof value !== 'string' || !value.trim()) invalidFields.push(name);
  };
  if (!object(request)) return { missingFields, invalidFields: ['request'] };
  const actions = ['activate', 'resume', 'recover-service', 'record-open-result', 'prepare-request'];
  if (!actions.includes(request.action)) {
    invalidFields.push('action');
  }
  text(request.actorId, 'actorId');
  if (request.action === 'recover-service') {
    const recovery = request.serviceRecovery;
    if (!object(recovery) || recovery.confirmedStopped !== true
        || typeof recovery.expectedServiceId !== 'string'
        || !/^[\x21-\x7e]{1,256}$/.test(recovery.expectedServiceId)
        || !Array.isArray(recovery.evidenceRefs) || !recovery.evidenceRefs.length
        || recovery.evidenceRefs.length > 16
        || recovery.evidenceRefs.some(ref => typeof ref !== 'string'
          || !ref.trim() || ref.length > 1024 || /[\x00-\x1f]/.test(ref))) {
      invalidFields.push('serviceRecovery');
    }
  }
  for (const key of ['hostId', 'mainSessionId', 'projectId', 'projectName', 'sessionName']) {
    text(request.sessionProfile?.[key], `sessionProfile.${key}`);
  }
  if (request.sessionProfile !== undefined && !object(request.sessionProfile)) {
    invalidFields.push('sessionProfile');
  }
  if (request.leadPrincipal !== undefined) {
    try {
      const { principal } = executorIdentity({ principal: request.leadPrincipal });
      if (!principal || principal.hostId !== request.sessionProfile?.hostId
          || principal.agentId !== request.sessionProfile?.mainSessionId) throw new Error('Mismatch');
    } catch { invalidFields.push('leadPrincipal'); }
  }
  if (!prepare) for (const key of ['leadToken', 'claimToken', 'serviceControlToken']) {
    text(request[key], key);
    if (typeof request[key] === 'string' && request[key]
        && (!/^[a-fA-F0-9]{64,}$/.test(request[key])
          || key === 'serviceControlToken' && request[key].length > 256)) invalidFields.push(key);
  }
  if (request.action !== 'record-open-result') {
    if (request.executionApproved !== true) invalidFields.push('executionApproved');
    for (const key of ['id', 'title', 'outcome']) text(request.task?.[key], `task.${key}`);
    for (const key of ['sourceRefs', 'acceptanceRefs']) {
      if (!Array.isArray(request.task?.[key]) || !request.task[key].length) {
        invalidFields.push(`task.${key}`);
      }
    }
    // Legacy aliases otherwise disappear into the default empty scope. Never
    // reinterpret caller ownership silently, including during private preparation.
    for (const key of ['readScope', 'writeScope']) {
      if (object(request.task) && Object.hasOwn(request.task, key)) {
        invalidFields.push(`task.${key}`);
      }
      if (Object.hasOwn(request, key)) invalidFields.push(key);
    }
    if (request.task?.scope !== undefined) {
      if (!object(request.task.scope)) invalidFields.push('task.scope');
      else for (const key of ['read', 'write']) {
        if (request.task.scope[key] !== undefined && !Array.isArray(request.task.scope[key])) {
          invalidFields.push(`task.scope.${key}`);
        }
      }
    }
  }
  return { missingFields, invalidFields };
}

export function invalidRequest(issues) {
  return { state: 'activation-pending', reasonCode: 'REQUEST_INVALID', ...issues,
    nextStep: 'Obtain current native host/project/main-session metadata and correct the listed fields. '
      + 'Use task.scope.read/write arrays, not readScope/writeScope aliases. '
      + 'For a new Board with no retained state, call prepare-request to create private random credentials, '
      + 'then activate using -RequestPath. For existing state, recover the retained private handoff instead; '
      + 'never rotate credentials, invent IDs or treat process exit 0 as enabled.' };
}
