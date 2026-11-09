/** Explicit CLI maintenance adapter. Ordinary operations never fall back to old-schema access. */
import { BoardError } from '../domain/errors.mjs';
import { tokenHash } from '../coordination/service.mjs';

export const maintenanceOperations = new Set([
  'maintenance-status', 'diagnose', 'enter-maintenance', 'exit-maintenance', 'migrate',
]);

/** Translate caller-held credentials into the complete hash-only storage options contract. */
function mutationOptions(operation, input) {
  const allowed = ['operationId', 'actorId', 'leadToken', 'generation', 'expectedBoardRevision',
    'maintenanceId', 'maintenanceToken', 'quiescence'];
  if (operation === 'migrate') allowed.push('fromVersion', 'toVersion', 'backupPath');
  if (Object.keys(input).some(key => !allowed.includes(key))) {
    throw new BoardError('INVALID_INPUT', 'Unknown maintenance input field.');
  }
  const options = {
    request: { operationId: input.operationId, actorId: input.actorId,
      generation: input.generation, expectedBoardRevision: input.expectedBoardRevision },
    leadId: input.actorId, leadTokenHash: tokenHash(input.leadToken),
    maintenanceId: input.maintenanceId, maintenanceTokenHash: tokenHash(input.maintenanceToken),
    quiescence: input.quiescence,
  };
  if (operation === 'migrate') {
    const supportedStep = input.fromVersion === 2 && input.toVersion === 3 ||
      input.fromVersion === 3 && input.toVersion === 4;
    if (!supportedStep) {
      throw new BoardError('UNSUPPORTED_SCHEMA',
        'Only explicit schema 2 to 3 and schema 3 to 4 migrations are supported.');
    }
    Object.assign(options, { fromVersion: input.fromVersion, toVersion: input.toVersion,
      backupPath: input.backupPath });
  }
  return options;
}

/** Invoke only the fixed maintenance facade; returned credentials and receipt behavior stay storage-owned. */
export async function maintenanceCommand(storage, location, operation, input) {
  const handle = storage.openMaintenanceBoard(location);
  try {
    if (operation === 'maintenance-status' || operation === 'diagnose') {
      const allowed = operation === 'diagnose' ? ['level'] : [];
      if (Object.keys(input).some(key => !allowed.includes(key))) {
        throw new BoardError('INVALID_INPUT', 'Unknown diagnostic input field.');
      }
      const result = operation === 'maintenance-status' ? handle.status() :
        handle.diagnose({ level: input.level ?? 'quick' });
      // The protocol is v1; result.schemaVersion explicitly describes the inspected database format.
      return { schemaVersion: 1, operation, ok: true, boardId: result.boardId,
        generation: result.generation, boardRevision: result.boardRevision,
        eventSeq: result.eventSeq, result };
    }
    const options = mutationOptions(operation, input);
    // Reuse the exact storage canonicalization over normalized options, never a raw CLI input hash.
    const { semanticDigest } = await import('../storage/maintenance-protocol.mjs');
    options.requestHash = semanticDigest(options);
    if (operation === 'enter-maintenance') return handle.enter(options);
    if (operation === 'exit-maintenance') return handle.exit(options);
    if (operation === 'migrate') return await handle.migrate(options);
    throw new BoardError('UNKNOWN_OPERATION', 'Unknown maintenance operation.');
  } finally {
    handle.close();
  }
}
