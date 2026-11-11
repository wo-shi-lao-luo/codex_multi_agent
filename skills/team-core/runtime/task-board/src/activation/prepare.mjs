/** Prepare one caller-owned credential file; never rotate or recover existing Board authority. */
import fs from 'node:fs';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { normalizeSessionProfile, sessionLocation } from '../domain/session.mjs';
import { inspectPath } from '../storage/paths.mjs';
import { protectArtifacts } from '../coordination/artifact-protection.mjs';
import { requestIssues, invalidRequest } from './request.mjs';

export function prepareRequest(projectRoot, request) {
  let lock;
  let lockPath;
  const issues = requestIssues(request, { prepare: true });
  if (issues.missingFields.length || issues.invalidFields.length) return invalidRequest(issues);
  try {
    const profile = normalizeSessionProfile(request.sessionProfile);
    const selected = sessionLocation(profile);
    const root = inspectPath(projectRoot);
    const directory = inspectPath(path.join(root, selected.boardPath));
    const requestPath = inspectPath(path.join(directory, 'request.private.json'));
    // Existing database, sidecars or caller state must be reconciled, never overwritten.
    const retained = ['board.sqlite', 'board.sqlite-wal', 'board.sqlite-shm', 'board.sqlite-journal', 'activation.json',
      'request.private.json'];
    if ([...retained,
      'activation.lock', 'request.private.json'].some(name => fs.existsSync(path.join(directory, name)))) {
      return { state: 'activation-pending', reasonCode: 'REQUEST_HANDOFF_REQUIRED',
        nextStep: 'Reuse the existing private request and verify fresh native identity; never generate replacement credentials.' };
    }
    protectArtifacts({ projectRoot: root, ...selected, allowAppend: true });
    fs.mkdirSync(directory, { recursive: true });
    lockPath = inspectPath(path.join(directory, 'activation.lock'));
    lock = fs.openSync(lockPath, 'wx', 0o600);
    if (retained.some(name => fs.existsSync(path.join(directory, name)))) {
      return { state: 'activation-pending', reasonCode: 'REQUEST_HANDOFF_REQUIRED',
        nextStep: 'Retained state changed during preparation; preserve it and reconcile.' };
    }
    const prepared = { ...request, action: 'activate', sessionProfile: request.sessionProfile,
      leadToken: randomBytes(32).toString('hex'), claimToken: randomBytes(32).toString('hex'),
      serviceControlToken: randomBytes(32).toString('hex') };
    fs.writeFileSync(requestPath, JSON.stringify(prepared), { flag: 'wx', mode: 0o600 });
    return { state: 'prepared', ...selected, requestPath,
      nextStep: 'Invoke activate-board.ps1 -ProjectRoot <project> -RequestPath <requestPath>; retain this private file and never paste its contents into chat.' };
  } catch (error) {
    return { state: 'activation-pending', reasonCode: error.code ?? 'REQUEST_PREPARATION_FAILED',
      nextStep: 'Correct the metadata or private artifact scope; preserve existing state.' };
  } finally {
    if (lock !== undefined) { fs.closeSync(lock); fs.unlinkSync(lockPath); }
  }
}
