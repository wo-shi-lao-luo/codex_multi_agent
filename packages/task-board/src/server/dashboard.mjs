/** Independent loopback dashboard with bounded writes for prepared human actions. */
import http from 'node:http';
import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { createDashboardCatalog } from './dashboard-catalog.mjs';
import { validManualConfirmationTaskId } from '../coordination/acceptance.mjs';
import { validHumanStepResult } from '../coordination/human-step.mjs';
import { BoardError } from '../domain/errors.mjs';
import { StorageError } from '../storage/errors.mjs';

const capabilityFormat = /^[a-f0-9]{64}$/;
const maxStreams = 24;
const pollIntervalMs = 750;
const keepaliveMs = 15000;
const viewHeader = 'x-task-board-view';
const confirmationRoute = '/api/manual-confirmation';
const humanStepRoute = '/api/human-step';
const referenceRoute = '/api/reference';
const confirmationBodyLimit = 16384;
const confirmationConflictCodes = new Set([
  'CONFLICT', 'STALE_GENERATION', 'STALE_ASSIGNMENT', 'DEPENDENCY_BLOCKED', 'QUESTION_PENDING',
  'WORKSPACE_MISMATCH', 'UNAUTHORIZED', 'SOURCE_INVALID', 'SOURCE_UNAVAILABLE', 'UNSAFE_PATH',
  'IDEMPOTENCY_MISMATCH',
]);
const assets = new Map([
  ['/', ['dashboard.html', 'text/html;charset=utf-8']],
  ['/dashboard.js', ['dashboard.js', 'text/javascript;charset=utf-8']],
  ['/dashboard.css', ['dashboard.css', 'text/css;charset=utf-8']],
]);
const csp = "default-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; "
  + "form-action 'self'";

function digest(value) {
  return createHash('sha256').update(value).digest();
}

function matches(value, expected) {
  return typeof value === 'string' && capabilityFormat.test(value)
    && timingSafeEqual(digest(value), expected);
}

function json(response, status, value) {
  response.writeHead(status, { 'Content-Type': 'application/json;charset=utf-8' });
  response.end(JSON.stringify(value));
}

/** Decode only the bounded fields accepted by the selected dashboard write. */
async function confirmationInput(request, includeResult) {
  if (Number(request.headers['content-length']) > confirmationBodyLimit) return { tooLarge: true };
  const chunks = [];
  let size = 0;
  for await (const chunk of request.iterator({ destroyOnReturn: false })) {
    size += chunk.length;
    if (size > confirmationBodyLimit) return { tooLarge: true };
    chunks.push(chunk);
  }
  try {
    const body = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(Buffer.concat(chunks)));
    if (!body || Object.keys(body).length !== (includeResult ? 4 : 3) ||
      !validManualConfirmationTaskId(body.taskId) ||
      typeof body.generation !== 'string' || !/^[a-f0-9-]{36}$/.test(body.generation) ||
      !Number.isSafeInteger(body.taskRevision) || body.taskRevision < 1 ||
      includeResult && !validHumanStepResult(body.result)) return {};
    return { input: body };
  } catch {
    return {};
  }
}

/** Handle an authorized same-origin human action; the browser cannot supply board credentials. */
async function respondToConfirmation(request, response, catalog, location, includeResult) {
  const contentType = request.headers['content-type']?.split(';')[0].trim().toLowerCase();
  if (contentType !== 'application/json') {
    json(response, 415, { error: 'CONFIRMATION_REQUIRES_JSON' });
    return;
  }
  const { input, tooLarge } = await confirmationInput(request, includeResult);
  if (tooLarge) {
    response.setHeader('Connection', 'close');
    json(response, 413, { error: 'CONFIRMATION_TOO_LARGE' });
    return;
  }
  if (!input) {
    json(response, 400, { error: 'INVALID_CONFIRMATION' });
    return;
  }
  try {
    if (includeResult) catalog.completeHumanStep(location, input);
    else catalog.confirmManual(location, input);
    json(response, 200, { ok: true });
  } catch (error) {
    if (error instanceof BoardError && error.code === 'ARTIFACTS') {
      json(response, 503, { error: 'CONFIRMATION_ARTIFACT_PROTECTION' });
      return;
    }
    const rejected = (error instanceof BoardError || error instanceof StorageError) &&
      confirmationConflictCodes.has(error.code);
    json(response, rejected ? 409 : 503,
      { error: rejected ? 'CONFIRMATION_CONFLICT' : 'CONFIRMATION_UNAVAILABLE' });
  }
}

/** Start a loopback dashboard that never loads Lead tokens or activation credentials. */
export async function startDashboard({ projectRoots, port = 43180 }) {
  if (!Number.isInteger(port) || port < 0 || port > 65535) {
    throw Object.assign(new Error('Dashboard port is invalid.'), {
      code: 'DASHBOARD_INPUT',
    });
  }
  const catalog = createDashboardCatalog(projectRoots);
  const cookieName = `task_board_dashboard_${randomBytes(8).toString('hex')}`;
  const cookieValue = randomBytes(32).toString('hex');
  const cookieDigest = digest(cookieValue);
  const viewCapability = randomBytes(32).toString('hex');
  const viewDigest = digest(viewCapability);
  const groups = new Map();
  let streamCount = 0;
  let origin;

  /** Cookies cross ports on the same hostname. Require an origin-held capability as well. */
  function authorized(request) {
    const cookie = (request.headers.cookie ?? '').split(';').map(item => item.trim())
      .find(item => item.startsWith(`${cookieName}=`));
    return matches(cookie?.slice(cookieName.length + 1), cookieDigest)
      && matches(request.headers[viewHeader], viewDigest);
  }

  /** Forward only an invalidation cursor. Each client refetches authoritative snapshots. */
  function notify(response, revision) {
    if (!response.write(`event: revision\ndata: ${JSON.stringify({ revision })}\n\n`)) {
      response.destroy();
    }
  }

  /** A connection gets the latest cursor immediately and never holds a SQLite read transaction. */
  function subscribe(response, location) {
    if (streamCount >= maxStreams) {
      json(response, 503, { error: 'STREAM_CAPACITY' });
      return;
    }
    let group = groups.get(location.id);
    if (!group) {
      group = { location, revision: catalog.revision(location), clients: new Set() };
      groups.set(location.id, group);
    }
    response.writeHead(200, { 'Content-Type': 'text/event-stream;charset=utf-8' });
    group.clients.add(response);
    streamCount += 1;
    response.once('close', () => {
      group.clients.delete(response);
      streamCount -= 1;
      if (group.clients.size === 0) groups.delete(location.id);
    });
    notify(response, group.revision);
  }

  /** Reject untrusted origins before handling credentials. Browser inputs cannot pick files. */
  async function handle(request, response) {
    response.setHeader('Content-Security-Policy', csp);
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Referrer-Policy', 'no-referrer');
    const requestUrl = request.url ?? '';
    if (request.headers.host !== new URL(origin).host
        || (request.headers.origin && request.headers.origin !== origin)) {
      response.writeHead(403).end();
      return;
    }
    if (requestUrl.length > 2048) {
      response.writeHead(414).end();
      return;
    }
    const url = new URL(requestUrl, origin);
    if (!requestUrl.startsWith('/') || url.origin !== origin) {
      response.writeHead(400).end();
      return;
    }
    // A same-origin fetch can establish view access without a user-entered code.
    // This boundary guards against web origins, not other programs on the local machine.
    if (url.pathname === '/api/view' && request.method === 'POST' && !url.search) {
      const headers = request.headers;
      if (headers.origin !== origin || headers['sec-fetch-site'] !== 'same-origin'
          || headers['x-task-board-bootstrap'] !== '1') {
        response.writeHead(403).end();
        return;
      }
      response.writeHead(204, {
        'Set-Cookie': `${cookieName}=${cookieValue}; HttpOnly; SameSite=Strict; Path=/api/`,
        [viewHeader]: viewCapability,
      }).end();
      return;
    }
    const completingStep = url.pathname === humanStepRoute;
    const confirming = request.method === 'POST' &&
      (url.pathname === confirmationRoute || completingStep);
    if (confirming && (request.headers.origin !== origin ||
        request.headers['sec-fetch-site'] !== 'same-origin')) {
      response.writeHead(403).end();
      return;
    }
    if (request.method !== 'GET' && !confirming) {
      response.writeHead(405).end();
      return;
    }
    const asset = assets.get(url.pathname);
    if (asset && !url.search) {
      const bytes = await readFile(new URL(`../../web/${asset[0]}`, import.meta.url));
      response.writeHead(200, { 'Content-Type': asset[1] }).end(bytes);
      return;
    }
    if (!url.pathname.startsWith('/api/')) {
      response.writeHead(404).end();
      return;
    }
    if (request.headers['sec-fetch-site'] === 'cross-site' || !authorized(request)) {
      response.writeHead(401).end();
      return;
    }
    if (url.pathname === '/api/sessions' && !url.search) {
      json(response, 200, catalog.list());
      return;
    }
    const previewing = url.pathname === referenceRoute;
    if (!confirming && !previewing && url.pathname !== '/api/snapshot' && url.pathname !== '/api/events') {
      response.writeHead(404).end();
      return;
    }
    const id = url.searchParams.get('session') ?? '';
    const taskId = url.searchParams.get('task');
    const referenceId = url.searchParams.get('ref');
    if (url.searchParams.size !== (previewing ? 3 : 1) || !capabilityFormat.test(id) ||
        (previewing && (!validManualConfirmationTaskId(taskId) || !capabilityFormat.test(referenceId)))) {
      response.writeHead(400).end();
      return;
    }
    const location = catalog.lookup(id);
    if (!location) {
      json(response, 404, { error: 'SESSION_NOT_AVAILABLE' });
      return;
    }
    if (confirming) {
      await respondToConfirmation(request, response, catalog, location, completingStep);
      return;
    }
    if (previewing) {
      // The browser names a visible reference slot, never a path to open.
      let preview;
      try { preview = catalog.reference(location, taskId, referenceId); }
      catch { /* Internal filesystem and Board errors may contain private paths. */ }
      if (preview) json(response, 200, preview);
      else json(response, 404, { error: 'REFERENCE_NOT_AVAILABLE' });
      return;
    }
    try {
      if (url.pathname === '/api/events') subscribe(response, location);
      else json(response, 200, catalog.snapshot(location));
    } catch {
      json(response, 503, { error: 'SESSION_READ_FAILED' });
    }
  }

  const server = http.createServer({ requestTimeout: 5000, headersTimeout: 5000 },
    (request, response) => {
      handle(request, response).catch(() => {
        if (response.headersSent) response.destroy();
        else json(response, 500, { error: 'DASHBOARD_UNAVAILABLE' });
      });
    });
  server.maxConnections = 64;
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, '127.0.0.1', () => {
      origin = `http://127.0.0.1:${server.address().port}`;
      server.off('error', reject);
      resolve();
    });
  });
  // A slow or unavailable session closes its own streams. Other selections keep their cursors.
  const polling = setInterval(() => {
    for (const group of groups.values()) {
      try {
        const revision = catalog.revision(group.location);
        if (revision === group.revision) continue;
        group.revision = revision;
        for (const response of group.clients) notify(response, revision);
      } catch {
        for (const response of group.clients) response.end();
      }
    }
  }, pollIntervalMs);
  const keepalive = setInterval(() => {
    for (const group of groups.values()) {
      for (const response of group.clients) {
        if (!response.write(': keepalive\n\n')) response.destroy();
      }
    }
  }, keepaliveMs);
  let stopped;
  return {
    url: origin,
    /** Close both timers and all browser sockets. Repeated calls await the same shutdown. */
    close() {
      if (stopped) return stopped;
      clearInterval(polling);
      clearInterval(keepalive);
      stopped = new Promise((resolve) => {
        server.close(resolve);
        server.closeAllConnections();
      });
      return stopped;
    },
  };
}
