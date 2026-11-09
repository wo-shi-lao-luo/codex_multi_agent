// Lead-inline responsibilities never impersonate a dispatched worker or bypass grants.
import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture, secret } from './helpers.mjs';

// Build a new explicit inline contract through the same public CLI used by a Lead.
async function inlineTask(f, id, extra = {}) {
  await f.ok('add', { task: { id, title: id, outcome: 'Verified inline result',
    sourceRefs: [`fixture/work#${id}`], acceptanceRefs: [`fixture/accept#${id}`],
    eligibleRoles: ['backend'], responsibilities: ['backend'], requiredSkills: [],
    allowLeadInline: true, workspaceId: 'main', scope: { read: [], write: [`src/${id}.mjs`] },
    resources: [], dependencies: [], ...extra } });
  await f.ok('approve', { taskId: id, taskRevision: 1 });
}

// SERIAL: complete a real inline claim, report, submit and accept with truthful Lead identity.
// Expected: explicit self grant required, assignment records Lead without invented host evidence.
test('EXECUTION.serial.leadInlineLifecycle', async t => {
  const f = await fixture(t);
  await f.ok('register', { worker: { id: 'lead', role: 'lead', mode: 'lead-inline',
    capabilities: ['write'] } });
  await inlineTask(f, 'inline');
  const claimToken = secret();
  const before = (await f.ok('inspect')).result;
  const denied = await f.raw('lead-inline-assign', { taskId: 'inline', taskRevision: 2,
    approvalRevision: 2, claimToken });
  assert.notEqual(denied.code, 0, 'Inline execution still requires explicit grant');
  assert.deepEqual((await f.ok('inspect')).result, before);
  await f.ok('grant', { workerId: 'lead', taskId: 'inline', approvalRevision: 2,
    executionMode: 'lead-inline', approvedResponsibilities: ['backend'] });
  const assigned = await f.ok('lead-inline-assign', { taskId: 'inline', taskRevision: 2,
    approvalRevision: 2, claimToken });
  const assignment = assigned.result.assignment;
  assert.equal(assignment.workerId, 'lead');
  assert.equal(assignment.executorKey, null, 'Unknown native host identity must stay unknown');
  const owner = { taskId: 'inline', assignmentId: assignment.id, claimToken };
  let task = (await f.ok('show', { taskId: 'inline' })).result.task;
  await f.ok('lead-inline-report', { ...owner, taskRevision: task.taskRevision,
    action: 'report', phase: 'implementation', progress: 'Lead performed bounded work' });
  task = (await f.ok('show', { taskId: 'inline' })).result.task;
  await f.ok('lead-inline-report', { ...owner, taskRevision: task.taskRevision,
    action: 'submit', writesStopped: true, processStopped: true,
    inputRevision: 'fixture-inline-v1', evidenceRefs: ['fixture/inline#self-check'] });
  task = (await f.ok('show', { taskId: 'inline' })).result.task;
  await f.ok('accept', { taskId: 'inline', taskRevision: task.taskRevision,
    gatesSatisfied: true, evidenceRefs: ['fixture/inline#consolidated'] });
  assert.equal((await f.ok('show', { taskId: 'inline' })).result.task.state, 'closed');
});

// IDENTITY: arbitrary registered IDs cannot opt into the Lead identity by labeling their mode.
// Expected: registration fails atomically, without granting a phantom inline worker authority.
test('EXECUTION.serial.forgedInlineIdentityRejected', async t => {
  const f = await fixture(t);
  const before = (await f.ok('inspect')).result;
  const denied = await f.raw('register', { worker: { id: 'fake-backend', role: 'backend',
    mode: 'lead-inline', capabilities: ['write'], workerToken: secret() } });
  assert.notEqual(denied.code, 0);
  assert.deepEqual((await f.ok('inspect')).result, before);
});

// IDENTITY-VALIDATION: malformed observation metadata must not silently become unknown proof.
// Expected: malformed principal and runtime fields reject registration atomically.
test('EXECUTION.serial.malformedIdentityObservationsRejected', async t => {
  const f = await fixture(t);
  for (const patch of [
    { principal: 0 }, { principal: [] },
    { runtimeIdentity: { model: 42 } }, { runtimeIdentity: { role: ['backend'] } },
  ]) {
    const before = (await f.ok('inspect')).result;
    const denied = await f.raw('register', { worker: { id: 'malformed', hostId: 'fixture',
      role: 'backend', mode: 'direct', capabilities: ['write'], workerToken: secret(), ...patch } });
    assert.notEqual(denied.code, 0);
    assert.deepEqual((await f.ok('inspect')).result, before);
  }
});

// READONLY: declared responsibility, Skills and labels cannot grant a read-only role write power.
// Expected: every readonly role rejects write capability escalation during registration.
test('EXECUTION.serial.readonlyRolesCannotEscalateWriteCapability', async t => {
  const f = await fixture(t);
  for (const role of ['team-reviewer', 'team-architect', 'team-ai-simulation-actor-basic',
    'team-ai-simulation-actor-advanced', 'team-explorer', 'team-delivery-checker']) {
    const before = (await f.ok('inspect')).result;
    const denied = await f.raw('register', { worker: { id: role, hostId: `fixture-${role}`,
      role, mode: 'direct', capabilities: ['read', 'write'], workerToken: secret() } });
    assert.notEqual(denied.code, 0, `${role} must remain read-only`);
    assert.deepEqual((await f.ok('inspect')).result, before);
  }
});

// AUTHORITY-LABELS: required Skills and responsibilities describe work, never confer capabilities.
// Expected: an otherwise eligible read-only backend worker cannot receive production write grant.
test('EXECUTION.serial.skillsAndResponsibilitiesDoNotGrantWrites', async t => {
  const f = await fixture(t);
  await f.ok('register', { worker: { id: 'readonly-backend', hostId: 'fixture-readonly',
    role: 'backend', mode: 'direct', capabilities: ['read'], workerToken: secret() } });
  await inlineTask(f, 'labeled', { responsibilities: ['backend'],
    requiredSkills: ['backend-engineering'] });
  const before = (await f.ok('inspect')).result;
  const denied = await f.raw('grant', { workerId: 'readonly-backend', taskId: 'labeled',
    approvalRevision: 2, approvedResponsibilities: ['backend'] });
  assert.notEqual(denied.code, 0);
  assert.deepEqual((await f.ok('inspect')).result, before);
});
