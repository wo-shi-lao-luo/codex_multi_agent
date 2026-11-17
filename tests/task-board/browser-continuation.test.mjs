// User-visible continuation: explicit new task, task-independent reopen and honest CLI failure.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { prepareRequest } from '../../packages/task-board/src/activation/prepare.mjs';
import { prepareNextTask } from '../../packages/task-board/src/activation/next-task.mjs';
import { activate } from '../../packages/task-board/src/activation/orchestrator.mjs';
import { callCli } from '../../packages/task-board/src/activation/transport.mjs';
import { stopService } from '../../packages/task-board/src/server/control.mjs';
import { serve } from '../../packages/task-board/src/server/server.mjs';
import { sourcePath } from './helpers.mjs';

async function fixture(t) {
  const parent=sourcePath('_work/task-board/test-fixtures');fs.mkdirSync(parent,{recursive:true});
  const root=fs.mkdtempSync(path.join(parent,'continuation-'));
  const ceiling=process.env.GIT_CEILING_DIRECTORIES;process.env.GIT_CEILING_DIRECTORIES=parent;
  let service,request;
  t.after(async()=>{if(service)await stopService({...service,serviceControlToken:request.serviceControlToken});await new Promise(r=>setTimeout(r,80));fs.rmSync(root,{recursive:true,force:true,maxRetries:10,retryDelay:30});if(ceiling===undefined)delete process.env.GIT_CEILING_DIRECTORIES;else process.env.GIT_CEILING_DIRECTORIES=ceiling;});
  const p=prepareRequest(root,{action:'prepare-request',actorId:'lead',executionApproved:true,
    sessionProfile:{hostId:'fixture',mainSessionId:root,projectId:'project',projectName:'Project',sessionName:'Session'},
    task:{id:'old',title:'Old work',outcome:'Old result',sourceRefs:['fixture/old'],acceptanceRefs:['fixture/accept'],scope:{read:[],write:[]}}});
  assert.equal(p.state,'prepared',p.reasonCode);request=JSON.parse(fs.readFileSync(p.requestPath));
  const first=await activate(root,request);assert.equal(first.state,'enabled');service=first.service;
  const inspect=async()=>(await callCli(root,first.boardPath,first.sessionKey,'inspect',{actorId:request.actorId,leadToken:request.leadToken})).result;
  return {root,request,p,first,inspect};
}

// A new outcome gets a different file/claim while existing authority and all old state stay intact.
test('CONTINUATION.newTaskPreservesAuthorityAndRejectsConflict',async t=>{
  const f=await fixture(t),before=await f.inspect(),oldBytes=fs.readFileSync(f.p.requestPath);
  const nextTask={executionApproved:true,task:{...f.request.task,id:'new',title:'New work'}};
  const next=await prepareNextTask(f.root,{...f.request,nextTask});assert.equal(next.state,'prepared');
  const fresh=JSON.parse(fs.readFileSync(next.requestPath));assert.notEqual(next.requestPath,f.p.requestPath);
  assert.equal(fresh.leadToken,f.request.leadToken);assert.equal(fresh.serviceControlToken,f.request.serviceControlToken);assert.notEqual(fresh.claimToken,f.request.claimToken);
  assert.deepEqual(fs.readFileSync(f.p.requestPath),oldBytes);assert.deepEqual(await f.inspect(),before);
  assert.equal((await prepareNextTask(f.root,{...f.request,nextTask})).requestPath,next.requestPath);
  assert.deepEqual(JSON.parse(fs.readFileSync(next.requestPath)),fresh);
  assert.equal((await prepareNextTask(f.root,{...f.request,nextTask:{...nextTask,task:{...nextTask.task,title:'Different'}}})).reasonCode,'NEXT_TASK_CONFLICT');
  assert.equal((await prepareNextTask(f.root,{...f.request,nextTask:{executionApproved:true,task:f.request.task}})).reasonCode,'NEW_TASK_ID_REQUIRED');
  assert.equal((await prepareNextTask(f.root,{...f.request,leadToken:'a'.repeat(64),nextTask})).state,'activation-pending');
  assert.equal((await prepareNextTask(f.root,{...f.request,nextTask:{...nextTask,leadToken:'a'.repeat(64)}})).reasonCode,'NEXT_TASK_INVALID');
  assert.equal((await activate(f.root,fresh)).state,'enabled');assert.equal((await f.inspect()).tasks.length,2);
});

// A stale execution contract cannot block explicit read-only display recovery or mutate task state.
test('CONTINUATION.reopenIgnoresStaleTaskAndBindsAttempt',async t=>{
  const f=await fixture(t),before=await f.inspect();
  const stale={...f.request,task:{...f.request.task,title:'Changed'}};
  assert.equal((await activate(f.root,stale)).reasonCode,'TASK_CONTRACT_CHANGED');
  const input={action:'reopen-service',actorId:f.request.actorId,sessionProfile:f.request.sessionProfile,
    leadToken:f.request.leadToken,serviceControlToken:f.request.serviceControlToken,
    servicePresentation:{expectedServiceId:f.first.service.serviceId,evidenceRefs:['fixture/expired-entry']}};
  const a=await activate(f.root,input);assert.equal(a.state,'enabled');assert.equal(a.activationScope,'presentation-only');assert.equal(a.taskExecution,'not-resumed');
  const bootstrap=await fetch(a.presentation.url,{redirect:'manual'});assert.equal(bootstrap.status,303);await bootstrap.text();
  const b=await activate(f.root,input);assert.notEqual(a.presentation.attemptId,b.presentation.attemptId);
  const oldResult=await activate(f.root,{...f.request,action:'record-open-result',presentationOutcome:'queued',presentationAttemptId:a.presentation.attemptId});assert.equal(oldResult.reasonCode,'PRESENTATION_CONFLICT');
  const current=await activate(f.root,{...f.request,action:'record-open-result',presentationOutcome:'queued',presentationAttemptId:b.presentation.attemptId});assert.equal(current.state,'enabled');
  assert.deepEqual(await f.inspect(),before);
});

// Structured pending is a nonzero process result; an automation must not treat it as execution approval.
test('CONTINUATION.pendingCLIExitsTwo',()=>{
  const r=spawnSync(process.execPath,[sourcePath('packages/task-board/src/cli/activation.mjs'),'--project-root',process.cwd(),'--stdin'],{input:'{}',encoding:'utf8'});
  assert.equal(r.status,2);const reply=JSON.parse(r.stdout);assert.equal(reply.result.state,'activation-pending');assert.equal(reply.result.taskExecution,'not-resumed');
});

// Expiration/replay still deny bootstrap; a fresh authenticated open is the recovery,
// not a longer TTL or an anonymous endpoint capable of reviving an old ticket.
test('CONTINUATION.delayedTicketExpiresAndFreshOpenRecovers',async t=>{
  const board={snapshot:()=>({board:{boardId:'fixture',generation:'g'}})};
  const token='cd'.repeat(32),server=await serve(board,{serviceControlToken:token});
  t.after(()=>server.close());
  const now=Date.now();t.mock.method(Date,'now',()=>now+120001);
  const expired=await fetch(server.ticketUrl,{redirect:'manual'});assert.equal(expired.status,401);await expired.text();
  const { serviceOpen }=await import('../../packages/task-board/src/server/control.mjs');
  const fresh=await serviceOpen({...server,serviceControlToken:token});
  const opened=await fetch(fresh.ticketUrl,{redirect:'manual'});assert.equal(opened.status,303);await opened.text();
  const replay=await fetch(fresh.ticketUrl,{redirect:'manual'});assert.equal(replay.status,401);await replay.text();
});
