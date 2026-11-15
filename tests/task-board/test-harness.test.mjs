// Exercise actual wrapper selection and source resolution from a foreign working directory.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { checkFixturePath, requireLoopback, fixtureDirectoryLink } from './fixture-environment.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const wrapper = join(root, 'tests/test-task-board.ps1');
// The wrapper is an external CLI invocation, not a nested Node test-worker transport.
const environment = { ...process.env };
delete environment.NODE_TEST_CONTEXT;

async function foreign(t) {
  const directory = await mkdtemp(join(tmpdir(), 'board-harness-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  return directory;
}

// A helper imported from this checkout must select its CLI, not a cwd-relative nonexistent CLI.
test('HARNESS.sourcePinnedOutsideCheckout', async t => {
  const cwd = await foreign(t);
  const module = new URL('./helpers.mjs', import.meta.url).href;
  const child = spawnSync(process.execPath, ['--input-type=module', '-e',
    `import {cli} from ${JSON.stringify(module)}; console.log(cli);`],
  { cwd, encoding: 'utf8' });
  assert.equal(child.status, 0, child.stderr);
  assert.equal(child.stdout.trim(), join(root, 'packages/task-board/src/cli/cli.mjs'));
});

// A controlled alternate CLI must still override the default source-pinned entry.
test('HARNESS.explicitEntrypointRemainsAuthoritative', async t => {
  const directory = await foreign(t);
  const entrypoint = join(directory, 'alternate.mjs');
  await writeFile(entrypoint, 'console.log(JSON.stringify({ok:true,selected:"explicit"}));');
  const { invoke } = await import('./helpers.mjs');
  const result = await invoke(directory, join(directory, 'unused'), 'inspect', {}, { entrypoint });
  assert.equal(result.code, 0);
  assert.equal(result.reply.selected, 'explicit');
});

// Selecting one named test must reach that actual test, without starting the whole suite.
test('HARNESS.wrapperSelectsFileAndCaseOutsideCheckout', async t => {
  const cwd = await foreign(t);
  const child = spawnSync('pwsh', ['-NoProfile', '-File', wrapper,
    '-NodePath', process.execPath, '-TestFile', 'activation-request-recovery.test.mjs',
    '-TestNamePattern', 'REQUEST.recovery.rejectLegacy.writeScope'],
  { cwd, env: environment, encoding: 'utf8', timeout: 30000 });
  assert.equal(child.error, undefined);
  assert.equal(child.status, 0, child.stderr + child.stdout);
  assert.match(child.stdout, /REQUEST\.recovery\.rejectLegacy\.writeScope/);
  assert.doesNotMatch(child.stdout, /CLI\.A1|INPUT\.CP936/);
});

// Invalid selections must be diagnosed as setup errors rather than executing arbitrary paths.
test('HARNESS.wrapperRejectsTraversal', async t => {
  const child = spawnSync('pwsh', ['-NoProfile', '-File', wrapper,
    '-NodePath', process.execPath, '-TestFile', '../activation-input.test.mjs'],
  { cwd: await foreign(t), encoding: 'utf8', timeout: 15000 });
  assert.notEqual(child.status, 0);
  assert.match(child.stderr, /TEST_SETUP:.*TEST_FILE/);
});

// A malformed or nonexistent basename cannot broaden selection to other files.
test('HARNESS.wrapperRejectsUnknownAndWildcard', async t => {
  for (const name of ['unknown-harness.test.mjs', '*.test.mjs']) {
    const child = spawnSync('pwsh', ['-NoProfile', '-File', wrapper,
      '-NodePath', process.execPath, '-TestFile', name],
    { cwd: await foreign(t), encoding: 'utf8', timeout: 15000 });
    assert.notEqual(child.status, 0);
    assert.match(child.stderr, /TEST_SETUP:.*TEST_FILE/);
  }
});

// This diagnoses SQLite's Windows fixture boundary, without changing product path policy.
test('HARNESS.windowsLongPathIsSetupError', () => {
  if (process.platform === 'win32') {
    assert.throws(() => checkFixturePath('x'.repeat(260)), /TEST_SETUP: PATH_TOO_LONG/);
  } else {
    assert.doesNotThrow(() => checkFixturePath('x'.repeat(260)));
  }
  assert.doesNotThrow(() => checkFixturePath(join(root, 'board.sqlite')));
});

// Probe transport behavior only; an unavailable host is not proof the Board service works.
test('HARNESS.loopbackProbeReportsCapability', async () => {
  try { await requireLoopback(); }
  catch (error) {
    assert.equal(error.code, 'TEST_SETUP');
    assert.match(error.message, /LOOPBACK_UNAVAILABLE/);
    assert.ok(error.cause);
  }
});

// Missing fixture parents remain bugs; permission denial is reported as a setup prerequisite.
test('HARNESS.directoryLinkErrorPreservesCategory', async t => {
  const directory = await foreign(t);
  await assert.rejects(fixtureDirectoryLink(directory, join(directory, 'missing', 'link')),
    error => error.code === 'ENOENT' ||
      error.code === 'TEST_SETUP' && /DIRECTORY_LINK_UNAVAILABLE/.test(error.message));
});
