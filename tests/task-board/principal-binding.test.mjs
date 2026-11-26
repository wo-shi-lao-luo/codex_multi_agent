// Forward-only identity repair preserves historical evidence and requires a new execution.
import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture, secret, invoke } from './helpers.mjs';
import { requestIssues } from '../../packages/task-board/src/activation/request.mjs';
import { sessionLocation } from '../../packages/task-board/src/domain/session.mjs';
import { activate } from '../../packages/task-board/src/activation/orchestrator.mjs';
import fs from 'node:fs';
import path from 'node:path';

const principal = { hostId: 'fixture-host', agentId: 'actual-lead', evidenceRefs: ['fixture/native#lead'] };
const bind = async (f, extra = {}) => f.raw('bind-lead-principal', {
  expectedBoardRevision: (await f.ok('inspect')).boardRevision, principal, ...extra });

test('IDENTITY.forwardBindingPreservesOldFreezeAndNeedsFreshIndependentCheck', async t => {
  const f = await fixture(t);
  await f.ok('register', { worker: { id: 'lead', role: 'lead', mode: 'lead-inline', capabilities: ['write'] } });
  await f.ok('sync-task', { action: 'prepare', contractApproved: true, task: {
    id: 'producer', title: 'Producer', outcome: 'Verified output', sourceRefs: ['fixture/work'],
    acceptanceRefs: ['fixture/accept'], eligibleRoles: ['backend'], allowLeadInline: true,
    scope: { read: [], write: ['src/output'] },
    acceptancePolicy: { requiredChecks: [{ id: 'review', kind: 'independent-review' }] } } });
  const claimToken = secret();
  const allocated = await f.ok('sync-task', { operationId: 'old-allocation', action: 'assign',
    workerId: 'lead', taskId: 'producer', taskRevision: 2, approvalRevision: 2, claimToken });
  async function freeze(assignment, token) {
    const task = (await f.ok('show', { taskId: 'producer' })).result.task;
    await f.ok('lead-inline-report', { taskId: task.id, taskRevision: task.taskRevision,
      assignmentId: assignment.id, claimToken: token, action: 'submit', writesStopped: true,
      processStopped: true, inputRevision: 'sha256:unchanged-source', evidenceRefs: ['fixture/source#frozen'] });
  }
  await freeze(allocated.result.assignment, claimToken);
  const old = (await f.ok('show', { taskId: 'producer' })).result;
  assert.equal(old.submissions[0].actualExecutor.executorKey, null);
  const before = (await f.ok('inspect')).result;
  const operationId = 'bind-actual-lead';
  const expectedBoardRevision = (await f.ok('inspect')).boardRevision;
  const binding = await f.ok('bind-lead-principal', { operationId, expectedBoardRevision, principal });
  assert.deepEqual(await f.ok('bind-lead-principal', { operationId, expectedBoardRevision, principal }), binding);
  let shown = (await f.ok('show', { taskId: 'producer' })).result;
  assert.deepEqual(shown.submissions, old.submissions, 'Do not stamp principal into the old freeze');
  assert.deepEqual(shown.assignment, old.assignment, 'Do not rewrite/release the old allocation');
  assert.deepEqual((await f.ok('inspect')).result.reservations, before.reservations);
  const replay = await f.raw('sync-task', { operationId: 'old-allocation', action: 'assign',
    workerId: 'lead', taskId: 'producer', taskRevision: 2, approvalRevision: 2, claimToken });
  assert.equal(replay.reply.error.code, 'STALE_ASSIGNMENT');
  const nextToken = secret();
  const transferred = await f.ok('transfer', { taskId: 'producer', taskRevision: shown.task.taskRevision,
    reason: 'New observed identity requires a fresh execution', newWorkerId: 'lead', newClaimToken: nextToken,
    expectedApprovalRevision: 2, writesStopped: true, processStopped: true, handoffRefs: ['fixture/native#binding'] });
  assert.ok(transferred.result.assignment.actualExecutor.executorKey);
  await freeze(transferred.result.assignment, nextToken);
  shown = (await f.ok('show', { taskId: 'producer' })).result;
  assert.equal(shown.submissions.find(s => s.freezeRevision === 1).actualExecutor.executorKey, null);
  assert.ok(shown.submissions.find(s => s.freezeValid).actualExecutor.executorKey);
  await f.ok('release', { taskId: 'producer', taskRevision: shown.task.taskRevision,
    writesStopped: true, processStopped: true });
  // Self-attestation still cannot replace a genuinely independent checker.
  shown = (await f.ok('show', { taskId: 'producer' })).result;
  assert.notEqual((await f.raw('accept', { taskId: 'producer', taskRevision: shown.task.taskRevision,
    gatesSatisfied: true, evidenceRefs: ['fixture/self-check'] })).code, 0);
  const manualWithoutReview = await f.raw('request-manual-acceptance', {
    taskId: 'producer', taskRevision: shown.task.taskRevision, evidenceRefs: ['fixture/self-check'],
  });
  assert.equal(manualWithoutReview.reply.error.code, 'DEPENDENCY_BLOCKED',
    'Moving a task to manual confirmation cannot replace a required independent review.');
  assert.equal((await f.ok('show', { taskId: 'producer' })).result.task.taskRevision, shown.task.taskRevision);
  await f.ok('register', { worker: { id: 'reviewer', role: 'team-reviewer', mode: 'lead-proxy',
    capabilities: ['read'], workerToken: secret(), principal: { ...principal, agentId: 'actual-reviewer' } } });
  await f.ok('sync-task', { action: 'prepare', contractApproved: true, task: {
    id: 'check', title: 'Independent check', outcome: 'Check current frozen output', sourceRefs: ['fixture/review'],
    acceptanceRefs: ['fixture/check'], eligibleRoles: ['team-reviewer'], scope: { read: ['src/output'], write: [] },
    dependencies: [{ taskId: 'producer', gate: 'frozen-submission' }],
    verification: { kind: 'independent-review', subjectTaskId: 'producer' } } });
  const reviewToken = secret();
  const review = await f.ok('sync-task', { action: 'assign', workerId: 'reviewer', taskId: 'check',
    taskRevision: 2, approvalRevision: 2, claimToken: reviewToken });
  await f.ok('lead-proxy-report', { taskId: 'check', taskRevision: 3,
    reportedByWorkerId: 'reviewer', assignmentId: review.result.assignment.id, claimToken: reviewToken,
    action: 'submit', writesStopped: true, processStopped: true,
    inputRevision: 'sha256:reviewed-current-freeze', evidenceRefs: ['fixture/review#current'] });
  await f.ok('accept', { taskId: 'check', taskRevision: 4, gatesSatisfied: true, evidenceRefs: ['fixture/review#closed'] });
  const check = (await f.ok('show', { taskId: 'check' })).result;
  await f.ok('accept', { taskId: 'producer', taskRevision: shown.task.taskRevision, gatesSatisfied: true,
    evidenceRefs: ['fixture/accepted'], checkResults: [{ checkId: 'review', taskId: 'check',
      submissionId: check.submissions.find(s => s.freezeValid).id }] });
  assert.equal((await f.ok('show', { taskId: 'producer' })).result.task.state, 'closed');
});

test('IDENTITY.bindDeniesStaleCasMalformedReplacementAndBadCredentials', async t => {
  const f = await fixture(t);
  await f.ok('register', { worker: { id: 'lead', role: 'lead', mode: 'lead-inline', capabilities: ['write'] } });
  for (const extra of [{ expectedBoardRevision: 0 }, { principal: null },
    { principal: { hostId: 'fixture', agentId: 'agent', evidenceRefs: [] } }, { leadToken: secret() }]) {
    const before = (await f.ok('inspect')).result;
    assert.notEqual((await bind(f, extra)).code, 0);
    assert.deepEqual((await f.ok('inspect')).result, before);
  }
  assert.equal((await bind(f)).code, 0);
  const before = (await f.ok('inspect')).result;
  assert.notEqual((await bind(f, { principal: { ...principal, agentId: 'replacement' } })).code, 0);
  assert.deepEqual((await f.ok('inspect')).result, before);
});

test('IDENTITY.activationRequiresExplicitConsistentObservedPrincipal', () => {
  const request = { action: 'prepare-request', actorId: 'lead', executionApproved: true,
    sessionProfile: { hostId: 'fixture-host', mainSessionId: 'actual-lead', projectId: 'project',
      projectName: 'Project', sessionName: 'Main' },
    task: { id: 't', title: 'T', outcome: 'O', sourceRefs: ['work'], acceptanceRefs: ['accept'] } };
  assert.deepEqual(requestIssues({ ...request, leadPrincipal: principal }, { prepare: true }).invalidFields, []);
  assert.ok(requestIssues({ ...request, leadPrincipal: { ...principal, agentId: 'other' } },
    { prepare: true }).invalidFields.includes('leadPrincipal'));
  assert.ok(requestIssues({ ...request, leadPrincipal: { ...principal, evidenceRefs: [] } },
    { prepare: true }).invalidFields.includes('leadPrincipal'));
});

test('IDENTITY.boundSessionRejectsOtherHostAndStaleGeneration', async t => {
  const f = await fixture(t);
  const sessionProfile = { hostId: principal.hostId, mainSessionId: principal.agentId,
    projectId: 'fixture-project', projectName: 'Project', sessionName: 'Main' };
  const { boardPath, sessionKey } = sessionLocation(sessionProfile);
  const raw = (operation, data = {}) => invoke(f.project, boardPath, operation,
    { actorId: 'lead', leadToken: f.leadToken, operationId: secret(), ...data }, { sessionKey });
  const initialized = await raw('initialize', { sessionProfile });
  assert.equal(initialized.code, 0);
  const generation = initialized.reply.generation;
  const registered = await raw('register', { generation,
    worker: { id: 'lead', role: 'lead', mode: 'lead-inline', capabilities: ['write'] } });
  assert.equal(registered.code, 0);
  const expectedBoardRevision = registered.reply.boardRevision;
  const before = await raw('inspect');
  for (const patch of [{ principal: { ...principal, hostId: 'other-host' } },
    { principal: { ...principal, agentId: 'other-agent' } }, { generation: 'obsolete' }]) {
    assert.notEqual((await raw('bind-lead-principal', { generation, expectedBoardRevision, principal, ...patch })).code, 0);
    assert.deepEqual((await raw('inspect')).reply.result, before.reply.result);
  }
  assert.equal((await raw('bind-lead-principal', { generation, expectedBoardRevision, principal })).code, 0);
});

test('IDENTITY.activationRejectsCredentialsInPublicPrincipalBeforeWrites', async t => {
  const f = await fixture(t);
  const request = { action: 'activate', actorId: 'lead', executionApproved: true,
    leadToken: secret(), claimToken: secret(), serviceControlToken: secret(),
    sessionProfile: { hostId: principal.hostId, mainSessionId: principal.agentId,
      projectId: 'fixture-project', projectName: 'Project', sessionName: 'Main' },
    task: { id: 'new-task', title: 'Task', outcome: 'Output', sourceRefs: ['fixture/work'],
      acceptanceRefs: ['fixture/accept'], scope: { read: [], write: [] } } };
  const { boardPath, sessionKey } = sessionLocation(request.sessionProfile);
  const journalPath = path.join(f.project, boardPath, 'activation.json');
  try {
    for (const field of ['leadToken', 'claimToken', 'serviceControlToken']) {
      const result = await activate(f.project, { ...request,
        leadPrincipal: { ...principal, evidenceRefs: [`fixture/ref#${request[field]}`] } });
      assert.equal(result.reasonCode, 'CREDENTIAL_IN_PUBLIC_CONTEXT', field);
      assert.equal(fs.existsSync(path.join(f.project, boardPath, 'board.sqlite')), false,
        'Reject public credentials before creating a Board or worker');
    }
  } finally {
    // A pre-fix Red can reach service startup; stop only this fixture's retained exact identity.
    if (fs.existsSync(journalPath)) {
      const { service } = JSON.parse(fs.readFileSync(journalPath, 'utf8'));
      if (service) {
        const stopped = await invoke(f.project, boardPath, 'service-stop',
          { ...service, serviceControlToken: request.serviceControlToken }, { sessionKey });
        assert.equal(stopped.code, 0);
      }
    }
  }
});
