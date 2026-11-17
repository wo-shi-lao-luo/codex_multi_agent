/** Explicit task selection preserves existing Board authority; it never amends old work. */
import fs from 'node:fs';
import path from 'node:path';
import { createHash, randomBytes } from 'node:crypto';
import { sessionLocation, normalizeSessionProfile } from '../domain/session.mjs';
import { inspectPath } from '../storage/paths.mjs';
import { callCli } from './transport.mjs';
import { requestIssues } from './request.mjs';
import { verifyRecoveryCredential } from './service-recovery.mjs';

const canonical = x => Array.isArray(x) ? x.map(canonical) : x && typeof x === 'object'
  ? Object.fromEntries(Object.keys(x).sort().map(k => [k, canonical(x[k])])) : x;
const withoutClaim = ({ claimToken, ...rest }) => JSON.stringify(canonical(rest));
const requestDigest = value => createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
const reject = code => { throw Object.assign(Error('Next task preparation requires reconciliation.'), { code }); };
/** Bounded no-link read of a caller-owned private handoff. */
function readPrivate(file, maximum=262144) {
  const fd=fs.openSync(inspectPath(file),fs.constants.O_RDONLY | (fs.constants.O_NOFOLLOW ?? 0));
  try {
    const stat=fs.fstatSync(fd);
    if (!stat.isFile() || stat.nlink !== 1 || stat.size > maximum) reject('NEXT_TASK_CONFLICT');
    const bytes=Buffer.alloc(maximum+1), size=fs.readSync(fd,bytes,0,bytes.length,0);
    if(size>maximum) reject('NEXT_TASK_CONFLICT');
    return JSON.parse(bytes.subarray(0,size).toString('utf8'));
  } finally { fs.closeSync(fd); }
}

/** The combined CLI consumes only the exact bounded handoff validated during preparation. */
export function readPreparedTask(file, expectedDigest) {
  const request=readPrivate(file);
  if(requestDigest(request)!==expectedDigest) reject('NEXT_TASK_CONFLICT');
  return request;
}

export async function prepareNextTask(projectRoot, retained) {
  try {
    const spec=retained.nextTask;
    const allowed=new Set(['executionApproved','task','phase','progress','nextCheckpoint']);
    if (!spec || typeof spec !== 'object' || Array.isArray(spec)
        || Object.keys(spec).some(k=>!allowed.has(k)) || spec.executionApproved !== true) reject('NEXT_TASK_INVALID');
    if (!spec.task?.id || spec.task.id === retained.task?.id) reject('NEW_TASK_ID_REQUIRED');
    const candidate={action:'activate',actorId:retained.actorId,sessionProfile:retained.sessionProfile,
      ...(retained.leadPrincipal ? {leadPrincipal:retained.leadPrincipal} : {}),
      leadToken:retained.leadToken,serviceControlToken:retained.serviceControlToken,
      claimToken:randomBytes(32).toString('hex'),...spec};
    const issues=requestIssues(candidate);
    if (issues.missingFields.length || issues.invalidFields.length) reject('NEXT_TASK_INVALID');
    const publicText=JSON.stringify(spec);
    if (['leadToken','serviceControlToken','claimToken'].some(k=>retained[k] && publicText.includes(retained[k]))) reject('CREDENTIAL_IN_PUBLIC_CONTEXT');
    const selected=sessionLocation(normalizeSessionProfile(retained.sessionProfile)), root=inspectPath(projectRoot);
    const directory=inspectPath(path.join(root,selected.boardPath));
    const observed=(await callCli(root,selected.boardPath,selected.sessionKey,'inspect',
      {actorId:retained.actorId,leadToken:retained.leadToken})).result;
    const journal=readPrivate(path.join(directory,'activation.json'),1048576);
    if(journal.root!==root || journal.actorId!==retained.actorId || journal.sessionKey!==selected.sessionKey
        || journal.generation!==observed.generation || journal.boardId!==observed.boardId) reject('ACTIVATION_CONTEXT_MISMATCH');
    verifyRecoveryCredential(journal,directory,retained,selected.sessionKey);
    const file=inspectPath(path.join(directory,`task-${createHash('sha256').update(spec.task.id).digest('hex')}.request.private.json`));
    const reuse=()=>{
      const existing=readPrivate(file);
      if(withoutClaim(existing)!==withoutClaim(candidate) || !/^[a-f0-9]{64}$/.test(existing.claimToken)) reject('NEXT_TASK_CONFLICT');
      // The exact prepared file is retryable; subsequent activation still checks its contract/grant.
      return {state:'prepared',...selected,requestPath:file,requestDigest:requestDigest(existing),taskId:spec.task.id,reused:true};
    };
    if(fs.existsSync(file)) return reuse();
    if(observed.tasks.some(t=>t.id===spec.task.id) || journal.tasks[spec.task.id]) reject('NEXT_TASK_ALREADY_EXISTS');
    const serialized=JSON.stringify(candidate);
    if(Buffer.byteLength(serialized)>262144)reject('NEXT_TASK_INVALID');
    try { fs.writeFileSync(file,serialized,{flag:'wx',mode:0o600}); }
    catch(e) { if(e.code==='EEXIST')return reuse();throw e; }
    return {state:'prepared',...selected,requestPath:file,requestDigest:requestDigest(candidate),taskId:spec.task.id,reused:false};
  } catch(error) {
    return {state:'activation-pending',taskExecution:'not-resumed',reasonCode:error.code??'NEXT_TASK_INVALID',
      nextStep:'Use an approved new task ID and the retained session authority. Preserve old requests/contracts; resume the exact prepared file after a successful preparation.'};
  }
}
