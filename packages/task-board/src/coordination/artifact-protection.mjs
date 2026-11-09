/** Protect exact local output scopes before CLI writes; never change Git's index or broad user policy. */
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { BoardError } from '../domain/errors.mjs';
import { inspectPath } from '../storage/paths.mjs';

function fail(message) { throw new BoardError('ARTIFACTS', message); }

/** Invoke Git without a shell, treating only the documented probe miss as a non-error. */
function git(root, args, miss = false) {
  try {
    return execFileSync('git', ['-C', root, ...args], {
      encoding: 'utf8', timeout: 10000, maxBuffer: 1048576, stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (error) {
    if (miss && error.status === 1) return '';
    throw new BoardError('ARTIFACTS', 'Git artifact policy could not be verified.');
  }
}

/** Validate prospective paths without creating them; a protected directory must be strictly local. */
function contained(root, target) {
  const absolute = inspectPath(path.resolve(root, target));
  const relative = path.relative(root, absolute).replaceAll('\\', '/');
  if (!relative || relative === '..' || relative.startsWith('../') || path.isAbsolute(relative)) {
    throw new BoardError('UNSAFE_PATH', 'Artifact scope must be strictly inside the project.');
  }
  return { absolute, relative };
}

/** Read policy bytes strictly so appending cannot silently corrupt user encoding or linked files. */
function policy(file) {
  inspectPath(file);
  if (!fs.existsSync(file)) return { bytes: Buffer.alloc(0), text: '' };
  const bytes = fs.readFileSync(file);
  let text;
  try { text = new TextDecoder('utf-8', { fatal: true }).decode(bytes); }
  catch { fail('Ignore policy must be valid UTF-8.'); }
  return { bytes, text };
}

/** Collect only relevant ancestor and descendant ignore files, refusing linked traversal. */
function relevantPolicies(root, scope) {
  const files = new Set([path.join(root, '.gitignore')]);
  let current = scope;
  while (current !== root) {
    files.add(path.join(current, '.gitignore'));
    current = path.dirname(current);
  }
  let count = 0;
  function descend(directory) {
    if (!fs.existsSync(directory)) return;
    for (const item of fs.readdirSync(directory, { withFileTypes: true })) {
      if (++count > 10000) fail('Artifact scope exceeds the policy audit bound.');
      const file = path.join(directory, item.name);
      inspectPath(file);
      if (item.isDirectory()) descend(file);
      else if (item.name === '.gitignore') files.add(file);
    }
  }
  descend(scope);
  return [...files];
}

/** Ignore unrelated anchored includes, but stop any include that can expose this output subtree. */
function conflictingInclude(file, scope, line) {
  if (!line.startsWith('!')) return false;
  const rule = line.slice(1).replace(/\/$/, '');
  if (!rule) return false;
  const relative = path.relative(path.dirname(file), scope).replaceAll('\\', '/');
  if (relative.startsWith('..')) return true; // Policy is already inside the protected scope.
  if (!rule.startsWith('/') && !rule.includes('/')) return true;
  const prefix = rule.replace(/^\//, '').split(/[?*\[]/, 1)[0].replace(/\/$/, '');
  return !prefix || relative === prefix || relative.startsWith(`${prefix}/`)
    || prefix.startsWith(`${relative}/`);
}

/** A literal directory policy must originate inside this project, with Git confirming effectiveness. */
function literalPolicy(root, repoRoot, relative) {
  const output = git(root, ['check-ignore', '--no-index', '-v', '--',
    `${relative}/.task-board-protection-probe`], true).trim();
  if (!output) return false;
  const match = /^(.*?):\d+:([^\t]+)\t/.exec(output);
  if (!match) return false;
  const source = path.resolve(repoRoot, match[1]);
  const sourceRelative = path.relative(root, source);
  if (sourceRelative.startsWith('..') || path.isAbsolute(sourceRelative)
      || path.basename(source) !== '.gitignore') return false;
  const rule = match[2];
  if (!rule.endsWith('/') || /[!*?\[\]\\]/.test(rule)) return false;
  const clean = rule.replace(/^\//, '').replace(/\/$/, '');
  if (!clean) return false; // A project-root ignore is never an owned artifact directory policy.
  const scope = path.resolve(root, relative);
  const exact = path.resolve(path.dirname(source), clean);
  // Unanchored basename rules can match a directory below the policy file.
  if (exact !== root && (exact === scope || scope.startsWith(exact + path.sep))) return true;
  if (!rule.startsWith('/') && !clean.includes('/')) {
    let ancestor = scope;
    while (ancestor !== path.dirname(source) && ancestor !== path.dirname(ancestor)) {
      if (path.basename(ancestor) === clean) return true;
      ancestor = path.dirname(ancestor);
    }
  }
  return false;
}

/** Establish all policies before any database/output write; policy conflicts never untrack artifacts.
 * Work scopes may append one exact rule. Custom scopes require an existing effective literal rule.
 */
export function protectArtifacts({ projectRoot, boardPath, destinations = [], allowAppend = true }) {
  const root = fs.realpathSync(inspectPath(projectRoot));
  const board = contained(root, boardPath);
  // File containment and link safety apply even without Git. Directory policy is a separate
  // Git-only concern: a valid output file may sit directly under a non-Git project root.
  const outputFiles = destinations.map(file => contained(root, file));
  let repoRoot;
  try {
    repoRoot = execFileSync('git', ['-C', root, 'rev-parse', '--show-toplevel'], {
      encoding: 'utf8', timeout: 10000, stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
  } catch (error) {
    if (error.status === 128 && /not a git repository/i.test(String(error.stderr))) {
      return { status: 'not-git' };
    }
    fail('Git availability could not be established.');
  }
  const scopes = [board, ...outputFiles.map(file => {
    const directory = path.dirname(file.absolute);
    if (directory === root) {
      fail('Git artifact output requires its own protected directory, not the project root.');
    }
    return contained(root, directory);
  }).filter(item => item.absolute !== board.absolute
    && !item.absolute.startsWith(board.absolute + path.sep))];
  const additions = [];
  for (const scope of new Map(scopes.map(item => [item.absolute, item])).values()) {
    if (git(root, ['ls-files', '-z', '--', `:(literal)${scope.relative}`]).length) {
      fail('Artifact scope contains tracked files.');
    }
    for (const file of relevantPolicies(root, scope.absolute)) {
      // A relevant explicit inclusion makes future output policy uncertain; never rewrite it.
      if (policy(file).text.split(/\r?\n/)
        .some(line => conflictingInclude(file, scope.absolute, line))) {
        fail('Explicit include policy conflicts with the artifact scope.');
      }
    }
    if (literalPolicy(root, repoRoot, scope.relative)) continue;
    if (!allowAppend) fail('Artifact scope needs an existing effective literal ignore policy.');
    const workScope = /^_work\/[a-zA-Z0-9][a-zA-Z0-9._-]*$/.test(scope.relative)
      && scope.relative.length <= 86;
    const sessionScope = /^_work\/task-board\/sessions\/v1\/[a-f0-9]{64}$/.test(scope.relative);
    if (!workScope && !sessionScope) fail('Custom artifact scope needs an effective literal ignore rule.');
    additions.push(`/${scope.relative}/`);
  }
  if (additions.length) {
    const file = path.join(root, '.gitignore');
    if (git(root, ['check-ignore', '--no-index', '--', '.gitignore'], true)) {
      fail('Project policy file is itself ignored; exact local protection cannot be established.');
    }
    const original = policy(file);
    const newline = original.text.includes('\r\n') ? '\r\n' : '\n';
    const separator = original.bytes.length && !original.text.endsWith('\n') ? newline : '';
    fs.writeFileSync(file, Buffer.concat([original.bytes,
      Buffer.from(separator + additions.join(newline) + newline)]));
    for (const scope of scopes) {
      if (!literalPolicy(root, repoRoot, scope.relative)) {
        fail('Appended artifact policy is not effective.');
      }
    }
  }
  return { status: 'protected' };
}
