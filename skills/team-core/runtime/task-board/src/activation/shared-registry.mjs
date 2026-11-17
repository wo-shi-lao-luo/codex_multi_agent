/** Private runtime files outside Skill discovery. Never accept these paths from a browser/task. */
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { randomBytes, randomUUID } from 'node:crypto';
import { inspectPath } from '../storage/paths.mjs';
import { BoardError } from '../domain/errors.mjs';

export const sharedHome = () => path.join(os.homedir(), '.agents', 'codex-multi-agent', 'board-service-v1');
export const sharedError = code => new BoardError(code, 'Shared Board service requires reconciliation.');
const names = new Set(['authority.json', 'instance.json', 'boards.json', 'startup.lock']);
export function runtimeFile(home, name) {
  if (!names.has(name)) throw sharedError('INVALID_INPUT');
  return inspectPath(path.join(inspectPath(home), name));
}
export function readRuntime(home, name) {
  const file = runtimeFile(home, name);
  let fd;
  try {
    fd = fs.openSync(file, fs.constants.O_RDONLY | (fs.constants.O_NOFOLLOW ?? 0));
    const stat = fs.fstatSync(fd);
    if (!stat.isFile() || stat.nlink !== 1 || stat.size > 1048576) throw sharedError('SHARED_STATE_INVALID');
    const bytes = Buffer.alloc(1048577);
    const size = fs.readSync(fd, bytes, 0, bytes.length, 0);
    if (size > 1048576) throw sharedError('SHARED_STATE_INVALID');
    return JSON.parse(bytes.subarray(0, size).toString('utf8'));
  } catch (error) { if (error.code === 'ENOENT') return null; throw error; }
  finally { if (fd !== undefined) fs.closeSync(fd); }
}
export function writeRuntime(home, name, value) {
  const target = runtimeFile(home, name), temp = inspectPath(`${target}.${randomUUID()}.tmp`);
  fs.writeFileSync(temp, JSON.stringify(value), { flag: 'wx', mode: 0o600 });
  fs.renameSync(temp, target);
}
/** A dead caller's lock may be retired; its unknown launch intent remains a hard stop. */
export function lockRuntime(home) {
  inspectPath(home); fs.mkdirSync(home, { recursive: true, mode: 0o700 });
  const file = runtimeFile(home, 'startup.lock');
  let fd;
  try { fd = fs.openSync(file, 'wx', 0o600); }
  catch (error) {
    if (error.code !== 'EEXIST') throw error;
    const before = fs.lstatSync(file), owner = readRuntime(home, 'startup.lock');
    if (!Number.isSafeInteger(owner?.pid) || owner.pid <= 0) throw sharedError('SHARED_BUSY');
    let absent = false;
    try { process.kill(owner.pid, 0); } catch (e) { absent = e.code === 'ESRCH'; }
    const after = fs.lstatSync(runtimeFile(home, 'startup.lock'));
    if (!absent || before.dev !== after.dev || before.ino !== after.ino) throw sharedError('SHARED_BUSY');
    fs.unlinkSync(file); fd = fs.openSync(file, 'wx', 0o600);
  }
  fs.writeFileSync(fd, JSON.stringify({ pid: process.pid, instance: randomUUID() }));
  return () => { fs.closeSync(fd); fs.unlinkSync(file); };
}
export function managerCredential(home) {
  let record = readRuntime(home, 'authority.json');
  if (!record) {
    record = { protocol: 1, token: randomBytes(32).toString('hex') };
    writeRuntime(home, 'authority.json', record);
  }
  if (record.protocol !== 1 || !/^[a-f0-9]{64}$/.test(record.token)) throw sharedError('SHARED_STATE_INVALID');
  return record.token;
}
