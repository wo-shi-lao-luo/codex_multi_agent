#!/usr/bin/env node
/** Finite activation entry; the owned read-only service has a separate lifetime. */
import { activate } from '../activation/orchestrator.mjs';
import { prepareRequest } from '../activation/prepare.mjs';

let reply;
try {
  const args = process.argv.slice(2);
  if (args.length === 1 && args[0] === '--help') {
    process.stdout.write(`${JSON.stringify({ schemaVersion: 1, operation: 'activation-help',
      requiredFlags: ['--project-root', '--stdin'],
      actions: ['activate', 'resume', 'record-open-result', 'prepare-request'],
      sessionProfileFields: ['hostId', 'mainSessionId', 'projectId', 'projectName', 'sessionName'],
      scopeShape: { read: ['relative-path'], write: ['relative-path'] },
      preparation: 'prepare-request needs approved task and fresh native sessionProfile; creates one private request file with caller-owned random credentials. No database or service is created.',
      requiredFields: ['action', 'actorId', 'sessionProfile', 'leadToken', 'claimToken',
        'serviceControlToken'],
      executionFields: ['executionApproved:true', 'task.id', 'task.title', 'task.outcome',
        'task.sourceRefs', 'task.acceptanceRefs'],
      optionalFields: ['task.scope', 'task.responsibilities', 'task.requiredSkills',
        'phase', 'progress', 'nextCheckpoint', 'presentationOutcome'],
      presentationOutcomes: ['queued', 'opened', 'link-only', 'unknown'],
      notes: 'Tokens remain caller-held and must be reused. Only first activation returns a URL. '
        + 'Record the observed host outcome separately; resume never reopens the panel.' })}\n`);
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
  reply = request.action === 'prepare-request' ? prepareRequest(args[1], request)
    : await activate(args[1], request);
} catch (error) {
  reply = { state: 'activation-pending', reasonCode: error.code ?? 'INVALID_INPUT',
    nextStep: 'Inspect the activation prerequisites; no automatic reset or installation.' };
}
process.stdout.write(`${JSON.stringify({ schemaVersion: 1, operation: 'activation',
  ok: true, result: reply })}\n`);
