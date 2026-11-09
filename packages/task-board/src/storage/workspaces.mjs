/** Persisted checkout identity verification. Registration policy and task scopes stay domain-owned. */
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { inspectPath } from './paths.mjs';
import { StorageError } from './errors.mjs';

// Small-board registry limit; registration rejects overflow rather than dropping retained bindings.
export const MAX_WORKSPACES = 100;

// Device/inode plus canonical path detects replacement without depending on branch names or HEAD.
function directoryIdentity(root) {
  const stat = fs.statSync(root, { bigint: true });
  if (!stat.isDirectory()) throw new StorageError('UNSAFE_PATH', 'Workspace must be a directory.');
  return `${root}:${stat.dev}:${stat.ino}`;
}

/** Run only bounded, read-only Git plumbing; no shell, network, hook or caller-supplied option. */
function git(root, args) {
  try {
    const env = Object.fromEntries(Object.entries(process.env)
      .filter(([key]) => !key.toUpperCase().startsWith('GIT_')));
    return execFileSync('git', ['--no-optional-locks', '-c', 'core.fsmonitor=false',
      '-C', root, ...args], { encoding: 'utf8', timeout: 5000,
      maxBuffer: 1024 * 1024, windowsHide: true, env,
      stdio: ['ignore', 'pipe', 'pipe'] }).trimEnd();
  } catch {
    throw new StorageError('WORKSPACE_MISMATCH', 'Git workspace identity could not be verified.');
  }
}

function canonicalDirectory(value) {
  const root = fs.realpathSync(inspectPath(value));
  directoryIdentity(root);
  return root;
}

/** Verify an actual checkout root and its Git metadata, rejecting subdirectories and path links. */
function gitIdentity(root) {
  inspectPath(path.join(root, '.git'));
  const top = canonicalDirectory(git(root, ['rev-parse', '--show-toplevel']));
  if (top !== root) {
    throw new StorageError('WORKSPACE_MISMATCH', 'Workspace must be the actual Git checkout root.');
  }
  const common = canonicalDirectory(git(root,
    ['rev-parse', '--path-format=absolute', '--git-common-dir']));
  const checkout = canonicalDirectory(git(root, ['rev-parse', '--absolute-git-dir']));
  // Linked checkouts have a reciprocal Git-owned backlink. A forged .git pointer alone is insufficient.
  if (checkout !== common) {
    const backlink = inspectPath(path.join(checkout, 'gitdir'));
    const marker = fs.realpathSync(inspectPath(path.join(root, '.git')));
    const target = fs.realpathSync(inspectPath(fs.readFileSync(backlink, 'utf8').trim()));
    if (!fs.statSync(marker).isFile() || target !== marker) {
      throw new StorageError('WORKSPACE_MISMATCH', 'Linked checkout metadata is not reciprocal.');
    }
  }
  const registered = git(root, ['worktree', 'list', '--porcelain', '-z']).split('\0')
    .filter(value => value.startsWith('worktree ')).map(value => value.slice(9));
  if (!registered.some(value => path.resolve(value) === root
      && canonicalDirectory(value) === root)) {
    throw new StorageError('WORKSPACE_MISMATCH', 'Checkout is absent from the Git worktree registry.');
  }
  if (checkout === common && canonicalDirectory(registered[0]) !== root) {
    throw new StorageError('WORKSPACE_MISMATCH', 'Primary checkout identity does not match Git metadata.');
  }
  return { root, repositoryIdentity: directoryIdentity(common),
    checkoutIdentity: `${directoryIdentity(root)}|${directoryIdentity(checkout)}` };
}

/** Initialize the sole legacy-compatible main binding; non-Git projects cannot add workspaces. */
export function initializeMainWorkspace(value) {
  const root = canonicalDirectory(value);
  inspectPath(path.join(root, '.git'));
  let identity;
  try { identity = gitIdentity(root); }
  catch (error) {
    // A local Git marker must be valid; an ordinary non-repository project remains supported.
    if (fs.existsSync(path.join(root, '.git'))) throw error;
    identity = { root, repositoryIdentity: null, checkoutIdentity: directoryIdentity(root) };
  }
  return { id: 'main', revision: 1, ...identity, status: 'active' };
}

/** Prove candidate membership in the main checkout's repository; sibling checkouts are allowed. */
export function verifyWorkspaceRoot(mainRoot, candidateRoot) {
  const main = gitIdentity(canonicalDirectory(mainRoot));
  const candidate = gitIdentity(canonicalDirectory(candidateRoot));
  if (main.repositoryIdentity !== candidate.repositoryIdentity) {
    throw new StorageError('WORKSPACE_MISMATCH', 'Workspace belongs to a different repository.');
  }
  return candidate;
}

/** Revalidate a stored binding without repairing, retargeting or persisting anything on reads. */
export function assertWorkspaceBinding(tx, id = 'main') {
  const registry = tx.board.workspaces;
  if (!Array.isArray(registry) || registry.length > MAX_WORKSPACES
      || registry.some(item => !item || typeof item !== 'object' || typeof item.id !== 'string')
      || new Set(registry.map(item => item.id)).size !== registry.length) {
    throw new StorageError('WORKSPACE_MISMATCH', 'Workspace registry is missing or invalid.');
  }
  const stored = registry.find(item => item.id === id);
  if (!stored || stored.status !== 'active' || !Number.isSafeInteger(stored.revision)
      || stored.revision < 1 || (id === 'main' && stored.root !== tx.board.projectRoot)) {
    throw new StorageError('WORKSPACE_MISMATCH', 'Workspace binding is unavailable.');
  }
  let actual;
  try {
    actual = id === 'main' ? initializeMainWorkspace(tx.board.projectRoot)
      : verifyWorkspaceRoot(tx.board.projectRoot, stored.root);
  } catch {
    throw new StorageError('WORKSPACE_MISMATCH', 'Workspace binding has drifted.');
  }
  if (['root', 'repositoryIdentity', 'checkoutIdentity'].some(key => actual[key] !== stored[key])) {
    throw new StorageError('WORKSPACE_MISMATCH', 'Workspace identity no longer matches registration.');
  }
  return structuredClone(stored);
}

/** Freeze sorted, distinct workspace identities into an immutable grant/execution/evidence binding. */
export function workspaceBindings(tx, workspaceIds = ['main']) {
  if (!Array.isArray(workspaceIds) || workspaceIds.some(id => typeof id !== 'string' || !id)) {
    throw new StorageError('INVALID_INPUT', 'Workspace IDs must be nonempty strings.');
  }
  return [...new Set(workspaceIds)].sort().map(id => {
    const record = assertWorkspaceBinding(tx, id);
    return { workspaceId: id, workspaceRevision: record.revision, root: record.root,
      repositoryIdentity: record.repositoryIdentity, checkoutIdentity: record.checkoutIdentity };
  });
}
