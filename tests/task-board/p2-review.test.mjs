// P2 review round1 regressions use real domain operations and generic detached repositories.
import test from 'node:test';
import assert from 'node:assert/strict';
import { domainFixture } from './domain-fixture.mjs';

function arrange(blocking = false) {
  const f = domainFixture();
  f.add('writer');
  const owner = f.claim('writer');
  const question = f.run('ask', { ...owner.owner, step: 'Current requirement',
    question: 'Does the current scope need an explicit change?', checkedRefs: ['fixture/current'],
    impact: 'Current evidence applicability', blocking }).question;
  const answer = decision => {
    const current = f.tx.questions.get(question.id);
    return f.run('answer', { questionId: question.id, questionRevision: current.questionRevision,
      answerRevision: current.answerRevision, answer: { text: decision, decision,
        evidenceRefs: ['fixture/decision'], authorizationEvidenceRefs: ['fixture/authorization'] } });
  };
  return { f, owner, question, answer };
}

// Scope-change remains an outstanding contract obligation across intermediate answer revisions.
test('P2.review.scopeObligationCannotDowngrade', () => {
  const { f, answer } = arrange(true);
  answer('scope-change');
  answer('needs-approval');
  const before = f.tx.tasks.get('writer');
  assert.throws(() => answer('clarify'), error => error.code === 'UNAUTHORIZED');
  assert.equal(f.tx.tasks.get('writer').inputRevision, before.inputRevision);
  assert.ok(f.tx.tasks.get('writer').questionHold);
});

// A late answer cannot re-enter execution from submitted or silently preserve consumed stale evidence.
test('P2.review.lateAnswerPreservesSubmittedLifecycle', () => {
  const { f, owner, answer } = arrange(false);
  f.submit(owner.owner);
  f.add('review', [{ taskId: 'writer', gate: 'frozen-submission' }]);
  const review = f.claim('review');
  f.submit(review.owner);
  f.run('accept', { taskId: 'review', gatesSatisfied: true, evidenceRefs: ['fixture/review#pass'] });
  answer('needs-approval');
  assert.equal(f.tx.tasks.get('writer').state, 'submitted',
    'Answers do not implement Return or reopen writer execution');
});

// Canceled work is historical; answering its old question must never resurrect blocked execution.
test('P2.review.lateAnswerCannotResurrectCanceled', () => {
  const { f, answer } = arrange(false);
  f.run('cancel', { taskId: 'writer' });
  try { answer('needs-approval'); }
  catch (error) { assert.ok(['STALE_ASSIGNMENT', 'CONFLICT'].includes(error.code)); }
  assert.equal(f.tx.tasks.get('writer').state, 'canceled');
});

// Preauthorization precedes dependency readiness; execution is the point that enforces ready inputs.
test('P2.review.grantBeforeDependencyReady', () => {
  const f = domainFixture();
  f.add('upstream');
  f.add('future', [{ taskId: 'upstream', gate: 'accepted-result' }]);
  assert.doesNotThrow(() => f.run('grant', { taskId: 'future', workerId: 'first-worker',
    approvalRevision: f.tx.tasks.get('future').approvalRevision }));
  assert.throws(() => f.run('claim', { taskId: 'future', actorId: 'first-worker',
    workerToken: '32'.repeat(32), claimToken: 'bb'.repeat(32) }),
  error => error.code === 'DEPENDENCY_BLOCKED' || error.code === 'NO_READY_TASK');
});

// A real scope amendment plus fresh authorization can resolve a hold after the old worker leaves.
test('P2.review.scopeObligationLegitimateResolution', () => {
  const { f, answer } = arrange(true);
  answer('scope-change');
  const original = f.tx.tasks.get('writer').inputRevision;
  f.run('amend', { taskId: 'writer', patch: { outcome: 'Explicitly amended scope contract' } });
  f.confirm('writer');
  f.run('release', { taskId: 'writer', writesStopped: true, processStopped: true });
  f.run('approve', { taskId: 'writer' });
  const applicable = f.tx.tasks.get('writer');
  assert.ok(applicable.inputRevision > original);
  f.run('grant', { taskId: 'writer', workerId: 'second-worker',
    approvalRevision: applicable.approvalRevision });
  assert.doesNotThrow(() => answer('clarify'));
  assert.equal(f.tx.tasks.get('writer').questionHold, null);
  assert.equal(f.tx.tasks.get('writer').state, 'open');
  const fresh = f.claim('writer', 'second-worker');
  assert.equal(fresh.result.assignment.workerId, 'second-worker');
});

// R7 round2: a late approval hold gates acceptance and future accepted-result consumption.
test('P2.review.approvalHoldBlocksAcceptance', () => {
  const { f, owner, answer } = arrange(false);
  f.submit(owner.owner);
  answer('needs-approval');
  assert.equal(f.tx.tasks.get('writer').state, 'submitted');
  assert.throws(() => f.run('accept', { taskId: 'writer', gatesSatisfied: true,
    evidenceRefs: ['fixture/review#unresolved-approval'] }),
  error => ['QUESTION_PENDING', 'DEPENDENCY_BLOCKED', 'UNAUTHORIZED'].includes(error.code));

  // A hold arriving after historical acceptance must also prevent a new consumer allocation.
  const closed = arrange(false);
  closed.f.submit(closed.owner.owner);
  closed.answer('needs-approval');
  // Model a retained historical closed+hold record produced before this acceptance repair.
  // A fixed accept API must no longer create that state; dependency checks must still reject it.
  const historical = closed.f.tx.tasks.get('writer');
  closed.f.tx.tasks.put({ ...historical, state: 'closed', resultValid: true });
  closed.f.add('consumer', [{ taskId: 'writer', gate: 'accepted-result' }]);
  assert.throws(() => closed.f.claim('consumer'),
    error => ['QUESTION_PENDING', 'DEPENDENCY_BLOCKED', 'NO_READY_TASK'].includes(error.code));
});

// A successful authorized Lead resolution remains replayable until its applicability changes.
test('P2.review.resolutionReceiptContinuity', () => {
  const { f, question, answer } = arrange(true);
  answer('scope-change');
  f.run('amend', { taskId: 'writer', patch: { outcome: 'New explicit scope' } });
  f.confirm('writer');
  f.run('release', { taskId: 'writer', writesStopped: true, processStopped: true });
  f.run('approve', { taskId: 'writer' });
  f.run('grant', { taskId: 'writer', workerId: 'second-worker',
    approvalRevision: f.tx.tasks.get('writer').approvalRevision });
  const latest = f.tx.questions.get(question.id);
  const request = f.request('answer', { questionId: question.id,
    questionRevision: latest.questionRevision, answerRevision: latest.answerRevision,
    answer: { text: 'Explicit current scope approved', decision: 'clarify',
      evidenceRefs: ['fixture/resolution'], authorizationEvidenceRefs: ['fixture/auth#scope'] } });
  const result = f.run('answer', request);
  assert.equal(f.tx.tasks.get('writer').questionHold, null);
  const before = f.tx.tasks.get('writer');
  assert.doesNotThrow(() => f.authorize('answer', request, result));
  assert.deepEqual(f.tx.tasks.get('writer'), before, 'Receipt authorization cannot redo resolution');
  f.run('amend', { taskId: 'writer', patch: { outcome: 'A later changed contract' } });
  assert.throws(() => f.authorize('answer', request, result));
});


// Accepted-result chains must carry an ancestor hold, then permit unchanged evidence after resolution.
test('P2.review.ancestorHoldThreeHopReuse', () => {
  const { f, owner, question, answer } = arrange(false);
  f.submit(owner.owner);
  f.add('review', [{ taskId: 'writer', gate: 'frozen-submission' }]);
  const review = f.claim('review');
  f.submit(review.owner);
  f.run('accept', { taskId: 'review', gatesSatisfied: true, evidenceRefs: ['fixture/review#pass'] });
  f.add('integration', [{ taskId: 'review', gate: 'accepted-result' }]);
  const integration = f.claim('integration');
  f.submit(integration.owner);
  f.run('accept', { taskId: 'integration', gatesSatisfied: true,
    evidenceRefs: ['fixture/integration#pass'] });
  f.add('consumer', [{ taskId: 'integration', gate: 'accepted-result' }]);
  const acceptedBefore = ['review', 'integration'].map(id => f.tx.tasks.get(id));
  answer('needs-approval');
  assert.equal(f.tx.tasks.get('writer').state, 'submitted');
  assert.throws(() => f.claim('consumer'),
    error => ['QUESTION_PENDING', 'DEPENDENCY_BLOCKED', 'NO_READY_TASK'].includes(error.code));
  answer('clarify');
  const latest = f.tx.questions.get(question.id);
  f.run('ack-answer', { ...owner.owner, questionId: question.id,
    questionRevision: latest.questionRevision, answerRevision: latest.answerRevision,
    applied: true, evidenceRefs: ['fixture/ack#unchanged-scope'] });
  assert.equal(f.tx.tasks.get('writer').questionHold, null);
  assert.equal(f.tx.tasks.get('writer').state, 'submitted');
  assert.deepEqual(['review', 'integration'].map(id => f.tx.tasks.get(id)), acceptedBefore,
    'Unchanged-scope resolution permits valid historical results without rerunning intermediates');
  assert.equal(f.claim('consumer').result.task.state, 'running');
});
