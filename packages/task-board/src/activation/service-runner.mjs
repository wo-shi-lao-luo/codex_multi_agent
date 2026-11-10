/** Owned long-lived service child; no task mutation and no credential files. */
import { openBoard } from '../storage/index.mjs';
import { serve } from '../server/server.mjs';
import { tokenHash } from '../coordination/service.mjs';

// Private IPC is disconnected after readiness. Ignored stdio prevents the detached listener
// from extending any ancestor PowerShell/caller output-pipe lifetime on Windows.
const request = await new Promise(resolve => process.once('message', resolve));
if (Buffer.byteLength(JSON.stringify(request)) > 262144) process.exit(2);
const board = openBoard(request.location);
const metadata = board.metadata();
if (metadata.leadId !== request.actorId || metadata.leadTokenHash !== tokenHash(request.leadToken)
    || metadata.generation !== request.generation) {
  board.close();
  process.exit(2);
}
const service = await serve(board, {
  serviceControlToken: request.serviceControlToken, onClose: () => board.close(),
});
const { close, ...identity } = service;
if (process.connected) process.send(identity, () => {
  if (process.connected) process.disconnect();
});
process.once('SIGTERM', () => close());
process.once('SIGINT', () => close());
