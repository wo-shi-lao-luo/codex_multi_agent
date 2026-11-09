/** Session guards and authenticated label updates; all durable writes use ordinary operation receipts. */
import { createHash, timingSafeEqual } from 'node:crypto';
import { normalizeSessionName, validateSessionProfile } from '../domain/session.mjs';
import { StorageError } from './errors.mjs';

/** Check current optional binding before exposing metadata, mutating state or replaying old success. */
export function assertSession(board, sessionKey) {
  if (sessionKey !== undefined && (typeof sessionKey !== 'string'
      || !/^[a-f0-9]{64}$/.test(sessionKey))) {
    throw new StorageError('INVALID_INPUT', 'Invalid session key.');
  }
  if (board.sessionProfile === undefined) {
    if (sessionKey !== undefined) {
      throw new StorageError('SESSION_UNBOUND', 'This board has no session binding.');
    }
    return;
  }
  const profile = validateSessionProfile(board.sessionProfile);
  if (sessionKey !== profile.sessionKey) {
    throw new StorageError('SESSION_MISMATCH', 'This board requires its expected session key.');
  }
}

/** Authenticate the current Lead; raw credentials are hashed and never copied into metadata/events. */
function authorize(board, request) {
  const supplied = createHash('sha256').update(
    typeof request.leadToken === 'string' ? request.leadToken : '',
  ).digest('hex');
  const expected = board.leadTokenHash;
  if (request.actorId !== board.leadId || typeof expected !== 'string'
      || expected.length !== supplied.length
      || !timingSafeEqual(Buffer.from(expected), Buffer.from(supplied))) {
    throw new StorageError('UNAUTHORIZED', 'Current Lead authorization is required.');
  }
}

// This private sentinel rolls back the reserved transaction before returning a read-only observation.
class UnchangedSession extends Error {
  constructor(envelope) { super('Session labels unchanged.'); this.envelope = envelope; }
}

/** Sync labels using current handle context; exact committed replays never reapply historical labels. */
export function syncSession(handle, { request, requestHash }) {
  const allowed = ['operationId', 'actorId', 'generation', 'leadToken',
    'expectedLabelRevision', 'projectName', 'sessionName'];
  if (!request || typeof request !== 'object' || Array.isArray(request)
      || typeof request.operationId !== 'string' || !request.operationId
      || Object.keys(request).some((key) => !allowed.includes(key))
      || !Number.isSafeInteger(request.expectedLabelRevision) || request.expectedLabelRevision < 0) {
    throw new StorageError('INVALID_INPUT', 'A label revision and name-only mutation are required.');
  }
  const projectName = normalizeSessionName(request.projectName);
  const sessionName = normalizeSessionName(request.sessionName);
  try {
    return handle.transactOperation({
      request, requestHash, operation: 'session-sync',
      authorizeReplay: ({ board }, envelope) => {
        authorize(board, request);
        if (envelope.operation !== 'session-sync') {
          throw new StorageError('IDEMPOTENCY_MISMATCH', 'Operation ID belongs to another method.');
        }
      },
    }, ({ board, audit, change }) => {
      authorize(board, request);
      if (!board.sessionProfile) throw new StorageError('SESSION_UNBOUND', 'This board is unbound.');
      const current = validateSessionProfile(board.sessionProfile);
      if (request.expectedLabelRevision !== current.labelRevision) {
        throw new StorageError('CONFLICT', 'Session label revision has changed.');
      }
      if (current.projectName === projectName && current.sessionName === sessionName) {
        throw new UnchangedSession({
          schemaVersion: 1, operation: 'session-sync', ok: true, boardId: board.boardId,
          generation: board.generation, boardRevision: board.boardRevision, eventSeq: board.eventSeq,
          result: { sessionProfile: current, unchanged: true, receiptCommitted: false },
        });
      }
      if (!Number.isSafeInteger(current.labelRevision + 1)) {
        throw new StorageError('CONFLICT', 'Session label revision is exhausted.');
      }
      board.sessionProfile = { ...current, projectName, sessionName,
        labelRevision: current.labelRevision + 1 };
      const data = { actorId: request.actorId, sessionProfile: board.sessionProfile };
      audit('session.labels.updated', data);
      change('session.labels.updated', data);
      return { sessionProfile: board.sessionProfile, unchanged: false, receiptCommitted: true };
    });
  } catch (error) {
    if (error instanceof UnchangedSession) return error.envelope;
    throw error;
  }
}
