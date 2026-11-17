// Source activation migrates an owned legacy listener without changing task authority.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { EventEmitter } from 'node:events';
import { randomUUID } from 'node:crypto';
import { activate } from '../../packages/task-board/src/activation/orchestrator.mjs';
import { prepareRequest } from '../../packages/task-board/src/activation/prepare.mjs';
import { callCli } from '../../packages/task-board/src/activation/transport.mjs';
import { serviceStatus, stopService } from '../../packages/task-board/src/server/control.mjs';
import { readRuntime } from '../../packages/task-board/src/activation/shared-registry.mjs';
import { hubRequest } from '../../packages/task-board/src/activation/shared-service.mjs';
import { sourcePath } from './helpers.mjs';

const pause = () => new Promise(resolve => setTimeout(resolve, 30));
for (const mode of ['healthy', 'stopped', 'cleanup-denied']) {
test(`SHARED.activation.migration.${mode}`, async t => {
  const parent = sourcePath('_work/task-board/test-fixtures'); fs.mkdirSync(parent, { recursive: true });
  const root = fs.mkdtempSync(path.join(parent, 'shared-activation-')), home = path.join(root, 'hub');
  const ceiling = process.env.GIT_CEILING_DIRECTORIES; process.env.GIT_CEILING_DIRECTORIES = parent;
  let request, requestPath;
  t.after(async () => {
    if (requestPath && fs.existsSync(path.join(path.dirname(requestPath), 'activation.json'))) {
      const journal = JSON.parse(fs.readFileSync(path.join(path.dirname(requestPath), 'activation.json'), 'utf8'));
      for (const service of [journal.service, ...(journal.serviceMigrationHistory ?? []).map(x => x.service)]) {
        if (service) try { await stopService({ ...service, serviceControlToken: request.serviceControlToken }); } catch { /* stopped */ }
      }
    }
    await pause();
    const instance = fs.existsSync(home) ? readRuntime(home, 'instance.json') : null;
    if (instance?.hubId) {
      try { await hubRequest(instance, readRuntime(home, 'authority.json').token, 'stop'); } catch { /* closed */ }
      for (let n = 0; n < 100; n++) {
        try { process.kill(instance.processId, 0); } catch (e) { if (e.code === 'ESRCH') break; throw e; }
        await pause();
      }
    }
    fs.rmSync(root, { recursive: true, force: true, maxRetries: 10, retryDelay: 50 });
    if (ceiling === undefined) delete process.env.GIT_CEILING_DIRECTORIES; else process.env.GIT_CEILING_DIRECTORIES = ceiling;
  });
  const prepared = prepareRequest(root, { action: 'prepare-request', actorId: 'lead', executionApproved: true,
    sessionProfile: { hostId: 'fixture', mainSessionId: randomUUID(), projectId: 'fixture-project',
      projectName: 'Migration', sessionName: 'Legacy' },
    task: { id: 'work', title: 'Work', outcome: 'Output', sourceRefs: ['fixture/work'], acceptanceRefs: ['fixture/accept'], scope: { read: [], write: [] } } });
  assert.equal(prepared.state, 'prepared'); requestPath = prepared.requestPath;
  request = JSON.parse(fs.readFileSync(requestPath, 'utf8'));
  const legacy = await activate(root, request); assert.equal(legacy.state, 'enabled');
  const inspect = async () => (await callCli(root, legacy.boardPath, legacy.sessionKey, 'inspect',
    { actorId: request.actorId, leadToken: request.leadToken })).result;
  const before = await inspect(), retainedRequest = fs.readFileSync(requestPath);
  const migration = { action: 'migrate-service', actorId: request.actorId,
    sessionProfile: request.sessionProfile, leadToken: request.leadToken,
    serviceControlToken: request.serviceControlToken,
    serviceMigration: { expectedServiceId: legacy.service.serviceId, evidenceRefs: ['fixture/authorized-migration'] } };
  if (mode === 'stopped') {
    await stopService({ ...legacy.service, serviceControlToken: request.serviceControlToken });
    for (let n = 0; n < 40; n++) {
      try { await serviceStatus({ ...legacy.service, serviceControlToken: request.serviceControlToken }); }
      catch (error) { if (error.details?.transportCode === 'ECONNREFUSED') break; }
      await pause();
    }
    const denied = await activate(root, migration, { serviceMode: 'shared', sharedRuntimeHome: home });
    assert.equal(denied.reasonCode, 'SERVICE_STOP_EVIDENCE_REQUIRED');
    assert.equal(fs.existsSync(home), false, 'Refused legacy service needs evidence before Hub creation');
    migration.serviceMigration.confirmedStopped = true;
  }
  const originalRequest = http.request;
  t.mock.method(http, 'request', function(...args) {
    if (mode === 'cleanup-denied' && new URL(args[0]).port === String(legacy.service.port)
        && args[1]?.method === 'POST') {
      const blocked = new EventEmitter(); blocked.destroy = () => {};
      blocked.end = () => queueMicrotask(() => {
        blocked.emit('error', Object.assign(Error('redacted fixture denial'), { code: 'EACCES' }));
        blocked.emit('close');
      });
      return blocked;
    }
    const request = originalRequest.apply(this, args);
    request.on('error', error => t.diagnostic(`transport ${error.code ?? 'unknown'}`));
    return request;
  });
  const result = await activate(root, migration, { serviceMode: 'shared', sharedRuntimeHome: home });
  assert.equal(result.state, 'enabled', JSON.stringify(result));
  assert.equal(result.service.serviceMode, 'shared-v1');
  assert.equal(result.taskExecution, 'not-resumed');
  assert.equal(result.legacyCleanup, mode === 'cleanup-denied' ? 'pending' : 'complete', JSON.stringify(result));
  assert.deepEqual(await inspect(), before);
  assert.deepEqual(fs.readFileSync(requestPath), retainedRequest);
  assert.equal((await serviceStatus({ ...result.service, serviceControlToken: request.serviceControlToken })).status, 'running');
  if (mode === 'cleanup-denied') {
    assert.equal((await serviceStatus({ ...legacy.service, serviceControlToken: request.serviceControlToken })).status, 'running');
    const journal = JSON.parse(fs.readFileSync(path.join(path.dirname(requestPath), 'activation.json'), 'utf8'));
    assert.equal(journal.legacyCleanupPending.service.serviceId, legacy.service.serviceId);
    assert.equal(journal.service.serviceId, result.service.serviceId);
  } else await assert.rejects(serviceStatus({ ...legacy.service, serviceControlToken: request.serviceControlToken }), { code: 'SERVICE_UNAVAILABLE' });
  t.mock.restoreAll();
  const again = await activate(root, migration, { serviceMode: 'shared', sharedRuntimeHome: home });
  assert.equal(again.state, 'enabled'); assert.equal(again.service.serviceId, result.service.serviceId);
  assert.equal(again.legacyCleanup, 'complete');
  assert.equal(readRuntime(home, 'boards.json').length, 1);
});
}
