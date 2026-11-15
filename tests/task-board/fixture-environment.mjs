// These checks diagnose fixture prerequisites, never turn unavailable product assertions green.
import { createServer, createConnection } from 'node:net';
import { symlink } from 'node:fs/promises';

function setupError(capability, cause) {
  const error = new Error(`TEST_SETUP: ${capability}; use an environment permitting this fixture capability.`,
    { cause });
  error.code = 'TEST_SETUP';
  return error;
}

// SQLite's Windows path boundary is checked before creating its canonical Board files.
export function checkFixturePath(path) {
  if (process.platform === 'win32' && path.length >= 260) {
    throw setupError('PATH_TOO_LONG; select a shorter checkout/fixture path');
  }
}

// Only service-bearing fixtures call this bounded, owned loopback check.
export async function requireLoopback() {
  const server = createServer(socket => socket.end());
  let client;
  try {
    await new Promise((resolve, reject) => {
      server.once('error', reject);
      server.listen(0, '127.0.0.1', resolve);
    });
    await new Promise((resolve, reject) => {
      client = createConnection(server.address().port, '127.0.0.1');
      client.once('connect', resolve);
      client.once('error', reject);
      client.setTimeout(2000, () => reject(new Error('Loopback probe timeout')));
    });
  } catch (error) {
    throw setupError('LOOPBACK_UNAVAILABLE', error);
  } finally {
    client?.destroy();
    if (server.listening) await new Promise(resolve => server.close(resolve));
  }
}

// Preserve unexpected fixture bugs; only permission/unsupported errors become setup diagnostics.
export async function fixtureDirectoryLink(target, link) {
  try { await symlink(target, link, 'junction'); }
  catch (error) {
    if (['EPERM', 'EACCES', 'ENOTSUP'].includes(error.code)) {
      throw setupError('DIRECTORY_LINK_UNAVAILABLE', error);
    }
    throw error;
  }
}
