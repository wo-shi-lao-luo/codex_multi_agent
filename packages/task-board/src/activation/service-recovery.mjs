/** Bounded self-owned loopback check before durable service launch intent. */
import net from 'node:net';
import fs from 'node:fs';
import path from 'node:path';
import { BoardError } from '../domain/errors.mjs';
import { transportDetails } from '../server/control.mjs';
import { inspectPath } from '../storage/paths.mjs';
import { normalizeSessionProfile } from '../domain/session.mjs';
import { tokenHash } from '../coordination/service.mjs';

/** A refused listener cannot authenticate its token. Require persisted authority continuity,
 * using the canonical private handoff only for legacy journals without a verifier.
 * Reads are bounded and never rewrite caller credentials; failure precedes recovery writes.
 */
export function verifyRecoveryCredential(journal, directory, request, sessionKey) {
  let expectedHash;
  if (Object.hasOwn(journal, 'serviceControlTokenHash')) {
    expectedHash = journal.serviceControlTokenHash;
    if (typeof expectedHash !== 'string' || !/^[a-f0-9]{64}$/.test(expectedHash)) {
      throw new BoardError('SERVICE_RECOVERY_VERIFIER_REQUIRED', 'Retained verifier is invalid.');
    }
  } else {
    try {
      const file = inspectPath(path.join(directory, 'request.private.json'));
      const stat = fs.lstatSync(file);
      if (!stat.isFile() || stat.nlink !== 1 || stat.size > 262144) throw new Error();
      // Bound the read itself too: a concurrent append must not defeat the stat limit.
      const descriptor = fs.openSync(file, fs.constants.O_RDONLY | (fs.constants.O_NOFOLLOW ?? 0));
      let retained;
      try {
        const opened = fs.fstatSync(descriptor);
        if (!opened.isFile() || opened.nlink !== 1 || opened.size > 262144
            || opened.dev !== stat.dev || opened.ino !== stat.ino) throw new Error();
        const bytes = Buffer.alloc(262145);
        const size = fs.readSync(descriptor, bytes, 0, bytes.length, 0);
        if (size > 262144) throw new Error();
        retained = JSON.parse(bytes.subarray(0, size).toString('utf8'));
      } finally {
        fs.closeSync(descriptor);
      }
      const profile = normalizeSessionProfile(retained.sessionProfile);
      if (retained.actorId !== request.actorId || profile.sessionKey !== sessionKey
          || typeof retained.serviceControlToken !== 'string'
          || !/^[a-fA-F0-9]{64,256}$/.test(retained.serviceControlToken)) throw new Error();
      expectedHash = tokenHash(retained.serviceControlToken);
    } catch {
      throw new BoardError('SERVICE_RECOVERY_VERIFIER_REQUIRED',
        'A valid canonical private handoff is required for legacy recovery.');
    }
  }
  if (tokenHash(request.serviceControlToken) !== expectedHash) {
    throw new BoardError('SERVICE_CONTROL_REJECTED', 'Retained service credential does not match.');
  }
  return expectedHash;
}

/** This checks current transport permission, not child survival across host job teardown. */
export function probeServiceTransport() {
  return new Promise((resolve, reject) => {
    const server = net.createServer(socket => socket.destroy());
    let client;
    let settled = false;
    const finish = error => {
      if (settled) return;
      settled = true;
      clearTimeout(deadline);
      client?.destroy();
      server.close(() => {});
      if (error) reject(new BoardError('SERVICE_UNAVAILABLE',
        'Loopback transport unavailable; service was not launched.', transportDetails(error)));
      else resolve();
    };
    const deadline = setTimeout(() => finish({ code: 'ETIMEDOUT' }), 2000);
    server.on('error', finish);
    server.listen(0, '127.0.0.1', () => {
      client = net.connect({ host: '127.0.0.1', port: server.address().port });
      client.once('error', finish);
      client.once('connect', () => finish());
    });
  });
}
