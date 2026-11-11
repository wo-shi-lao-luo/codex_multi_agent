/** Responsibility rendering uses the shipped client and immutable execution evidence. */
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
import { fixture } from './helpers.mjs';

/** Minimal DOM records visible text/options; bootstrap is held without network or queue writes. */
async function page(snapshot) {
  const element = () => ({
    textContent: '', value: '', checked: false, hidden: false, dataset: {}, children: [],
    className: '', scrollLeft: 0, addEventListener() {}, setAttribute() {}, focus() {},
    append(...items) { this.children.push(...items); },
    replaceChildren(...items) { this.children = items; }, querySelectorAll() { return []; },
  });
  const elements = new Map();
  const document = {
    activeElement: null,
    getElementById(id) {
      if (!elements.has(id)) elements.set(id, element());
      return elements.get(id);
    },
    createElement: element,
  };
  const context = vm.createContext({
    document, window: { addEventListener() {} }, AbortController,
    fetch: () => new Promise(() => {}), setTimeout: () => 0, clearTimeout() {},
  });
  vm.runInContext(await readFile('packages/task-board/web/app.js', 'utf8'), context);
  context.fixtureSnapshot = structuredClone(snapshot);
  vm.runInContext('state.snapshot = fixtureSnapshot; render();', context);
  const flatten = item => [item, ...(item.children ?? []).flatMap(flatten)];
  return {
    elements, context,
    text: item => flatten(item).map(part => part.textContent).filter(Boolean).join('\n'),
    cards: () => flatten(elements.get('board')).filter(item => item.className === 'card'),
    card: id => flatten(elements.get('board')).find(item => item.dataset?.task === id),
    run: code => vm.runInContext(code, context),
  };
}

const backend = 'team-backend-engineer';
const frontend = 'team-frontend-engineer';
const executor = (workerId, role = backend, executionMode = 'direct') =>
  ({ workerId, role, executionMode });
const assignment = (id, taskId, workerId, active = false, role = backend) =>
  ({ id, taskId, workerId, active, actualExecutor: executor(workerId, role) });
const submission = (id, taskId, workerId, extra = {}) =>
  ({ id, taskId, actualExecutor: executor(workerId), ...extra });

// Scenario: unassigned planned/ready tasks list alternatives and explicit Lead-inline opt-in.
// Expected: role filtering finds either eligible role; no instance or mandatory child is invented.
test('Responsibility.unassignedRolesAndLeadOptIn', async () => {
  const p = await page({ tasks: [
    { id: 'plan', state: 'planned', title: '准备接口', eligibleRoles: [backend, frontend] },
    { id: 'ready', state: 'open', readiness: 'ready', title: '直接处理',
      eligibleRoles: [backend], allowLeadInline: true },
  ] });
  assert.match(p.text(p.cards()[0]), /可承接：后端工程师.*前端工程师/);
  assert.match(p.text(p.cards()[0]), /任选其一/);
  assert.match(p.text(p.cards()[1]), /主 Agent/);
  assert.match(p.text(p.cards()[1]), /未分配实例/);
  p.run(`ui.role.value = '${frontend}'; render();`);
  assert.deepEqual(p.cards().map(card => card.dataset.task), ['plan']);
  assert.equal(p.elements.get('instance').children.length, 1);
});

// Scenario: two active Agents share the same host; their native Board handles are distinct.
// Expected: instance options remain distinct and selecting one returns only its actual task.
test('Responsibility.instancesNeverCollapseToHost', async () => {
  const p = await page({ tasks: ['a', 'b'].map(id => ({ id, title: id, state: 'running' })),
    workers: ['agent-a', 'agent-b'].map(id => ({ id, role: backend, hostId: 'local' })),
    assignments: [assignment('aa', 'a', 'agent-a', true), assignment('ab', 'b', 'agent-b', true)],
  });
  const values = p.elements.get('instance').children.map(option => option.value);
  assert.deepEqual(values, ['', 'agent-a', 'agent-b']);
  assert.match(p.text(p.cards()[0]), /执行者：后端工程师 · agent-a/);
  p.run("ui.instance.value = 'agent-b'; render();");
  assert.deepEqual(p.cards().map(card => card.dataset.task), ['b']);
});

// Scenario: an accepted result belongs to A, while newer rejected work and current registration say B.
// Expected: the released card and filters retain the exact accepted submitter, without mutable lookup.
test('Responsibility.completedUsesAcceptedSubmission', async () => {
  const p = await page({ tasks: [{ id: 'done', title: '已结束', state: 'closed', resultValid: true,
    acceptedResult: { submissionId: 'accepted-a' } }],
  workers: [{ id: 'agent-a', role: frontend, hostId: 'local' }],
  assignments: [assignment('latest', 'done', 'agent-b')], submissions: [
    submission('accepted-a', 'done', 'agent-a'), submission('newer-b', 'done', 'agent-b'),
  ] });
  assert.match(p.text(p.cards()[0]), /完成者：后端工程师 · agent-a/);
  assert.doesNotMatch(p.text(p.cards()[0]), /完成者：.*agent-b|前端工程师/);
  p.run(`ui.role.value = '${backend}'; render();`);
  assert.equal(p.cards().length, 1, 'Historical attribution remains discoverable by its recorded role');
  p.run("ui.instance.value = 'agent-a'; render();");
  assert.equal(p.cards().length, 1);
  p.run("state.selected = 'done'; renderDetail();");
  const detail = p.text(p.elements.get('detail-content'));
  assert.match(detail, /已验收提交\n提交者：后端工程师 · agent-a/);
  assert.match(detail, /历史提交（非当前验收结果）\n提交者：后端工程师 · agent-b/);
  assert.doesNotMatch(detail, /"actualExecutor"|"executionMode"/);
  p.run("ui.instance.value = 'agent-b'; render();");
  assert.equal(p.cards().length, 0);
});

// Scenario: submitted work was released; a proxy Lead recorded a real reviewer's frozen output.
// Expected: current freeze identifies the actual submitter, not the Lead recorder or an older freeze.
test('Responsibility.submittedUsesCurrentFrozenExecutor', async () => {
  const current = { freezeRevision: 3, executionRevision: 2, approvalRevision: 4,
    boundTaskInputRevision: 1, freezeValid: true };
  const p = await page({ tasks: [{ id: 'review', title: '待核验', state: 'submitted',
    freezeRevision: 3, executionRevision: 2, approvalRevision: 4, inputRevision: 1 }],
  submissions: [submission('old', 'review', 'old', { ...current, freezeRevision: 2 }),
    { ...submission('current', 'review', 'reviewer-a', current),
      actualExecutor: { ...executor('reviewer-a', 'team-reviewer', 'lead-proxy'),
        provenance: { actorId: 'lead', proxyWriterId: 'lead' } } }],
  });
  assert.match(p.text(p.cards()[0]), /提交者：代码审查.*reviewer-a/);
  assert.doesNotMatch(p.text(p.cards()[0]), /提交者：.*lead/);
});

// Scenario: a historical accepted result is invalidated, and another legacy close has no evidence.
// Expected: historical attribution is explicit; absent or foreign-task evidence never invents completion.
test('Responsibility.invalidAndMissingHistoryStayExplicit', async () => {
  const p = await page({ tasks: [
    { id: 'invalid', title: '旧结果', state: 'closed', resultValid: false,
      acceptedResult: { submissionId: 'old-result' } },
    { id: 'legacy', title: '缺失证据', state: 'closed', acceptedResult: { submissionId: 'foreign' } },
  ], submissions: [submission('old-result', 'invalid', 'old-agent'),
    submission('foreign', 'another-task', 'wrong-agent')],
  assignments: [assignment('legacy-allocation', 'legacy', 'guessed-agent')] });
  assert.match(p.text(p.cards()[0]), /历史完成人：.*old-agent/);
  assert.match(p.text(p.cards()[0]), /结果已失效/);
  assert.match(p.text(p.cards()[1]), /完成者：未记录/);
  assert.doesNotMatch(p.text(p.cards()[1]), /wrong-agent|guessed-agent/);
});

// Scenario: a task is transferred from A to B, while a released current freeze has ambiguous proof.
// Expected: current ownership is B, history retains A, and ambiguous submission attribution stays unknown.
test('Responsibility.transferHistoryAndAmbiguousFreeze', async () => {
  const p = await page({ tasks: [
    { id: 'transfer', title: '转交', state: 'running' },
    { id: 'ambiguous', title: '证据有歧义', state: 'submitted', freezeRevision: 2 },
  ], assignments: [assignment('old-a', 'transfer', 'agent-a'),
    assignment('current-b', 'transfer', 'agent-b', true)],
  submissions: ['a', 'b'].map(id => submission(id, 'ambiguous', `submitter-${id}`,
    { freezeValid: true, freezeRevision: 2 })) });
  assert.match(p.text(p.card('transfer')), /执行者：.*agent-b/);
  assert.doesNotMatch(p.text(p.card('transfer')), /执行者：.*agent-a/);
  p.run("state.selected = 'transfer'; renderDetail();");
  assert.match(p.text(p.elements.get('detail-content')), /曾分配：.*agent-a/);
  assert.match(p.text(p.card('ambiguous')), /提交者：未记录/);
});

// Scenario: a canceled task had an old submission/assignment, and another is executed inline by Lead.
// Expected: cancellation never implies completion; history/reason and actual Lead responsibility remain visible.
test('Responsibility.cancellationHistoryAndInlineLead', async () => {
  const p = await page({ tasks: [
    { id: 'cancel', title: '取消', state: 'canceled',
      cancellation: { reason: '优先级改变', actorId: 'lead' } },
    { id: 'inline', title: '主 Agent 处理', state: 'running', responsibilities: ['接口维护'] },
  ], assignments: [assignment('past', 'cancel', 'old-agent'),
    { ...assignment('lead-a', 'inline', '/root', true, 'lead'),
      actualExecutor: executor('/root', 'lead', 'lead-inline') }],
  submissions: [submission('abandoned', 'cancel', 'old-agent')] });
  assert.match(p.text(p.card('cancel')), /已取消.*无完成者/);
  assert.match(p.text(p.card('cancel')), /优先级改变/);
  assert.match(p.text(p.card('inline')), /执行者：主 Agent · \/root/);
  p.run("state.selected = 'cancel'; renderDetail();");
  assert.match(p.text(p.elements.get('detail-content')), /曾分配：.*old-agent/);
  p.run("state.selected = 'inline'; renderDetail();");
  assert.match(p.text(p.elements.get('detail-content')), /承担职责：接口维护/);
});

// Scenario: the server-supplied role/handle contains HTML, then SSE changes assignment to a released close.
// Expected: text stays literal, identity switches to accepted evidence, and the selected filter survives.
test('Responsibility.literalTextAndSnapshotTransition', async () => {
  const hostile = '<img src=x onerror=alert(1)>';
  const p = await page({ tasks: [{ id: 'flow', title: '更新', state: 'running' }],
    assignments: [assignment('active', 'flow', hostile, true)] });
  assert.ok(p.text(p.cards()[0]).includes(hostile));
  p.run(`ui.instance.value = ${JSON.stringify(hostile)};
    state.snapshot.tasks[0] = { id: 'flow', state: 'closed', resultValid: true,
      acceptedResult: { submissionId: 'accepted' } };
    state.snapshot.assignments[0].active = false;
    state.snapshot.submissions = [{ id: 'accepted', taskId: 'flow',
      actualExecutor: { workerId: ${JSON.stringify(hostile)}, role: '${backend}' } }];
    render();`);
  assert.equal(p.elements.get('instance').value, hostile);
  assert.equal(p.cards().length, 1);
  assert.match(p.text(p.cards()[0]), /完成者：后端工程师/);
});

// Scenario: a real refresh carries opaque Board/generation/task IDs and a useful human title.
// Expected: visible header/cards/details omit protocol IDs/revision counters; binding and actions retain IDs.
test('Responsibility.internalIdentifiersStayOutOfVisibleContent', async () => {
  const snapshot = { schemaVersion: 1, boardId: 'opaque-board-uuid',
    generation: 'opaque-generation-uuid', revision: 827, eventSeq: 4,
    tasks: [{ id: 'opaque-task-slug', title: '整理任务说明', state: 'planned' }] };
  const p = await page(snapshot);
  p.context.fetch = async () => ({ ok: true, status: 200, json: async () => snapshot });
  p.context.EventSource = class { addEventListener() {} close() {} };
  await p.run('refresh(false)');
  assert.equal(p.run('state.snapshot.boardId'), snapshot.boardId);
  assert.equal(p.run('state.snapshot.generation'), snapshot.generation);
  assert.equal(p.cards()[0].dataset.task, 'opaque-task-slug');
  p.run("state.selected = 'opaque-task-slug'; renderDetail();");
  const visible = [...p.elements.values()].map(p.text).join('\n');
  assert.match(visible, /整理任务说明/);
  assert.match(p.elements.get('sync').textContent, /同步于/);
  assert.doesNotMatch(visible, /opaque-board-uuid|opaque-generation-uuid|opaque-task-slug|修订 827/);
  assert.match(p.text(p.elements.get('detail-content')), /角色与执行者/);
});

// Scenario: Lead cancels through the real authorized CLI and later releases retained allocations.
// Expected: cancellation reason/recorder survive the snapshot and release without fabricating acceptance.
test('Responsibility.cancelReasonPersistsThroughRelease', async t => {
  const f = await fixture(t);
  await f.task('cancel-fact');
  const s = await f.ok('show', { taskId: 'cancel-fact' });
  const canceled = await f.ok('cancel', { taskId: 'cancel-fact',
    taskRevision: s.result.task.taskRevision, reason: '需求已撤回' });
  assert.deepEqual(canceled.result.task.cancellation, { actorId: 'lead', reason: '需求已撤回' });
  await f.ok('release', { taskId: 'cancel-fact', taskRevision: canceled.result.task.taskRevision,
    writesStopped: true, processStopped: true });
  const readback = await f.ok('show', { taskId: 'cancel-fact' });
  assert.equal(readback.result.task.state, 'canceled');
  assert.equal(readback.result.task.resultValid, false);
  assert.deepEqual(readback.result.task.cancellation, { actorId: 'lead', reason: '需求已撤回' });
});
