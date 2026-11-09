/** Native identity is observed evidence; transport labels never establish independence. */
import { collectTaskWorkspaceIds } from './workspace-scope.mjs';
import { workspaceBindings } from '../storage/workspaces.mjs';
import { compositeId } from './identity.mjs';
import { BoardError } from './errors.mjs';
/** Validate optional native principal and derive its key without trusting a caller key. */
export function executorIdentity(item) {
  const principal = item.principal ?? null;
  for (const field of ['principal', 'runtimeIdentity']) {
    const value = item[field];
    if (value !== undefined && value !== null &&
      (typeof value !== 'object' || Array.isArray(value))) {
      throw new BoardError('INVALID_INPUT', 'Observed identity must be an object or null.');
    }
  }
  for (const field of ['role', 'model', 'reasoningEffort']) {
    const value = item.runtimeIdentity?.[field];
    if (value !== undefined && value !== null && (typeof value !== 'string' || !value)) {
      throw new BoardError('INVALID_INPUT', 'Runtime identity facts must be nonempty strings or null.');
    }
  }
  if (principal && (typeof principal.hostId !== 'string' || !principal.hostId ||
    typeof principal.agentId !== 'string' || !principal.agentId ||
    !Array.isArray(principal.evidenceRefs) || !principal.evidenceRefs.length ||
    principal.evidenceRefs.some(ref => typeof ref !== 'string' || !ref))) {
    throw new BoardError('INVALID_INPUT', 'Principal requires host, agent and evidence.');
  }
  return { principal, executorKey: principal ? compositeId(principal.hostId, principal.agentId) : null,
    runtimeIdentity: { role: item.runtimeIdentity?.role ?? null, model: item.runtimeIdentity?.model ?? null,
      reasoningEffort: item.runtimeIdentity?.reasoningEffort ?? null } };
}
/** Snapshot actual registered executor and immutable recorder provenance. */
export function executorBinding(worker, provenance = {}) {
  return { workerId: worker.id, role: worker.role, executionMode: worker.mode,
    ...executorIdentity(worker), provenance: structuredClone(provenance) };
}
/** Inline bypass is restricted to explicit task opt-in. */
export function roleEligible(task, worker) {
  return worker?.mode === 'lead-inline' ? task.allowLeadInline === true :
    task.eligibleRoles.includes(worker?.role);
}

/** Validate task metadata at add/amend boundaries; skills never confer filesystem authority. */
export function validateExecutionContract(task, tx) {
  const fail = message => { throw new BoardError('INVALID_INPUT', message); };
  for (const field of ['requiredSkills', 'responsibilities']) {
    const values = task[field] ?? [];
    if (!Array.isArray(values) || values.some(value => typeof value !== 'string' || !value) ||
      new Set(values).size !== values.length) fail('Task metadata requires distinct nonempty strings.');
  }
  if (typeof task.workspaceId !== 'string' || !task.workspaceId ||
    typeof task.allowLeadInline !== 'boolean') fail('Invalid task execution workspace or inline opt-in.');
  workspaceBindings(tx, collectTaskWorkspaceIds(task, tx));
  const kinds = ['independent-review', 'independent-evaluation', 'independent-test'];
  const checks = task.acceptancePolicy?.requiredChecks;
  if (!Array.isArray(checks) || checks.some(check => !check || typeof check.id !== 'string' ||
    !check.id || !kinds.includes(check.kind)) || new Set(checks.map(check => check.id)).size !== checks.length) {
    fail('Acceptance policy requires distinct check IDs and supported independent kinds.');
  }
  if (task.verification && (!kinds.includes(task.verification.kind) ||
    typeof task.verification.subjectTaskId !== 'string' ||
    !tx.dependencies.list({ taskId: task.id }).some(edge =>
      edge.dependsOnTaskId === task.verification.subjectTaskId && edge.gate === 'frozen-submission'))) {
    fail('Verification requires an exact subject frozen-submission dependency.');
  }
}

/** Enforce registered role ceilings again on stored workers, including explicit legacy migrations. */
export function requireWorkerScope(task, worker) {
  const readonly = ['team-reviewer', 'team-architect', 'team-ai-architect',
    'team-ai-simulation-actor-basic', 'team-ai-simulation-actor-advanced',
    'team-explorer', 'team-delivery-checker'];
  if (task.scope.write.length && (readonly.includes(worker.role) ||
    !worker.capabilities.includes('write') || worker.mode === 'lead-proxy')) {
    throw new BoardError('UNAUTHORIZED', 'Registered role and capability do not permit write scope.');
  }
}
