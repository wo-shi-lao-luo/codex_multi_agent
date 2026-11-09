#!/usr/bin/env node
/** JSON-only task-board entrypoint. This bootstrap validates transport and runtime before dispatch. */
import { open } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { BoardError } from '../domain/errors.mjs';
import {
  hash, tokenHash, mutate, query, publicSnapshot, authorizeReplay,
} from '../coordination/service.mjs';
import { serve } from '../server/server.mjs';
import { serviceStatus, stopService, serviceOpen } from '../server/control.mjs';
import { dataLifecycleOperations, executeDataLifecycle, validateDataLifecycleInput,
  dataLifecycleDestinations } from './data-lifecycle.mjs';
import { maintenanceOperations, maintenanceCommand } from './maintenance.mjs';
import { help } from './help.mjs';
import { protectArtifacts } from '../coordination/artifact-protection.mjs';
import { sessionLocation, validateSessionInitialization } from '../domain/session.mjs';
import { probeRuntime } from '../runtime/preflight.mjs';

const MAX_INPUT_BYTES = 262144;

/** Parse the bounded transport flags; JSON fields belong to the operation implementation. */
function parseArguments(args) {
  const operation = args.shift();
  if (!operation || !/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/.test(operation)) {
    throw new BoardError('INVALID_INPUT', 'A lower-kebab operation is required.');
  }
  const options = {};
  while (args.length) {
    const flag = args.shift();
    if (flag === '--stdin') {
      options.stdin = true;
      continue;
    }
    if (!['--project-root', '--board-path', '--session-key', '--input'].includes(flag)) {
      throw new BoardError('INVALID_INPUT', 'Unknown argument.');
    }
    if (!args.length || args[0].startsWith('--') || options[flag] !== undefined) {
      throw new BoardError('INVALID_INPUT', 'Missing or repeated argument.');
    }
    options[flag] = args.shift();
  }
  if (options['--session-key'] !== undefined && !/^[a-f0-9]{64}$/.test(options['--session-key'])) {
    throw new BoardError('INVALID_INPUT', 'Session key must be 64 lowercase hex characters.');
  }
  if (!['runtime-doctor', 'session-path', 'service-status', 'service-stop', 'service-open'].includes(operation)
      && (!options['--project-root'] || !options['--board-path'])) {
    throw new BoardError('INVALID_INPUT', 'Explicit project-root and board-path are required.');
  }
  if (options.stdin && options['--input']) {
    throw new BoardError('INVALID_INPUT', 'Choose input file or stdin.');
  }
  return { operation, options };
}

/** Reject unverified Node majors and SQLite builds without the required WAL reset fix. */
async function checkRuntime() {
  const result = await probeRuntime();
  if (!result.available) throw new BoardError('UNSUPPORTED_RUNTIME',
    'Task board requires Node >=26.13.0 <27 and SQLite >=3.54.0.', { reasonCode: result.reasonCode });
}

/** Read one bounded JSON object, never echoing malformed payloads into diagnostics. */
async function readInput(options) {
  let bytes;
  if (options.stdin) {
    const chunks = [];
    let size = 0;
    for await (const chunk of process.stdin) {
      size += chunk.length;
      if (size > MAX_INPUT_BYTES) throw new BoardError('INVALID_INPUT', 'Input is too large.');
      chunks.push(chunk);
    }
    bytes = Buffer.concat(chunks);
  } else if (options['--input']) {
    const file = await open(options['--input'], 'r');
    try {
      const buffer = Buffer.alloc(MAX_INPUT_BYTES + 1);
      let size = 0;
      while (size < buffer.length) {
        const read = await file.read(buffer, size, buffer.length - size, null);
        if (read.bytesRead === 0) break;
        size += read.bytesRead;
      }
      bytes = buffer.subarray(0, size);
    } finally {
      await file.close();
    }
  } else {
    bytes = Buffer.from('{}');
  }
  if (bytes.length > MAX_INPUT_BYTES) throw new BoardError('INVALID_INPUT', 'Input is too large.');
  let input;
  try {
    input = JSON.parse(bytes.toString('utf8'));
  } catch {
    throw new BoardError('INVALID_INPUT', 'Input must be valid JSON.');
  }
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    throw new BoardError('INVALID_INPUT', 'Input must be a JSON object.');
  }
  return input;
}

let operation = process.argv[2] ?? null;
let board;
try {
  if (operation === 'help') {
    process.stdout.write(`${JSON.stringify(help(process.argv.slice(3)))}\n`);
  } else {
    const parsed = parseArguments(process.argv.slice(2));
    operation = parsed.operation;
    const input = await readInput(parsed.options);
    let reply;
    if (operation === 'runtime-doctor') {
      if (Object.keys(input).length) throw new BoardError('INVALID_INPUT', 'Runtime doctor accepts an empty object.');
      reply = { schemaVersion: 1, operation, ok: true, result: await probeRuntime() };
    } else if (operation === 'session-path') {
      if (Object.keys(input).some(key => !['hostId', 'mainSessionId', 'projectId'].includes(key))) {
        throw new BoardError('INVALID_INPUT', 'Session path accepts only stable context identifiers.');
      }
      reply = { schemaVersion: 1, operation, ok: true, result: sessionLocation(input) };
    } else if (['service-status', 'service-stop', 'service-open'].includes(operation)) {
      const allowed = ['url', 'port', 'serviceId', 'boardId', 'generation',
        'serviceControlToken', 'timeoutMs', 'sessionKey'];
      if (Object.keys(input).some(key => !allowed.includes(key))) {
        throw new BoardError('INVALID_INPUT', 'Unknown service control field.');
      }
      const flagKey = parsed.options['--session-key'];
      if (flagKey !== undefined && input.sessionKey !== undefined && flagKey !== input.sessionKey) {
        throw new BoardError('INVALID_INPUT', 'Conflicting session context values.');
      }
      const identity = { ...input, ...(flagKey === undefined ? {} : { sessionKey: flagKey }) };
      const handler = { 'service-status': serviceStatus, 'service-stop': stopService,
        'service-open': serviceOpen }[operation];
      const result = await handler(identity,
        { timeoutMs: input.timeoutMs ?? 2000 });
      reply = { schemaVersion: 1, operation, ok: true, boardId: result.boardId,
        generation: result.generation, result };
    } else {
      await checkRuntime();
      const location = { projectRoot: parsed.options['--project-root'],
        boardPath: parsed.options['--board-path'], sessionKey: parsed.options['--session-key'] };
      if (operation === 'initialize') {
        // Validate identity, required expected key and canonical path before ignore policy can change.
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
            authorizeReplay: (tx, receipt) => authorizeReplay(tx, operation, input, receipt.result, { cwd: process.cwd() }) },
          tx => mutate(tx, operation, input, { cwd: process.cwd() }));
        }
      }
    }
    if (reply.ok === false) process.exitCode = failureExitCode(reply.error?.code);
    process.stdout.write(`${JSON.stringify(reply)}\n`);
  }
} catch (error) {
  const known = typeof error.code === 'string' &&
    (error instanceof BoardError || error.name === 'StorageError');
  process.stdout.write(`${JSON.stringify({
    schemaVersion: 1,
    operation,
    ok: false,
    error: {
      code: known ? error.code : 'IO_ERROR',
      message: known ? error.message : 'Task board could not complete the operation.',
      details: known ? error.details : {},
    },
  })}\n`);
  process.exitCode = failureExitCode(known ? error.code : 'IO_ERROR');
} finally {
  board?.close();
}

/** Committed failure receipts retain their envelope but still signal failure to CLI callers. */
function failureExitCode(code) {
  return ['UNSUPPORTED_RUNTIME', 'IO_ERROR', 'BUSY', 'RECOVERY_REQUIRED', 'SERVICE_UNAVAILABLE']
    .includes(code) ? 3 : code === 'NO_READY_TASK' ? 4 : 2;
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
