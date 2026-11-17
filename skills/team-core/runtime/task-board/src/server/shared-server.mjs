/** One listener, independent in-process Board endpoints. Browser routes cannot mount files. */
import http from 'node:http';
import path from 'node:path';
import { randomUUID, createHash, timingSafeEqual } from 'node:crypto';
import { openBoard } from '../storage/index.mjs';
import { tokenHash } from '../coordination/service.mjs';
import { serve } from './server.mjs';
import { serviceOpen } from './control.mjs';
import { readRuntime, writeRuntime, sharedError } from '../activation/shared-registry.mjs';

export const WELCOME = '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>任务看板入口</title>'
  + '<h1>任务看板服务已就绪</h1><p>请从对应 Codex 会话重新打开授权入口。直接输入地址或入口过期时，无法读取任务。</p>'
  + '<p>此页不会列出其他会话或任务。</p></html>';

export async function startSharedServer({ home, managerToken, fingerprint, port = 0 }) {
  if (!/^[a-f0-9]{64}$/.test(managerToken) || !/^[a-f0-9]{64}$/.test(fingerprint)) throw sharedError('INVALID_INPUT');
  const hubId = randomUUID(), mounts = new Map();
  let descriptors = readRuntime(home, 'boards.json') ?? [];
  if (!Array.isArray(descriptors) || descriptors.length > 64) throw sharedError('SHARED_STATE_INVALID');
  let origin;
  let mutation = Promise.resolve();
  const managerHash = createHash('sha256').update(managerToken).digest(); managerToken = undefined;
  const persist = () => writeRuntime(home, 'boards.json', descriptors);
  const identity = () => ({ protocol: 1, hubId, fingerprint, port: server.address().port, url: origin, status: 'running' });

  async function mount(input, retained) {
    const location = retained?.location ?? input?.location;
    if (!location || !/^[a-f0-9]{64}$/.test(location.sessionKey)) throw sharedError('INVALID_INPUT');
    const board = openBoard({ ...location, readOnly: true });
    let owns = true;
    try {
      const meta = board.metadata();
      const leadHash = retained?.leadTokenHash ?? tokenHash(input.leadToken);
      const controlHash = retained?.controlHash ?? tokenHash(input.serviceControlToken);
      if (!/^[a-f0-9]{64}$/.test(controlHash) || meta.leadId !== (retained?.actorId ?? input.actorId)
        || meta.leadTokenHash !== leadHash || meta.generation !== (retained?.generation ?? input.generation)
        || retained && meta.boardId !== retained.boardId || meta.sessionProfile?.sessionKey !== location.sessionKey) {
        throw sharedError('SHARED_BOARD_REJECTED');
      }
      const key = location.sessionKey, existing = mounts.get(key);
      if (existing) {
        if (existing.descriptor.controlHash !== controlHash || existing.descriptor.leadTokenHash !== leadHash
          || existing.service.boardId !== meta.boardId || existing.service.generation !== meta.generation
          || existing.descriptor.location.projectRoot !== meta.projectRoot
          || existing.descriptor.location.boardPath !== path.relative(meta.projectRoot,
            path.resolve(location.projectRoot, location.boardPath))) throw sharedError('SHARED_BOARD_REJECTED');
        return await serviceOpen({ ...existing.service, serviceControlToken: input.serviceControlToken });
      }
      // Failed rehydrations retain their durable reservation. Do not silently discard them
      // or append a 65th descriptor that would make the entire next startup invalid.
      if (mounts.size >= 64 || descriptors.length >= 64
          && !descriptors.some(item => item.location.sessionKey === key)) throw sharedError('SHARED_CAPACITY');
      const descriptor = { location: { projectRoot: meta.projectRoot,
        boardPath: path.relative(meta.projectRoot, path.resolve(location.projectRoot, location.boardPath)), sessionKey: key },
        actorId: meta.leadId, boardId: meta.boardId, generation: meta.generation,
        leadTokenHash: leadHash, controlHash, serviceId: retained?.serviceId ?? randomUUID() };
      let committed = false;
      const service = await serve(board, { sharedServer: server, hubId, routeBase: `/boards/${key}/`,
        retainedServiceId: descriptor.serviceId, retainedControlHash: controlHash,
        onClose() {
          board.close(); mounts.delete(key);
          if (committed) { descriptors = descriptors.filter(d => d.location.sessionKey !== key); persist(); }
        } });
      const previous = descriptors;
      mounts.set(key, { service, descriptor }); owns = false;
      descriptors = descriptors.filter(d => d.location.sessionKey !== key); descriptors.push(descriptor);
      try { persist(); committed = true; }
      catch (error) { descriptors = previous; await service.close(); throw error; }
      const { close, handler, ...publicIdentity } = service;
      return publicIdentity;
    } finally { if (owns) board.close(); }
  }

  const server = http.createServer(async (request, response) => {
    response.setHeader('Cache-Control', 'no-store'); response.setHeader('Referrer-Policy', 'no-referrer');
    response.setHeader('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'; base-uri 'none'");
    try {
      if (request.headers.host !== new URL(origin).host || request.headers.origin && request.headers.origin !== origin) {
        response.writeHead(403).end(); return;
      }
      if (request.url.length > 2048) { response.writeHead(414).end(); return; }
      const url = new URL(request.url, origin);
      if (url.pathname.startsWith('/_hub/')) {
        const token = /^Bearer ([a-f0-9]{64})$/.exec(request.headers.authorization ?? '')?.[1];
        if (!token || !timingSafeEqual(createHash('sha256').update(token).digest(), managerHash)
          || request.headers['x-task-board-hub-id'] !== hubId || url.search) { response.writeHead(401).end(); return; }
        if (url.pathname === '/_hub/status' && request.method === 'GET') {
          response.setHeader('Content-Type', 'application/json'); response.end(JSON.stringify(identity())); return;
        }
        if (url.pathname === '/_hub/stop' && request.method === 'POST') {
          if (mounts.size) { response.writeHead(409).end(); return; }
          response.once('finish', () => server.close()); response.end(JSON.stringify({ ...identity(), status: 'stopping' })); return;
        }
        if (url.pathname !== '/_hub/attach' || request.method !== 'POST') { response.writeHead(405).end(); return; }
        const chunks = []; let size = 0;
        for await (const chunk of request) {
          size += chunk.length; if (size > 262144) { response.writeHead(413).end(); return; } chunks.push(chunk);
        }
        const input = JSON.parse(Buffer.concat(chunks).toString('utf8'));
        const pending = mutation.then(() => mount(input));
        mutation = pending.catch(() => {});
        const attached = await pending;
        response.setHeader('Content-Type', 'application/json'); response.end(JSON.stringify(attached)); return;
      }
      const match = /^\/boards\/([a-f0-9]{64})\/(.*)$/.exec(url.pathname);
      const endpoint = match && mounts.get(match[1]);
      if (endpoint) { request.url = '/' + match[2] + url.search; await endpoint.service.handler(request, response); return; }
      if (match && /^api\//.test(match[2])) { response.writeHead(401).end(); return; }
      if (request.method !== 'GET') { response.writeHead(405).end(); return; }
      // Generic 200 avoids browser transport-error screens; it never enumerates Board identities.
      response.setHeader('Content-Type', 'text/html; charset=utf-8'); response.end(WELCOME);
    } catch (error) {
      if (!response.headersSent) response.writeHead(error.code === 'SHARED_CAPACITY' ? 429 : 403);
      response.end(JSON.stringify({ error: { code: 'SHARED_BOARD_REJECTED' } }));
    }
  });
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(port, '127.0.0.1', resolve); });
  origin = `http://127.0.0.1:${server.address().port}`;
  const failed = [];
  for (const descriptor of [...descriptors]) {
    try { await mount(null, descriptor); } catch { failed.push(descriptor.location?.sessionKey); }
  }
  return { ...identity(), failedAttachments: failed,
    async close() {
      // Shutdown retains authenticated descriptors for future rehydration; not a Board detach.
      const saved = [...descriptors];
      for (const endpoint of [...mounts.values()]) await endpoint.service.close();
      descriptors = saved; persist();
      await new Promise(resolve => { server.close(resolve); server.closeAllConnections(); });
    } };
}
