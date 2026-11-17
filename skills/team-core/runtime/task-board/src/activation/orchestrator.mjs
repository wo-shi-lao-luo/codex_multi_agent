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
import { serviceStatus, serviceOpen, stopService } from '../server/control.mjs';
import { attachSharedService } from './shared-service.mjs';
import { sharedHome } from './shared-registry.mjs';
import { callCli } from './transport.mjs';
import { normalizeScope } from '../domain/workspace-scope.mjs';
import { requestIssues, invalidRequest } from './request.mjs';
import { probeServiceTransport, verifyRecoveryCredential } from './service-recovery.mjs';

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
      } else resolve({ service: identity, processId: child.pid });
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

/** Authenticate a private activation request and serialize its journal effects.
 * Recovery requires a reconciled refused service or an OS-confirmed absent owned PID.
 * Uncertain launch is never retried.
 */
export async function activate(projectRoot, request, { serviceMode = 'legacy', sharedRuntimeHome } = {}) {
  let release;
  let selected;
  let retainedService;
  try {
    const issues = requestIssues(request);
    if (issues.missingFields.length || issues.invalidFields.length) return invalidRequest(issues);
    if (!request || !['activate', 'resume', 'recover-service', 'reopen-service', 'migrate-service', 'record-open-result'].includes(request.action)
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
    const credentials = ['record-open-result', 'recover-service', 'reopen-service', 'migrate-service'].includes(request.action)
      ? ['leadToken', 'serviceControlToken'] : ['leadToken', 'claimToken', 'serviceControlToken'];
    for (const field of credentials) tokenHash(request[field]);
    if (!/^[a-fA-F0-9]{64,256}$/.test(request.serviceControlToken)) fail('INVALID_INPUT');
    const publicText = JSON.stringify({ task: request.task, phase: request.phase,
      progress: request.progress, nextCheckpoint: request.nextCheckpoint,
      serviceRecovery: request.serviceRecovery, servicePresentation: request.servicePresentation,
      serviceMigration: request.serviceMigration, leadPrincipal: request.leadPrincipal });
    if (['leadToken', 'claimToken', 'serviceControlToken'].some(field =>
      typeof request[field] === 'string' && request[field].length > 0
        && publicText.includes(request[field]))) fail('CREDENTIAL_IN_PUBLIC_CONTEXT');
    if (!['record-open-result', 'recover-service', 'reopen-service', 'migrate-service'].includes(request.action) && (request.executionApproved !== true
        || !request.task?.id || !request.task.title || !request.task.outcome
        || !request.task.sourceRefs?.length || !request.task.acceptanceRefs?.length)) {
      fail('EXECUTION_APPROVAL_REQUIRED');
    }
    const call = (operation, input) => callCli(root, selected.boardPath, selected.sessionKey,
      operation, { actorId: request.actorId, leadToken: request.leadToken, ...input });
    // Authenticate existing data before touching ignore policy, journal or lock files.
    let observed;
    if (fs.existsSync(database)) observed = await call('inspect', {});
    if (['record-open-result', 'recover-service', 'reopen-service', 'migrate-service'].includes(request.action)
        && (!observed || !fs.existsSync(journalPath))) {
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
    const runtimeHome = sharedRuntimeHome ?? journal.sharedRuntimeHome ?? sharedHome();
    if (journal.service?.serviceMode === 'shared-v1' && journal.sharedRuntimeHome
        && runtimeHome !== journal.sharedRuntimeHome) fail('ACTIVATION_CONTEXT_MISMATCH');
    const attach = () => attachSharedService({ location, actorId: request.actorId,
      generation: observed.generation, leadToken: request.leadToken,
      serviceControlToken: request.serviceControlToken }, { home: runtimeHome });
    const retain = (service, processId) => {
      const { ticketUrl, ticketExpiresAt, status, ...identity } = service;
      journal.service = identity; journal.serviceProcessId = processId;
      if (service.serviceMode === 'shared-v1') journal.sharedRuntimeHome = runtimeHome;
      journal.serviceIntent = 'known'; journal.presentation = { status: 'unknown' };
      retainedService = identity; save();
      return ticketUrl;
    };
    // Both recovery paths preserve task authority and use the same durable launch sequence.
    const validateRetainedService = () => {
      if (journal.generation !== observed.generation || journal.boardId !== observed.boardId) {
        fail('ACTIVATION_CONTEXT_MISMATCH');
      }
      retainedService = journal.service;
      if (!retainedService || journal.serviceIntent !== 'known') fail('SERVICE_OUTCOME_UNKNOWN');
      if (retainedService.boardId !== observed.boardId
          || retainedService.generation !== observed.generation
          || retainedService.sessionKey !== selected.sessionKey) fail('ACTIVATION_CONTEXT_MISMATCH');
      return verifyRecoveryCredential(
        journal, directory, request, selected.sessionKey,
      );
    };
    const replaceService = async (serviceControlTokenHash, evidence) => {
      await probeServiceTransport();
      journal.serviceRecoveryHistory = [...(journal.serviceRecoveryHistory ?? []), {
        service: retainedService,
        ...evidence,
      }].slice(-16);
      journal.serviceControlTokenHash = serviceControlTokenHash;
      if (retainedService?.serviceMode === 'shared-v1') {
        const { service, processId } = await attach();
        const url = retain(service, processId);
        return { state: 'enabled', ...selected, boardId: observed.boardId, generation: observed.generation,
          activationScope: 'service-only', taskExecution: 'not-resumed', service: journal.service,
          presentation: { status: 'unknown', url } };
      }
      delete journal.service;
      delete journal.serviceProcessId;
      journal.serviceIntent = 'unknown';
      journal.presentation = { status: 'unknown' };
      save();
      const { service, processId } = await launchService({ location, actorId: request.actorId,
        generation: observed.generation, leadToken: request.leadToken,
        serviceControlToken: request.serviceControlToken });
      const { ticketUrl, ...identity } = service;
      journal.service = identity;
      journal.serviceProcessId = processId;
      retainedService = identity;
      journal.serviceIntent = 'known';
      save();
      await serviceStatus({ ...identity, serviceControlToken: request.serviceControlToken });
      return { state: 'enabled', ...selected, activationScope: 'service-only',
        taskExecution: 'not-resumed', boardId: observed.boardId,
        generation: observed.generation, service: identity,
        presentation: { ...journal.presentation, url: ticketUrl } };
    };
    /** Commit the new binding before stopping only the exact authenticated legacy listener. */
    const migrate = async migration => {
      const verifier = validateRetainedService();
      const shared = retainedService.serviceMode === 'shared-v1';
      const history = journal.serviceMigrationHistory ?? [];
      let legacy = shared ? journal.legacyCleanupPending?.service
        ?? history.findLast(item => item.service.serviceId === migration.expectedServiceId)?.service : retainedService;
      if (!legacy || legacy.serviceId !== migration.expectedServiceId) fail('ACTIVATION_CONTEXT_MISMATCH');
      if (!shared) {
        try { await serviceStatus({ ...legacy, serviceControlToken: request.serviceControlToken }); }
        catch (error) {
          if (error.code !== 'SERVICE_UNAVAILABLE' || error.details?.transportCode !== 'ECONNREFUSED') throw error;
          if (migration.confirmedStopped !== true) fail('SERVICE_STOP_EVIDENCE_REQUIRED');
        }
      }
      const { service, processId } = await attach();
      if (!shared) {
        journal.serviceMigrationHistory = [...history, { service: legacy,
          evidenceRefs: migration.evidenceRefs }].slice(-16);
        journal.legacyCleanupPending = { service: legacy };
      }
      journal.serviceControlTokenHash = verifier;
      const url = retain(service, processId);
      let cleanup = 'complete';
      let cleanupReason;
      let cleanupTransportCode;
      if (journal.legacyCleanupPending) {
        cleanup = 'pending';
        try {
          try { await stopService({ ...legacy, serviceControlToken: request.serviceControlToken }); }
          catch (error) {
            // Losing the stop response proves neither success nor failure. A separate fresh
            // authenticated status observation below must prove exact refusal before cleanup.
            if (error.code !== 'SERVICE_UNAVAILABLE'
                || ['EACCES', 'EPERM', 'ETIMEDOUT'].includes(error.details?.transportCode)) throw error;
          }
          for (let attempt = 0; attempt < 20; attempt++) {
            try { await serviceStatus({ ...legacy, serviceControlToken: request.serviceControlToken }, { timeoutMs: 250 }); }
            catch (error) {
              if (error.code === 'SERVICE_UNAVAILABLE' && error.details?.transportCode === 'ECONNREFUSED') {
                cleanup = 'complete'; break;
              }
              if (error.code !== 'SERVICE_UNAVAILABLE'
                  || ['EACCES', 'EPERM', 'ETIMEDOUT'].includes(error.details?.transportCode)) throw error;
              // A closing listener may reset a racing status socket. This is not stop proof:
              // continue only this bounded confirmation, and require a later exact refusal.
            }
            await new Promise(resolve => setTimeout(resolve, 50));
          }
        } catch (error) {
          cleanupTransportCode = error.details?.transportCode;
          cleanupReason = ['SERVICE_CONTROL_REJECTED', 'SERVICE_UNAVAILABLE', 'INVALID_INPUT'].includes(error.code)
            ? error.code : 'LEGACY_STOP_UNCONFIRMED';
        }
        if (cleanup === 'complete') { delete journal.legacyCleanupPending; save(); }
      }
      return { state: 'enabled', ...selected, boardId: observed.boardId, generation: observed.generation,
        activationScope: 'service-only', taskExecution: 'not-resumed', service: journal.service,
        legacyCleanup: cleanup, ...(cleanup === 'pending' ? { legacyCleanupReason: cleanupReason ?? 'LEGACY_STOP_UNCONFIRMED' } : {}),
        ...(['EACCES', 'EPERM', 'ECONNREFUSED', 'ETIMEDOUT'].includes(cleanupTransportCode)
          ? { legacyCleanupTransportCode: cleanupTransportCode } : {}),
        presentation: { status: 'unknown', url } };
    };
    if (request.action === 'reopen-service') {
      validateRetainedService();
      if (retainedService.serviceId !== request.servicePresentation.expectedServiceId) fail('ACTIVATION_CONTEXT_MISMATCH');
      await serviceStatus({...retainedService,serviceControlToken:request.serviceControlToken});
      const attemptId=randomUUID();
      journal.presentation={status:'unknown',attemptId};save();
      const entry=await serviceOpen({...retainedService,serviceControlToken:request.serviceControlToken});
      return {state:'enabled',...selected,boardId:observed.boardId,generation:observed.generation,
        activationScope:'presentation-only',taskExecution:'not-resumed',service:retainedService,
        presentation:{status:'unknown',attemptId,url:entry.ticketUrl,ticketExpiresAt:entry.ticketExpiresAt}};
    }
    if (request.action === 'migrate-service') return await migrate(request.serviceMigration);
    if (request.action === 'recover-service') {
      const verifier = validateRetainedService();
      if (retainedService.serviceId !== request.serviceRecovery.expectedServiceId) {
        fail('ACTIVATION_CONTEXT_MISMATCH');
      }
      try {
        await serviceStatus({ ...retainedService, serviceControlToken: request.serviceControlToken });
        fail('SERVICE_STILL_RUNNING');
      } catch (error) {
        if (!(retainedService.serviceMode === 'shared-v1' && error.code === 'SERVICE_CONTROL_REJECTED')
            && (error.code !== 'SERVICE_UNAVAILABLE'
              || error.details?.transportCode !== 'ECONNREFUSED')) throw error;
      }
      return await replaceService(verifier, { confirmedStopped: true,
        evidenceRefs: request.serviceRecovery.evidenceRefs });
    }
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
      if (journal.presentation?.attemptId && request.presentationAttemptId !== journal.presentation.attemptId) fail('PRESENTATION_CONFLICT');
      if (!['queued', 'opened', 'link-only', 'unknown'].includes(request.presentationOutcome)
          || journal.presentation.status !== 'unknown') fail('PRESENTATION_CONFLICT');
      journal.presentation = { ...journal.presentation, status: request.presentationOutcome };
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
      ...(request.leadPrincipal ? { principal: request.leadPrincipal } : {}),
    } }, 'register-lead');
    else if (worker.role !== 'lead' || worker.mode !== 'lead-inline') fail('EXECUTOR_CONFLICT');
    else if (request.leadPrincipal && !worker.executorKey) fail('LEAD_PRINCIPAL_BINDING_REQUIRED');
    else if (request.leadPrincipal && (worker.principal?.hostId !== request.leadPrincipal.hostId
      || worker.principal?.agentId !== request.leadPrincipal.agentId)) fail('EXECUTOR_CONFLICT');
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
    // All task validation and transitions precede automatic repair: a rejected task must
    // not consume a replacement service's first presentation ticket.
    let firstUrl;
    if (journal.serviceIntent && !journal.service) fail('SERVICE_OUTCOME_UNKNOWN');
    if (journal.service && journal.service.serviceMode !== 'shared-v1' && serviceMode === 'shared') {
      const result = await migrate({ expectedServiceId: journal.service.serviceId,
        evidenceRefs: ['authenticated-activation-shared-migration'] });
      firstUrl = result.presentation.url;
    } else if (journal.service) {
      retainedService = journal.service;
      try {
        await serviceStatus({ ...retainedService, serviceControlToken: request.serviceControlToken });
      } catch (error) {
        if (error.code !== 'SERVICE_UNAVAILABLE'
            || error.details?.transportCode !== 'ECONNREFUSED') throw error;
        const verifier = validateRetainedService();
        const processId = journal.serviceProcessId;
        if (!Number.isSafeInteger(processId) || processId <= 0) throw error;
        // Signal zero observes process existence only. Alive, inaccessible or reused PIDs
        // remain pending; absence must be an actual ESRCH, never inferred from the port.
        let absent = false;
        try { process.kill(processId, 0); } catch (processError) {
          absent = processError.code === 'ESRCH';
        }
        if (!absent) throw error;
        const replacement = await replaceService(verifier, {
          proof: { kind: 'process-not-found', processId },
        });
        firstUrl = replacement.presentation.url;
      }
    } else if (serviceMode === 'shared') {
      const { service, processId } = await attach();
      journal.serviceControlTokenHash = tokenHash(request.serviceControlToken);
      firstUrl = retain(service, processId);
    } else {
      await probeServiceTransport();
      journal.serviceControlTokenHash = tokenHash(request.serviceControlToken);
      journal.serviceIntent = 'unknown';
      journal.presentation = { status: 'unknown' };
      save();
      const { service, processId } = await launchService({ location, actorId: request.actorId,
        generation: observed.generation, leadToken: request.leadToken,
        serviceControlToken: request.serviceControlToken });
      const { ticketUrl, ...identity } = service;
      journal.service = identity;
      journal.serviceProcessId = processId;
      retainedService = identity;
      journal.serviceIntent = 'known';
      save();
      await serviceStatus({ ...identity, serviceControlToken: request.serviceControlToken });
      firstUrl = ticketUrl;
    }
    return { state: 'enabled', ...selected, taskId: task.id, boardId: observed.boardId,
      generation: observed.generation, service: journal.service,
      identityBinding: request.leadPrincipal || worker?.executorKey ? 'observed' : 'unknown',
      presentation: { ...journal.presentation, ...(firstUrl ? { url: firstUrl } : {}) } };
  } catch (error) {
    const transportCode = error.details?.transportCode;
    let nextStep = 'Reconcile the indicated prerequisite or retained state; '
      + 'do not reset or install automatically.';
    if (['EACCES', 'EPERM'].includes(transportCode)) {
      nextStep = 'Use explicitly authorized host execution with loopback permission; '
        + 'reconcile retained state before retry.';
    } else if (transportCode === 'ECONNREFUSED') {
      nextStep = 'Reconcile the exact retained service with host listener and runner evidence, '
        + 'then explicitly recover-service.';
    } else if (error.code === 'LEAD_PRINCIPAL_BINDING_REQUIRED') {
      nextStep = 'Read the current Board revision and explicitly bind-lead-principal using observed '
        + 'native evidence. Preserve old allocations and frozen evidence; use stopped-owner transfer, '
        + 'a fresh freeze and newly bound independent checks. Resume never backfills historical identity.';
    } else if (error.code === 'TASK_CONTRACT_CHANGED') {
      nextStep = 'The task contract requires explicit reconciliation; no task execution was resumed. '
        + 'For display-only recovery, use recover-service with the exact retained service identity, '
        + 'credentials and fresh host-confirmed stop evidence. For a healthy display use reopen-service; '
        + 'for a new outcome prepare-next-task (wrapper -TaskPath). Do not restore an obsolete task scope.';
    }
    return { state: 'activation-pending', taskExecution:'not-resumed', ...selected,
      ...(retainedService ? { service: retainedService } : {}),
      reasonCode: error.code ?? 'ACTIVATION_STATE_INVALID',
      ...(['EACCES', 'EPERM', 'ECONNREFUSED', 'ETIMEDOUT'].includes(transportCode)
        ? { transportCode } : {}),
      nextStep };
  } finally { release?.(); }
}
