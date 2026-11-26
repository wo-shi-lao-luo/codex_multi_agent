/** Resolve only displayed Board evidence and read it within its verified checkout. */
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { inspectPath } from '../storage/paths.mjs';
import { assertWorkspaceBinding } from '../storage/workspaces.mjs';

const formatByExtension = new Map([
  ['.md', 'markdown'], ['.markdown', 'markdown'], ['.txt', 'text'], ['.json', 'json'],
]);
// Bound both filesystem I/O and the amount of evidence returned to the renderer.
const maxTextBytes = 128 * 1024;
const maxJsonBytes = 256 * 1024;
const maxResultRows = 20;
const resultStates = new Set([
  'pass', 'passed', 'fail', 'failed', 'ok', 'success', 'succeeded', 'error',
  'partial', 'completed', 'skipped', 'blocked', 'pending', 'timeout',
]);
const scalarFields = [
  'status', 'result', 'outcome', 'verdict', 'ok', 'success',
  'total', 'passed', 'failed', 'skipped', 'pending', 'errors', 'warnings',
  'count', 'totalCount', 'passCount', 'failCount', 'passedCount', 'failedCount',
  'skippedCount', 'duration', 'durationMs',
];
const privateSegment = /^(?:_work|node_modules|(?:.*[-_.])?(?:api[-_]?keys?|secrets?|credentials?|passwords?|tokens?|private|auth|id_rsa|id_ed25519)(?:[-_.].*)?)$/i;

/** Normalize portable reference syntax; metadata labels never become filesystem input. */
function fileReference(value) {
  if (typeof value !== 'string' || value.length > 1024 || /[\u0000-\u001f\u007f]/u.test(value)) {
    return null;
  }
  if (/^file:/i.test(value)) {
    try {
      // URL parsing would discard dot segments before the containment checks could reject them.
      if (/(?:^|[\\/])(?:\.|%2e){1,2}(?=[\\/]|$)/i.test(value)) return null;
      const url = new URL(value);
      if (url.hostname || url.search || url.hash) return null;
      value = fileURLToPath(url, { windows: /^\/[a-z]:/i.test(url.pathname) });
    } catch {
      return null;
    }
  }
  const windowsAbsolute = /^[a-z]:[\\/]/i.test(value);
  if (/^[a-z][a-z0-9+.-]*:/i.test(value) && !windowsAbsolute) return null;
  const normalized = value.replaceAll('\\', '/');
  if (normalized.startsWith('//')) return null;
  const absolute = windowsAbsolute || normalized.startsWith('/');
  const pieces = normalized.slice(windowsAbsolute ? 3 : absolute ? 1 : 0).split('/');
  if (pieces.some(item => !item || item === '.' || item === '..' ||
    /[:<>"|?*]|[. ]$/u.test(item))) return null;
  return { normalized, absolute };
}

/** Match only an exact, still-registered frozen binding for submission evidence. */
function submissionRegistry(registry, submission) {
  if (!submission) return registry;
  const frozen = submission.workspaceBindings;
  if (!Array.isArray(frozen)) return [];
  return registry.filter(record => frozen.some(binding => binding.workspaceId === record.id &&
    binding.workspaceRevision === record.revision &&
    ['root', 'repositoryIdentity', 'checkoutIdentity'].every(key => binding[key] === record[key])));
}

function inside(root, target) {
  const relative = path.relative(root, target);
  return relative && relative !== '..' && !relative.startsWith('..' + path.sep) &&
    !path.isAbsolute(relative) ? relative : null;
}

/** Create an opaque preview ID for one renderable slot, retaining the origin only on the server. */
export function dashboardReference(board, task, value, slot, submission) {
  const typed = value && typeof value === 'object' && value.kind === 'work';
  const reference = fileReference(typed ? value.path : value);
  if (!reference) return null;

  const registry = Array.isArray(board.workspaces) ? board.workspaces.filter(record =>
    record?.status === 'active' && typeof record.root === 'string' && path.isAbsolute(record.root)) : [];
  const permitted = submissionRegistry(registry, submission);
  let workspace;
  let relative;
  if (reference.absolute) {
    if (!path.isAbsolute(reference.normalized)) return null;
    // Pick the nearest approved checkout. A stale binding cannot fall back to a parent checkout.
    workspace = registry.filter(record => inside(record.root, reference.normalized))
      .sort((left, right) => right.root.length - left.root.length)[0];
    if (!permitted.includes(workspace) ||
        (typed && value.workspaceId && workspace.id !== value.workspaceId)) return null;
    relative = inside(workspace.root, reference.normalized);
  } else {
    workspace = submission ? (permitted.length === 1 ? permitted[0] : null) :
      permitted.find(record => record.id === (value?.workspaceId ?? task.workspaceId ?? 'main'));
    relative = reference.normalized;
  }
  if (!workspace || !relative) return null;

  const parts = relative.replaceAll('\\', '/').split('/');
  const format = formatByExtension.get(path.extname(relative).toLowerCase());
  if (!format || parts.some(part => privateSegment.test(part) ||
    (part.startsWith('.') && (part !== '.runtime' || format !== 'json')))) return null;

  const id = createHash('sha256').update(JSON.stringify([
    board.generation, task.id, slot, workspace.id, workspace.revision,
    workspace.root, relative, submission?.id ?? null,
  ])).digest('hex');
  return { id, workspaceId: workspace.id, root: workspace.root, relative, format };
}

/** Extract only report numbers and fixed outcome values, never arbitrary text or nested payloads. */
function reportScalars(source) {
  if (!source || typeof source !== 'object' || Array.isArray(source)) return {};
  return Object.fromEntries(scalarFields.flatMap(key => {
    const value = source[key];
    if (typeof value === 'number' && Number.isFinite(value) && value >= 0) return [[key, value]];
    if ((key === 'ok' || key === 'success') && typeof value === 'boolean') return [[key, value]];
    if (['status', 'result', 'outcome', 'verdict'].includes(key) &&
        typeof value === 'string' && resultStates.has(value.toLowerCase())) {
      return [[key, value.toLowerCase()]];
    }
    return [];
  }));
}

function reportPreview(source) {
  if (!source || typeof source !== 'object') return null;
  const data = reportScalars(source);
  let truncated = false;
  for (const key of ['summary', 'stats', 'totals', 'counts']) {
    const summary = reportScalars(source[key]);
    if (Object.keys(summary).length) data[key] = summary;
  }
  for (const key of ['results', 'tests', 'cases', 'checks']) {
    const items = Array.isArray(source) && key === 'results' ? source : source[key];
    if (!Array.isArray(items)) continue;
    const rows = items.slice(0, maxResultRows).map(reportScalars)
      .filter(row => Object.keys(row).length);
    if (rows.length) data[key] = rows;
    truncated ||= items.length > maxResultRows;
  }
  return Object.keys(data).length ?
    { format: 'json', content: JSON.stringify(data, null, 2), truncated } : null;
}

/** Reject nested, independently bound checkouts rather than silently changing artifact identity. */
function withinCheckout(root, file) {
  const relative = inside(root, file);
  if (!relative) return false;
  let directory = root;
  for (const part of relative.split(path.sep).slice(0, -1)) {
    directory = path.join(directory, part);
    if (fs.existsSync(path.join(directory, '.git'))) return false;
  }
  return true;
}

/** Return bounded inert UTF-8 content; unreadable, stale or prohibited evidence is unavailable. */
export function readDashboardReference(board, reference) {
  let descriptor;
  try {
    const workspace = assertWorkspaceBinding({ board }, reference.workspaceId);
    if (workspace.root !== reference.root) return null;
    const file = inspectPath(path.join(workspace.root, reference.relative));
    const before = fs.lstatSync(file, { bigint: true });
    if (!before.isFile() || before.nlink !== 1n ||
        !withinCheckout(workspace.root, fs.realpathSync(file))) return null;

    descriptor = fs.openSync(file, fs.constants.O_RDONLY |
      (fs.constants.O_NOFOLLOW ?? 0) | (fs.constants.O_NONBLOCK ?? 0));
    const opened = fs.fstatSync(descriptor, { bigint: true });
    // Recheck ancestors after opening and verify that the handle still represents the checked file.
    if (!opened.isFile() || opened.nlink !== 1n || opened.dev !== before.dev ||
        opened.ino !== before.ino ||
        !withinCheckout(workspace.root, fs.realpathSync(inspectPath(file)))) {
      return null;
    }

    const maxBytes = reference.format === 'json' ? maxJsonBytes : maxTextBytes;
    if (reference.format === 'json' && opened.size > BigInt(maxBytes)) return null;
    const bytes = Buffer.alloc(Math.min(Number(opened.size), maxBytes + 1));
    let length = 0;
    while (length < bytes.length) {
      const read = fs.readSync(descriptor, bytes, length, bytes.length - length, length);
      if (!read) break;
      length += read;
    }
    const truncated = length > maxBytes;
    const decoder = new TextDecoder('utf-8', { fatal: true });
    const content = decoder.decode(bytes.subarray(0, Math.min(length, maxBytes)), { stream: truncated });
    if (/\u0000/u.test(content)) return null;
    if (reference.format === 'json') return reportPreview(JSON.parse(content));
    return { format: reference.format, content, truncated };
  } catch {
    // Errors may include absolute filenames or in-file content; never send them to the dashboard.
    return null;
  } finally {
    if (descriptor !== undefined) fs.closeSync(descriptor);
  }
}
