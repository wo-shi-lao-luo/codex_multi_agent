/** One owned process for every authenticated Board mounted in the selected runtime home. */
import { startSharedServer } from '../server/shared-server.mjs';
import { sharedFingerprint } from './shared-service.mjs';
const input = await new Promise(resolve => process.once('message', resolve));
if (Buffer.byteLength(JSON.stringify(input)) > 16384) process.exit(2);
try {
  if (sharedFingerprint() !== input.fingerprint) throw Object.assign(Error(), { code: 'SHARED_RUNTIME_MISMATCH' });
  const service = await startSharedServer(input);
  const { close, ...identity } = service;
  if (process.connected) process.send(identity, () => { if (process.connected) process.disconnect(); });
  process.once('SIGTERM', () => close()); process.once('SIGINT', () => close());
} catch (error) {
  if (process.connected) process.send({ error: { code: error.code === 'EADDRINUSE' ? 'SHARED_PORT_CONFLICT' : 'SHARED_START_FAILED' } }, () => process.exit(2));
  else process.exit(2);
}
