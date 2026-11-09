/** Owned lifecycle HTTP tests; fixed read snapshots are not database/browser E2E evidence. */
import test from 'node:test';
import assert from 'node:assert/strict';
import { serve } from '../../packages/task-board/src/server/server.mjs';

/** Provide complete empty read projections without database writes or user project access. */
function board(id) {
  return {
    snapshot: () => ({ board: { boardId: id, generation: `generation-${id}`,
      schemaVersion: 3, boardRevision: 1, eventSeq: 1, replayFloor: 0 },
    tasks: [], workers: [], assignments: [], questions: [], answers: [], dependencies: [],
    reservations: [], submissions: [], grants: [] }),
    eventsAfter: () => ({ events: [] }),
  };
}

// Scenario: two services at the same host but different ports authenticate into one cookie jar.
// Expected: both real snapshots remain authorized after both bootstraps. The host/path map
// deliberately excludes port, matching cookie scope, without claiming an actual browser engine.
test('Service.sharedCookieJar', async t => {
  const first = await serve(board('first'));
  t.after(() => first.close());
  const second = await serve(board('second'));
  t.after(() => second.close());
  const jar = new Map();
  for (const service of [first, second]) {
    const response = await fetch(service.ticketUrl, { redirect: 'manual',
      signal: AbortSignal.timeout(2000) });
    assert.equal(response.status, 303);
    const cookie = response.headers.get('set-cookie').split(';')[0];
    const separator = cookie.indexOf('=');
    jar.set(cookie.slice(0, separator), cookie.slice(separator + 1));
    await response.text();
  }
  const observed = [];
  for (const service of [first, second]) {
    const response = await fetch(new URL('/api/snapshot', service.url), {
      headers: { Cookie: [...jar].map(([key, value]) => `${key}=${value}`).join('; ') },
      signal: AbortSignal.timeout(2000),
    });
    observed.push(response.status);
    await response.text();
  }
  assert.deepEqual(observed, [200, 200], 'Both owned services must retain independent sessions');
});

/** Send literal HTTP headers, including Host, which browser fetch may forbid overriding. */
async function request(service, path, { method = 'GET', headers = {} } = {}) {
  const http = await import('node:http');
  return new Promise((resolve, reject) => {
    const call = http.request(new URL(path, service.url), { method, headers, agent: false }, reply => {
      let body = '';
      reply.setEncoding('utf8');
      reply.on('data', chunk => { body += chunk; });
      reply.on('end', () => resolve({ status: reply.statusCode, body, headers: reply.headers }));
    });
    call.setTimeout(2000, () => call.destroy(new Error('Owned request timeout')));
    call.on('error', reject);
    call.end();
  });
}

/** Caller retains the token outside serve's return value; cleanup closes only this owned listener. */
async function controlled(t, id, options = {}) {
  const { randomBytes } = await import('node:crypto');
  const serviceControlToken = randomBytes(32).toString('hex');
  const data = board(id);
  const original = data.snapshot();
  let reads = 0;
  data.snapshot = () => { reads++; return structuredClone(original); };
  const service = await serve(data, { serviceControlToken, ...options });
  t.after(() => service.close());
  const identity = { serviceControlToken, serviceId: service.serviceId,
    boardId: id, generation: `generation-${id}`, port: service.port, url: service.url };
  const headers = { Authorization: `Bearer ${serviceControlToken}`,
    'X-Task-Board-Service-Id': identity.serviceId, 'X-Task-Board-Id': id,
    'X-Task-Board-Generation': identity.generation };
  return { service, identity, headers, data, original, reads: () => reads };
}

// Scenario: invalid control credentials/identities/methods/query/Host/Origin reach an owned server.
// Expected: exact rejection categories, no cleanup, other service still live, token never echoed;
// browser cookie grants no stop authority, and direct serve without control token exposes no control.
test('Service.controlIdentity', async t => {
  const { serviceStatus, stopService } = await import('../../packages/task-board/src/server/control.mjs');
  let closed = 0;
  const first = await controlled(t, 'protected', { onClose: () => { closed++; } });
  const second = await controlled(t, 'other');
  assert.ok(!JSON.stringify(first.service).includes(first.identity.serviceControlToken));
  const bootstrap = await request(first.service, '/?ticket=' +
    new URL(first.service.ticketUrl).searchParams.get('ticket'));
  const cookie = bootstrap.headers['set-cookie'][0].split(';')[0];
  const cases = [
    { method: 'POST', headers: { Cookie: cookie }, expected: 401 },
    { method: 'POST', headers: { ...first.headers, Authorization: 'Bearer ' + '0'.repeat(64) }, expected: 401 },
    ...['X-Task-Board-Service-Id', 'X-Task-Board-Id', 'X-Task-Board-Generation'].map(key =>
      ({ method: 'POST', headers: { ...first.headers, [key]: 'wrong' }, expected: 409 })),
    { method: 'GET', headers: first.headers, expected: 405 },
    { method: 'POST', headers: { ...first.headers, Host: 'untrusted.invalid' }, expected: 403 },
    { method: 'POST', headers: { ...first.headers, Origin: 'http://untrusted.invalid' }, expected: 403 },
    { method: 'POST', headers: first.headers, query: '?token=must-not-authorize', expected: 400 },
  ];
  for (const scenario of cases) {
    const response = await request(first.service, '/_service/stop' + (scenario.query ?? ''), scenario);
    assert.equal(response.status, scenario.expected);
    assert.ok(!response.body.includes(first.identity.serviceControlToken));
    assert.equal(closed, 0);
    assert.equal((await serviceStatus(first.identity)).status, 'running');
    assert.equal((await serviceStatus(second.identity)).status, 'running');
  }
  const statusWrongMethod = await request(first.service, '/_service/status', {
    method: 'POST', headers: first.headers });
  assert.equal(statusWrongMethod.status, 405);
  await assert.rejects(stopService({ ...first.identity, url: second.service.url,
    port: second.service.port }), { code: 'SERVICE_CONTROL_REJECTED' });
  assert.equal((await serviceStatus(second.identity)).status, 'running');
  assert.equal(first.reads(), 1, 'Controls must use startup identity, not new snapshots');
  assert.deepEqual(first.data.snapshot(), first.original);
  const plain = await serve(board('no-controls'));
  t.after(() => plain.close());
  assert.equal((await request(plain, '/_service/status')).status, 404);
  assert.equal((await request(plain, '/_service/stop', { method: 'POST',
    headers: first.headers })).status, 404);
});

// Scenario: the backing read fails after startup; accepted stop runs delayed caller-owned cleanup.
// Expected: cached status remains exact, stop acknowledges only stopping, own port actually closes,
// close shares one Promise and invokes cleanup once; second service and database projection untouched.
test('Service.changedBoardClose', async t => {
  const { serviceStatus, stopService } = await import('../../packages/task-board/src/server/control.mjs');
  let closed = 0;
  let release;
  const pendingCleanup = new Promise(resolve => { release = resolve; });
  t.after(() => release());
  const first = await controlled(t, 'changing', { onClose: async () => {
    closed++;
    await pendingCleanup;
  } });
  const second = await controlled(t, 'survives');
  first.data.snapshot = () => { throw new Error('Controlled backing-read failure'); };
  const status = await serviceStatus(first.identity);
  assert.deepEqual(status, { serviceId: first.identity.serviceId, boardId: 'changing',
    generation: first.identity.generation, port: first.identity.port, status: 'running' });
  const accepted = await stopService(first.identity);
  assert.equal(accepted.status, 'stopping');
  const closing = first.service.close();
  assert.strictEqual(first.service.close(), closing);
  let completed = false;
  closing.then(() => { completed = true; });
  assert.equal(completed, false, 'Acceptance must not claim delayed cleanup completion');
  await assert.rejects(serviceStatus(first.identity), { code: 'SERVICE_UNAVAILABLE' });
  assert.equal((await serviceStatus(second.identity)).status, 'running');
  assert.equal(completed, false, 'Port closure does not imply caller cleanup finished');
  release();
  await closing;
  assert.equal(closed, 1);
  assert.equal(first.reads(), 1);
});

// Scenario: caller helper receives off-loopback/port-inconsistent identity or an owned closed port.
// Expected: invalid inputs reject before transport, closed listener returns state-unknown unavailable;
// no retry/discovery/credential echo or unrelated listener shutdown occurs.
test('Service.clientBoundary', async t => {
  const { serviceStatus } = await import('../../packages/task-board/src/server/control.mjs');
  const own = await controlled(t, 'client');
  for (const patch of [
    { url: 'http://example.invalid/' }, { port: own.identity.port + 1 },
    { url: own.service.url + '/extra' }, { serviceControlToken: 'invalid' },
  ]) await assert.rejects(serviceStatus({ ...own.identity, ...patch }), { code: 'INVALID_INPUT' });
  await assert.rejects(serviceStatus(own.identity, { timeoutMs: 0 }), { code: 'INVALID_INPUT' });
  assert.equal((await serviceStatus(own.identity)).status, 'running');
  await own.service.close();
  await assert.rejects(serviceStatus(own.identity, { timeoutMs: 100 }),
    error => error.code === 'SERVICE_UNAVAILABLE' &&
      !error.message.includes(own.identity.serviceControlToken));
});


// Open mints a new one-use bootstrap without database reads or invalidating existing browser sessions.
test('Service.openFreshTicketsAndSessions', async t => {
  const own = await controlled(t, 'open');
  const first = await request(own.service, '/_service/open', { method: 'POST', headers: own.headers });
  assert.equal(first.status, 200, first.body);
  const firstResult = JSON.parse(first.body);
  assert.equal(firstResult.serviceId, own.identity.serviceId);
  assert.equal(firstResult.boardId, own.identity.boardId);
  assert.equal(firstResult.generation, own.identity.generation);
  assert.equal(firstResult.port, own.identity.port);
  assert.equal(firstResult.status, 'running');
  assert.equal(own.reads(), 1, 'Open must use startup cached identity without snapshot access');
  const ticket1 = new URL(firstResult.ticketUrl);
  const consumed = await request(own.service, ticket1.pathname + ticket1.search);
  assert.equal(consumed.status, 303);
  const cookie1 = consumed.headers['set-cookie'][0].split(';')[0];
  assert.equal((await request(own.service, '/api/snapshot', { headers: { Cookie: cookie1 } })).status, 200);
  const reads = own.reads();
  const second = await request(own.service, '/_service/open', { method: 'POST', headers: own.headers });
  assert.equal(second.status, 200, second.body);
  const ticket2 = new URL(JSON.parse(second.body).ticketUrl);
  assert.notEqual(ticket2.search, ticket1.search);
  assert.equal(own.reads(), reads, 'Fresh open cannot re-read the backing board');
  const consumed2 = await request(own.service, ticket2.pathname + ticket2.search);
  assert.equal(consumed2.status, 303);
  const cookie2 = consumed2.headers['set-cookie'][0].split(';')[0];
  for (const cookie of [cookie1, cookie2]) {
    assert.equal((await request(own.service, '/api/snapshot', { headers: { Cookie: cookie } })).status, 200);
  }
  const reused = await request(own.service, ticket1.pathname + ticket1.search);
  assert.equal(reused.status, 401);
  assert.equal(reused.headers['set-cookie'], undefined);
});

// Browser cookies and malformed controls cannot mint tickets or alter the cached service/database.
test('Service.openControlBoundary', async t => {
  const own = await controlled(t, 'open-boundary');
  const boot = await request(own.service, new URL(own.service.ticketUrl).pathname +
    new URL(own.service.ticketUrl).search);
  const cookie = boot.headers['set-cookie'][0].split(';')[0];
  const scenarios = [
    { method: 'POST', headers: { Cookie: cookie }, expected: 401 },
    { method: 'POST', headers: { ...own.headers, Authorization: 'Bearer ' + '0'.repeat(64) }, expected: 401 },
    ...['X-Task-Board-Service-Id', 'X-Task-Board-Id', 'X-Task-Board-Generation'].map(key =>
      ({ method: 'POST', headers: { ...own.headers, [key]: 'wrong' }, expected: 409 })),
    { method: 'GET', headers: own.headers, expected: 405 },
    { method: 'POST', headers: { ...own.headers, Host: 'untrusted.invalid' }, expected: 403 },
    { method: 'POST', headers: { ...own.headers, Origin: 'http://untrusted.invalid' }, expected: 403 },
    { method: 'POST', headers: own.headers, query: '?ticket=not-authority', expected: 400 },
  ];
  for (const scenario of scenarios) {
    const response = await request(own.service, '/_service/open' + (scenario.query ?? ''), scenario);
    assert.equal(response.status, scenario.expected, response.body);
    assert.ok(!response.body.includes(own.identity.serviceControlToken));
  }
  assert.equal(own.reads(), 1);
  const plain = await serve(board('open-no-control'));
  t.after(() => plain.close());
  assert.equal((await request(plain, '/_service/open', { method: 'POST', headers: own.headers })).status, 404);
});

// Eight pending tickets include startup; expired tickets free capacity without revoking valid sessions.
test('Service.openCapacityAndExpiry', async t => {
  const own = await controlled(t, 'open-capacity');
  let now = Date.now();
  t.mock.method(Date, 'now', () => now);
  const tickets = [];
  for (let index = 0; index < 7; index++) {
    const result = await request(own.service, '/_service/open', { method: 'POST', headers: own.headers });
    assert.equal(result.status, 200, result.body);
    const data = JSON.parse(result.body);
    assert.equal(new Date(data.ticketExpiresAt).getTime(), now + 120000);
    tickets.push(new URL(data.ticketUrl));
  }
  const capacity = await request(own.service, '/_service/open', { method: 'POST', headers: own.headers });
  assert.equal(capacity.status, 429);
  assert.equal(JSON.parse(capacity.body).error.code, 'TICKET_CAPACITY');
  const { serviceOpen } = await import('../../packages/task-board/src/server/control.mjs');
  await assert.rejects(serviceOpen(own.identity), { code: 'SERVICE_TICKET_CAPACITY' });
  const stillValid = await request(own.service, tickets[0].pathname + tickets[0].search);
  assert.equal(stillValid.status, 303, 'Capacity refusal must not evict a still-valid ticket');
  now += 120000;
  assert.equal((await request(own.service, tickets[1].pathname + tickets[1].search)).status, 401);
  assert.equal((await request(own.service, '/_service/open', {
    method: 'POST', headers: own.headers })).status, 200);
  assert.equal(own.reads(), 1);
});

// Client rejects wrong identity/origin/path/query/token spelling before returning a browser URL.
test('Service.openClientValidatesResponse', async t => {
  const { createServer } = await import('node:http');
  const { serviceOpen } = await import('../../packages/task-board/src/server/control.mjs');
  assert.equal(typeof serviceOpen, 'function', 'Service-open client interface must be implemented');
  let result;
  let calls = 0;
  const server = createServer((req, res) => {
    calls++;
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(result));
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const port = server.address().port;
  const url = `http://127.0.0.1:${port}/`;
  const identity = { serviceId: 'owned-client', boardId: 'owned-board', generation: 'owned-generation',
    port, url, serviceControlToken: 'ab'.repeat(32) };
  const valid = { ...identity, url: new URL(url).origin, serviceControlToken: undefined, status: 'running',
    ticketUrl: url + '?ticket=' + 'cd'.repeat(32), ticketExpiresAt: '2000-01-01T00:00:00.000Z' };
  // An old-but-valid timestamp shape is accepted: clients cannot assume synchronized clocks.
  result = valid;
  assert.equal((await serviceOpen(identity)).ticketUrl, valid.ticketUrl);
  result = { ...valid, serviceControlToken: identity.serviceControlToken, unexpected: 'untrusted-extra' };
  let sanitized;
  try { sanitized = await serviceOpen(identity); }
  catch (error) { assert.equal(error.code, 'SERVICE_CONTROL_REJECTED'); }
  if (sanitized) {
    assert.ok(!JSON.stringify(sanitized).includes(identity.serviceControlToken));
    const allowed = ['serviceId', 'boardId', 'generation', 'port', 'url', 'status',
      'ticketUrl', 'ticketExpiresAt'];
    assert.ok(Object.keys(sanitized).every(key => allowed.includes(key)));
  }
  for (const patch of [
    { boardId: 'wrong-board' }, { port: port + 1 }, { url: 'http://example.invalid/' },
    { ticketUrl: 'http://example.invalid/?ticket=' + 'cd'.repeat(32) },
    { ticketUrl: url + 'extra?ticket=' + 'cd'.repeat(32) },
    { ticketUrl: url + '?ticket=' + 'CD'.repeat(32) },
    { ticketUrl: url + '?ticket=' + 'cd'.repeat(32) + '&extra=1' },
    { ticketUrl: url + '?ticket=' + 'cd'.repeat(32) + '&ticket=' + 'ef'.repeat(32) },
    { ticketUrl: url + '?ticket=%63' + 'cd'.repeat(31) + 'd' },
    { ticketUrl: url + '?ticket=' + 'cd'.repeat(32) + '#fragment' },
    { ticketExpiresAt: 'invalid timestamp' },
  ]) {
    result = { ...valid, ...patch };
    const before = calls;
    await assert.rejects(serviceOpen(identity), { code: 'SERVICE_CONTROL_REJECTED' });
    assert.equal(calls, before + 1, 'Rejected response must not trigger a retry');
  }
});
