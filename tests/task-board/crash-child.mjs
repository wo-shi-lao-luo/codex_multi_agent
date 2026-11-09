// This owned child pauses inside a real SQLite transaction or just after its commit.
// The parent kills only this process after the barrier, then reopens through production storage.
import { openBoard } from '../../packages/task-board/src/storage/index.mjs';
import { createHash } from 'node:crypto';
import { writeSync } from 'node:fs';
import { atomicMutation } from './atomic-fixture.mjs';
const [projectRoot, boardPath, stage, generation] = process.argv.slice(2);
const request = { operationId: 'crash-operation', actorId: 'lead', generation };
const requestHash = createHash('sha256').update(JSON.stringify(request)).digest('hex');
const pause = () => {
  writeSync(1, 'COMMIT_BARRIER\n');
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0);
};
const board = openBoard({ projectRoot, boardPath, testHooks: { [stage]: pause } });
board.transactOperation({ request, requestHash, operation: 'fixture-change' }, atomicMutation);
board.close();
