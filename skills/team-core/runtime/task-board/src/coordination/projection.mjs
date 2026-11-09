/** Bounded actor views and shared readiness; the browser consumes this projection without copying DAG rules. */
import { currentExecutionEligibility } from '../domain/execution.mjs';
import { compositeId } from '../domain/identity.mjs';
import { BoardError } from '../domain/errors.mjs';
import { dispatchUnknown } from './dispatch.mjs';
import { effectivePending, notification, questionPolicy, projectQuestion }
  from '../questions/service.mjs';

/** Explain readiness using the same production grant, input, resource and decision gates as claiming. */
export function readiness(tx, task, resourcesAvailable, worker) {
  if (!Number.isSafeInteger(task.executionRevision) || task.executionRevision < 1 ||
    task.inputRevision == null) return { readiness: 'unknown', readinessReason: 'Execution requires reconciliation.' };
  if (tx.board.recoveryRequired || tx.board.maintenance?.active) {
    return { readiness: 'blocked', readinessReason: 'Board recovery or maintenance is active.' };
  }
  if (task.state !== 'open' || task.cleanupPending ||
    tx.assignments.list({ taskId: task.id, active: true }).length) {
    return { readiness: 'blocked', readinessReason: 'Task state or retained ownership prevents claiming.' };
  }
  if (task.questionHold) return { readiness: 'blocked', readinessReason: 'An approval hold remains unresolved.' };
  if (effectivePending(tx).length >= questionPolicy(tx.board).pendingThreshold) {
    return { readiness: 'blocked', readinessReason: 'Pending decisions pause new assignments.' };
  }
  const candidates = worker ? [worker] : tx.workers.list();
  let reason = 'No current eligible grant.';
  for (const candidate of candidates) {
    try {
      if (!(['direct', 'lead-recorded', 'lead-inline'].includes(candidate.mode) && candidate.capabilities.includes('write') ||
        candidate.mode === 'lead-proxy' && candidate.capabilities.includes('read') &&
          task.scope.write.length === 0)) continue;
      currentExecutionEligibility(tx, task, { worker: candidate,
        grant: tx.grants.get(compositeId(task.id, candidate.id)), requireGrant: true });
      if (candidate.mode === 'lead-proxy' && task.scope.write.length) continue;
      if (dispatchUnknown(tx, candidate, task)) {
        reason = 'Related dispatch outcome is unknown.';
        continue;
      }
      if (!resourcesAvailable(tx, task)) {
        reason = 'Declared resources overlap current reservations.';
        continue;
      }
      return { readiness: 'ready', readinessReason: 'Approved inputs, grant and resources are available.' };
    } catch (error) { reason = error.message; }
  }
  return { readiness: 'blocked', readinessReason: reason };
}

/** Paginate immutable board-revision views; stale cursors demand a fresh first page. */
export function page(tx, items, input, filter, defaultLimit = 20, maxLimit = 100,
  keyOf = item => item.id) {
  const limit = input.limit ?? defaultLimit;
  if (!Number.isSafeInteger(limit) || limit < 1 || limit > maxLimit) {
    throw new BoardError('INVALID_INPUT', 'Page limit exceeds the operation bound.');
  }
  let lastId = '';
  if (input.cursor !== undefined) {
    let cursor;
    try {
      if (typeof input.cursor !== 'string' || input.cursor.length > 2048) throw new Error();
      cursor = JSON.parse(Buffer.from(input.cursor, 'base64url').toString());
    } catch { throw new BoardError('INVALID_INPUT', 'Malformed cursor.'); }
    if (cursor.generation !== tx.board.generation || cursor.revision !== tx.board.boardRevision ||
      cursor.filter !== filter || typeof cursor.lastId !== 'string') {
      throw new BoardError('CONFLICT', 'Cursor requires resynchronization.', { resync: true });
    }
    lastId = cursor.lastId;
  }
  const sorted = items.slice().sort((a, b) => keyOf(a) < keyOf(b) ? -1 : keyOf(a) > keyOf(b) ? 1 : 0)
    .filter(item => keyOf(item) > lastId);
  const selected = sorted.slice(0, limit);
  const hasMore = sorted.length > limit;
  const cursor = hasMore ? Buffer.from(JSON.stringify({ generation: tx.board.generation,
    revision: tx.board.boardRevision, filter, lastId: keyOf(selected.at(-1)) })).toString('base64url') : null;
  return { items: selected, hasMore, cursor };
}

/** Return compact task pages or the Lead inbox, bounded without exporting full context by default. */
export function compactQuery(tx, operation, input, worker, resourcesAvailable) {
  if (operation === 'inbox') {
    const pending = effectivePending(tx).map(question => {
      const projected = projectQuestion(tx, question);
      return { id: question.id, questionId: question.id, taskId: question.taskId,
        workerId: question.workerId, step: question.step, question: question.question,
        impact: question.impact, state: projected.state, approvalPending: projected.approvalPending,
        blocking: question.blocking, questionRevision: question.questionRevision,
        answerRevision: question.answerRevision };
    });
    const paged = page(tx, pending, input, `inbox:${input.actorId}`, 10, 50,
      question => `${question.blocking || question.approvalPending ? '0' : '1'}:${question.id}`);
    return { ...paged, notification: notification(tx), revision: tx.board.boardRevision };
  }
  let tasks = tx.tasks.list().filter(task => task.archived !== true);
  if (operation === 'ready') {
    tasks = tasks.filter(task => readiness(tx, task, resourcesAvailable, worker).readiness === 'ready');
  } else if (worker) {
    const owned = new Set(tx.assignments.list({ workerId: worker.id, active: true }).map(item => item.taskId));
    const visible = new Set(owned);
    for (const id of owned) {
      for (const edge of tx.dependencies.list({ taskId: id })) visible.add(edge.dependsOnTaskId);
    }
    tasks = tasks.filter(task => visible.has(task.id));
  }
  const summaries = tasks.map(task => ({ id: task.id, title: String(task.title).slice(0, 160),
    state: task.state, phase: task.phase, taskRevision: task.taskRevision,
    inputRevision: task.inputRevision, ...readiness(tx, task, resourcesAvailable, worker),
    ownerId: tx.assignments.list({ taskId: task.id, active: true })[0]?.workerId ?? null,
    progress: String(task.progress ?? '').slice(0, 280),
    lastReportAt: task.lastReportAt ?? null,
    nextCheckpoint: String(task.nextCheckpoint ?? '').slice(0, 280), cleanupPending: task.cleanupPending }));
  const { items, ...pagination } = page(tx, summaries, input, `${operation}:${input.actorId}`);
  const visibleIds = new Set(tasks.map(task => task.id));
  const stateCounts = Object.fromEntries([...new Set(tasks.map(task => task.state))]
    .map(state => [state, tasks.filter(task => task.state === state).length]));
  const scheduling = operation === 'status' ? {
    totalTasks: tasks.length, readyTasks: summaries.filter(task => task.readiness === 'ready').length,
    stateCounts,
    activeAssignments: tx.assignments.list({ active: true }).filter(item => visibleIds.has(item.taskId)).length,
    // Dispatch intent belongs to the Lead; role similarity never establishes worker visibility.
    unknownDispatches: worker ? null : (tx.board.dispatchAttempts ?? [])
      .filter(attempt => attempt.status === 'unknown').length,
    hostCapacity: null,
  } : undefined;
  return { tasks: items, ...pagination, revision: tx.board.boardRevision, eventSeq: tx.board.eventSeq,
    ...(scheduling === undefined ? {} : { scheduling }),
    questionPolicy: questionPolicy(tx.board) };
}

/** Adapt a consistent storage snapshot to the same pure repository rules used inside transactions. */
export function snapshotContext(snapshot) {
  return { board: snapshot.board, ...Object.fromEntries(Object.entries(snapshot)
    .filter(([, value]) => Array.isArray(value)).map(([name, records]) => [name, {
      get: id => records.find(record => record.id === id),
      list: (filter = {}) => records.filter(record => Object.entries(filter)
        .every(([key, value]) => record[key] === value)),
    }])) };
}
