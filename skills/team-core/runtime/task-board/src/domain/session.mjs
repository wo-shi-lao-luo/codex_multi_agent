/** Pure session identity, label and initialization contracts; never imports SQLite or touches files. */
import { createHash } from 'node:crypto';
import { BoardError } from './errors.mjs';

const ids = ['hostId', 'mainSessionId', 'projectId'];
const rawKeys = [...ids, 'projectName', 'sessionName'];
const persistedKeys = [...rawKeys, 'version', 'sessionKey', 'labelRevision'];
const object = (value) => value && typeof value === 'object' && !Array.isArray(value);
const invalid = (message) => { throw new BoardError('INVALID_INPUT', message); };
const validUnicode = (value) => {
  for (const character of value) {
    const point = character.codePointAt(0);
    if (point >= 0xd800 && point <= 0xdfff) return false;
  }
  return !/\p{Cc}/u.test(value);
};

/** Require reliable exact host identities; no trimming or canonicalization can merge sessions. */
function contextIds(context) {
  if (!object(context) || ids.some((key) => context[key] === undefined || context[key] === '')) {
    throw new BoardError('SESSION_CONTEXT_UNAVAILABLE', 'Stable session context is required.');
  }
  for (const key of ids) {
    const value = context[key];
    if (typeof value !== 'string' || [...value].length > 256 || !validUnicode(value)) {
      invalid('Session identities must be bounded valid Unicode strings.');
    }
  }
  return ids.map((key) => context[key]);
}

const digest = (parts) => createHash('sha256').update(JSON.stringify(parts), 'utf8').digest('hex');

/** Derive an immutable context key and relative directory without filesystem/runtime dependencies. */
export function sessionLocation(context) {
  const [hostId, mainSessionId, projectId] = contextIds(context);
  return {
    sessionKey: digest(['codex-board-context-v1', hostId, mainSessionId, projectId]),
    boardPath: `_work/task-board/sessions/v1/${digest([
      'codex-board-session-v1', hostId, mainSessionId,
    ])}`,
  };
}

/** Normalize display text only; reject malformed Unicode and controls before trimming. */
export function normalizeSessionName(value) {
  if (typeof value !== 'string' || !validUnicode(value)) invalid('Invalid session display name.');
  const normalized = value.trim().normalize('NFC');
  if ([...normalized].length < 1 || [...normalized].length > 200) {
    invalid('Session display names require 1 to 200 Unicode code points.');
  }
  return normalized;
}

/** Strict raw initialization profile becomes versioned public metadata with an initial label cursor. */
export function normalizeSessionProfile(raw) {
  if (!object(raw) || Object.keys(raw).length !== rawKeys.length
      || Object.keys(raw).some((key) => !rawKeys.includes(key))) invalid('Invalid session profile.');
  const { sessionKey } = sessionLocation(raw);
  return {
    version: 1, ...Object.fromEntries(ids.map((key) => [key, raw[key]])), sessionKey,
    projectName: normalizeSessionName(raw.projectName),
    sessionName: normalizeSessionName(raw.sessionName), labelRevision: 0,
  };
}

/** Validate persisted/public metadata, including canonical labels and identity-derived key agreement. */
export function validateSessionProfile(profile) {
  if (!object(profile) || Object.keys(profile).length !== persistedKeys.length
      || Object.keys(profile).some((key) => !persistedKeys.includes(key))) {
    invalid('Invalid persisted session profile.');
  }
  const normalized = normalizeSessionProfile(
    Object.fromEntries(rawKeys.map((key) => [key, profile[key]])),
  );
  if (profile.version !== 1 || profile.sessionKey !== normalized.sessionKey
      || profile.projectName !== normalized.projectName || profile.sessionName !== normalized.sessionName
      || !Number.isSafeInteger(profile.labelRevision) || profile.labelRevision < 0) {
    invalid('Invalid persisted session profile values.');
  }
  return { ...normalized, labelRevision: profile.labelRevision };
}

/** Check new-board binding before any artifact protection, directory creation or database reservation. */
export function validateSessionInitialization({ sessionProfile, sessionKey, boardPath }) {
  if (sessionKey !== undefined && (typeof sessionKey !== 'string'
      || !/^[a-f0-9]{64}$/.test(sessionKey))) invalid('Invalid session key.');
  if (sessionProfile === undefined) {
    if (sessionKey !== undefined) {
      throw new BoardError('SESSION_UNBOUND', 'An unbound board cannot accept a session key.');
    }
    return undefined;
  }
  const profile = normalizeSessionProfile(sessionProfile);
  if (sessionKey !== profile.sessionKey) {
    throw new BoardError('SESSION_MISMATCH', 'The expected session key is required.');
  }
  if (boardPath !== sessionLocation(profile).boardPath) {
    invalid('Bound initialization requires its canonical relative directory.');
  }
  return profile;
}
