/** Execute Board operations after the caller verifies the runtime and parses its transport. */
import { existsSync } from 'node:fs';
import path from 'node:path';
import { BoardError } from '../domain/errors.mjs';
import {
  hash, tokenHash, mutate, query, publicSnapshot, authorizeReplay,
} from '../coordination/service.mjs';
import { serve } from '../server/server.mjs';
import { dataLifecycleOperations, executeDataLifecycle, validateDataLifecycleInput,
  dataLifecycleDestinations } from './data-lifecycle.mjs';
import { maintenanceOperations, maintenanceCommand } from './maintenance.mjs';
import { protectArtifacts } from '../coordination/artifact-protection.mjs';

import { validateSessionInitialization } from '../domain/session.mjs';

export async function executeBoardCommand(location, operation, input, { cwd }) {
  let board;
  let reply;
  try {
    if (operation === 'initialize') {
      validateSessionInitialization({ sessionProfile: input.sessionProfile,
        sessionKey: location.sessionKey, boardPath: location.boardPath });
    }
    const storage = await import('../storage/index.mjs');
    if (dataLifecycleOperations.has(operation)) validateDataLifecycleInput(operation, input);
    if (!['show', 'source-check', 'ready', 'status', 'inbox', 'workspaces', 'inspect', 'maintenance-status', 'diagnose']
      .includes(operation)) {
      // Guard every disk-writing entrypoint before storage can create directories or SQLite sidecars.
      const destinations = dataLifecycleOperations.has(operation) ?
        dataLifecycleDestinations(operation, input) : [];
      if (operation === 'initialize') {
        if (typeof input.actorId !== 'string' || !input.actorId) {
          throw new BoardError('INVALID_INPUT', 'Lead actorId is required.');
        }
        tokenHash(input.leadToken);
      }
      if (operation === 'backup' && typeof input.destination === 'string') {
        // Existing board policy is audit-only. Only an authenticated Lead may append a new
        // backup destination policy; the read-only connection cannot change SQLite journal mode.
        protectArtifacts({ ...location, allowAppend: false });
        const existing = storage.openBoard({ ...location, readOnly: true });
        try { verifyLead(existing, input); } finally { existing.close(); }
        protectArtifacts({ ...location, destinations: [input.destination] });
      }
      if (operation === 'migrate' && typeof input.backupPath === 'string') {
        destinations.push(input.backupPath);
      }
      const newBoard = operation === 'initialize' && !existsSync(path.resolve(
        location.projectRoot, location.boardPath, 'board.sqlite'));
      protectArtifacts({ ...location, destinations, allowAppend: newBoard });
    }
    if (operation === 'initialize') {
      if (typeof input.actorId !== 'string' || !input.actorId) {
        throw new BoardError('INVALID_INPUT', 'Lead actorId is required.');
      }
      board = storage.initializeBoard({ ...location, boardId: input.boardId,
        leadId: input.actorId, leadTokenHash: tokenHash(input.leadToken), sessionProfile: input.sessionProfile });
      reply = success(board, operation, { initialized: true,
        questionPolicy: board.metadata().questionPolicy });
    } else if (dataLifecycleOperations.has(operation)) {
      reply = await executeDataLifecycle(storage, location, operation, input, { verifyLead });
    } else if (maintenanceOperations.has(operation)) {
      reply = await maintenanceCommand(storage, location, operation, input);
    } else if (operation === 'restore') {
      if (input.writesStopped !== true || input.processStopped !== true ||
        input.maintenanceApproved !== true) {
        throw new BoardError('MAINTENANCE_REQUIRED', 'Restore requires approved stopped-writer maintenance.');
      }
      board = await storage.restoreBoard({ ...location, backupPath: input.backupPath,
        leadId: input.actorId, leadTokenHash: tokenHash(input.leadToken) });
      verifyLead(board, { ...input, generation: undefined });
      reply = success(board, operation, { restored: true, reconciliationRequired: true });
    } else {
      board = storage.openBoard({ ...location,
        readOnly: ['show', 'source-check', 'ready', 'status', 'inbox', 'workspaces', 'inspect'].includes(operation) });
      if (operation === 'session-sync') {
        reply = board.syncSession({ request: input, requestHash: hash(canonical({ operation, input })) });
      } else if (['show', 'source-check', 'ready', 'status', 'inbox', 'workspaces'].includes(operation)) {
        const view = board.read(tx => ({ result: query(tx, operation, input), metadata: tx.board }));
        if (operation === 'show' && input.history === true) {
          view.result.history = board.history({ taskId: input.taskId,
            limit: input.limit ?? 20, cursor: input.cursor });
          if (view.result.history.metadata.generation !== view.metadata.generation ||
            view.result.history.metadata.boardRevision !== view.metadata.boardRevision) {
            throw new BoardError('CONFLICT', 'Task history changed during the read.', { resync: true });
          }
        }
        reply = success(board, operation, view.result, view.metadata);
      } else if (operation === 'inspect') {
        verifyLead(board, input);
        const snapshot = board.snapshot();
        reply = success(board, operation, publicSnapshot(snapshot, { includeArchived: true }), snapshot.board);
      } else if (operation === 'backup') {
        verifyLead(board, input);
        reply = success(board, operation, await board.backup(input.destination));
      } else if (operation === 'serve') {
        verifyLead(board, input);
        const serviceBoard = board;
        const shutdown = () => { service.close().catch(() => { process.exitCode = 3; }); };
        const service = await serve(serviceBoard, { port: input.port ?? 0,
          serviceControlToken: input.serviceControlToken,
          onClose() {
            process.removeListener('SIGTERM', shutdown);
            process.removeListener('SIGINT', shutdown);
            serviceBoard.close();
          } });
        const { close, ...details } = service;
        reply = success(board, operation, details);
        process.once('SIGTERM', shutdown);
        process.once('SIGINT', shutdown);
        board = null;
      } else {
        if (typeof input.operationId !== 'string' || !input.operationId) {
          throw new BoardError('INVALID_INPUT', 'operationId is required for mutations.');
        }
        reply = board.transactOperation({ request: input,
          requestHash: hash(canonical({ operation, input })), operation,
          authorizeReplay: (tx, receipt) => authorizeReplay(tx, operation, input, receipt.result, { cwd }) },
        tx => mutate(tx, operation, input, { cwd }));
      }
    }
    return reply;
  } finally { board?.close(); }
}

/** Format non-mutating results with the same revision metadata as durable operation receipts. */
function success(handle, name, result, metadata = handle.metadata()) {
  return { schemaVersion: 1, operation: name, ok: true, boardId: metadata.boardId,
    generation: metadata.generation, boardRevision: metadata.boardRevision,
    eventSeq: metadata.eventSeq, result };
}

/** Service and maintenance entrypoints require the current coordinator credential and generation. */
function verifyLead(handle, input) {
  const metadata = handle.metadata();
  if (metadata.leadId !== input.actorId || metadata.leadTokenHash !== hash(input.leadToken ?? '')) {
    throw new BoardError('UNAUTHORIZED', 'Lead authority is required.');
  }
  if (input.generation !== undefined && input.generation !== metadata.generation) {
    throw new BoardError('STALE_GENERATION', 'Board generation changed.');
  }
  return metadata;
}

/** Object property order is transport trivia, so equivalent retries share a request hash. */
function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map(key =>
      `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}
