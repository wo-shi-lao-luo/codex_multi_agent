/** Physical maintenance validation: no business receipts or revisions are implied by filesystem effects. */
import fs from 'node:fs';
import path from 'node:path';
import { timingSafeEqual, createHash } from 'node:crypto';
import { planDigest } from '../maintenance/protection.mjs';
import { inspectPath } from './paths.mjs';
import { inspectBackup } from './inspection.mjs';
import { StorageError } from './errors.mjs';

/** Authenticate a complete semantic request against current or explicitly verified backup identity. */
export function authorizePhysical(board, options) {
  if (!options || typeof options !== 'object' || Array.isArray(options)) {
    throw new StorageError('INVALID_INPUT', 'Physical maintenance requires an options object.');
  }
  const supplied = Buffer.from(typeof options.leadTokenHash === 'string' ? options.leadTokenHash : '');
  const expected = Buffer.from(board.leadTokenHash);
  if (options.leadId !== board.leadId || options.request?.actorId !== board.leadId
      || supplied.length !== expected.length || !timingSafeEqual(supplied, expected)) {
    throw new StorageError('UNAUTHORIZED', 'The current coordinator credential is required.');
  }
  const { requestHash, ...semantic } = options;
  if (!options.request.operationId || typeof options.request.operationId !== 'string'
      || !Number.isSafeInteger(options.request.expectedBoardRevision)
      || options.request.expectedBoardRevision < 0 || requestHash !== planDigest(semantic)) {
    throw new StorageError('INVALID_INPUT', 'Complete physical operation identity and digest are required.');
  }
  if (options.request.generation !== board.generation) {
    throw new StorageError('STALE_GENERATION', 'The source generation has changed.');
  }
}

/** Resolve only inspected project-local paths, never a live board filename or recovery sidecar. */
export function artifactPath(paths, value) {
  if (typeof value !== 'string' || !value) {
    throw new StorageError('INVALID_INPUT', 'Artifact path is required.');
  }
  const target = inspectPath(path.resolve(paths.projectRoot, value));
  const relative = path.relative(paths.projectRoot, target);
  if (!relative || relative === '..' || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative)
      || target === paths.file || target.startsWith(`${paths.file}-`)
      || /^(board\.sqlite|.*-(wal|shm|journal))$/i.test(path.basename(target))) {
    throw new StorageError('UNSAFE_PATH', 'Artifact must be an independent project-local backup file.');
  }
  return target;
}

/** Require a standalone closed source or a genuinely new target, checking every reserved sidecar. */
export function inspectArtifact(file, source = false) {
  inspectPath(file);
  if (source && (!fs.existsSync(file) || !fs.statSync(file).isFile())) {
    throw new StorageError('INVALID_INPUT', 'Backup source must be a regular closed file.');
  }
  for (const suffix of source ? ['-wal', '-shm', '-journal'] : ['', '-wal', '-shm', '-journal']) {
    if (fs.existsSync(file + suffix)) {
      throw new StorageError('CONFLICT', 'Artifact target exists or the source has SQLite sidecars.');
    }
  }
}

/** Stream a file digest and byte count without retaining its contents in memory. */
export async function artifactDigest(file) {
  const digest = createHash('sha256');
  let bytes = 0;
  for await (const chunk of fs.createReadStream(file)) {
    bytes += chunk.length;
    digest.update(chunk);
  }
  return { sha256: digest.digest('hex'), bytes };
}

/** Match a caller-pinned digest before copying, converting or publishing an artifact. */
export async function verifyDigest(file, expected) {
  if (typeof expected !== 'string' || !/^[a-f0-9]{64}$/i.test(expected)) {
    throw new StorageError('INVALID_INPUT', 'An expected SHA256 digest is required.');
  }
  const actual = await artifactDigest(file);
  if (actual.sha256 !== expected.toLowerCase()) {
    throw new StorageError('CONFLICT', 'Backup bytes do not match the expected digest.');
  }
  return actual;
}

/** Validate a known-format backup read-only; no journal-mode conversion may alter its bytes. */
export async function verifyBackup(file, projectRoot, boardId) {
  return inspectBackup(file, projectRoot, (db, board) => board, { boardId });
}
