// Realistic caller errors must be actionable and rejected before filesystem mutations.
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readdirSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { requestIssues, invalidRequest } from '../../packages/task-board/src/activation/request.mjs';

const request = () => ({ action: 'activate', actorId: 'lead', executionApproved: true,
  sessionProfile: { hostId: 'fixture-host', mainSessionId: 'fixture-session',
    projectId: 'fixture-project', projectName: 'Fixture', sessionName: 'Work' },
  task: { id: 'work', title: 'Approved task', outcome: 'Bounded result',
    sourceRefs: ['docs/work.md'], acceptanceRefs: ['docs/checks.md'] },
  leadToken: 'a'.repeat(64), claimToken: 'b'.repeat(64), serviceControlToken: 'c'.repeat(64) });

for (const field of ['writeScope', 'readScope']) {
  // Scenario: a caller uses a legacy scope alias even with otherwise valid identity and tokens.
  // Expected: reject the alias in activation and preparation, never silently grant empty scope.
  test(`REQUEST.recovery.rejectLegacy.${field}`, () => {
    const input = request();
    input.task[field] = ['src/'];
    for (const prepare of [false, true]) {
      assert.ok(requestIssues(input, { prepare }).invalidFields.includes(`task.${field}`));
    }
    delete input.task[field];
    input.task.scope = { read: ['docs/'], write: ['src/'] };
    assert.deepEqual(requestIssues(input), { missingFields: [], invalidFields: [] });
  });
}

// Scenario: a first-time caller omits the profile and credentials, like an actual development call.
// Expected: direct it to native context and the existing private preparation flow, not a runtime fix.
test('REQUEST.recovery.missingBootstrapExplainsNextSteps', () => {
  const input = request();
  delete input.sessionProfile;
  for (const field of ['leadToken', 'claimToken', 'serviceControlToken']) delete input[field];
  const result = invalidRequest(requestIssues(input));
  assert.equal(result.reasonCode, 'REQUEST_INVALID');
  assert.match(result.nextStep, /native/i);
  assert.match(result.nextStep, /prepare-request/);
  assert.match(result.nextStep, /RequestPath/);
  assert.match(result.nextStep, /retained|existing/i);
  assert.equal(result.missingFields.length, 8);
});

// Scenario: malformed requests reach the real CLI in a new isolated directory.
// Expected: process success remains a structured pending result, with no Board or ignore writes.
test('REQUEST.recovery.cliRejectsWrongScopeWithoutMutation', t => {
  const parent = resolve('_work/task-board/test-fixtures');
  mkdirSync(parent, { recursive: true });
  const root = mkdtempSync(join(parent, 'request-recovery-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const input = request();
  input.task.writeScope = ['src/'];
  const child = spawnSync(process.execPath, [resolve('packages/task-board/src/cli/activation.mjs'),
    '--project-root', root, '--stdin'], { input: JSON.stringify(input), encoding: 'utf8', timeout: 10000 });
  assert.equal(child.status, 0, child.stderr);
  const result = JSON.parse(child.stdout).result;
  assert.equal(result.state, 'activation-pending');
  assert.equal(result.reasonCode, 'REQUEST_INVALID');
  assert.ok(result.invalidFields.includes('task.writeScope'));
  assert.deepEqual(readdirSync(root), []);
  for (const field of ['leadToken', 'claimToken', 'serviceControlToken']) {
    assert.ok(!child.stdout.includes(input[field]));
  }
});
