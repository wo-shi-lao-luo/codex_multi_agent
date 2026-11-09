// Stage A CLI catalog and generated-artifact protection; only disposable owned Git projects are used.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdir, mkdtemp, rm, readFile, writeFile, access } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { cli, invoke, secret } from './helpers.mjs';

// Read-only help invocation intentionally supplies neither project nor coordination location.
function help(operation) {
  const args = [cli, 'help'];
  if (operation) args.push('--operation', operation);
  const result = spawnSync(process.execPath, args, { encoding: 'utf8', timeout: 10000 });
  return { code: result.status, reply: JSON.parse(result.stdout) };
}

// Git setup is project-local; these commands never touch global configuration or real repository index.
function git(root, args) {
  const result = spawnSync('git', ['-C', root, ...args], { encoding: 'utf8', timeout: 10000 });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout;
}

async function project(t, withGit = true) {
  const parent = resolve('_work/task-board/test-fixtures');
  await mkdir(parent, { recursive: true });
  const root = await mkdtemp(join(parent, 'cli-operations-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  if (withGit) git(root, ['init', '--quiet']);
  const token = secret();
  const board = join(root, '_work', 'board');
  const initialize = target => invoke(root, target ?? board, 'initialize', {
    actorId: 'lead', leadToken: token, operationId: 'initialize' });
  return { root, board, token, initialize };
}

// A1: implemented catalog and selected input contracts are available before root/DB/runtime dispatch.
test('CLI.A1.helpCatalogWithoutProject', () => {
  const catalog = help();
  assert.equal(catalog.code, 0, JSON.stringify(catalog.reply));
  assert.equal(catalog.reply.schemaVersion, 1);
  assert.equal(catalog.reply.operation, 'help');
  assert.equal(catalog.reply.ok, true);
  const names = catalog.reply.result.commands.map(item => item.operation);
  for (const name of ['initialize', 'add', 'claim', 'assign', 'ask', 'answer', 'reconcile',
    'maintenance-status', 'enter-maintenance', 'migrate', 'inspect', 'serve']) {
    assert.ok(names.includes(name), `Implemented ${name} must be discoverable`);
  }
  assert.equal(new Set(names).size, names.length);
  for (const name of ['force-claim', 'reset', 'run-command', 'spawn-agent']) {
    assert.ok(!names.includes(name), `Unsupported ${name} must not be advertised`);
  }
});

// A1: nested and conditional inputs describe actual wire contracts without requiring both actor tokens.
test('CLI.A1.selectedOperationFields', () => {
  const expected = {
    add: ['operationId', 'actorId', 'generation', 'task', 'task.id', 'task.outcome'],
    reconcile: ['taskId', 'taskRevision', 'expectedInputRevision', 'decision'],
    answer: ['questionId', 'questionRevision', 'answerRevision', 'answer', 'answer.decision'],
    migrate: ['operationId', 'actorId', 'generation', 'expectedBoardRevision', 'maintenanceId',
      'maintenanceToken', 'fromVersion', 'toVersion', 'backupPath'],
  };
  for (const [operation, fields] of Object.entries(expected)) {
    const response = help(operation);
    assert.equal(response.code, 0, JSON.stringify(response.reply));
    const entry = response.reply.result.commands.find(item => item.operation === operation);
    assert.ok(entry);
    for (const field of fields) assert.ok(entry.requiredFields.includes(field), `${operation}.${field}`);
  }
  const claim = help('claim').reply.result.commands.find(item => item.operation === 'claim');
  const claimFields = [...claim.requiredFields,
    ...(claim.conditions ?? []).flatMap(item => item.requiredFields)];
  for (const field of ['workerToken', 'claimToken', 'taskRevision']) assert.ok(claimFields.includes(field));
  assert.ok(!claim.requiredFields.includes('leadToken'));
  assert.equal(help('future-unknown').reply.error.code, 'INVALID_INPUT');
});

// A2: exact Work scope policy is appended with original BOM/EOL preserved before database creation.
test('CLI.A2.workProtectionPreservesEncoding', async t => {
  const f = await project(t);
  const initial = Buffer.from('\ufeffexisting/\r\n', 'utf8');
  await writeFile(join(f.root, '.gitignore'), initial);
  const indexBefore = git(f.root, ['ls-files', '--stage']);
  const response = await f.initialize();
  assert.equal(response.code, 0, JSON.stringify(response.reply));
  const actual = await readFile(join(f.root, '.gitignore'));
  assert.deepEqual(actual, Buffer.from('\ufeffexisting/\r\n/_work/board/\r\n', 'utf8'));
  assert.equal(git(f.root, ['ls-files', '--stage']), indexBefore);
});

// A2: custom coordination paths require existing literal repository policy, never an inferred wildcard.
test('CLI.A2.customUnprotectedStopsBeforeWrite', async t => {
  const f = await project(t);
  await writeFile(join(f.root, '.gitignore'), '*.sqlite\n');
  const target = join(f.root, 'custom-coordination');
  const before = await readFile(join(f.root, '.gitignore'));
  const response = await f.initialize(target);
  assert.equal(response.code, 2);
  assert.equal(response.reply.ok, false);
  await assert.rejects(access(target), { code: 'ENOENT' });
  assert.deepEqual(await readFile(join(f.root, '.gitignore')), before);
});

// A2: tracked artifacts retain index and bytes, and must not receive a database despite ignore policy.
test('CLI.A2.trackedArtifactsStop', async t => {
  const f = await project(t);
  await mkdir(f.board, { recursive: true });
  await writeFile(join(f.board, 'existing.txt'), 'owned historical fixture');
  git(f.root, ['add', '--force', '_work/board/existing.txt']);
  const index = git(f.root, ['ls-files', '--stage']);
  const response = await f.initialize();
  assert.equal(response.code, 2);
  await assert.rejects(access(join(f.board, 'board.sqlite')), { code: 'ENOENT' });
  assert.equal(git(f.root, ['ls-files', '--stage']), index);
  assert.equal(await readFile(join(f.board, 'existing.txt'), 'utf8'), 'owned historical fixture');
});

// A2: independent backup directory requires its own narrow Work protection, not the live board rule.
test('CLI.A2.backupOutsideBoardProtected', async t => {
  const f = await project(t);
  await writeFile(join(f.root, '.gitignore'), '/_work/board/\n');
  const initialized = await f.initialize();
  assert.equal(initialized.code, 0);
  const destination = join(f.root, '_work', 'backups', 'consistent.sqlite');
  const backedUp = await invoke(f.root, f.board, 'backup', { actorId: 'lead', leadToken: f.token,
    generation: initialized.reply.generation, destination });
  assert.equal(backedUp.code, 0, JSON.stringify(backedUp.reply));
  assert.equal(await readFile(join(f.root, '.gitignore'), 'utf8'),
    '/_work/board/\n/_work/backups/\n');
});

// A2: non-Git projects remain usable without silently initializing Git or manufacturing ignore files.
test('CLI.A2.noGitDoesNotInitializeGit', async t => {
  const f = await project(t, false);
  assert.equal((await f.initialize()).code, 0);
  await assert.rejects(access(join(f.root, '.git')), { code: 'ENOENT' });
  await assert.rejects(access(join(f.root, '.gitignore')), { code: 'ENOENT' });
});

// Conditional credential documentation must reflect actor capabilities, not generic token alternatives.
test('CLI.A1.actorAndResolutionConditions', () => {
  const entry = name => help(name).reply.result.commands.find(item => item.operation === name);
  const alternatives = command => command.conditions ?? [];
  for (const name of ['report', 'block', 'submit']) {
    const conditions = alternatives(entry(name));
    assert.ok(conditions.some(item => item.requiredFields.includes('workerToken')));
    assert.ok(!conditions.some(item => item.requiredFields.includes('leadToken')),
      `${name} cannot advertise direct Lead execution; proxy uses lead-proxy-report`);
  }
  for (const name of ['ask', 'ack-answer']) {
    const command = entry(name);
    const proxy = alternatives(command).find(item => item.requiredFields.includes('leadToken'));
    assert.ok(proxy);
    assert.ok(proxy.requiredFields.includes('reportedByWorkerId'));
    assert.ok(!proxy.requiredFields.includes('workerToken'));
    if (name === 'ack-answer') {
      assert.ok([...command.requiredFields, ...proxy.requiredFields].includes('taskId'));
    }
  }
  assert.ok(alternatives(entry('answer')).some(item =>
    item.requiredFields.includes('answer.authorizationEvidenceRefs')),
  'Resolving an approval hold requires explicit conditional authorization evidence');
});

// Effective literal parent/custom policy is reusable; private excludes are not repository policy proof.
test('CLI.A2.literalPoliciesAndPrivateExcludes', async t => {
  for (const rule of ['/_work/\n', '/custom-coordination/\n']) {
    const f = await project(t);
    await writeFile(join(f.root, '.gitignore'), rule);
    const target = rule.includes('custom') ? join(f.root, 'custom-coordination') : f.board;
    assert.equal((await f.initialize(target)).code, 0);
    assert.equal(await readFile(join(f.root, '.gitignore'), 'utf8'), rule);
  }
  const f = await project(t);
  await writeFile(join(f.root, '.git', 'info', 'exclude'), '/private-coordination/\n');
  const target = join(f.root, 'private-coordination');
  assert.equal((await f.initialize(target)).code, 2);
  await assert.rejects(access(target), { code: 'ENOENT' });
});

// Explicit negation and external excludes cannot be silently replaced by a new permissive rule.
test('CLI.A2.negationAndExternalPolicyDenied', async t => {
  const f = await project(t);
  const policy = '/_work/\n!/_work/board/\n';
  await writeFile(join(f.root, '.gitignore'), policy);
  assert.equal((await f.initialize()).code, 2);
  assert.equal(await readFile(join(f.root, '.gitignore'), 'utf8'), policy);
  await assert.rejects(access(f.board), { code: 'ENOENT' });
  const other = await project(t);
  const external = join(other.root, 'external-excludes');
  await writeFile(external, '/external-coordination/\n');
  git(other.root, ['config', 'core.excludesFile', external]);
  const target = join(other.root, 'external-coordination');
  assert.equal((await other.initialize(target)).code, 2);
  await assert.rejects(access(target), { code: 'ENOENT' });
  const globalFixture = await project(t);
  const excludes = join(globalFixture.root, 'fixture-global-excludes');
  const config = join(globalFixture.root, 'fixture-global-config');
  await writeFile(excludes, '/global-coordination/\n');
  await writeFile(config, '[core]\n  excludesFile = ' +
    JSON.stringify(excludes.replaceAll('\\', '/')) + '\n');
  const globalTarget = join(globalFixture.root, 'global-coordination');
  const refused = await invoke(globalFixture.root, globalTarget, 'initialize', {
    actorId: 'lead', leadToken: globalFixture.token, operationId: 'global-policy-only' },
  { env: { GIT_CONFIG_GLOBAL: config } });
  assert.equal(refused.code, 2);
  await assert.rejects(access(globalTarget), { code: 'ENOENT' });
});

// Wrong credentials or stale generation cannot append backup policy or create a destination.
test('CLI.A2.backupAuthorizationBeforeAppend', async t => {
  const f = await project(t);
  const policy = '/_work/board/\n';
  await writeFile(join(f.root, '.gitignore'), policy);
  const initialized = await f.initialize();
  assert.equal(initialized.code, 0);
  for (const input of [{ leadToken: secret(), generation: initialized.reply.generation },
    { leadToken: f.token, generation: 'stale-generation' }]) {
    const destination = join(f.root, '_work', 'new-backups', 'backup.sqlite');
    const result = await invoke(f.root, f.board, 'backup', { actorId: 'lead', ...input, destination });
    assert.equal(result.code, 2);
    assert.equal(await readFile(join(f.root, '.gitignore'), 'utf8'), policy);
    await assert.rejects(access(join(f.root, '_work', 'new-backups')), { code: 'ENOENT' });
  }
});

// Linked ancestors and root escape are rejected within the enclosing owned fixture tree.
test('CLI.A2.linkAndEscapeDenied', async t => {
  const { symlink } = await import('node:fs/promises');
  const f = await project(t);
  const real = join(f.root, 'real-target');
  const linked = join(f.root, 'linked-target');
  await mkdir(real);
  await symlink(real, linked, 'junction');
  assert.equal((await f.initialize(join(linked, '_work', 'board'))).code, 2);
  await assert.rejects(access(join(real, '_work')), { code: 'ENOENT' });
  const childProject = join(f.root, 'child-project');
  await mkdir(childProject);
  const escaped = join(f.root, 'escaped-coordination');
  const result = await invoke(childProject, escaped, 'initialize', {
    actorId: 'lead', leadToken: f.token, operationId: 'escape' });
  assert.equal(result.code, 2);
  await assert.rejects(access(escaped), { code: 'ENOENT' });
});


// A legitimate closed backup at a noGit project root needs neither a parent ignore scope nor Git init.
test('CLI.A2.noGitRootBackup', async t => {
  const f = await project(t, false);
  const initialized = await f.initialize();
  assert.equal(initialized.code, 0);
  const destination = join(f.root, 'closed-root-backup.sqlite');
  const backup = await invoke(f.root, f.board, 'backup', { actorId: 'lead', leadToken: f.token,
    generation: initialized.reply.generation, destination });
  assert.equal(backup.code, 0, JSON.stringify(backup.reply));
  await access(destination);
  await assert.rejects(access(join(f.root, '.gitignore')), { code: 'ENOENT' });
  await assert.rejects(access(join(f.root, '.git')), { code: 'ENOENT' });
});

// The noGit exception never permits escaping its project; Git root files require explicit policy.
test('CLI.A2.rootFilePolicyAndContainment', async t => {
  const f = await project(t, false);
  const nested = join(f.root, 'nested-project');
  await mkdir(nested);
  const board = join(nested, '_work', 'board');
  const initialized = await invoke(nested, board, 'initialize', {
    actorId: 'lead', leadToken: f.token, operationId: 'nested-init' });
  assert.equal(initialized.code, 0);
  const outside = join(f.root, 'outside-project-backup.sqlite');
  const refused = await invoke(nested, board, 'backup', { actorId: 'lead', leadToken: f.token,
    generation: initialized.reply.generation, destination: outside });
  assert.equal(refused.reply.error.code, 'UNSAFE_PATH');
  await assert.rejects(access(outside), { code: 'ENOENT' });
  const repository = await project(t);
  const policy = '/_work/board/\n';
  await writeFile(join(repository.root, '.gitignore'), policy);
  const ready = await repository.initialize();
  assert.equal(ready.code, 0);
  const rootFile = join(repository.root, 'closed-root-backup.sqlite');
  const unprotected = await invoke(repository.root, repository.board, 'backup', {
    actorId: 'lead', leadToken: repository.token, generation: ready.reply.generation,
    destination: rootFile });
  assert.equal(unprotected.reply.error.code, 'ARTIFACTS');
  await assert.rejects(access(rootFile), { code: 'ENOENT' });
  assert.equal(await readFile(join(repository.root, '.gitignore'), 'utf8'), policy);
});
