/** Closed-backup gzip round trips; published artifacts are physical effects, not business receipts. */
import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { Transform } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { createGzip, createGunzip } from 'node:zlib';
import { artifactPath, inspectArtifact, artifactDigest, verifyDigest, verifyBackup }
  from './physical-protocol.mjs';
import { publish } from './maintenance.mjs';
import { StorageError } from './errors.mjs';
import { assertSession } from './session.mjs';

/** Bound decompressed bytes before writing each chunk; overflow leaves only a rejected staging file. */
async function expand(source, destination, maximum) {
  let bytes = 0;
  const limiter = new Transform({
    transform(chunk, encoding, callback) {
      bytes += chunk.length;
      callback(bytes > maximum
        ? new StorageError('LIMIT_EXCEEDED', 'Decompressed backup exceeds the approved byte limit.')
        : null, bytes > maximum ? undefined : chunk);
    },
  });
  await pipeline(fs.createReadStream(source), createGunzip(), limiter,
    fs.createWriteStream(destination, { flags: 'wx', mode: 0o600 }));
}

/** Publish gzip or SQLite only after hash, size, full integrity, foreign-key and identity checks. */
export async function convertBackup(paths, board, options, decompress = false) {
  const maximum = options.maxUncompressedBytes;
  if (!Number.isSafeInteger(maximum) || maximum < 1) {
    throw new StorageError('INVALID_INPUT', 'A positive safe decompression byte limit is required.');
  }
  if (decompress && !/^[a-f0-9]{64}$/i.test(options.expectedDatabaseSha256 ?? '')) {
    throw new StorageError('INVALID_INPUT', 'Decompression requires an expected SQLite digest.');
  }
  const source = artifactPath(paths, options.sourcePath);
  const target = artifactPath(paths, options.destination);
  inspectArtifact(source, true);
  inspectArtifact(target);
  const sourceDigest = await verifyDigest(source, options.expectedSha256);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  const stage = `${target}.${randomUUID()}.pending`;
  let database;
  let databaseDigest;
  if (decompress) {
    await expand(source, stage, maximum);
    databaseDigest = await verifyDigest(stage, options.expectedDatabaseSha256);
    database = await verifyBackup(stage, paths.projectRoot, board.boardId);
    assertSession(database, board.sessionProfile?.sessionKey);
  } else {
    if (sourceDigest.bytes > maximum) {
      throw new StorageError('LIMIT_EXCEEDED', 'Backup exceeds the approved byte limit.');
    }
    database = await verifyBackup(source, paths.projectRoot, board.boardId);
    assertSession(database, board.sessionProfile?.sessionKey);
    await pipeline(fs.createReadStream(source), createGzip(),
      fs.createWriteStream(stage, { flags: 'wx', mode: 0o600 }));
    const verification = `${stage}.verify.sqlite`;
    await expand(stage, verification, maximum);
    databaseDigest = await verifyDigest(verification, sourceDigest.sha256);
    await verifyBackup(verification, paths.projectRoot, board.boardId);
    // This is our successful independent verification file, never a source or live SQLite family.
    fs.unlinkSync(verification);
  }
  // Concurrent source changes invalidate the result; no old recovery point is replaced on failure.
  await verifyDigest(source, sourceDigest.sha256);
  const output = await artifactDigest(stage);
  inspectArtifact(target);
  publish(stage, target);
  return {
    operationId: options.request.operationId, format: decompress ? 'sqlite' : 'gzip',
    path: target, sha256: output.sha256, bytes: output.bytes,
    databaseSha256: databaseDigest.sha256, databaseBytes: databaseDigest.bytes,
    databaseSchemaVersion: database.schemaVersion, boardId: database.boardId,
    generation: database.generation, boardRevision: database.boardRevision, eventSeq: database.eventSeq,
    sourceRetained: true, receiptCommitted: false,
  };
}
