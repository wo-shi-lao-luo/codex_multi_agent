// Controlled fault actor: only this owned child pauses before/after the actual fixed VACUUM call.
import { DatabaseSync } from 'node:sqlite';
import { join } from 'node:path';
let input = '';
for await (const chunk of process.stdin) input += chunk;
const { projectRoot, boardPath, options, phase } = JSON.parse(input);
const original = DatabaseSync.prototype.exec;
let vacuumCalls = 0;
DatabaseSync.prototype.exec = function(sql, ...args) {
  const vacuum = /^\s*VACUUM\s*;?\s*$/i.test(sql);
  if (vacuum) vacuumCalls++;
  if (vacuum && phase === 'observed-busy') {
    // A real separate writer holds SQLite's lock only during this child's attempted VACUUM.
    const lock = new DatabaseSync(join(boardPath, 'board.sqlite'));
    original.call(lock, 'BEGIN IMMEDIATE');
    try { return original.call(this, sql, ...args); }
    finally { original.call(lock, 'ROLLBACK'); lock.close(); }
  }
  if (vacuum && phase === 'before') {
    process.stdout.write('VACUUM_BARRIER\n');
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0);
  }
  const result = original.call(this, sql, ...args);
  if (vacuum && phase === 'after') {
    process.stdout.write('VACUUM_BARRIER\n');
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0);
  }
  return result;
};
const { openMaintenanceBoard } = await import('../../packages/task-board/src/storage/index.mjs');
const maintenance = openMaintenanceBoard({ projectRoot, boardPath });
try {
  const result = await maintenance.vacuum(options);
  if (phase === 'observed-busy') {
    const replay = await maintenance.vacuum(options);
    process.stdout.write(JSON.stringify({ result, replay, vacuumCalls }));
  } else {
    throw new Error('Expected owned child to stop at the requested SQL boundary');
  }
} finally { maintenance.close(); }
