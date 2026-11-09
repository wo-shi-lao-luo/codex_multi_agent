/** Read-only loopback HTTP/SSE projection. Connections never hold a SQLite transaction. */
import http from 'node:http';
import { randomBytes, randomUUID, createHash, timingSafeEqual } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { publicSnapshot } from '../coordination/service.mjs';
import { BoardError } from '../domain/errors.mjs';
import { validateSessionProfile } from '../domain/session.mjs';

const CONTROL_TOKEN = /^[a-fA-F0-9]{64,256}$/;
// Startup and reopened browser tickets share one bounded, expiring pending set.
const TICKET_TTL_MS = 120000;
const MAX_PENDING_TICKETS = 8;
const CSP = "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; " +
  "object-src 'none'; base-uri 'none'; frame-ancestors 'none'";

/**
 * Start read-only browser routes and optional caller-token service controls.
 * The caller retains its token; close() shares one Promise and awaits onClose exactly once.
 * onClose owns only caller-selected cleanup; startup failure leaves that ownership with caller.
 */
export async function serve(board, { port = 0, serviceControlToken, onClose = () => {} } = {}) {
  if (!Number.isInteger(port) || port < 0 || port > 65535) {
    throw new BoardError('INVALID_INPUT', 'Port must be an integer from 0 to 65535.');
  }
  if (serviceControlToken !== undefined &&
    (typeof serviceControlToken !== 'string' || !CONTROL_TOKEN.test(serviceControlToken))) {
    throw new BoardError('INVALID_INPUT', 'Service control token must be 64 to 256 hex characters.');
  }
  if (typeof onClose !== 'function') {
    throw new BoardError('INVALID_INPUT', 'onClose must be a function.');
  }
  const { boardId, generation, sessionProfile } = board.snapshot().board;
  // Cache immutable context once; controls must not reread SQLite or follow mutable display labels.
  const sessionKey = sessionProfile === undefined ? undefined : validateSessionProfile(sessionProfile).sessionKey;
  const sessionIdentity = sessionKey === undefined ? {} : { sessionKey };
  const serviceId = randomUUID();
  const cookieName = `task_board_session_${serviceId.replaceAll('-', '')}`;
  const controlHash = serviceControlToken === undefined ? null :
    createHash('sha256').update(serviceControlToken).digest();
  serviceControlToken = undefined;
  let closing;
  const pendingTickets = new Map();
  /** Retire expired entry capabilities without revoking established browser session cookies. */
  function pruneTickets() {
    const now = Date.now();
    for (const [ticket, expiresAt] of pendingTickets) {
      if (now >= expiresAt) pendingTickets.delete(ticket);
    }
  }
  /** Mint without evicting another outstanding ticket; failed capacity never revokes sessions. */
  function mintTicket() {
    pruneTickets();
    if (pendingTickets.size >= MAX_PENDING_TICKETS) return null;
    const ticket = randomBytes(32).toString('hex');
    const expiresAt = Date.now() + TICKET_TTL_MS;
    pendingTickets.set(ticket, expiresAt);
    return { ticket, ticketExpiresAt: new Date(expiresAt).toISOString() };
  }
  const initialTicket = mintTicket().ticket;
  const session = randomBytes(32).toString('hex');
  const clients = new Set();
  let origin;
  const server = http.createServer(async (request, response) => {
    response.setHeader('Content-Security-Policy', CSP);
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Cache-Control', 'no-store');
    try {
      if (request.headers.host !== new URL(origin).host ||
        (request.headers.origin && request.headers.origin !== origin)) {
        response.writeHead(403).end();
        return;
      }
      const url = new URL(request.url, origin);
      if (request.url.length > 2048) {
        response.writeHead(414).end();
        return;
      }
      // Service controls use cached identity, never a browser session or a fresh DB read.
      if (['/_service/status', '/_service/stop', '/_service/open'].includes(url.pathname)) {
        if (!controlHash) {
          response.writeHead(404).end();
          return;
        }
        if (url.search) {
          response.writeHead(400).end();
          return;
        }
        const expectedMethod = url.pathname === '/_service/status' ? 'GET' : 'POST';
        if (request.method !== expectedMethod) {
          response.writeHead(405).end();
          return;
        }
        const token = /^Bearer ([a-fA-F0-9]{64,256})$/.exec(
          request.headers.authorization ?? '',
        )?.[1];
        if (!token || !CONTROL_TOKEN.test(token) ||
          !timingSafeEqual(createHash('sha256').update(token).digest(), controlHash)) {
          response.writeHead(401).end();
          return;
        }
        if (request.headers['x-task-board-service-id'] !== serviceId ||
          request.headers['x-task-board-id'] !== boardId ||
          request.headers['x-task-board-generation'] !== generation ||
          request.headers['x-task-board-session-key'] !== sessionKey) {
          response.writeHead(409).end();
          return;
        }
        const stopping = url.pathname === '/_service/stop';
        response.setHeader('Content-Type', 'application/json');
        if (url.pathname === '/_service/open') {
          const minted = mintTicket();
          if (!minted) {
            response.writeHead(429).end(JSON.stringify({ error: { code: 'TICKET_CAPACITY' } }));
            return;
          }
          response.end(JSON.stringify({ serviceId, boardId, generation, ...sessionIdentity, port: actualPort,
            url: origin, status: 'running', ticketUrl: `${origin}/?ticket=${minted.ticket}`,
            ticketExpiresAt: minted.ticketExpiresAt }));
          return;
        }
        // A stop response acknowledges acceptance; it does not claim cleanup completed.
        if (stopping) response.once('finish', () => { close().catch(() => {}); });
        response.end(JSON.stringify({ serviceId, boardId, generation, ...sessionIdentity, port: actualPort,
          status: stopping ? 'stopping' : 'running' }));
        return;
      }
      if (request.method !== 'GET') {
        response.writeHead(405).end();
        return;
      }
      pruneTickets();
      const ticket = /^\/\?ticket=([a-f0-9]{64})$/.exec(request.url)?.[1];
      if (ticket && pendingTickets.has(ticket)) {
        pendingTickets.delete(ticket);
        response.setHeader('Set-Cookie', `${cookieName}=${session}; HttpOnly; SameSite=Strict; Path=/`);
        response.writeHead(303, { Location: '/' }).end();
        return;
      }
      const authorized = request.headers.cookie?.split(';').some(value =>
        value.trim() === `${cookieName}=${session}`);
      if (!authorized) {
        response.writeHead(401).end();
        return;
      }
      if (url.pathname === '/api/snapshot') {
        response.setHeader('Content-Type', 'application/json');
        response.end(JSON.stringify(publicSnapshot(board.snapshot())));
        return;
      }
      if (url.pathname === '/api/events') {
        if (clients.size >= 32) {
          response.writeHead(503).end();
          return;
        }
        const after = request.headers['last-event-id'] ?? url.searchParams.get('after');
        const match = typeof after === 'string' && /^([^:]+):(\d+)$/.exec(after);
        if (!match || !Number.isSafeInteger(Number(match[2]))) {
          response.writeHead(400).end();
          return;
        }
        response.writeHead(200, { 'Content-Type': 'text/event-stream',
          Connection: 'keep-alive', 'X-Accel-Buffering': 'no' });
        response.flushHeaders();
        const client = { response, generation: match[1], eventSeq: Number(match[2]) };
        clients.add(client);
        response.on('close', () => clients.delete(client));
        push(client);
        return;
      }
      const assets = { '/': ['index.html', 'text/html'],
        '/app.js': ['app.js', 'text/javascript'], '/style.css': ['style.css', 'text/css'] };
      const asset = assets[url.pathname];
      if (!asset) {
        response.writeHead(404).end();
        return;
      }
      const content = await readFile(new URL(`../../web/${asset[0]}`, import.meta.url));
      response.setHeader('Content-Type', asset[1]);
      response.end(content);
    } catch {
      if (!response.headersSent) response.writeHead(503);
      response.end();
    }
  });

  /** A bounded event batch fills snapshot/subscription gaps; slow clients reconnect from storage. */
  function push(client) {
    try {
      const batch = board.eventsAfter({ generation: client.generation, eventSeq: client.eventSeq }, 100);
      if (batch.reset) {
        client.response.end(`event: reset\ndata: ${JSON.stringify({ reason: 'CURSOR_INVALID' })}\n\n`);
        clients.delete(client);
        return;
      }
      for (const event of batch.events) {
        const data = { generation: batch.generation, eventSeq: event.eventSeq,
          revision: event.boardRevision ?? batch.boardRevision, type: event.type,
          entityId: event.data?.taskId ?? null };
        const writable = client.response.write(`id: ${batch.generation}:${event.eventSeq}\n` +
          `event: change\ndata: ${JSON.stringify(data)}\n\n`);
        client.eventSeq = event.eventSeq;
        if (!writable) {
          client.response.destroy();
          clients.delete(client);
          break;
        }
      }
    } catch {
      client.response.destroy();
      clients.delete(client);
    }
  }
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, '127.0.0.1', resolve);
  });
  const actualPort = server.address().port;
  origin = `http://127.0.0.1:${actualPort}`;
  const polling = setInterval(() => { for (const client of clients) push(client); }, 250);
  const heartbeat = setInterval(() => {
    for (const client of clients) {
      if (!client.response.write(': keepalive\n\n')) client.response.destroy();
    }
  }, 15000);
  /** Stop only this listener and its clients, then await the caller-owned cleanup once. */
  function close() {
    if (closing) return closing;
    pendingTickets.clear();
    clearInterval(polling);
    clearInterval(heartbeat);
    for (const client of clients) client.response.destroy();
    clients.clear();
    closing = new Promise((resolve, reject) => {
      server.close(error => error ? reject(error) : resolve());
      server.closeAllConnections();
    }).then(() => onClose());
    return closing;
  }
  return {
    serviceId, boardId, generation, ...sessionIdentity, port: actualPort, url: origin,
    ticketUrl: `${origin}/?ticket=${initialTicket}`, close,
  };
}
