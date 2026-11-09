// Maintenance CLI contract: explicit old-schema routing, raw caller credentials and replay semantics.
// Each scenario owns historical input, backups and subprocesses; no user homes or background service.
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdir, mkdtemp, rm } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { invoke, secret, assertRedacted } from './helpers.mjs';
import { createLegacyBoard, legacyToken } from './fixtures/legacy-board.mjs';

// Construct historical input directly; the CLI must explicitly choose its maintenance adapter.
async function fixture(t) {
  const parent = resolve('_work/task-board/test-fixtures');
  await mkdir(parent, { recursive: true });
  const project = await mkdtemp(join(parent, 'maintenance-cli-'));
  t.after(() => rm(project, { recursive: true, force: true }));
  const board = join(project, 'board');
  const legacy = await createLegacyBoard(project, board);
  const call = (operation, input = {}) => invoke(project, board, operation, input);
  return { project, board, legacy, call };
}

// Normal open stays strict3 while explicit status/diagnose can safely inspect historical2.
test('P1B.cli.oldSchemaReadRoutes', async t => {
  const f = await fixture(t);
  const ordinary = await f.call('inspect');
  assert.equal(ordinary.code, 2);
  assert.equal(ordinary.reply.error.code, 'UNSUPPORTED_SCHEMA');
  const status = await f.call('maintenance-status');
  assert.equal(status.code, 0, JSON.stringify(status.reply));
  assert.equal(status.reply.schemaVersion, 1);
  assert.equal(status.reply.result.schemaVersion, 2);
  assert.equal(status.reply.result.maintenance, null);
  const diagnosed = await f.call('diagnose', { level: 'full' });
  assert.equal(diagnosed.code, 0, JSON.stringify(diagnosed.reply));
  assert.equal(diagnosed.reply.schemaVersion, 1);
  assert.equal(diagnosed.reply.result.schemaVersion, 2);
  assert.equal(diagnosed.reply.result.integrity, 'ok');
  assert.equal(diagnosed.reply.result.foreignKeys, 'ok');
  assertRedacted(status, [legacyToken]);
  assertRedacted(diagnosed, [legacyToken]);
});

// Enter/migrate/exit adapters retain caller tokens, full-payload receipt identity and session revocation.
test('P1B.cli.rawTokenMigrationLifecycle', async t => {
  const f = await fixture(t);
  const maintenanceToken = secret();
  const quiescence = { writersStopped: true, servicesStopped: true,
    evidenceRefs: ['fixture/stop#all-writers-and-services'] };
  const common = { actorId: 'lead', leadToken: legacyToken,
    generation: f.legacy.board.generation, expectedBoardRevision: f.legacy.board.boardRevision,
    maintenanceId: 'caller-owned-maintenance-session', maintenanceToken, quiescence };
  const entered = await f.call('enter-maintenance', { ...common, operationId: 'cli-enter' });
  assert.equal(entered.code, 0, JSON.stringify(entered.reply));
  assert.equal(entered.reply.result.maintenance.id, common.maintenanceId);
  const input = { ...common, operationId: 'cli-migrate',
    generation: entered.reply.generation, expectedBoardRevision: entered.reply.boardRevision,
    fromVersion: 2, toVersion: 3, backupPath: join(f.project, 'before-migration.sqlite') };
  const migrated = await f.call('migrate', input);
  assert.equal(migrated.code, 0, JSON.stringify(migrated.reply));
  assert.notEqual(migrated.reply.generation, common.generation);
  assert.equal(migrated.reply.result.fromVersion, 2);
  assert.equal(migrated.reply.result.toVersion, 3);
  const replay = await f.call('migrate', input);
  assert.equal(replay.code, 0);
  assert.deepEqual(replay.reply, migrated.reply);
  const mismatch = await f.call('migrate', { ...input,
    backupPath: join(f.project, 'different-backup.sqlite') });
  assert.equal(mismatch.code, 2);
  assert.equal(mismatch.reply.error.code, 'IDEMPOTENCY_MISMATCH');
  assertRedacted(entered, [legacyToken, maintenanceToken]);
  assertRedacted(migrated, [legacyToken, maintenanceToken]);
  assertRedacted(replay, [legacyToken, maintenanceToken]);
  const exited = await f.call('exit-maintenance', { ...common, operationId: 'cli-exit',
    generation: migrated.reply.generation, expectedBoardRevision: migrated.reply.boardRevision });
  assert.equal(exited.code, 0, JSON.stringify(exited.reply));
  assert.equal(exited.reply.result.maintenance, null);
  const stale = await f.call('migrate', input);
  assert.equal(stale.code, 2);
  assert.equal(stale.reply.error.code, 'UNAUTHORIZED');
});
