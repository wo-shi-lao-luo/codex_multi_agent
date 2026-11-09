// P1b B1-B2 only: maintenance diagnostics/gates and explicit schema2→3 migration.
// Missing export is an interface Red; deeper assertions remain unexecuted until implementation.
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdir, mkdtemp, rm, readFile, copyFile } from 'node:fs/promises';
import { DatabaseSync } from 'node:sqlite';
import { resolve, join } from 'node:path';
import { createHash } from 'node:crypto';
import { createLegacyBoard, legacyToken, legacyHash } from './fixtures/legacy-board.mjs';
import { secret, assertRedacted } from './helpers.mjs';

// Canonicalize every semantic field, including session identity and quiescence, before hashing.
function semanticHash(options) {
  const canonical = value => {
    if (Array.isArray(value)) return value.map(canonical);
    if (value && typeof value === 'object') {
      return Object.fromEntries(Object.keys(value).sort()
        .filter(key => key !== 'requestHash').map(key => [key, canonical(value[key])]));
    }
    return value;
  };
  return createHash('sha256').update(JSON.stringify(canonical(options))).digest('hex');
}

// Generate each operation's immutable full-payload hash and caller-owned session identity.
function operation(status, operationId, session, extra = {}) {
  const request = { operationId, actorId: 'lead', generation: status.generation,
    expectedBoardRevision: status.boardRevision };
  const options = { request, leadId: 'lead', leadTokenHash: legacyHash,
    maintenanceId: session.id, maintenanceTokenHash: session.hash, ...extra };
  return { ...options, requestHash: semanticHash(options) };
}

// Retain operation identity while changing one semantic field, producing a genuinely new hash.
function changed(options, patch) {
  const next = { ...options, ...patch };
  return { ...next, requestHash: semanticHash(next) };
}
// Keep historical input construction independent from current schema initialization.
async function fixture(t, options = {}) {
  const storage = await import('../../packages/task-board/src/storage/index.mjs');
  assert.equal(typeof storage.openMaintenanceBoard, 'function',
    'P1b requires the explicit maintenance storage interface');
  const parent = resolve('_work/task-board/test-fixtures');
  await mkdir(parent, { recursive: true });
  const projectRoot = await mkdtemp(join(parent, 'maintenance-'));
  t.after(() => rm(projectRoot, { recursive: true, force: true }));
  const boardPath = join(projectRoot, 'board');
  const legacy = await createLegacyBoard(projectRoot, boardPath, options);
  const token = secret();
  const session = { id: 'fixture-maintenance', token,
    hash: createHash('sha256').update(token).digest('hex') };
  return { storage, projectRoot, boardPath, legacy, session,
    open: () => storage.openMaintenanceBoard({ projectRoot, boardPath }) };
}

// B1: diagnostics report actual database schema2 and never disclose credentials or mutate data.
test('P1B.diagnoseAndStatus', async t => {
  const f = await fixture(t);
  const file = join(f.boardPath, 'board.sqlite');
  const before = await readFile(file);
  const maintenance = f.open();
  try {
    const status = maintenance.status();
    assert.equal(status.schemaVersion, 2);
    assert.equal(status.maintenance, null);
    const diagnosed = maintenance.diagnose({ level: 'full' });
    assert.equal(diagnosed.schemaVersion, 2);
    assert.equal(diagnosed.integrity, 'ok');
    assert.equal(diagnosed.foreignKeys, 'ok');
    assert.equal(diagnosed.level, 'full');
    assert.ok(Number.isFinite(diagnosed.space.freeBytes) || diagnosed.space.freeBytes === 'unknown');
    assertRedacted(status, [legacyToken, f.session.token]);
    assertRedacted(diagnosed, [legacyToken, f.session.token]);
  } finally { maintenance.close(); }
  assert.deepEqual(await readFile(file), before);
});

// B1 gate: active business assignment prevents maintenance even with caller quiescence statements.
test('P1B.activeOwnerBlocksMaintenance', async t => {
  const f = await fixture(t, { active: true });
  const maintenance = f.open();
  try {
    const before = maintenance.status();
    const options = operation(before, 'enter-active', f.session, {
      quiescence: { writersStopped: true, servicesStopped: true,
        evidenceRefs: ['fixture/stop#business-holder-still-exists'] },
    });
    await assert.rejects(async () => maintenance.enter(options),
      error => error.code === 'MAINTENANCE_REQUIRED' || error.code === 'RECOVERY_REQUIRED');
    assert.deepEqual(maintenance.status(), before);
  } finally { maintenance.close(); }
});

// B2: migration requires a live authenticated maintenance session and preserves historical unknowns.
test('P1B.explicitMigration', async t => {
  const f = await fixture(t);
  const maintenance = f.open();
  try {
    const quiescence = { writersStopped: true, servicesStopped: true,
      evidenceRefs: ['fixture/stop#writers-and-services'] };
    const entered = await maintenance.enter(operation(maintenance.status(), 'enter', f.session,
      { quiescence }));
    assert.equal(entered.ok, true);
    assert.equal(entered.result.maintenance.id, f.session.id);
    const options = operation(maintenance.status(), 'migrate-2-to-3', f.session, {
      fromVersion: 2, toVersion: 3, backupPath: join(f.projectRoot, 'before-migration.sqlite'),
      quiescence,
    });
    const migrated = await maintenance.migrate(options);
    assert.equal(migrated.ok, true);
    assert.equal(migrated.result.fromVersion, 2);
    assert.equal(migrated.result.toVersion, 3);
    assert.notEqual(migrated.generation, f.legacy.board.generation);
    assert.deepEqual(await maintenance.migrate(options), migrated);
    // Schema3 remains an explicit intermediate; ordinary schema4 runtime must reject it.
    assert.throws(() => f.storage.openBoard({ projectRoot: f.projectRoot, boardPath: f.boardPath }),
      error => error.code === 'UNSUPPORTED_SCHEMA');
    assert.equal(maintenance.status().schemaVersion, 3);
    await maintenance.migrate(operation(maintenance.status(), 'migrate-3-to-4', f.session, {
      fromVersion: 3, toVersion: 4, backupPath: join(f.projectRoot, 'before-workspaces.sqlite'),
      quiescence,
    }));
    const ordinary = f.storage.openBoard({ projectRoot: f.projectRoot, boardPath: f.boardPath });
    try {
      const snapshot = ordinary.snapshot();
      const item = snapshot.tasks.find(value => value.id === 'legacy-task');
      assert.equal(item.state, 'closed');
      assert.equal(item.repairAttempts, 2);
      assert.equal(item.inputRevision, null);
      assert.equal(item.freezeRevision, null);
      assert.equal(item.resultRevision, null);
      assert.equal(item.inputValid, false);
      assert.equal(item.resultValid, false);
      assert.equal(item.needsReconcile, true);
      const submission = snapshot.submissions.find(value => value.id === 'legacy-submission');
      assert.equal(submission.inputRevision, 'opaque-source-revision-v2');
      assert.equal(submission.boundTaskInputRevision, null);
      assert.equal(submission.freezeRevision, null);
      assert.equal(submission.freezeValid, false);
      assert.equal(snapshot.grants.find(value => value.id === f.legacy.grant.id).revoked, true);
      assert.throws(() => ordinary.transactOperation({ request: {
        operationId: 'ordinary-during-maintenance', generation: maintenance.status().generation,
        actorId: 'lead' }, requestHash: '77'.repeat(32), operation: 'forbidden' }, () => ({})),
      error => error.code === 'MAINTENANCE_REQUIRED');
    } finally { ordinary.close(); }
    assertRedacted(migrated, [legacyToken, f.session.token]);
    await maintenance.exit(operation(maintenance.status(), 'exit', f.session, { quiescence }));
    assert.equal(maintenance.status().maintenance, null);
    await assert.rejects(async () => maintenance.migrate(options));
  } finally { maintenance.close(); }
});


// B1-B2 auth/replay negative: complete-payload identity and current session authority gate receipts.
// Every denial must preserve durable status; old success is never a substitute for current auth.
test('P1B.authorizationAndReplayMismatch', async t => {
  const f = await fixture(t);
  const maintenance = f.open();
  const quiescence = { writersStopped: true, servicesStopped: true,
    evidenceRefs: ['fixture/stop#all'] };
  try {
    const initial = maintenance.status();
    const invalidLead = operation(initial, 'wrong-lead', f.session, {
      leadTokenHash: '00'.repeat(32), quiescence });
    await assert.rejects(async () => maintenance.enter(invalidLead),
      error => error.code === 'UNAUTHORIZED');
    assert.deepEqual(maintenance.status(), initial);
    await maintenance.enter(operation(initial, 'enter-authorized', f.session, { quiescence }));
    const options = operation(maintenance.status(), 'migrate-auth', f.session, {
      fromVersion: 2, toVersion: 3, backupPath: join(f.projectRoot, 'auth-migration.sqlite'),
      quiescence,
    });
    const migrated = await maintenance.migrate(options);
    const after = maintenance.status();
    const changedDestination = changed(options, {
      backupPath: join(f.projectRoot, 'different-destination.sqlite') });
    assert.notEqual(changedDestination.requestHash, options.requestHash);
    await assert.rejects(async () => maintenance.migrate(changedDestination),
      error => error.code === 'IDEMPOTENCY_MISMATCH');
    assert.deepEqual(maintenance.status(), after);
    const wrongSession = changed(options, { maintenanceTokenHash: '00'.repeat(32) });
    await assert.rejects(async () => maintenance.migrate(wrongSession),
      error => error.code === 'UNAUTHORIZED');
    assert.deepEqual(maintenance.status(), after);
    assert.deepEqual(await maintenance.migrate(options), migrated);
    await maintenance.exit(operation(after, 'exit-authorized', f.session, { quiescence }));
    const exited = maintenance.status();
    await assert.rejects(async () => maintenance.migrate(options));
    assert.deepEqual(maintenance.status(), exited);
  } finally { maintenance.close(); }
});


// Capture exact main/sidecar bytes and journal mode without changing the fixture configuration.
async function databaseState(file) {
  const digest = bytes => createHash('sha256').update(bytes).digest('hex');
  const sidecars = {};
  for (const suffix of ['-wal', '-shm', '-journal']) {
    try { sidecars[suffix] = digest(await readFile(file + suffix)); }
    catch (error) {
      if (error.code !== 'ENOENT') throw error;
      sidecars[suffix] = null;
    }
  }
  const db = new DatabaseSync(file, { readOnly: true });
  let journalMode;
  try { journalMode = db.prepare('PRAGMA journal_mode').get().journal_mode; }
  finally { db.close(); }
  return { mainSha256: digest(await readFile(file)), journalMode, sidecars };
}

// Historical non-WAL input is legitimate diagnostic data, not permission to reconfigure its storage.
function configureDeleteJournal(file) {
  const db = new DatabaseSync(file);
  try { assert.equal(db.prepare('PRAGMA journal_mode=DELETE').get().journal_mode, 'delete'); }
  finally { db.close(); }
}

// Review round1: status/full diagnostics on known schema2 DELETE-mode must be observational only.
test('P1B.review.nonWalDiagnosticsReadOnly', async t => {
  const f = await fixture(t);
  const file = join(f.boardPath, 'board.sqlite');
  configureDeleteJournal(file);
  const before = await databaseState(file);
  assert.equal(before.journalMode, 'delete');
  const maintenance = f.open();
  try {
    assert.equal(maintenance.status().schemaVersion, 2);
    assert.equal(maintenance.diagnose({ level: 'full' }).integrity, 'ok');
  } finally { maintenance.close(); }
  assert.deepEqual(await databaseState(file), before,
    'Read diagnostics must preserve main bytes, journal mode and every sidecar');
});

// Review round1: known schemas bound to another project must reject before any SQLite reconfiguration.
test('P1B.review.projectMismatchPreservesFiles', async t => {
  const observations = [];
  for (const schema of [2, 3]) {
    const f = await fixture(t);
    let sourceBoard = f.boardPath;
    if (schema === 3) {
      sourceBoard = join(f.projectRoot, 'current-board');
      const board = f.storage.initializeBoard({ projectRoot: f.projectRoot, boardPath: sourceBoard,
        leadId: 'lead', leadTokenHash: legacyHash });
      board.close();
    }
    const sourceFile = join(sourceBoard, 'board.sqlite');
    configureDeleteJournal(sourceFile);
    const otherProject = join(f.projectRoot, `different-project-${schema}`);
    const otherBoard = join(otherProject, 'board');
    await mkdir(otherBoard, { recursive: true });
    const targetFile = join(otherBoard, 'board.sqlite');
    await copyFile(sourceFile, targetFile);
    const before = await databaseState(targetFile);
    assert.throws(() => f.storage.openMaintenanceBoard({ projectRoot: otherProject,
      boardPath: otherBoard }), error => error.code === 'PROJECT_MISMATCH');
    observations.push({ schema, before, after: await databaseState(targetFile) });
  }
  for (const observation of observations) {
    assert.deepEqual(observation.after, observation.before,
      `Rejected project binding on schema${observation.schema} must preserve all files`);
  }
});
