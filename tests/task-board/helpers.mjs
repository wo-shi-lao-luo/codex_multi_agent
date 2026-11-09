// Exercise the real CLI using disposable projects; never touch user homes or model services.
import { spawn } from 'node:child_process';
import { mkdtemp, mkdir, rm } from 'node:fs/promises';
import { resolve, join, dirname } from 'node:path';
import { randomBytes, createHash } from 'node:crypto';
import assert from 'node:assert/strict';

export const cli = resolve('packages/task-board/src/cli/cli.mjs');
// Generate caller-owned fixture credentials with the production minimum entropy.
export const secret = () => randomBytes(32).toString('hex');

// Run a real CLI request, isolating ancestor Git discovery to the declared project by default.
// Set isolateGit:false for deliberate ancestor tests; overrides affect only this owned child.
// Optional entrypoint selects a frozen packaged CLI; omitted entrypoint preserves source CLI behavior.
export function invoke(project, board, operation, request, options = {}) {
  return new Promise((done, reject) => {
    const args = [options.entrypoint ?? cli, operation, '--project-root', project,
      '--board-path', board, '--stdin'];
    if (options.sessionKey !== undefined) args.push('--session-key', options.sessionKey);
    const child = spawn(process.execPath, args, {
      stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env,
        ...(options.isolateGit === false ? {} : { GIT_CEILING_DIRECTORIES: dirname(resolve(project)) }),
        ...options.env },
    });
    let stdout = '';
    let stderr = '';
    const timeout = setTimeout(() => { child.kill(); reject(new Error('CLI timeout')); }, 10000);
    child.stdout.on('data', data => { stdout += data; });
    child.stderr.on('data', data => { stderr += data; });
    child.on('error', reject);
    child.on('close', code => {
      clearTimeout(timeout);
      try { done({ code, reply: JSON.parse(stdout), stderr }); }
      catch { reject(new Error(`Invalid CLI JSON, exit ${code}: ${stderr}`)); }
    });
    child.stdin.end(JSON.stringify(request));
  });
}

// Create an isolated project with real registration/grant helpers and owner-scoped cleanup.
export async function fixture(t) {
  const parent = resolve('_work/task-board/test-fixtures');
  await mkdir(parent, { recursive: true });
  const project = await mkdtemp(join(parent, 'p0-'));
  const children = [];
  t.after(async () => {
    for (const child of children) {
      if (child.exitCode !== null || child.signalCode !== null) continue;
      const closed = new Promise(done => child.once('close', done));
      child.kill();
      await closed;
    }
    await rm(project, { recursive: true, force: true });
  });
  await mkdir(join(project, 'src'));
  const board = join(project, '_work', 'board');
  const leadToken = secret();
  let generation;
  let sequence = 0;
  async function raw(operation, payload = {}) {
    return invoke(project, board, operation, {
      operationId: `op-${++sequence}`, actorId: 'lead', leadToken, generation, ...payload,
    });
  }
  async function ok(operation, payload = {}) {
    const response = await raw(operation, payload);
    assert.equal(response.code, 0, `${operation}: ${JSON.stringify(response.reply)}`);
    assert.equal(response.reply.ok, true);
    return response.reply;
  }
  const initialized = await ok('initialize');
  generation = initialized.generation;
  const workers = {};
  async function worker(id, role = 'backend') {
    const workerToken = secret();
    workers[id] = workerToken;
    await ok('register', { worker: { id, hostId: `fixture-${id}`, role,
      mode: 'direct', capabilities: ['write'], workerToken } });
  }
  async function task(id, write = `src/${id}.mjs`, dependencies = []) {
    await ok('add', { task: { id, title: id, outcome: 'Verified output',
      sourceRefs: [`fixture/work#${id}`], acceptanceRefs: [`fixture/accept#${id}`],
      eligibleRoles: ['backend'], scope: { read: [], write: [write] },
      resources: [], dependencies } });
    await ok('approve', { taskId: id, taskRevision: 1 });
  }
  async function grant(workerId, taskId) {
    const current = await ok('show', { taskId });
    await ok('grant', { workerId, taskId,
      approvalRevision: current.result.task.approvalRevision });
  }
  function claim(workerId, taskId, operationId = `claim-${workerId}-${taskId}`) {
    return raw('claim', { operationId, actorId: workerId, workerToken: workers[workerId],
      taskId, taskRevision: 2, claimToken: secret() });
  }
  return { project, board, raw, ok, worker, task, grant, claim, workers, children,
    generation, leadToken };
}

// Recursively serialized public results must never expose caller credentials or their hashes.
// Check exact fixture secrets, their SHA256 values, and prohibited credential field names.
export function assertRedacted(reply, tokens) {
  const serialized = JSON.stringify(reply);
  for (const token of tokens) {
    assert.ok(!serialized.includes(token), 'Public response leaked a caller credential');
    const hash = createHash('sha256').update(token).digest('hex');
    assert.ok(!serialized.includes(hash), 'Public response leaked a caller credential hash');
  }
  assert.ok(!/leadTokenHash|workerTokenHash|tokenHash/.test(serialized),
    'Public response leaked a credential hash field');
}
