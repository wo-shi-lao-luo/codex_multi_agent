// Real disposable Boards exercise explicit service recovery without changing task authority.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { EventEmitter } from 'node:events';
import { randomUUID } from 'node:crypto';
import { prepareRequest } from '../../packages/task-board/src/activation/prepare.mjs';
import { activate } from '../../packages/task-board/src/activation/orchestrator.mjs';
import { requestIssues } from '../../packages/task-board/src/activation/request.mjs';
import { serviceStatus, stopService } from '../../packages/task-board/src/server/control.mjs';
import { callCli } from '../../packages/task-board/src/activation/transport.mjs';

const pause = () => new Promise(resolve => setTimeout(resolve, 25));

async function waitForOwnedProcessExit(processId) {
  if (!Number.isSafeInteger(processId)) return;
  for (let attempt = 0; attempt < 80; attempt++) {
    try { process.kill(processId, 0); }
    catch (error) { if (error.code === 'ESRCH') return; throw error; }
    await pause();
  }
  throw Error('Owned service process did not exit');
}

async function fixture(t) {
  const parent = path.resolve('_work/task-board/test-fixtures');
  fs.mkdirSync(parent, { recursive: true });
  const root = fs.mkdtempSync(path.join(parent, 'service-recovery-'));
  const priorCeiling = process.env.GIT_CEILING_DIRECTORIES;
  process.env.GIT_CEILING_DIRECTORIES = parent;
  let request;
  let journalPath;
  t.after(async () => {
    if (journalPath && fs.existsSync(journalPath)) {
      const journal = JSON.parse(fs.readFileSync(journalPath, 'utf8'));
      if (journal.service) {
        try { await stopService({ ...journal.service, serviceControlToken: request.serviceControlToken }); }
        catch (error) { assert.equal(error.code, 'SERVICE_UNAVAILABLE'); }
      }
    }
    // Windows can retain the stopped child's project-directory handle for a short exit interval.
    fs.rmSync(root, { recursive: true, force: true, maxRetries: 10, retryDelay: 50 });
    if (priorCeiling === undefined) delete process.env.GIT_CEILING_DIRECTORIES;
    else process.env.GIT_CEILING_DIRECTORIES = priorCeiling;
  });
  const prepared = prepareRequest(root, {
    action: 'prepare-request', actorId: 'lead', executionApproved: true,
    sessionProfile: { hostId: 'fixture-host', mainSessionId: randomUUID(), projectId: 'fixture-project',
      projectName: 'Recovery fixture', sessionName: 'Retained work' },
    task: { id: 'work', title: 'Retain task', outcome: 'Recover display only',
      sourceRefs: ['fixture/work'], acceptanceRefs: ['fixture/check'], scope: { read: [], write: [] } },
  });
  assert.equal(prepared.state, 'prepared', JSON.stringify(prepared));
  request = JSON.parse(fs.readFileSync(prepared.requestPath, 'utf8'));
  journalPath = path.join(path.dirname(prepared.requestPath), 'activation.json');
  const first = await activate(root, request);
  assert.equal(first.state, 'enabled', JSON.stringify(first));
  const journal = () => JSON.parse(fs.readFileSync(journalPath, 'utf8'));
  const recovery = () => ({ ...request, action: 'recover-service', serviceRecovery: {
    expectedServiceId: first.service.serviceId, confirmedStopped: true,
    evidenceRefs: ['fixture/host-process-and-listener-check'],
  } });
  async function stop() {
    await stopService({ ...first.service, serviceControlToken: request.serviceControlToken });
    for (let attempt = 0; attempt < 40; attempt++) {
      try { await serviceStatus({ ...first.service, serviceControlToken: request.serviceControlToken }); }
      catch (error) {
        if (error.code !== 'SERVICE_UNAVAILABLE') throw error;
        await waitForOwnedProcessExit(journal().serviceProcessId);
        return;
      }
      await pause();
    }
    throw Error('Owned fixture service did not stop');
  }
  return { root, request, first, journal, journalPath, recovery, stop,
    requestPath: prepared.requestPath };
}

// Each transport failure must retain a safe actionable code without leaking raw error text.
for (const transportCode of ['EACCES', 'EPERM', 'ECONNREFUSED', 'ETIMEDOUT']) {
  test(`SERVICE.diagnostic.${transportCode}`, async t => {
    t.mock.method(http, 'request', () => {
      const request = new EventEmitter();
      request.end = () => queueMicrotask(() => {
        request.emit('error', Object.assign(Error('secret-must-not-escape'), { code: transportCode }));
        request.emit('close');
      });
      request.destroy = () => request.emit('close');
      return request;
    });
    await assert.rejects(serviceStatus({ url: 'http://127.0.0.1:12345', port: 12345,
      serviceId: 'fixture-service', boardId: 'fixture-board', generation: 'fixture-generation',
      serviceControlToken: 'a'.repeat(64) }), error => {
      assert.equal(error.code, 'SERVICE_UNAVAILABLE');
      assert.equal(error.details?.transportCode, transportCode);
      assert.ok(!JSON.stringify(error).includes('secret-must-not-escape'));
      return true;
    });
  });
}

// Missing host confirmation/evidence is a schema failure, never permission to restart a listener.
test('SERVICE.recovery.requiresExplicitHostEvidence', () => {
  const request = { action: 'recover-service', actorId: 'lead', executionApproved: true,
    sessionProfile: { hostId: 'h', mainSessionId: 'm', projectId: 'p', projectName: 'P', sessionName: 'S' },
    leadToken: 'a'.repeat(64), claimToken: 'b'.repeat(64), serviceControlToken: 'c'.repeat(64),
    task: { id: 't', title: 'T', outcome: 'O', sourceRefs: ['w'], acceptanceRefs: ['v'] } };
  assert.ok(requestIssues(request).invalidFields.includes('serviceRecovery'));
  request.serviceRecovery = { expectedServiceId: 'old', confirmedStopped: true, evidenceRefs: ['host/check'] };
  assert.deepEqual(requestIssues(request), { missingFields: [], invalidFields: [] });
});

// A stopped service is replaced only explicitly; task, generation, credentials and original scope survive.
test('SERVICE.recovery.replacesStoppedDisplayPreservingBoard', async t => {
  const f = await fixture(t);
  const originalRequest = fs.readFileSync(f.requestPath);
  const originalTask = f.journal().tasks;
  await f.stop();
  assert.equal(f.journal().service.serviceId, f.first.service.serviceId);
  const recovered = await activate(f.root, f.recovery());
  assert.equal(recovered.state, 'enabled', JSON.stringify(recovered));
  assert.notEqual(recovered.service.serviceId, f.first.service.serviceId);
  assert.equal(recovered.boardId, f.first.boardId);
  assert.equal(recovered.generation, f.first.generation);
  assert.deepEqual(f.journal().tasks, originalTask);
  assert.deepEqual(fs.readFileSync(f.requestPath), originalRequest);
  assert.ok(recovered.presentation.url.includes('?ticket='));
  const running = await serviceStatus({ ...recovered.service,
    serviceControlToken: f.request.serviceControlToken });
  assert.equal(running.status, 'running');
  const replay = await activate(f.root, f.recovery());
  assert.equal(replay.state, 'activation-pending');
  assert.equal(f.journal().service.serviceId, recovered.service.serviceId);
});

// A healthy retained service or stale expected identity cannot be replaced by a recovery request.
test('SERVICE.recovery.rejectsHealthyOrMismatchedService', async t => {
  const f = await fixture(t);
  const result = await activate(f.root, f.recovery());
  assert.equal(result.state, 'activation-pending');
  assert.equal(f.journal().service.serviceId, f.first.service.serviceId);
  await f.stop();
  const wrong = f.recovery();
  wrong.serviceRecovery.expectedServiceId = 'different-service';
  const rejected = await activate(f.root, wrong);
  assert.equal(rejected.state, 'activation-pending');
  assert.equal(f.journal().service.serviceId, f.first.service.serviceId);
});

// Permission denial is not proof of exit, even when a caller claims it checked the host.
test('SERVICE.recovery.neverRestartsOnPermissionDenial', async t => {
  const f = await fixture(t);
  const mock = t.mock.method(http, 'request', () => {
    const request = new EventEmitter();
    request.end = () => queueMicrotask(() => {
      request.emit('error', Object.assign(Error('redacted'), { code: 'EACCES' }));
      request.emit('close');
    });
    request.destroy = () => request.emit('close');
    return request;
  });
  const result = await activate(f.root, f.recovery());
  mock.mock.restore();
  assert.equal(result.state, 'activation-pending');
  assert.equal(result.transportCode, 'EACCES');
  assert.equal(f.journal().service.serviceId, f.first.service.serviceId);
});

// Authentication and uncertain prior launch intent remain hard stops despite a refused endpoint.
test('SERVICE.recovery.preservesUnknownIntentAndRejectsWrongAuthority', async t => {
  const f = await fixture(t);
  await f.stop();
  const before = fs.readFileSync(f.journalPath);
  const wrongAuthority = { ...f.recovery(), leadToken: 'f'.repeat(64) };
  assert.equal((await activate(f.root, wrongAuthority)).state, 'activation-pending');
  assert.deepEqual(fs.readFileSync(f.journalPath), before);
  const uncertain = f.journal();
  uncertain.serviceIntent = 'unknown';
  fs.writeFileSync(f.journalPath, JSON.stringify(uncertain));
  const unknownBytes = fs.readFileSync(f.journalPath);
  const result = await activate(f.root, f.recovery());
  assert.equal(result.state, 'activation-pending');
  assert.equal(result.reasonCode, 'SERVICE_OUTCOME_UNKNOWN');
  assert.deepEqual(fs.readFileSync(f.journalPath), unknownBytes);
});

// A refused socket cannot authenticate a token: recovery must verify retained credential continuity.
test('SERVICE.recovery.rejectsChangedControlCredentialWithoutWrites', async t => {
  const f = await fixture(t);
  await f.stop();
  const before = fs.readFileSync(f.journalPath);
  const wrong = { ...f.recovery(), serviceControlToken: 'd'.repeat(64) };
  const result = await activate(f.root, wrong);
  // Clean up even on the pre-fix Red, where the defect creates a service with the wrong token.
  if (result.state === 'enabled') {
    await stopService({ ...result.service, serviceControlToken: wrong.serviceControlToken });
  }
  assert.equal(result.state, 'activation-pending', JSON.stringify(result));
  assert.deepEqual(fs.readFileSync(f.journalPath), before);
});

// Legacy receipts need their exact private handoff; missing or changed credentials cannot be adopted.
test('SERVICE.recovery.legacyPrivateHandoffPreservesAuthority', async t => {
  const f = await fixture(t);
  await f.stop();
  const legacy = f.journal();
  delete legacy.serviceControlTokenHash;
  fs.writeFileSync(f.journalPath, JSON.stringify(legacy));
  const before = fs.readFileSync(f.journalPath);
  const wrong = { ...f.recovery(), serviceControlToken: 'e'.repeat(64) };
  assert.equal((await activate(f.root, wrong)).state, 'activation-pending');
  assert.deepEqual(fs.readFileSync(f.journalPath), before);
  fs.renameSync(f.requestPath, `${f.requestPath}.held`);
  try {
    const missing = await activate(f.root, f.recovery());
    assert.equal(missing.state, 'activation-pending');
    assert.equal(missing.reasonCode, 'SERVICE_RECOVERY_VERIFIER_REQUIRED');
    assert.deepEqual(fs.readFileSync(f.journalPath), before);
  } finally { fs.renameSync(`${f.requestPath}.held`, f.requestPath); }
  const recovered = await activate(f.root, f.recovery());
  assert.equal(recovered.state, 'enabled', JSON.stringify(recovered));
  assert.equal(typeof f.journal().serviceControlTokenHash, 'string');
});

// Ordinary resume repairs a service only after its recorded actual process has exited.
test('SERVICE.recovery.automaticallyRepairsConfirmedExitedProcess', async t => {
  const f = await fixture(t);
  const originalTask = f.journal().tasks;
  const originalRequest = fs.readFileSync(f.requestPath);
  const processId = f.journal().serviceProcessId;
  await f.stop();
  const recovered = await activate(f.root, { ...f.request, action: 'resume' });
  assert.equal(recovered.state, 'enabled', JSON.stringify(recovered));
  assert.ok(Number.isSafeInteger(processId) && processId > 0);
  assert.notEqual(recovered.service.serviceId, f.first.service.serviceId);
  assert.notEqual(f.journal().serviceProcessId, processId);
  assert.deepEqual(f.journal().tasks, originalTask);
  assert.equal(recovered.boardId, f.first.boardId);
  assert.equal(recovered.generation, f.first.generation);
  assert.deepEqual(fs.readFileSync(f.requestPath), originalRequest);
  assert.deepEqual(f.journal().serviceRecoveryHistory.at(-1).proof,
    { kind: 'process-not-found', processId });
});

// Missing legacy process identity or an alive/reused PID never proves the listener's process exited.
test('SERVICE.recovery.automaticModeRejectsUnknownOrAliveProcess', async t => {
  const f = await fixture(t);
  await f.stop();
  for (const processId of [undefined, process.pid]) {
    const retained = f.journal();
    if (processId === undefined) delete retained.serviceProcessId;
    else retained.serviceProcessId = processId;
    fs.writeFileSync(f.journalPath, JSON.stringify(retained));
    const before = fs.readFileSync(f.journalPath);
    const result = await activate(f.root, f.request);
    assert.equal(result.state, 'activation-pending');
    assert.equal(result.transportCode, 'ECONNREFUSED');
    assert.deepEqual(fs.readFileSync(f.journalPath), before);
  }
});

// Restoring the display must not skip activation of a newly approved task on the same Board.
test('SERVICE.recovery.automaticRepairContinuesNormalTaskActivation', async t => {
  const f = await fixture(t);
  await f.stop();
  const next = { ...f.request, task: { ...f.request.task, id: 'next-work', title: 'Next approved task' } };
  const result = await activate(f.root, next);
  assert.equal(result.state, 'enabled', JSON.stringify(result));
  const observed = await callCli(f.root, f.first.boardPath, f.first.sessionKey, 'inspect', {
    actorId: f.request.actorId, leadToken: f.request.leadToken,
  });
  const task = observed.result.tasks.find(item => item.id === next.task.id);
  assert.ok(task, 'An enabled task must exist in SQLite, not only in the recovery response');
  assert.equal(task.state, 'running');
  assert.ok(result.presentation.url.includes('?ticket='));
});

// Service repair cannot approve a changed contract merely because the display was unavailable.
test('SERVICE.recovery.automaticRepairStillRejectsTaskContractDrift', async t => {
  const f = await fixture(t);
  await f.stop();
  const changed = { ...f.request, task: { ...f.request.task, title: 'Unapproved contract change' } };
  const result = await activate(f.root, changed);
  assert.equal(result.state, 'activation-pending');
  assert.equal(result.reasonCode, 'TASK_CONTRACT_CHANGED');
  const observed = await callCli(f.root, f.first.boardPath, f.first.sessionKey, 'inspect', {
    actorId: f.request.actorId, leadToken: f.request.leadToken,
  });
  assert.equal(observed.result.tasks.find(item => item.id === f.request.task.id).title,
    f.request.task.title);
  const corrected = await activate(f.root, f.request);
  assert.equal(corrected.state, 'enabled', JSON.stringify(corrected));
  assert.match(corrected.presentation.url ?? '', /\?ticket=/,
    'A failed contract must not consume the first usable recovery presentation');
});
