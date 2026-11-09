/** Data-only catalog of implemented CLI inputs; help never opens a board or probes SQLite. */
import { BoardError } from '../domain/errors.mjs';

const mutation = ['operationId', 'actorId', 'generation'];
const task = ['taskId', 'taskRevision'];
const lead = [{ when: 'Lead actor', requiredFields: ['leadToken'] }];
const actor = [...lead, { when: 'Registered direct worker', requiredFields: ['workerToken'] }];
const writer = [{ when: 'Current registered direct writer', requiredFields: ['workerToken'] }];
const questionActor = [
  ...writer,
  { when: 'Lead proxy for the current registered worker',
    requiredFields: ['leadToken', 'reportedByWorkerId', 'taskId'] },
  { when: 'Lead recording a lead-recorded worker question or acknowledgement',
    requiredFields: ['leadToken', 'reportedByWorkerId', 'taskId', 'reportEvidenceRefs'] },
  { when: 'Registered Lead inline executor', requiredFields: ['leadToken'] },
];
const commands = [];

/** Describe actual payload fields, with conditional authority separate from unconditional fields. */
function entry(operation, requiredFields = [], optionalFields = [], conditions = [], notes = '') {
  commands.push({ operation, requiredFields, optionalFields,
    conditions: structuredClone(conditions), notes });
}
/** Expand the mutation envelope without implying that all actor credential alternatives are required. */
function write(operation, required = [], optional = [], conditions = lead) {
  entry(operation, [...mutation, ...required], optional, conditions);
}

entry('session-path', ['hostId', 'mainSessionId', 'projectId'], [], [],
  'Pure context routing before runtime/SQLite. Names never determine keys or paths.');
entry('runtime-doctor', [], [], [],
  'Informational optional Board check without paths or project writes. available=false does not disable the Kit.');
entry('initialize', ['actorId', 'leadToken'], ['boardId', 'sessionProfile'], [
  { when: 'sessionProfile supplied', requiredFields: ['sessionProfile.hostId',
    'sessionProfile.mainSessionId', 'sessionProfile.projectId', 'sessionProfile.projectName',
    'sessionProfile.sessionName'], notes: 'Requires matching --session-key and canonical relative session path.' },
]);
write('session-sync', ['expectedLabelRevision', 'projectName', 'sessionName']);
commands.at(-1).notes = 'Lead-only label CAS on the bound board. Requires --session-key. '
  + 'Normalized unchanged names are authenticated no-op observations; no task or approval changes.';
for (const name of ['show', 'source-check', 'ready', 'status', 'inbox', 'workspaces']) {
  entry(name, ['actorId', ...(['show', 'source-check'].includes(name) ? ['taskId'] : [])],
    name === 'source-check' ? [] : name === 'show' ? ['history', 'limit', 'cursor'] : ['limit', 'cursor'],
    name === 'inbox' ? lead : actor);
  if (name === 'status') {
    commands.at(-1).notes = 'Scheduling counts use actor-visible unarchived tasks before pagination. '
      + 'Host capacity is unknown; worker dispatch counts are undisclosed. Missing lastReportAt is '
      + 'unknown, not a label-sync or page-refresh time.';
  }
}
entry('inspect', ['actorId', 'leadToken'], ['generation']);
entry('backup', ['actorId', 'leadToken', 'destination'], ['generation']);
commands.at(-1).notes = 'Existing board policy is audited. After Lead authentication, a new exact '
  + '_work/<slug>/ backup policy may be appended; custom directories require existing literal policy.';
entry('restore', ['actorId', 'leadToken', 'backupPath', 'writesStopped', 'processStopped',
  'maintenanceApproved']);
commands.at(-1).notes = 'Restore output requires an existing effective literal ignore policy in Git projects.';
entry('serve', ['actorId', 'leadToken'], ['generation', 'port', 'serviceControlToken']);
for (const name of ['service-status', 'service-stop', 'service-open']) {
  entry(name, ['url', 'port', 'serviceId', 'boardId', 'generation', 'serviceControlToken'],
    ['timeoutMs', 'sessionKey'], [],
    'Caller-held flat service identity. No database access. Stop status stopping acknowledges '
    + 'acceptance; it does not certify completed shutdown.');
}
commands.at(-1).notes = 'Returns an ephemeral one-use browser URL, valid for 120 seconds; '
  + 'at most 8 pending tickets including startup. Capacity rejects without eviction. Running means '
  + 'issuance succeeded, not host-opened proof. No database access or automatic browser launch.';
write('register', ['worker', 'worker.id', 'worker.role', 'worker.mode', 'worker.capabilities'],
  ['worker.hostId', 'worker.workerToken', 'worker.principal', 'worker.runtimeIdentity'], [
    ...lead, { when: 'worker.mode=direct or lead-proxy', requiredFields: ['worker.workerToken'] },
  ]);
write('add', ['task', 'task.id', 'task.title', 'task.outcome', 'task.sourceRefs',
  'task.acceptanceRefs', 'task.eligibleRoles'], ['task.priority', 'task.scope.read',
  'task.scope.write', 'task.resources', 'task.dependencies', 'task.requiredSkills',
  'task.responsibilities', 'task.allowLeadInline', 'task.workspaceId', 'task.acceptancePolicy',
  'task.verification']);
write('grant', ['taskId', 'workerId', 'approvalRevision'],
  ['executionMode', 'approvedResponsibilities']);
write('workspace-register', ['workspace', 'workspace.id', 'workspace.root']);
write('lead-inline-assign', [...task, 'approvalRevision', 'claimToken']);
write('lead-inline-report', [...task, 'assignmentId', 'claimToken', 'action'],
  ['phase', 'progress', 'blocker', 'nextCheckpoint', 'evidenceRefs', 'inputRevision',
    'writesStopped', 'processStopped']);
write('lead-record-report', [...task, 'reportedByWorkerId', 'assignmentId', 'claimToken',
  'action', 'reportEvidenceRefs'], ['phase', 'progress', 'blocker', 'nextCheckpoint',
    'evidenceRefs', 'inputRevision', 'writesStopped', 'processStopped']);
write('approve', task);
write('claim', [...task, 'claimToken'], [],
  [{ when: 'Authorized direct worker', requiredFields: ['workerToken'] }]);
write('assign', [...task, 'workerId', 'claimToken']);
for (const name of ['report', 'block', 'submit']) {
  const payload = name === 'submit' ? ['evidenceRefs', 'inputRevision'] :
    name === 'block' ? ['blocker'] : [];
  write(name, [...task, 'assignmentId', 'claimToken', ...payload],
    name === 'submit' ? ['writesStopped', 'processStopped'] :
      ['phase', 'progress', 'blocker', 'nextCheckpoint'], writer);
  commands.at(-1).notes = 'Direct worker only. The Lead reports through lead-proxy-report. '
    + 'Report/block records server-owned lastReportAt; submit does not. Caller timestamps are rejected.';
}
write('lead-proxy-report', [...task, 'reportedByWorkerId', 'assignmentId', 'claimToken', 'action'],
  ['phase', 'progress', 'blocker', 'nextCheckpoint', 'evidenceRefs', 'inputRevision',
    'writesStopped', 'processStopped']);
commands.at(-1).conditions.push(
  { when: 'action=submit', requiredFields: ['evidenceRefs', 'inputRevision'] },
  { when: 'action=block', requiredFields: ['blocker'] },
);
commands.at(-1).notes = 'Only action=report/block records server-owned lastReportAt; submit does not. '
  + 'Caller lastReportAt is rejected. Exact receipt replay preserves the recorded time.';
write('accept', [...task, 'gatesSatisfied', 'evidenceRefs'], ['checkResults']);
write('release', [...task, 'writesStopped', 'processStopped']);
write('amend', [...task, 'reason', 'expectedInputRevision', 'patch']);
for (const name of ['return', 'reopen', 'cancel']) write(name, [...task, 'reason']);
write('transfer', [...task, 'reason', 'newWorkerId', 'newClaimToken', 'expectedApprovalRevision',
  'writesStopped', 'processStopped', 'handoffRefs']);
write('reconcile', [...task, 'reason', 'expectedInputRevision', 'decision'], ['patch', 'evidenceRefs'], [
  ...lead,
  { when: 'All sourceRefs are legacy opaque declarations', requiredFields: ['sourceObservation',
    'sourceObservation.available', 'sourceObservation.revision', 'sourceObservation.evidenceRefs'] },
]);
commands.at(-1).conditions.push({ when: 'decision=amend', requiredFields: ['patch'] });
commands.at(-1).notes = 'Typed references use actual bounded file observations and approval pins; '
  + 'changed or inaccessible sources commit blocked invalidation. Legacy sourceObservation remains '
  + 'an explicit Lead declaration, not filesystem proof.';
write('recover', ['expectedBoardRevision', 'externalEffectsReviewed', 'decisions']);
write('record-dispatch', ['attemptId', 'role', 'status', 'capacityObservation',
  'capacityObservation.available', 'capacityObservation.evidenceRefs', 'evidenceRefs'],
['taskId', 'hostId', 'workerId']);
commands.at(-1).conditions.push({ when: 'status=known', requiredFields: ['hostId', 'workerId'] });
write('ask', [...task, 'assignmentId', 'claimToken', 'step', 'question', 'checkedRefs', 'impact'],
  ['options', 'recommendation', 'blocking', 'reportEvidenceRefs'], questionActor);
commands.at(-1).notes = 'Lead proxy identifies the actual registered reporter. Read-only proxy '
  + 'workers require read capability and an empty write scope; direct reports require a direct writer. '
  + 'Lead-recorded questions require reportEvidenceRefs; inline questions use the registered Lead.';
write('answer', ['questionId', 'questionRevision', 'answerRevision', 'answer', 'answer.text',
  'answer.decision', 'answer.evidenceRefs'], [], [
    ...lead,
    { when: 'Replacing a needs-approval or scope-change answer with clarify',
      requiredFields: ['answer.authorizationEvidenceRefs'] },
  ]);
commands.at(-1).notes = 'Authorization evidence does not replace current approval/grant or a '
  + 'required scope amendment when resolving an approval hold.';
write('ack-answer', ['questionId', 'questionRevision', 'answerRevision', 'assignmentId',
  'claimToken', 'applied', 'evidenceRefs'], ['taskId', 'reportEvidenceRefs'], questionActor);
commands.at(-1).notes = 'Lead proxy requires taskId and the actual registered reportedByWorkerId. '
  + 'Read-only proxy workers require read capability and an empty write scope. '
  + 'Lead-recorded acknowledgements require reportEvidenceRefs.';
write('ack-inbox', ['notificationBatchId']);
entry('maintenance-status');
entry('diagnose', [], ['level']);
for (const name of ['enter-maintenance', 'exit-maintenance', 'migrate']) {
  entry(name, [...mutation, 'leadToken', 'expectedBoardRevision', 'maintenanceId',
    'maintenanceToken', 'quiescence', ...(name === 'migrate' ?
      ['fromVersion', 'toVersion', 'backupPath'] : [])]);
  commands.at(-1).requiredFields.push('quiescence.writersStopped', 'quiescence.servicesStopped',
    'quiescence.evidenceRefs');
  commands.at(-1).notes = 'Board and migration backup output policy is audit-only and must already '
    + 'be effective. Missing policy fails with ARTIFACTS before database writes.';
  if (name === 'migrate') commands.at(-1).notes +=
    ' Explicit version pairs are 2 to 3 and 3 to 4; other steps are unsupported.';
}

const lifecycleCredentials = ['actorId', 'leadToken', 'generation'];
const lifecycleMutation = [...lifecycleCredentials, 'operationId', 'expectedBoardRevision'];
const classification = ['classificationRefs'];
entry('preview-archive', [...lifecycleCredentials, 'taskIds', 'action'], classification);
entry('archive', [...lifecycleMutation, 'taskIds', 'action', 'previewHash', 'approvalRef'], classification);
for (const command of commands.filter(item => ['preview-archive', 'archive'].includes(item.operation))) {
  command.conditions.push({ when: 'Providing classificationRefs entries', requiredFields: [
    'classificationRefs[].taskId', 'classificationRefs[].decision', 'classificationRefs[].evidenceRefs',
    'classificationRefs[].observedBoardRevision',
  ] });
}
for (const name of ['preview-prune', 'apply-prune']) {
  entry(name, [...(name === 'preview-prune' ? lifecycleCredentials : lifecycleMutation), 'target',
    'retentionApprovalRef', ...(name === 'apply-prune' ? ['previewHash', 'approvalRef'] : [])],
  ['taskIds', 'throughEventSeq'], [
    { when: 'target=change-events', requiredFields: ['throughEventSeq'] },
    { when: 'target=tasks', requiredFields: ['taskIds'] },
  ]);
  commands.at(-1).notes = 'Only approved change-events transport prefixes can be pruned. '
    + 'Task deletion is unsupported and returns protected diagnostics.';
}
entry('checkpoint', [...lifecycleMutation, 'mode']);
for (const name of ['compress-backup', 'decompress-backup']) {
  entry(name, [...lifecycleMutation, 'sourcePath', 'destination', 'expectedSha256',
    'maxUncompressedBytes', ...(name === 'decompress-backup' ? ['expectedDatabaseSha256'] : [])]);
}
entry('restore-migration-backup-2-to-3', [...lifecycleMutation, 'backupPath', 'expectedSha256']);
entry('restore-migration-backup-3-to-4', [...lifecycleMutation, 'backupPath', 'expectedSha256']);
for (const name of ['preview-vacuum', 'vacuum']) {
  entry(name, [...lifecycleMutation, 'maintenanceId', 'maintenanceToken', 'quiescence',
    'quiescence.writersStopped', 'quiescence.servicesStopped', 'quiescence.evidenceRefs',
    'policyVersion', 'backupPath', 'expectedBackupSha256', 'windowApprovalRef',
    ...(name === 'vacuum' ? ['previewHash'] : [])]);
}
entry('resolve-maintenance-operation', [...lifecycleMutation, 'maintenanceId', 'maintenanceToken',
  'pendingOperationId', 'decision', 'processObservation', 'processObservation.pid',
  'processObservation.instanceId', 'processObservation.stopped', 'processObservation.evidenceRefs',
  'integrityEvidenceRefs']);
commands.at(-1).notes = 'decision=abandon-unknown requires matching stopped-owner and integrity '
  + 'evidence; resolution does not claim that the physical operation completed.';

/** Return a selected or complete catalog; unknown command names fail without runtime access. */
export function help(args) {
  if (args.length && (args.length !== 2 || args[0] !== '--operation')) {
    throw new BoardError('INVALID_INPUT', 'Help accepts only --operation <implemented-command>.');
  }
  const selected = args.length ? commands.filter(item => item.operation === args[1]) : commands;
  if (!selected.length) throw new BoardError('INVALID_INPUT', 'Unknown help operation.');
  return { schemaVersion: 1, operation: 'help', ok: true, result: {
    transport: { requiredFlags: ['--project-root', '--board-path'],
      optionalFlags: ['--input', '--stdin', '--session-key'], maxInputBytes: 262144,
      notes: 'Paths required except help, runtime-doctor, session-path and service controls. Bound boards require '
        + '--session-key; legacy explicit boards reject supplied keys. Control input/flag keys must agree.' },
    commands: selected,
  } };
}
