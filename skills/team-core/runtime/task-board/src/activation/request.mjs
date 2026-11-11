/** Validate public request structure without echoing values or touching project state. */
export function requestIssues(request, { prepare = false } = {}) {
  const missingFields = [];
  const invalidFields = [];
  const object = value => value && typeof value === 'object' && !Array.isArray(value);
  const text = (value, name) => {
    if (value === undefined || value === null || value === '') missingFields.push(name);
    else if (typeof value !== 'string' || !value.trim()) invalidFields.push(name);
  };
  if (!object(request)) return { missingFields, invalidFields: ['request'] };
  if (!['activate', 'resume', 'record-open-result', 'prepare-request'].includes(request.action)) {
    invalidFields.push('action');
  }
  text(request.actorId, 'actorId');
  for (const key of ['hostId', 'mainSessionId', 'projectId', 'projectName', 'sessionName']) {
    text(request.sessionProfile?.[key], `sessionProfile.${key}`);
  }
  if (request.sessionProfile !== undefined && !object(request.sessionProfile)) {
    invalidFields.push('sessionProfile');
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
    nextStep: 'Obtain current native host/project/main-session metadata and correct the listed fields; never invent IDs or omit credentials.' };
}
