/** Stable storage failures; domain errors pass through transaction rollback unchanged. */
export class StorageError extends Error {
  constructor(code, message, details = {}) {
    super(message);
    this.name = 'StorageError';
    this.code = code;
    this.details = details;
  }
}

/** Translate SQLite failures without exposing SQL or secret-bearing values. */
export function storageFailure(error) {
  if (error instanceof StorageError || error.code !== 'ERR_SQLITE_ERROR') return error;
  const primary = error.errcode & 255;
  if (primary === 5 || primary === 6) {
    return new StorageError('BUSY', 'The board is busy; read current facts before retrying.');
  }
  if (primary === 19) return new StorageError('CONFLICT', 'A storage constraint rejected the change.');
  return new StorageError('RECOVERY_REQUIRED', 'SQLite could not complete the operation.', {
    sqliteCode: error.errcode,
  });
}
