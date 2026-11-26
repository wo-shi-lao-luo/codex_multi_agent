#!/usr/bin/env node
/** JSON-only task-board entrypoint. This bootstrap validates transport and runtime before dispatch. */
import { open } from 'node:fs/promises';
import { BoardError } from '../domain/errors.mjs';
import { serviceStatus, stopService, serviceOpen } from '../server/control.mjs';
import { help } from './help.mjs';
import { sessionLocation } from '../domain/session.mjs';
import { probeRuntime } from '../runtime/preflight.mjs';
import { executeBoardCommand } from './board-command.mjs';
import { runDashboard } from './dashboard-command.mjs';

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
try {
  if (operation === 'help') {
    process.stdout.write(`${JSON.stringify(help(process.argv.slice(3)))}\n`);
  } else if (operation === 'dashboard') {
    await runDashboard(process.argv.slice(3));
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
        'serviceControlToken', 'timeoutMs', 'sessionKey', 'serviceMode', 'hubId', 'routeBase'];
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
      reply = await executeBoardCommand(location, operation, input, { cwd: process.cwd() });
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
}

/** Committed failure receipts retain their envelope but still signal failure to CLI callers. */
function failureExitCode(code) {
  return ['UNSUPPORTED_RUNTIME', 'IO_ERROR', 'BUSY', 'RECOVERY_REQUIRED', 'SERVICE_UNAVAILABLE']
    .includes(code) ? 3 : code === 'NO_READY_TASK' ? 4 : 2;
}
