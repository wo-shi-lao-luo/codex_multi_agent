/** View committed task snapshots, inspect evidence, and confirm reviewed work. */
'use strict';

const elements = Object.fromEntries([
  'connection', 'sync-time',
  'session-list', 'group-mode', 'retry', 'catalog-warning', 'work', 'work-title', 'work-project',
  'work-summary', 'work-empty', 'tasks', 'task-detail', 'task-detail-title', 'task-detail-content',
  'work-confirmation-message', 'task-confirmation', 'task-confirmation-message', 'task-confirm-complete',
  'task-detail-close', 'reference-back', 'reference-preview', 'reference-title',
  'reference-status', 'reference-content',
].map(id => [id, document.getElementById(id)]));

const stateNames = new Map([
  ['planned', '计划'], ['open', '待分配'], ['ready', '就绪'], ['running', '进行中'], ['blocked', '阻塞'],
  ['submitted', '待核验'], ['closed', '已结束'], ['ended', '已结束'],
  ['canceled', '已放弃'], ['archived', '已归档'],
]);
const taskColumns = [
  { id: 'waiting', title: '待开始', empty: '暂无待开始的任务' },
  { id: 'active', title: '进行中', empty: '暂无进行中的任务' },
  { id: 'confirmation', title: '需要人工确认', empty: '暂无需要人工确认的任务' },
  { id: 'ended', title: '已结束', empty: '暂无已结束的任务' },
  { id: 'abandoned', title: '已放弃', empty: '暂无已放弃的任务' },
];
const columnForState = new Map([
  ['running', 'active'], ['blocked', 'active'], ['submitted', 'active'],
  ['closed', 'ended'], ['ended', 'ended'], ['archived', 'ended'], ['canceled', 'abandoned'],
]);
const activeStateOrder = new Map([['running', 0], ['blocked', 1], ['submitted', 2]]);
const roleNames = new Map([
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
const responsibilityLabels = new Map([
  ['executor', '执行者'], ['submitter', '提交者'],
  ['completed', '完成者'], ['historical', '历史完成人'],
]);
const submissionLabels = new Map([
  ['current', '当前待核验提交'], ['accepted', '已验收提交'],
  ['historical', '历史提交'], ['invalid', '历史验收提交（结果已失效）'],
]);
const questionLabels = new Map([
  ['pending', '待答复'], ['answered', '已答复，尚未应用'], ['applied', '已应用'],
  ['stale', '已过期'], ['approval-pending', '审批待决'],
  ['stale-approval-pending', '审批待决 · 原问询已过期'],
]);
const timeFormat = new Intl.DateTimeFormat('zh-CN', { dateStyle: 'medium', timeStyle: 'medium' });
const lastSessionKey = 'task-board:last-session';
const groupModeKey = 'task-board:group-by-activity';
const confirmationDragType = 'application/x-task-board-confirmation';
const state = {
  catalog: new Map(),
  catalogSignature: null,
  catalogRequest: null,
  catalogTimer: null,
  selected: null,
  lastSessionId: readPreference(lastSessionKey),
  groupByActivity: readPreference(groupModeKey) === 'true',
  viewCapability: null,
  viewRequest: null,
  confirmationDrag: null,
};

/** Persist only presentation preferences. A private browser can still use the current page. */
function readPreference(key) {
  try { return window.localStorage.getItem(key); } catch { return null; }
}

function savePreference(key, value) {
  try { window.localStorage.setItem(key, value); } catch { /* Keep in-memory state. */ }
}

/** Fresh tabs and restarted servers obtain a page capability automatically. */
async function getViewCapability() {
  if (state.viewCapability) return state.viewCapability;
  if (!state.viewRequest) {
    state.viewRequest = (async () => {
      const response = await fetch('/api/view', {
        method: 'POST',
        headers: { 'X-Task-Board-Bootstrap': '1' },
        signal: AbortSignal.timeout(8000),
      });
      requireSuccess(response);
      const capability = response.headers.get('X-Task-Board-View');
      if (!capability) throw new Error('Dashboard view capability missing.');
      state.viewCapability = capability;
      return capability;
    })().finally(() => { state.viewRequest = null; });
  }
  return state.viewRequest;
}

function node(tag, text, className) {
  const element = document.createElement(tag);
  element.textContent = text;
  if (className) element.className = className;
  return element;
}

function formatTime(value) {
  if (value == null || value === '') return '';
  const time = new Date(value);
  return Number.isNaN(time.getTime()) ? '' : timeFormat.format(time);
}

function showText(id, value) {
  elements[id].textContent = value;
  elements[id].hidden = !value;
}

function status(message) {
  if (elements.connection.textContent !== message) elements.connection.textContent = message;
}

function refreshStatus(view) {
  if (view.error) status(view.lastSync ? '更新暂不可用 · 正在重试' : '任务暂时无法读取');
  else if (!view.lastSync) status('正在同步任务');
  else status(view.live ? '实时更新' : '实时连接中断 · 正在重连');
  showText('sync-time', view.lastSync ? `上次同步 ${formatTime(view.lastSync)}` : '');
}

/** Preserve a visible, timestamped snapshot on temporary connection failures. */
function showCatalogWarning(text) {
  if (elements['catalog-warning'].textContent !== text) showText('catalog-warning', text);
}

async function callBoard(url, signal, options = {}) {
  const request = capability => fetch(url, {
    ...options,
    cache: 'no-store',
    signal,
    headers: { ...options.headers, 'X-Task-Board-View': capability },
  });
  const used = await getViewCapability();
  const response = await request(used);
  if (response.status !== 401) return response;
  if (state.viewCapability === used) state.viewCapability = null;
  return request(await getViewCapability());
}

function requireSuccess(response) {
  if (!response.ok) {
    throw Object.assign(new Error('Dashboard request failed.'), { status: response.status });
  }
}

function sessionUrl(kind, id) {
  return `/api/${kind}?${new URLSearchParams({ session: id })}`;
}

function stopSelected() {
  if (!state.selected) return false;
  const view = state.selected;
  state.selected = null;
  clearConfirmationDrag();
  resetReferencePreview(view);
  const dialog = elements['task-detail'];
  const wasOpen = dialog.open;
  if (wasOpen) dialog.close();
  clearTimeout(view.streamRetry);
  view.streamRequest?.abort();
  view.snapshotRequest?.abort();
  return wasOpen;
}

function roleName(role) {
  return roleNames.get(role) ?? role ?? '角色未记录';
}

function personName(person) {
  return person ? roleNames.get(person.role) ?? '角色未记录' : '未记录';
}

function candidatesText(task) {
  const roles = new Set(task.eligibleRoles ?? []);
  if (task.allowLeadInline) roles.add('lead');
  return `可承接：${[...roles].map(roleName).join(' / ') || '角色未指定'}`;
}

function responsibilityText(task) {
  const { kind, person } = task.responsibility ?? {};
  if (kind === 'canceled') return '已放弃 · 无完成者';
  const label = responsibilityLabels.get(kind);
  return label ? `${label}：${personName(person)}` : '未分配实例';
}

function showTaskDetail(task) {
  const view = state.selected;
  if (!view) return;
  const dialog = elements['task-detail'];
  if (!dialog.open || view.detailTaskId !== task.id) {
    resetReferencePreview(view);
    view.detailConfirmation = confirmationRequest(task);
  }
  view.detailTaskId = task.id;
  renderTaskDetail(task);
  if (!dialog.open) dialog.showModal();
}

function needsManualConfirmation(task) {
  return ['ready', 'waiting-for-submission'].includes(task?.manualConfirmation?.state)
    && !['closed', 'ended', 'canceled', 'archived'].includes(task.state);
}

/** Keep the steps and pass conditions visible on the card, including old cards without a guide. */
function manualGuide(task, headingTag) {
  if (!needsManualConfirmation(task)) return null;
  const { guide, state: confirmationState } = task.manualConfirmation;
  const section = node('section', '', 'manual-guide');
  section.append(node(headingTag, '人工核验'));
  if (!guide?.steps?.length) {
    const message = confirmationState === 'ready'
      ? '这张卡尚未附核验步骤，请先核对验收引用。'
      : '等候可确认的提交，核验步骤准备好后会显示在这里。';
    section.append(node('p', message, 'manual-guide-expected'));
    return section;
  }
  if (guide.setup) section.append(node('p', guide.setup, 'manual-guide-setup'));
  const steps = node('ol', '', 'manual-guide-steps');
  for (const step of guide.steps) {
    const item = node('li', '');
    item.append(node('p', step.action),
      node('p', `通过标准：${step.expected}`, 'manual-guide-expected'));
    steps.append(item);
  }
  section.append(steps);
  return section;
}

function confirmationRequest(task) {
  const confirmation = task?.manualConfirmation;
  if (!needsManualConfirmation(task) || confirmation.state !== 'ready') return null;
  return { taskId: task.id, taskRevision: confirmation.taskRevision, generation: confirmation.generation };
}

function sameConfirmation(a, b) {
  return Boolean(a && b && a.taskId === b.taskId && a.taskRevision === b.taskRevision
    && a.generation === b.generation);
}

function canConfirm(view, request) {
  if (!view || view !== state.selected || !request || view.pendingConfirmation) return false;
  const current = confirmationRequest(view.tasks?.get(request.taskId));
  return sameConfirmation(current, request)
    && !sameConfirmation(view.completedConfirmations.get(request.taskId), request);
}

/** Accept a drop only when it starts in this view with the same current result. */
function clearConfirmationDrag() {
  state.confirmationDrag = null;
  delete elements.tasks.dataset.confirmationDragging;
}

function dragConfirmation(event, task) {
  const view = state.selected;
  const request = confirmationRequest(task);
  if (!canConfirm(view, request) || !event.dataTransfer) {
    event.preventDefault();
    return;
  }
  event.dataTransfer.effectAllowed = 'move';
  event.dataTransfer.setData(confirmationDragType, '1');
  state.confirmationDrag = { view, request };
  elements.tasks.dataset.confirmationDragging = 'true';
}

function allowConfirmationDrop(event) {
  const drag = state.confirmationDrag;
  if (!drag || !canConfirm(drag.view, drag.request)
      || !Array.from(event.dataTransfer?.types ?? []).includes(confirmationDragType)) return false;
  event.preventDefault();
  event.dataTransfer.dropEffect = 'move';
  return true;
}

function dropConfirmation(event) {
  const drag = state.confirmationDrag;
  const accepted = allowConfirmationDrop(event);
  clearConfirmationDrag();
  if (accepted) void confirmTask(drag.view, drag.request);
}

function renderTaskCard(task) {
  const manual = needsManualConfirmation(task);
  let stateLabel = stateNames.get(task.state) ?? '状态未知';
  if (manual) stateLabel = '待人工确认';
  if (task.state === 'closed' && task.manualConfirmed === true) stateLabel = '已人工确认';
  const abandoned = task.state === 'canceled';
  const item = node('li', '', 'task');
  const header = node('div', '', 'task-heading');
  const badge = node('span', stateLabel, 'task-state');
  if (manual) badge.classList.add('manual-confirmation');
  else if (stateNames.has(task.state)) badge.classList.add(task.state);
  const title = node('button', task.title || '未命名任务', 'task-title-button');
  title.type = 'button';
  title.dataset.taskId = task.id;
  title.setAttribute('aria-haspopup', 'dialog');
  title.addEventListener('click', event => {
    event?.stopPropagation();
    showTaskDetail(task);
  });
  item.addEventListener('click', () => {
    title.focus({ preventScroll: true });
    showTaskDetail(task);
  });
  if (canConfirm(state.selected, confirmationRequest(task))) {
    item.draggable = true;
    item.addEventListener('dragstart', event => dragConfirmation(event, task));
    item.addEventListener('dragend', clearConfirmationDrag);
  }
  const heading = node('h4', '', 'task-title');
  heading.append(title);
  header.append(heading, badge);
  item.append(header);
  if (manual) item.append(manualGuide(task, 'h5'));

  item.append(node('p', candidatesText(task), 'subtle task-line'),
    node('p', responsibilityText(task), 'subtle task-line'));
  const phase = stateNames.get(task.phase) ?? task.phase;
  if (!manual && !abandoned && phase && phase !== stateLabel) {
    item.append(node('p', `阶段 · ${phase}`, 'subtle task-phase'));
  }
  if (task.state === 'open' && task.readinessReason) {
    item.append(node('p', task.readiness === 'ready' ? '就绪条件已满足' : task.readinessReason,
      'subtle task-line'));
  }
  if (!abandoned) item.append(node('p', task.progress || '尚无实际进展报告', 'task-progress'),
    node('p', `下一检查点：${task.nextCheckpoint || '尚未报告'}`, 'task-checkpoint'));
  const flags = [
    !manual && !abandoned && task.blocker && `阻塞：${task.blocker}`,
    abandoned && task.cancellationReason && `放弃说明：${task.cancellationReason}`,
    task.dependencyCount > 0 && `依赖 ${task.dependencyCount}`,
    task.pendingQuestionCount > 0 && `待处理问询 ${task.pendingQuestionCount}`,
    task.cleanupPending && '资源待安全收尾',
    task.needsReconcile && '待协调确认',
    task.state === 'closed' && task.resultValid === false && '历史结果已失效',
  ].filter(Boolean);
  if (flags.length) item.append(node('p', flags.join(' · '), 'task-warning'));
  const lastReport = formatTime(task.lastReportAt);
  const updated = formatTime(task.updatedAt);
  if (lastReport) item.append(node('p', `最近报告 ${lastReport}`, 'task-time'));
  if (updated && updated !== lastReport) item.append(node('p', `最近更新 ${updated}`, 'task-time'));
  return item;
}

function detailSection(title, entries) {
  const values = entries.filter(Boolean);
  if (!values.length) return null;
  const section = node('section', '', 'detail-section');
  section.append(node('h3', title),
    ...values.map(value => typeof value === 'string' ? node('p', value) : value));
  return section;
}

/** Bind only projected reference IDs. Older snapshots keep their readable, static labels. */
function referenceRows(task, labels, ids, prefix = '') {
  return (labels ?? []).map((label, index) => {
    const referenceId = ids?.[index];
    if (!referenceId) return `${prefix}${label}`;
    const row = node('p', prefix, 'detail-reference-row');
    const button = node('button', label, 'detail-reference-button');
    button.type = 'button';
    button.dataset.referenceId = referenceId;
    button.addEventListener('click', () => void openReferencePreview(task, referenceId, label));
    row.append(button);
    return row;
  });
}

function showReferencePane(show) {
  elements['reference-preview'].hidden = !show;
  elements['reference-back'].hidden = !show;
  elements['task-detail-content'].hidden = show;
  if (show) elements['task-confirmation'].hidden = true;
}

function resetReferencePreview(view) {
  view.referencePreview?.controller.abort();
  view.referencePreview = null;
  showReferencePane(false);
  elements['reference-content'].replaceChildren();
}

/** Return focus even if the task detail controls were rebuilt by a newer snapshot. */
function returnToReferences(view) {
  const preview = view?.referencePreview;
  if (!preview) return;
  resetReferencePreview(view);
  const task = view.tasks.get(view.detailTaskId);
  if (task) updateConfirmationControls(view, task);
  const trigger = [...elements['task-detail-content'].querySelectorAll('[data-reference-id]')]
    .find(button => button.dataset.referenceId === preview.referenceId);
  (trigger ?? elements['task-detail-close']).focus({ preventScroll: true });
  elements['task-detail'].scrollTop = preview.detailScroll;
}

/** Open one read-only request per click and ignore responses after leaving the selected preview. */
async function openReferencePreview(task, referenceId, label) {
  const view = state.selected;
  const dialog = elements['task-detail'];
  if (!view || view.detailTaskId !== task.id || !dialog.open) return;
  const detailScroll = view.referencePreview?.detailScroll ?? dialog.scrollTop;
  resetReferencePreview(view);
  const controller = new AbortController();
  const preview = { controller, referenceId, detailScroll };
  view.referencePreview = preview;
  showReferencePane(true);
  showText('reference-title', label);
  showText('reference-status', '正在读取引用…');
  dialog.scrollTop = 0;
  elements['reference-title'].focus({ preventScroll: true });
  const current = () => view === state.selected && view.referencePreview === preview && dialog.open;
  const parameters = new URLSearchParams({ session: view.id, task: task.id, ref: referenceId });
  const timeout = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await callBoard(`/api/reference?${parameters}`, controller.signal);
    requireSuccess(response);
    const result = await response.json();
    if (!current()) return;
    if (typeof result.content !== 'string') throw new Error('Invalid reference response.');
    renderReferenceContent(result);
  } catch (error) {
    if (!current()) return;
    const missing = [403, 404, 410].includes(error.status);
    showText('reference-status', missing
      ? '此引用已不存在或无法读取。返回任务详情查看其他引用。'
      : '暂时无法读取。返回任务详情后可重新打开这条引用。');
  } finally {
    clearTimeout(timeout);
  }
}

function renderReferenceContent({ format, content, truncated }) {
  const notice = truncated ? '显示文件的部分内容。' : '';
  showText('reference-status', content.trim() ? notice : '引用内容为空。');
  if (!content.trim()) return;
  const section = elements['reference-content'];
  if (format !== 'markdown') {
    section.replaceChildren(node('pre', content));
    return;
  }
  section.replaceChildren(...markdownBlocks(content));
}

/** Render common Markdown blocks as text nodes. Links, scripts and images stay as document text. */
function markdownBlocks(content) {
  const lines = content.split(/\r?\n/);
  if (lines.length > 1500) return [node('pre', content)];
  const blocks = [];
  let paragraph = [];
  let list = null;
  let fence = null;
  function flushParagraph() {
    if (paragraph.length) blocks.push(node('p', paragraph.join('\n')));
    paragraph = [];
  }
  for (const line of lines) {
    if (fence) {
      const closing = line.trim();
      if (closing.length >= fence.marker.length
          && [...closing].every(character => character === fence.marker[0])) {
        blocks.push(node('pre', fence.lines.join('\n')));
        fence = null;
      } else fence.lines.push(line);
      continue;
    }
    const fenceMarker = line.match(/^\s*(`{3,}|~{3,})/);
    const heading = line.match(/^(#{1,6})\s+(.+)$/);
    const bullet = line.match(/^\s*(?:([-+*])|(\d+)\.)\s+(\S.*)$/);
    if (bullet) {
      flushParagraph();
      const tag = bullet[2] ? 'ol' : 'ul';
      if (tag !== list?.tag) {
        const element = node(tag, '');
        list = { element, tag };
        blocks.push(element);
      }
      const item = node('li', bullet[3]);
      if (bullet[2]) item.setAttribute('value', bullet[2]);
      list.element.append(item);
      continue;
    }
    list = null;
    if (fenceMarker) {
      flushParagraph();
      fence = { marker: fenceMarker[1], opening: line, lines: [] };
    } else if (heading) {
      flushParagraph();
      blocks.push(node(`h${Math.min(heading[1].length + 3, 6)}`, heading[2]));
    } else if (!line.trim()) flushParagraph();
    else paragraph.push(line);
  }
  flushParagraph();
  if (fence) blocks.push(node('pre', [fence.opening, ...fence.lines].join('\n')));
  return blocks;
}

function questionText(question) {
  return [
    questionLabels.get(question.status) ?? question.status, question.question, question.step, question.impact,
    ...(question.options ?? []), question.recommendation && `建议：${question.recommendation}`,
    ...(question.checkedRefs ?? []),
    ...(question.answers ?? []).flatMap(answer => [
      answer.text && `答复：${answer.text}`, answer.decision,
      ...(answer.evidenceRefs ?? []),
    ]),
  ].filter(Boolean).join('\n');
}

function updateConfirmationControls(view, task) {
  const request = confirmationRequest(task);
  const changed = request && view?.detailTaskId === task.id
    && !sameConfirmation(view.detailConfirmation, request);
  let message = view?.confirmationMessage?.taskId === task.id ? view.confirmationMessage.text : '';
  if (changed) message = '待确认的结果已更新。请关闭后重新打开详情，核对最新结果。';
  const button = elements['task-confirm-complete'];
  const disabled = Boolean(changed) || !canConfirm(view, request);
  if (disabled && document.activeElement === button) elements['task-detail-close'].focus();
  button.hidden = !request;
  button.disabled = disabled;
  elements['task-confirmation'].hidden = Boolean(view?.referencePreview) || (!request && !message);
  showText('task-confirmation-message', message);
}

function reportConfirmation(view, request, message) {
  view.confirmationMessage = { taskId: request.taskId, text: message };
  showText('work-confirmation-message', message);
  const detail = view.tasks.get(view.detailTaskId);
  if (detail) updateConfirmationControls(view, detail);
}

/** Both gestures submit only the selected snapshot's acceptance request. Never move a card locally. */
async function confirmTask(view, request) {
  if (!canConfirm(view, request)) return;
  view.pendingConfirmation = request;
  clearConfirmationDrag();
  reportConfirmation(view, request, '正在保存人工确认…');

  let message;
  try {
    const response = await callBoard(sessionUrl('manual-confirmation', view.id),
      AbortSignal.timeout(8000), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(request),
      });
    if (response.status === 503) {
      const failure = await response.json().catch(() => null);
      if (failure?.error === 'CONFIRMATION_ARTIFACT_PROTECTION') {
        message = '项目的看板写入保护未满足。请由主 Agent 核对后再试。';
        return;
      }
    }
    requireSuccess(response);
    const result = await response.json();
    if (result.ok !== true) throw new Error('Missing confirmation receipt.');
    view.completedConfirmations.set(request.taskId, request);
    message = '已保存人工确认。';
  } catch (error) {
    if (error.status === 409) {
      message = '当前结果暂不能确认。请核对更新后的详情。';
    } else {
      message = '暂时无法核实确认结果。正在重新读取任务。';
    }
  } finally {
    view.pendingConfirmation = null;
    if (view === state.selected) {
      reportConfirmation(view, request, message);
      void refreshSnapshot(view);
    }
  }
}

function renderTaskDetail(task) {
  const detail = task.details ?? {};
  const previews = detail.referencePreviews ?? {};
  elements['task-detail-title'].textContent = task.title || '未命名任务';
  const result = task.resultValid === true ? '当前结果有效' :
    task.state === 'closed' && task.resultValid === false ? '历史已关闭 · 结果已失效' : '';
  const abandoned = task.state === 'canceled';
  const manual = needsManualConfirmation(task);
  const sections = [
    detailSection('角色与执行者', [candidatesText(task), responsibilityText(task), ...(detail.responsibilities ?? [])]),
    detailSection('任务说明', [detail.outcome]),
    manualGuide(task, 'h3'),
    detailSection('人工确认', [task.state === 'closed' && task.manualConfirmed === true && '已人工确认。']),
    detailSection('放弃记录', [task.cancellationReason,
      abandoned && task.cleanupPending && '资源待安全收尾']),
    detailSection(abandoned ? '历史进展' : '执行进展', [task.progress,
      task.nextCheckpoint && `${abandoned ? '放弃前的检查点' : '下一检查点'}：${task.nextCheckpoint}`,
      !manual && task.blocker && `${abandoned ? '当时的阻塞' : '阻塞'}：${task.blocker}`]),
    detailSection('执行与交接记录', (detail.executionHistory ?? []).map(record =>
      `${personName(record.person)}（${record.active ? '当前分配' : '分配已结束'}）`)),
    detailSection('来源与验收引用', [
      ...referenceRows(task, detail.sourceRefs, previews.sourceRefs, '来源：'),
      ...referenceRows(task, detail.acceptanceRefs, previews.acceptanceRefs, '验收：'),
    ]),
    detailSection('结果与提交', [result,
      ...referenceRows(task, detail.acceptanceEvidence, previews.acceptanceEvidence),
      ...(detail.submissions ?? []).flatMap((submission, index) => [
        `${submissionLabels.get(submission.kind) ?? '提交'} · ${personName(submission.person)}`,
        ...referenceRows(task, submission.evidenceRefs, previews.submissions?.[index]),
      ])]),
    detailSection('依赖与资源', [
      ...(detail.dependencies ?? []).map(dependency => `依赖：${dependency.title || '名称未记录'}`),
      ...(detail.resources ?? []).map(resource => `资源：${resource.key}${resource.mode ? `（${resource.mode}）` : ''}`),
      !abandoned && task.cleanupPending && '资源待安全收尾', task.needsReconcile && '任务待协调确认',
    ]),
    detailSection('问询与答复', (detail.questions ?? []).map(questionText)),
  ];
  elements['task-detail-content'].replaceChildren(...sections.filter(Boolean));
  const view = state.selected;
  if (view?.referencePreview
      && !Object.values(previews).flat(2).includes(view.referencePreview.referenceId)) {
    returnToReferences(view);
  } else updateConfirmationControls(view, task);
}

function restoreCardFocus(id) {
  if (!id) return;
  const button = [...elements.tasks.querySelectorAll('[data-task-id]')]
    .find(item => item.dataset.taskId === id);
  (button ?? elements['work-title']).focus({ preventScroll: true });
}

function renderTasks(tasks) {
  const view = state.selected;
  if (view) {
    view.tasks = new Map(tasks.map(task => [task.id, task]));
    for (const [id, request] of view.completedConfirmations) {
      if (!sameConfirmation(confirmationRequest(view.tasks.get(id)), request)) {
        view.completedConfirmations.delete(id);
      }
    }
  }
  const drag = state.confirmationDrag;
  if (drag && !canConfirm(drag.view, drag.request)) clearConfirmationDrag();

  const focused = document.activeElement?.dataset?.taskId;
  const grouped = new Map(taskColumns.map(({ id }) => [id, []]));
  for (const task of tasks) {
    const column = needsManualConfirmation(task)
      ? 'confirmation' : columnForState.get(task.state) ?? 'waiting';
    grouped.get(column).push(task);
  }
  // Keep the snapshot order within each state while surfacing work that is still in motion.
  grouped.get('active').sort((left, right) =>
    activeStateOrder.get(left.state) - activeStateOrder.get(right.state));
  elements.tasks.replaceChildren(...taskColumns.map(({ id, title, empty }) => {
    const items = grouped.get(id);
    const column = node('section', '', 'task-column');
    const heading = node('h3', title, 'column-title');
    heading.id = `task-column-${id}`;
    column.setAttribute('aria-labelledby', heading.id);
    const header = node('div', '', 'column-heading');
    header.append(heading, node('span', String(items.length), 'column-count'));
    const list = node('ul', '', 'column-tasks');
    list.append(...items.map(renderTaskCard));
    column.append(header, items.length ? list : node('p', empty, 'column-empty'));
    if (id === 'ended') {
      column.dataset.confirmationTarget = 'true';
      column.addEventListener('dragover', allowConfirmationDrop);
      column.addEventListener('drop', dropConfirmation);
    }
    return column;
  }));
  elements.tasks.hidden = false;
  showText('work-empty', '');
  const running = tasks.filter(task => task.state === 'running' && !needsManualConfirmation(task)).length;
  showText('work-summary', `${tasks.length} 项任务 · ${running} 项进行中`);
  const detailId = state.selected?.detailTaskId;
  if (detailId) {
    const current = tasks.find(task => task.id === detailId);
    if (current) renderTaskDetail(current);
    else elements['task-detail'].close();
  } else restoreCardFocus(focused);
}

function showSessionHeading(session) {
  elements['work-title'].textContent = session.sessionName;
  showText('work-project', session.projectName);
}

/** Replace selection atomically. Aborted or late requests cannot paint the next session. */
function selectSession(id) {
  const closedDetails = stopSelected();
  showText('sync-time', '');
  elements.work.hidden = false;
  elements.tasks.replaceChildren();
  elements.tasks.hidden = true;
  showText('work-summary', '');
  showText('work-confirmation-message', '');

  const session = state.catalog.get(id);
  if (!session) {
    elements['work-title'].textContent = '任务';
    showText('work-project', '');
    status('已连接看板');
    showText('work-empty', state.catalog.size ? '请从左侧选择会话。' : '暂无可查看的会话。');
    renderSidebar();
    if (closedDetails) elements['work-title'].focus({ preventScroll: true });
    return;
  }

  const view = {
    id, live: false, lastSync: null, error: false, refreshPending: false,
    tasks: new Map(),
    completedConfirmations: new Map(),
  };
  state.selected = view;
  state.lastSessionId = id;
  savePreference(lastSessionKey, id);
  showSessionHeading(session);
  renderSidebar();
  showText('work-empty', '正在读取任务…');
  refreshStatus(view);
  void refreshSnapshot(view);
  void followRevisions(view);
}

function sidebarProjects(sessions, headingTag, buttons) {
  const groups = new Map();
  for (const session of sessions) {
    if (!groups.has(session.projectKey)) {
      const project = node('section', '', 'sidebar-project');
      const list = node('ul', '', 'session-rows');
      project.append(node(headingTag, session.projectName, 'sidebar-project-name'), list);
      groups.set(session.projectKey, { project, list });
    }
    const row = node('li', '', 'session-row');
    const button = node('button', '', 'session-link');
    button.type = 'button';
    button.dataset.sessionId = session.id;
    if (session.id === state.selected?.id) button.setAttribute('aria-current', 'true');
    button.append(node('span', session.sessionName, 'session-label'));
  if (session.hasRunningTasks) {
    const activity = node('span', '进行中', 'session-activity');
    activity.title = '此会话有已开始且仍为进行中的看板任务';
    button.append(activity);
  }
    button.addEventListener('click', () => {
      if (state.selected?.id !== session.id) selectSession(session.id);
    });
    buttons.set(session.id, button);
    row.append(button);
    groups.get(session.projectKey).list.append(row);
  }
  return [...groups.values()].map(({ project }) => project);
}

/** Keep the sidebar stable during background refreshes, including keyboard focus. */
function renderSidebar() {
  const sessions = [...state.catalog.values()];
  const signature = JSON.stringify([state.groupByActivity, state.selected?.id,
    ...sessions.map(({ id, projectKey, projectName, sessionName, hasRunningTasks }) =>
      [id, projectKey, projectName, sessionName, Boolean(hasRunningTasks)])]);
  if (signature === state.catalogSignature) return;
  state.catalogSignature = signature;
  elements['group-mode'].setAttribute('aria-pressed', String(state.groupByActivity));
  elements['group-mode'].disabled = !sessions.length;
  const focused = document.activeElement?.dataset?.sessionId;
  const buttons = new Map();
  if (!sessions.length) {
    elements['session-list'].replaceChildren(node('p', '暂无可查看的会话。', 'catalog-empty'));
  } else if (state.groupByActivity) {
    elements['session-list'].replaceChildren(...[true, false].map(active => {
      const group = node('section', '', 'activity-group');
      const members = sessions.filter(session => Boolean(session.hasRunningTasks) === active);
      group.append(node('h3', active ? '进行中' : '无进行中任务', 'activity-heading'));
      group.append(...(members.length ? sidebarProjects(members, 'h4', buttons)
        : [node('p', '暂无会话', 'catalog-empty')]));
      return group;
    }));
  } else {
    elements['session-list'].replaceChildren(...sidebarProjects(sessions, 'h3', buttons));
  }
  buttons.get(focused)?.focus({ preventScroll: true });
}

function renderCatalog(sessions) {
  const previousId = state.selected?.id ?? state.lastSessionId;
  state.catalog = new Map(sessions.map(session => [session.id, session]));
  const session = previousId ? state.catalog.get(previousId) : sessions[0];
  if (!state.selected || session?.id !== state.selected.id) selectSession(session?.id);
  else {
    showSessionHeading(session);
    renderSidebar();
  }
  return Boolean(previousId && !session);
}

/** Refresh session discovery without overlapping requests or destroying an existing view on error. */
async function refreshCatalog() {
  if (state.catalogRequest) return;
  clearTimeout(state.catalogTimer);
  const request = new AbortController();
  state.catalogRequest = request;
  const timeout = setTimeout(() => request.abort(), 8000);
  try {
    const response = await callBoard('/api/sessions', request.signal);
    requireSuccess(response);
    const { sessions, unavailable } = await response.json();
    if (request !== state.catalogRequest) return;
    const missing = renderCatalog(sessions);
    const warnings = [];
    if (missing) warnings.push('上次查看的会话暂不可用。');
    if (unavailable) warnings.push(`${unavailable} 项会话来源暂时无法读取，系统会自动重试。`);
    showCatalogWarning(warnings.join(' '));
  } catch {
    if (request !== state.catalogRequest) return;
    if (!state.selected) status('会话列表暂不可用');
    showCatalogWarning('无法更新会话列表。系统会自动重试，也可以手动重新连接。');
  } finally {
    clearTimeout(timeout);
    if (state.catalogRequest === request) {
      state.catalogRequest = null;
      state.catalogTimer = setTimeout(refreshCatalog, 4000);
    }
  }
}

/** Coalesce revision notifications during a request into one follow-up snapshot read. */
async function refreshSnapshot(view) {
  if (view !== state.selected) return;
  if (view.snapshotRequest) {
    view.refreshPending = true;
    return;
  }
  const request = new AbortController();
  view.snapshotRequest = request;
  const timeout = setTimeout(() => request.abort(), 8000);
  try {
    const response = await callBoard(sessionUrl('snapshot', view.id), request.signal);
    requireSuccess(response);
    const { tasks } = await response.json();
    if (view !== state.selected) return;
    view.lastSync = Date.now();
    view.error = false;
    renderTasks(tasks);
  } catch {
    if (view !== state.selected) return;
    view.error = true;
    if (!view.lastSync) showText('work-empty', '暂时无法读取任务。可重新连接或切换会话。');
  } finally {
    clearTimeout(timeout);
    view.snapshotRequest = null;
    if (view === state.selected) {
      refreshStatus(view);
      if (view.refreshPending) {
        view.refreshPending = false;
        void refreshSnapshot(view);
      }
    }
  }
}

/** Read complete revision frames. Fetch allows the required private view header. */
async function followRevisions(view) {
  if (view !== state.selected || view.streamRequest) return;
  clearTimeout(view.streamRetry);
  const request = new AbortController();
  view.streamRequest = request;
  const connectTimeout = setTimeout(() => request.abort(), 8000);
  try {
    const response = await callBoard(sessionUrl('events', view.id), request.signal);
    requireSuccess(response);
    clearTimeout(connectTimeout);
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let pending = '';
    try {
      while (view === state.selected && view.streamRequest === request) {
        const { value, done } = await reader.read();
        if (done) break;
        pending += decoder.decode(value, { stream: true });
        let endOfFrame = pending.indexOf('\n\n');
        while (endOfFrame !== -1) {
          const frame = pending.slice(0, endOfFrame);
          pending = pending.slice(endOfFrame + 2);
          if (frame.startsWith('event: revision\n')) {
            view.live = true;
            void refreshSnapshot(view);
          }
          endOfFrame = pending.indexOf('\n\n');
        }
        if (pending.length > 16384) throw new Error('Dashboard stream frame too large.');
      }
    } finally {
      await reader.cancel().catch(() => {});
      reader.releaseLock();
    }
  } catch {
    // Keep the last observed snapshot visible while the stream reconnects.
  } finally {
    clearTimeout(connectTimeout);
    if (view === state.selected && view.streamRequest === request) {
      view.streamRequest = null;
      view.live = false;
      refreshStatus(view);
      view.streamRetry = setTimeout(() => void followRevisions(view), 2000);
    }
  }
}

elements['group-mode'].addEventListener('click', () => {
  state.groupByActivity = !state.groupByActivity;
  savePreference(groupModeKey, String(state.groupByActivity));
  renderSidebar();
});
elements['task-detail'].addEventListener('close', () => {
  if (!state.selected || elements['task-detail'].open) return;
  const id = state.selected.detailTaskId;
  resetReferencePreview(state.selected);
  state.selected.detailTaskId = null;
  state.selected.detailConfirmation = null;
  restoreCardFocus(id);
});
elements['reference-back'].addEventListener('click', () => returnToReferences(state.selected));
elements['task-detail'].addEventListener('cancel', event => {
  if (!state.selected?.referencePreview) return;
  event.preventDefault();
  returnToReferences(state.selected);
});
elements['task-confirm-complete'].addEventListener('click', () => {
  const view = state.selected;
  if (!view || view.referencePreview || !elements['task-detail'].open) return;
  void confirmTask(view, view.detailConfirmation);
});
elements.retry.addEventListener('click', () => {
  void refreshCatalog();
  const view = state.selected;
  if (!view) return;
  view.streamRequest?.abort();
  view.streamRequest = null;
  view.live = false;
  refreshStatus(view);
  void followRevisions(view);
  void refreshSnapshot(view);
});

// Remove the obsolete fragment from old local dashboard shortcuts.
if (window.location.hash.startsWith('#code=')) {
  window.history.replaceState(null, '', window.location.pathname + window.location.search);
}
void refreshCatalog();
