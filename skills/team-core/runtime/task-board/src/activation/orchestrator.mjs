/** Session-local activation handoff; existing Board operations remain the task authority. */
import fs from 'node:fs';
import path from 'node:path';
import { randomUUID, createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { normalizeSessionProfile, sessionLocation } from '../domain/session.mjs';
import { inspectPath } from '../storage/paths.mjs';
import { protectArtifacts } from '../coordination/artifact-protection.mjs';
import { probeRuntime } from '../runtime/preflight.mjs';
import { tokenHash } from '../coordination/service.mjs';
import { serviceStatus } from '../server/control.mjs';
import { callCli } from './transport.mjs';
import { normalizeScope } from '../domain/workspace-scope.mjs';
import { requestIssues, invalidRequest } from './request.mjs';

const fail = code => { throw Object.assign(new Error('Activation requires reconciliation.'), { code }); };
const canonical = value => Array.isArray(value) ? value.map(canonical)
  : value && typeof value === 'object' ? Object.fromEntries(Object.keys(value).sort()
    .map(key => [key, canonical(value[key])])) : value;
const digest = value => createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
const ordered = values => values.map(canonical).sort((a, b) =>
  JSON.stringify(a).localeCompare(JSON.stringify(b)));

/** Match the complete effective Add contract, including separately persisted relation rows. */
function effectiveContract(task, workspaces) {
  const normalize = value => {
    const workspaceId = typeof value === 'string' ? task.workspaceId ?? 'main' : value.workspaceId;
    const workspace = workspaces.find(item => item.id === workspaceId);
    if (!workspace) fail('WORKSPACE_MISMATCH');
    const clean = normalizeScope(workspace.root, typeof value === 'string' ? value : value.path);
    return typeof value === 'string' ? clean : { workspaceId, path: clean };
  };
  return { id: task.id, title: task.title, outcome: task.outcome,
    sourceRefs: task.sourceRefs, acceptanceRefs: task.acceptanceRefs,
    requiredSkills: task.requiredSkills ?? [], responsibilities: task.responsibilities ?? [],
    allowLeadInline: task.allowLeadInline === true, workspaceId: task.workspaceId ?? 'main',
    acceptancePolicy: task.acceptancePolicy ?? { requiredChecks: [] },
    verification: task.verification ?? null, eligibleRoles: task.eligibleRoles,
    priority: task.priority ?? 0,
    scope: { read: (task.scope?.read ?? []).map(normalize),
      write: (task.scope?.write ?? []).map(normalize) },
    resources: ordered((task.resources ?? []).map(({ kind, key, mode }) => ({ kind, key, mode }))),
    dependencies: ordered((task.dependencies ?? []).map(({ taskId, gate }) => ({ taskId, gate }))),
  };
}

/** Launch once after durable intent. Uncertain outcomes never authorize duplicate processes. */
function launchService(input) {
  return new Promise((resolve, reject) => {
    const runner = fileURLToPath(new URL('./service-runner.mjs', import.meta.url));
    const child = spawn(process.execPath, [runner], {
      detached: true, windowsHide: true, cwd: input.location.projectRoot,
      stdio: ['ignore', 'ignore', 'ignore', 'ipc'],
    });
    const timer = setTimeout(() => {
      if (child.connected) child.disconnect();
      child.unref();
      reject(Object.assign(new Error('Service outcome unknown.'), { code: 'SERVICE_OUTCOME_UNKNOWN' }));
    }, 10000);
    child.on('error', () => {
      clearTimeout(timer);
      reject(Object.assign(new Error('Service start failed.'), { code: 'SERVICE_OUTCOME_UNKNOWN' }));
    });
    child.once('message', identity => {
      clearTimeout(timer);
      if (child.connected) child.disconnect();
      child.unref();
      if (!identity || Buffer.byteLength(JSON.stringify(identity)) > 16384) {
        reject(Object.assign(new Error('Invalid service response.'), { code: 'SERVICE_OUTCOME_UNKNOWN' }));
      } else resolve(identity);
    });
    child.send(input, error => {
      if (error) {
        clearTimeout(timer);
        if (child.connected) child.disconnect();
        child.unref();
        reject(Object.assign(new Error('Service outcome unknown.'), { code: 'SERVICE_OUTCOME_UNKNOWN' }));
      }
    });
  });
}

export async function activate(projectRoot, request) {
  let release;
  let selected;
  let retainedService;
  try {
    const issues = requestIssues(request);
    if (issues.missingFields.length || issues.invalidFields.length) return invalidRequest(issues);
    if (!request || !['activate', 'resume', 'record-open-result'].includes(request.action)
        || typeof request.actorId !== 'string' || !request.actorId) fail('INVALID_INPUT');
    const profile = normalizeSessionProfile(request.sessionProfile);
    selected = sessionLocation(profile);
    const root = inspectPath(projectRoot);
    const location = { projectRoot: root, ...selected };
    const directory = inspectPath(path.join(root, selected.boardPath));
    const database = path.join(directory, 'board.sqlite');
    const journalPath = inspectPath(path.join(directory, 'activation.json'));
    const lockPath = inspectPath(path.join(directory, 'activation.lock'));
    const runtime = await probeRuntime();
    if (!runtime.available) fail(runtime.reasonCode);
    for (const field of ['leadToken', 'claimToken', 'serviceControlToken']) tokenHash(request[field]);
    if (!/^[a-fA-F0-9]{64,256}$/.test(request.serviceControlToken)) fail('INVALID_INPUT');
    const publicText = JSON.stringify({ task: request.task, phase: request.phase,
      progress: request.progress, nextCheckpoint: request.nextCheckpoint });
    if (['leadToken', 'claimToken', 'serviceControlToken'].some(field =>
      publicText.includes(request[field]))) fail('CREDENTIAL_IN_PUBLIC_CONTEXT');
    if (request.action !== 'record-open-result' && (request.executionApproved !== true
        || !request.task?.id || !request.task.title || !request.task.outcome
        || !request.task.sourceRefs?.length || !request.task.acceptanceRefs?.length)) {
      fail('EXECUTION_APPROVAL_REQUIRED');
    }
    const call = (operation, input) => callCli(root, selected.boardPath, selected.sessionKey,
      operation, { actorId: request.actorId, leadToken: request.leadToken, ...input });
    // Authenticate existing data before touching ignore policy, journal or lock files.
    let observed;
    if (fs.existsSync(database)) observed = await call('inspect', {});
    if (request.action === 'record-open-result' && (!observed || !fs.existsSync(journalPath))) {
      fail('ACTIVATION_HANDOFF_REQUIRED');
    }
    protectArtifacts({ ...location, allowAppend: !fs.existsSync(database) });
    fs.mkdirSync(directory, { recursive: true });
    let lock;
    try { lock = fs.openSync(lockPath, 'wx', 0o600); } catch { fail('ACTIVATION_BUSY'); }
    release = () => { fs.closeSync(lock); fs.unlinkSync(lockPath); };
    let journal;
    if (fs.existsSync(journalPath)) {
      if (fs.statSync(journalPath).size > 1048576) fail('ACTIVATION_STATE_INVALID');
      journal = JSON.parse(fs.readFileSync(journalPath, 'utf8'));
      if (journal.version !== 1 || journal.root !== root || journal.sessionKey !== selected.sessionKey
          || journal.actorId !== request.actorId) fail('ACTIVATION_CONTEXT_MISMATCH');
      if (journal.generation && !observed) fail('RECOVERY_REQUIRED');
    } else {
      if (observed) fail('ACTIVATION_HANDOFF_REQUIRED');
      journal = { version: 1, root, sessionKey: selected.sessionKey, actorId: request.actorId,
        tasks: {}, presentation: { status: 'not-attempted' } };
    }
    const save = () => {
      inspectPath(journalPath);
      const temporary = `${journalPath}.${randomUUID()}.tmp`;
      fs.writeFileSync(temporary, JSON.stringify(journal), { flag: 'wx', mode: 0o600 });
      fs.renameSync(temporary, journalPath);
    };
    if (!observed) {
      if (journal.initializeIntent) fail('INITIALIZATION_OUTCOME_UNKNOWN');
      journal.initializeIntent = 'unknown';
      save();
      observed = await call('initialize', { sessionProfile: request.sessionProfile });
    }
    if (journal.generation && journal.generation !== observed.generation) fail('STALE_GENERATION');
    journal.generation = observed.generation;
    journal.boardId = observed.boardId;
    journal.initializeIntent = 'known';
    save();
    const mutate = (operation, input, step) => call(operation, {
      generation: observed.generation,
      operationId: `activation-${digest([selected.sessionKey, request.task?.id, step])}`,
      ...input,
    });
    if (request.action === 'record-open-result') {
      if (!['queued', 'opened', 'link-only', 'unknown'].includes(request.presentationOutcome)
          || journal.presentation.status !== 'unknown') fail('PRESENTATION_CONFLICT');
      journal.presentation = { status: request.presentationOutcome };
      save();
      return { state: 'enabled', ...selected, presentation: journal.presentation };
    }
    const task = { ...request.task, eligibleRoles: ['lead'], allowLeadInline: true };
    const workspaces = (await call('workspaces', {})).result.workspaces;
    const contract = effectiveContract(task, workspaces);
    const contractDigest = digest(contract);
    const taskJournal = journal.tasks[task.id];
    if (taskJournal && taskJournal.contractDigest !== contractDigest) fail('TASK_CONTRACT_CHANGED');
    const existingTask = observed.result?.tasks?.find(item => item.id === task.id);
    if (!taskJournal && existingTask) fail('TASK_RECONCILIATION_REQUIRED');
    if (!taskJournal) {
      journal.tasks[task.id] = { contractDigest };
      save();
    }
    let snapshot = (await call('inspect', {})).result;
    const worker = snapshot.workers.find(item => item.id === request.actorId);
    if (!worker) await mutate('register', { worker: {
      id: request.actorId, role: 'lead', mode: 'lead-inline', capabilities: ['write'],
    } }, 'register-lead');
    else if (worker.role !== 'lead' || worker.mode !== 'lead-inline') fail('EXECUTOR_CONFLICT');
    if (!snapshot.tasks.some(item => item.id === task.id)) await mutate('add', { task }, 'add');
    let shown = (await call('show', { taskId: task.id })).result;
    snapshot = (await call('inspect', {})).result;
    const actual = effectiveContract({ ...shown.task,
      resources: snapshot.taskResources.filter(item => item.taskId === task.id && item.kind === 'resource'),
      dependencies: snapshot.dependencies.filter(item => item.taskId === task.id)
        .map(item => ({ taskId: item.dependsOnTaskId, gate: item.gate })),
    }, workspaces);
    if (digest(actual) !== contractDigest) fail('TASK_CONTRACT_CHANGED');
    if (!shown.task.allowLeadInline || shown.task.needsReconcile || !shown.task.inputValid) {
      fail('TASK_RECONCILIATION_REQUIRED');
    }
    if (shown.task.state === 'planned') {
      await mutate('approve', { taskId: task.id, taskRevision: shown.task.taskRevision }, 'approve');
      shown = (await call('show', { taskId: task.id })).result;
    }
    if (shown.task.state === 'open') {
      await mutate('grant', { workerId: request.actorId, taskId: task.id,
        approvalRevision: shown.task.approvalRevision, executionMode: 'lead-inline',
        approvedResponsibilities: task.responsibilities ?? [] }, 'grant');
      await mutate('lead-inline-assign', { taskId: task.id, taskRevision: shown.task.taskRevision,
        approvalRevision: shown.task.approvalRevision, claimToken: request.claimToken }, 'assign');
      shown = (await call('show', { taskId: task.id })).result;
    }
    if (shown.assignment && shown.assignment.workerId !== request.actorId) fail('EXECUTOR_CONFLICT');
    const retainedTask = journal.tasks[task.id];
    if (shown.assignment && shown.task.state === 'running' && !retainedTask.reported) {
      // Persist the exact revision before dispatch so an interrupted response can replay its receipt.
      retainedTask.reportRevision ??= shown.task.taskRevision;
      retainedTask.initialReport ??= {
        phase: request.phase ?? 'execution-start',
        progress: request.progress ?? 'Authorized execution started; task visibility is active.',
        nextCheckpoint: request.nextCheckpoint ?? 'Complete the next agreed task milestone.',
      };
      save();
      await mutate('lead-inline-report', {
        taskId: task.id, taskRevision: retainedTask.reportRevision,
        assignmentId: shown.assignment.id, claimToken: request.claimToken,
        action: 'report', ...retainedTask.initialReport,
      }, 'initial-report');
      retainedTask.reported = true;
      save();
    }
    // Labels change independently from task/approval revisions.
    const labels = observed.result?.sessionProfile;
    if (labels && (labels.projectName !== profile.projectName || labels.sessionName !== profile.sessionName)) {
      await call('session-sync', { operationId: randomUUID(), generation: observed.generation,
        expectedLabelRevision: labels.labelRevision, projectName: profile.projectName,
        sessionName: profile.sessionName });
    }
    let firstUrl;
    if (journal.serviceIntent && !journal.service) fail('SERVICE_OUTCOME_UNKNOWN');
    if (journal.service) {
      retainedService = journal.service;
      await serviceStatus({ ...journal.service, serviceControlToken: request.serviceControlToken });
    } else {
      journal.serviceIntent = 'unknown';
      journal.presentation = { status: 'unknown' };
      save();
      const service = await launchService({ location, actorId: request.actorId,
        generation: observed.generation, leadToken: request.leadToken,
        serviceControlToken: request.serviceControlToken });
      const { ticketUrl, ...identity } = service;
      journal.service = identity;
      retainedService = identity;
      journal.serviceIntent = 'known';
      save();
      await serviceStatus({ ...identity, serviceControlToken: request.serviceControlToken });
      firstUrl = ticketUrl;
    }
    return { state: 'enabled', ...selected, taskId: task.id, boardId: observed.boardId,
      generation: observed.generation, service: journal.service,
      presentation: { ...journal.presentation, ...(firstUrl ? { url: firstUrl } : {}) } };
  } catch (error) {
    return { state: 'activation-pending', ...selected,
      ...(retainedService ? { service: retainedService } : {}),
      reasonCode: error.code ?? 'ACTIVATION_STATE_INVALID',
      nextStep: 'Reconcile the indicated prerequisite or retained state; do not reset or install automatically.' };
  } finally { release?.(); }
}
