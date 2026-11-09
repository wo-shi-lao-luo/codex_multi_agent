/** Read-only native source observations. Pins bind approval to file semantics, never native progress. */
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { BoardError } from '../domain/errors.mjs';
import { validateTaskScopes, collectTaskWorkspaceIds } from '../domain/workspace-scope.mjs';
import { assertWorkspaceBinding, workspaceBindings } from '../storage/workspaces.mjs';
import { inspectPath } from '../storage/paths.mjs';

const digest = value => createHash('sha256').update(value).digest('hex');
const budgets = new WeakMap();

/** Begin a fresh public operation; reusable in-memory transaction adapters must not reuse file proof. */
export function resetSourceObservation(context) { budgets.delete(context); }

/** Reject unknown typed mappings rather than silently treating them as opaque declarations. */
export function validateSourceRefs(refs) {
  if (!Array.isArray(refs)) throw new BoardError('INVALID_INPUT', 'Source references must be an array.');
  for (const ref of refs) {
    if (typeof ref === 'string' && ref) continue;
    const fields = ['workspaceId', 'schemaVersion', 'kind', 'nativeTaskId', 'expectedRevision',
      ...(ref?.kind === 'work' ? ['path'] : ['changeId'])];
    if (!ref || ref.schemaVersion !== 1 || !['work', 'openspec'].includes(ref.kind)
        || Object.keys(ref).some(key => !fields.includes(key))
        || ref.workspaceId !== undefined && (typeof ref.workspaceId !== 'string' || !ref.workspaceId)
        || typeof ref.nativeTaskId !== 'string' || !ref.nativeTaskId
        || ref.expectedRevision !== undefined && (typeof ref.expectedRevision !== 'string'
          || !/^[a-f0-9]{64}$/.test(ref.expectedRevision))
        || ref.kind === 'work' && (typeof ref.path !== 'string' || !ref.path)
        || ref.kind === 'openspec' && (!/^[a-z0-9][a-z0-9-]*$/.test(ref.changeId)
          || !/^\d+(?:\.\d+)*$/.test(ref.nativeTaskId))) {
      throw new BoardError('INVALID_INPUT', 'Unsupported typed source mapping or revision pin.');
    }
  }
}

/** Share caps across one transaction/query, including recursively checked accepted lineage. */
function budgetFor(context) {
  if (!budgets.has(context)) {
    budgets.set(context, { refs: 0, files: 0, bytes: 0, entries: 0, cache: new Map(), workspaces: new Set() });
  }
  return budgets.get(context);
}

/** Observe actual bounded files under a canonical root; no source content is returned or persisted. */
function observeReference(root, ref, budget) {
  const files = new Map();
  function limit(message) {
    budget.exhausted = true;
    throw new BoardError('SOURCE_LIMIT', message);
  }
  function remaining() {
    if (budget.exhausted || budget.bytes >= 4194304 || budget.files >= 256) {
      limit('Source observation exhausted its whole-operation budget.');
    }
    return 4194304 - budget.bytes;
  }
  function resolve(relative) {
    remaining();
    if (typeof relative !== 'string' || relative.includes('\\') || path.isAbsolute(relative)
        || relative.split('/').some(part => !part || part === '.' || part === '..')) {
      throw new BoardError('UNSAFE_PATH', 'Source path must be a contained relative path.');
    }
    const absolute = inspectPath(path.join(root, relative));
    const inside = path.relative(root, absolute);
    if (!inside || inside.startsWith('..') || path.isAbsolute(inside)) {
      throw new BoardError('UNSAFE_PATH', 'Source path escaped its project.');
    }
    return absolute;
  }
  function read(relative, required = false, normalizeTasks = false) {
    const file = resolve(relative);
    let handle;
    try {
      handle = fs.openSync(file, 'r');
      const stat = fs.fstatSync(handle);
      if (!stat.isFile()) throw new BoardError('SOURCE_UNAVAILABLE', 'Source is not a regular file.');
      const capacity = Math.min(1048576, remaining());
      if (stat.size > capacity) {
        limit('Source file exceeds the remaining whole-operation or per-file byte budget.');
      }
      budget.files++;
      // Bound actual reads, not merely the counter checked afterward. A growing file is rejected
      // through fstat instead of reading an extra byte beyond the operation's remaining allowance.
      const buffer = Buffer.alloc(capacity);
      let size = 0;
      while (size < buffer.length) {
        const count = fs.readSync(handle, buffer, size, buffer.length - size, null);
        if (!count) break;
        size += count;
        budget.bytes += count;
      }
      if (fs.fstatSync(handle).size > size) {
        limit('Source grew beyond its bounded read allowance.');
      }
      const text = new TextDecoder('utf-8', { fatal: true }).decode(buffer.subarray(0, size));
      const semantic = normalizeTasks ? text.replace(/^(\s*- )\[[ xX]\]/gm, '$1[ ]') : text;
      files.set(relative, digest(normalizeTasks ? semantic : buffer.subarray(0, size)));
      return text;
    } catch (error) {
      if (error.code === 'ENOENT' && !required) { files.set(relative, 'absent'); return null; }
      throw error;
    } finally { if (handle !== undefined) fs.closeSync(handle); }
  }
  function walk(relative) {
    const directory = resolve(relative);
    if (!fs.existsSync(directory)) return;
    const handle = fs.opendirSync(directory);
    try {
      while (true) {
        remaining();
        const item = handle.readSync();
        if (!item) break;
        if (++budget.entries > 4096) {
          limit('Source directory enumeration exceeded its bound.');
        }
        const next = `${relative}/${item.name}`;
        resolve(next);
        if (item.isDirectory()) walk(next);
        else read(next, true);
      }
    } finally { handle.closeSync(); }
  }
  if (ref.kind === 'work') read(ref.path, true);
  else {
    const marker = JSON.parse(read('openspec/team-integration.json', true));
    const config = read('openspec/config.yaml', true);
    // Match the existing optional adapter's pinned profile; do not execute or discover a native CLI.
    if (marker.schemaVersion !== 1 || marker.enabled !== true || marker.openSpecVersion !== '1.13.2'
        || !/^schema:\s*['"]?spec-driven['"]?\s*(?:#.*)?$/m.test(config)) {
      throw new BoardError('SOURCE_UNAVAILABLE', 'OpenSpec opt-in profile is unsupported.');
    }
    const base = `openspec/changes/${ref.changeId}`;
    for (const name of ['proposal.md', 'design.md', '.openspec.yaml']) read(`${base}/${name}`);
    walk('openspec/specs');
    walk(`${base}/specs`);
    const tasks = read(`${base}/tasks.md`, true, true);
    const ids = [...tasks.matchAll(/^\s*- \[[ xX]\]\s+(\d+(?:\.\d+)*)(?:\s|$)/gm)]
      .map(match => match[1]);
    if (new Set(ids).size !== ids.length) {
      return { status: 'ambiguous', reasonCode: 'DUPLICATE_NATIVE_ID' };
    }
    if (!ids.includes(ref.nativeTaskId)) return { status: 'missing-task', reasonCode: 'MISSING_NATIVE_ID' };
  }
  const snapshot = [...files].sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0)
    .map(([file, hash]) => ({ path: file, hash }));
  const actualRevision = digest(JSON.stringify(snapshot));
  return { snapshot, actualRevision, status: !ref.expectedRevision ? 'unpinned' :
    ref.expectedRevision === actualRevision ? 'matched' : 'changed' };
}

/** Compute current native observations, preserving legacy strings as explicitly unverified references.
 * Query observations are candidates only. Callers must use current pins again at mutation boundaries.
 */
export function observeSources(context, task) {
  validateTaskScopes(context, task);
  validateSourceRefs(task.sourceRefs);
  const budget = budgetFor(context);
  // Share fresh root proof within this operation, just like source observations. Recursive
  // lineage can revisit a workspace many times without adding quadratic Git/metadata reads.
  const unchecked = collectTaskWorkspaceIds(task, context)
    .filter(id => !budget.workspaces.has(id));
  workspaceBindings(context, unchecked);
  for (const id of unchecked) budget.workspaces.add(id);
  const key = JSON.stringify([task.id, task.workspaceId, task.sourceRefs]);
  if (budget.cache.has(key)) {
    return { ...budget.cache.get(key), comparedRevision: task.sourceObservation?.revision ?? null };
  }
  const checkedRefs = task.sourceRefs.map((ref, sourceRefIndex) => {
    if (typeof ref === 'string') return { sourceRefIndex, status: 'declared-unverified' };
    const mappingIdentity = { workspaceId: ref.workspaceId ?? task.workspaceId ?? 'main', kind: ref.kind, nativeTaskId: ref.nativeTaskId,
      ...(ref.kind === 'work' ? { path: ref.path } : { changeId: ref.changeId }) };
    let result;
    try {
      if (budget.exhausted || ++budget.refs > 32) {
        budget.exhausted = true;
        throw new BoardError('SOURCE_LIMIT', 'Source observation budget is exhausted.');
      }
      result = observeReference(assertWorkspaceBinding(context, ref.workspaceId ?? task.workspaceId ?? 'main').root, ref, budget);
    } catch (error) {
      result = { status: 'unavailable', reasonCode: error instanceof BoardError ? error.code :
        ['ENOENT', 'EACCES', 'EPERM'].includes(error.code) ? 'SOURCE_UNAVAILABLE' : 'SOURCE_INVALID' };
    }
    return { sourceRefIndex, mappingIdentity, ...result };
  });
  const priority = ['unavailable', 'ambiguous', 'missing-task', 'changed', 'unpinned', 'matched'];
  const dominant = priority.find(status => checkedRefs.some(ref => ref.status === status));
  const status = dominant === 'matched' ? 'unchanged' : dominant === 'unpinned' ? 'unbaselined' :
    dominant ?? 'declared-unverified';
  const observation = { schemaVersion: 1, status,
    revision: digest(JSON.stringify(checkedRefs)), checkedRefs,
    comparedRevision: task.sourceObservation?.revision ?? null,
    hasUnverifiedRefs: checkedRefs.some(ref => ref.status === 'declared-unverified') };
  budget.cache.set(key, observation);
  return observation;
}

/** Fail closed before execution whenever a typed source lacks a current, matched approval pin. */
export function requireCurrentSources(context, task, requireReconciled = false) {
  const observation = observeSources(context, task);
  if (!['unchanged', 'declared-unverified'].includes(observation.status)) {
    throw new BoardError('SOURCE_UNAVAILABLE', 'Typed source pins require explicit reconciliation.',
      { status: observation.status });
  }
  if (requireReconciled && observation.status === 'unchanged'
      && (task.sourceObservation?.boundInputRevision !== task.inputRevision
        || task.sourceObservation?.revision !== observation.revision)) {
    throw new BoardError('SOURCE_UNAVAILABLE', 'Current typed source pins need explicit Lead reconciliation.');
  }
  return observation;
}
