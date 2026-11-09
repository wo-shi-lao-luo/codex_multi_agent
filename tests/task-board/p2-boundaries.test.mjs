// Focused deterministic P2 boundaries supplement the real CLI journeys without patching database policy.
import test from 'node:test';
import assert from 'node:assert/strict';
import { domainFixture } from './domain-fixture.mjs';
import { effectivePending } from '../../packages/task-board/src/questions/service.mjs';

function question(f, owner) {
  return f.run('ask', { ...owner, step: 'Current decision', question: 'Which current input applies?',
    checkedRefs: ['fixture/current'], impact: 'Current task waits', blocking: true }).question;
}

// Ten actual questions reach the documented fixed threshold; no fake threshold2/config mutation.
test('P2.boundary.tenQuestionsBackpressure', () => {
  const f = domainFixture();
  for (let index = 0; index < 10; index++) {
    const id = `work-${index}`;
    f.add(id);
    const owner = f.claim(id);
    question(f, owner.owner);
  }
  assert.equal(effectivePending(f.tx).length, 10);
  f.add('next-work');
  f.run('grant', { taskId: 'next-work', workerId: 'first-worker', approvalRevision: 2 });
  assert.throws(() => f.run('claim', { taskId: 'next-work', actorId: 'first-worker',
    workerToken: '32'.repeat(32), claimToken: '98'.repeat(32) }),
  error => error.code === 'QUESTION_BACKPRESSURE');
  assert.equal(f.tx.assignments.list({ taskId: 'next-work' }).length, 0);
});

// Approval hold remains effective when safe release makes its old question stale; only Lead resolves.
test('P2.boundary.approvalHoldSurvivesRelease', () => {
  const f = domainFixture();
  f.add('work');
  const owner = f.claim('work');
  const asked = question(f, owner.owner);
  const answered = f.run('answer', { questionId: asked.id, questionRevision: asked.questionRevision,
    answerRevision: asked.answerRevision, answer: { text: 'Wait for explicit approval',
      decision: 'needs-approval', evidenceRefs: ['fixture/approval#pending'] } }).question;
  f.run('ack-answer', { ...owner.owner, questionId: asked.id,
    questionRevision: answered.questionRevision, answerRevision: answered.answerRevision,
    applied: true, evidenceRefs: ['fixture/application#waiting'] });
  f.run('release', { taskId: 'work', writesStopped: true, processStopped: true });
  assert.equal(effectivePending(f.tx).length, 1);
  assert.ok(f.tx.tasks.get('work').questionHold);
  const revision = f.tx.tasks.get('work').approvalRevision;
  const latest = f.tx.questions.get(asked.id);
  f.run('answer', { questionId: asked.id, questionRevision: latest.questionRevision,
    answerRevision: latest.answerRevision, answer: { text: 'Prior scope explicitly authorized',
      decision: 'clarify', evidenceRefs: ['fixture/approval#lead-authorized'],
      authorizationEvidenceRefs: ['fixture/authorization#explicit-lead-decision'] } });
  assert.equal(f.tx.tasks.get('work').questionHold, null);
  assert.equal(f.tx.tasks.get('work').approvalRevision, revision);
  assert.notEqual(f.tx.tasks.get('work').state, 'running');
});

// Changed execution epochs cannot apply an old answer, even for the same real worker.
test('P2.boundary.oldAssignmentAckDenied', () => {
  const f = domainFixture();
  f.add('work');
  const owner = f.claim('work');
  const asked = question(f, owner.owner);
  const answered = f.run('answer', { questionId: asked.id, questionRevision: asked.questionRevision,
    answerRevision: asked.answerRevision, answer: { text: 'Use current input', decision: 'clarify',
      evidenceRefs: ['fixture/answer#applicable'] } }).question;
  f.run('transfer', { taskId: 'work', newWorkerId: 'first-worker',
    newClaimToken: 'a9'.repeat(32), expectedApprovalRevision: 2,
    writesStopped: true, processStopped: true, handoffRefs: ['fixture/handoff#new-owner'] });
  assert.throws(() => f.run('ack-answer', { ...owner.owner, questionId: asked.id,
    questionRevision: answered.questionRevision, answerRevision: answered.answerRevision,
    applied: true, evidenceRefs: ['fixture/apply#old-allocation'] }),
  error => error.code === 'STALE_ASSIGNMENT');
});
