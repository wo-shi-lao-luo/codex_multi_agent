// Independent acceptance must bind a current verification result to a distinct real principal.
import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture, secret } from './helpers.mjs';
import { writeFile } from 'node:fs/promises';
import { join } from 'node:path';

// Create a production task requiring a concrete independent review, not a boolean assertion.
async function target(f, kind = 'independent-review') {
  await f.ok('add', { task: { id: 'writer', title: 'writer', outcome: 'Verified output',
    sourceRefs: ['fixture/work#writer'], acceptanceRefs: ['fixture/accept#writer'],
    eligibleRoles: ['backend'], scope: { read: [], write: ['src/writer.mjs'] },
    resources: [], dependencies: [],
    acceptancePolicy: { requiredChecks: [{ id: 'review', kind }] } } });
  await f.ok('approve', { taskId: 'writer', taskRevision: 1 });
}

// Submit using the actual authenticated worker claim and stopped declarations.
async function submit(f) {
  await f.grant('writer', 'writer');
  const claimToken = secret();
  const claimed = await f.ok('claim', { taskId: 'writer', taskRevision: 2,
    actorId: 'writer', workerToken: f.workers.writer, claimToken });
  const task = (await f.ok('show', { taskId: 'writer' })).result.task;
  await f.ok('submit', { taskId: 'writer', taskRevision: task.taskRevision,
    actorId: 'writer', workerToken: f.workers.writer,
    assignmentId: claimed.result.assignment.id, claimToken,
    writesStopped: true, processStopped: true, inputRevision: 'fixture-writer-v1',
    evidenceRefs: ['fixture/writer#self-tests'] });
  const submitted = (await f.ok('show', { taskId: 'writer' })).result.task;
  await f.ok('release', { taskId: 'writer', taskRevision: submitted.taskRevision,
    writesStopped: true, processStopped: true });
}

// EVIDENCE: an old gatesSatisfied boolean cannot satisfy an explicit independent gate.
// Expected: deny with no accepted result or persisted mutation, retaining submitted state.
test('EXECUTION.evidence.selfAttestationCannotFillIndependentGate', async t => {
  const f = await fixture(t);
  await f.worker('writer');
  await target(f);
  await submit(f);
  const task = (await f.ok('show', { taskId: 'writer' })).result.task;
  const before = (await f.ok('inspect')).result;
  const reply = await f.raw('accept', { taskId: 'writer', taskRevision: task.taskRevision,
    gatesSatisfied: true, evidenceRefs: ['fixture/writer#self-review'] });
  assert.notEqual(reply.code, 0, 'Self attestation cannot replace required independent evidence');
  assert.deepEqual((await f.ok('inspect')).result, before);
});

// Build and close a real verification task bound to the producer's frozen submission.
async function verify(f, id, agentId, kind = 'independent-review', extraDependencies = []) {
  const role = { 'independent-review': 'team-reviewer',
    'independent-evaluation': 'team-ai-tester', 'independent-test': 'team-tester' }[kind];
  const token = secret();
  f.workers[id] = token;
  await f.ok('register', { worker: { id, hostId: `fixture-${id}`, role,
    mode: 'lead-proxy', capabilities: ['read'], workerToken: token,
    principal: { hostId: 'fixture-host', agentId, evidenceRefs: ['fixture/host#declared'] } } });
  await f.ok('add', { task: { id, title: id, outcome: 'Independent reviewed result',
    sourceRefs: [`fixture/review#${id}`], acceptanceRefs: [`fixture/accept#${id}`],
    eligibleRoles: [role], scope: { read: ['src/writer.mjs'], write: [] },
    resources: [], dependencies: [{ taskId: 'writer', gate: 'frozen-submission' }, ...extraDependencies],
    verification: { kind, subjectTaskId: 'writer' } } });
  await f.ok('approve', { taskId: id, taskRevision: 1 });
  await f.grant(id, id);
  const claimToken = secret();
  const assignment = (await f.ok('assign', { taskId: id, taskRevision: 2,
    workerId: id, claimToken })).result.assignment;
  let task = (await f.ok('show', { taskId: id })).result.task;
  await f.ok('lead-proxy-report', { taskId: id, taskRevision: task.taskRevision,
    reportedByWorkerId: id, action: 'submit', claimToken, assignmentId: assignment.id,
    writesStopped: true, processStopped: true, inputRevision: 'fixture-review-v1',
    evidenceRefs: [`fixture/review#${id}`] });
  task = (await f.ok('show', { taskId: id })).result.task;
  await f.ok('accept', { taskId: id, taskRevision: task.taskRevision,
    gatesSatisfied: true, evidenceRefs: [`fixture/review#${id}-closed`] });
  const shown = (await f.ok('show', { taskId: id })).result;
  return { checkId: 'review', taskId: id,
    submissionId: shown.submissions.find(item => item.freezeValid).id };
}

// EVIDENCE-PRINCIPAL: alternate IDs sharing a principal are not an independent reviewer.
// Expected: same-principal evidence fails atomically; a genuinely distinct declared principal passes.
for (const kind of ['independent-review', 'independent-evaluation', 'independent-test']) {
  test(`EXECUTION.evidence.samePrincipalAliasDeniedDistinctPrincipalAccepted.${kind}`, async t => {
    const f = await fixture(t);
    const token = secret();
    f.workers.writer = token;
    await f.ok('register', { worker: { id: 'writer', hostId: 'fixture-writer', role: 'backend',
      mode: 'direct', capabilities: ['write'], workerToken: token,
      principal: { hostId: 'fixture-host', agentId: 'producer-agent',
        evidenceRefs: ['fixture/host#declared'] } } });
    await target(f, kind);
    await submit(f);
    const alias = await verify(f, 'alias-reviewer', 'producer-agent', kind);
    let task = (await f.ok('show', { taskId: 'writer' })).result.task;
    const before = (await f.ok('inspect')).result;
    const denied = await f.raw('accept', { taskId: 'writer', taskRevision: task.taskRevision,
      gatesSatisfied: true, evidenceRefs: ['fixture/accept#alias'], checkResults: [alias] });
    assert.notEqual(denied.code, 0, 'Different worker IDs cannot conceal the same executor');
    assert.deepEqual((await f.ok('inspect')).result, before);
    const independent = await verify(f, 'independent-reviewer', 'reviewer-agent', kind);
    task = (await f.ok('show', { taskId: 'writer' })).result.task;
    // A valid checker does not authorize malformed, duplicate or unknown check result entries.
    for (const checkResults of [
      [independent, independent],
      [{ ...independent, checkId: 'unknown-check' }],
      [{ checkId: 'review', taskId: independent.taskId }],
    ]) {
      const snapshot = (await f.ok('inspect')).result;
      const malformed = await f.raw('accept', { taskId: 'writer', taskRevision: task.taskRevision,
        gatesSatisfied: true, evidenceRefs: ['fixture/accept#malformed'], checkResults });
      assert.notEqual(malformed.code, 0);
      assert.deepEqual((await f.ok('inspect')).result, snapshot);
    }
    await f.ok('accept', { taskId: 'writer', taskRevision: task.taskRevision,
      gatesSatisfied: true, evidenceRefs: ['fixture/accept#independent'], checkResults: [independent] });
    assert.equal((await f.ok('show', { taskId: 'writer' })).result.task.state, 'closed');
    if (kind === 'independent-review') {
      // Closed verification unlocks subject acceptance and then a normal accepted-result consumer.
      await f.task('consumer', 'src/consumer.mjs', [{ taskId: 'writer', gate: 'accepted-result' }]);
      await f.grant('writer', 'consumer');
      const claimToken = secret();
      const owner = (await f.ok('claim', { taskId: 'consumer', taskRevision: 2,
        actorId: 'writer', workerToken: token, claimToken })).result.assignment;
      let consumer = (await f.ok('show', { taskId: 'consumer' })).result.task;
      await f.ok('submit', { taskId: 'consumer', taskRevision: consumer.taskRevision,
        actorId: 'writer', workerToken: token, claimToken, assignmentId: owner.id,
        writesStopped: true, processStopped: true, inputRevision: 'fixture-consumer-v1',
        evidenceRefs: ['fixture/consumer#pass'] });
      consumer = (await f.ok('show', { taskId: 'consumer' })).result.task;
      await f.ok('accept', { taskId: 'consumer', taskRevision: consumer.taskRevision,
        gatesSatisfied: true, evidenceRefs: ['fixture/consumer#accepted'] });
      task = (await f.ok('show', { taskId: 'writer' })).result.task;
      await f.ok('reopen', { taskId: 'writer', taskRevision: task.taskRevision,
        reason: 'New producer iteration invalidates consumed verification',
        evidenceRefs: ['fixture/producer#reopen'] });
      assert.equal((await f.ok('show', { taskId: independent.taskId })).result.task.resultValid, false);
      assert.equal((await f.ok('show', { taskId: 'consumer' })).result.task.resultValid, false);
    }
  });
}

// EVIDENCE-UNKNOWN: historical workers without principal proof remain usable, never independent.
// Expected: a known reviewer cannot turn an unknown producer identity into independence proof.
test('EXECUTION.evidence.unknownProducerCannotSatisfyIndependentGate', async t => {
  const f = await fixture(t);
  await f.worker('writer');
  await target(f);
  await submit(f);
  const independent = await verify(f, 'known-reviewer', 'known-reviewer-agent');
  const task = (await f.ok('show', { taskId: 'writer' })).result.task;
  const before = (await f.ok('inspect')).result;
  const denied = await f.raw('accept', { taskId: 'writer', taskRevision: task.taskRevision,
    gatesSatisfied: true, evidenceRefs: ['fixture/accept#unknown'], checkResults: [independent] });
  assert.notEqual(denied.code, 0);
  assert.deepEqual((await f.ok('inspect')).result, before);
});



// POLICY-KIND: unsupported independent-check kinds cannot be silently ignored at acceptance.
// Expected: invalid task policy is rejected atomically at the public contract boundary.
test('EXECUTION.evidence.unknownCheckKindRejected', async t => {
  const f = await fixture(t);
  const before = (await f.ok('inspect')).result;
  const denied = await f.raw('add', { task: { id: 'invalid-policy', title: 'invalid-policy',
    outcome: 'Must not create', sourceRefs: ['fixture/work#invalid'],
    acceptanceRefs: ['fixture/accept#invalid'], eligibleRoles: ['backend'],
    scope: { read: [], write: [] }, resources: [], dependencies: [],
    acceptancePolicy: { requiredChecks: [{ id: 'unknown', kind: 'independent-magic' }] } } });
  assert.notEqual(denied.code, 0);
  assert.deepEqual((await f.ok('inspect')).result, before);
});


// BE-02: accepted producer results consume independent checker evidence after checker closure.
// Expected: reopening the checker preserves producer history but invalidates its consumable result.
test('EXECUTION.evidence.reopenedCheckerInvalidatesAcceptedProducer', async t => {
  const f = await fixture(t);
  const token = secret();
  f.workers.writer = token;
  await f.ok('register', { worker: { id: 'writer', hostId: 'fixture-writer', role: 'backend',
    mode: 'direct', capabilities: ['write'], workerToken: token,
    principal: { hostId: 'fixture-host', agentId: 'producer-agent',
      evidenceRefs: ['fixture/host#declared'] } } });
  await target(f);
  await submit(f);
  const independent = await verify(f, 'checker', 'distinct-checker-agent');
  let writer = (await f.ok('show', { taskId: 'writer' })).result.task;
  const acceptance = { operationId: 'durable-independent-accept', taskId: 'writer',
    taskRevision: writer.taskRevision, gatesSatisfied: true,
    evidenceRefs: ['fixture/accept#durable'], checkResults: [independent] };
  await f.ok('accept', acceptance);
  await f.task('consumer', 'src/consumer.mjs', [{ taskId: 'writer', gate: 'accepted-result' }]);
  await f.grant('writer', 'consumer');
  assert.ok((await f.ok('ready')).result.tasks.some(item => item.id === 'consumer'));
  const checker = (await f.ok('show', { taskId: 'checker' })).result.task;
  await f.ok('reopen', { taskId: 'checker', taskRevision: checker.taskRevision,
    reason: 'Independent evidence has been reopened', evidenceRefs: ['fixture/checker#reopened'] });
  writer = (await f.ok('show', { taskId: 'writer' })).result.task;
  assert.equal(writer.state, 'closed', 'Historical producer completion remains recorded');
  assert.equal(writer.resultValid, false, 'Reopened checker invalidates accepted producer evidence');
  assert.equal(writer.needsReconcile, true);
  assert.ok(!(await f.ok('ready')).result.tasks.some(item => item.id === 'consumer'));
  const replay = await f.raw('accept', acceptance);
  assert.notEqual(replay.code, 0, 'Receipt replay must not revive obsolete checker proof');
});



// BE-02-LINEAGE: accepted checker evidence also consumes its other upstream sources.
// Expected: changed upstream native input blocks producer consumption without a graph cycle.
test('EXECUTION.evidence.checkerOtherUpstreamSourceDriftBlocksConsumption', async t => {
  const f = await fixture(t);
  const workerToken = secret();
  f.workers.writer = workerToken;
  await f.ok('register', { worker: { id: 'writer', hostId: 'fixture-writer', role: 'backend',
    mode: 'direct', capabilities: ['write'], workerToken,
    principal: { hostId: 'fixture-host', agentId: 'producer', evidenceRefs: ['fixture/host#declared'] } } });
  await writeFile(join(f.project, 'OTHER.md'), '# Stable upstream input\n');
  const source = { schemaVersion: 1, kind: 'work', path: 'OTHER.md', nativeTaskId: 'other-native' };
  await f.ok('add', { task: { id: 'other', title: 'other', outcome: 'Accepted checker input',
    sourceRefs: [source], acceptanceRefs: ['fixture/accept#other'], eligibleRoles: ['backend'],
    scope: { read: [], write: [] }, resources: [], dependencies: [] } });
  const observed = (await f.ok('source-check', { taskId: 'other' })).result.observation;
  const pinned = { ...source, expectedRevision: observed.checkedRefs[0].actualRevision };
  let other = (await f.ok('show', { taskId: 'other' })).result.task;
  await f.ok('amend', { taskId: other.id, taskRevision: other.taskRevision,
    expectedInputRevision: other.inputRevision, reason: 'Pin actual other input',
    patch: { sourceRefs: [pinned] } });
  other = (await f.ok('show', { taskId: 'other' })).result.task;
  await f.ok('approve', { taskId: other.id, taskRevision: other.taskRevision });
  other = (await f.ok('show', { taskId: 'other' })).result.task;
  await f.ok('reconcile', { taskId: other.id, taskRevision: other.taskRevision,
    expectedInputRevision: other.inputRevision, decision: 'confirm', reason: 'Confirm other input',
    sourceObservation: { available: true, revision: pinned.expectedRevision,
      evidenceRefs: ['fixture/source#other'] } });
  await f.grant('writer', 'other');
  other = (await f.ok('show', { taskId: 'other' })).result.task;
  const claimToken = secret();
  const assignment = (await f.ok('claim', { taskId: other.id, taskRevision: other.taskRevision,
    actorId: 'writer', workerToken, claimToken })).result.assignment;
  other = (await f.ok('show', { taskId: 'other' })).result.task;
  await f.ok('submit', { taskId: other.id, taskRevision: other.taskRevision,
    actorId: 'writer', workerToken, assignmentId: assignment.id, claimToken,
    writesStopped: true, processStopped: true, inputRevision: 'fixture-other-output',
    evidenceRefs: ['fixture/other#pass'] });
  other = (await f.ok('show', { taskId: 'other' })).result.task;
  await f.ok('accept', { taskId: other.id, taskRevision: other.taskRevision,
    gatesSatisfied: true, evidenceRefs: ['fixture/other#accepted'] });
  await target(f);
  await submit(f);
  const check = await verify(f, 'checker', 'independent-checker', 'independent-review',
    [{ taskId: 'other', gate: 'accepted-result' }]);
  const writer = (await f.ok('show', { taskId: 'writer' })).result.task;
  await f.ok('accept', { taskId: writer.id, taskRevision: writer.taskRevision,
    gatesSatisfied: true, checkResults: [check], evidenceRefs: ['fixture/writer#accepted'] });
  await f.task('consumer', 'src/consumer.mjs', [{ taskId: 'writer', gate: 'accepted-result' }]);
  await f.grant('writer', 'consumer');
  assert.ok((await f.ok('ready')).result.tasks.some(item => item.id === 'consumer'));
  await writeFile(join(f.project, 'OTHER.md'), '# Changed upstream input\n');
  assert.ok(!(await f.ok('ready')).result.tasks.some(item => item.id === 'consumer'),
    'Checker other-upstream source drift must invalidate consumption of accepted producer');
});
