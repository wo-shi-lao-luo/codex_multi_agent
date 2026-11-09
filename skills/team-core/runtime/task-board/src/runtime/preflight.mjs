/** Optional Board runtime diagnostics. No filesystem, network or third-party dependency is needed. */
export const runtimeRequirements = Object.freeze({ node: '>=26.13.0 <27', sqlite: '>=3.54.0' });

/** Compare actual version components; missing/unsupported SQLite never disables the rest of the Kit. */
export function assessRuntime(nodeVersion, sqliteVersion = null) {
  const node = /^(\d+)\.(\d+)\.(\d+)$/.exec(nodeVersion ?? '');
  const sqlite = /^(\d+)\.(\d+)\.(\d+)$/.exec(sqliteVersion ?? '');
  const nodeSupported = node && Number(node[1]) === 26 && Number(node[2]) >= 13;
  const sqliteSupported = sqlite && (Number(sqlite[1]) > 3
    || Number(sqlite[1]) === 3 && Number(sqlite[2]) >= 54);
  const reasonCode = !nodeSupported ? 'NODE_UNSUPPORTED' : !sqliteVersion ? 'SQLITE_UNAVAILABLE' :
    !sqliteSupported ? 'SQLITE_UNSUPPORTED' : 'READY';
  return { nodeVersion, sqliteVersion, available: reasonCode === 'READY', reasonCode,
    requirements: runtimeRequirements };
}

/** Probe only supported Node versions, using a closed in-memory database; unsupported Node imports no SQLite. */
export async function probeRuntime() {
  const nodeVersion = process.versions.node;
  if (assessRuntime(nodeVersion).reasonCode === 'NODE_UNSUPPORTED') return assessRuntime(nodeVersion);
  let database;
  try {
    const { DatabaseSync } = await import('node:sqlite');
    database = new DatabaseSync(':memory:');
    return assessRuntime(nodeVersion, database.prepare('SELECT sqlite_version() AS version').get().version);
  } catch { return assessRuntime(nodeVersion); }
  finally { database?.close(); }
}
