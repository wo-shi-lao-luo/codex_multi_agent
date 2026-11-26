/** Exercise card interactions and real SQLite/HTTP boundaries using disposable Board fixtures. */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { createContext, runInContext } from 'node:vm';
import { randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { initializeBoard, openBoard } from '../../packages/task-board/src/storage/index.mjs';
import { sessionLocation } from '../../packages/task-board/src/domain/session.mjs';
import { hash } from '../../packages/task-board/src/coordination/service.mjs';
import { startDashboard } from '../../packages/task-board/src/server/dashboard.mjs';
import { invoke, secret, sourcePath } from './helpers.mjs';

const viewHeader = 'x-task-board-view';

async function dashboardClient(sessions, preferences = new Map()) {
  const elements = new Map();
  const element = tag => ({ tag, children: [], dataset: {}, attributes: {}, listeners: {}, open: false,
    classList: { add() {} },
    addEventListener(name, callback) { this.listeners[name] = callback; },
    setAttribute(name, value) { this.attributes[name] = value; },
    replaceChildren(...items) { this.children = items; },
    append(...items) { this.children.push(...items); },
    showModal() { this.open = true; },
    close() { this.open = false; this.listeners.close?.(); },
    focus() { this.focused = true; },
    querySelectorAll(selector) {
      const dataKey = selector === '[data-reference-id]' ? 'referenceId' : 'taskId';
      return this.children.flatMap(child =>
        child.dataset?.[dataKey] ? [child] : child.querySelectorAll(selector));
    },
  });
  const context = createContext({
    document: { createElement: element, getElementById(id) {
      if (!elements.has(id)) elements.set(id, element(id));
      return elements.get(id);
    } },
    window: { location: { hash: '' }, localStorage: {
      getItem: key => preferences.get(key) ?? null,
      setItem: (key, value) => preferences.set(key, value),
    } },
    AbortController, AbortSignal, URLSearchParams,
    setTimeout: () => 1, clearTimeout() {},
    fetch: async url => {
      if (url === '/api/view') return { ok: true, headers: { get: () => 'fixture-capability' } };
      if (url === '/api/sessions') return { ok: true, json: async () => ({ sessions, unavailable: 0 }) };
      if (url.startsWith('/api/snapshot?')) return { ok: true, json: async () => ({ tasks: [] }) };
      return new Promise(() => {});
    },
  });
  runInContext(fs.readFileSync(sourcePath('packages/task-board/web/dashboard.js'), 'utf8'), context);
  await new Promise(resolve => setImmediate(resolve));
  return { elements, context };
}

function sessionButtons(project) {
  return project.children[1].children.map(row => row.children[0]);
}

function renderedText(element) {
  return [element.textContent, ...element.children.map(renderedText)].filter(Boolean).join('\n');
}

function findRendered(element, predicate) {
  if (predicate(element)) return element;
  for (const child of element.children) {
    const found = findRendered(child, predicate);
    if (found) return found;
  }
}

test('dashboard sidebar groups by project identity even if names differ or collide', async () => {
  const { elements } = await dashboardClient([
    { id: 'a', projectKey: 'one', projectName: 'Kit', sessionName: 'First session' },
    { id: 'b', projectKey: 'one', projectName: 'old_kit_label', sessionName: 'Earlier session' },
    { id: 'c', projectKey: 'two', projectName: 'Kit', sessionName: 'Other project session' },
  ]);
  const groups = elements.get('session-list').children;
  assert.deepEqual(groups.map(project => sessionButtons(project).map(button => button.dataset.sessionId)),
    [['a', 'b'], ['c']]);
});

test('dashboard restores its last session and can group by real activity without changing selection', async () => {
  const sessions = [
    { id: 'a', projectKey: 'one', projectName: 'Kit', sessionName: 'Active session', hasRunningTasks: true },
    { id: 'b', projectKey: 'one', projectName: 'Kit', sessionName: 'Saved session', hasRunningTasks: false },
  ];
  const preferences = new Map([['task-board:last-session', 'b']]);
  const { elements, context } = await dashboardClient(sessions, preferences);
  assert.equal(elements.get('work-title').textContent, 'Saved session');
  const [active, idle] = sessionButtons(elements.get('session-list').children[0]);
  assert.equal(active.children[1].textContent, '进行中');
  assert.equal(idle.children.length, 1);
  assert.equal(idle.attributes['aria-current'], 'true');
  const toggle = elements.get('group-mode');
  toggle.listeners.click();
  assert.equal(toggle.attributes['aria-pressed'], 'true');
  const groups = elements.get('session-list').children;
  assert.deepEqual(groups.map(group => group.children[0].textContent), ['进行中', '无进行中任务']);
  assert.equal(sessionButtons(groups[1].children[1])[0].attributes['aria-current'], 'true');
  sessionButtons(groups[0].children[1])[0].listeners.click();
  assert.equal(preferences.get('task-board:last-session'), 'a');

  const reloaded = await dashboardClient(sessions, preferences);
  assert.equal(reloaded.elements.get('work-title').textContent, 'Active session');
  assert.equal(reloaded.elements.get('group-mode').attributes['aria-pressed'], 'true');
  reloaded.elements.get('group-mode').listeners.click();
  assert.equal(reloaded.elements.get('group-mode').attributes['aria-pressed'], 'false');
  assert.deepEqual(sessionButtons(reloaded.elements.get('session-list').children[0])
    .map(button => button.dataset.sessionId), ['a', 'b']);
  runInContext('renderCatalog([]);', context);
  assert.equal(preferences.get('task-board:last-session'), 'a', 'Temporary absence keeps the saved session.');
});

test('dashboard puts abandoned tasks in their own column and preserves precise task states', async () => {
  const { elements, context } = await dashboardClient([]);
  const board = elements.get('tasks');
  runInContext('renderTasks([]);', context);
  assert.deepEqual(board.children.map(column => column.children[0].children[0].textContent),
    ['待开始', '进行中', '需要人工确认', '已结束', '已放弃']);
  assert.ok(board.children.every(column => column.children[1].tag === 'p'));

  context.sampleTasks = ['planned', 'open', 'ready', 'running', 'blocked', 'submitted', 'closed', 'canceled']
    .map(state => state === 'canceled'
      ? { id: state, state, title: state, cancellationReason: 'The approved scope was superseded.', cleanupPending: true,
          progress: 'Past work', nextCheckpoint: 'Obsolete checkpoint' }
      : { id: state, state, title: state });
  context.sampleTasks.unshift({ state: 'blocked', title: 'legacy-manual', id: 'legacy-manual',
    manualConfirmation: { state: 'waiting-for-submission' } });
  runInContext('renderTasks(sampleTasks);', context);
  const cards = board.children.map(column => column.children[1].children);
  assert.deepEqual(cards.map(column => column.map(card => card.children[0].children[0].children[0].textContent)),
    [['planned', 'open', 'ready'], ['running', 'blocked', 'submitted'], ['legacy-manual'], ['closed'], ['canceled']]);
  assert.deepEqual(cards[1].map(card => card.children[0].children[1].textContent),
    ['进行中', '阻塞', '待核验']);
  assert.equal(cards[2][0].children[0].children[1].textContent, '待人工确认');
  assert.equal(cards[2][0].draggable, undefined);
  assert.equal(cards[4][0].children[0].children[1].textContent, '已放弃');
  const abandoned = cards[4][0].children.map(child => child.textContent);
  assert.ok(abandoned.some(text => text?.includes('The approved scope was superseded.')));
  assert.ok(abandoned.some(text => text?.includes('资源待安全收尾')));
  assert.ok(!abandoned.some(text => text?.includes('Obsolete checkpoint')));
  runInContext('renderTaskDetail(sampleTasks.at(-1));', context);
  const detail = elements.get('task-detail-content').children;
  const history = detail.find(section => section.children[0].textContent === '历史进展');
  assert.ok(history.children.some(item => item.textContent === '放弃前的检查点：Obsolete checkpoint'));
});

test('dashboard keeps running work at the top and submissions last in the active column', async () => {
  const { elements, context } = await dashboardClient([]);
  context.sampleTasks = [
    ['verify-new', 'submitted'], ['run-new', 'running'], ['blocked', 'blocked'],
    ['verify-old', 'submitted'], ['run-old', 'running'],
  ].map(([id, state]) => ({ id, title: id, state }));
  runInContext('renderTasks(sampleTasks);', context);
  // Interleaving states in the input must not move submissions above current work.
  const active = elements.get('tasks').children[1].children[1].children;
  assert.deepEqual(active.map(card => card.children[0].children[0].children[0].textContent),
    ['run-new', 'run-old', 'blocked', 'verify-new', 'verify-old']);
});

test('dashboard cards restore execution context and expose the detailed evidence on demand', async () => {
  const { elements, context } = await dashboardClient([
    { id: 's', projectKey: 'p', projectName: 'Kit', sessionName: 'Development' },
  ]);
  const task = { id: 'rich-task', state: 'running', title: 'Build the card', progress: 'Snapshot ready',
    eligibleRoles: ['team-backend-engineer'], nextCheckpoint: 'Verify the endpoint',
    dependencyCount: 1, pendingQuestionCount: 1,
    responsibility: { kind: 'executor', person: { id: 'worker', role: 'team-backend-engineer' } },
    details: { outcome: 'Restore the old evidence.\n\nVerify that the saved result can be reopened.',
      sourceRefs: ['fixture/source'],
      acceptanceRefs: ['fixture/acceptance'], dependencies: [{ title: 'Prepare setup', gate: 'accepted-result' }],
      questions: [{ status: 'answered', question: 'Proceed?', answers: [{ text: 'Yes' }] }] } };
  context.fixtureTask = task;
  runInContext('renderTasks([fixtureTask]);', context);
  const card = elements.get('tasks').children[1].children[1].children[0];
  const title = card.children[0].children[0].children[0];
  const rendered = card.children.map(child => child.textContent);
  assert.ok(rendered.includes('可承接：后端工程师'));
  assert.ok(rendered.includes('执行者：后端工程师'));
  assert.ok(rendered.includes('下一检查点：Verify the endpoint'));
  assert.ok(rendered.some(line => line?.includes('待处理问询 1')));
  card.listeners.click();
  const dialog = elements.get('task-detail');
  assert.equal(dialog.open, true);
  assert.equal(elements.get('task-detail-title').textContent, task.title);
  const sections = elements.get('task-detail-content').children;
  const description = sections.find(section => section.children[0].textContent === '任务说明');
  const progress = sections.find(section => section.children[0].textContent === '执行进展');
  assert.equal(description.children[1].textContent, task.details.outcome);
  assert.equal(progress.children[1].textContent, task.progress);
  const detailText = sections.flatMap(section => section.children.map(child => child.textContent)).join('\n');
  for (const text of ['Restore the old evidence', 'fixture/source', 'fixture/acceptance', 'Prepare setup', '答复：Yes']) {
    assert.ok(detailText.includes(text), `Missing detail: ${text}`);
  }
  dialog.close();
  assert.equal(title.focused, true, 'Closing details restores the card button focus.');

  title.listeners.click();
  runInContext('renderTasks([]);', context);
  assert.equal(dialog.open, false, 'Removing a task closes its details.');
  const heading = elements.get('work-title');
  assert.equal(heading.focused, true, 'Removing the trigger moves focus to the workspace heading.');

  heading.focused = false;
  runInContext('renderTasks([fixtureTask]); showTaskDetail(fixtureTask); renderCatalog([]);', context);
  assert.equal(dialog.open, false, 'Removing a session closes its task details.');
  assert.equal(heading.focused, true, 'Removing the session moves focus to the workspace heading.');
});

test('manual cards show what to do and expect without exposing recorded executor IDs', async () => {
  // Without opening task details, a human can read the setup, action and passing condition.
  // Role names remain visible in the card and the historical rows, while native IDs stay private.
  const { elements, context } = await dashboardClient([
    { id: 'guide-session', projectKey: 'p', projectName: 'Kit', sessionName: 'Fixture' },
  ]);
  const executor = { id: 'technical-executor-fixture', role: 'team-backend-engineer' };
  const submitter = { id: 'technical-submitter-fixture', role: 'team-tester' };
  const guide = {
    setup: 'Use the prepared sample account.',
    steps: [{
      action: 'Open the saved order.',
      expected: 'The original delivery date appears.',
    }],
  };
  context.fixtureTasks = [{
    id: 'guide', title: 'Review order', state: 'submitted',
    manualConfirmation: { state: 'ready', taskRevision: 3, generation: 'fixture', guide },
    responsibility: { kind: 'submitter', person: submitter },
    details: {
      executionHistory: [{ person: executor, active: false }],
      submissions: [{ kind: 'current', person: submitter }],
    },
  }, {
    id: 'legacy-guide', title: 'Old request', state: 'submitted',
    manualConfirmation: { state: 'ready', taskRevision: 3, generation: 'fixture' },
  }];
  runInContext('renderTasks(fixtureTasks);', context);
  const [card, legacy] = elements.get('tasks').children[2].children[1].children;
  assert.equal(elements.get('task-detail').open, false);
  for (const text of [guide.setup, guide.steps[0].action, guide.steps[0].expected]) {
    assert.ok(renderedText(card).includes(text), `Missing inline guidance: ${text}`);
  }
  assert.match(renderedText(legacy), /(?:未|没有).{0,24}(?:步骤|说明)/);
  assert.doesNotMatch(renderedText(card), /technical-(?:executor|submitter)-fixture/);

  card.listeners.click();
  const detail = renderedText(elements.get('task-detail-content'));
  assert.match(detail, /后端工程师/);
  assert.match(detail, /测试/);
  assert.doesNotMatch(detail, /technical-(?:executor|submitter)-fixture/);
});

test('a visible reference opens its content in the existing card on demand', async () => {
  // Opening a card fetches nothing. Clicking an eligible label requests the exact Board reference.
  // The text is rendered in the card dialog, and an ineligible reference remains a label.
  const { elements, context } = await dashboardClient([
    { id: 'preview-session', projectKey: 'p', projectName: 'Kit', sessionName: 'Fixture' },
  ]);
  const referenceId = 'c'.repeat(64);
  const requests = [];
  let releaseLateResponse;
  context.fetch = async (url, options) => {
    if (!url.startsWith('/api/reference?')) return new Promise(() => {});
    requests.push({ query: new URL(url, 'http://127.0.0.1').searchParams, signal: options.signal });
    if (requests.length > 1) {
      await new Promise(resolve => { releaseLateResponse = resolve; });
      return { ok: true, json: async () => ({ format: 'text', content: 'Late fixture content' }) };
    }
    return { ok: true, json: async () => ({
      format: 'markdown', content: '# Evidence preview fixture\n\n<img src="not-rendered">',
    }) };
  };
  context.fixtureTask = {
    id: 'preview-card', title: 'Verify delivery', state: 'open',
    details: {
      sourceRefs: ['docs/review.md', 'Operation receipt'],
      referencePreviews: { sourceRefs: [referenceId, null] },
    },
  };
  runInContext('renderTasks([fixtureTask]); showTaskDetail(fixtureTask);', context);
  const content = elements.get('task-detail-content');
  const isButton = (item, text) => item.tag === 'button' && renderedText(item).includes(text);
  const trigger = findRendered(content, item => isButton(item, 'docs/review.md'));
  assert.ok(trigger, 'The safe file reference is actionable.');
  assert.equal(findRendered(content, item => isButton(item, 'Operation receipt')), undefined);
  assert.equal(requests.length, 0);
  const dialog = elements.get('task-detail');
  dialog.scrollTop = 72;
  trigger.listeners.click();
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(requests.map(({ query }) => Object.fromEntries(query)), [
    { session: 'preview-session', task: 'preview-card', ref: referenceId },
  ]);
  const preview = elements.get('reference-preview');
  const previewContent = elements.get('reference-content');
  assert.equal(dialog.open, true);
  assert.equal(preview.hidden, false);
  assert.match(renderedText(previewContent), /Evidence preview fixture/);
  assert.equal(findRendered(previewContent, item => item.tag === 'img'), undefined);
  elements.get('reference-back').listeners.click();
  assert.equal(preview.hidden, true);
  assert.equal(dialog.scrollTop, 72);
  assert.equal(trigger.focused, true);

  // A response finishing after the reader has left the pane cannot repopulate it.
  trigger.listeners.click();
  await new Promise(resolve => setImmediate(resolve));
  elements.get('reference-back').listeners.click();
  assert.equal(requests[1].signal.aborted, true);
  releaseLateResponse();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(preview.hidden, true);
  assert.doesNotMatch(renderedText(previewContent), /Late fixture content/);
});

test('dashboard detail button and internal drag confirm the same scoped result', async () => {
  // Exercise both UI gestures and verify that only a server snapshot moves the card.
  const { elements, context } = await dashboardClient([
    { id: 's', projectKey: 'p', projectName: 'Kit', sessionName: 'Development' },
  ]);
  const request = { state: 'ready', taskRevision: 4, generation: 'fixture-generation' };
  const makeTask = id => ({ id, title: id, state: 'submitted', manualConfirmation: request });
  const requests = [];
  let snapshot = [makeTask('button'), makeTask('drag')];
  let releaseResponse;
  const failures = [503, 409];
  context.fetch = async (url, options) => {
    if (url.startsWith('/api/snapshot?')) return { ok: true, json: async () => ({ tasks: snapshot }) };
    if (url === '/api/manual-confirmation?session=s' && options.method === 'POST') {
      const body = JSON.parse(options.body);
      requests.push(body);
      await new Promise(resolve => { releaseResponse = resolve; });
      const status = failures.shift();
      if (status) return { ok: false, status, json: async () => ({ error: 'CONFIRMATION_ARTIFACT_PROTECTION' }) };
      snapshot = snapshot.map(task => task.id === body.taskId
        ? { ...task, state: 'closed', manualConfirmation: null } : task);
      return { ok: true, json: async () => ({ ok: true }) };
    }
    return new Promise(() => {});
  };
  context.fixtureTasks = snapshot;
  runInContext('renderTasks(fixtureTasks);', context);
  const tasks = elements.get('tasks');
  const [first] = tasks.children[2].children[1].children;
  first.listeners.click();
  const button = elements.get('task-confirm-complete');
  assert.equal(button.hidden, false);
  for (const message of ['写入保护未满足', '暂不能确认']) {
    button.listeners.click();
    await new Promise(resolve => setImmediate(resolve));
    releaseResponse();
    await new Promise(resolve => setImmediate(resolve));
    assert.ok(elements.get('task-confirmation-message').textContent.includes(message));
    assert.equal(button.disabled, false, 'A declined request can be retried while its snapshot is still current.');
  }
  button.listeners.click();
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(requests, Array.from({ length: 3 }, () =>
    ({ taskId: 'button', taskRevision: 4, generation: request.generation })));
  assert.equal(tasks.children[2].children[1].children.length, 2, 'No optimistic move.');
  releaseResponse();
  await new Promise(resolve => setImmediate(resolve));
  elements.get('task-detail').close();

  const [drag] = tasks.children[2].children[1].children;
  const target = tasks.children[3];
  const dataTransfer = { types: [], setData(type) { this.types.push(type); } };
  const event = { dataTransfer, preventDefault() {} };
  target.listeners.drop(event);
  assert.equal(requests.length, 3, 'A drop from outside this dashboard cannot confirm.');
  assert.equal(drag.draggable, true);
  drag.listeners.dragstart(event);
  target.listeners.drop(event);
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(requests[3], { taskId: 'drag', taskRevision: 4, generation: request.generation });
  releaseResponse();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(tasks.children[3].children[1].children.length, 2);
});

test('only an explicit, current manual confirmation request can close through the dashboard', async t => {
  // Use the same writer CLI, actual SQLite receipts and same-origin browser boundary as production.
  const parent = sourcePath('_work/task-board/test-fixtures');
  fs.mkdirSync(parent, { recursive: true });
  const root = fs.mkdtempSync(path.join(parent, 'manual-confirmation-'));
  let viewer;
  t.after(async () => {
    await viewer?.close();
    if (path.dirname(root) !== parent || !path.basename(root).startsWith('manual-confirmation-')) {
      throw Error('Unexpected fixture cleanup path.');
    }
    fs.rmSync(root, { recursive: true, force: true });
  });
  execFileSync('git', ['init', '-q', root]);
  fs.writeFileSync(path.join(root, '.gitignore'), '/_work/task-board/\n');
  const board = session(root, 'Fixture project', 'Manual confirmation');
  await addTask(board, 'manual', { eligibleRoles: ['lead'], allowLeadInline: true,
    resources: [{ kind: 'resource', key: 'fixture-editor', mode: 'exclusive' }] });
  const assignment = await assignTask(board, 'manual');
  const submitted = await boardCommand(board, 'lead-inline-report', {
    taskId: 'manual', taskRevision: assignment.task.taskRevision,
    assignmentId: assignment.assignment.id, claimToken: assignment.claimToken,
    action: 'submit', inputRevision: 'fixture:tested-result', writesStopped: true, processStopped: true,
    evidenceRefs: ['fixture/artifact'],
  });
  const legacy = session(root, 'Fixture project', 'Legacy manual wait');
  await addTask(legacy, 'manual', { eligibleRoles: ['lead'], allowLeadInline: true });
  const waiting = await assignTask(legacy, 'manual');
  await boardCommand(legacy, 'lead-inline-report', {
    taskId: 'manual', taskRevision: waiting.task.taskRevision,
    assignmentId: waiting.assignment.id, claimToken: waiting.claimToken,
    action: 'report', phase: 'awaiting-manual-acceptance', progress: 'Legacy record only',
  });
  viewer = await startDashboard({ projectRoots: [root], port: 0 });
  const { url } = viewer;
  const { headers } = await openView(url);
  const response = await fetch(url + '/api/sessions', { headers });
  const { sessions } = await response.json();
  const target = sessions.find(item => item.sessionName === 'Manual confirmation');
  const priorSession = sessions.find(item => item.sessionName === 'Legacy manual wait');
  assert.equal(priorSession.hasRunningTasks, false);
  const snapshot = async (sessionId = target.id) => {
    const reply = await fetch(`${url}/api/snapshot?session=${sessionId}`, { headers });
    assert.equal(reply.status, 200);
    return reply.json();
  };
  const submit = (payload, overrides = {}, sessionId = target.id) => fetch(`${url}/api/manual-confirmation?session=${sessionId}`, {
    method: 'POST', headers: { ...headers, Origin: url, 'Sec-Fetch-Site': 'same-origin',
      'Content-Type': 'application/json', ...overrides }, body: JSON.stringify(payload),
  });
  const initial = { taskId: 'manual', taskRevision: submitted.result.task.taskRevision,
    generation: board.generation };
  assert.equal((await snapshot(priorSession.id)).tasks[0].manualConfirmation.state,
    'waiting-for-submission');
  assert.notEqual((await submit(initial)).status, 200, 'Ordinary technical submissions cannot be closed here.');
  // An empty expectation cannot describe a pass, and rejection leaves the submission unprepared.
  const invalid = await invoke(board.projectRoot, board.boardPath, 'request-manual-acceptance', {
    ...initial, actorId: 'lead', leadToken: board.leadToken, operationId: randomUUID(),
    evidenceRefs: ['fixture/technical-verification'],
    guide: { steps: [{ action: 'Open the saved order.', expected: ' ' }] },
  }, { sessionKey: board.sessionKey });
  assert.notEqual(invalid.code, 0);
  assert.equal((await snapshot()).tasks[0].manualConfirmation, null);

  const guide = { setup: 'Use the sample account.', steps: [{
    action: 'Open the saved order.',
    expected: 'The delivery date matches the prepared order.',
  }] };
  await boardCommand(board, 'request-manual-acceptance', {
    taskId: 'manual', taskRevision: initial.taskRevision, evidenceRefs: ['fixture/technical-verification'],
    guide,
  });
  const pending = await snapshot();
  const { manualConfirmation } = pending.tasks[0];
  assert.equal(manualConfirmation.state, 'ready');
  assert.deepEqual(manualConfirmation.guide, guide);
  const exact = { taskId: 'manual', taskRevision: manualConfirmation.taskRevision,
    generation: manualConfirmation.generation };
  assert.notEqual((await submit(exact, { Origin: 'http://127.0.0.1:1' })).status, 200);
  assert.notEqual((await submit(exact, { [viewHeader]: '' })).status, 200);
  assert.notEqual((await submit(exact, { 'Sec-Fetch-Site': 'same-site' })).status, 200);
  assert.notEqual((await submit(exact, {}, 'a'.repeat(64))).status, 200);
  assert.equal((await submit(exact, {}, priorSession.id)).status, 409);
  assert.equal((await submit({ ...exact, taskId: 'a'.repeat(4097) })).status, 400);
  assert.notEqual((await submit({ ...exact, evidenceRefs: ['browser/forgery'] })).status, 200);
  assert.equal((await submit(initial)).status, 409, 'A previous task revision cannot confirm the new request.');
  const bypass = await invoke(board.projectRoot, board.boardPath, 'accept', {
    ...exact, actorId: 'lead', leadToken: board.leadToken, operationId: randomUUID(),
    gatesSatisfied: true, evidenceRefs: ['fixture/not-a-human-confirmation'],
  }, { sessionKey: board.sessionKey });
  assert.notEqual(bypass.code, 0, 'A prepared manual gate cannot be bypassed by ordinary accept.');
  const ignore = path.join(root, '.gitignore');
  fs.writeFileSync(ignore, '# Board policy temporarily unavailable in this fixture.\n');
  try {
    const missingProtection = await submit(exact);
    assert.equal(missingProtection.status, 503);
    assert.deepEqual(await missingProtection.json(), { error: 'CONFIRMATION_ARTIFACT_PROTECTION' });
  } finally {
    fs.writeFileSync(ignore, '/_work/task-board/\n');
  }
  assert.equal((await snapshot()).revision, pending.revision, 'Denied attempts cannot advance the Board.');
  const stream = await subscribe(url, target.id, headers, t);
  assert.equal(await stream.next(), pending.revision);
  const confirmations = await Promise.all([submit(exact), submit(exact)]);
  for (const confirmed of confirmations) {
    assert.equal(confirmed.status, 200);
    assert.deepEqual(await confirmed.json(), { ok: true });
  }
  assert.notEqual(await stream.next(), pending.revision);
  const complete = await snapshot();
  assert.equal(complete.tasks[0].state, 'closed');
  assert.equal(complete.tasks[0].manualConfirmed, true);
  assert.equal(complete.tasks[0].responsibility.person.id, 'lead');
  // Historical attribution still includes the original worker for authenticated CLI callers.
  const cliView = await boardCommand(board, 'show', { taskId: 'manual' });
  assert.equal(cliView.result.submissions[0].actualExecutor.workerId, 'lead');
  const stored = openBoard({ ...board, readOnly: true });
  try {
    assert.equal(stored.snapshot().reservations.filter(record => record.active).length, 1,
      'Manual confirmation does not release recorded ownership.');
  } finally { stored.close(); }
  assert.equal((await submit(exact)).status, 200, 'An exact retry returns the committed confirmation.');
  assert.equal((await snapshot()).revision, complete.revision, 'An exact retry does not write again.');
});

test('dashboard previews only references bound to the selected visible task', async t => {
  // Read a listed Markdown document and a JSON evidence summary using actual viewer credentials.
  // Changing the task, losing credentials, or asking for a filesystem path cannot read content.
  const parent = sourcePath('_work/test-fixtures');
  fs.mkdirSync(parent, { recursive: true });
  const root = fs.mkdtempSync(path.join(parent, 'preview-'));
  let viewer;
  t.after(async () => {
    await viewer?.close();
    if (path.dirname(root) !== parent || !path.basename(root).startsWith('preview-')) {
      throw Error('Unexpected fixture cleanup path.');
    }
    fs.rmSync(root, { recursive: true, force: true });
  });
  const project = path.join(root, 'project');
  const linked = path.join(root, 'linked');
  fs.mkdirSync(project);
  execFileSync('git', ['init', '-q', project]);
  fs.writeFileSync(path.join(project, '.gitignore'), '/_work/task-board/\n');
  execFileSync('git', ['-C', project, 'add', '.gitignore']);
  execFileSync('git', ['-C', project, '-c', 'user.name=Fixture', '-c',
    'user.email=fixture@example.invalid', '-c', 'core.hooksPath=NUL', 'commit', '-qm', 'Fixture']);
  execFileSync('git', ['-C', project, 'worktree', 'add', '--quiet', '--detach', linked]);
  fs.mkdirSync(path.join(project, 'docs'));
  fs.mkdirSync(path.join(linked, 'docs'));
  fs.mkdirSync(path.join(project, '.runtime', 'test-probe'), { recursive: true });
  fs.writeFileSync(path.join(project, 'docs', 'reference.md'), '# Fixture chapter\n\nRead me.\n');
  fs.writeFileSync(path.join(linked, 'docs', 'reference.md'), '# Linked checkout chapter\n');
  fs.writeFileSync(path.join(project, 'docs', 'unlisted.md'), 'EXCLUDED-IN-PROJECT');
  fs.writeFileSync(path.join(project, 'docs', 'payload.html'), '<p>EXCLUDED-HTML</p>');
  fs.writeFileSync(path.join(root, 'outside.md'), 'EXCLUDED-OUTSIDE');
  fs.writeFileSync(path.join(project, '.runtime', 'test-probe', 'result.json'), JSON.stringify({
    status: 'passed', passed: 3, apiKey: 'EXCLUDED-JSON-SECRET',
  }));
  const board = session(project, 'Preview project', 'Preview scenario');
  const otherBoard = session(project, 'Preview project', 'Other scenario');
  await boardCommand(board, 'workspace-register', { workspace: { id: 'linked', root: linked } });
  await addTask(board, 'reader', {
    sourceRefs: ['docs/reference.md', 'docs/payload.html', '../outside.md'],
    acceptanceRefs: ['.runtime/test-probe/result.json'],
  });
  await addTask(board, 'unrelated');
  await addTask(board, 'linked-reader', {
    workspaceId: 'linked',
    sourceRefs: ['docs/reference.md'],
  });
  await addTask(otherBoard, 'reader', { sourceRefs: ['docs/unlisted.md'] });
  viewer = await startDashboard({ projectRoots: [project], port: 0 });
  const { url } = viewer;
  const { headers } = await openView(url);
  const listing = await fetch(url + '/api/sessions', { headers });
  const { sessions } = await listing.json();
  const id = sessions.find(item => item.sessionName === 'Preview scenario').id;
  const otherId = sessions.find(item => item.sessionName === 'Other scenario').id;
  const response = await fetch(`${url}/api/snapshot?session=${id}`, { headers });
  const { tasks } = await response.json();
  const reader = tasks.find(task => task.id === 'reader');
  const { sourceRefs, acceptanceRefs, referencePreviews } = reader.details;
  const sourceId = label => referencePreviews.sourceRefs[sourceRefs.indexOf(label)] ?? null;
  const markdownId = sourceId('docs/reference.md');
  const jsonId = referencePreviews.acceptanceRefs[acceptanceRefs.indexOf('.runtime/test-probe/result.json')];
  assert.match(markdownId, /^[a-f0-9]{64}$/);
  assert.match(jsonId, /^[a-f0-9]{64}$/);
  assert.equal(sourceId('docs/payload.html'), null);
  assert.equal(sourceId('../outside.md'), null);

  const reference = (task, ref, auth = headers, sessionId = id) => {
    const query = new URLSearchParams({ session: sessionId, task, ref });
    return fetch(`${url}/api/reference?${query}`, { headers: auth });
  };
  const markdown = await reference('reader', markdownId);
  assert.equal(markdown.status, 200);
  const markdownPreview = await markdown.json();
  assert.equal(markdownPreview.format, 'markdown');
  assert.match(markdownPreview.content, /# Fixture chapter/);
  // Two real worktrees contain the same relative path; each bound card reads its checkout.
  const linkedId = tasks.find(task => task.id === 'linked-reader').details.referencePreviews.sourceRefs[0];
  assert.match(linkedId, /^[a-f0-9]{64}$/);
  assert.notEqual(linkedId, markdownId);
  const linkedFile = await reference('linked-reader', linkedId);
  assert.equal(linkedFile.status, 200);
  assert.match((await linkedFile.json()).content, /# Linked checkout chapter/);
  const json = await reference('reader', jsonId);
  assert.equal(json.status, 200);
  const jsonPreview = await json.json();
  assert.equal(jsonPreview.format, 'json');
  assert.equal(JSON.parse(jsonPreview.content).status, 'passed');
  assert.doesNotMatch(jsonPreview.content, /EXCLUDED-JSON-SECRET/);

  const denied = [
    await reference('reader', markdownId, {}),
    await reference('unrelated', markdownId),
    await reference('reader', markdownId, headers, otherId),
    await reference('reader', 'f'.repeat(64)),
    await reference('reader', 'docs/unlisted.md'),
  ];
  assert.equal(denied[0].status, 401);
  for (const reply of denied) {
    assert.ok(reply.status >= 400 && reply.status < 500);
    assert.doesNotMatch(await reply.text(), /Fixture chapter|EXCLUDED-|Preview project/);
  }
});

/** Create canonical Board files and keep the original credential only in the writer fixture. */
function session(projectRoot, projectName, sessionName) {
  const mainSessionId = randomUUID();
  const sessionProfile = {
    hostId: 'fixture',
    mainSessionId,
    projectId: projectName,
    projectName,
    sessionName,
  };
  const { boardPath, sessionKey } = sessionLocation(sessionProfile);
  const leadToken = secret();
  const board = initializeBoard({
    projectRoot, boardPath, sessionKey, sessionProfile, leadId: 'lead',
    leadTokenHash: hash(leadToken),
  });
  const { generation } = board.metadata();
  board.close();
  return { projectRoot, boardPath, sessionKey, generation, leadToken, mainSessionId };
}

/** Commit through the same agent CLI the viewer intentionally does not depend on. */
async function boardCommand(location, operation, input) {
  const result = await invoke(location.projectRoot, location.boardPath, operation, {
    operationId: randomUUID(),
    actorId: 'lead',
    leadToken: location.leadToken,
    generation: location.generation,
    ...input,
  }, { sessionKey: location.sessionKey });
  assert.equal(result.code, 0, JSON.stringify(result.reply));
  return result.reply;
}

async function addTask(location, id, options = {}) {
  return boardCommand(location, 'add', {
    task: {
      id, title: id, outcome: 'Fixture output', sourceRefs: ['fixture/source'],
      acceptanceRefs: ['fixture/acceptance'], eligibleRoles: ['backend'],
      scope: { read: [], write: [] }, resources: [], dependencies: [],
      ...options,
    },
  });
}

async function grantTask(location, id) {
  await boardCommand(location, 'register', { worker: {
    id: 'lead', mode: 'lead-inline', role: 'lead', capabilities: ['write'],
  } });
  const approved = await boardCommand(location, 'approve', { taskId: id, taskRevision: 1 });
  const { taskRevision, approvalRevision } = approved.result.task;
  await boardCommand(location, 'grant', {
    workerId: 'lead', taskId: id, approvalRevision, executionMode: 'lead-inline',
  });
  return { taskRevision, approvalRevision };
}

async function assignTask(location, id) {
  const { taskRevision, approvalRevision } = await grantTask(location, id);
  const claimToken = secret();
  const reply = await boardCommand(location, 'lead-inline-assign', {
    taskId: id, taskRevision, approvalRevision, claimToken,
  });
  return { ...reply.result, claimToken };
}

/** Model the dashboard page's automatic same-origin bootstrap. */
async function openView(url, overrides) {
  const reply = await fetch(url + '/api/view', {
    method: 'POST',
    headers: { Origin: url, 'Sec-Fetch-Site': 'same-origin',
      'X-Task-Board-Bootstrap': '1', ...overrides },
  });
  if (reply.status !== 204) return { status: reply.status };
  const cookie = reply.headers.get('set-cookie');
  assert.match(cookie, /; HttpOnly; SameSite=Strict; Path=\/api\/$/);
  const capability = reply.headers.get(viewHeader);
  assert.match(capability, /^[a-f0-9]{64}$/);
  return { status: reply.status, headers: { cookie: cookie.split(';')[0], [viewHeader]: capability } };
}

/** Read complete SSE frames under a finite deadline. Dispose the connection at test cleanup. */
async function subscribe(url, id, headers, t) {
  const abort = new AbortController();
  t.after(() => abort.abort());
  const reply = await fetch(`${url}/api/events?session=${id}`, {
    headers, signal: AbortSignal.any([abort.signal, AbortSignal.timeout(7000)]),
  });
  assert.equal(reply.status, 200);
  const reader = reply.body.getReader();
  const decoder = new TextDecoder();
  let buffered = '';
  return {
    close: () => abort.abort(),
    async next() {
      while (!buffered.includes('\n\n')) {
        const chunk = await reader.read();
        assert.equal(chunk.done, false, 'SSE closed before a revision arrived.');
        buffered += decoder.decode(chunk.value, { stream: true });
      }
      const end = buffered.indexOf('\n\n');
      const frame = buffered.slice(0, end);
      buffered = buffered.slice(end + 2);
      assert.match(frame, /^event: revision\n/);
      return JSON.parse(frame.match(/^data: (.+)$/m)[1]).revision;
    },
  };
}

test('dashboard displays independently committed sessions through one authenticated port', async t => {
  // Start with the viewer closed, commit to two boards, then connect to one port.
  // Expect distinct scoped snapshots, read authorization and committed live/restart visibility.
  const parent = sourcePath('_work/task-board/test-fixtures');
  fs.mkdirSync(parent, { recursive: true });
  const root = fs.mkdtempSync(path.join(parent, 'dashboard-'));
  let viewer;
  t.after(async () => {
    await viewer?.close();
    if (path.dirname(root) !== parent || !path.basename(root).startsWith('dashboard-')) {
      throw Error('Unexpected fixture cleanup path.');
    }
    fs.rmSync(root, { recursive: true, force: true });
  });
  const projects = ['first', 'second', 'excluded'].map(name => {
    const directory = path.join(root, name);
    fs.mkdirSync(directory);
    return directory;
  });
  const first = session(projects[0], 'First project', 'First conversation');
  const awaitingStart = session(projects[0], 'first', 'Earlier conversation');
  const second = session(projects[1], 'First project', 'Second conversation');
  session(projects[2], 'Unapproved project', 'Unapproved conversation');
  // A damaged board should count as unreadable without hiding the healthy boards.
  const broken = path.join(projects[0], '_work/task-board/sessions/v1', 'f'.repeat(64));
  fs.mkdirSync(broken);
  fs.writeFileSync(path.join(broken, 'board.sqlite'), 'fixture corruption');
  await addTask(first, 'first-initial-task');
  await addTask(awaitingStart, 'ready-but-not-started', { eligibleRoles: ['lead'], allowLeadInline: true });
  await grantTask(awaitingStart, 'ready-but-not-started');
  const dropped = await addTask(awaitingStart, 'dropped-by-decision');
  await boardCommand(awaitingStart, 'cancel', { taskId: dropped.result.task.id,
    taskRevision: dropped.result.task.taskRevision, reason: 'Scope superseded by an approved follow-on.' });
  const externalReference = '/outside-registered-project/private.txt';
  const taskIntroduction = 'Fix the missing details.\n\nA saved task shows its outcome when expanded.';
  await addTask(second, 'second-initial-task', {
    eligibleRoles: ['lead'], allowLeadInline: true,
    outcome: taskIntroduction,
    sourceRefs: ['fixture/source', path.join(projects[1], 'docs/source.md'), externalReference],
    acceptanceRefs: ['fixture/acceptance', `file://${externalReference}`],
  });
  const running = await assignTask(second, 'second-initial-task');
  await boardCommand(second, 'lead-inline-report', {
    taskId: running.task.id, taskRevision: running.task.taskRevision,
    assignmentId: running.assignment.id, claimToken: running.claimToken,
    action: 'report', phase: 'implementation', progress: 'Projection ready', nextCheckpoint: 'Check the details',
  });

  viewer = await startDashboard({ projectRoots: projects.slice(0, 2), port: 0 });
  const { url } = viewer;
  assert.equal(new URL(url).hostname, '127.0.0.1');
  const landing = await fetch(url);
  assert.equal(landing.status, 200);
  assert.doesNotMatch(await landing.text(), /访问码|access-form/);
  assert.equal((await openView(url, { Origin: 'http://127.0.0.1:1' })).status, 403);
  assert.equal((await openView(url, { 'Sec-Fetch-Site': 'same-site' })).status, 403);
  assert.equal((await openView(url, { 'X-Task-Board-Bootstrap': '0' })).status, 403);
  assert.equal((await fetch(url + '/api/view', { method: 'POST' })).status, 403);
  assert.equal((await fetch(url + '/api/sessions')).status, 401);
  const { headers } = await openView(url);
  assert.equal((await fetch(url + '/api/sessions', { headers: { cookie: headers.cookie } })).status,
    401);
  assert.equal((await fetch(url + '/api/sessions', {
    headers: { [viewHeader]: headers[viewHeader] },
  })).status, 401);

  const listing = await (await fetch(url + '/api/sessions', { headers })).json();
  assert.equal(listing.unavailable, 1);
  assert.deepEqual(listing.sessions.map(item => item.sessionName).sort(),
    ['Earlier conversation', 'First conversation', 'Second conversation']);
  const earlier = listing.sessions.find(item => item.sessionName === 'Earlier conversation');
  const primary = listing.sessions.find(item => item.sessionName === 'First conversation');
  const different = listing.sessions.find(item => item.sessionName === 'Second conversation');
  assert.equal(earlier.projectKey, primary.projectKey, 'Different names for one root share a project.');
  assert.equal(earlier.projectName, 'First project', 'Prefer the display name over the directory fallback.');
  assert.notEqual(primary.projectKey, different.projectKey, 'Different roots sharing a name stay separate.');
  assert.equal(primary.hasRunningTasks, false, 'Planned tasks do not imply live execution.');
  assert.equal(earlier.hasRunningTasks, false, 'A grant without an assignment does not mark its session running.');
  assert.equal(different.hasRunningTasks, true, 'A persisted running task marks its session.');
  const firstId = listing.sessions.find(item => item.sessionName === 'First conversation').id;
  const secondId = listing.sessions.find(item => item.sessionName === 'Second conversation').id;
  assert.notEqual(firstId, secondId);
  async function snapshot(id, auth = headers) {
    const reply = await fetch(`${url}/api/snapshot?session=${id}`, { headers: auth });
    assert.equal(reply.status, 200);
    return reply.json();
  }
  const firstSnapshot = await snapshot(firstId);
  assert.deepEqual(firstSnapshot.tasks.map(item => item.id), ['first-initial-task']);
  const priorTasks = (await snapshot(earlier.id)).tasks;
  const grantedTask = priorTasks.find(task => task.id === 'ready-but-not-started');
  assert.equal(grantedTask.state, 'open');
  assert.deepEqual(grantedTask.responsibility, { kind: 'unassigned', person: null });
  const canceledTask = priorTasks.find(task => task.id === 'dropped-by-decision');
  assert.equal(canceledTask.state, 'canceled');
  assert.equal(canceledTask.cancellationReason, 'Scope superseded by an approved follow-on.');
  const secondSnapshot = await snapshot(secondId);
  assert.deepEqual(secondSnapshot.tasks.map(item => item.id), ['second-initial-task']);
  const runningTask = secondSnapshot.tasks[0];
  assert.deepEqual(runningTask.responsibility, { kind: 'executor', person: { id: 'lead', role: 'lead' } });
  assert.deepEqual(runningTask.details.sourceRefs, ['fixture/source', 'docs/source.md']);
  assert.deepEqual(runningTask.details.acceptanceRefs, ['fixture/acceptance']);
  assert.equal(runningTask.details.outcome, taskIntroduction);
  assert.equal(runningTask.progress, 'Projection ready');
  assert.equal(runningTask.nextCheckpoint, 'Check the details');
  assert.ok(runningTask.lastReportAt);
  const displayed = JSON.stringify({ listing, firstSnapshot, secondSnapshot });
  for (const hidden of [first.leadToken, first.mainSessionId, first.sessionKey, first.projectRoot,
    second.leadToken, second.sessionKey, second.projectRoot, running.claimToken, running.assignment.id,
    externalReference]) {
    assert.equal(displayed.includes(hidden), false, 'A native identity, credential or path leaked.');
  }

  const stream = await subscribe(url, firstId, headers, t);
  assert.equal(await stream.next(), firstSnapshot.revision);
  await addTask(first, 'first-live-task');
  assert.notEqual(await stream.next(), firstSnapshot.revision);
  assert.deepEqual((await snapshot(firstId)).tasks.map(item => item.id),
    ['first-initial-task', 'first-live-task']);
  stream.close();
  await viewer.close();
  await addTask(first, 'first-offline-task');

  // Reuse the exact address after a normal shutdown. The page can renew its view automatically.
  viewer = await startDashboard({
    projectRoots: projects.slice(0, 2), port: Number(new URL(url).port),
  });
  assert.equal((await fetch(url + '/api/sessions', { headers })).status, 401);
  const restarted = await openView(url);
  assert.deepEqual((await snapshot(firstId, restarted.headers)).tasks.map(item => item.id),
    ['first-initial-task', 'first-live-task', 'first-offline-task']);
});
