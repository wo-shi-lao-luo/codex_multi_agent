/** Discover existing session Boards beneath approved projects; only prepared confirmation writes. */
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { confirmManualAcceptance, legacyManualAcceptancePhase, replayManualAcceptance }
  from '../coordination/acceptance.mjs';
import { protectArtifacts } from '../coordination/artifact-protection.mjs';
import { sessionLocation } from '../domain/session.mjs';
import { connect, readMetadata } from '../storage/connection.mjs';
import { openBoard } from '../storage/index.mjs';
import { dashboardTasks } from './dashboard-card-projection.mjs';
import { boardPaths, inspectPath } from '../storage/paths.mjs';

const sessionsPath = '_work/task-board/sessions/v1';
const sessionDirectory = /^[a-f0-9]{64}$/;
const maxProjects = 16;
const maxDirectoriesPerProject = 128;
const listingLifetimeMs = 2000;

function unavailable() {
  return Object.assign(new Error('Dashboard cannot read this Board.'), {
    code: 'DASHBOARD_BOARD_UNAVAILABLE',
  });
}

function boardRevision(board) {
  return `${board.generation}:${board.boardRevision}:${board.eventSeq}`;
}

function projectKeyFor(root) {
  return createHash('sha256').update(JSON.stringify(['dashboard-project', root])).digest('hex');
}

/** Require the stored checkout and native identity to match the exact discovered layout. */
function describeBoard(projectRoot, boardPath, { expectedSessionKey, includeActivity = false } = {}) {
  const location = boardPaths(projectRoot, boardPath);
  const db = connect(location.file, true);
  try {
    const board = readMetadata(db);
    if (board.projectRoot !== location.projectRoot || !board.sessionProfile) throw unavailable();
    const binding = sessionLocation(board.sessionProfile);
    if (binding.boardPath !== boardPath
        || (expectedSessionKey !== undefined && binding.sessionKey !== expectedSessionKey)) {
      throw unavailable();
    }
    return {
      sessionKey: binding.sessionKey,
      projectName: board.sessionProfile.projectName,
      sessionName: board.sessionProfile.sessionName,
      updatedAt: board.updatedAt ?? null,
      revision: boardRevision(board),
      ...(includeActivity ? {
        // Some older Leads reported waiting for a human while leaving the persisted state running.
        hasRunningTasks: db.prepare(`SELECT 1 FROM tasks WHERE state = 'running'
          AND coalesce(json_extract(payload, '$.phase'), '') <> ? LIMIT 1`)
          .get(legacyManualAcceptancePhase) !== undefined,
      } : {}),
    };
  } finally {
    db.close();
  }
}

/** Discover only canonical child directories and bound the work even for malformed listings. */
function scanProject(root, catalog) {
  let projectRoot;
  try { projectRoot = fs.realpathSync(inspectPath(root)); }
  catch { return 1; }
  const projectKey = projectKeyFor(projectRoot);
  let directory;
  try {
    directory = fs.opendirSync(inspectPath(path.join(projectRoot, sessionsPath)));
  } catch (error) {
    return error.code === 'ENOENT' ? 0 : 1;
  }
  let unavailableCount = 0;
  try {
    for (let index = 0; index < maxDirectoriesPerProject; index += 1) {
      const entry = directory.readSync();
      if (entry === null) return unavailableCount;
      if (!sessionDirectory.test(entry.name)) continue;
      if (!entry.isDirectory() || entry.isSymbolicLink()) {
        unavailableCount += 1;
        continue;
      }
      const boardPath = `${sessionsPath}/${entry.name}`;
      try {
        const details = describeBoard(projectRoot, boardPath, { includeActivity: true });
        const id = createHash('sha256').update(JSON.stringify([projectRoot, boardPath])).digest('hex');
        catalog.set(id, { id, projectKey, projectRoot, boardPath, ...details });
      } catch {
        unavailableCount += 1;
      }
    }
    return unavailableCount + Number(directory.readSync() !== null);
  } catch {
    return unavailableCount + 1;
  } finally {
    directory.closeSync();
  }
}

/** Create an in-memory discovery index. The HTTP layer receives public rows and opaque IDs only. */
export function createDashboardCatalog(projectRoots) {
  if (!Array.isArray(projectRoots) || projectRoots.length < 1 || projectRoots.length > maxProjects) {
    throw Object.assign(new Error('Supply one to sixteen explicit project roots.'), {
      code: 'DASHBOARD_PROJECT_ROOT',
    });
  }
  let roots;
  try {
    roots = [...new Set(projectRoots.map(root => {
      if (typeof root !== 'string' || !path.isAbsolute(root)) throw unavailable();
      return path.normalize(root);
    }))];
  } catch {
    throw Object.assign(new Error('Dashboard requires explicit absolute project paths.'), {
      code: 'DASHBOARD_PROJECT_ROOT',
    });
  }
  let catalog = new Map();
  let unavailableCount = 0;
  let expiresAt = 0;

  function refresh() {
    if (Date.now() < expiresAt) return;
    const discoveries = new Map();
    unavailableCount = roots.reduce((count, root) => count + scanProject(root, discoveries), 0);
    catalog = discoveries;
    expiresAt = Date.now() + listingLifetimeMs;
  }

  return {
    /** Use the canonical project identity even when sessions saved different display names. */
    list() {
      refresh();
      const sessions = [...catalog.values()].sort((first, second) =>
        String(second.updatedAt).localeCompare(String(first.updatedAt))
        || first.id.localeCompare(second.id));
      const names = new Map();
      // Prefer the newest saved display name over a fallback taken from the directory name.
      for (const { projectKey, projectRoot, projectName } of sessions) {
        if (!names.has(projectKey)
            && projectName.toLowerCase() !== path.basename(projectRoot).toLowerCase()) {
          names.set(projectKey, projectName);
        }
      }
      return {
        sessions: sessions.map(({ id, projectKey, projectRoot, sessionName, updatedAt, hasRunningTasks }) => ({
          id, projectKey, projectName: names.get(projectKey) ?? path.basename(projectRoot),
          sessionName, updatedAt, hasRunningTasks,
        })),
        unavailable: unavailableCount,
      };
    },

    /** Resolve a dashboard ID via the authorized discovery index, never a browser path. */
    lookup(id) {
      refresh();
      return catalog.get(id);
    },

    /** Recheck the selected session binding and fetch its committed revision without loading tasks. */
    revision(location) {
      return describeBoard(location.projectRoot, location.boardPath,
        { expectedSessionKey: location.sessionKey }).revision;
    },

    /** Close the consistent SQLite read before building the dashboard projection. */
    snapshot(location) {
      const board = openBoard({ ...location, readOnly: true });
      let snapshot;
      try {
        snapshot = board.snapshot();
      } finally {
        board.close();
      }
      const { board: metadata } = snapshot;
      return {
        revision: boardRevision(metadata),
        projectName: metadata.sessionProfile.projectName,
        sessionName: metadata.sessionProfile.sessionName,
        tasks: dashboardTasks(snapshot),
      };
    },

    /** Commit only the exact prepared result. Every retry shares a deterministic receipt key. */
    confirmManual(location, { taskId, taskRevision, generation }) {
      protectArtifacts({ ...location, allowAppend: false });
      const operation = 'manual-confirmation';
      const requestHash = createHash('sha256')
        .update(JSON.stringify([operation, generation, taskId, taskRevision])).digest('hex');
      const request = { taskId, taskRevision, generation, operationId: `${operation}:${requestHash}` };
      const board = openBoard(location);
      try {
        board.transactOperation({ request, requestHash, operation,
          authorizeReplay: (tx, receipt) => replayManualAcceptance(tx, request, receipt.result),
        }, tx => confirmManualAcceptance(tx, request));
      } finally {
        board.close();
      }
    },
  };
}
