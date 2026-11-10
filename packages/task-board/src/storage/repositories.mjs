/** Small-board repositories own all SQL; synchronous domain callbacks own eligibility decisions. */
import { repositoryDefinitions } from './schema.mjs';
import { StorageError } from './errors.mjs';

const MAX_ROWS = 10000;

/** Create bounded repositories. Writes require an active unit of work and never accept SQL text. */
export function repositories(db, assertWritable = () => {
  throw new StorageError('READ_ONLY', 'Repository writes require an operation transaction.');
}) {
  return Object.fromEntries(Object.entries(repositoryDefinitions).map(([name, definition]) => {
    const { table, fields } = definition;
    const keys = Object.keys(fields);
    const get = db.prepare(`SELECT payload FROM ${table} WHERE id = ?`);
    const count = db.prepare(`SELECT COUNT(*) AS total FROM ${table}`);
    const list = db.prepare(`SELECT payload FROM ${table} ORDER BY id LIMIT ${MAX_ROWS + 1}`);
    const columns = ['id', 'payload', ...keys];
    const put = db.prepare(`INSERT INTO ${table} (${columns.join(', ')})
      VALUES (${columns.map(() => '?').join(', ')}) ON CONFLICT(id) DO UPDATE SET
      ${columns.slice(1).map((column) => `${column} = excluded.${column}`).join(', ')}`);
    return [name, {
      /** Return one detached camelCase record, or undefined when the identity does not exist. */
      get(id) {
        const row = get.get(id);
        return row ? JSON.parse(row.payload) : undefined;
      },
      /** Equality-filter a bounded small-board set; overflow fails rather than silently truncating. */
      list(filter = {}) {
        const rows = list.all();
        if (rows.length > MAX_ROWS) {
          throw new StorageError('LIMIT_EXCEEDED', 'Board exceeds the supported P0 record limit.');
        }
        return rows.map((row) => JSON.parse(row.payload)).filter((record) => (
          Object.entries(filter).every(([key, value]) => record[key] === value)
        ));
      },
      /** Insert/update a complete record; new identities must fit the per-table small-board cap. */
      put(record) {
        assertWritable();
        if (!record || typeof record.id !== 'string' || !record.id) {
          throw new StorageError('INVALID_INPUT', 'Repository records require a nonempty id.');
        }
        // The caller's serialized write transaction protects count plus insert. Count the entire
        // table, including history, so a filtered read cannot conceal snapshot-breaking overflow.
        // Existing identities stay writable at capacity for lifecycle updates and invalidation.
        if (!get.get(record.id) && count.get().total >= MAX_ROWS) {
          throw new StorageError('LIMIT_EXCEEDED', 'Board exceeds the supported P0 record limit.');
        }
        const values = keys.map((key) => {
          const value = record[key];
          return typeof value === 'boolean' ? Number(value) : value ?? null;
        });
        put.run(record.id, JSON.stringify(record), ...values);
        return structuredClone(record);
      },
      /** Explicit removal still respects references; lifecycle authorization remains domain-owned. */
      remove(id) {
        assertWritable();
        return db.prepare(`DELETE FROM ${table} WHERE id = ?`).run(id).changes;
      },
    }];
  }));
}
