#!/usr/bin/env node
/** Finite activation entry; the owned read-only service has a separate lifetime. */
import { activate } from '../activation/orchestrator.mjs';
import { prepareRequest } from '../activation/prepare.mjs';
import { prepareNextTask, readPreparedTask } from '../activation/next-task.mjs';
import { sharedHome } from '../activation/shared-registry.mjs';

let reply;
try {
  const args = process.argv.slice(2);
  if (args.length === 1 && args[0] === '--help') {
    process.stdout.write(`${JSON.stringify({ schemaVersion: 1, operation: 'activation-help',
      requiredFlags: ['--project-root', '--stdin'],
      actions: ['activate', 'resume', 'recover-service', 'reopen-service', 'migrate-service', 'record-open-result', 'prepare-request', 'prepare-next-task'],
      nextTask: 'prepare-next-task or nextTask on an activate request explicitly selects approved new work with retained Board credentials; wrapper -TaskPath supplies the public spec.',
      presentationOnly: { action:'reopen-service', requiredFields:['servicePresentation.expectedServiceId','servicePresentation.evidenceRefs'], result:'presentation-only; taskExecution:not-resumed' },
      sharedService: { default: true, perBoardRoute: '/boards/<sessionKey>/',
        serviceMigration: { expectedServiceId: 'retained legacy service ID', evidenceRefs: ['authorized migration'],
          confirmedStopped: 'required only if the legacy endpoint is already refused' } },
      serviceRecovery: { expectedServiceId: 'retained service ID', confirmedStopped: true,
        evidenceRefs: ['local host listener and runner proof reference'] },
      sessionProfileFields: ['hostId', 'mainSessionId', 'projectId', 'projectName', 'sessionName'],
      scopeShape: { read: ['relative-path'], write: ['relative-path'] },
      preparation: 'prepare-request needs approved task and fresh native sessionProfile; creates one private request file with caller-owned random credentials. No database or service is created.',
      requiredFields: ['action', 'actorId', 'sessionProfile', 'leadToken',
        'serviceControlToken'],
      executionFields: ['claimToken', 'executionApproved:true', 'task.id', 'task.title', 'task.outcome',
        'task.sourceRefs', 'task.acceptanceRefs'],
      serviceOnlyRecovery: { requiredFields: ['serviceRecovery'], taskContractRequired: false,
        claimTokenRequired: false, executionApprovalRequired: false,
        result: { state: 'enabled', activationScope: 'service-only', taskExecution: 'not-resumed' } },
      optionalFields: ['task.scope', 'task.responsibilities', 'task.requiredSkills',
        'phase', 'progress', 'nextCheckpoint', 'presentationOutcome', 'presentationAttemptId', 'leadPrincipal'],
      leadPrincipalShape: { hostId: 'observed host matching sessionProfile.hostId',
        agentId: 'observed main session matching sessionProfile.mainSessionId',
        evidenceRefs: ['reference to actual native observation'] },
      presentationOutcomes: ['queued', 'opened', 'link-only', 'unknown'],
      notes: 'Tokens remain caller-held and must be reused. recover-service authenticates an existing Board '
        + 'without a task, claimToken or executionApproved; normal activate/resume retain execution fields. '
        + 'Service-only recovery never authorizes task execution. First activation or verified service '
        + 'recovery (explicit or automatic) may return the replacement service first URL. '
        + 'Automatic recovery requires exact refusal and an OS-confirmed absent retained runner PID. '
        + 'Record the observed host outcome separately; healthy resume never reopens the panel.' })}\n`);
    process.exit(0);
  }
  if (args.length !== 3 || args[0] !== '--project-root' || args[2] !== '--stdin') {
    throw Object.assign(new Error('Explicit root and stdin are required.'), { code: 'INVALID_INPUT' });
  }
  const chunks = [];
  let inputBytes = 0;
  for await (const chunk of process.stdin) {
    inputBytes += chunk.length;
    if (inputBytes > 262144) throw new Error('Input too large.');
    chunks.push(chunk);
  }
  // Decode only after concatenation: a UTF-8 character may span stdin chunks.
  const request = JSON.parse(Buffer.concat(chunks).toString('utf8'));
  if (request.action === 'prepare-request') reply=prepareRequest(args[1],request);
  else if (request.action === 'prepare-next-task' || Object.hasOwn(request,'nextTask')) {
    if (!['prepare-next-task','activate','resume'].includes(request.action)) throw Object.assign(Error(),{code:'NEXT_TASK_INVALID'});
    reply=await prepareNextTask(args[1],request);
    if (reply.state==='prepared' && request.action!=='prepare-next-task') {
      const preparedPath=reply.requestPath;
      const prepared=readPreparedTask(preparedPath,reply.requestDigest);
      reply=await activate(args[1],prepared,{serviceMode:'shared',sharedRuntimeHome:process.env.CODEX_BOARD_SERVICE_HOME??sharedHome()});
      reply.requestPath=preparedPath;
    }
  } else reply=await activate(args[1], request, { serviceMode: 'shared',
      sharedRuntimeHome: process.env.CODEX_BOARD_SERVICE_HOME ?? sharedHome() });
} catch (error) {
  reply = { state: 'activation-pending', taskExecution:'not-resumed', reasonCode: error.code ?? 'INVALID_INPUT',
    nextStep: 'Inspect the activation prerequisites; no automatic reset or installation.' };
}
if (reply.state==='activation-pending') reply.taskExecution='not-resumed';
process.stdout.write(`${JSON.stringify({ schemaVersion: 1, operation: 'activation',
  ok: true, result: reply })}\n`);
// A parseable protocol envelope does not mean execution was authorized.
if (reply.state === 'activation-pending') process.exitCode=2;
