/** Strict JSON adapter for storage-owned retention, physical maintenance and legacy recovery. */
import { BoardError } from '../domain/errors.mjs';
import { tokenHash } from '../coordination/service.mjs';

const credentials = ['actorId', 'leadToken', 'generation'];
const mutation = [...credentials, 'operationId', 'expectedBoardRevision'];
const archive = ['taskIds', 'action', 'classificationRefs'];
const prune = ['target', 'taskIds', 'throughEventSeq', 'retentionApprovalRef'];
const approval = ['previewHash', 'approvalRef'];
const compression = ['sourcePath', 'destination', 'expectedSha256', 'maxUncompressedBytes'];
const session = ['maintenanceId', 'maintenanceToken'];
const vacuum = [...session, 'quiescence', 'policyVersion', 'backupPath',
  'expectedBackupSha256', 'windowApprovalRef'];
const fields = {
  'preview-archive': [...credentials, ...archive],
  archive: [...mutation, ...archive, ...approval],
  'preview-prune': [...credentials, ...prune],
  'apply-prune': [...mutation, ...prune, ...approval],
  checkpoint: [...mutation, 'mode'],
  'compress-backup': [...mutation, ...compression],
  'decompress-backup': [...mutation, ...compression, 'expectedDatabaseSha256'],
  'restore-migration-backup-2-to-3': [...mutation, 'backupPath', 'expectedSha256'],
  'restore-migration-backup-3-to-4': [...mutation, 'backupPath', 'expectedSha256'],
  'preview-vacuum': [...mutation, ...vacuum],
  vacuum: [...mutation, ...vacuum, 'previewHash'],
  'resolve-maintenance-operation': [...mutation, ...session, 'pendingOperationId',
    'decision', 'processObservation', 'integrityEvidenceRefs'],
};

/** The core dispatcher uses this exact set before its ordinary board-opening branch. */
export const dataLifecycleOperations = new Set(Object.keys(fields));

/** Reject transport extensions without interpreting storage-owned authorization or retention rules. */
function allowedObject(value, allowed) {
  if (!value || typeof value !== 'object' || Array.isArray(value) ||
    Object.keys(value).some(key => !allowed.includes(key))) {
    throw new BoardError('INVALID_INPUT', 'Unknown or invalid lifecycle input field.');
  }
}

/** Validate flat JSON and nested field boundaries before policy checks or any board is opened. */
export function validateDataLifecycleInput(operation, input) {
  if (!dataLifecycleOperations.has(operation)) {
    throw new BoardError('UNKNOWN_OPERATION', 'Unknown data lifecycle operation.');
  }
  allowedObject(input, fields[operation]);
  // The core derives output policy paths before storage runs; reject missing paths here.
  if (['compress-backup', 'decompress-backup'].includes(operation) &&
    (typeof input.destination !== 'string' || !input.destination.trim())) {
    throw new BoardError('INVALID_INPUT', 'A nonempty destination path is required.');
  }
  if (typeof input.generation !== 'string' || !input.generation) {
    throw new BoardError('INVALID_INPUT', 'An explicit generation is required.');
  }
  if (input.classificationRefs !== undefined) {
    if (!Array.isArray(input.classificationRefs)) {
      throw new BoardError('INVALID_INPUT', 'Classification references must be an array.');
    }
    for (const row of input.classificationRefs) {
      allowedObject(row, ['taskId', 'decision', 'evidenceRefs', 'observedBoardRevision']);
    }
  }
  if (input.quiescence !== undefined) {
    allowedObject(input.quiescence, ['writersStopped', 'servicesStopped', 'evidenceRefs']);
  }
  if (input.processObservation !== undefined) {
    allowedObject(input.processObservation, ['pid', 'instanceId', 'stopped', 'evidenceRefs']);
  }
  // No nested caller digest may disappear through canonicalization or become hidden semantics.
  function rejectDigest(value) {
    if (!value || typeof value !== 'object') return;
    for (const [key, child] of Object.entries(value)) {
      if (['requestHash', 'leadTokenHash', 'maintenanceTokenHash'].includes(key)) {
        throw new BoardError('INVALID_INPUT', 'Caller-supplied digests are unsupported.');
      }
      rejectDigest(child);
    }
  }
  rejectDigest(input);
}

/** Return only new output files for the core's audit-only policy; recovery backup is a source. */
export function dataLifecycleDestinations(operation, input) {
  validateDataLifecycleInput(operation, input);
  return ['compress-backup', 'decompress-backup'].includes(operation) ? [input.destination] : [];
}

/** Translate credentials once and digest every normalized option, retaining lexical caller paths. */
function storageOptions(input, location, semanticDigest) {
  const { actorId, leadToken, generation, operationId, expectedBoardRevision,
    maintenanceToken, ...parameters } = input;
  const options = {
    ...parameters, ...(location ?? {}),
    request: { operationId, actorId, generation, expectedBoardRevision },
    leadId: actorId, leadTokenHash: tokenHash(leadToken),
  };
  if (maintenanceToken !== undefined) options.maintenanceTokenHash = tokenHash(maintenanceToken);
  options.requestHash = semanticDigest(options);
  return options;
}

/** Wrap non-receipted observations without upgrading them to durable business operations. */
function observation(operation, metadata, result) {
  return { schemaVersion: 1, operation, ok: true, boardId: metadata.boardId,
    generation: metadata.generation, boardRevision: metadata.boardRevision,
    eventSeq: metadata.eventSeq, result: { ...result, receiptCommitted: false } };
}

/** Detect a changed authorization/read boundary rather than returning a mixed-cursor preview. */
function sameCursor(before, after, expectedRevision) {
  if (['generation', 'boardRevision', 'eventSeq'].some(key => before[key] !== after[key]) ||
    expectedRevision !== after.boardRevision) {
    throw new BoardError('CONFLICT', 'The preview changed while reading; request a fresh preview.');
  }
}

/**
 * Execute one fixed facade, closing its own handle on success or failure.
 * verifyLead is the core's existing authorization callback and returns validated metadata.
 * Restoration is dispatched before opening any target; storage owns all mutation gates and receipts.
 */
export async function executeDataLifecycle(storage, location, operation, input, { verifyLead } = {}) {
  validateDataLifecycleInput(operation, input);
  // Help and retained service controls import this catalog without loading SQLite or storage.
  // Only actual data operations load the authoritative storage canonicalization implementation.
  const { semanticDigest } = await import('../storage/maintenance-protocol.mjs');
  if (operation === 'restore-migration-backup-2-to-3') {
    return storage.restoreMigrationBackup2To3(storageOptions(input, location, semanticDigest));
  }
  if (operation === 'restore-migration-backup-3-to-4') {
    return storage.restoreMigrationBackup3To4(storageOptions(input, location, semanticDigest));
  }
  const maintenance = ['preview-vacuum', 'vacuum', 'resolve-maintenance-operation']
    .includes(operation);
  const preview = ['preview-archive', 'preview-prune'].includes(operation);
  if (preview && typeof verifyLead !== 'function') {
    throw new BoardError('INVALID_INPUT', 'Preview authorization callback is required.');
  }
  const handle = maintenance ? storage.openMaintenanceBoard(location) :
    storage.openBoard({ ...location, readOnly: preview });
  try {
    if (preview) {
      const before = verifyLead(handle, input);
      const { actorId, leadToken, generation, ...parameters } = input;
      const result = operation === 'preview-archive' ? handle.previewArchive(parameters) :
        handle.previewPrune(parameters);
      const after = verifyLead(handle, input);
      sameCursor(before, after, result.expectedRevision);
      return observation(operation, after, result);
    }
    const options = storageOptions(input, undefined, semanticDigest);
    if (operation === 'archive') return handle.archive(options);
    if (operation === 'apply-prune') return handle.applyPrune(options);
    if (operation === 'vacuum') return await handle.vacuum(options);
    if (operation === 'resolve-maintenance-operation') {
      return await handle.resolveMaintenanceOperation(options);
    }
    if (operation === 'preview-vacuum') {
      const before = handle.status();
      const result = await handle.previewVacuum(options);
      const after = handle.status();
      sameCursor(before, after, result.plan.expectedRevision);
      return observation(operation, after, result);
    }
    const method = { checkpoint: 'checkpoint', 'compress-backup': 'compressBackup',
      'decompress-backup': 'decompressBackup' }[operation];
    const result = await handle[method](options);
    return observation(operation, handle.metadata(), result);
  } finally {
    handle.close();
  }
}
