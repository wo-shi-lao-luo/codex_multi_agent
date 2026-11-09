/** Owned real-CLI/SQLite preview for Lead browser inspection, with explicit transport faults only. */
import { mkdir, mkdtemp, rm, readFile, readdir, writeFile } from 'node:fs/promises';
import { resolve, join, relative } from 'node:path';
import { createHash } from 'node:crypto';
import { createInterface } from 'node:readline';
import { existsSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { invoke, secret } from './helpers.mjs';

const args = process.argv.slice(2);
if (args.length && (args.length !== 2 || args[0] !== '--runtime-root')) {
  throw new Error('Use only --runtime-root PATH');
}
const runtimeRoot = resolve(args[1] ?? 'packages/task-board');
const entrypoint = existsSync(join(runtimeRoot, 'cli.mjs')) ?
  join(runtimeRoot, 'cli.mjs') : join(runtimeRoot, 'src/cli/cli.mjs');
const parent = resolve('_work/task-board/test-fixtures');
await mkdir(parent, { recursive: true });
const project = await mkdtemp(join(parent, 'web-preview-'));
const boardPath = join(project, '_work', 'board');
const leadToken = secret();
let sequence = 0;
let generation;
let store;
let service;
let transportOutage = false;
let forceReset = false;
let cleaned = false;
const owners = new Map();
const children = [];

/** Record the exact runtime/source inputs; later commands report drift without relabeling evidence. */
async function hashes() {
  const result = {};
  async function walk(directory) {
    for (const item of await readdir(directory, { withFileTypes: true })) {
      const path = join(directory, item.name);
      if (item.isDirectory()) await walk(path);
      else result[relative(process.cwd(), path)] = createHash('sha256')
        .update(await readFile(path)).digest('hex');
    }
  }
  await walk(join(runtimeRoot, 'src'));
  await walk(join(runtimeRoot, 'web'));
  for (const name of ['package.json', 'cli.mjs', 'manifest.json']) {
    const path = join(runtimeRoot, name);
    if (existsSync(path)) result[relative(process.cwd(), path)] = createHash('sha256')
      .update(await readFile(path)).digest('hex');
  }
  return result;
}
const initialHashes = await hashes();
const evidencePath = join(project, 'preview-inputs.json');
await writeFile(evidencePath, JSON.stringify(initialHashes, null, 2));

/** Execute actual CLI mutations/reads; credentials remain only in this owned process and stdin. */
async function cli(operation, fields = {}) {
  const response = await invoke(project, boardPath, operation, {
    actorId: 'lead', leadToken, generation, ...(!operation.startsWith('preview-') ?
      { operationId: `web-preview-${++sequence}` } : {}), ...fields,
  }, { entrypoint });
  if (response.code !== 0 || !response.reply.ok) {
    throw new Error(`${operation}: ${JSON.stringify(response.reply.error)}`);
  }
  return response.reply;
}
const currentTask = async id => (await cli('show', { taskId: id })).result.task;

/** Seed authentic task transitions through the real authorization/grant lifecycle. */
async function addTask(id, state, title = id) {
  await cli('add', { task: { id, title, outcome: 'Preview evidence only',
    sourceRefs: [`fixture/work#${id}`], acceptanceRefs: [`fixture/accept#${id}`],
    eligibleRoles: ['backend'], scope: { read: [], write: [`src/${id}.mjs`] },
    resources: [], dependencies: [] } });
  if (state === 'planned') return;
  await cli('approve', { taskId: id, taskRevision: (await currentTask(id)).taskRevision });
  const workerId = `worker-${id}`;
  const workerToken = secret();
  await cli('register', { worker: { id: workerId, hostId: `preview-${id}`, role: 'backend',
    mode: 'direct', capabilities: ['write'], workerToken } });
  await cli('grant', { workerId, taskId: id,
    approvalRevision: (await currentTask(id)).approvalRevision });
  if (state === 'open') return;
  const claimToken = secret();
  const claimed = await cli('claim', { actorId: workerId, workerToken, claimToken,
    taskId: id, taskRevision: (await currentTask(id)).taskRevision });
  const owner = { actorId: workerId, workerToken, claimToken,
    assignmentId: claimed.result.assignment.id };
  owners.set(id, owner);
  if (state === 'canceled') {
    await cli('cancel', { taskId: id, taskRevision: (await currentTask(id)).taskRevision,
      reason: 'Canceled with owned cleanup pending' });
  } else if (state === 'blocked') {
    await cli('block', { ...owner, taskId: id,
      taskRevision: (await currentTask(id)).taskRevision,
      blocker: 'Awaiting fixture decision', phase: 'verification', progress: 'Blocked visibly' });
  } else if (['submitted', 'closed'].includes(state)) {
    await cli('submit', { ...owner, taskId: id,
      taskRevision: (await currentTask(id)).taskRevision,
      writesStopped: true, processStopped: true, inputRevision: `fixture-source-${id}`,
      evidenceRefs: [`fixture/tests#${id}`] });
    if (state === 'closed') {
      await cli('accept', { taskId: id, taskRevision: (await currentTask(id)).taskRevision,
        gatesSatisfied: true, evidenceRefs: [`fixture/review#${id}`] });
    }
  }
}

/** Create one dedicated visual fixture using only actual CLI lifecycle authority, never SQL patches. */
async function specialState(action) {
  const id = { approvalHold: 'approval-hold', invalidClosed: 'invalid-closed',
    archivalFixture: 'archival-fixture' }[action];
  await addTask(id, action === 'approvalHold' ? 'running' : 'closed', id);
  if (action === 'approvalHold') {
    const asked = await cli('ask', { ...owners.get(id), taskId: id,
      taskRevision: (await currentTask(id)).taskRevision, step: 'Approve fixture scope',
      question: 'May this owned preview proceed?', checkedRefs: ['fixture/scope#current'],
      impact: 'Approval required', blocking: true });
    const question = asked.result.question;
    await cli('answer', { questionId: question.id, questionRevision: question.questionRevision,
      answerRevision: question.answerRevision, answer: { text: 'Pending explicit approval',
        decision: 'needs-approval', evidenceRefs: ['fixture/decision#approval-pending'] } });
  }
  await cli('release', { taskId: id, taskRevision: (await currentTask(id)).taskRevision,
    writesStopped: true, processStopped: true });
  if (action === 'invalidClosed') {
    const task = await currentTask(id);
    await cli('amend', { taskId: id, taskRevision: task.taskRevision,
      expectedInputRevision: task.inputRevision, reason: 'Changed authoritative fixture source',
      patch: { sourceRefs: ['fixture/source#materially-revised'] } });
  } else if (action === 'archivalFixture') {
    const snapshot = await cli('inspect');
    const fields = { taskIds: [id], action: 'archive', classificationRefs: [{ taskId: id,
      decision: 'logical-archive-safe', observedBoardRevision: snapshot.boardRevision,
      evidenceRefs: ['fixture/classify#archive-visible-only'] }] };
    const preview = await cli('preview-archive', fields);
    await cli('archive', { ...fields, expectedBoardRevision: snapshot.boardRevision,
      previewHash: preview.result.previewHash, approvalRef: 'fixture/approval#archive' });
  }
  const inspected = await cli('inspect');
  return { task: inspected.result.tasks.find(task => task.id === id),
    questions: inspected.result.questions.filter(question => question.taskId === id) };
}
/** Close this owned listener/storage and remove only the checked preview directory. */
async function cleanup() {
  if (cleaned) return;
  cleaned = true;
  await service?.close();
  service = null;
  store?.close();
  store = null;
  for (const child of children) child.kill();
  if (project.startsWith(`${parent}\\web-preview-`) ||
      project.startsWith(`${parent}/web-preview-`)) {
    await rm(project, { recursive: true, force: true });
  } else throw new Error('Refusing cleanup outside owned preview prefix');
}

try {
  await mkdir(join(project, 'src'));
  generation = (await cli('initialize')).generation;
  for (const [id, state, title] of [
    ['planned', 'planned', '计划：来源待核对'],
    ['ready', 'open', '就绪：可领取的独立工作'],
    ['running', 'running', '<img src=x onerror="window.__taskTextExecuted=1"> javascript:alert(1) ' +
      '长标题与未经执行的任务文字 '.repeat(18)],
    ['blocked', 'blocked', '受阻：等待确认'],
    ['submitted', 'submitted', '已提交：等待审查'],
    ['closed', 'closed', '已验收：完成'],
    ['canceled', 'canceled', '已取消：清理占用仍待处理'],
  ]) await addTask(id, state, title);
  const { openBoard } = await import(pathToFileURL(join(runtimeRoot, 'src/storage/index.mjs')));
  const { serve } = await import(pathToFileURL(join(runtimeRoot, 'src/server/server.mjs')));
  store = openBoard({ projectRoot: project, boardPath });
  // Fault injection is at the real service read boundary, never page JavaScript or fake database data.
  service = await serve({
    snapshot() {
      if (transportOutage) throw new Error('Controlled preview read outage');
      return store.snapshot();
    },
    eventsAfter(...args) {
      if (transportOutage) throw new Error('Controlled preview event outage');
      if (forceReset) {
        forceReset = false;
        return { reset: true };
      }
      return store.eventsAfter(...args);
    },
  });
  const startupDrift = JSON.stringify(initialHashes) !== JSON.stringify(await hashes());
  console.log(JSON.stringify({ ready: true, url: service.url, ticketUrl: service.ticketUrl,
    project, boardPath, runtimeRoot, entrypoint, revision: store.metadata().boardRevision,
    evidencePath, startupDrift,
    transportFault: 'controlled wrapper only; not physical network outage' }));
  const lines = createInterface({ input: process.stdin });
  for await (const line of lines) {
    try {
      const command = JSON.parse(line);
      if (command.action === 'cleanup') {
        await cleanup();
        console.log(JSON.stringify({ cleaned: true }));
        lines.close();
        process.stdin.pause();
        break;
      }
      let result;
      if (['approvalHold', 'invalidClosed', 'archivalFixture'].includes(command.action)) {
        result = await specialState(command.action);
      } else if (command.action === 'transportOutage') transportOutage = command.on === true;
      else if (command.action === 'reset') forceReset = true;
      else if (command.action === 'update') {
        const id = command.taskId ?? 'running';
        if (!owners.has(id)) throw new Error('No preview-owned assignment');
        await cli('report', { ...owners.get(id), taskId: id,
          taskRevision: (await currentTask(id)).taskRevision,
          phase: command.phase ?? 'browser-verification',
          progress: command.progress ?? '真实 CLI 提交后的浏览器自动更新',
          nextCheckpoint: command.nextCheckpoint ?? 'Inspect rendered revision' });
      } else if (command.action === 'stop') {
        await service.close();
      } else if (command.action !== 'status') throw new Error('Unknown preview action');
      console.log(JSON.stringify({ action: command.action, transportOutage, runtimeRoot, entrypoint, result,
        revision: store.metadata().boardRevision, snapshot: command.action === 'status' ?
          (await cli('status')).result : undefined,
        sourceDrift: JSON.stringify(initialHashes) !== JSON.stringify(await hashes()) }));
    } catch (error) { console.log(JSON.stringify({ error: error.message })); }
  }
  await cleanup();
} catch (error) {
  await cleanup();
  console.error(JSON.stringify({ error: error.message }));
  process.exitCode = 1;
}
