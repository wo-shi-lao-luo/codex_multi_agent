/** Authenticated discovery/start/attach, finite and serialized. No task operations or host UI. */
import fs from 'node:fs';
import http from 'node:http';
import net from 'node:net';
import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { lockRuntime, readRuntime, writeRuntime, managerCredential, sharedHome, sharedError } from './shared-registry.mjs';
import { transportDetails } from '../server/control.mjs';

export function sharedFingerprint() {
  const hash = createHash('sha256');
  const root = fileURLToPath(new URL('../../', import.meta.url));
  const visit = relative => {
    for (const entry of fs.readdirSync(`${root}/${relative}`, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const file = `${relative}/${entry.name}`;
      if (entry.isSymbolicLink()) throw sharedError('UNSAFE_PATH');
      if (entry.isDirectory()) visit(file);
      else if (entry.isFile()) { hash.update(file); hash.update(fs.readFileSync(`${root}/${file}`)); }
    }
  };
  visit('src'); visit('web'); hash.update(fs.readFileSync(`${root}/package.json`));
  return hash.digest('hex');
}

function hasRetainedEndpoint(identity) {
  return identity?.protocol === 1 && typeof identity.hubId === 'string'
    && /^[a-f0-9-]{36}$/.test(identity.hubId)
    && Number.isInteger(identity.port) && identity.port >= 1 && identity.port <= 65535
    && identity.url === `http://127.0.0.1:${identity.port}`;
}

/** An obsolete port may belong to a different listener. Probe without credentials or HTTP. */
function probeRetainedPort(port) {
  return new Promise((resolve, reject) => {
    const socket = net.connect({ host: '127.0.0.1', port });
    socket.once('connect', () => { socket.destroy(); resolve(); });
    socket.once('error', error => reject(Object.assign(sharedError('SHARED_UNAVAILABLE'), {
      details: transportDetails(error),
    })));
    socket.setTimeout(2000, () => socket.destroy(Object.assign(Error(), { code: 'ETIMEDOUT' })));
  });
}

/** Bounded private management transport. Tokens are header/stdin data, never URL/argv data. */
export function hubRequest(identity, managerToken, operation, input) {
  if (!hasRetainedEndpoint(identity) || typeof managerToken !== 'string'
      || !/^[a-f0-9]{64}$/.test(managerToken)) {
    throw sharedError('SHARED_STATE_INVALID');
  }
  return new Promise((resolve, reject) => {
    const request = http.request(`${identity.url}/_hub/${operation}`, {
      method: operation === 'status' ? 'GET' : 'POST', agent: false,
      headers: { Authorization: `Bearer ${managerToken}`, 'X-Task-Board-Hub-Id': identity.hubId,
        'Content-Type': 'application/json' },
    }, response => {
      let size = 0; const chunks = [];
      response.on('data', chunk => { size += chunk.length; if (size > 16384) request.destroy(); else chunks.push(chunk); });
      response.on('error', () => reject(sharedError('SHARED_RESPONSE_INVALID')));
      response.on('end', () => {
        try {
          if (response.statusCode !== 200 || size > 16384) throw sharedError('SHARED_CONTROL_REJECTED');
          const result = JSON.parse(Buffer.concat(chunks).toString('utf8'));
          if (result.hubId !== identity.hubId || result.port !== identity.port) throw sharedError('SHARED_RESPONSE_INVALID');
          resolve(result);
        } catch (error) { reject(error); }
      });
    });
    const timer = setTimeout(() => request.destroy(Object.assign(Error(), { code: 'ETIMEDOUT' })), 15000);
    request.on('close', () => clearTimeout(timer));
    request.on('error', error => reject(Object.assign(sharedError('SHARED_UNAVAILABLE'), { details: transportDetails(error) })));
    request.end(input === undefined ? undefined : JSON.stringify(input));
  });
}

function launch(input) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [fileURLToPath(new URL('./shared-service-runner.mjs', import.meta.url))],
      { cwd: input.home, detached: true, windowsHide: true, stdio: ['ignore', 'ignore', 'ignore', 'ipc'] });
    let done = false;
    const finish = (error, result) => {
      if (done) return; done = true; clearTimeout(timer);
      if (child.connected) child.disconnect(); child.unref();
      if (error) reject(error); else resolve({ ...result, processId: child.pid });
    };
    const timer = setTimeout(() => finish(sharedError('SHARED_START_OUTCOME_UNKNOWN')), 15000);
    child.once('error', () => finish(sharedError('SHARED_START_OUTCOME_UNKNOWN')));
    child.once('message', result => {
      if (!result || result.error || Buffer.byteLength(JSON.stringify(result)) > 16384) {
        finish(sharedError(result?.error?.code ?? 'SHARED_START_OUTCOME_UNKNOWN'));
      } else finish(null, result);
    });
    child.send(input, error => { if (error) finish(sharedError('SHARED_START_OUTCOME_UNKNOWN')); });
  });
}

/** Runtime home comes only from a trusted launcher/programmatic caller, never request.task. */
export async function attachSharedService(input, { home = sharedHome() } = {}) {
  const release = lockRuntime(home);
  try {
    const token = managerCredential(home), fingerprint = sharedFingerprint();
    let instance = readRuntime(home, 'instance.json');
    if (instance?.state === 'starting') throw sharedError('SHARED_START_OUTCOME_UNKNOWN');
    const incompatible = instance && instance.fingerprint !== fingerprint;
    // An older running record may be stale after an upgrade. Check its exact endpoint
    // before deciding, and permit replacement only via the existing refused + absent-PID proof.
    if (incompatible && (instance.state !== 'running' || typeof instance.fingerprint !== 'string'
        || !/^[a-f0-9]{64}$/.test(instance.fingerprint) || !hasRetainedEndpoint(instance))) {
      throw sharedError('SHARED_RUNTIME_MISMATCH');
    }
    if (instance && instance.state !== 'stopped') {
      try {
        if (incompatible) {
          await probeRetainedPort(instance.port);
          throw sharedError('SHARED_RUNTIME_MISMATCH');
        }
        const status = await hubRequest(instance, token, 'status');
        if (status.fingerprint !== fingerprint || status.status !== 'running') {
          throw sharedError('SHARED_RUNTIME_MISMATCH');
        }
      } catch (error) {
        if (error.code !== 'SHARED_UNAVAILABLE' || error.details?.transportCode !== 'ECONNREFUSED') throw error;
        let absent = false;
        if (Number.isSafeInteger(instance.processId) && instance.processId > 0) {
          try { process.kill(instance.processId, 0); } catch (e) { absent = e.code === 'ESRCH'; }
        }
        if (!absent) throw sharedError('SHARED_PROCESS_UNCONFIRMED');
        instance = { ...instance, state: 'stopped' };
      }
    }
    if (!instance || instance.state === 'stopped') {
      const port = instance?.port ?? 0;
      writeRuntime(home, 'instance.json', { state: 'starting', protocol: 1, fingerprint, port });
      try { instance = await launch({ home, managerToken: token, fingerprint, port }); }
      catch (error) {
        // An explicit bind conflict is known not to have created a listener. Unknown IPC outcomes
        // keep their durable starting intent and never authorize another process.
        if (error.code === 'SHARED_PORT_CONFLICT') writeRuntime(home, 'instance.json', {
          state: 'stopped', protocol: 1, fingerprint, port });
        throw error;
      }
      if (instance.protocol !== 1 || instance.fingerprint !== fingerprint || instance.status !== 'running') throw sharedError('SHARED_START_OUTCOME_UNKNOWN');
      instance.state = 'running'; writeRuntime(home, 'instance.json', instance);
    }
    const attached = await hubRequest(instance, token, 'attach', input);
    if (attached.serviceMode !== 'shared-v1' || attached.routeBase !== `/boards/${input.location.sessionKey}/`
      || attached.sessionKey !== input.location.sessionKey || attached.generation !== input.generation
      || attached.url !== instance.url || typeof attached.serviceId !== 'string') throw sharedError('SHARED_RESPONSE_INVALID');
    return { service: attached, processId: instance.processId };
  } finally { release(); }
}
