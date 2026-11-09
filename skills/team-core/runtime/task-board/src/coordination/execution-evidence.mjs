/** Independent gates resolve accepted checker evidence against the current subject freeze. */
import { workspaceBindings } from '../storage/workspaces.mjs';
import { collectTaskWorkspaceIds, validateTaskScopes } from '../domain/workspace-scope.mjs';
import { requireCurrentSources } from '../sources/adapter.mjs';
import { BoardError } from '../domain/errors.mjs';
import { currentExecutionEligibility } from '../domain/execution.mjs';
/** Reject missing, stale, wrong-role, unknown-principal and same-principal checks. */
export function requireIndependentChecks(tx, task, subject, results = []) {
  if (!Array.isArray(results) || results.some(item => !item ||
    typeof item.checkId !== 'string' || typeof item.taskId !== 'string' ||
    typeof item.submissionId !== 'string') ||
    new Set(results.map(item => item.checkId)).size !== results.length) {
    throw new BoardError('INVALID_INPUT', 'Check results require distinct IDs and evidence references.');
  }
  const bindings = [];
  for (const check of task.acceptancePolicy?.requiredChecks ?? []) {
    const result = results.find(item => item.checkId === check.id);
    const verification = tx.tasks.get(result?.taskId);
    const evidence = tx.submissions.get(result?.submissionId);
    const actual = evidence?.actualExecutor;
    const worker = tx.workers.get(actual?.workerId);
    const roles = { 'independent-review': ['team-reviewer'], 'independent-evaluation': ['team-ai-tester'],
      'independent-test': ['team-tester', 'team-ai-tester'] };
    const binding = evidence?.inputBindings?.find(item => item.taskId === task.id &&
      item.gate === 'frozen-submission');
    if (!verification || verification.state !== 'closed' || !verification.resultValid ||
      verification.acceptedResult?.submissionId !== evidence?.id || !evidence?.freezeValid ||
      verification.verification?.kind !== check.kind || verification.verification?.subjectTaskId !== task.id ||
      !binding || binding.inputRevision !== task.inputRevision || binding.gateRevision !== task.freezeRevision ||
      !actual?.executorKey || !subject.actualExecutor?.executorKey ||
      actual.executorKey === subject.actualExecutor.executorKey || actual.executionMode === 'lead-inline' ||
      !worker || worker.role !== actual.role || !(roles[check.kind] ?? []).includes(worker.role)) {
      throw new BoardError('DEPENDENCY_BLOCKED', 'Current independent verification is required.');
    }
    currentExecutionEligibility(tx, verification, { record: evidence });
    bindings.push({ checkId: check.id, taskId: verification.id,
      resultRevision: verification.resultRevision, submissionId: evidence.id,
      executorKey: actual.executorKey, workspaceBindings: structuredClone(evidence.workspaceBindings) });
  }
  return bindings;
}

/** Validate accepted checker references without recursing through their subject frozen dependency.
 * Checker-to-subject evidence references are separate from the scheduling DAG to avoid a cycle.
 */
export function acceptedChecksCurrent(tx, task, visited = new Set(), lineage) {
  const required = task.acceptancePolicy?.requiredChecks ?? [];
  if (!required.length) return true;
  if (visited.has(task.id)) return false;
  visited.add(task.id);
  const bindings = task.acceptedResult?.checkBindings;
  if (!Array.isArray(bindings) || bindings.length !== required.length) return false;
  return required.every(check => {
    const binding = bindings.find(item => item.checkId === check.id);
    const checker = tx.tasks.get(binding?.taskId);
    const evidence = tx.submissions.get(binding?.submissionId);
    if (!checker || checker.state !== 'closed' || !checker.resultValid ||
      !checker.inputValid || checker.needsReconcile || checker.questionHold ||
      checker.resultRevision !== binding.resultRevision ||
      checker.acceptedResult?.submissionId !== evidence?.id || !evidence?.freezeValid ||
      checker.verification?.subjectTaskId !== task.id || checker.verification?.kind !== check.kind ||
      evidence.actualExecutor?.executorKey !== binding.executorKey ||
      checker.executionRevision !== evidence.executionRevision ||
      checker.inputRevision !== evidence.boundTaskInputRevision ||
      checker.freezeRevision !== evidence.freezeRevision) return false;
    try {
      validateTaskScopes(tx, checker);
      requireCurrentSources(tx, checker, true);
      if (JSON.stringify(binding.workspaceBindings) !==
        JSON.stringify(workspaceBindings(tx, collectTaskWorkspaceIds(checker, tx)))) return false;
    } catch { return false; }
    return lineage ? lineage(checker) : acceptedChecksCurrent(tx, checker, new Set(visited));
  });
}
