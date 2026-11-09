// Workspace authority is derived from real disposable Git checkouts through the public CLI.
import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawn } from 'node:child_process';
import { mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { invoke, secret, cli } from './helpers.mjs';

// Construct actual same-repository worktrees before Board initialization, with local-only Git state.
async function worktrees(t) {
  const parent = resolve('_work/task-board/test-fixtures');
  await mkdir(parent, { recursive: true });
  const root = await mkdtemp(join(parent, 'execution-workspaces-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const project = join(root, 'main');
  const checkout = join(root, 'checkout');
  await mkdir(project);
  const git = args => execFileSync('git', ['-C', project, ...args],
    { stdio: 'pipe', env: { ...process.env, GIT_CONFIG_NOSYSTEM: '1' } });
  git(['init']);
  await writeFile(join(project, 'tracked.txt'), 'disposable fixture\n');
  git(['add', 'tracked.txt']);
  git(['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
    '-c', 'core.hooksPath=NUL', 'commit', '-m', 'Fixture initial content']);
  git(['worktree', 'add', '--detach', checkout]);
  const board = join(project, '_work', 'board');
  const leadToken = secret();
  let generation;
  let sequence = 0;
  const raw = (operation, payload = {}, options = {}) => invoke(project, board, operation,
    { operationId: `workspace-${++sequence}`, actorId: 'lead', leadToken, generation, ...payload }, options);
  const ok = async (operation, payload) => {
    const result = await raw(operation, payload);
    assert.equal(result.code, 0, `${operation}: ${JSON.stringify(result.reply)}`);
    return result.reply;
  };
  generation = (await ok('initialize')).generation;
  // Only the subprocess cwd supplies execution context; JSON cannot substitute for this value.
  const at = (cwd, operation, payload = {}) => new Promise((done, reject) => {
    const child = spawn(process.execPath, [cli, operation, '--project-root', project,
      '--board-path', board, '--stdin'], { cwd, stdio: ['pipe', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';
    const timer = setTimeout(() => { child.kill(); reject(new Error('CLI timeout')); }, 10000);
    child.stdout.on('data', chunk => { stdout += chunk; });
    child.stderr.on('data', chunk => { stderr += chunk; });
    child.on('error', reject);
    child.on('close', code => {
      clearTimeout(timer);
      try { done({ code, reply: JSON.parse(stdout), stderr }); } catch (error) { reject(error); }
    });
    child.stdin.end(JSON.stringify({ operationId: `workspace-${++sequence}`,
      actorId: 'lead', leadToken, generation, ...payload }));
  });
  return { root, project, checkout, raw, ok, at };
}

// WORKSPACE: a linked checkout from the same repository can be registered and inspected.
// Expected: persisted server-derived identity and revision distinguish it from default main.
test('EXECUTION.workspace.registerRealLinkedCheckout', async t => {
  const f = await worktrees(t);
  await f.ok('workspace-register', { workspace: { id: 'implementation', root: f.checkout } });
  const result = (await f.ok('workspaces')).result;
  const records = Array.isArray(result) ? result : result.workspaces;
  const main = records.find(item => item.id === 'main');
  const linked = records.find(item => item.id === 'implementation');
  assert.ok(main);
  assert.ok(linked);
  assert.equal(linked.revision, 1);
  assert.equal(linked.status, 'active');
  assert.deepEqual(linked.repositoryIdentity, main.repositoryIdentity);
  assert.notDeepEqual(linked.checkoutIdentity, main.checkoutIdentity);
});

// WORKSPACE: an unrelated directory cannot obtain same-repository checkout authority.
// Expected: rejection leaves registry and Board revision unchanged.
test('EXECUTION.workspace.outsideDirectoryRejectedAtomically', async t => {
  const f = await worktrees(t);
  const outside = join(f.root, 'outside');
  await mkdir(outside);
  const before = (await f.ok('inspect')).result;
  const denied = await f.raw('workspace-register', { workspace: { id: 'foreign', root: outside } });
  assert.notEqual(denied.code, 0);
  assert.deepEqual((await f.ok('inspect')).result, before);
});


// WORKSPACE-NEGATIVE: missing, foreign-repository and symlink roots cannot enter the registry.
// Expected: once a valid checkout proves the operation exists, every invalid request is atomic.
test('EXECUTION.workspace.invalidRootsAndReadOnlyInspection', async t => {
  const f = await worktrees(t);
  await f.ok('workspace-register', { workspace: { id: 'implementation', root: f.checkout } });
  const foreign = join(f.root, 'foreign-repository');
  await mkdir(foreign);
  execFileSync('git', ['-C', foreign, 'init'], { stdio: 'pipe' });
  const { symlink } = await import('node:fs/promises');
  const linked = join(f.root, 'linked-checkout');
  const invalidRoots = [
    ['missing', join(f.root, 'missing')],
    ['foreign', foreign],
    ['nested', join(f.project, '_work')],
  ];
  try {
    await symlink(f.checkout, linked, process.platform === 'win32' ? 'junction' : 'dir');
    invalidRoots.push(['symlink', linked]);
  } catch (error) {
    if (!['EPERM', 'EACCES'].includes(error.code)) throw error;
    t.diagnostic('ENVIRONMENT GAP: symlink/junction creation denied; link scenario unexecuted');
  }
  for (const [id, root] of invalidRoots) {
    const before = (await f.ok('inspect')).result;
    const denied = await f.raw('workspace-register', { workspace: { id, root } });
    assert.notEqual(denied.code, 0, `${id} root must be denied`);
    assert.deepEqual((await f.ok('inspect')).result, before, `${id} denial is atomic`);
  }
  const beforeQuery = (await f.ok('inspect')).result;
  await f.ok('workspaces');
  assert.deepEqual((await f.ok('inspect')).result, beforeQuery,
    'Read-only inspection must not update registry or revision');
});


// Prepare a real direct worker and current task grant for a selected execution checkout.
async function workspaceTask(f, id, workspaceId, { path = 'shared.mjs', resources = [] } = {}) {
  const workerToken = secret();
  await f.ok('register', { worker: { id, hostId: `fixture-${id}`, role: 'backend', mode: 'direct',
    capabilities: ['write'], workerToken } });
  await f.ok('add', { task: { id, title: id, outcome: 'Workspace output', workspaceId,
    sourceRefs: [`fixture/work#${id}`], acceptanceRefs: [`fixture/accept#${id}`],
    eligibleRoles: ['backend'], scope: { read: [], write: [path] }, resources, dependencies: [] } });
  await f.ok('approve', { taskId: id, taskRevision: 1 });
  await f.ok('grant', { workerId: id, taskId: id, approvalRevision: 2 });
  return { taskId: id, taskRevision: 2, actorId: id, workerToken, claimToken: secret() };
}

// RESOURCES/CWD: distinct physical checkout files permit concurrency, global resources do not.
// Expected: forged JSON cwd cannot authorize a claim; real cwd claims acquire only their bindings.
test('EXECUTION.workspace.actualCwdAndCrossCheckoutReservations', async t => {
  const f = await worktrees(t);
  await f.ok('workspace-register', { workspace: { id: 'implementation', root: f.checkout } });
  const main = await workspaceTask(f, 'main-writer', 'main');
  const linked = await workspaceTask(f, 'linked-writer', 'implementation');
  const before = (await f.ok('inspect')).result;
  const wrongCwd = await f.at(f.project, 'claim', { ...linked, clientCwd: f.checkout });
  assert.notEqual(wrongCwd.code, 0, 'JSON cwd cannot replace actual process cwd');
  assert.deepEqual((await f.ok('inspect')).result, before);
  assert.equal((await f.at(f.project, 'claim', main)).code, 0);
  assert.equal((await f.at(f.checkout, 'claim', linked)).code, 0,
    'Same relative path in physically different checkouts must not conflict');
  const global = [{ kind: 'resource', key: 'shared-database', mode: 'exclusive' }];
  const first = await workspaceTask(f, 'global-main', 'main', { path: 'one.mjs', resources: global });
  const second = await workspaceTask(f, 'global-linked', 'implementation',
    { path: 'two.mjs', resources: global });
  assert.equal((await f.at(f.project, 'claim', first)).code, 0);
  const held = (await f.ok('inspect')).result;
  assert.notEqual((await f.at(f.checkout, 'claim', second)).code, 0);
  assert.deepEqual((await f.ok('inspect')).result, held,
    'Logical resource contention is Board-wide even across distinct physical worktrees');
});

// RESOURCES-ALIAS: two registered names for one physical checkout cannot bypass reservations.
// Expected: overlapping physical scope is rejected regardless of workspace label.
test('EXECUTION.workspace.samePhysicalCheckoutAliasIsProtected', async t => {
  const f = await worktrees(t);
  await f.ok('workspace-register', { workspace: { id: 'implementation', root: f.checkout } });
  const alias = await f.raw('workspace-register', { workspace: { id: 'alias', root: f.checkout } });
  if (alias.code !== 0) {
    assert.ok(alias.reply.error, 'Duplicate physical registry entry is explicitly rejected');
    return;
  }
  const first = await workspaceTask(f, 'first', 'implementation');
  const second = await workspaceTask(f, 'second', 'alias');
  assert.equal((await f.at(f.checkout, 'claim', first)).code, 0);
  const before = (await f.ok('inspect')).result;
  assert.notEqual((await f.at(f.checkout, 'claim', second)).code, 0);
  assert.deepEqual((await f.ok('inspect')).result, before);
});


// FILE-CASE: platform path semantics determine whether two spellings name the same physical file.
// Expected: Windows spelling aliases conflict; Linux distinct existing files can execute separately.
test('EXECUTION.workspace.existingFileCaseAliasesFollowPhysicalIdentity', async t => {
  const f = await worktrees(t);
  await writeFile(join(f.project, 'MixedCase.mjs'), 'one\n');
  if (process.platform !== 'win32') await writeFile(join(f.project, 'mixedcase.mjs'), 'two\n');
  const first = await workspaceTask(f, 'case-first', 'main', { path: 'MixedCase.mjs' });
  const second = await workspaceTask(f, 'case-second', 'main', { path: 'mixedcase.mjs' });
  assert.equal((await f.at(f.project, 'claim', first)).code, 0);
  const secondResult = await f.at(f.project, 'claim', second);
  if (process.platform === 'win32') assert.notEqual(secondResult.code, 0);
  else assert.equal(secondResult.code, 0);
});

// HARDLINK: a second physical filename cannot bypass exclusive file protection.
// Expected: a linked output scope is rejected before any assignment/reservation is committed.
test('EXECUTION.workspace.hardlinkedScopeRejected', async t => {
  const f = await worktrees(t);
  const { link } = await import('node:fs/promises');
  await writeFile(join(f.project, 'original.mjs'), 'protected\n');
  const owner = await workspaceTask(f, 'hardlink-writer', 'main', { path: 'original.mjs' });
  try { await link(join(f.project, 'original.mjs'), join(f.project, 'alias.mjs')); }
  catch (error) {
    if (!['EPERM', 'EACCES', 'ENOTSUP'].includes(error.code)) throw error;
    t.skip(`Hardlink unavailable: ${error.code}; requirement remains an environmental gap`);
    return;
  }
  const before = (await f.ok('inspect')).result;
  const denied = await f.at(f.project, 'claim', owner);
  assert.notEqual(denied.code, 0);
  assert.deepEqual((await f.ok('inspect')).result, before);
});

// REPLAY/DRIFT: an operation receipt cannot revive a checkout that moved after a valid claim.
// Expected: repeat operation revalidates membership/root and rejects without new allocation.
test('EXECUTION.workspace.movedCheckoutInvalidatesClaimReplay', async t => {
  const f = await worktrees(t);
  await f.ok('workspace-register', { workspace: { id: 'implementation', root: f.checkout } });
  const owner = await workspaceTask(f, 'moving-writer', 'implementation');
  const request = { ...owner, operationId: 'fixed-workspace-claim' };
  assert.equal((await f.at(f.checkout, 'claim', request)).code, 0);
  const before = (await f.ok('inspect')).result;
  const { rename } = await import('node:fs/promises');
  const moved = join(f.root, 'moved-checkout');
  await rename(f.checkout, moved);
  const replay = await f.at(moved, 'claim', request);
  assert.notEqual(replay.code, 0, 'Historical receipt must not bypass current workspace proof');
  assert.deepEqual((await f.ok('inspect')).result, before);
});


// GIT-ENV: inherited Git variables cannot convert a foreign directory into a registered checkout.
// Expected: verification uses actual root/common-directory/membership and leaves state unchanged.
test('EXECUTION.workspace.gitEnvironmentCannotForgeRepository', async t => {
  const f = await worktrees(t);
  const foreign = join(f.root, 'foreign');
  await mkdir(foreign);
  const before = (await f.ok('inspect')).result;
  const denied = await f.raw('workspace-register', { workspace: { id: 'forged', root: foreign } },
    { env: { GIT_DIR: join(f.project, '.git'), GIT_WORK_TREE: f.checkout,
      GIT_COMMON_DIR: join(f.project, '.git') } });
  assert.notEqual(denied.code, 0);
  assert.deepEqual((await f.ok('inspect')).result, before);
});

// SOURCE-WORKSPACE: typed source mappings must observe the selected checkout's actual contents.
// Expected: same relative source name with different content produces distinct observations.
test('EXECUTION.workspace.typedSourcesObserveSelectedCheckout', async t => {
  const f = await worktrees(t);
  await f.ok('workspace-register', { workspace: { id: 'implementation', root: f.checkout } });
  await writeFile(join(f.checkout, 'tracked.txt'), 'different linked checkout input\n');
  const fingerprints = [];
  for (const workspaceId of ['main', 'implementation']) {
    const id = `source-${workspaceId}`;
    await f.ok('add', { task: { id, title: id, outcome: 'Bound source observation',
      workspaceId, sourceRefs: [{ schemaVersion: 1, kind: 'work', path: 'tracked.txt',
        nativeTaskId: 'fixture-native', workspaceId }], acceptanceRefs: ['fixture/accept#source'],
      eligibleRoles: ['backend'], scope: { read: [], write: [] }, resources: [], dependencies: [] } });
    const observation = (await f.ok('source-check', { taskId: id })).result.observation;
    fingerprints.push(observation.checkedRefs[0].actualRevision);
    assert.match(fingerprints.at(-1), /^[a-f0-9]{64}$/);
  }
  assert.notEqual(fingerprints[0], fingerprints[1]);
});

// CWD-NESTING: being textually beneath main is insufficient when cwd enters another Git checkout.
// Expected: a nonmain production claim fails from an unregistered nested repository.
test('EXECUTION.workspace.unregisteredNestedCheckoutCwdRejected', async t => {
  const f = await worktrees(t);
  await f.ok('workspace-register', { workspace: { id: 'implementation', root: f.checkout } });
  const nested = join(f.checkout, 'nested');
  await mkdir(nested);
  execFileSync('git', ['-C', nested, 'init'], { stdio: 'pipe' });
  const owner = await workspaceTask(f, 'nested-cwd-writer', 'implementation');
  const before = (await f.ok('inspect')).result;
  const denied = await f.at(nested, 'claim', owner);
  assert.notEqual(denied.code, 0);
  assert.deepEqual((await f.ok('inspect')).result, before);
});


// SOURCE-DRIFT: cross-checkout source pins and grants must be rechecked before allocation.
// Expected: changing the bound input after grant blocks execution and creates no reservation.
test('EXECUTION.workspace.changedCrossCheckoutSourceInvalidatesGrant', async t => {
  const f = await worktrees(t);
  await f.ok('workspace-register', { workspace: { id: 'implementation', root: f.checkout } });
  const workerToken = secret();
  await f.ok('register', { worker: { id: 'source-writer', hostId: 'fixture-source-writer',
    role: 'backend', mode: 'direct', capabilities: ['write'], workerToken } });
  const source = { schemaVersion: 1, kind: 'work', path: 'tracked.txt',
    nativeTaskId: 'fixture-native', workspaceId: 'implementation' };
  await f.ok('add', { task: { id: 'source-bound', title: 'source-bound', outcome: 'Pinned source',
    sourceRefs: [source], acceptanceRefs: ['fixture/accept#source'], eligibleRoles: ['backend'],
    scope: { read: [], write: ['source-output.mjs'] }, resources: [], dependencies: [] } });
  const observed = (await f.ok('source-check', { taskId: 'source-bound' })).result.observation;
  const pinned = { ...source, expectedRevision: observed.checkedRefs[0].actualRevision };
  let task = (await f.ok('show', { taskId: 'source-bound' })).result.task;
  await f.ok('amend', { taskId: task.id, taskRevision: task.taskRevision,
    expectedInputRevision: task.inputRevision, reason: 'Pin linked checkout source',
    patch: { sourceRefs: [pinned] } });
  task = (await f.ok('show', { taskId: 'source-bound' })).result.task;
  await f.ok('approve', { taskId: task.id, taskRevision: task.taskRevision });
  task = (await f.ok('show', { taskId: 'source-bound' })).result.task;
  await f.ok('reconcile', { taskId: task.id, taskRevision: task.taskRevision,
    expectedInputRevision: task.inputRevision, decision: 'confirm', reason: 'Observed pinned source',
    sourceObservation: { available: true, revision: pinned.expectedRevision,
      evidenceRefs: ['fixture/source#observed'] } });
  task = (await f.ok('show', { taskId: 'source-bound' })).result.task;
  await f.ok('grant', { taskId: task.id, workerId: 'source-writer',
    approvalRevision: task.approvalRevision });
  await writeFile(join(f.checkout, 'tracked.txt'), 'changed after grant\n');
  const denied = await f.at(f.project, 'claim', { taskId: task.id,
    taskRevision: task.taskRevision, actorId: 'source-writer', workerToken, claimToken: secret() });
  assert.notEqual(denied.code, 0);
  const after = (await f.ok('inspect')).result;
  assert.ok(!after.assignments.some(item => item.taskId === task.id && item.active));
  assert.ok(!after.reservations.some(item => item.taskId === task.id && item.active));
});


// READ-SCOPE: string reads follow task workspace, while typed reads follow their explicit workspace.
// Expected: linked checkout read proceeds beside main write; explicit main read conflicts.
test('EXECUTION.workspace.readScopesUseDeclaredCheckout', async t => {
  const f = await worktrees(t);
  await f.ok('workspace-register', { workspace: { id: 'implementation', root: f.checkout } });
  const main = await workspaceTask(f, 'tracked-writer', 'main', { path: 'tracked.txt' });
  assert.equal((await f.at(f.project, 'claim', main)).code, 0);
  for (const [id, read, allowed] of [
    ['linked-read', ['tracked.txt'], true],
    ['main-read', [{ workspaceId: 'main', path: 'tracked.txt' }], false],
  ]) {
    const workerToken = secret();
    await f.ok('register', { worker: { id, hostId: `fixture-${id}`, role: 'backend',
      mode: 'direct', capabilities: ['read', 'write'], workerToken } });
    await f.ok('add', { task: { id, title: id, outcome: 'Correct read binding',
      workspaceId: 'implementation', sourceRefs: [`fixture/work#${id}`],
      acceptanceRefs: [`fixture/accept#${id}`], eligibleRoles: ['backend'],
      scope: { read, write: [] }, resources: [], dependencies: [] } });
    await f.ok('approve', { taskId: id, taskRevision: 1 });
    await f.ok('grant', { workerId: id, taskId: id, approvalRevision: 2 });
    const result = await f.at(f.checkout, 'claim', { taskId: id, taskRevision: 2,
      actorId: id, workerToken, claimToken: secret() });
    if (allowed) assert.equal(result.code, 0);
    else assert.notEqual(result.code, 0);
  }
});

// EMPTY-WORKSPACE-SOURCE: opaque source refs do not waive the declared checkout binding.
// Expected: source-check rejects moved nonmain roots even when no filesystem scopes exist.
test('EXECUTION.workspace.emptyScopeSourceCheckRevalidatesCheckout', async t => {
  const f = await worktrees(t);
  await f.ok('workspace-register', { workspace: { id: 'implementation', root: f.checkout } });
  await f.ok('add', { task: { id: 'empty', title: 'empty', outcome: 'Bound declaration',
    workspaceId: 'implementation', sourceRefs: ['opaque:declared'],
    acceptanceRefs: ['fixture/accept#empty'], eligibleRoles: ['backend'],
    scope: { read: [], write: [] }, resources: [], dependencies: [] } });
  const { rename } = await import('node:fs/promises');
  await rename(f.checkout, join(f.root, 'moved-empty-checkout'));
  const denied = await f.raw('source-check', { taskId: 'empty' });
  assert.notEqual(denied.code, 0, 'Empty scopes and opaque refs cannot skip checkout revalidation');
});

// EMPTY-WORKSPACE-AMEND: amendments cannot install unregistered checkout authority via empty scope.
// Expected: missing workspace fails atomically even when there are no read/write paths to validate.
test('EXECUTION.workspace.emptyScopeAmendRejectsMissingCheckout', async t => {
  const f = await worktrees(t);
  await f.ok('add', { task: { id: 'empty', title: 'empty', outcome: 'Bound declaration',
    sourceRefs: ['opaque:declared'], acceptanceRefs: ['fixture/accept#empty'],
    eligibleRoles: ['backend'], scope: { read: [], write: [] }, resources: [], dependencies: [] } });
  const before = (await f.ok('inspect')).result;
  const denied = await f.raw('amend', { taskId: 'empty', taskRevision: 1,
    expectedInputRevision: 1, reason: 'Attempt missing checkout', patch: { workspaceId: 'missing' } });
  assert.notEqual(denied.code, 0);
  assert.deepEqual((await f.ok('inspect')).result, before);
});
