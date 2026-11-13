/** Real Git directory exclusion regressions; disposable repositories only, no user policy edits. */
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { protectArtifacts } from '../../packages/task-board/src/coordination/artifact-protection.mjs';
import { prepareRequest } from '../../packages/task-board/src/activation/prepare.mjs';

/** Own one repository and remove only its resolved fixture directory after the case. */
function actualGit(t, ignore) {
  const parent = path.resolve('_work/task-board/test-fixtures');
  fs.mkdirSync(parent, { recursive: true });
  const root = fs.mkdtempSync(path.join(parent, 'artifact-policy-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const git = args => execFileSync('git', ['-C', root, ...args], { encoding: 'utf8' });
  git(['init', '--quiet']);
  fs.writeFileSync(path.join(root, '.gitignore'), ignore);
  return { root, git, policy: () => fs.readFileSync(path.join(root, '.gitignore'), 'utf8') };
}

// Unrelated exceptions and negations overridden by directory exclusion cannot expose descendants.
// Expect real Git-backed protection to reuse each literal policy without changing any bytes.
for (const ignore of [
  '.env*\n!.env.example\n/_work/task-board/\n',
  '!/_work/task-board/\n/_work/task-board/\n',
  '/_work/\n!.env.example\n',
  '/_work/task-board/\n!/_work/task-board/request.private.json\n',
]) {
  test(`actualGit reuses effective directory exclusion ${JSON.stringify(ignore)}`, t => {
    const f = actualGit(t, ignore);
    const boardPath = '_work/task-board/sessions/v1/' + 'a'.repeat(64);
    assert.equal(protectArtifacts({ projectRoot: f.root, boardPath, allowAppend: false }).status,
      'protected');
    assert.equal(f.policy(), ignore);
    assert.match(f.git(['check-ignore', '-v', '--', `${boardPath}/request.private.json`]),
      /_work/);
  });
}

test('actualGit realistic policy allows private request preparation without rewriting policy', t => {
  // Regression: common dotenv exceptions must not block credential preparation in an ignored Board.
  // Expect a private request file, no SQLite database, and byte-identical user policy.
  const ignore = 'node_modules/\n.env*\n!.env.example\ndist/\n/_work/task-board/\n';
  const f = actualGit(t, ignore);
  const result = prepareRequest(f.root, {
    action: 'prepare-request', actorId: 'lead', executionApproved: true,
    sessionProfile: { hostId: 'fixture', mainSessionId: 'main', projectId: 'project',
      projectName: 'Project', sessionName: 'Session' },
    task: { id: 'fixture-task', title: 'Task', outcome: 'Outcome',
      sourceRefs: ['fixture/work'], acceptanceRefs: ['fixture/accept'],
      scope: { read: [], write: [] } },
  });
  assert.equal(result.state, 'prepared', JSON.stringify(result));
  assert.ok(fs.existsSync(result.requestPath));
  assert.equal(fs.existsSync(path.join(path.dirname(result.requestPath), 'board.sqlite')), false);
  assert.equal(f.policy(), ignore);
});

test('actualGit exposed filename rejects even when a different child matches literal policy', t => {
  // A literal ignored child directory is insufficient: another filename remains explicitly exposed.
  // Expect rejection before any rewrite, proving safety is not based on an arbitrary child probe.
  const ignore = '/_work/task-board/\n!/_work/task-board/\n'
    + '/_work/task-board/.task-board-protection-probe/\n!/_work/task-board/private.json\n';
  const f = actualGit(t, ignore);
  assert.throws(() => protectArtifacts({ projectRoot: f.root,
    boardPath: '_work/task-board' }), { code: 'ARTIFACTS' });
  assert.equal(f.policy(), ignore);
});

test('actualGit tracked contents reject despite effective directory exclusion', t => {
  // Git ignore never protects already tracked data; forced fixture tracking must still fail closed.
  const ignore = '/_work/task-board/\n!.env.example\n';
  const f = actualGit(t, ignore);
  const scope = path.join(f.root, '_work/task-board');
  fs.mkdirSync(scope, { recursive: true });
  fs.writeFileSync(path.join(scope, 'tracked.json'), '{}');
  f.git(['add', '-f', '--', '_work/task-board/tracked.json']);
  assert.throws(() => protectArtifacts({ projectRoot: f.root, boardPath: scope }),
    { code: 'ARTIFACTS' });
  assert.equal(f.policy(), ignore);
});

test('actualGit custom scope reuses literal exclusion with nested policy audits', t => {
  // Custom scopes retain their existing literal-policy requirement; excluded nested includes
  // cannot expose content, but malformed policy bytes must still be audited and rejected.
  const ignore = '!example.txt\n/private-output/\n';
  const f = actualGit(t, ignore);
  const scope = path.join(f.root, 'private-output');
  fs.mkdirSync(scope);
  const nested = path.join(scope, '.gitignore');
  fs.writeFileSync(nested, '!request.private.json\n');
  assert.equal(protectArtifacts({ projectRoot: f.root, boardPath: scope,
    allowAppend: false }).status, 'protected');
  fs.writeFileSync(nested, Buffer.from([0xff]));
  assert.throws(() => protectArtifacts({ projectRoot: f.root, boardPath: scope }),
    { code: 'ARTIFACTS' });
  assert.equal(f.policy(), ignore);
  assert.deepEqual(fs.readFileSync(nested), Buffer.from([0xff]));
});

test('actualGit ignored descendant symlinks still reject before policy reuse', t => {
  // Even excluded trees must undergo link inspection; an owned junction must never bypass it.
  const ignore = '/_work/task-board/\n!.env.example\n';
  const f = actualGit(t, ignore);
  const scope = path.join(f.root, '_work/task-board');
  const target = path.join(f.root, 'target');
  fs.mkdirSync(scope, { recursive: true });
  fs.mkdirSync(target);
  try {
    fs.symlinkSync(target, path.join(scope, 'linked'), process.platform === 'win32' ? 'junction' : 'dir');
  } catch (error) {
    if (error.code !== 'EPERM') throw error;
    t.skip('Host does not permit creation of fixture directory links');
    return;
  }
  assert.throws(() => protectArtifacts({ projectRoot: f.root, boardPath: scope }),
    { code: 'UNSAFE_PATH' });
  assert.equal(f.policy(), ignore);
});
