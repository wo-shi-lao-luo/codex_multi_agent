// Build a fixed historical schema2 database directly from frozen DDL and representative old payloads.
// This is migration input only: never call current initialize3 then relabel it as historical data.
import { DatabaseSync } from 'node:sqlite';
import { mkdir } from 'node:fs/promises';
import { realpathSync } from 'node:fs';
import { join } from 'node:path';
import { createHash, randomUUID } from 'node:crypto';
import { createSchema } from './schema-v2.mjs';

export const legacyToken = '43'.repeat(32);
export const legacyHash = createHash('sha256').update(legacyToken).digest('hex');

export async function createLegacyBoard(projectRoot, boardPath, { active = false } = {}) {
  await mkdir(boardPath, { recursive: true });
  const db = new DatabaseSync(join(boardPath, 'board.sqlite'));
  const timestamp = '2026-11-09T00:00:00.000Z';
  const board = { schemaVersion: 2, boardId: randomUUID(), generation: randomUUID(),
    boardRevision: 5, eventSeq: 5, replayFloor: 0, projectRoot: realpathSync(projectRoot),
    leadId: 'lead', leadTokenHash: legacyHash, createdAt: timestamp, updatedAt: timestamp };
  try {
    db.exec('PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; BEGIN IMMEDIATE');
    createSchema(db);
    db.prepare('INSERT INTO boards(id,payload) VALUES(1,?)').run(JSON.stringify(board));
    const task = { id: 'legacy-task', title: 'Historical accepted work', outcome: 'Old output',
      sourceRefs: ['fixture/work#legacy'], acceptanceRefs: ['fixture/accept#legacy'],
      eligibleRoles: ['backend'], scope: { read: [], write: ['src/legacy.mjs'] },
      taskRevision: 4, approvalRevision: 2, state: active ? 'running' : 'closed', phase: active ? 'running' : 'submitted',
      resultValid: true, cleanupPending: false, repairAttempts: 2,
      acceptanceEvidence: ['fixture/old-review#pass'] };
    db.prepare('INSERT INTO tasks(id,payload,taskRevision,state) VALUES(?,?,?,?)')
      .run(task.id, JSON.stringify(task), task.taskRevision, task.state);
    db.prepare('INSERT INTO workers(id,payload) VALUES(?,?)').run('legacy-worker',
      JSON.stringify({ id: 'legacy-worker', role: 'backend', tokenHash: legacyHash }));
    const grant = { id: JSON.stringify(['legacy-task', 'legacy-worker']),
      taskId: task.id, workerId: 'legacy-worker', approvalRevision: 2 };
    db.prepare('INSERT INTO grants(id,payload,taskId,workerId,approvalRevision) VALUES(?,?,?,?,?)')
      .run(grant.id, JSON.stringify(grant), grant.taskId, grant.workerId, grant.approvalRevision);
    const assignment = { id: 'legacy-assignment', taskId: task.id,
      workerId: 'legacy-worker', active, tokenHash: legacyHash,
      generation: board.generation, approvalRevision: 2 };
    db.prepare('INSERT INTO assignments(id,payload,taskId,workerId,active) VALUES(?,?,?,?,?)')
      .run(assignment.id, JSON.stringify(assignment), task.id, assignment.workerId, Number(active));
    const submission = { id: 'legacy-submission', taskId: task.id,
      assignmentId: assignment.id, taskRevision: 4, inputRevision: 'opaque-source-revision-v2',
      evidenceRefs: ['fixture/old-tests#pass'], freezeValid: true,
      writesStopped: true, processStopped: true };
    db.prepare('INSERT INTO submissions(id,payload,taskId,assignmentId,taskRevision) VALUES(?,?,?,?,?)')
      .run(submission.id, JSON.stringify(submission), task.id, assignment.id, 4);
    for (let sequence = 1; sequence <= 5; sequence++) {
      const event = { generation: board.generation, eventSeq: sequence,
        boardRevision: sequence, type: 'legacy-history', entityId: task.id };
      db.prepare('INSERT INTO change_events(sequence,generation,type,payload) VALUES(?,?,?,?)')
        .run(sequence, board.generation, event.type, JSON.stringify(event));
      db.prepare('INSERT INTO audit_events(operation_id,type,payload) VALUES(?,?,?)')
        .run('legacy-' + sequence, event.type, JSON.stringify(event));
    }
    db.exec('COMMIT');
    return { board, task, grant, submission };
  } finally { db.close(); }
}
