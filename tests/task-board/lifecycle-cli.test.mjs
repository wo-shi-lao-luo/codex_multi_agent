/** Final CLI facade wiring tests on real SQLite; deep SQL/fault semantics stay storage-owned. */
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { join, dirname } from 'node:path';
import { fixture, invoke, cli, secret, assertRedacted } from './helpers.mjs';

/** Pass exact flat raw-credential wire fields, without helper-added preview mutation fields. */
async function call(f, operation, fields = {}) {
  const response = await invoke(f.project, f.board, operation,
    { actorId: 'lead', leadToken: f.leadToken, generation: f.generation, ...fields });
  assert.equal(response.code, 0, `${operation}: ${JSON.stringify(response.reply)}`);
  assert.equal(response.reply.ok, true);
  assertRedacted(response.reply, [f.leadToken]);
  return response.reply;
}

// Scenario: real canceled terminal work is classified, archived, replayed and unarchived through CLI.
// Expected: preview has no receipt, exact mutation replays, public detail retains history; default
// status/ready hide archived work and reopen/unarchive preserve the normal authorization gates.
test('LifecycleCLI.archive', async t => {
  const f = await fixture(t);
  await f.task('archivable');
  const task = (await f.ok('show', { taskId: 'archivable' })).result.task;
  await f.ok('cancel', { taskId: task.id, taskRevision: task.taskRevision,
    reason: 'Owned terminal fixture' });
  const before = await f.ok('inspect');
  const classification = { taskId: task.id, decision: 'logical-archive-safe',
    evidenceRefs: ['fixture/classify#terminal'], observedBoardRevision: before.boardRevision };
  const fields = { taskIds: [task.id], action: 'archive', classificationRefs: [classification] };
  const preview = await call(f, 'preview-archive', fields);
  assert.equal(preview.result.receiptCommitted, false);
  const mutation = { ...fields, operationId: 'archive-real-cli',
    expectedBoardRevision: before.boardRevision, previewHash: preview.result.previewHash,
    approvalRef: 'fixture/approval#archive' };
  const archived = await call(f, 'archive', mutation);
  assert.deepEqual(await call(f, 'archive', mutation), archived);
  const shown = await call(f, 'show', { taskId: task.id });
  assert.equal(shown.result.task.archived, true);
  assert.ok(!(await call(f, 'status')).result.tasks.some(item => item.id === task.id));
  assert.ok(!(await call(f, 'ready')).result.tasks.some(item => item.id === task.id));
  assert.ok((await call(f, 'inspect')).result.tasks.some(item => item.id === task.id));
  const next = await f.ok('inspect');
  const unarchiveFields = { taskIds: [task.id], action: 'unarchive',
    classificationRefs: [{ taskId: task.id, decision: 'logical-archive-safe',
      evidenceRefs: ['fixture/classify#unarchive'], observedBoardRevision: next.boardRevision }] };
  const unarchive = await call(f, 'preview-archive', unarchiveFields);
  await call(f, 'archive', { ...unarchiveFields, operationId: 'unarchive-real-cli',
    expectedBoardRevision: next.boardRevision, previewHash: unarchive.result.previewHash,
    approvalRef: 'fixture/approval#unarchive' });
  assert.equal((await call(f, 'show', { taskId: task.id })).result.task.archived, false);
});

// Scenario: CLI previews/applies an approved transport prefix then performs PASSIVE checkpoint.
// Expected: exact public receipt/floor change, while physical checkpoint reports no business receipt.
// Vacuum/session-resolution permutations remain preplanned until their prerequisite wire is reached.
test('LifecycleCLI.pruneMaintenance', async t => {
  const f = await fixture(t);
  await f.task('history');
  const before = await f.ok('inspect');
  const fields = { target: 'change-events', throughEventSeq: before.eventSeq,
    retentionApprovalRef: 'fixture/retention#prefix' };
  const preview = await call(f, 'preview-prune', fields);
  assert.equal(preview.result.receiptCommitted, false);
  const applied = await call(f, 'apply-prune', { ...fields, operationId: 'prune-real-cli',
    expectedBoardRevision: before.boardRevision, previewHash: preview.result.previewHash,
    approvalRef: 'fixture/approval#prune' });
  assert.ok(applied.result.deletedEventSeqs.length > 0);
  assert.equal((await call(f, 'inspect')).result.replayFloor, before.eventSeq);
  const current = await f.ok('inspect');
  const checkpoint = await call(f, 'checkpoint', { operationId: 'checkpoint-real-cli',
    expectedBoardRevision: current.boardRevision, mode: 'PASSIVE' });
  assert.equal(checkpoint.result.receiptCommitted, false);
});

// Scenario: a real SQLite backup is compressed/decompressed through normalized CLI paths/digests.
// Expected: actual gzip artifact, byte-identical SQLite recovery output and retained original;
// Decoded schema3 uses normal restore3; R1 uses a separate true historical schema2 fixture.`n// Both actual restore routes remain downstream checkpoints, not observed in this prerequisite Red.
test('LifecycleCLI.gzipRestore', async t => {
  const f = await fixture(t);
  const sourcePath = join(f.board, 'recovery.sqlite');
  await f.ok('backup', { destination: sourcePath });
  const bytes = await readFile(sourcePath);
  const expectedSha256 = createHash('sha256').update(bytes).digest('hex');
  const before = await f.ok('inspect');
  const compressed = await call(f, 'compress-backup', { operationId: 'compress-real-cli',
    expectedBoardRevision: before.boardRevision, sourcePath,
    destination: join(f.board, 'recovery.sqlite.gz'), expectedSha256,
    maxUncompressedBytes: 8 * 1024 * 1024 });
  assert.equal(compressed.result.receiptCommitted, false);
  assert.deepEqual([...(await readFile(compressed.result.path)).subarray(0, 2)], [31, 139]);
  const decoded = await call(f, 'decompress-backup', { operationId: 'decompress-real-cli',
    expectedBoardRevision: before.boardRevision, sourcePath: compressed.result.path,
    destination: join(f.board, 'decoded.sqlite'), expectedSha256: compressed.result.sha256,
    expectedDatabaseSha256: expectedSha256, maxUncompressedBytes: 8 * 1024 * 1024 });
  assert.deepEqual(await readFile(decoded.result.path), bytes);
  assert.deepEqual(await readFile(sourcePath), bytes);
  const target = join(f.project, '_work', 'decoded3-restored');
  const restored = await invoke(f.project, target, 'restore', {
    actorId: 'lead', leadToken: f.leadToken, backupPath: decoded.result.path,
    writesStopped: true, processStopped: true, maintenanceApproved: true });
  assert.equal(restored.code, 0, JSON.stringify(restored.reply));
  assert.notEqual(restored.reply.generation, f.generation);
});

/** Start only the owned persistent CLI child; parse its first envelope, never wait for serve exit. */
async function startService(f, token) {
  const child = spawn(process.execPath, [cli, 'serve', '--project-root', f.project,
    '--board-path', f.board, '--stdin'], { stdio: ['pipe', 'pipe', 'pipe'],
    env: { ...process.env, GIT_CEILING_DIRECTORIES: dirname(f.project) } });
  f.children.push(child);
  child.stdin.end(JSON.stringify({ actorId: 'lead', leadToken: f.leadToken,
    generation: f.generation, port: 0, serviceControlToken: token }));
  return new Promise((resolve, reject) => {
    let output = '';
    let errors = '';
    const timer = setTimeout(() => reject(new Error('Owned CLI serve startup timeout')), 5000);
    child.stderr.on('data', data => { errors += data; });
    child.stdout.on('data', data => {
      output += data;
      if (!output.includes('\n')) return;
      clearTimeout(timer);
      try { resolve(JSON.parse(output.split('\n')[0])); } catch (error) { reject(error); }
    });
    child.once('error', reject);
    child.once('exit', code => { clearTimeout(timer);
      if (!output.includes('\n')) reject(new Error(`Owned serve exited ${code}: ${errors}`)); });
  });
}

// Scenario: actual CLI serve accepts caller control credential; status/stop need no usable DB path.
// Expected: flat identity controls before DB open, token never returned, stop is acceptance then real
// listener closure; finally kills only its own child if a missing-route prerequisite blocks stop.
test('LifecycleCLI.serviceControl', async t => {
  const f = await fixture(t);
  const token = secret();
  const started = await startService(f, token);
  assert.equal(started.ok, true, JSON.stringify(started));
  assert.ok(!JSON.stringify(started).includes(token));
  const { serviceId, boardId, generation, port, url } = started.result;
  const identity = { serviceId, boardId, generation, port, url, serviceControlToken: token };
  const missingBoard = join(f.project, '_work', 'not-a-database');
  const status = await invoke(f.project, missingBoard, 'service-status', identity);
  assert.equal(status.code, 0, JSON.stringify(status.reply));
  assert.equal(status.reply.result.status, 'running');
  const { spawnSync } = await import('node:child_process');
  const noSQLite = spawnSync(process.execPath, ['--no-experimental-sqlite', cli,
    'service-status', '--project-root', f.project, '--board-path', missingBoard, '--stdin'], {
    encoding: 'utf8', input: JSON.stringify(identity),
    env: { ...process.env, GIT_CEILING_DIRECTORIES: dirname(f.project) } });
  assert.equal(noSQLite.status, 0, noSQLite.stderr + noSQLite.stdout);
  assert.equal(JSON.parse(noSQLite.stdout).result.status, 'running');
  const stopped = await invoke(f.project, missingBoard, 'service-stop', identity);
  assert.equal(stopped.code, 0, JSON.stringify(stopped.reply));
  assert.equal(stopped.reply.result.status, 'stopping');
  await assert.rejects(fetch(new URL('/_service/status', url), { signal: AbortSignal.timeout(2000) }));
});


// Scenario: adapter receives bad authorization, extended raw/hash fields, or changed replay payload.
// Expected: fail before mutation/output; stable semantic request replays but changed approval cannot.
test('LifecycleCLI.authAndSemanticGuards', async t => {
  const f = await fixture(t);
  const base = { actorId: 'lead', leadToken: f.leadToken, generation: f.generation };
  const before = await f.ok('inspect');
  for (const patch of [
    { requestHash: '00'.repeat(32) }, { generation: undefined },
    { classificationRefs: [{ taskId: 'x', unexpected: true }] },
  ]) {
    const rejected = await invoke(f.project, f.board, 'preview-archive', {
      ...base, taskIds: ['missing'], action: 'archive', ...patch });
    assert.equal(rejected.code, 2);
    assert.equal(rejected.reply.error.code, 'INVALID_INPUT');
  }
  const denied = await invoke(f.project, f.board, 'preview-prune', { ...base,
    leadToken: secret(), target: 'change-events', throughEventSeq: before.eventSeq,
    retentionApprovalRef: 'fixture/retention#bad-auth' });
  assert.equal(denied.code, 2);
  assert.equal(denied.reply.error.code, 'UNAUTHORIZED');
  assert.deepEqual((await f.ok('inspect')).result, before.result);
  const fields = { target: 'change-events', throughEventSeq: before.eventSeq,
    retentionApprovalRef: 'fixture/retention#semantic' };
  const preview = await call(f, 'preview-prune', fields);
  const request = { ...base, ...fields, operationId: 'semantic-prune',
    expectedBoardRevision: before.boardRevision, previewHash: preview.result.previewHash,
    approvalRef: 'fixture/approval#original' };
  const applied = await invoke(f.project, f.board, 'apply-prune', request);
  assert.equal(applied.code, 0);
  assert.deepEqual((await invoke(f.project, f.board, 'apply-prune', request)).reply, applied.reply);
  const changed = await invoke(f.project, f.board, 'apply-prune', {
    ...request, approvalRef: 'fixture/approval#changed' });
  assert.equal(changed.code, 2);
  assert.equal(changed.reply.error.code, 'IDEMPOTENCY_MISMATCH');
});

// Scenario: closed accepted work is archived, inspected through default HTTP and reopened.
// Expected: browser-default snapshot omits it, explicit inspect/show retain it, reopen unarchives
// while invalidating results and preserving ordinary approval/grant requirements (no automatic owner).
test('LifecycleCLI.closedArchiveViewsAndReopen', async t => {
  const f = await fixture(t);
  await f.worker('w');
  await f.task('closed');
  await f.grant('w', 'closed');
  const owner = { actorId: 'w', workerToken: f.workers.w, claimToken: secret() };
  const claimed = await f.ok('claim', { ...owner, taskId: 'closed', taskRevision: 2 });
  owner.assignmentId = claimed.result.assignment.id;
  let current = (await f.ok('show', { taskId: 'closed' })).result.task;
  await f.ok('submit', { ...owner, taskId: 'closed', taskRevision: current.taskRevision,
    writesStopped: true, processStopped: true, inputRevision: 'fixture/source#closed',
    evidenceRefs: ['fixture/tests#closed'] });
  current = (await f.ok('show', { taskId: 'closed' })).result.task;
  await f.ok('accept', { taskId: 'closed', taskRevision: current.taskRevision,
    gatesSatisfied: true, evidenceRefs: ['fixture/review#closed'] });
  await f.ok('release', { taskId: 'closed', writesStopped: true, processStopped: true,
    taskRevision: (await f.ok('show', { taskId: 'closed' })).result.task.taskRevision });
  const before = await f.ok('inspect');
  const fields = { taskIds: ['closed'], action: 'archive', classificationRefs: [{
    taskId: 'closed', decision: 'logical-archive-safe', observedBoardRevision: before.boardRevision,
    evidenceRefs: ['fixture/classify#closed'] }] };
  const plan = await call(f, 'preview-archive', fields);
  await call(f, 'archive', { ...fields, operationId: 'closed-archive',
    expectedBoardRevision: before.boardRevision, previewHash: plan.result.previewHash,
    approvalRef: 'fixture/approval#closed' });
  const started = await startService(f, secret());
  assert.equal(started.ok, true);
  const boot = await fetch(started.result.ticketUrl, { redirect: 'manual' });
  const cookie = boot.headers.get('set-cookie').split(';')[0];
  await boot.text();
  const response = await fetch(new URL('/api/snapshot', started.result.url), {
    headers: { Cookie: cookie }, signal: AbortSignal.timeout(2000) });
  assert.equal(response.status, 200);
  assert.ok(!(await response.json()).tasks.some(task => task.id === 'closed'));
  assert.equal((await call(f, 'show', { taskId: 'closed' })).result.task.archived, true);
  current = (await call(f, 'show', { taskId: 'closed' })).result.task;
  await f.ok('reopen', { taskId: 'closed', taskRevision: current.taskRevision,
    reason: 'Fixture approved rework', evidenceRefs: ['fixture/reopen#closed'] });
  const reopened = (await call(f, 'show', { taskId: 'closed' })).result;
  assert.equal(reopened.task.archived, false);
  assert.equal(reopened.task.resultValid, false);
  assert.equal(reopened.assignment, null);
  await f.worker('ungranted');
  const deniedClaim = await f.raw('claim', { actorId: 'ungranted',
    workerToken: f.workers.ungranted, claimToken: secret(), taskId: 'closed',
    taskRevision: reopened.task.taskRevision });
  assert.equal(deniedClaim.code, 2);
  assert.equal(deniedClaim.reply.error.code, 'UNAUTHORIZED');
  const authorizedClaim = await f.raw('claim', { ...owner, claimToken: secret(), taskId: 'closed',
    taskRevision: reopened.task.taskRevision });
  assert.equal(authorizedClaim.code, 0, JSON.stringify(authorizedClaim.reply));
});

// Scenario: decoded schema3 restores normally; separately a true closed schema2 source uses R1.
// Expected: actual new target/generation, original bytes retained, obsolete maintenance session denied;
// ordinary restore still requires maintenance declaration and R1 never accepts schema3 as schema2.
test('LifecycleCLI.actualRecoveryRoutes', async t => {
  const { copyFile } = await import('node:fs/promises');
  const { createLegacyBoard, legacyToken } = await import('./fixtures/legacy-board.mjs');
  const f = await fixture(t);
  const legacyPath = join(f.project, '_work', 'historical2');
  const legacy = await createLegacyBoard(f.project, legacyPath);
  const base = { actorId: 'lead', leadToken: legacyToken, generation: legacy.board.generation };
  const session = { maintenanceId: 'legacy-session', maintenanceToken: secret(),
    quiescence: { writersStopped: true, servicesStopped: true,
      evidenceRefs: ['fixture/stop#historical2'] } };
  const entered = await invoke(f.project, legacyPath, 'enter-maintenance', { ...base, ...session,
    operationId: 'legacy-enter', expectedBoardRevision: legacy.board.boardRevision });
  assert.equal(entered.code, 0, JSON.stringify(entered.reply));
  const backupPath = join(f.board, 'schema2.sqlite');
  const migrated = await invoke(f.project, legacyPath, 'migrate', { ...base, ...session,
    operationId: 'legacy-migrate', expectedBoardRevision: entered.reply.boardRevision,
    fromVersion: 2, toVersion: 3, backupPath });
  assert.equal(migrated.code, 0, JSON.stringify(migrated.reply));
  const exited = await invoke(f.project, legacyPath, 'exit-maintenance', { ...base, ...session,
    generation: migrated.reply.generation, operationId: 'legacy-exit',
    expectedBoardRevision: migrated.reply.boardRevision });
  assert.equal(exited.code, 0, JSON.stringify(exited.reply));
  const bytes = await readFile(backupPath);
  const target = join(f.project, '_work', 'r1-target');
  const recovered = await invoke(f.project, target, 'restore-migration-backup-2-to-3', {
    ...base, operationId: 'actual-r1', expectedBoardRevision: entered.reply.boardRevision,
    backupPath, expectedSha256: createHash('sha256').update(bytes).digest('hex') });
  assert.equal(recovered.code, 0, JSON.stringify(recovered.reply));
  assert.notEqual(recovered.reply.generation, base.generation);
  assert.equal(recovered.reply.result.sourceRetained, true);
  const oldSession = await invoke(f.project, target, 'exit-maintenance', { ...base, ...session,
    generation: recovered.reply.generation, operationId: 'obsolete-session',
    expectedBoardRevision: recovered.reply.boardRevision });
  assert.equal(oldSession.code, 2);
  assert.equal(oldSession.reply.error.code, 'UNAUTHORIZED');
  assert.deepEqual(await readFile(backupPath), bytes);
  const normal = await f.raw('restore', { backupPath });
  assert.equal(normal.code, 2);
  assert.equal(normal.reply.error.code, 'MAINTENANCE_REQUIRED');
  // A normal schema3 backup is restored by its native route, never relabeled as schema2.
  const normalBackup = join(f.board, 'schema3.sqlite');
  await f.ok('backup', { destination: normalBackup });
  const normalTarget = join(f.project, '_work', 'restored3');
  const restored = await invoke(f.project, normalTarget, 'restore', {
    actorId: 'lead', leadToken: f.leadToken, backupPath: normalBackup,
    writesStopped: true, processStopped: true, maintenanceApproved: true });
  assert.equal(restored.code, 0, JSON.stringify(restored.reply));
  assert.notEqual(restored.reply.generation, f.generation);
  const wrong = await invoke(f.project, join(f.project, '_work', 'wrong-r1'),
    'restore-migration-backup-2-to-3', { actorId: 'lead', leadToken: f.leadToken,
      generation: f.generation, operationId: 'wrong-schema', expectedBoardRevision: 0,
      backupPath: normalBackup, expectedSha256: createHash('sha256')
        .update(await readFile(normalBackup)).digest('hex') });
  assert.equal(wrong.code, 2);
  assert.equal(wrong.reply.error.code, 'UNSUPPORTED_SCHEMA');
});

// Scenario: active CLI maintenance session previews and runs real VACUUM, replays then resolves no pending.
// Expected: completed durable receipt/replay, physical operation not rerun, no-pending resolution denied.
test('LifecycleCLI.vacuumAndResolution', async t => {
  const f = await fixture(t);
  const before = await f.ok('inspect');
  const session = { maintenanceId: 'vacuum-cli', maintenanceToken: secret(),
    quiescence: { writersStopped: true, servicesStopped: true,
      evidenceRefs: ['fixture/stop#vacuum-cli'] } };
  const entered = await call(f, 'enter-maintenance', { ...session, operationId: 'vacuum-enter',
    expectedBoardRevision: before.boardRevision });
  const backupPath = join(f.board, 'pre-vacuum.sqlite');
  const backup = await f.ok('backup', { destination: backupPath });
  const input = { ...session, policyVersion: 1, backupPath,
    expectedBackupSha256: backup.result.sha256, windowApprovalRef: 'fixture/window#vacuum',
    expectedBoardRevision: entered.boardRevision };
  const plan = await call(f, 'preview-vacuum', { ...input, operationId: 'vacuum-preview' });
  assert.equal(plan.result.receiptCommitted, false);
  const payload = { ...input, operationId: 'vacuum-real-cli', previewHash: plan.result.previewHash };
  const completed = await call(f, 'vacuum', payload);
  assert.equal(completed.result.outcome, 'completed');
  assert.equal(completed.result.receiptCommitted, true);
  assert.deepEqual(await call(f, 'vacuum', payload), completed);
  const resolution = await f.raw('resolve-maintenance-operation', { ...session,
    quiescence: undefined, operationId: 'resolve-no-pending',
    expectedBoardRevision: completed.boardRevision, pendingOperationId: payload.operationId,
    decision: 'abandon-unknown', processObservation: { pid: 1, instanceId: 'owned-observation',
      stopped: true, evidenceRefs: ['fixture/process#none'] },
    integrityEvidenceRefs: ['fixture/integrity#none'] });
  assert.notEqual(resolution.code, 0);
  assert.equal(resolution.reply.error.code, 'RECOVERY_REQUIRED');
  assert.equal(resolution.code, 3);
});

// Scenario: data-only help/catalog and retained service controls run with SQLite disabled.
// Expected: help imports/answers without SQLite; control reaches transport rather than storage import.
test('LifecycleCLI.noSQLiteCatalogAndControls', async () => {
  const { spawnSync } = await import('node:child_process');
  const help = spawnSync(process.execPath, ['--no-experimental-sqlite', cli, 'help'],
    { encoding: 'utf8' });
  assert.equal(help.status, 0, help.stderr + help.stdout);
  assert.equal(JSON.parse(help.stdout).ok, true);
  const catalog = spawnSync(process.execPath, ['--no-experimental-sqlite', '--input-type=module',
    '-e', "await import('./packages/task-board/src/cli/data-lifecycle.mjs');"], { encoding: 'utf8' });
  assert.equal(catalog.status, 0, catalog.stderr);
});


// Scenario: physical conversion has valid authorized source/hash but omits required destination.
// Expected: INVALID_INPUT/exit2 before business/policy/output changes, never a path.resolve IO error.
for (const operation of ['compress-backup', 'decompress-backup']) {
  test(`LifecycleCLI.missingDestination.${operation}`, async t => {
    const { readdir } = await import('node:fs/promises');
    const f = await fixture(t);
    const backup = join(f.board, 'missing-destination-source.sqlite');
    await f.ok('backup', { destination: backup });
    const sourceBytes = await readFile(backup);
    const databaseHash = createHash('sha256').update(sourceBytes).digest('hex');
    let sourcePath = backup;
    let expectedSha256 = databaseHash;
    if (operation === 'decompress-backup') {
      const metadata = await f.ok('inspect');
      const zipped = await call(f, 'compress-backup', { operationId: 'prepare-valid-gzip',
        expectedBoardRevision: metadata.boardRevision, sourcePath: backup,
        destination: join(f.board, 'valid-source.gz'), expectedSha256: databaseHash,
        maxUncompressedBytes: 8 * 1024 * 1024 });
      sourcePath = zipped.result.path;
      expectedSha256 = zipped.result.sha256;
    }
    const before = await f.ok('inspect');
    const files = (await readdir(f.board)).sort();
    const policy = await readFile(join(f.project, '.gitignore')).catch(() => null);
    const response = await invoke(f.project, f.board, operation, {
      actorId: 'lead', leadToken: f.leadToken, generation: f.generation,
      operationId: 'missing-destination', expectedBoardRevision: before.boardRevision,
      sourcePath, expectedSha256, maxUncompressedBytes: 8 * 1024 * 1024,
      ...(operation === 'decompress-backup' ? { expectedDatabaseSha256: databaseHash } : {}),
    });
    assert.deepEqual((await f.ok('inspect')).result, before.result);
    assert.deepEqual((await readdir(f.board)).sort(), files);
    assert.deepEqual(await readFile(join(f.project, '.gitignore')).catch(() => null), policy);
    assert.deepEqual(await readFile(backup), sourceBytes);
    assert.equal(response.reply.error?.code, 'INVALID_INPUT', JSON.stringify(response.reply));
    assert.equal(response.code, 2);
  });
}
