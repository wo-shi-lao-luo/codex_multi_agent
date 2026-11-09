/** Local path binding for SQLite and its reserved sidecars; no cloud-drive safety claim. */
import fs from 'node:fs';
import path from 'node:path';
import { StorageError } from './errors.mjs';

/** Reject links in every existing component, including junctions and multiply-linked files. */
export function inspectPath(value) {
  const absolute = path.resolve(value);
  if (absolute.startsWith('\\\\') || absolute.startsWith('//')) {
    throw new StorageError('UNSAFE_PATH', 'Network and device paths are unsupported.');
  }
  const parsed = path.parse(absolute);
  let current = parsed.root;
  for (const component of absolute.slice(parsed.root.length).split(path.sep)) {
    if (!component) continue;
    if (process.platform === 'win32' && /[:<>"|?*]|[. ]$/.test(component)) {
      throw new StorageError('UNSAFE_PATH', 'Ambiguous Windows path component.');
    }
    if (process.platform === 'win32'
        && /^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$/i.test(component)) {
      throw new StorageError('UNSAFE_PATH', 'Windows device names are unsupported.');
    }
    current = path.join(current, component);
    let stat;
    try { stat = fs.lstatSync(current); } catch (error) {
      if (error.code === 'ENOENT') continue;
      throw error;
    }
    if (stat.isSymbolicLink() || (stat.isFile() && stat.nlink > 1)) {
      throw new StorageError('UNSAFE_PATH', 'Links are not supported in board paths.');
    }
  }
  return absolute;
}

/** Resolve a board directory strictly inside the existing canonical project root. */
export function boardPaths(projectRoot, boardPath, create = false) {
  const root = fs.realpathSync(inspectPath(projectRoot));
  const directory = inspectPath(path.resolve(root, boardPath));
  const relative = path.relative(root, directory);
  if (!relative || relative === '..' || relative.startsWith(`..${path.sep}`)
      || path.isAbsolute(relative)) {
    throw new StorageError('UNSAFE_PATH', 'Board directory must be inside the project root.');
  }
  if (/\.(sqlite|db)(-(wal|shm|journal))?$/i.test(path.basename(directory))) {
    throw new StorageError('UNSAFE_PATH', 'boardPath must be a directory, not a SQLite filename.');
  }
  if (create) fs.mkdirSync(directory, { recursive: true });
  if (!fs.existsSync(directory)) {
    throw new StorageError('NOT_INITIALIZED', 'Board directory does not exist.');
  }
  const canonical = fs.realpathSync(directory);
  const file = path.join(canonical, 'board.sqlite');
  for (const suffix of ['', '-wal', '-shm', '-journal']) inspectPath(file + suffix);
  return { projectRoot: root, directory: canonical, file };
}

/** Reserve a brand-new destination without replacing files or SQLite recovery sidecars. */
export function reserveDatabase(file) {
  inspectPath(file);
  for (const suffix of ['', '-wal', '-shm', '-journal']) {
    if (fs.existsSync(file + suffix)) {
      throw new StorageError('CONFLICT', 'Destination or a reserved SQLite sidecar already exists.');
    }
  }
  const descriptor = fs.openSync(file, 'wx', 0o600);
  fs.closeSync(descriptor);
}
