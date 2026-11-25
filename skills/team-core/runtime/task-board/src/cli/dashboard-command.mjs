/** User-started local viewer. The foreground process owns the listener and its credentials. */
import { BoardError } from '../domain/errors.mjs';
import { probeRuntime } from '../runtime/preflight.mjs';

export async function runDashboard(args) {
  const projectRoots = [];
  let port;
  for (let index = 0; index < args.length; index += 2) {
    const flag = args[index];
    const value = args[index + 1];
    if (flag === '--project-root' && value && !value.startsWith('--')) {
      projectRoots.push(value);
    } else if (flag === '--port' && port === undefined && /^\d{1,5}$/.test(value ?? '')) {
      port = Number(value);
    } else {
      throw new BoardError('INVALID_INPUT', 'Use dashboard --project-root PATH [--project-root PATH] [--port PORT].');
    }
  }
  if (!projectRoots.length || projectRoots.length > 16 || port > 65535) {
    throw new BoardError('INVALID_INPUT', 'Specify between 1 and 16 project roots and a valid local port.');
  }
  const runtime = await probeRuntime();
  if (!runtime.available) {
    throw new BoardError('UNSUPPORTED_RUNTIME', 'The viewer requires the installed Board runtime.',
      { reasonCode: runtime.reasonCode });
  }
  const { startDashboard } = await import('../server/dashboard.mjs');
  let dashboard;
  try {
    dashboard = await startDashboard({ projectRoots, port });
  } catch (error) {
    if (error.code === 'EADDRINUSE') throw new BoardError('DASHBOARD_PORT_IN_USE', 'The viewer port is in use. Choose --port PORT.');
    if (error.code === 'DASHBOARD_PROJECT_ROOT') throw new BoardError(error.code, 'A project root is invalid or inaccessible.');
    throw error;
  }
  const shutdown = () => {
    dashboard.close().catch(() => { process.exitCode = 3; });
  };
  process.once('SIGINT', shutdown);
  process.once('SIGTERM', shutdown);
  process.stdout.write(`${JSON.stringify({ schemaVersion: 1, operation: 'dashboard', ok: true,
    result: { url: dashboard.url } })}\n`);
}
