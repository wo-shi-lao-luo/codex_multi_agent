// P2 contract groups exercise real CLI authorizations and bounded question/dispatch flows.
import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture, secret, assertRedacted, invoke } from './helpers.mjs';

// Read current CAS while retaining caller-owned assignment credentials independently.
async function current(f, taskId) {
  return (await f.ok('show', { taskId })).result.task;
}

// Create a true direct current assignment; no execution/authorization bypass flags exist.
async function executing(f, taskId = 'work') {
  await f.worker('w1');
  await f.task(taskId);
  await f.grant('w1', taskId);
  const claimToken = secret();
  const result = await f.ok('claim', { actorId: 'w1', workerToken: f.workers.w1,
    taskId, taskRevision: (await current(f, taskId)).taskRevision, claimToken });
  return { actorId: 'w1', workerToken: f.workers.w1, taskId,
    assignmentId: result.result.assignment.id, claimToken };
}

// A compact current-task question is the only supplied context; no unrelated task data is injected.
async function ask(f, owner, extra = {}) {
  return f.ok('ask', { ...owner, taskRevision: (await current(f, owner.taskId)).taskRevision,
    step: 'Choose current output format', question: 'Which format applies to this task?',
    checkedRefs: ['fixture/current-contract'], options: ['JSON', 'Text'],
    recommendation: 'JSON', impact: 'Current output is blocked', blocking: true, ...extra });
}

// Group1: readonly proxy uses Lead transport, exact current worker attribution and no direct writes.
test('P2.proxyAttribution', async t => {
  const f = await fixture(t);
  const workerToken = secret();
  await f.ok('register', { worker: { id: 'proxy', hostId: 'fixture-readonly-host', role: 'reviewer',
    mode: 'lead-proxy', capabilities: ['read'], workerToken } });
  await f.ok('add', { task: { id: 'review', title: 'Review', outcome: 'Bounded findings',
    sourceRefs: ['opaque:review-input'], acceptanceRefs: ['opaque:review-acceptance'],
    eligibleRoles: ['reviewer'], scope: { read: ['src/'], write: [] },
    resources: [], dependencies: [] } });
  await f.ok('approve', { taskId: 'review', taskRevision: 1 });
  await f.grant('proxy', 'review');
  const claimToken = secret();
  const assigned = await f.ok('assign', { taskId: 'review', taskRevision: 2,
    workerId: 'proxy', claimToken });
  assert.equal(assigned.result.assignment.workerId, 'proxy');
  const payload = { taskId: 'review', assignmentId: assigned.result.assignment.id,
    taskRevision: assigned.result.task.taskRevision, claimToken,
    reportedByWorkerId: 'proxy', action: 'report', phase: 'review', progress: 'Read current input' };
  const wrong = await f.raw('lead-proxy-report', { ...payload, reportedByWorkerId: 'other' });
  assert.equal(wrong.code, 2);
  const impersonation = await f.raw('report', { ...payload, actorId: 'proxy', workerToken });
  assert.equal(impersonation.reply.error.code, 'UNAUTHORIZED');
  await f.ok('lead-proxy-report', payload);
  assert.equal((await current(f, 'review')).progress, 'Read current input');
  const history = await f.ok('show', { taskId: 'review', history: true });
  const attributed = history.result.history.items.find(item =>
    item.data.reportedByWorkerId === 'proxy');
  assert.ok(attributed, 'Proxy report must preserve the real reporter in audit history');
  assert.equal(attributed.data.actorId, 'lead');
  assert.equal(attributed.data.proxyWriterId, 'lead');
  assert.equal(attributed.data.reportedByRole, 'reviewer');
  assert.equal(attributed.data.reportedByHostId, 'fixture-readonly-host');
  const snapshot = await f.ok('inspect');
  assertRedacted(snapshot, [f.leadToken, workerToken, claimToken]);
});

// Group2: one nonterminal scoped question, stable compact notification latch and retained holds.
test('P2.questionScopeAndLatch', async t => {
  const f = await fixture(t);
  const owner = await executing(f);
  const first = await ask(f, owner);
  assert.equal(first.result.deduplicated, false);
  assert.ok(first.result.firstHint.batchId);
  const duplicate = await ask(f, owner);
  assert.equal(duplicate.result.deduplicated, true);
  assert.equal(duplicate.result.question.id, first.result.question.id);
  assert.ok(!duplicate.result.firstHint);
  const denied = await f.raw('ask', { ...owner,
    taskRevision: (await current(f, 'work')).taskRevision,
    step: 'Different pending decision', question: 'May a second question bypass the first?',
    checkedRefs: [], impact: 'No bypass', blocking: true });
  assert.equal(denied.reply.error.code, 'QUESTION_PENDING');
  const before = await f.ok('inspect');
  const inbox1 = await f.ok('inbox', { limit: 10 });
  const inbox2 = await f.ok('inbox', { limit: 10 });
  assert.deepEqual(inbox2.result, inbox1.result);
  assert.equal(inbox1.result.items.length, 1);
  assert.deepEqual((await f.ok('inspect')).result, before.result,
    'Inbox reads never change durable notification state');
  assert.ok(before.result.reservations.some(item => item.active &&
    item.assignmentId === owner.assignmentId));
  assert.equal((await current(f, 'work')).state, 'blocked');
  await f.ok('ack-inbox', { notificationBatchId: first.result.firstHint.batchId });
});

// Group3: newest answer binding only, no implicit resume or expanded authority at answer/ack.
test('P2.answerRevisionAndResume', async t => {
  const f = await fixture(t);
  const owner = await executing(f);
  const asked = await ask(f, owner);
  const question = asked.result.question;
  const first = await f.ok('answer', { questionId: question.id,
    questionRevision: question.questionRevision, answerRevision: question.answerRevision,
    answer: { text: 'Use JSON', decision: 'clarify', evidenceRefs: ['fixture/decision#first'] } });
  const second = await f.ok('answer', { questionId: question.id,
    questionRevision: first.result.question.questionRevision,
    answerRevision: first.result.question.answerRevision,
    answer: { text: 'Approval still required', decision: 'needs-approval',
      evidenceRefs: ['fixture/decision#second'] } });
  const stale = await f.raw('ack-answer', { ...owner, questionId: question.id,
    questionRevision: first.result.question.questionRevision,
    answerRevision: first.result.question.answerRevision, applied: true,
    evidenceRefs: ['fixture/application#obsolete'] });
  assert.equal(stale.code, 2);
  const latest = second.result.question;
  await f.ok('ack-answer', { ...owner, questionId: question.id,
    questionRevision: latest.questionRevision, answerRevision: latest.answerRevision,
    applied: true, evidenceRefs: ['fixture/application#latest'] });
  assert.equal((await current(f, 'work')).state, 'blocked');
  assert.equal((await current(f, 'work')).approvalRevision, 2,
    'Answer application must not create a new approval revision');
  const deniedResume = await f.raw('report', { ...owner,
    taskRevision: (await current(f, 'work')).taskRevision, phase: 'running',
    progress: 'Acknowledgement alone must not authorize pending approval' });
  assert.equal(deniedResume.code, 2,
    'needs-approval remains blocking after acknowledgement until explicit Lead resolution');
  assert.equal((await current(f, 'work')).state, 'blocked');
});

// Group4: uncertainty creates no worker/owner; compact worker pages expose only current grants.
test('P2.dispatchAndBoundedViews', async t => {
  const f = await fixture(t);
  await f.worker('w1');
  await f.worker('w2');
  await f.task('mine-a');
  await f.task('mine-b');
  await f.task('private-other');
  await f.grant('w1', 'mine-a');
  await f.grant('w1', 'mine-b');
  await f.grant('w2', 'private-other');
  const before = (await f.ok('inspect')).result;
  await f.ok('record-dispatch', { attemptId: 'uncertain-attempt', status: 'unknown', role: 'backend',
    capacityObservation: { available: null, evidenceRefs: ['fixture/host#unknown'] },
    evidenceRefs: ['fixture/dispatch#unknown'] });
  const after = (await f.ok('inspect')).result;
  assert.equal(after.workers.length, before.workers.length);
  assert.equal(after.assignments.length, before.assignments.length);
  await f.ok('record-dispatch', { attemptId: 'uncertain-attempt', status: 'failed', role: 'backend',
    capacityObservation: { available: false, evidenceRefs: ['fixture/host#resolved'] },
    evidenceRefs: ['fixture/dispatch#resolved'] });
  const input = { actorId: 'w1', workerToken: f.workers.w1, limit: 1 };
  const page = await f.ok('ready', input);
  assert.equal(page.result.tasks.length, 1);
  assert.equal(page.result.hasMore, true);
  assert.ok(['mine-a', 'mine-b'].includes(page.result.tasks[0].id));
  assert.ok(!JSON.stringify(page.result).includes('private-other'));
  const status = await f.ok('status', input);
  assert.ok(status.result.tasks.length <= 1);
  assert.ok(!JSON.stringify(status.result).includes('private-other'));
  await f.task('revision-change');
  const stale = await f.raw('ready', { ...input, cursor: page.result.cursor });
  assert.equal(stale.reply.error.code, 'CONFLICT');
});





// Global diagnostic inspect is Lead-only; anonymous/worker callers use scoped summaries instead.
test('P2.review.inspectRequiresLead', async t => {
  const f = await fixture(t);
  await f.worker('w1');
  await f.task('unrelated-private-task');
  const anonymous = await invoke(f.project, f.board, 'inspect', {});
  const worker = await invoke(f.project, f.board, 'inspect', {
    actorId: 'w1', workerToken: f.workers.w1, generation: f.generation });
  const lead = await f.ok('inspect');
  assert.equal(lead.ok, true);
  for (const response of [anonymous, worker]) {
    assert.equal(response.code, 2, JSON.stringify(response.reply));
    assert.equal(response.reply.error.code, 'UNAUTHORIZED');
    assert.ok(!JSON.stringify(response.reply).includes('unrelated-private-task'));
  }
});
