// CASE-20/23: real loopback HTTP/SSE must bridge snapshot gaps and reconnect without lost commits.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { cli, fixture, assertRedacted } from './helpers.mjs';

// Launch an owned service and exchange its one-use ticket for the required session cookie.
async function serve(t, f) {
  const child = spawn(process.execPath, [cli, 'serve', '--project-root', f.project,
    '--board-path', f.board, '--stdin'], { stdio: ['pipe', 'pipe', 'pipe'], env: { ...process.env,
      GIT_CEILING_DIRECTORIES: dirname(resolve(f.project)) } });
  f.children.push(child);
  child.stdin.end(JSON.stringify({ actorId: 'lead', leadToken: f.leadToken,
    generation: f.generation, port: 0 }));
  const result = await new Promise((done, reject) => {
    let output = '';
    let errors = '';
    const timer = setTimeout(() => reject(new Error(`Serve timeout: ${errors}`)), 10000);
    child.stderr.on('data', data => { errors += data; });
    child.stdout.on('data', data => {
      output += data;
      if (!output.includes('\n')) return;
      clearTimeout(timer);
      try { done(JSON.parse(output.split('\n')[0])); } catch (error) { reject(error); }
    });
    child.on('error', reject);
    child.once('exit', code => { clearTimeout(timer); reject(new Error(`Serve exited ${code}: ${output} ${errors}`)); });
  });
  assert.equal(result.ok, true, JSON.stringify(result));
  const ticket = await fetch(result.result.ticketUrl, { redirect: 'manual' });
  assert.equal(ticket.status, 303);
  const cookie = ticket.headers.get('set-cookie').split(';')[0];
  return { url: result.result.url, cookie };
}

// Open one real authenticated SSE connection and parse bounded event frames until cleanup.
async function stream(t, service, cursor) {
  const abort = new AbortController();
  t.after(() => abort.abort());
  const response = await fetch(new URL(`/api/events?after=${encodeURIComponent(cursor)}`,
    service.url), { headers: { Cookie: service.cookie }, signal: abort.signal });
  assert.equal(response.status, 200);
  const reader = response.body.getReader();
  let buffer = '';
  const decoder = new TextDecoder();
  async function next() {
    const deadline = setTimeout(() => abort.abort(), 2500);
    try {
      while (true) {
        const end = buffer.indexOf('\n\n');
        if (end >= 0) {
          const block = buffer.slice(0, end);
          buffer = buffer.slice(end + 2);
          const data = block.split('\n').filter(line => line.startsWith('data:'))
            .map(line => line.slice(5).trim()).join('\n');
          if (!data) continue;
          return { type: block.match(/^event:\s*(.+)$/m)?.[1],
            id: block.match(/^id:\s*(.+)$/m)?.[1], data: JSON.parse(data) };
        }
        const chunk = await reader.read();
        assert.equal(chunk.done, false, 'SSE ended before expected event');
        buffer += decoder.decode(chunk.value, { stream: true }).replaceAll('\r\n', '\n');
      }
    } finally { clearTimeout(deadline); }
  }
  return { next, close: () => abort.abort() };
}

// A gap commit, live commit and disconnected commit must each arrive exactly once in order.
test('P0.snapshotLiveReconnect', async t => {
  const f = await fixture(t);
  const service = await serve(t, f);
  const snapshotResponse = await fetch(new URL('/api/snapshot', service.url),
    { headers: { Cookie: service.cookie } });
  assert.equal(snapshotResponse.status, 200);
  const snapshot = await snapshotResponse.json();
  assertRedacted(snapshot, [f.leadToken]);
  // Commit between snapshot and subscription: the durable event must still arrive.
  await f.worker('gap-worker');
  const events = await stream(t, service, `${snapshot.generation}:${snapshot.eventSeq}`);
  const gap = await events.next();
  assert.equal(gap.type, 'change');
  assert.equal(gap.data.eventSeq, snapshot.eventSeq + 1);
  assert.equal(gap.data.generation, snapshot.generation);
  const started = Date.now();
  await f.worker('live-worker');
  const live = await events.next();
  assert.equal(live.data.eventSeq, gap.data.eventSeq + 1);
  assert.ok(Date.now() - started <= 2000, 'Committed change exceeded local two-second target');
  events.close();
  await f.worker('offline-worker');
  const reconnect = await stream(t, service, live.id);
  const caughtUp = await reconnect.next();
  assert.equal(caughtUp.data.eventSeq, live.data.eventSeq + 1);
  reconnect.close();
  const stale = await stream(t, service, `stale-generation:${live.data.eventSeq}`);
  const reset = await stale.next();
  assert.equal(reset.type, 'reset');
  assert.equal(reset.data.reason, 'CURSOR_INVALID');
  stale.close();
  const denied = await fetch(new URL('/api/snapshot', service.url));
  assert.equal(denied.status, 401);
});
