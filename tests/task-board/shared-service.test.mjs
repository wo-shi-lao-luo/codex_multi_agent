// Actual HTTP/SQLite and owned shared runners. Every case has a private temporary runtime home.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import net from 'node:net';
import { randomUUID } from 'node:crypto';
import { initializeBoard, openBoard } from '../../packages/task-board/src/storage/index.mjs';
import { normalizeSessionProfile, sessionLocation } from '../../packages/task-board/src/domain/session.mjs';
import { hash } from '../../packages/task-board/src/coordination/service.mjs';
import { startSharedServer } from '../../packages/task-board/src/server/shared-server.mjs';
import { attachSharedService, hubRequest, sharedFingerprint } from '../../packages/task-board/src/activation/shared-service.mjs';
import { readRuntime, writeRuntime } from '../../packages/task-board/src/activation/shared-registry.mjs';
import { serviceStatus, stopService } from '../../packages/task-board/src/server/control.mjs';
import { secret, sourcePath } from './helpers.mjs';

const pause = () => new Promise(resolve => setTimeout(resolve, 30));
async function exited(pid) {
  for (let i = 0; i < 100; i++) {
    try { process.kill(pid, 0); } catch (e) { if (e.code === 'ESRCH') return; throw e; }
    await pause();
  }
  throw Error('Owned shared runner did not exit');
}
function fixture(t, count = 2) {
  const parent = sourcePath('_work/task-board/test-fixtures'); fs.mkdirSync(parent, { recursive: true });
  const root = fs.mkdtempSync(path.join(parent, 'shared-')), home = path.join(root, 'runtime');
  fs.mkdirSync(home);
  const boards = Array.from({ length: count }, (_, index) => index).map(index => {
    const projectRoot = path.join(root, `project${index}`); fs.mkdirSync(projectRoot);
    const sessionProfile = normalizeSessionProfile({ hostId: 'fixture', mainSessionId: randomUUID(),
      projectId: `project${index}`, projectName: `PRIVATE PROJECT ${index}`, sessionName: `PRIVATE CHAT ${index}` });
    const { boardPath, sessionKey } = sessionLocation(sessionProfile);
    const leadToken = secret(), serviceControlToken = secret();
    const board = initializeBoard({ projectRoot, boardPath, leadId: 'lead', leadTokenHash: hash(leadToken),
      sessionProfile: Object.fromEntries(['hostId','mainSessionId','projectId','projectName','sessionName']
        .map(key => [key, sessionProfile[key]])), sessionKey });
    const generation = board.metadata().generation; board.close();
    return { location: { projectRoot, boardPath, sessionKey }, actorId: 'lead', generation,
      leadToken, serviceControlToken };
  });
  let inProcess;
  t.after(async () => {
    if (inProcess) await inProcess.close();
    const instance = readRuntime(home, 'instance.json');
    if (instance?.hubId) {
      // The authenticated registry lists only this owned fixture's attached endpoints.
      const descriptors = readRuntime(home, 'boards.json') ?? [];
      for (const d of descriptors) {
        const input = boards.find(b => b.location.sessionKey === d.location.sessionKey);
        try { await stopService({ serviceId: d.serviceId, boardId: d.boardId, generation: d.generation,
          sessionKey: d.location.sessionKey, serviceMode: 'shared-v1', hubId: instance.hubId,
          routeBase: `/boards/${d.location.sessionKey}/`, port: instance.port, url: instance.url,
          serviceControlToken: input.serviceControlToken }); } catch { /* It may already be stopped. */ }
      }
      await pause();
      const authority = readRuntime(home, 'authority.json');
      try { await hubRequest(instance, authority.token, 'stop'); } catch { /* May be stopped by case. */ }
      await exited(instance.processId);
    }
    fs.rmSync(root, { recursive: true, force: true, maxRetries: 10, retryDelay: 50 });
  });
  return { home, boards, useServer(server) { inProcess = server; } };
}
async function bootstrap(service) {
  const response = await fetch(service.ticketUrl, { redirect: 'manual' });
  assert.equal(response.status, 303);
  const cookie = response.headers.get('set-cookie')?.split(';')[0];
  const fragment = new URL(response.headers.get('location'), service.url).hash;
  const capability = /^#view=([a-f0-9]{64})$/.exec(fragment)?.[1]; assert.ok(capability);
  await response.text(); return { Cookie: cookie, 'X-Task-Board-View': capability };
}

test('SHARED.launcher.sameProcessPortIsolationAndDetach', async t => {
  const f = fixture(t);
  const first = await attachSharedService(f.boards[0], { home: f.home });
  const second = await attachSharedService(f.boards[1], { home: f.home });
  assert.equal(first.processId, second.processId);
  assert.equal(first.service.port, second.service.port);
  assert.notEqual(first.service.routeBase, second.service.routeBase);
  const a = await bootstrap(first.service), b = await bootstrap(second.service);
  for (const service of [first.service, second.service]) {
    const naked = await fetch(service.url + service.routeBase); assert.equal(naked.status, 200);
    assert.ok(!(await naked.text()).includes('PRIVATE PROJECT'));
  }
  const at = (service, resource, headers) => fetch(service.url + service.routeBase + resource, { headers });
  assert.equal((await at(second.service, 'api/snapshot', a)).status, 401);
  assert.equal((await at(second.service, 'api/snapshot', { Cookie: b.Cookie })).status, 401);
  assert.equal((await at(second.service, 'api/snapshot', { ...b, 'X-Task-Board-View': a['X-Task-Board-View'] })).status, 401);
  const snapA = await (await at(first.service, 'api/snapshot', a)).json();
  const snapB = await (await at(second.service, 'api/snapshot', b)).json();
  assert.notEqual(snapA.boardId, snapB.boardId);
  assert.equal(snapB.sessionProfile.projectName, 'PRIVATE PROJECT 1');
  await assert.rejects(serviceStatus({ ...second.service, serviceControlToken: f.boards[0].serviceControlToken }),
    { code: 'SERVICE_CONTROL_REJECTED' });
  const expired = await fetch(first.service.ticketUrl, { redirect: 'manual' });
  assert.equal(expired.status, 200); assert.ok(!(await expired.text()).includes(a['X-Task-Board-View']));
  const registry = fs.readFileSync(path.join(f.home, 'boards.json'), 'utf8');
  for (const input of f.boards) for (const token of [input.leadToken, input.serviceControlToken]) {
    assert.ok(!registry.includes(token), 'Attachment registry keeps only credential hashes');
  }
  await stopService({ ...first.service, serviceControlToken: f.boards[0].serviceControlToken });
  await pause();
  assert.equal((await serviceStatus({ ...second.service, serviceControlToken: f.boards[1].serviceControlToken })).status, 'running');
  assert.equal((await at(second.service, 'api/snapshot', b)).status, 200);
});

test('SHARED.streamUsesCapabilityAndOwnCommittedCursor', async t => {
  const f = fixture(t), result = await attachSharedService(f.boards[0], { home: f.home });
  const service = result.service, headers = await bootstrap(service);
  const stream = await fetch(`${service.url}${service.routeBase}api/events?after=${f.boards[0].generation}:0`,
    { headers, signal: AbortSignal.timeout(5000) });
  assert.equal(stream.status, 200);
  const board = openBoard(f.boards[0].location);
  try {
    const request = { operationId: randomUUID(), actorId: 'lead', generation: f.boards[0].generation };
    board.transactOperation({ request, requestHash: hash(JSON.stringify(request)), operation: 'fixture-event' },
      tx => tx.change('fixture', { taskId: 'board-a-only' }));
  } finally { board.close(); }
  const reader = stream.body.getReader(); let text = '';
  while (!text.includes('board-a-only')) { const { value, done } = await reader.read(); if (done) break; text += new TextDecoder().decode(value); }
  assert.match(text, /event: change/); assert.match(text, /board-a-only/); await reader.cancel();
});

test('SHARED.restartRehydratesAndPreservesPort', async t => {
  const f = fixture(t), a = await attachSharedService(f.boards[0], { home: f.home });
  await attachSharedService(f.boards[1], { home: f.home });
  process.kill(a.processId, 'SIGTERM'); await exited(a.processId);
  const b = await attachSharedService(f.boards[0], { home: f.home });
  assert.equal(b.service.port, a.service.port); assert.notEqual(b.processId, a.processId);
  assert.notEqual(b.service.hubId, a.service.hubId);
  assert.equal(readRuntime(f.home, 'boards.json').length, 2);
  const c = await attachSharedService(f.boards[1], { home: f.home }); assert.equal(c.processId, b.processId);
});

test('SHARED.managerIsolationStartupAndRuntimeMismatch', async t => {
  const f = fixture(t), first = await attachSharedService(f.boards[0], { home: f.home });
  const instance = readRuntime(f.home, 'instance.json'), authority = readRuntime(f.home, 'authority.json');
  const denied = await fetch(first.service.url + '/_hub/attach', { method: 'POST', body: JSON.stringify(f.boards[1]) });
  assert.equal(denied.status, 401);
  await assert.rejects(attachSharedService({ ...f.boards[1], leadToken: secret() }, { home: f.home }),
    { code: 'SHARED_CONTROL_REJECTED' });
  await assert.rejects(attachSharedService({ ...f.boards[0], serviceControlToken: secret() }, { home: f.home }),
    { code: 'SHARED_CONTROL_REJECTED' });
  await assert.rejects(hubRequest(instance, authority.token, 'stop'), { code: 'SHARED_CONTROL_REJECTED' });
  assert.equal(readRuntime(f.home, 'boards.json').length, 1);
  const file = path.join(f.home, 'instance.json'), bytes = fs.readFileSync(file);
  try {
    fs.writeFileSync(file, JSON.stringify({ ...instance, state: 'starting' }));
    await assert.rejects(attachSharedService(f.boards[1], { home: f.home }), { code: 'SHARED_START_OUTCOME_UNKNOWN' });
    fs.writeFileSync(file, JSON.stringify({ ...instance, fingerprint: '0'.repeat(64) }));
    await assert.rejects(attachSharedService(f.boards[1], { home: f.home }), { code: 'SHARED_RUNTIME_MISMATCH' });
  } finally { fs.writeFileSync(file, bytes); }
  assert.equal((await serviceStatus({ ...first.service, serviceControlToken: f.boards[0].serviceControlToken })).status, 'running');
});

test('SHARED.concurrentStartupIsBoundedAndDoesNotDuplicateRunners', async t => {
  const f = fixture(t);
  const results = await Promise.allSettled(f.boards.map(input => attachSharedService(input, { home: f.home })));
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(results.find(r => r.status === 'rejected').reason.code, 'SHARED_BUSY');
  const first = results.find(r => r.status === 'fulfilled').value;
  // Retry only after the other startup is confirmed complete, not a blind launch retry.
  const a = await attachSharedService(f.boards[0], { home: f.home });
  const b = await attachSharedService(f.boards[1], { home: f.home });
  assert.equal(a.processId, first.processId); assert.equal(b.processId, first.processId);
});

test('SHARED.capabilityCannotReadAChangedGeneration', async t => {
  const f = fixture(t), result = await attachSharedService(f.boards[0], { home: f.home });
  const headers = await bootstrap(result.service);
  const board = openBoard(f.boards[0].location);
  try {
    const request = { operationId: randomUUID(), actorId: 'lead', generation: f.boards[0].generation };
    board.transactOperation({ request, requestHash: hash(JSON.stringify(request)), operation: 'fixture-generation' },
      tx => { tx.board.generation = randomUUID(); });
  } finally { board.close(); }
  const response = await fetch(result.service.url + result.service.routeBase + 'api/snapshot', { headers });
  assert.equal(response.status, 401);
  assert.ok(!(await response.text()).includes('PRIVATE PROJECT'));
  await assert.rejects(attachSharedService(f.boards[0], { home: f.home }), { code: 'SHARED_CONTROL_REJECTED' });
});

test('SHARED.occupiedStablePortNeverFallsBackOrKillsOwner', async t => {
  const f = fixture(t), owner = net.createServer(socket => socket.end());
  await new Promise(resolve => owner.listen(0, '127.0.0.1', resolve));
  const port = owner.address().port;
  t.after(() => { if (owner.listening) owner.close(); });
  writeRuntime(f.home, 'instance.json', { state: 'stopped', protocol: 1, fingerprint: sharedFingerprint(), port });
  await assert.rejects(attachSharedService(f.boards[0], { home: f.home }), { code: 'SHARED_PORT_CONFLICT' });
  assert.equal(owner.listening, true);
  assert.equal(readRuntime(f.home, 'instance.json').port, port);
  await new Promise(resolve => owner.close(resolve));
  const result = await attachSharedService(f.boards[0], { home: f.home });
  assert.equal(result.service.port, port);
});

test('SHARED.failedRetainedMountStillCountsTowardRegistryCapacity', async t => {
  const f = fixture(t, 65), managerToken = secret();
  const descriptors = f.boards.slice(0, 64).map(input => {
    const board = openBoard({ ...input.location, readOnly: true });
    try { return { location: input.location, actorId: input.actorId, boardId: board.metadata().boardId,
      generation: input.generation, leadTokenHash: hash(input.leadToken),
      controlHash: hash(input.serviceControlToken), serviceId: randomUUID() }; }
    finally { board.close(); }
  });
  writeRuntime(f.home, 'boards.json', descriptors);
  const missing = f.boards[0].location.projectRoot, away = missing + '-temporarily-away';
  fs.renameSync(missing, away);
  let server;
  try {
    server = await startSharedServer({ home: f.home, managerToken, fingerprint: sharedFingerprint() });
    f.useServer(server);
    assert.equal(server.failedAttachments.length, 1);
    const before = fs.readFileSync(path.join(f.home, 'boards.json'));
    const response = await fetch(server.url + '/_hub/attach', { method: 'POST',
      headers: { Authorization: `Bearer ${managerToken}`, 'X-Task-Board-Hub-Id': server.hubId },
      body: JSON.stringify(f.boards[64]) });
    assert.equal(response.status, 429);
    assert.deepEqual(fs.readFileSync(path.join(f.home, 'boards.json')), before);
    await server.close(); server = null;
    const restarted = await startSharedServer({ home: f.home, managerToken, fingerprint: sharedFingerprint() });
    f.useServer(restarted);
    assert.equal(restarted.failedAttachments.length, 1);
    assert.equal(readRuntime(f.home, 'boards.json').length, 64);
  } finally { fs.renameSync(away, missing); }
});
