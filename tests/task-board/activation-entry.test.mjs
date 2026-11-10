// Real activation entrypoint: disposable projects, actual SQLite/CLI, no host or user-home mutation.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync, spawn } from 'node:child_process';
import { mkdtemp, mkdir, rm, readFile, writeFile, cp } from 'node:fs/promises';
import { resolve, join, dirname } from 'node:path';
import { createHash } from 'node:crypto';
import { invoke, secret } from './helpers.mjs';

const entry = resolve('packages/task-board/src/cli/activation.mjs');
const hash = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
async function fixture(t) {
  const parent = resolve('_work/task-board/test-fixtures');
  await mkdir(parent, { recursive: true });
  const root = await mkdtemp(join(parent, 'activation-'));
  const request = { action: 'activate', actorId: 'lead', executionApproved: true,
    sessionProfile: { hostId: 'test-host', mainSessionId: 'test-main', projectId: 'test-project',
      projectName: 'Fixture project', sessionName: 'Fixture session' },
    task: { id: 'work-one', title: 'One bounded task', outcome: 'Verified bounded result',
      sourceRefs: ['fixture/work#one'], acceptanceRefs: ['fixture/accept#one'],
      scope: { read: [], write: [] } },
    leadToken: secret(), claimToken: secret(), serviceControlToken: secret() };
  const board = `_work/task-board/sessions/v1/${hash(['codex-board-session-v1', 'test-host', 'test-main'])}`;
  const sessionKey = hash(['codex-board-context-v1', 'test-host', 'test-main', 'test-project']);
  let service;
  t.after(async () => {
    if (!service) {
      // A timed-out wrapper may have published identity before losing its response.
      // Recover only this owned fixture's journal and use its still-held caller token.
      try {
        service = JSON.parse(await readFile(join(root, board, 'activation.json'), 'utf8')).service;
      } catch (error) {
        if (error.code !== 'ENOENT') throw error;
      }
    }
    if (service) {
      const stopped = await invoke(root, board, 'service-stop', { ...service,
        serviceControlToken: request.serviceControlToken }, { sessionKey });
      assert.equal(stopped.code, 0, 'Owned service stop must be observed before fixture cleanup');
    }
    await rm(root, { recursive: true, force: true });
  });
  function run(patch = {}, nodeArgs = []) {
    const child = spawnSync(process.execPath, [...nodeArgs, entry, '--project-root', root, '--stdin'], {
      input: JSON.stringify({ ...request, ...patch }), encoding: 'utf8', timeout: 20000,
      env: { ...process.env, GIT_CEILING_DIRECTORIES: dirname(root) },
    });
    assert.equal(child.error, undefined, 'Activation must return without waiting for its detached service');
    assert.equal(child.status, 0, child.stdout + child.stderr);
    const result = JSON.parse(child.stdout);
    if (result.result?.service) service = result.result.service;
    for (const token of [request.leadToken, request.claimToken, request.serviceControlToken]) {
      assert.ok(!child.stdout.includes(token), 'Public response must not expose caller credentials');
    }
    return result;
  }
  return { root, request, board, sessionKey, run, track: value => { service = value; } };
}

// A ready runtime must proceed beyond help/doctor into a real visible task and owned service.
test('ACTIVATION.freshCreatesTruthfulInlineCard', async t => {
  const f = await fixture(t);
  const activation = f.run();
  assert.equal(activation.ok, true);
  assert.equal(activation.result.state, 'enabled', JSON.stringify(activation));
  assert.equal(activation.result.boardPath, f.board);
  assert.equal(activation.result.sessionKey, f.sessionKey);
  assert.equal(activation.result.taskId, f.request.task.id);
  assert.ok(activation.result.service?.serviceId, 'An owned read-only service must be started');
  assert.equal(activation.result.presentation.status, 'unknown', 'URL issuance is not host opening proof');
  assert.ok(activation.result.presentation.url, 'First invocation offers exactly one temporary entry URL');
  const snapshot = await invoke(f.root, f.board, 'inspect', { actorId: 'lead',
    leadToken: f.request.leadToken }, { sessionKey: f.sessionKey });
  assert.equal(snapshot.code, 0, JSON.stringify(snapshot.reply));
  assert.equal(snapshot.reply.result.tasks.length, 1);
  assert.equal(snapshot.reply.result.assignments[0].workerId, 'lead');
  assert.equal(snapshot.reply.result.workers[0].mode, 'lead-inline');
  const journal = await readFile(join(f.root, f.board, 'activation.json'), 'utf8');
  for (const token of [f.request.leadToken, f.request.claimToken, f.request.serviceControlToken]) {
    assert.ok(!journal.includes(token), 'Journal may retain intent but not credential material');
  }
});

test('ACTIVATION.resumeReusesTaskServiceAndFirstOpen', async t => {
  const f = await fixture(t);
  const first = f.run().result;
  const resumed = f.run({ action: 'resume' }).result;
  assert.equal(resumed.state, 'enabled');
  assert.equal(resumed.service.serviceId, first.service.serviceId);
  assert.equal(resumed.presentation.url, undefined, 'Resume must not issue or repeat a first-open URL');
  const view = await invoke(f.root, f.board, 'inspect', { actorId: 'lead',
    leadToken: f.request.leadToken }, { sessionKey: f.sessionKey });
  assert.equal(view.reply.result.tasks.length, 1);
  assert.equal(view.reply.result.assignments.length, 1);
});

test('ACTIVATION.invalidIdentityDoesNotCreateBoard', async t => {
  const f = await fixture(t);
  const denied = f.run({ sessionProfile: { ...f.request.sessionProfile, mainSessionId: '' } });
  assert.equal(denied.result.state, 'activation-pending');
  await assert.rejects(readFile(join(f.root, f.board, 'board.sqlite')), { code: 'ENOENT' });
});

test('ACTIVATION.incompatibleExistingDatabaseIsPreserved', async t => {
  const f = await fixture(t);
  await mkdir(join(f.root, f.board), { recursive: true });
  const original = Buffer.from('incompatible existing Board sentinel');
  const database = join(f.root, f.board, 'board.sqlite');
  await writeFile(database, original);
  const denied = f.run();
  assert.equal(denied.result.state, 'activation-pending');
  assert.deepEqual(await readFile(database), original);
});

// Dependency repair is explicit and external: the next invocation rechecks rather than caching failure.
test('ACTIVATION.unavailableRuntimeCanRecoverOnNextInvocation', async t => {
  const f = await fixture(t);
  const unavailable = f.run({}, ['--no-experimental-sqlite']);
  assert.equal(unavailable.result.state, 'activation-pending');
  await assert.rejects(readFile(join(f.root, f.board, 'board.sqlite')), { code: 'ENOENT' });
  assert.equal(f.run({ action: 'resume' }).result.state, 'enabled');
});

test('ACTIVATION.recordedOpeningResultDoesNotReopenBrowser', async t => {
  const f = await fixture(t);
  const first = f.run().result;
  const recorded = f.run({ action: 'record-open-result', presentationOutcome: 'queued' }).result;
  assert.equal(recorded.presentation.status, 'queued');
  assert.equal(recorded.presentation.url, undefined);
  const resumed = f.run({ action: 'resume' }).result;
  assert.equal(resumed.presentation.status, 'queued');
  assert.equal(resumed.presentation.url, undefined);
  assert.equal(resumed.service.serviceId, first.service.serviceId);
});

// An opening outcome is observation only; it must never create an absent Board.
test('ACTIVATION.recordOpenOnMissingBoardDoesNotInitialize', async t => {
  const f = await fixture(t);
  const result = f.run({ action: 'record-open-result', presentationOutcome: 'queued' });
  assert.equal(result.result.state, 'activation-pending');
  await assert.rejects(readFile(join(f.root, f.board, 'board.sqlite')), { code: 'ENOENT' });
});

// Retained identity is evidence that state once existed, not permission to recreate lost history.
test('ACTIVATION.retainedGenerationWithLostDatabaseDoesNotReset', async t => {
  const f = await fixture(t);
  await mkdir(join(f.root, f.board), { recursive: true });
  const journal = { version: 1, root: f.root, sessionKey: f.sessionKey, actorId: 'lead',
    generation: 'previous-generation', boardId: 'previous-board', tasks: {},
    presentation: { status: 'unknown' } };
  const journalFile = join(f.root, f.board, 'activation.json');
  await writeFile(journalFile, JSON.stringify(journal));
  assert.equal(f.run({ action: 'resume' }).result.state, 'activation-pending');
  await assert.rejects(readFile(join(f.root, f.board, 'board.sqlite')), { code: 'ENOENT' });
  assert.deepEqual(JSON.parse(await readFile(journalFile, 'utf8')), journal);
});

test('ACTIVATION.doesNotApproveExistingUnjournaledTask', async t => {
  const f = await fixture(t);
  const initialized = await invoke(f.root, f.board, 'initialize', {
    actorId: 'lead', leadToken: f.request.leadToken, sessionProfile: f.request.sessionProfile,
  }, { sessionKey: f.sessionKey });
  assert.equal(initialized.code, 0);
  const generation = initialized.reply.generation;
  const added = await invoke(f.root, f.board, 'add', { actorId: 'lead',
    leadToken: f.request.leadToken, generation, operationId: 'manual-task-add',
    task: { ...f.request.task, eligibleRoles: ['lead'], allowLeadInline: true },
  }, { sessionKey: f.sessionKey });
  assert.equal(added.code, 0, JSON.stringify(added.reply));
  await writeFile(join(f.root, f.board, 'activation.json'), JSON.stringify({
    version: 1, root: f.root, sessionKey: f.sessionKey, actorId: 'lead', generation,
    boardId: initialized.reply.boardId, tasks: {}, presentation: { status: 'not-attempted' },
  }));
  assert.equal(f.run({ action: 'resume' }).result.state, 'activation-pending');
  const view = await invoke(f.root, f.board, 'inspect', { actorId: 'lead',
    leadToken: f.request.leadToken }, { sessionKey: f.sessionKey });
  assert.equal(view.reply.result.tasks[0].state, 'planned', 'Existing work needs explicit adoption, not implicit approval');
  assert.equal(view.reply.result.assignments.length, 0);
});

// Copy only candidate files to an owned Skill layout; actual installed files are read-only inputs.
async function wrapperFixture(f) {
  const skill = join(f.root, 'candidate-kit', 'skills', 'team-core');
  await mkdir(join(skill, 'scripts'), { recursive: true });
  await mkdir(join(skill, 'runtime'), { recursive: true });
  for (const name of ['activate-board.ps1', 'board-runtime.ps1']) {
    await cp(resolve('skills/team-core/scripts', name), join(skill, 'scripts', name));
  }
  await cp(resolve('skills/team-core/runtime/node-runtime.json'), join(skill, 'runtime/node-runtime.json'));
  await cp(resolve('packages/task-board'), join(skill, 'runtime/task-board'), { recursive: true });
  return join(skill, 'scripts/activate-board.ps1');
}

test('ACTIVATION.wrapperUsesManagedRuntimeAndForwardsStdin', async t => {
  const f = await fixture(t);
  const wrapper = await wrapperFixture(f);
  // This suite is run with the verified managed runtime; locate its owning AgentsHome generically.
  const agentsHome = resolve(dirname(process.execPath), '../../../../..');
  const args = ['-NoProfile', '-File', wrapper, '-AgentsHome', agentsHome];
  const help = spawnSync('pwsh', [...args, '-Help'], { encoding: 'utf8', timeout: 15000 });
  assert.equal(help.status, 0, help.stdout + help.stderr);
  assert.equal(JSON.parse(help.stdout).operation, 'activation-help');
  const child = spawnSync('pwsh', [...args, '-ProjectRoot', f.root], {
    input: JSON.stringify(f.request), encoding: 'utf8', timeout: 25000,
    env: { ...process.env, GIT_CEILING_DIRECTORIES: dirname(f.root) },
  });
  assert.equal(child.error, undefined, child.stderr);
  assert.equal(child.status, 0, child.stdout + child.stderr);
  const result = JSON.parse(child.stdout).result;
  if (result.service) f.track(result.service);
  assert.equal(result.state, 'enabled', JSON.stringify(result));
  assert.equal(result.taskId, f.request.task.id);
  for (const value of [f.request.leadToken, f.request.claimToken, f.request.serviceControlToken]) {
    assert.ok(!child.stdout.includes(value), 'Wrapper must not echo protected stdin');
  }
});

test('ACTIVATION.wrapperRejectsConflictingRuntimeWithoutDownloading', async t => {
  const f = await fixture(t);
  const wrapper = await wrapperFixture(f);
  const fakeHome = join(f.root, 'empty-agents');
  const target = join(fakeHome, 'codex-multi-agent/runtimes/node/26.13.0', `${process.platform}-${process.arch}`);
  await mkdir(target, { recursive: true });
  const child = spawnSync('pwsh', ['-NoProfile', '-File', wrapper, '-AgentsHome', fakeHome,
    '-ProjectRoot', f.root], { input: JSON.stringify(f.request), encoding: 'utf8', timeout: 15000 });
  assert.equal(child.status, 0, child.stdout + child.stderr);
  const result = JSON.parse(child.stdout).result;
  assert.equal(result.state, 'activation-pending');
  assert.equal(result.reasonCode, 'RUNTIME_UNAVAILABLE');
  await assert.rejects(readFile(join(f.root, f.board, 'board.sqlite')), { code: 'ENOENT' });
  await assert.rejects(readFile(join(target, process.platform === 'win32' ? 'node.exe' : 'node')), { code: 'ENOENT' });
});

test('ACTIVATION.resumeAcceptsEquivalentTypedScopeAndDirectorySpelling', async t => {
  const f = await fixture(t);
  await mkdir(join(f.root, 'src'));
  const initial = { ...f.request.task, scope: { read: [{ workspaceId: 'main', path: 'src/' }], write: [] } };
  const first = f.run({ task: initial }).result;
  assert.equal(first.state, 'enabled', JSON.stringify(first));
  const equivalent = { ...initial, scope: { write: [], read: [{ path: 'src', workspaceId: 'main' }] } };
  const resumed = f.run({ action: 'resume', task: equivalent }).result;
  assert.equal(resumed.state, 'enabled', JSON.stringify(resumed));
  assert.equal(resumed.presentation.url, undefined);
});

test('ACTIVATION.unknownInitializationIntentCannotRecreateMissingDatabase', async t => {
  const f = await fixture(t);
  await mkdir(join(f.root, f.board), { recursive: true });
  const journal = { version: 1, root: f.root, sessionKey: f.sessionKey, actorId: 'lead',
    initializeIntent: 'unknown', tasks: {}, presentation: { status: 'not-attempted' } };
  const file = join(f.root, f.board, 'activation.json');
  await writeFile(file, JSON.stringify(journal));
  assert.equal(f.run({ action: 'resume' }).result.state, 'activation-pending');
  await assert.rejects(readFile(join(f.root, f.board, 'board.sqlite')), { code: 'ENOENT' });
  assert.deepEqual(JSON.parse(await readFile(file, 'utf8')), journal);
});

// Reconstruct the public Add-boundary partial state: old approval intent, changed planned contract.
// No live database patching or reconcile holds mask the complete-contract comparison being tested.
test('ACTIVATION.interruptedPlannedTaskDriftCannotBeAutoApproved', async t => {
  const f = await fixture(t);
  const initialized = await invoke(f.root, f.board, 'initialize', {
    actorId: 'lead', leadToken: f.request.leadToken, sessionProfile: f.request.sessionProfile,
  }, { sessionKey: f.sessionKey });
  assert.equal(initialized.code, 0);
  const expected = { ...f.request.task, requiredSkills: [], responsibilities: [], allowLeadInline: true,
    workspaceId: 'main', acceptancePolicy: { requiredChecks: [] }, verification: null,
    eligibleRoles: ['lead'], priority: 0, resources: [], dependencies: [] };
  const canonical = value => Array.isArray(value) ? value.map(canonical) : value && typeof value === 'object'
    ? Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])])) : value;
  const added = await invoke(f.root, f.board, 'add', {
    operationId: 'changed-planned-add', actorId: 'lead', leadToken: f.request.leadToken,
    generation: initialized.reply.generation, task: { ...expected,
      resources: [{ kind: 'resource', key: 'shared-browser-profile', mode: 'exclusive' }] },
  }, { sessionKey: f.sessionKey });
  assert.equal(added.code, 0, JSON.stringify(added.reply));
  await writeFile(join(f.root, f.board, 'activation.json'), JSON.stringify({
    version: 1, root: f.root, sessionKey: f.sessionKey, actorId: 'lead',
    generation: initialized.reply.generation, boardId: initialized.reply.boardId,
    tasks: { [expected.id]: { contractDigest: hash(canonical(expected)) } },
    presentation: { status: 'not-attempted' },
  }));
  const denied = f.run({ action: 'resume' }).result;
  assert.equal(denied.state, 'activation-pending');
  assert.equal(denied.reasonCode, 'TASK_CONTRACT_CHANGED');
  const view = await invoke(f.root, f.board, 'show', { actorId: 'lead',
    leadToken: f.request.leadToken, taskId: expected.id }, { sessionKey: f.sessionKey });
  assert.equal(view.reply.result.task.state, 'planned');
  assert.equal(view.reply.result.task.approvalRevision, 0);
  assert.equal(view.reply.result.task.needsReconcile, false, 'No unrelated reconcile guard can explain rejection');
  assert.deepEqual(view.reply.result.task.acceptancePolicy, expected.acceptancePolicy);
  assert.equal(view.reply.result.task.priority, expected.priority);
});

// Native pipe boundaries are byte boundaries, not UTF-8 character boundaries.
test('ACTIVATION.splitUtf8StdinPreservesObservedSessionName', async t => {
  const f = await fixture(t);
  const label = '测试项目';
  const request = { ...f.request, sessionProfile: { ...f.request.sessionProfile, projectName: label } };
  const bytes = Buffer.from(JSON.stringify(request));
  const split = bytes.indexOf(Buffer.from('测')) + 1;
  assert.ok(split > 0);
  const child = spawn(process.execPath, [entry, '--project-root', f.root, '--stdin'], {
    stdio: ['pipe', 'pipe', 'pipe'], env: { ...process.env, GIT_CEILING_DIRECTORIES: dirname(f.root) },
  });
  const output = [];
  child.stdout.on('data', chunk => output.push(chunk));
  const completed = new Promise((done, reject) => {
    child.once('error', reject);
    child.once('close', code => done(code));
  });
  child.stdin.write(bytes.subarray(0, split));
  // Allow CLI startup and consumption of the incomplete prefix before delivering the continuation.
  await new Promise(done => setTimeout(done, 500));
  child.stdin.end(bytes.subarray(split));
  assert.equal(await completed, 0);
  const activated = JSON.parse(Buffer.concat(output).toString('utf8')).result;
  if (activated.service) f.track(activated.service);
  assert.equal(activated.state, 'enabled', JSON.stringify(activated));
  const view = await invoke(f.root, f.board, 'inspect', { actorId: 'lead',
    leadToken: f.request.leadToken }, { sessionKey: f.sessionKey });
  assert.equal(view.reply.result.sessionProfile.projectName, label);
});
