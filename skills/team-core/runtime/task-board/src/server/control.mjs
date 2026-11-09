/** Caller-held loopback service controls. No database access, discovery, retries or PID actions. */
import http from 'node:http';
import { BoardError } from '../domain/errors.mjs';

/** Validate retained identity before any network access; never echo credentials in errors. */
function validate(identity, timeoutMs) {
  let url;
  try { url = new URL(identity?.url); } catch { /* Reject below using a stable error. */ }
  if (!identity || !url || url.protocol !== 'http:' || url.hostname !== '127.0.0.1' ||
    url.username || url.password || url.pathname !== '/' || url.search || url.hash ||
    !Number.isInteger(identity.port) || identity.port < 1 || identity.port > 65535 ||
    Number(url.port || 80) !== identity.port ||
    !['serviceId', 'boardId', 'generation'].every(key =>
      typeof identity[key] === 'string' && /^[\x21-\x7e]{1,256}$/.test(identity[key])) ||
    typeof identity.serviceControlToken !== 'string' ||
    !/^[a-fA-F0-9]{64,256}$/.test(identity.serviceControlToken) ||
    identity.sessionKey !== undefined && (typeof identity.sessionKey !== 'string'
      || !/^[a-f0-9]{64}$/.test(identity.sessionKey)) ||
    !Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 30000) {
    throw new BoardError('INVALID_INPUT', 'Invalid service identity, credential or timeout.');
  }
  return url;
}

/** One bounded request verifies response identity; transport failure never implies stop completed. */
async function control(identity, operation, timeoutMs) {
  const url = validate(identity, timeoutMs);
  const expectedStatus = operation === 'stop' ? 'stopping' : 'running';
  return new Promise((resolve, reject) => {
    const unavailable = () => reject(new BoardError(
      'SERVICE_UNAVAILABLE', 'Service request failed; service state is unknown.',
    ));
    const rejected = () => reject(new BoardError(
      'SERVICE_CONTROL_REJECTED', 'Service rejected control or returned an invalid identity.',
    ));
    const request = http.request(new URL(`/_service/${operation}`, url), {
      method: operation === 'status' ? 'GET' : 'POST',
      agent: false,
      headers: {
        Authorization: `Bearer ${identity.serviceControlToken}`,
        'X-Task-Board-Service-Id': identity.serviceId,
        'X-Task-Board-Id': identity.boardId,
        'X-Task-Board-Generation': identity.generation,
        ...(identity.sessionKey === undefined ? {} : { 'X-Task-Board-Session-Key': identity.sessionKey }),
      },
    }, response => {
      let size = 0;
      const chunks = [];
      response.on('data', chunk => {
        size += chunk.length;
        if (size > 4096) {
          rejected();
          response.destroy();
          return;
        }
        chunks.push(chunk);
      });
      response.on('error', unavailable);
      response.on('end', () => {
        try {
          const result = JSON.parse(Buffer.concat(chunks).toString('utf8'));
          if (operation === 'open' && response.statusCode === 429
              && result.error?.code === 'TICKET_CAPACITY') {
            reject(new BoardError('SERVICE_TICKET_CAPACITY', 'Pending browser ticket capacity reached.'));
            return;
          }
          if (response.statusCode !== 200) return rejected();
          if (!['serviceId', 'boardId', 'generation', 'port'].every(key =>
            result[key] === identity[key]) || result.status !== expectedStatus
              || result.sessionKey !== identity.sessionKey) {
            return rejected();
          }
          if (operation === 'open') {
            // Validate raw canonical spelling, not just a normalized URL that can hide extra
            // query keys, encoded tokens or fragments. Never forward untrusted response extras.
            const prefix = `${url.origin}/?ticket=`;
            if (result.url !== url.origin || typeof result.ticketUrl !== 'string'
                || !result.ticketUrl.startsWith(prefix)
                || !/^[a-f0-9]{64}$/.test(result.ticketUrl.slice(prefix.length))
                || typeof result.ticketExpiresAt !== 'string'
                || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(result.ticketExpiresAt)
                || !Number.isFinite(Date.parse(result.ticketExpiresAt))) return rejected();
            resolve({ serviceId: result.serviceId, boardId: result.boardId,
              generation: result.generation, port: result.port, url: result.url,
              ...(identity.sessionKey === undefined ? {} : { sessionKey: result.sessionKey }),
              status: 'running', ticketUrl: result.ticketUrl, ticketExpiresAt: result.ticketExpiresAt });
          } else resolve(result);
        } catch { rejected(); }
      });
    });
    // A wall-clock deadline also bounds peers that continually drip response bytes.
    const deadline = setTimeout(() => request.destroy(), timeoutMs);
    request.on('error', unavailable);
    request.on('close', () => clearTimeout(deadline));
    request.end();
  });
}

/** Query the exact retained service identity with its caller-held token (1–30000 ms deadline). */
export function serviceStatus(identity, { timeoutMs = 2000 } = {}) {
  return control(identity, 'status', timeoutMs);
}

/** Request stop of this listener only; status 'stopping' means accepted, not completed cleanup. */
export function stopService(identity, { timeoutMs = 2000 } = {}) {
  return control(identity, 'stop', timeoutMs);
}

/** Mint a one-use browser entry; validates its exact origin before returning it to host navigation.
 * Running means issuance succeeded, not that a browser opened. Caller clocks need not synchronize.
 */
export function serviceOpen(identity, { timeoutMs = 2000 } = {}) {
  return control(identity, 'open', timeoutMs);
}
