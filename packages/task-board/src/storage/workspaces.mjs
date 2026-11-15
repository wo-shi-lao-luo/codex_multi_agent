/** Persisted checkout identity verification. Registration policy and task scopes stay domain-owned. */
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { inspectPath } from './paths.mjs';
import { StorageError } from './errors.mjs';

// Small-board registry limit; registration rejects overflow rather than dropping retained bindings.
export const MAX_WORKSPACES = 100;

// Only storage-owned synchronous operation/read/replay contexts opt in. Never connection/global cache.
const observations = new WeakMap();
export function beginWorkspaceObservation(tx) {
  observations.set(tx, { bindings: new Map(), roots: new Map() });
}
export function discardWorkspaceObservation(tx) { if (tx) observations.delete(tx); }

/** Retain physical identity and the bytes of Git-owned pointer files, never HEAD/branch content. */
function physicalSnapshot(root, metadata = {}) {
  const paths = new Set([root, path.join(root, '.git')]);
  for (const value of [metadata.common, metadata.checkout]) if (value) {
    paths.add(value);
    for (const leaf of ['commondir', 'gitdir']) paths.add(path.join(value, leaf));
  }
  return [...paths].map(value => {
    inspectPath(value);
    let stat;
    try { stat = fs.statSync(value, { bigint: true }); }
    catch (error) { if (error.code === 'ENOENT') return [value, null]; throw error; }
    if (stat.isFile() && stat.size > 8192n) {
      throw new StorageError('WORKSPACE_MISMATCH', 'Git identity pointer exceeds its bound.');
    }
    return [value, fs.realpathSync(value), String(stat.dev), String(stat.ino),
      stat.isDirectory() ? 'directory' : fs.readFileSync(value, 'utf8')];
  });
}

function observedRoot(tx, value, main = false) {
  const context = observations.get(tx);
  const root = canonicalDirectory(value);
  const retained = context?.roots.get(root);
  if (retained) {
    if (JSON.stringify(physicalSnapshot(root, retained.metadata)) !== retained.physical) {
      throw new StorageError('WORKSPACE_MISMATCH', 'Workspace physical identity has drifted.');
    }
    return retained.identity;
  }
  const metadata = {};
  const identity = main ? initializeMainWorkspace(root, metadata) : gitIdentity(root, metadata);
  if (context) context.roots.set(root, { identity, metadata,
    physical: JSON.stringify(physicalSnapshot(root, metadata)) });
  return identity;
}

/** Complete a fresh full identity pass over every binding used, including newly registered ones. */
export function finishWorkspaceObservation(tx) {
  const context = observations.get(tx);
  if (!context) return;
  try {
    // Separate pass: no initial Git observation can satisfy the final verification.
    observations.set(tx, { bindings: new Map(), roots: new Map() });
    for (const [id, binding] of context.bindings) {
      if (JSON.stringify(assertWorkspaceBinding(tx, id)) !== binding) {
        throw new StorageError('WORKSPACE_MISMATCH', 'Workspace binding changed during the operation.');
      }
    }
  } finally { observations.delete(tx); }
}

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
function gitIdentity(root, metadata = {}) {
  inspectPath(path.join(root, '.git'));
  const top = canonicalDirectory(git(root, ['rev-parse', '--show-toplevel']));
  if (top !== root) {
    throw new StorageError('WORKSPACE_MISMATCH', 'Workspace must be the actual Git checkout root.');
  }
  const common = canonicalDirectory(git(root,
    ['rev-parse', '--path-format=absolute', '--git-common-dir']));
  const checkout = canonicalDirectory(git(root, ['rev-parse', '--absolute-git-dir']));
  Object.assign(metadata, { common, checkout });
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
export function initializeMainWorkspace(value, metadata = {}) {
  const root = canonicalDirectory(value);
  inspectPath(path.join(root, '.git'));
  let identity;
  try { identity = gitIdentity(root, metadata); }
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
    const main = observedRoot(tx, tx.board.projectRoot, true);
    actual = id === 'main' ? main : observedRoot(tx, stored.root);
    if (id !== 'main' && (!main.repositoryIdentity || main.repositoryIdentity !== actual.repositoryIdentity)) {
      throw new StorageError('WORKSPACE_MISMATCH', 'Workspace belongs to a different repository.');
    }
  } catch {
    throw new StorageError('WORKSPACE_MISMATCH', 'Workspace binding has drifted.');
  }
  if (['root', 'repositoryIdentity', 'checkoutIdentity'].some(key => actual[key] !== stored[key])) {
    throw new StorageError('WORKSPACE_MISMATCH', 'Workspace identity no longer matches registration.');
  }
  const context = observations.get(tx);
  const binding = JSON.stringify(stored);
  if (context?.bindings.has(id) && context.bindings.get(id) !== binding) {
    throw new StorageError('WORKSPACE_MISMATCH', 'Workspace registration changed during the operation.');
  }
  context?.bindings.set(id, binding);
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
