/** Bounded task audit projection; this is work history, separate from disposable change-event replay. */
import { StorageError } from './errors.mjs';

/** Strip credential/request fields recursively without changing the stored audit evidence. */
function publicData(value) {
  if (Array.isArray(value)) return value.map(publicData);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(Object.entries(value)
    .filter(([key]) => !/token|secret|password|credential|requesthash|^request$/i.test(key))
    .map(([key, item]) => [key, publicData(item)]));
}

/** Read one ascending page inside the caller's existing read transaction, with exact task identity. */
export function readHistory(db, board, { taskId, limit = 20, cursor, afterSeq } = {}) {
  const after = cursor ?? afterSeq ?? 0;
  if (typeof taskId !== 'string' || !taskId || !Number.isSafeInteger(limit)
      || limit < 1 || limit > 100 || !Number.isSafeInteger(after) || after < 0
      || (cursor !== undefined && (!Number.isSafeInteger(cursor) || cursor < 0))
      || (afterSeq !== undefined && (!Number.isSafeInteger(afterSeq) || afterSeq < 0))
      || (cursor !== undefined && afterSeq !== undefined && cursor !== afterSeq)) {
    throw new StorageError('INVALID_INPUT', 'History requires a task ID and bounded numeric pagination.');
  }
  // Dispatch has one explicitly known nested identity. Unattributed/global events are never guessed.
  const rows = db.prepare(`SELECT sequence, type, payload FROM audit_events
    WHERE sequence > ? AND (json_extract(payload, '$.data.taskId') = ?
      OR (type = 'record-dispatch' AND json_extract(payload, '$.data.taskId') IS NULL
        AND json_extract(payload, '$.data.attempt.taskId') = ?))
    ORDER BY sequence LIMIT ?`).all(after, taskId, taskId, limit + 1);
  const hasMore = rows.length > limit;
  const items = rows.slice(0, limit).map((row) => {
    const audit = JSON.parse(row.payload);
    return {
      sequence: row.sequence, type: row.type, at: audit.at ?? null,
      data: publicData(audit.data ?? {}),
    };
  });
  return {
    items, hasMore, cursor: items.at(-1)?.sequence ?? after,
    metadata: {
      schemaVersion: board.schemaVersion, boardId: board.boardId, generation: board.generation,
      boardRevision: board.boardRevision, eventSeq: board.eventSeq,
    },
  };
}
