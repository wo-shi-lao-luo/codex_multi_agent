// Native input boundaries: copied candidate only, real CLI/SQLite and isolated owned services.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdir, mkdtemp, readFile, writeFile, cp, rm, readdir } from 'node:fs/promises';
import { resolve, join, dirname } from 'node:path';
import { createHash } from 'node:crypto';
import { invoke, secret } from './helpers.mjs';

const digest = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
const entry = resolve('packages/task-board/src/cli/activation.mjs');
const quote = value => `'${value.replaceAll("'", "''")}'`;
async function fixture(t) {
  const parent = resolve('_work/task-board/test-fixtures');
  await mkdir(parent, { recursive: true });
  const root = await mkdtemp(join(parent, 'activation-input-'));
  const request = { action: 'activate', actorId: 'lead', executionApproved: true,
    sessionProfile: { hostId: 'fixture-host', mainSessionId: 'fixture-main', projectId: 'fixture-project',
      projectName: '创作工作台', sessionName: '团队开发' },
    task: { id: 'input-check', title: '整理演示任务', outcome: '保留中文任务与会话名称',
      sourceRefs: ['fixture/work#input'], acceptanceRefs: ['fixture/accept#input'],
      scope: { read: [], write: [] } }, leadToken: secret(), claimToken: secret(), serviceControlToken: secret() };
  const board = `_work/task-board/sessions/v1/${digest(['codex-board-session-v1', 'fixture-host', 'fixture-main'])}`;
  const sessionKey = digest(['codex-board-context-v1', 'fixture-host', 'fixture-main', 'fixture-project']);
  t.after(async () => {
    let journal;
    try { journal = JSON.parse(await readFile(join(root, board, 'activation.json'), 'utf8')); }
    catch (error) { if (error.code !== 'ENOENT') throw error; }
    if (journal?.service) {
      const stopped = await invoke(root, board, 'service-stop', { ...journal.service,
        serviceControlToken: request.serviceControlToken }, { sessionKey });
      assert.equal(stopped.code, 0, 'Confirm owned service stop before fixture removal');
    }
    await rm(root, { recursive: true, force: true });
  });
  async function wrapper(cp936 = false) {
    const skill = join(root, 'candidate', 'skills', 'team-core');
    await mkdir(join(skill, 'scripts'), { recursive: true });
    await mkdir(join(skill, 'runtime'), { recursive: true });
    for (const file of ['activate-board.ps1', 'board-runtime.ps1']) {
      await cp(resolve('skills/team-core/scripts', file), join(skill, 'scripts', file));
    }
    await cp(resolve('skills/team-core/runtime/node-runtime.json'), join(skill, 'runtime/node-runtime.json'));
    await cp(resolve('packages/task-board'), join(skill, 'runtime/task-board'), { recursive: true });
    const target = join(skill, 'scripts/activate-board.ps1');
    if (cp936) {
      // Simulate the observed host Console decoding before running the unchanged wrapper body.
      const text = await readFile(target, 'utf8');
      await writeFile(target, text.replace("$ErrorActionPreference = 'Stop'",
        "[Console]::InputEncoding = [Text.Encoding]::GetEncoding(936)\n$ErrorActionPreference = 'Stop'"));
    }
    return target;
  }
  async function assertChinese() {
    const observed = await invoke(root, board, 'inspect', { actorId: 'lead', leadToken: request.leadToken }, { sessionKey });
    assert.equal(observed.code, 0, JSON.stringify(observed.reply));
    assert.equal(observed.reply.result.sessionProfile.projectName, request.sessionProfile.projectName);
    assert.equal(observed.reply.result.sessionProfile.sessionName, request.sessionProfile.sessionName);
    assert.equal(observed.reply.result.tasks[0].title, request.task.title);
  }
  return { root, request, board, sessionKey, wrapper, assertChinese };
}

for (const pipeline of [false, true]) {
  test(`INPUT.CP936 console preserves UTF8 JSON through ${pipeline ? 'native PowerShell pipeline -File' : 'Node OS stdin'}`, {
    skip: process.platform !== 'win32',
  }, async t => {
    const f = await fixture(t);
    const wrapper = await f.wrapper(true);
    const agents = resolve(dirname(process.execPath), '../../../../..');
    const args = ['-NoProfile', '-File', wrapper, '-ProjectRoot', f.root, '-AgentsHome', agents];
    const command = "$OutputEncoding = [Text.UTF8Encoding]::new($false); [Console]::InputEncoding = [Text.UTF8Encoding]::new($false); "
      + `[Console]::In.ReadToEnd() | pwsh -NoProfile -File ${quote(wrapper)} -ProjectRoot ${quote(f.root)} -AgentsHome ${quote(agents)}`;
    const child = spawnSync('pwsh', pipeline ? ['-NoProfile', '-Command', command] : args, {
      input: Buffer.from(JSON.stringify(f.request), 'utf8'), encoding: 'utf8', timeout: 25000,
      env: { ...process.env, GIT_CEILING_DIRECTORIES: dirname(f.root) },
    });
    assert.equal(child.error, undefined);
    assert.equal(child.status, 0, child.stderr);
    const result = JSON.parse(child.stdout).result;
    assert.equal(result.state, 'enabled', JSON.stringify(result));
    await f.assertChinese();
  });
}

for (const [name, patch, missing, invalid] of [
  ['empty profile', { sessionProfile: {} }, [
    'sessionProfile.hostId', 'sessionProfile.mainSessionId', 'sessionProfile.projectId',
    'sessionProfile.projectName', 'sessionProfile.sessionName',
  ], []],
  ['missing caller tokens', { leadToken: undefined, claimToken: undefined, serviceControlToken: undefined },
    ['leadToken', 'claimToken', 'serviceControlToken'], []],
  ['array scope', { task: { id: 'input-check', title: '任务', outcome: '结果',
    sourceRefs: ['fixture/work#input'], acceptanceRefs: ['fixture/accept#input'], scope: [] } }, [], ['task.scope']],
]) {
  test(`INPUT.${name} reports actionable field paths before any mutation`, async t => {
    const f = await fixture(t);
    const before = await readdir(f.root);
    const child = spawnSync(process.execPath, [entry, '--project-root', f.root, '--stdin'], {
      input: JSON.stringify({ ...f.request, ...patch }), encoding: 'utf8', timeout: 10000,
      env: { ...process.env, GIT_CEILING_DIRECTORIES: dirname(f.root) },
    });
    assert.equal(child.status, 0, child.stderr);
    const result = JSON.parse(child.stdout).result;
    assert.equal(result.state, 'activation-pending');
    assert.equal(result.reasonCode, 'REQUEST_INVALID');
    for (const field of missing) assert.ok(result.missingFields.includes(field), field);
    for (const field of invalid) assert.ok(result.invalidFields.includes(field), field);
    assert.deepEqual(await readdir(f.root), before, 'Input validation must precede Board/journal/ignore writes');
    for (const token of [f.request.leadToken, f.request.claimToken, f.request.serviceControlToken]) {
      assert.ok(!child.stdout.includes(token), 'Diagnostics must not echo request secrets');
    }
  });
}

test('INPUT.prepare creates private credentials once and RequestPath activates exact Chinese task', async t => {
  const f = await fixture(t);
  const preparation = { ...f.request, action: 'prepare-request' };
  for (const key of ['leadToken', 'claimToken', 'serviceControlToken']) delete preparation[key];
  const run = () => spawnSync(process.execPath, [entry, '--project-root', f.root, '--stdin'], {
    input: JSON.stringify(preparation), encoding: 'utf8', timeout: 10000,
    env: { ...process.env, GIT_CEILING_DIRECTORIES: dirname(f.root) },
  });
  const first = run();
  assert.equal(first.status, 0, first.stderr);
  const result = JSON.parse(first.stdout).result;
  assert.equal(result.state, 'prepared', first.stdout);
  assert.equal(result.requestPath, join(f.root, f.board, 'request.private.json'));
  await assert.rejects(readFile(join(f.root, f.board, 'board.sqlite')), { code: 'ENOENT' });
  const bytes = await readFile(result.requestPath);
  const prepared = JSON.parse(bytes);
  for (const key of ['leadToken', 'claimToken', 'serviceControlToken']) {
    assert.match(prepared[key], /^[a-f0-9]{64}$/);
    assert.ok(!first.stdout.includes(prepared[key]));
  }
  assert.equal(JSON.parse(run().stdout).result.reasonCode, 'REQUEST_HANDOFF_REQUIRED');
  assert.deepEqual(await readFile(result.requestPath), bytes, 'Never rotate existing caller authority');
  Object.assign(f.request, prepared); // fixture retains the actual caller tokens for authenticated cleanup
  const wrapper = await f.wrapper(true);
  const child = spawnSync('pwsh', ['-NoProfile', '-File', wrapper, '-ProjectRoot', f.root,
    '-AgentsHome', resolve(dirname(process.execPath), '../../../../..'), '-RequestPath', result.requestPath], {
    encoding: 'utf8', timeout: 25000,
    env: { ...process.env, GIT_CEILING_DIRECTORIES: dirname(f.root) },
  });
  assert.equal(child.error, undefined);
  assert.equal(child.status, 0, child.stderr);
  assert.equal(JSON.parse(child.stdout).result.state, 'enabled', child.stdout);
  await f.assertChinese();
});

test('INPUT.prepare rejects empty native context without creating caller files', async t => {
  const f = await fixture(t);
  const before = await readdir(f.root);
  const child = spawnSync(process.execPath, [entry, '--project-root', f.root, '--stdin'], {
    input: JSON.stringify({ ...f.request, action: 'prepare-request', sessionProfile: {} }),
    encoding: 'utf8', timeout: 10000,
  });
  const result = JSON.parse(child.stdout).result;
  assert.equal(result.reasonCode, 'REQUEST_INVALID');
  assert.ok(result.missingFields.includes('sessionProfile.projectId'));
  assert.deepEqual(await readdir(f.root), before);
});
