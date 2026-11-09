// Flat retained service identity controls work with SQLite explicitly disabled; no database fixture exists.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { resolve } from 'node:path';
import { serve } from '../../packages/task-board/src/server/server.mjs';

// Async child transport keeps the parent-owned HTTP listener responsive and captures exact CLI output.
function call(operation, input) {
  return new Promise((done, reject) => {
    const child = spawn(process.execPath, ['--no-experimental-sqlite',
      resolve('packages/task-board/src/cli/cli.mjs'), operation, '--stdin'],
    { stdio: ['pipe', 'pipe', 'pipe'] });
    let output = '';
    let errors = '';
    const timer = setTimeout(() => { child.kill(); reject(new Error('Owned CLI timeout')); }, 5000);
    child.stdout.on('data', chunk => { output += chunk; });
    child.stderr.on('data', chunk => { errors += chunk; });
    child.on('error', reject);
    child.on('close', code => {
      clearTimeout(timer);
      try { done({ code, reply: JSON.parse(output) }); }
      catch { reject(new Error(`Invalid CLI output ${code}: ${output} ${errors}`)); }
    });
    child.stdin.end(JSON.stringify(input));
  });
}

// Current owned listener reopens without SQLite, location flags or task/assignment effects.
test('ServiceOpen.cliWithoutSqliteOrBoard', async t => {
  const token = 'ab'.repeat(32);
  const board = { snapshot: () => ({ board: { boardId: 'cli-board', generation: 'cli-generation',
    schemaVersion: 3, boardRevision: 1, eventSeq: 1, replayFloor: 0 }, tasks: [], workers: [],
  assignments: [], questions: [], answers: [], dependencies: [], reservations: [], submissions: [],
  grants: [] }), eventsAfter: () => ({ events: [] }) };
  const service = await serve(board, { serviceControlToken: token });
  t.after(() => service.close());
  const response = await call('service-open', { url: service.url, port: service.port,
    serviceId: service.serviceId, boardId: 'cli-board', generation: 'cli-generation',
    serviceControlToken: token });
  assert.equal(response.code, 0, JSON.stringify(response.reply));
  assert.equal(response.reply.schemaVersion, 1);
  assert.equal(response.reply.operation, 'service-open');
  assert.equal(response.reply.result.status, 'running');
  assert.ok(!JSON.stringify(response.reply).includes(token));
  const identity = { url: service.url, port: service.port, serviceId: service.serviceId,
    boardId: 'cli-board', generation: 'cli-generation', serviceControlToken: token };
  // Startup plus the first successful open use two slots; six more reach the fixed capacity.
  for (let index = 0; index < 6; index++) {
    assert.equal((await call('service-open', identity)).code, 0);
  }
  const capacity = await call('service-open', identity);
  assert.equal(capacity.code, 2);
  assert.equal(capacity.reply.error.code, 'SERVICE_TICKET_CAPACITY');
});

// Data-only help advertises exactly the new operation before any SQLite/runtime/root gate.
test('ServiceOpen.helpWithoutSqlite', async () => {
  const { spawnSync } = await import('node:child_process');
  const result = spawnSync(process.execPath, ['--no-experimental-sqlite',
    resolve('packages/task-board/src/cli/cli.mjs'), 'help', '--operation', 'service-open'],
  { encoding: 'utf8', timeout: 5000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  const response = JSON.parse(result.stdout);
  assert.equal(response.ok, true);
  assert.equal(response.result.commands[0].operation, 'service-open');
});
