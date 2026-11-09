/** Scope declarations bind canonical registered checkouts without retargeting missing roots. */
import path from 'node:path';
import { existsSync, lstatSync, realpathSync } from 'node:fs';
import { BoardError } from './errors.mjs';
import { assertWorkspaceBinding, workspaceBindings } from '../storage/workspaces.mjs';
/** Collect execution, explicit scope and typed-source workspace selectors. */
export function collectTaskWorkspaceIds(task, tx, visited = new Set()) {
  if (!task || visited.has(task.id)) return [];
  visited.add(task.id);
  return [...new Set([task.workspaceId ?? 'main',
    ...(tx ? tx.dependencies.list({ taskId: task.id }).flatMap(edge =>
      collectTaskWorkspaceIds(tx.tasks.get(edge.dependsOnTaskId), tx, visited)) : []),
    ...[...(task.scope?.read ?? []), ...(task.scope?.write ?? []), ...(task.sourceRefs ?? [])]
      .filter(item => item && typeof item === 'object')
      .map(item => item.workspaceId ?? task.workspaceId ?? 'main')])];
}
/** Normalize a scope using the strict existing path validator and registered root. */
export function normalizeWorkspaceScope(tx, task, value, normalize) {
  const id = typeof value === 'string' ? task.workspaceId ?? 'main' : value?.workspaceId;
  if (typeof id !== 'string' || !id) {
    throw new BoardError('INVALID_INPUT', 'Object scopes require an explicit workspace ID.');
  }
  const workspace = assertWorkspaceBinding(tx, id);
  const clean = normalize(workspace.root, typeof value === 'string' ? value : value?.path);
  return typeof value === 'string' ? clean : { workspaceId: id, path: clean };
}
/** Physical checkout keys prevent aliases escaping the global reservation namespace. */
export function scopeResourceKey(tx, task, value) {
  const workspace = assertWorkspaceBinding(tx,
    typeof value === 'string' ? task.workspaceId ?? 'main' : value.workspaceId);
  return canonicalPhysicalPathKey(path.join(workspace.root,
    typeof value === 'string' ? value : value.path));
}
/** Canonicalize physical path syntax only; callers separately prove root identity and containment. */
export function canonicalPhysicalPathKey(value) {
  const key = path.normalize(value).replaceAll('\\', '/');
  return process.platform === 'win32' ? key.toLowerCase() : key;
}

/** Trusted CLI cwd applies only to multiworkspace execution, preserving legacy main use. */
export function requireExecutionCwd(tx, task, cwd) {
  if (!task) throw new BoardError('NOT_FOUND', 'Task does not exist.');
  const bindings = workspaceBindings(tx, collectTaskWorkspaceIds(task, tx));
  if (bindings.length === 1 && bindings[0].workspaceId === 'main') return;
  const root = assertWorkspaceBinding(tx, task.workspaceId ?? 'main').root;
  let relative;
  let actual;
  try {
    actual = realpathSync(cwd);
    relative = path.relative(root, actual);
  } catch {
    throw new BoardError('WORKSPACE_MISMATCH', 'Execution directory is unavailable.');
  }
  if (relative.startsWith('..') || path.isAbsolute(relative)) {
    throw new BoardError('WORKSPACE_MISMATCH', 'Actor is outside execution checkout.');
  }
  // Containment alone is insufficient when another worktree is nested under the assigned root.
  for (let directory = actual; directory !== root; directory = path.dirname(directory)) {
    if (existsSync(path.join(directory, '.git'))) {
      throw new BoardError('WORKSPACE_MISMATCH', 'Actor is inside a different nested checkout.');
    }
    if (path.dirname(directory) === directory) {
      throw new BoardError('WORKSPACE_MISMATCH', 'Execution checkout cannot be established.');
    }
  }
}

/** Scope validation errors are domain failures, never implicit filesystem authorization. */
function requireValue(condition, code, message) {
  if (!condition) throw new BoardError(code, message);
}

/** Validate exact paths and directory prefixes without allowing links or root escape. */
export function normalizeScope(root, value) {
  requireValue(typeof value === 'string' && value.length > 0 && !value.includes('\\') &&
    !/[\*?\[\]]/.test(value) && !path.isAbsolute(value), 'UNSAFE_PATH', 'Invalid scope path.');
  // Validate prospective components before normalization or ENOENT can erase ambiguity.
  const components = value.replace(/\/$/, '').split('/');
  for (const component of components) {
    requireValue(component.length > 0 && !['.', '..'].includes(component) &&
      !/[. ]$/.test(component) && !/[\x00-\x1f<>:"|?*]/.test(component) &&
      !/^(?:con|prn|aux|nul|com[1-9¹²³]|lpt[1-9¹²³])(?:\..*)?$/i.test(component),
      'UNSAFE_PATH', 'Scope contains an ambiguous or reserved path component.');
  }
  const clean = path.posix.normalize(value).replace(/\/$/, '');
  requireValue(clean !== '.' && clean !== '..' && !clean.startsWith('../'),
    'UNSAFE_PATH', 'Scope must stay inside the project.');
  let current = root;
  for (const part of clean.split('/')) {
    current = path.join(current, part);
    try {
      const entry = lstatSync(current);
      requireValue(!entry.isSymbolicLink() && !(entry.isFile() && entry.nlink > 1),
        'UNSAFE_PATH', 'Scope contains a symbolic or hard link.');
      requireValue(realpathSync(current) === current,
        'UNSAFE_PATH', 'Scope resolves ambiguously.');
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  }
  return clean;
}

/** Recheck prospective scope components at every execution and evidence boundary. */
export function validateTaskScopes(tx, task) {
  for (const value of [...task.scope.read, ...task.scope.write]) {
    const current = normalizeWorkspaceScope(tx, task, value, normalizeScope);
    if (JSON.stringify(current) !== JSON.stringify(value)) {
      throw new BoardError('UNSAFE_PATH', 'Scope no longer matches its canonical declaration.');
    }
  }
}
