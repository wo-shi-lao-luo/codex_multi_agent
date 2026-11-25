// Real activation entrypoint: disposable projects, actual SQLite/CLI, no host or user-home mutation.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync, spawn } from 'node:child_process';
import { mkdtemp, mkdir, rm, readFile, writeFile, cp } from 'node:fs/promises';
import { resolve, join, dirname } from 'node:path';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { invoke, secret } from './helpers.mjs';

const entry = resolve('packages/task-board/src/cli/activation.mjs');
import { closeFixtureSharedRuntime } from './fixture-environment.mjs';
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
    await closeFixtureSharedRuntime(join(root, 'hub'));
    await rm(root, { recursive: true, force: true });
  });
  function run(patch = {}, nodeArgs = [], flags = []) {
    const input = { ...request, ...patch };
    const child = spawnSync(process.execPath, [...nodeArgs, entry, '--project-root', root, '--stdin', ...flags], {
      input: JSON.stringify(input), encoding: 'utf8', timeout: 20000,
      env: { ...process.env, GIT_CEILING_DIRECTORIES: dirname(root), CODEX_BOARD_SERVICE_HOME: join(root, 'hub') },
    });
    assert.equal(child.error, undefined, 'Activation must return without waiting for its detached service');
    const result = JSON.parse(child.stdout);
    assert.equal(child.status, result.result?.state === 'activation-pending' ? 2 : 0, child.stdout + child.stderr);
    if (result.result?.service) service = result.result.service;
    for (const token of [input.leadToken, input.claimToken, input.serviceControlToken]) {
      assert.ok(!child.stdout.includes(token), 'Public response must not expose caller credentials');
    }
    return result;
  }
  return { root, request, board, sessionKey, run, track: value => { service = value; } };
}

test('ACTIVATION.standaloneRecordingDoesNotSpawnOrContactViewer', async t => {
  const f = await fixture(t);
  const blockChild = join(f.root, 'deny-child.mjs');
  await writeFile(blockChild, `import child from 'node:child_process';
    import { syncBuiltinESMExports } from 'node:module';
    child.spawn = () => { throw Object.assign(Error('Fixture denies async children'), { code: 'EPERM' }); };
    syncBuiltinESMExports();`);
  const first = f.run({}, ['--import', pathToFileURL(blockChild).href], ['--record-only']).result;
  assert.equal(first.state, 'enabled', JSON.stringify(first));
  assert.equal(first.activationScope, 'record-only');
  assert.deepEqual(first.presentation, { status: 'external' });
  assert.deepEqual(first.completed, { boardVerified: true, initialReportVerified: true });
  assert.equal(first.service, undefined);
  await assert.rejects(readFile(join(f.root, 'hub', 'instance.json')), { code: 'ENOENT' });
  const resume = f.run({ action: 'resume' }, ['--import', pathToFileURL(blockChild).href], ['--record-only']).result;
  assert.equal(resume.state, 'enabled');
  const snapshot = await invoke(f.root, f.board, 'inspect', { actorId: 'lead',
    leadToken: f.request.leadToken }, { sessionKey: f.sessionKey });
  assert.equal(snapshot.code, 0);
  assert.equal(snapshot.reply.result.tasks.length, 1);
  assert.equal(snapshot.reply.result.tasks[0].state, 'running');
  const reject = f.run({ action: 'resume', leadToken: secret() }, [], ['--record-only']).result;
  assert.equal(reject.reasonCode, 'UNAUTHORIZED');
  assert.deepEqual(reject.diagnostic, { phase: 'record', operation: 'inspect', pathCategory: 'project-board' });
  assert.deepEqual(reject.completed, { boardVerified: false, initialReportVerified: false });
});

test('ACTIVATION.reportsDurableRecordWhenActivationLockCleanupIsDenied', async t => {
  const f = await fixture(t);
  const hook = join(f.root, 'deny-lock-release.mjs');
  await writeFile(hook, `import fs from 'node:fs';
    const unlink = fs.unlinkSync;
    fs.unlinkSync = file => {
      if (String(file).endsWith('activation.lock')) {
        throw Object.assign(Error('Fixture denies lock removal'), { code: 'EPERM' });
      }
      return unlink(file);
    };`);
  const result = f.run({}, ['--import', pathToFileURL(hook).href], ['--record-only']).result;
  assert.equal(result.state, 'enabled');
  assert.equal(result.completed.initialReportVerified, true);
  assert.deepEqual(result.cleanup, { status: 'pending', reasonCode: 'EPERM',
    diagnostic: { phase: 'record', operation: 'release-activation-lock', pathCategory: 'project-journal' } });
});

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

const sharedWriteScope = { read: [], write: ['shared.txt'] };

async function boardCall(f, operation, input = {}) {
  const response = await invoke(f.root, f.board, operation, {
    actorId: f.request.actorId, leadToken: f.request.leadToken, ...input,
  }, { sessionKey: f.sessionKey });
  assert.equal(response.code, 0, JSON.stringify(response.reply));
  return response.reply;
}

// Redeem the real first entry ticket and reuse the same authenticated read-only session.
async function browserSnapshotReader(activation) {
  const { service, presentation } = activation;
  assert.ok(presentation.url, 'First presentation must offer a temporary entry URL');
  const bootstrap = await fetch(presentation.url, { redirect: 'manual' });
  assert.equal(bootstrap.status, 303);
  const cookie = bootstrap.headers.get('set-cookie')?.split(';')[0];
  const fragment = new URL(bootstrap.headers.get('location'), service.url).hash;
  const view = /^#view=([a-f0-9]{64})$/.exec(fragment)?.[1];
  assert.ok(cookie && view, 'Entry must establish a read-only browser session');
  await bootstrap.text();
  return async () => {
    const response = await fetch(new URL('api/snapshot', service.url + service.routeBase), {
      headers: { Cookie: cookie, 'X-Task-Board-View': view },
    });
    assert.equal(response.status, 200);
    return response.json();
  };
}

// A new overlapping task should appear blocked in the existing Board. Only a safe release may
// let it run, and neither conflict nor retry should issue another first-open ticket.
test('ACTIVATION.scopeConflictReusesServiceAndResumesAfterSafeRelease', async t => {
  const f = await fixture(t);
  const firstTask = { ...f.request.task, scope: sharedWriteScope };
  const first = f.run({ task: firstTask }).result;
  assert.equal(first.state, 'enabled', JSON.stringify(first));
  const readBrowserSnapshot = await browserSnapshotReader(first);
  const before = (await boardCall(f, 'inspect')).result;
  assert.equal(before.assignments.length, 1);
  assert.ok(before.reservations.some(row => row.active));

  const newTask = { ...firstTask, id: 'work-two', title: 'Overlapping work' };
  const request = { task: newTask, claimToken: secret() };
  const recordOnly = f.run(request, [], ['--record-only']).result;
  assert.equal(recordOnly.state, 'enabled', JSON.stringify(recordOnly));
  assert.equal(recordOnly.activationScope, 'record-only');
  assert.equal(recordOnly.taskExecution, 'not-resumed');
  assert.equal(recordOnly.reasonCode, 'SCOPE_CONFLICT');
  assert.equal(recordOnly.completed.initialReportVerified, false);
  assert.deepEqual(recordOnly.presentation, { status: 'external' });
  const blocked = f.run(request).result;
  assert.equal(blocked.state, 'enabled', JSON.stringify(blocked));
  assert.equal(blocked.activationScope, 'presentation-only');
  assert.equal(blocked.taskExecution, 'not-resumed');
  assert.equal(blocked.reasonCode, 'SCOPE_CONFLICT');
  assert.equal(blocked.taskId, newTask.id);
  assert.equal(blocked.service.serviceId, first.service.serviceId);
  assert.equal(blocked.presentation.url, undefined);

  const snapshot = await readBrowserSnapshot();
  const visibleTask = snapshot.tasks.find(task => task.id === newTask.id);
  assert.equal(visibleTask?.state, 'open');
  assert.equal(visibleTask.readiness, 'blocked');
  assert.match(visibleTask.readinessReason, /overlap current reservations/i);
  const during = (await boardCall(f, 'inspect')).result;
  assert.deepEqual(during.assignments, before.assignments);
  assert.deepEqual(during.reservations, before.reservations);

  const owner = (await boardCall(f, 'show', { taskId: firstTask.id })).result.task;
  await boardCall(f, 'release', {
    operationId: 'safe-release-first-task', generation: first.generation, taskId: owner.id,
    taskRevision: owner.taskRevision, writesStopped: true, processStopped: true,
  });
  const resumed = f.run({ ...request, action: 'resume' }).result;
  assert.equal(resumed.state, 'enabled', JSON.stringify(resumed));
  assert.equal(resumed.taskId, newTask.id);
  assert.equal(resumed.service.serviceId, first.service.serviceId);
  assert.equal(resumed.presentation.url, undefined);
  const after = (await boardCall(f, 'inspect')).result;
  assert.deepEqual(after.assignments.filter(row => row.active).map(row => row.taskId), [
    newTask.id,
  ]);
  assert.equal((await readBrowserSnapshot()).tasks.find(task => task.id === newTask.id)?.state,
    'running');
});

// A Board can retain a live reservation before a service exists. The first blocked activation
// should make that Board readable and supply a one-time entry opportunity.
test('ACTIVATION.scopeConflictStartsFirstService', async t => {
  const f = await fixture(t);
  const initialized = await boardCall(f, 'initialize', { sessionProfile: f.request.sessionProfile });
  const seed = (operation, input) => boardCall(f, operation, {
    generation: initialized.generation, operationId: `prior-work-${operation}`, ...input,
  });
  await seed('register', { worker: {
    id: f.request.actorId, mode: 'lead-inline', role: 'lead', capabilities: ['write'],
  } });
  const priorTask = { ...f.request.task, id: 'prior-work', scope: sharedWriteScope,
    eligibleRoles: ['lead'], allowLeadInline: true };
  await seed('add', { task: priorTask });
  const approved = await seed('approve', { taskId: priorTask.id, taskRevision: 1 });
  const { approvalRevision, taskRevision } = approved.result.task;
  await seed('grant', {
    workerId: f.request.actorId, taskId: priorTask.id, approvalRevision, executionMode: 'lead-inline',
  });
  await seed('lead-inline-assign', {
    taskId: priorTask.id, taskRevision, approvalRevision, claimToken: secret(),
  });

  // Model the durable initialization checkpoint before a service launch; seed the owner above
  // through real CLI transitions so the overlap and ownership checks use persisted reservations.
  await writeFile(join(f.root, f.board, 'activation.json'), JSON.stringify({
    version: 1, root: f.root, sessionKey: f.sessionKey, actorId: f.request.actorId,
    generation: initialized.generation, boardId: initialized.boardId, initializeIntent: 'known',
    tasks: {}, presentation: { status: 'not-attempted' },
  }));
  const before = (await boardCall(f, 'inspect')).result;
  assert.equal(before.assignments.length, 1);
  assert.ok(before.reservations.some(row => row.active));

  const task = { ...f.request.task, scope: sharedWriteScope };
  const first = f.run({ task }).result;
  assert.equal(first.state, 'enabled', JSON.stringify(first));
  assert.equal(first.activationScope, 'presentation-only');
  assert.equal(first.taskExecution, 'not-resumed');
  assert.equal(first.reasonCode, 'SCOPE_CONFLICT');
  assert.equal(first.taskId, task.id);
  assert.equal(first.boardId, initialized.boardId);
  const readBrowserSnapshot = await browserSnapshotReader(first);
  const snapshot = await readBrowserSnapshot();
  assert.equal(snapshot.boardId, initialized.boardId);
  const visibleTask = snapshot.tasks.find(item => item.id === task.id);
  assert.equal(visibleTask?.state, 'open');
  assert.equal(visibleTask.readiness, 'blocked');
  const replay = f.run({ task, action: 'resume' }).result;
  assert.equal(replay.state, 'enabled', JSON.stringify(replay));
  assert.equal(replay.reasonCode, 'SCOPE_CONFLICT');
  assert.equal(replay.service.serviceId, first.service.serviceId);
  assert.equal(replay.presentation.url, undefined);
  const after = (await boardCall(f, 'inspect')).result;
  assert.deepEqual(after.assignments, before.assignments);
  assert.deepEqual(after.reservations, before.reservations);
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
  const args = ['-NoProfile', '-File', wrapper, '-AgentsHome', agentsHome, '-SharedRuntimeHome', join(f.root, 'hub')];
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
  assert.equal(child.status, 2, child.stdout + child.stderr);
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
    stdio: ['pipe', 'pipe', 'pipe'], env: { ...process.env, GIT_CEILING_DIRECTORIES: dirname(f.root),
      CODEX_BOARD_SERVICE_HOME: join(f.root, 'hub') },
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
