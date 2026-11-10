/** Bounded private subprocess transport; credentials travel only through stdin. */
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export const cliPath = fileURLToPath(new URL('../cli/cli.mjs', import.meta.url));
export function callCli(root, boardPath, sessionKey, operation, input) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [cliPath, operation, '--project-root', root,
      '--board-path', boardPath, '--session-key', sessionKey, '--stdin'], {
      cwd: root, windowsHide: true, stdio: ['pipe', 'pipe', 'ignore'],
    });
    let output = '';
    const timer = setTimeout(() => {
      child.kill();
      reject(Object.assign(new Error('CLI outcome requires reconciliation.'), { code: 'OUTCOME_UNKNOWN' }));
    }, 15000);
    child.stdout.on('data', chunk => {
      output += chunk;
      if (output.length > 1048576) child.kill();
    });
    child.on('error', reject);
    child.on('close', () => {
      clearTimeout(timer);
      try {
        const reply = JSON.parse(output);
        if (!reply.ok) throw Object.assign(new Error('Board operation rejected.'), {
          code: reply.error?.code ?? 'IO_ERROR',
        });
        resolve(reply);
      } catch (error) { reject(error); }
    });
    child.stdin.on('error', () => {});
    child.stdin.end(JSON.stringify(input));
  });
}
