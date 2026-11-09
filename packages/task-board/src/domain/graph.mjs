/** Dependency DAG validation and revision-bound invalidation; historical results remain recorded. */
import { collectTaskWorkspaceIds, validateTaskScopes } from './workspace-scope.mjs';
import { workspaceBindings } from '../storage/workspaces.mjs';
import { acceptedChecksCurrent } from '../coordination/execution-evidence.mjs';
import { compositeId } from './identity.mjs';
import { BoardError } from './errors.mjs';
import { requireCurrentSources } from '../sources/adapter.mjs';

/** Validate a complete replacement edge set before changing any relationship rows. */
export function replaceDependencies(tx, taskId, edges) {
  if (!Array.isArray(edges)) throw new BoardError('INVALID_INPUT', 'Dependencies must be an array.');
  const seen = new Set();
  for (const edge of edges) {
    if (!edge || !tx.tasks.get(edge.taskId) || seen.has(edge.taskId) ||
      !['accepted-result', 'frozen-submission'].includes(edge.gate)) {
      throw new BoardError('INVALID_INPUT', 'Dependencies must name distinct existing tasks and gates.');
    }
    seen.add(edge.taskId);
  }
  const existing = tx.dependencies.list().filter(edge => edge.taskId !== taskId);
  const all = [...existing, ...edges.map(edge => ({ taskId, dependsOnTaskId: edge.taskId }))];
  const visiting = new Set();
  const visited = new Set();
  function visit(id) {
    if (visiting.has(id)) throw new BoardError('CONFLICT', 'Dependency cycle is not allowed.');
    if (visited.has(id)) return;
    visiting.add(id);
    for (const edge of all.filter(item => item.taskId === id)) visit(edge.dependsOnTaskId);
    visiting.delete(id);
    visited.add(id);
  }
  visit(taskId);
  for (const edge of tx.dependencies.list({ taskId })) tx.dependencies.remove(edge.id);
  for (const edge of edges) {
    tx.dependencies.put({ id: compositeId(taskId, edge.taskId), taskId,
      dependsOnTaskId: edge.taskId, gate: edge.gate });
  }
}

/** Gate validity depends on immutable evidence counters, never routine progress/task CAS updates. */
export function dependenciesReady(tx, task) {
  return tx.dependencies.list({ taskId: task.id }).every(edge => {
    const upstream = tx.tasks.get(edge.dependsOnTaskId);
    if (!upstream || !Number.isSafeInteger(upstream.executionRevision) ||
      upstream.executionRevision < 1 || upstream.inputValid !== true ||
      upstream.needsReconcile || upstream.approvalRevision <= 0) return false;
    try {
      validateTaskScopes(tx, upstream);
      workspaceBindings(tx, collectTaskWorkspaceIds(upstream, tx));
      requireCurrentSources(tx, upstream, true);
    } catch { return false; }
    if (edge.gate === 'accepted-result') {
      return upstream.state === 'closed' && upstream.resultValid === true && consumableResult(tx, upstream);
    }
    return ['submitted', 'closed'].includes(upstream.state) &&
      tx.submissions.list({ taskId: upstream.id }).some(submission => submission.freezeValid &&
        submission.freezeRevision === upstream.freezeRevision &&
        submission.executionRevision === upstream.executionRevision &&
        submission.approvalRevision === upstream.approvalRevision &&
        submission.boundTaskInputRevision === upstream.inputRevision);
  });
}

/** Accepted execution results cannot launder unresolved obligations through historical intermediates.
 * Frozen source remains available for read-only verification; acceptance checks its full lineage.
 */
export function consumableResult(tx, task, visited = new Set()) {
  if (!task || task.questionHold || !task.inputValid || task.needsReconcile ||
    task.approvalRevision <= 0) return false;
  let currentWorkspaces;
  try {
    validateTaskScopes(tx, task);
    currentWorkspaces = workspaceBindings(tx, collectTaskWorkspaceIds(task, tx));
    requireCurrentSources(tx, task, true);
  } catch { return false; }
  const submission = tx.submissions.list({ taskId: task.id }).find(item =>
    item.freezeValid && item.freezeRevision === task.freezeRevision);
  const record = task.state === 'closed' ? task.acceptedResult : submission;
  if (!record || !submission || task.state === 'closed' &&
    (!task.resultValid || record.submissionId !== submission.id) ||
    record.executionRevision !== task.executionRevision ||
    record.boundTaskInputRevision !== task.inputRevision ||
    record.approvalRevision !== task.approvalRevision ||
    JSON.stringify(record.workspaceBindings) !== JSON.stringify(currentWorkspaces)) return false;
  const bindings = record.inputBindings;
  if (!Array.isArray(bindings)) return false;
  const currentBindings = bindings.every(binding => {
    const upstream = tx.tasks.get(binding.taskId);
    if (!upstream || upstream.questionHold || upstream.inputRevision !== binding.inputRevision) return false;
    const revision = binding.gate === 'accepted-result' ? upstream.resultRevision : upstream.freezeRevision;
    if (revision !== binding.gateRevision) return false;
    try {
      return JSON.stringify(binding.workspaceBindings) ===
        JSON.stringify(workspaceBindings(tx, collectTaskWorkspaceIds(upstream, tx)));
    } catch { return false; }
  });
  if (!currentBindings) return false;
  // Checkers legitimately consume their subject freeze. Cut that backreference only after local
  // sources, holds, proof counters and workspace/input identities above have been revalidated.
  if (visited.has(task.id)) return true;
  visited.add(task.id);
  if (task.state === 'closed' && !acceptedChecksCurrent(tx, task, new Set(),
    checker => consumableResult(tx, checker, visited))) return false;
  return bindings.every(binding => consumableResult(tx, tx.tasks.get(binding.taskId), visited));
}

/** Bind newly executing work to the exact upstream gate and input versions it consumes. */
export function consumeDependencies(tx, task) {
  for (const edge of tx.dependencies.list({ taskId: task.id })) {
    const upstream = tx.tasks.get(edge.dependsOnTaskId);
    tx.dependencies.put({ ...edge, consumedInputRevision: upstream.inputRevision,
      consumedRevision: edge.gate === 'accepted-result' ? upstream.resultRevision :
        upstream.freezeRevision });
  }
}

/** Invalidate consumed outputs breadth-first, preserving closed history and every resource hold. */
export function invalidateOutputs(tx, root) {
  const queue = [root];
  const visited = new Set();
  while (queue.length) {
    const task = queue.shift();
    if (visited.has(task.id)) continue;
    visited.add(task.id);
    const oldResult = task.resultRevision;
    const oldFreeze = task.freezeRevision;
    task.resultRevision = (task.resultRevision ?? 0) + 1;
    task.freezeRevision = (task.freezeRevision ?? 0) + 1;
    task.resultValid = false;
    for (const submission of tx.submissions.list({ taskId: task.id })) {
      if (submission.freezeValid) tx.submissions.put({ ...submission, freezeValid: false });
    }
    // Required checker evidence has a reverse invalidation relation, not a scheduling edge.
    // Preserve the producer's closed history and every hold while withdrawing consumable validity.
    for (const producer of tx.tasks.list()) {
      if (visited.has(producer.id) || !producer.resultValid ||
        !producer.acceptedResult?.checkBindings?.some(binding =>
          binding.taskId === task.id && binding.resultRevision === oldResult)) continue;
      producer.inputValid = false;
      producer.needsReconcile = true;
      producer.executionRevision = Number.isSafeInteger(producer.executionRevision) ?
        producer.executionRevision + 1 : null;
      producer.taskRevision++;
      queue.push(producer);
    }
    for (const edge of tx.dependencies.list({ dependsOnTaskId: task.id })) {
      const oldGate = edge.gate === 'accepted-result' ? oldResult : oldFreeze;
      if (edge.consumedRevision !== oldGate || oldGate == null) continue;
      const downstream = tx.tasks.get(edge.taskId);
      if (visited.has(downstream.id)) continue;
      downstream.inputValid = false;
      downstream.needsReconcile = true;
      // Missing legacy epochs stay unknown until explicit Lead reconciliation, never default to one.
      downstream.executionRevision = Number.isSafeInteger(downstream.executionRevision) ?
        downstream.executionRevision + 1 : null;
      if (downstream.state === 'running') downstream.state = 'blocked';
      downstream.taskRevision++;
      queue.push(downstream);
    }
    tx.tasks.put(task);
  }
}
