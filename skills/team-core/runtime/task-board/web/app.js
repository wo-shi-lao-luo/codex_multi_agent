/** Read-only snapshot/SSE client. Only this history entry retains its Board capability. */
'use strict';
(() => {
const sharedView = /^\/boards\/[a-f0-9]{64}\/$/.test(window.location.pathname);
const fragmentCapability = sharedView ? /^#view=([a-f0-9]{64})$/.exec(window.location.hash)?.[1] : null;
const retainedView = sharedView ? window.history.state?.taskBoardView : null;
const viewCapability = fragmentCapability ?? (sharedView && retainedView?.version === 1
  && retainedView.routeBase === window.location.pathname && /^[a-f0-9]{64}$/.test(retainedView.capability)
  ? retainedView.capability : null);
if (sharedView && viewCapability) window.history.replaceState({ ...window.history.state,
  taskBoardView: { version: 1, routeBase: window.location.pathname, capability: viewCapability } }, '', window.location.pathname);
else if (sharedView && window.location.hash) window.history.replaceState(null, '', window.location.pathname);
function forgetView() {
  if (!sharedView) return;
  const { taskBoardView, ...rest } = window.history.state ?? {};
  window.history.replaceState(rest, '', window.location.pathname);
}
const viewHeaders = () => sharedView && viewCapability ? { 'X-Task-Board-View': viewCapability } : {};

const ui = Object.fromEntries([
  'connection', 'sync', 'attention', 'search', 'role', 'instance',
  'attention-only', 'clear', 'retry', 'empty', 'board', 'detail', 'detail-content',
  'close-detail', 'board-name', 'summary-ready', 'summary-running', 'summary-attention',
  'filtered-count', 'session-scope-note',
].map(id => [id, document.getElementById(id)]));
const lanes = [
  ['planned', '计划'], ['ready', '就绪'], ['running', '进行'],
  ['blocked', '阻塞'], ['submitted', '待核验'], ['ended', '已结束'],
];
/** Translate stable phase codes only; worker-supplied phase descriptions remain verbatim. */
const phaseLabels = new Map([
  ...lanes, ['running', '进行中'], ['closed', '已关闭'], ['canceled', '已取消'],
  ['open', '待分配'],
]);
const state = { snapshot: null, selected: null, stream: null, attempt: 0,
  timer: null, refreshTimer: null, request: 0, stopped: false, controller: null };

function node(tag, text, className) {
  const element = document.createElement(tag);
  if (text !== undefined) element.textContent = String(text);
  if (className) element.className = className;
  return element;
}
function text(value, fallback = '未提供') {
  if (value === undefined || value === null || value === '') return fallback;
  return typeof value === 'object' ? JSON.stringify(value) : String(value);
}
function list(name) { return state.snapshot?.[name] ?? []; }
function related(name, task) { return list(name).filter(item => item.taskId === task.id); }
const roleLabels = new Map([
  ['lead', '主 Agent'], ['team-backend-engineer', '后端工程师'],
  ['team-frontend-engineer', '前端工程师'], ['team-reviewer', '代码审查'],
  ['team-tester', '测试工程师'], ['team-ai-tester', 'AI 测试'],
  ['team-architect', '架构师'], ['team-ai-architect', 'AI 架构师'],
  ['team-ai-engineer', 'AI 工程师'], ['team-database-specialist', '数据库专家'],
  ['team-data-scientist', '数据科学家'], ['team-designer', '界面设计'],
  ['team-explorer', '代码探索'], ['team-researcher', '信息收集'],
  ['team-docs-maintainer', '文档维护'], ['team-code-maintainer', '代码整理'],
  ['team-delivery-checker', '交付检查'],
  ['team-ai-simulation-actor-basic', '基础模拟 Actor'],
  ['team-ai-simulation-actor-advanced', '高级模拟 Actor'],
]);
function roleLabel(role) { return roleLabels.get(role) ?? text(role, '角色未记录'); }

/** Read immutable executor attribution; a recorder or shared host is never an Agent identity. */
function executorOf(record) {
  if (!record) return null;
  const executor = record.actualExecutor ?? record;
  if (!executor.workerId) return null;
  return { id: executor.workerId, role: executor.role,
    mode: executor.executionMode, principal: executor.principal };
}
function executorLabel(executor) {
  return executor ? `${roleLabel(executor.role)} · ${executor.id}` : '未记录';
}

/** Role alternatives are conditions, not grants; explicit inline opt-in also permits the Lead. */
function eligibleRoles(task) {
  return [...new Set([...(task.eligibleRoles ?? []), ...(task.allowLeadInline ? ['lead'] : [])])];
}
function candidatesLabel(task) {
  const roles = eligibleRoles(task);
  return `可承接：${roles.length ? roles.map(roleLabel).join(' / ') : '角色未指定'}` +
    (roles.length > 1 ? '（任选其一）' : '');
}

/** Select the exact accepted result or current freeze, never the newest array entry/active owner. */
function attributedSubmission(task) {
  const submissions = related('submissions', task);
  if (task.state === 'closed') {
    return submissions.find(item => item.id === task.acceptedResult?.submissionId) ?? null;
  }
  if (task.state !== 'submitted' || !Number.isSafeInteger(task.freezeRevision)) return null;
  const matches = submissions.filter(item => item.freezeValid === true &&
    item.freezeRevision === task.freezeRevision &&
    ['executionRevision', 'approvalRevision'].every(key =>
      task[key] === undefined || item[key] === task[key]) &&
    (task.inputRevision === undefined || item.boundTaskInputRevision === task.inputRevision));
  return matches.length === 1 ? matches[0] : null;
}
function submissionExecutor(task, submission) {
  if (!submission) return null;
  return executorOf(submission) ?? executorOf(related('assignments', task)
    .find(item => item.id === submission.assignmentId));
}

/** Match visible attribution to task state; released and canceled work has no current owner. */
function responsibility(task) {
  if (task.state === 'canceled') return { label: '已取消 · 无完成者', executor: null };
  if (['closed', 'submitted'].includes(task.state)) {
    const executor = submissionExecutor(task, attributedSubmission(task));
    const label = task.state === 'submitted' ? '提交者' :
      invalidClosedResult(task) ? '历史完成人' : '完成者';
    return { label: `${label}：${executorLabel(executor)}`, executor };
  }
  const active = related('assignments', task).find(item => item.active === true);
  const executor = executorOf(active);
  return { label: executor ? `执行者：${executorLabel(executor)}` : '未分配实例', executor };
}

/** Role filters cover alternatives and attributed executors; cancellations retain former assignees. */
function taskPeople(task) {
  const executor = responsibility(task).executor;
  const people = executor ? [executor] : task.state === 'canceled' ?
    related('assignments', task).map(executorOf).filter(Boolean) : [];
  return { people, roles: [...new Set([...eligibleRoles(task),
    ...people.map(person => person.role).filter(Boolean)])] };
}

/** Human-readable assignment history survives release without presenting it as completed output. */
function executionHistory(task) {
  return related('assignments', task).map(assignment =>
    `曾分配：${executorLabel(executorOf(assignment))}` +
    (assignment.active ? '（当前分配）' : '（分配已结束）'));
}

/** Distinguish accepted evidence from other submissions without dumping internal execution bindings. */
function submissionHistory(task) {
  const current = attributedSubmission(task);
  return related('submissions', task).map(submission => {
    let status = '历史提交（非当前验收结果）';
    if (submission === current) {
      status = task.state === 'submitted' ? '当前待核验提交' :
        invalidClosedResult(task) ? '历史验收提交（结果已失效）' : '已验收提交';
    }
    return [status, `提交者：${executorLabel(submissionExecutor(task, submission))}`,
      ...(submission.evidenceRefs ?? []).map(reference => `证据：${text(reference)}`)].join('\n');
  });
}
/** Retain stale origin independently of any unresolved approval authority. */
function staleQuestion(question) {
  return question.stale === true || question.state === 'stale' || question.status === 'stale';
}
/** Backend approval holds remain pending even when their originating binding is stale. */
function pendingQuestions(task) {
  return related('questions', task).filter(question =>
    (question.approvalPending === true || !staleQuestion(question)) &&
    question.state !== 'applied' && question.status !== 'applied');
}
/** A historical close is not current acceptance when its result has been invalidated. */
function invalidClosedResult(task) {
  return task.state === 'closed' && task.resultValid === false;
}
function resultStatus(task) {
  if (invalidClosedResult(task)) return '历史已关闭 · 结果已失效';
  if (task.resultValid === true) return '当前结果有效';
  if (task.resultValid === false) return '尚无当前有效结果';
  return '结果有效性未知';
}
/** Claim readiness describes open tasks; other states need their own attention evidence. */
function needsAttention(task) {
  return task.state === 'blocked' || (task.state === 'open' && task.readiness === 'blocked') ||
    task.cleanupPending || task.needsReconcile || invalidClosedResult(task) ||
    pendingQuestions(task).length > 0;
}
/** Readiness belongs to the backend; an open task without projection stays unconfirmed. */
function laneFor(task) {
  if (['closed', 'canceled'].includes(task.state)) return 'ended';
  if (task.state === 'open') {
    if (task.readiness === 'ready') return 'ready';
    if (task.readiness === 'blocked') return 'blocked';
    return 'planned';
  }
  return lanes.some(([key]) => key === task.state) ? task.state : 'planned';
}
function date(value) {
  if (!value || Number.isNaN(new Date(value).getTime())) return '时间未知';
  return new Date(value).toLocaleString('zh-CN');
}
/** Refresh options in place so focus and user-selected filters survive data changes. */
function options(select, values, label, format = value => value) {
  const selected = select.value;
  const next = ['', ...new Set(values.filter(Boolean))];
  if (selected && !next.includes(selected)) next.push(selected);
  const signature = JSON.stringify(next.map(value => [value, value ? format(value) : label]));
  if (select.dataset.options === signature) return;
  select.replaceChildren(...next.map(value => {
    const option = node('option', value ? format(value) : label);
    option.value = value;
    return option;
  }));
  select.value = selected;
  select.dataset.options = signature;
}
/** Cards prioritize actual progress, then the next checkpoint; server text never becomes HTML. */
function card(task) {
  const button = node('button', undefined, 'card');
  button.type = 'button';
  button.dataset.task = task.id;
  button.setAttribute('aria-expanded', String(state.selected === task.id));
  button.append(node('span', task.title, 'card-title'));
  button.append(node('span', candidatesLabel(task), 'meta'),
    node('span', responsibility(task).label, 'meta responsibility'));
  if (task.state === 'canceled') {
    button.append(node('span', `取消说明：${text(task.cancellation?.reason, '历史记录未提供')}`,
      'meta'));
  }
  let phase = phaseLabels.get(task.phase) ?? text(task.phase, '阶段未提供');
  if (task.state === 'closed') {
    phase = invalidClosedResult(task) ? '历史已关闭 · 结果已失效' : '已验收关闭';
  }
  if (task.state === 'canceled') phase = '已取消';
  button.append(node('span', phase, 'meta'));
  if (task.state === 'open') {
    const readinessLabel = task.readiness === 'ready' ? '就绪条件已满足' :
      text(task.readinessReason, '就绪条件待确认');
    button.append(node('span', readinessLabel, 'meta'));
  }
  button.append(node('span', text(task.progress, '尚无实际进展报告'), 'progress'));
  button.append(node('span', `下一检查点：${text(task.nextCheckpoint, '尚未报告')}`, 'checkpoint'));
  const flags = [];
  if (task.blocker) flags.push(`阻塞：${text(task.blocker)}`);
  if (related('dependencies', task).length) flags.push(`依赖 ${related('dependencies', task).length}`);
  if (pendingQuestions(task).length) flags.push(`待处理问询 ${pendingQuestions(task).length}`);
  if (task.cleanupPending) flags.push('待安全收尾 · 资源可能仍被占用');
  if (task.needsReconcile) flags.push('待协调确认');
  if (flags.length) button.append(node('span', flags.join(' · '), 'warning'));
  button.append(node('span', `最近报告：${date(task.lastReportAt)}`, 'meta report-time'));
  if (task.updatedAt) {
    button.append(node('span', `最近更新：${date(task.updatedAt)}`, 'meta'));
  }
  button.addEventListener('click', () => {
    state.selected = task.id;
    render();
    ui['close-detail'].focus();
  });
  return button;
}
function section(title, values) {
  const block = node('section');
  block.append(node('h3', title));
  for (const value of values.length ? values : ['未提供']) block.append(node('p', text(value)));
  return block;
}
/** Show supplied reporter provenance without exposing execution bindings or inferring identity. */
function reporter(record) {
  const reported = [record.reportedByRole, record.reportedByHostId, record.reportedByWorkerId]
    .filter(Boolean);
  const source = reported.length ? reported.join(' · ') : text(record.workerId ?? record.actorId);
  return record.proxyWriterId ? `${source}（代理记录：${text(record.proxyWriterId)}）` : source;
}
/** Details retain plaintext evidence and distinguish answer availability from application. */
function renderDetail() {
  ui.detail.hidden = !state.selected;
  if (!state.selected) return;
  const task = list('tasks').find(item => item.id === state.selected);
  if (!task) {
    ui['detail-content'].replaceChildren(node('p', '该任务已不在当前快照中。'));
    return;
  }
  const content = [node('h2', task.title),
    section('结果有效性', [resultStatus(task)]),
    section('角色与执行者', [candidatesLabel(task), responsibility(task).label,
      ...(task.responsibilities?.length ? [`承担职责：${task.responsibilities.join(' / ')}`] : []),
      '可承接角色仅表示角色条件，实际执行仍需 Lead 授权。']),
    section('执行与交接记录', executionHistory(task)),
    section('实际进展', [task.progress]), section('下一检查点', [task.nextCheckpoint]),
    section('目标与阻塞', [task.outcome, task.blocker]),
    section('来源引用', task.sourceRefs ?? []),
    section('验收引用', task.acceptanceRefs ?? []),
    section('结果与提交', submissionHistory(task)),
    section('依赖', related('dependencies', task)),
    section('资源与收尾', [task.cleanupPending ? '待安全收尾' : '无待收尾标记',
      ...list('reservations').filter(item => related('assignments', task)
        .some(assignment => assignment.id === item.assignmentId) && item.active)]),
  ];
  if (task.state === 'canceled') {
    content.push(section('取消记录', [text(task.cancellation?.reason, '历史记录未提供取消说明'),
      `取消记录人：${text(task.cancellation?.actorId, '未记录')}`]));
  }
  const questions = related('questions', task).map(question => {
    const answers = list('answers').filter(answer => answer.questionId === question.id);
    let status = '待答复';
    if (answers.length) status = '已答复，尚未应用';
    if (question.state === 'applied' || question.status === 'applied') status = '已应用';
    if (staleQuestion(question)) status = '已过期';
    if (question.approvalPending === true &&
      question.state !== 'applied' && question.status !== 'applied') {
      status = staleQuestion(question) ? '审批待决 · 原问询已过期' : '审批待决';
    }
    // Only reader-facing fields belong here; opaque bindings remain in the snapshot protocol.
    const lines = [status, `问题：${text(question.question)}`, `步骤：${text(question.step)}`,
      `影响：${text(question.impact)}`];
    if (question.options?.length) {
      lines.push('选项：', ...question.options.map((option, index) => `${index + 1}. ${text(option)}`));
    }
    if (question.recommendation) lines.push(`建议：${text(question.recommendation)}`);
    if (question.checkedRefs?.length) {
      lines.push('已查阅：', ...question.checkedRefs.map(value => text(value)));
    }
    lines.push(`提问来源：${reporter(question)}`);
    const decisions = { clarify: '澄清', 'needs-approval': '需要审批', 'scope-change': '范围变更' };
    for (const answer of answers) {
      // Absent question revision cannot establish whether an answer is current or historical.
      let label = '答复记录';
      if (question.answerRevision !== undefined && question.answerRevision !== null) {
        label = answer.answerRevision === question.answerRevision ? '最新答复' : '历史答复';
      }
      const heading = answer.answerRevision === undefined ? label :
        `${label} · 版本 ${text(answer.answerRevision)}`;
      lines.push('', heading, `答复：${text(answer.text)}`,
        `决策：${text(decisions[answer.decision] ?? answer.decision)}`);
      if (answer.evidenceRefs?.length) {
        lines.push('依据：', ...answer.evidenceRefs.map(value => text(value)));
      }
      if (answer.authorizationEvidenceRefs?.length) {
        lines.push('授权依据：', ...answer.authorizationEvidenceRefs.map(value => text(value)));
      }
      lines.push(`答复来源：${reporter(answer)}`);
    }
    return lines.join('\n');
  });
  content.push(section('问询与答复', questions));
  ui['detail-content'].replaceChildren(...content);
}
/** Replace only the board, preserving filter/detail controls and restoring focused card identity. */
function render() {
  const tasks = list('tasks');
  const focusedTask = document.activeElement?.dataset.task;
  const scroll = ui.board.scrollLeft;
  // Keep only local DOM scroll positions while rebuilding lanes, without adding application state.
  const laneScroll = new Map([...ui.board.querySelectorAll('.lane')]
    .map(lane => [lane.dataset.phase, lane.scrollTop]));
  const peopleByTask = new Map(tasks.map(task => [task.id, taskPeople(task)]));
  options(ui.role, [...peopleByTask.values()].flatMap(item => item.roles), '全部角色', roleLabel);
  options(ui.instance, [...peopleByTask.values()].flatMap(item => item.people.map(person => person.id)),
    '全部实例');
  const query = ui.search.value.toLocaleLowerCase();
  const filtered = tasks.filter(task => {
    const { people, roles } = peopleByTask.get(task.id);
    return (!query || [task.id, task.title, task.progress, task.nextCheckpoint,
      ...roles, ...roles.map(roleLabel), ...people.map(person => person.id)]
      .some(value => text(value, '').toLocaleLowerCase().includes(query))) &&
      (!ui.role.value || roles.includes(ui.role.value)) &&
      (!ui.instance.value || people.some(person => person.id === ui.instance.value)) &&
      (!ui['attention-only'].checked || needsAttention(task));
  });
  // Summary counts describe the complete snapshot, independently of the current filters.
  ui['summary-ready'].textContent = String(tasks.filter(task => laneFor(task) === 'ready').length);
  ui['summary-running'].textContent = String(tasks.filter(task => laneFor(task) === 'running').length);
  ui['summary-attention'].textContent = String(tasks.filter(needsAttention).length);
  ui['filtered-count'].textContent = `当前显示 ${filtered.length} / 全部 ${tasks.length}`;
  ui['session-scope-note'].textContent =
    '不同会话仍可能修改相同文件；此板不提供跨会话文件互斥';
  ui.board.replaceChildren(...lanes.map(([key, label]) => {
    const group = node('section', undefined, 'lane');
    group.dataset.phase = key;
    const items = filtered.filter(task => laneFor(task) === key);
    const heading = node('div', undefined, 'lane-heading');
    heading.append(node('h2', label), node('span', items.length, 'lane-count'));
    group.append(heading, ...items.map(card));
    if (!items.length) group.append(node('p', '暂无任务', 'meta'));
    return group;
  }));
  ui.board.scrollLeft = scroll;
  for (const lane of ui.board.querySelectorAll('.lane')) {
    lane.scrollTop = laneScroll.get(lane.dataset.phase) ?? 0;
  }
  if (focusedTask) {
    [...ui.board.querySelectorAll('button')].find(item => item.dataset.task === focusedTask)
      ?.focus({ preventScroll: true });
  }
  ui.empty.hidden = filtered.length > 0;
  ui.empty.textContent = tasks.length ? '没有符合当前筛选的任务。清除筛选可查看全部任务。' :
    '看板尚无任务。任务由 Lead 经现有流程建立。';
  const blockers = tasks.filter(task => laneFor(task) === 'blocked').length;
  const questions = tasks.reduce((count, task) => count + pendingQuestions(task).length, 0);
  const cleanup = tasks.filter(task => task.cleanupPending).length;
  const invalidResults = tasks.filter(invalidClosedResult).length;
  const maintenance = state.snapshot?.maintenance;
  ui.attention.hidden = !(blockers || questions || cleanup || invalidResults || maintenance ||
    state.snapshot?.recoveryRequired);
  ui.attention.textContent = [blockers && `${blockers} 项阻塞`, questions && `${questions} 项待处理问询`,
    invalidResults && `${invalidResults} 项历史关闭结果已失效`,
    cleanup && `${cleanup} 项待安全收尾`, maintenance && `维护状态：${text(maintenance)}`,
    state.snapshot?.recoveryRequired && '恢复后待协调确认'].filter(Boolean).join(' · ');
  renderDetail();
}
function connection(message, retry = false) {
  ui.connection.textContent = message;
  ui.retry.hidden = !retry;
}
/** Close SSE before retrying; fresh snapshots avoid native EventSource's unbounded retry loop. */
function recover() {
  if (state.stopped) return;
  state.stream?.close();
  state.stream = null;
  connection(state.snapshot ? '连接中断 · 当前内容已过期' : '无法连接看板', true);
  if (state.attempt >= 5) {
    connection('重连已暂停 · 请手动重新连接', true);
    return;
  }
  clearTimeout(state.timer);
  state.timer = setTimeout(() => refresh(true), Math.min(1000 * 2 ** state.attempt++, 16000));
}
/** Coalesce invalidations without keeping event history; snapshot is the sole client data store. */
function queueRefresh() {
  if (state.refreshTimer || state.stopped) return;
  state.refreshTimer = setTimeout(() => {
    state.refreshTimer = null;
    refresh(false);
  }, 150);
}
function subscribe() {
  state.stream?.close();
  const snapshot = state.snapshot;
  const cursor = `${snapshot.generation}:${snapshot.eventSeq}`;
  if (sharedView) { subscribeShared(cursor); return; }
  const stream = new EventSource(`api/events?after=${encodeURIComponent(cursor)}`);
  state.stream = stream;
  stream.onopen = () => {
    if (state.stream !== stream) return;
    state.attempt = 0;
    connection('实时连接正常');
  };
  stream.addEventListener('change', () => {
    if (state.stream !== stream) return;
    // A new generation must never apply a partial update to an old snapshot.
    queueRefresh();
  });
  stream.addEventListener('reset', () => {
    if (state.stream !== stream) return;
    connection('事件记录已重置 · 正在完整同步');
    refresh(true);
  });
  stream.onerror = () => { if (state.stream === stream) recover(); };
}
/** Fetch streaming keeps the Board capability out of URLs and supports cancellation/backpressure. */
async function subscribeShared(cursor) {
  const controller = new AbortController();
  const stream = { close: () => controller.abort() };
  state.stream = stream;
  try {
    const response = await fetch(`api/events?after=${encodeURIComponent(cursor)}`, {
      headers: viewHeaders(), credentials: 'same-origin', signal: controller.signal, cache: 'no-store' });
    if (response.status === 401) { forgetView(); state.stopped = true; connection('访问凭据已失效 · 请让本会话重新打开看板'); return; }
    if (!response.ok || !response.body) throw Error('Stream unavailable');
    state.attempt = 0; connection('实时连接正常');
    const reader = response.body.getReader(), decoder = new TextDecoder();
    let buffer = '';
    while (state.stream === stream && !controller.signal.aborted) {
      const { value, done } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      if (buffer.length > 1048576) throw Error('Stream bound exceeded');
      let end;
      while ((end = buffer.indexOf('\n\n')) !== -1) {
        const event = buffer.slice(0, end); buffer = buffer.slice(end + 2);
        if (/^event: reset$/m.test(event)) { refresh(true); return; }
        if (/^event: change$/m.test(event)) queueRefresh();
      }
    }
    if (!controller.signal.aborted && state.stream === stream) recover();
  } catch { if (!controller.signal.aborted && state.stream === stream) recover(); }
}
/** Latest request wins. 401 stops retries; successful full snapshots reopen the gap-filled stream. */
async function refresh(full = true) {
  if (state.stopped) return;
  const request = ++state.request;
  state.controller?.abort();
  const controller = new AbortController();
  state.controller = controller;
  const timeout = setTimeout(() => controller.abort(), 15000);
  if (full) {
    state.stream?.close();
    state.stream = null;
    connection(state.snapshot ? '正在重连并完整同步 · 内容可能过期' : '正在完整同步');
  }
  try {
    const response = await fetch('api/snapshot', { credentials: 'same-origin', headers: viewHeaders(),
      cache: 'no-store', signal: controller.signal });
    if (request !== state.request) return;
    if (response.status === 401) {
      forgetView();
      state.stopped = true;
      state.stream?.close();
      clearTimeout(state.timer);
      clearTimeout(state.refreshTimer);
      connection('访问凭据已失效 · 请通过授权入口重新打开', false);
      if (!state.snapshot) ui.empty.textContent = '无法读取任务：访问凭据已失效。';
      return;
    }
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const snapshot = await response.json();
    if (request !== state.request) return;
    if (snapshot.schemaVersion !== 1 || !Array.isArray(snapshot.tasks) ||
      !Number.isSafeInteger(snapshot.eventSeq)) throw new Error('Unsupported snapshot');
    if (state.snapshot?.generation === snapshot.generation &&
      state.snapshot.revision > snapshot.revision) return;
    state.snapshot = snapshot;
    // Labels follow accepted snapshots; renames never replace identity or current view state.
    const profile = snapshot.sessionProfile;
    const boardName = profile ? `${profile.projectName} + ${profile.sessionName}` : '任务看板';
    ui['board-name'].textContent = boardName;
    document.title = boardName;
    // Protocol IDs remain in the snapshot and DOM bindings, outside reader-facing status text.
    ui.sync.textContent = `同步于 ${date(Date.now())}`;
    render();
    subscribe();
  } catch (error) {
    if (request === state.request) recover();
  } finally {
    clearTimeout(timeout);
  }
}
for (const id of ['search', 'role', 'instance', 'attention-only']) {
  ui[id].addEventListener(id === 'search' ? 'input' : 'change', render);
}
ui.clear.addEventListener('click', () => {
  ui.search.value = '';
  ui.role.value = '';
  ui.instance.value = '';
  ui['attention-only'].checked = false;
  render();
});
ui['close-detail'].addEventListener('click', () => {
  const selected = state.selected;
  state.selected = null;
  render();
  [...ui.board.querySelectorAll('button')].find(item => item.dataset.task === selected)
    ?.focus({ preventScroll: true });
});
ui.retry.addEventListener('click', () => {
  clearTimeout(state.timer);
  state.attempt = 0;
  refresh(true);
});
window.addEventListener('offline', recover);
window.addEventListener('online', () => { if (!state.stopped) refresh(true); });
refresh();
})();
