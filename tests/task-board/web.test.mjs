/** P3 static-resource contract against the real server; fixed reads are not database/browser E2E. */
import test from 'node:test';
import assert from 'node:assert/strict';
import { serve } from '../../packages/task-board/src/server/server.mjs';

/** Run the shipped closure with controllable transport/clipboard; this checks client
 * transitions only. Real browser and real server tests cover the separate boundaries. */
async function recoveryClient({ snapshotStatus = 401, streamStatus = 200,
  clipboard = 'available', networkFailure = false, delayFirstStream = false } = {}) {
  const { readFile } = await import('node:fs/promises');
  const vm = await import('node:vm');
  const elements = new Map(), requests = [], copies = [];
  let streamRequests = 0, finishFirstStream;
  const element = () => ({ textContent: '', value: '', checked: false, hidden: true,
    disabled: false, dataset: {}, children: [], handlers: {}, scrollLeft: 0,
    addEventListener(type, callback) { this.handlers[type] = callback; },
    setAttribute() {}, focus() { this.focused = true; }, select() { this.selected = true; },
    append(...items) { this.children.push(...items); },
    replaceChildren(...items) { this.children = items; }, querySelectorAll() { return []; } });
  const capability = 'ab'.repeat(32), route = `/boards/${'12'.repeat(32)}/`;
  const location = { origin: 'http://127.0.0.1:12345', pathname: route, hash: '#view=' + capability };
  const history = { state: {}, replaceState(state, _title, url) {
    this.state = state; location.hash = ''; assert.equal(url, route);
  } };
  const navigator = clipboard === 'missing' ? {} : { clipboard: { async writeText(value) {
    if (clipboard === 'denied') throw new Error('Clipboard permission denied');
    copies.push(value);
  } } };
  const context = vm.createContext({
    window: { location, history, addEventListener() {} }, navigator,
    document: { title: '', activeElement: null, createElement: element,
      getElementById(id) { if (!elements.has(id)) elements.set(id, element()); return elements.get(id); } },
    AbortController, TextDecoder, setTimeout: () => 1, clearTimeout() {},
    fetch: async (url, options) => {
      requests.push({ url, headers: options.headers });
      if (url === 'api/snapshot') {
        if (networkFailure && requests.length === 1) throw new Error('Network interrupted');
        return { status: snapshotStatus, ok: snapshotStatus === 200, json: async () => ({
          schemaVersion: 1, boardId: 'fixture', generation: 'g', revision: 1,
          eventSeq: 0, tasks: [], questions: [] }) };
      }
      if (delayFirstStream && streamRequests++ === 0) {
        return new Promise(resolve => { finishFirstStream = resolve; });
      }
      return { status: streamStatus, ok: streamStatus === 200,
        body: { getReader: () => ({ read: () => new Promise(() => {}) }) } };
    },
  });
  vm.runInContext(await readFile('packages/task-board/web/app.js', 'utf8'), context);
  const settle = () => new Promise(resolve => setImmediate(resolve));
  await settle();
  return { elements, requests, copies, capability, route, history, settle,
    rejectOldStream() { finishFirstStream({ status: 401, ok: false }); } };
}

// A copied view without authorization must show an actionable recovery area; copying
// its request carries only the canonical page address, never credentials or false success.
test('RECOVERY.snapshot401OffersSafeCopyWithoutPretendingConnected', async () => {
  const page = await recoveryClient();
  assert.equal(page.elements.get('access-recovery')?.hidden, false);
  assert.equal(page.elements.get('retry').hidden, true);
  const before = page.requests.length;
  await page.elements.get('copy-recovery-request').handlers.click();
  assert.equal(page.copies.length, 1);
  assert.ok(page.copies[0].includes(page.route));
  assert.ok(!page.copies[0].includes(page.capability));
  assert.ok(!/[?#]/.test(page.copies[0]), 'No ticket or fragment is copied');
  assert.match(page.elements.get('recovery-status').textContent, /粘贴.*发送/);
  assert.doesNotMatch(page.elements.get('connection').textContent, /实时连接正常/);
  assert.equal(page.requests.length, before, 'Copy does not resume polling or request authorization');
  assert.equal(page.history.state.taskBoardView, undefined);
});

// Stream authorization rejection must converge on the same recovery UX. Clipboard
// denial or absence exposes selectable text and never claims that copying succeeded.
for (const clipboard of ['denied', 'missing']) {
  test(`RECOVERY.stream401ManualFallback.${clipboard}`, async () => {
    const page = await recoveryClient({ snapshotStatus: 200, streamStatus: 401, clipboard });
    assert.equal(page.elements.get('access-recovery')?.hidden, false);
    assert.equal(page.elements.get('sync').textContent, '同步已停止 · 下方内容可能过期');
    const before = page.requests.length;
    await page.elements.get('copy-recovery-request').handlers.click();
    assert.equal(page.elements.get('recovery-manual').hidden, false);
    assert.equal(page.elements.get('recovery-request').selected, true);
    assert.match(page.elements.get('recovery-status').textContent, /手动复制/);
    assert.equal(page.copies.length, 0);
    assert.equal(page.requests.length, before);
    assert.equal(page.elements.get('retry').hidden, true);
  });
}

// A network interruption keeps the original proof and retries in place. It must
// reconnect rather than treating a transport error as loss of access authority.
test('RECOVERY.networkRetryKeepsAuthorizedSamePageFlow', async () => {
  const page = await recoveryClient({ snapshotStatus: 200, networkFailure: true });
  assert.equal(page.elements.get('retry').hidden, false);
  await page.elements.get('retry').handlers.click();
  await page.settle();
  assert.equal(page.elements.get('connection').textContent, '实时连接正常');
  assert.equal(page.elements.get('access-recovery').hidden, true);
  assert.equal(page.copies.length, 0);
  assert.ok(page.requests.every(request => request.headers['X-Task-Board-View'] === page.capability));
});

// A replaced stream may finish with 401 after a newer connection is healthy.
// Its obsolete response must not erase the current proof or show recovery UI.
test('RECOVERY.lateOldStream401CannotStopNewConnection', async () => {
  const page = await recoveryClient({ snapshotStatus: 200, delayFirstStream: true });
  await page.elements.get('retry').handlers.click();
  await page.settle();
  assert.equal(page.elements.get('connection').textContent, '实时连接正常');
  page.rejectOldStream();
  await page.settle();
  assert.equal(page.elements.get('access-recovery').hidden, true);
  assert.equal(page.elements.get('connection').textContent, '实时连接正常');
  assert.equal(page.history.state.taskBoardView.capability, page.capability);
});

// Legacy text/projection unit probes hoist the app closure only inside their isolated VM.
// They do not test browser authorization; shared capability tests use the unmodified source.
function legacyProjectionSource(source) {
  return "window.location = { pathname: '/', hash: '' };\n" + source
    .replace('(() => {\n', '').replace(/\}\)\(\);\s*$/, '');
}

// Execute the untouched app: private capability is cleared from URL, carried in headers,
// and split SSE frames invalidate the view without placing credentials in URLs/globals.
test('SHARED.webClosedCapabilityAndSplitFetchStream', async () => {
  const { readFile } = await import('node:fs/promises');
  const vm = await import('node:vm');
  const element = () => ({ textContent: '', value: '', checked: false, hidden: false,
    dataset: {}, children: [], scrollLeft: 0, addEventListener() {}, setAttribute() {}, focus() {},
    append(...items) { this.children.push(...items); }, replaceChildren(...items) { this.children = items; },
    querySelectorAll() { return []; } });
  const elements = new Map(), callbacks = [], requests = [];
  const capability = 'ab'.repeat(32), route = `/boards/${'12'.repeat(32)}/`;
  let cleared;
  const context = vm.createContext({
    document: { title: '', activeElement: null, createElement: element,
      getElementById(id) { if (!elements.has(id)) elements.set(id, element()); return elements.get(id); } },
    window: { location: { pathname: route, hash: '#view=' + capability },
      history: { replaceState(_state, _title, url) { cleared = url; } }, addEventListener() {} },
    AbortController, TextDecoder, setTimeout(fn, ms) { if (ms === 150) callbacks.push(fn); return 1; }, clearTimeout() {},
    fetch: async (url, options) => {
      requests.push({ url, headers: options.headers });
      if (url === 'api/snapshot') return { ok: true, status: 200, json: async () => ({ schemaVersion: 1,
        boardId: 'fixture', generation: 'g', revision: 1, eventSeq: 0, tasks: [], questions: [] }) };
      const chunks = ['event: cha', 'nge\ndata: {}\n\nevent: change\ndata: {}\n\n']; let n = 0;
      return { ok: true, status: 200, body: { getReader: () => ({ read: () => n < chunks.length
        ? Promise.resolve({ done: false, value: new TextEncoder().encode(chunks[n++]) }) : new Promise(() => {}) }) } };
    },
  });
  vm.runInContext(await readFile('packages/task-board/web/app.js', 'utf8'), context);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(cleared, route);
  assert.equal(vm.runInContext('typeof viewCapability', context), 'undefined');
  assert.equal(vm.runInContext('typeof state', context), 'undefined');
  assert.equal(requests.length, 2);
  assert.equal(callbacks.length, 1, 'Split/coalesced stream changes enqueue one refresh');
  for (const request of requests) {
    assert.equal(request.headers['X-Task-Board-View'], capability);
    assert.ok(!request.url.includes(capability)); assert.ok(!request.url.startsWith('/'));
  }
});

// A real reload starts a fresh JS closure with only the same history entry. Restore the
// capability for exactly its Board route, preserve unrelated state and erase rejected access.
test('SHARED.historyEntryRestoresOnlyItsBoardAndClearsOn401', async () => {
  const { readFile } = await import('node:fs/promises');
  const vm = await import('node:vm');
  const source=await readFile('packages/task-board/web/app.js','utf8');
  const route=`/boards/${'12'.repeat(32)}/`,capability='ab'.repeat(32);
  async function load(hash,entry,pathname=route,status=200) {
    const requests=[],elements=new Map();
    const element=()=>({textContent:'',value:'',checked:false,hidden:false,dataset:{},children:[],scrollLeft:0,
      addEventListener(){},setAttribute(){},focus(){},append(...x){this.children.push(...x);},replaceChildren(...x){this.children=x;},querySelectorAll(){return [];}});
    const location={pathname,hash};
    const history={state:entry,replaceState(state,_title,url){this.state=state;location.hash='';assert.equal(url,pathname);}};
    const context=vm.createContext({window:{location,history,addEventListener(){}},
      document:{title:'',activeElement:null,createElement:element,getElementById(id){if(!elements.has(id))elements.set(id,element());return elements.get(id);}},
      AbortController,TextDecoder,setTimeout:()=>1,clearTimeout(){},fetch:async(url,options)=>{
        requests.push({url,headers:options.headers});if(url!=='api/snapshot')return new Promise(()=>{});
        return {status,ok:status===200,json:async()=>({schemaVersion:1,boardId:'fixture',generation:'g',revision:1,eventSeq:0,tasks:[],questions:[]})};
      }});
    vm.runInContext(source,context);await new Promise(r=>setImmediate(r));
    return {history,requests,context};
  }
  const first=await load('#view='+capability,{unrelated:'preserved'});
  assert.equal(first.history.state.taskBoardView.capability,capability);
  assert.equal(first.history.state.unrelated,'preserved');
  const reloaded=await load('',JSON.parse(JSON.stringify(first.history.state)));
  assert.equal(reloaded.requests[0].headers['X-Task-Board-View'],capability);
  assert.equal(vm.runInContext('typeof viewCapability',reloaded.context),'undefined');
  const wrong=await load('',first.history.state,`/boards/${'34'.repeat(32)}/`,401);
  assert.equal(wrong.requests[0].headers['X-Task-Board-View'],undefined);
  assert.equal(wrong.history.state.taskBoardView,undefined);
  const rejected=await load('',first.history.state,route,401);
  assert.equal(rejected.history.state.taskBoardView,undefined);
  assert.equal(rejected.history.state.unrelated,'preserved');
});

// Scenario: an authenticated page requests the shipped resources from an owned loopback server.
// Expected: each trusted asset has nonempty HTTP 200 content of the declared MIME, anonymous
// access is denied, and serving resources leaves the fixed read projection unchanged.
test('P3.trustedAssets', async t => {
  const stored = {
    board: {
      schemaVersion: 3,
      boardId: 'web-asset-fixture',
      generation: 'web-asset-generation',
      boardRevision: 7,
      eventSeq: 9,
      replayFloor: 0,
      recoveryRequired: false,
    },
    tasks: [],
    workers: [],
    assignments: [],
    questions: [],
  };
  const original = structuredClone(stored);
  let snapshotCalls = 0;
  let eventCalls = 0;
  // The production service receives only read capabilities; no real queue or writer is exposed.
  const service = await serve({
    snapshot() {
      snapshotCalls++;
      return structuredClone(stored);
    },
    eventsAfter() {
      eventCalls++;
      throw new Error('Static asset requests must not subscribe to events');
    },
  });
  t.after(() => service.close());
  // Owned service startup may read/capture identity; measure asset reads independently.
  const startupReads = snapshotCalls;
  const request = (path, headers = {}) => fetch(new URL(path, service.url), {
    headers,
    redirect: 'manual',
    signal: AbortSignal.timeout(5000),
  });
  const ticket = await request(service.ticketUrl);
  assert.equal(ticket.status, 303, 'Bootstrap must reach the running production server');
  await ticket.text();
  const cookie = ticket.headers.get('set-cookie')?.split(';')[0];
  assert.ok(cookie, 'Bootstrap must establish an authenticated session');
  const headers = { Cookie: cookie };
  const beforeResponse = await request('/api/snapshot', headers);
  assert.equal(beforeResponse.status, 200);
  const before = await beforeResponse.json();
  assert.equal(snapshotCalls, startupReads + 1, 'Explicit before API reads one snapshot');
  const readsBeforeAssets = snapshotCalls;
  const observed = [];
  for (const [path, mime] of [
    ['/', 'text/html'],
    ['/app.js', 'text/javascript'],
    ['/style.css', 'text/css'],
  ]) {
    const denied = await request(path);
    assert.equal(denied.status, 401, `${path}: anonymous access`);
    await denied.text();
    const response = await request(path, headers);
    const body = await response.text();
    observed.push({ path, status: response.status,
      mime: response.headers.get('content-type'), nonempty: body.trim().length > 0 });
  }
  assert.equal(snapshotCalls, readsBeforeAssets, 'Asset loop must add zero snapshot reads');
  const afterResponse = await request('/api/snapshot', headers);
  assert.equal(afterResponse.status, 200);
  const after = await afterResponse.json();
  assert.deepEqual(after, before, 'Read-only HTTP requests must preserve the projection');
  assert.deepEqual(stored, original, 'The fixed fixture must remain unchanged');
  assert.equal(snapshotCalls, readsBeforeAssets + 1, 'Only explicit after API adds one read');
  assert.equal(eventCalls, 0, 'Assets must not create event subscriptions');
  assert.deepEqual(observed, [
    { path: '/', status: 200, mime: 'text/html', nonempty: true },
    { path: '/app.js', status: 200, mime: 'text/javascript', nonempty: true },
    { path: '/style.css', status: 200, mime: 'text/css', nonempty: true },
  ], 'Trusted page, script and style must all be delivered by the production server');
});

// Scenario: an approval hold has an obsolete question binding, alongside genuinely terminal history.
// Expected: stale+approvalPending remains pending/attention; terminal stale and applied history do
// not count. This executes actual client projection functions, not browser rendering or DOM safety.
test('P3.approvalHoldClassification', async () => {
  const { readFile } = await import('node:fs/promises');
  const vm = await import('node:vm');
  const source = legacyProjectionSource(await readFile('packages/task-board/web/app.js', 'utf8'));
  const context = vm.createContext({
    document: { getElementById: () => ({ addEventListener() {} }) },
    window: { addEventListener() {} },
    AbortController,
    // Hold bootstrap HTTP unresolved so this unit test observes projection only, with no network.
    fetch: () => new Promise(() => {}),
    setTimeout: () => 0,
    clearTimeout() {},
  });
  vm.runInContext(source, context, { filename: 'production-web-app.js' });
  const actual = JSON.parse(vm.runInContext(`
    state.snapshot = { questions: [
      { id: 'approval', taskId: 'held', state: 'stale', approvalPending: true },
      { id: 'terminal', taskId: 'history', state: 'stale', approvalPending: false },
      { id: 'applied', taskId: 'history', state: 'applied' }
    ] };
    JSON.stringify({
      pending: pendingQuestions({ id: 'held' }).map(question => question.id),
      heldAttention: needsAttention({ id: 'held', state: 'running' }),
      historyPending: pendingQuestions({ id: 'history' }).map(question => question.id),
      historyAttention: needsAttention({ id: 'history', state: 'running' })
    });
  `, context));
  assert.deepEqual(actual, { pending: ['approval'], heldAttention: true,
    historyPending: [], historyAttention: false });
});

// Scenario: detail text presents stale approval holds alongside expired/applied history.
// Expected: approval authority and stale origin are both explicit, while history retains its
// terminal labels. This test-after text-sink observation does not establish browser layout/focus.
test('P3.approvalHoldDetailText', async () => {
  const { readFile } = await import('node:fs/promises');
  const vm = await import('node:vm');
  // Minimal text sinks capture text assigned by real renderDetail; no HTML parser is simulated.
  const element = () => ({
    textContent: '', children: [], addEventListener() {},
    append(...items) { this.children.push(...items); },
    replaceChildren(...items) { this.children = items; },
  });
  const context = vm.createContext({
    document: { getElementById: element, createElement: element },
    window: { addEventListener() {} }, AbortController,
    fetch: () => new Promise(() => {}), setTimeout: () => 0, clearTimeout() {},
  });
  vm.runInContext(legacyProjectionSource(await readFile('packages/task-board/web/app.js', 'utf8')), context,
    { filename: 'production-web-app.js' });
  const actual = JSON.parse(vm.runInContext(`
    state.snapshot = { tasks: [{ id: 'held', title: 'held' }], questions: [
      { id: 'approval', taskId: 'held', state: 'stale', approvalPending: true },
      { id: 'terminal', taskId: 'held', state: 'stale', approvalPending: false },
      { id: 'applied', taskId: 'held', state: 'applied' }
    ] };
    state.selected = 'held';
    renderDetail();
    const questionSection = ui['detail-content'].children.find(section =>
      section.children?.[0]?.textContent === '问询与答复');
    JSON.stringify(questionSection.children.slice(1).map(paragraph =>
      paragraph.textContent.split('\\n')[0]));
  `, context));
  assert.deepEqual(actual, ['审批待决 · 原问询已过期', '已过期', '已应用']);
});


// Scenario: approval detail receives realistic question/answer records with internal binding metadata.
// Expected: readers see separate human question, answer and decision labels, not serialized record
// JSON/fingerprint/epoch fields. Actual renderDetail executes with plaintext sinks; no browser claim.
test('P3.humanQuestionAnswerDetail', async () => {
  const { readFile } = await import('node:fs/promises');
  const vm = await import('node:vm');
  const element = () => ({
    textContent: '', children: [], addEventListener() {},
    append(...items) { this.children.push(...items); },
    replaceChildren(...items) { this.children = items; },
  });
  const context = vm.createContext({
    document: { getElementById: element, createElement: element },
    window: { addEventListener() {} }, AbortController,
    fetch: () => new Promise(() => {}), setTimeout: () => 0, clearTimeout() {},
  });
  vm.runInContext(legacyProjectionSource(await readFile('packages/task-board/web/app.js', 'utf8')), context,
    { filename: 'production-web-app.js' });
  const result = JSON.parse(vm.runInContext(`
    state.snapshot = { tasks: [{ id: 'held', title: '审批示例' }], questions: [{
      id: 'question-human', taskId: 'held', state: 'stale', approvalPending: true,
      step: '确认当前输出要求', question: '当前任务可以扩大范围吗？',
      checkedRefs: ['fixture/contract#current'], options: ['维持范围', '提交审批'],
      recommendation: '提交审批', impact: '当前执行暂停',
      fingerprint: 'private-fingerprint-evidence', executionRevision: 12,
      workerEpoch: 'private-worker-epoch', assignmentId: 'private-assignment-binding'
    }], answers: [{ id: 'answer-human', questionId: 'question-human',
      text: '先取得明确批准，再继续执行。', decision: 'needs-approval',
      evidenceRefs: ['fixture/approval#pending'], answeredAt: '2026-11-09T01:00:00Z',
      answerRevision: 2, taskInputRevision: 4 }] };
    state.selected = 'held';
    renderDetail();
    const questionBlock = ui['detail-content'].children.find(item =>
      item.children?.[0]?.textContent === '问询与答复');
    function content(item) {
      return [item.textContent, ...(item.children ?? []).flatMap(content)].filter(Boolean);
    }
    JSON.stringify(content(questionBlock));
  `, context));
  const text = result.join('\n');
  const lines = text.split('\n').map(line => line.trim());
  assert.ok(lines.some(line => /^(问题[：:]\s*)?当前任务可以扩大范围吗？$/.test(line)),
    'Question must be independently readable, rather than embedded in serialized JSON');
  assert.ok(lines.some(line => /^(答复[：:]\s*)?先取得明确批准，再继续执行。$/.test(line)),
    'Answer must be independently readable, rather than embedded in serialized JSON');
  assert.match(text, /审批待决/);
  assert.match(text, /原问询已过期/);
  assert.match(text, /需要审批|审批待决/);
  for (const internal of ['private-fingerprint-evidence', 'private-worker-epoch',
    'private-assignment-binding', '"fingerprint"', '"executionRevision"']) {
    assert.ok(!text.includes(internal), `Detail must not dump internal metadata: ${internal}`);
  }
});


// Scenario: complete client accepts named snapshot, then a renamed hostile/long profile and legacy snapshot.
// Expected: literal project + session document title updates through actual async refresh while user
// filters/selection persist; absent profile restores generic title. This is a VM/data-flow test only.
test('P3.sessionTitleSnapshotRefresh', async () => {
  const { readFile } = await import('node:fs/promises');
  const vm = await import('node:vm');
  // Minimal DOM sinks support whole-app rendering without parsing HTML or claiming browser safety.
  const element = () => ({ textContent: '', value: '', checked: false, hidden: false,
    dataset: {}, children: [], scrollLeft: 0, addEventListener() {}, setAttribute() {}, focus() {},
    append(...items) { this.children.push(...items); },
    replaceChildren(...items) { this.children = items; }, querySelectorAll() { return []; },
  });
  const elements = new Map();
  const heading = element();
  heading.textContent = '任务看板';
  const document = { title: '任务看板', activeElement: null,
    getElementById(id) {
      if (id === 'board-name') return heading;
      if (!elements.has(id)) elements.set(id, element());
      return elements.get(id);
    },
    createElement: element, querySelector: () => heading };
  let snapshot = { schemaVersion: 1, boardId: 'title-board', generation: 'title-generation',
    revision: 1, eventSeq: 1, tasks: [{ id: 'selected', title: '保留的任务', state: 'planned' }],
    sessionProfile: { projectName: '测试项目', sessionName: '主会话', labelRevision: 0 } };
  const context = vm.createContext({ document, window: { addEventListener() {} }, AbortController,
    fetch: async () => ({ status: 200, ok: true, json: async () => structuredClone(snapshot) }),
    setTimeout: () => 1, clearTimeout() {},
    EventSource: class { addEventListener() {} close() {} },
  });
  vm.runInContext(legacyProjectionSource(await readFile('packages/task-board/web/app.js', 'utf8')), context,
    { filename: 'production-web-app.js' });
  await vm.runInContext('refresh(false)', context);
  assert.equal(vm.runInContext('state.snapshot.revision', context), 1,
    'Current real app must reach successful snapshot application before title assertion');
  assert.equal(document.title, '测试项目 + 主会话',
    'Named snapshot must replace the generic document title with the literal display pair');
  assert.equal(heading.textContent, '测试项目 + 主会话');
  vm.runInContext("ui.search.value = '保留'; ui.role.value = 'backend'; state.selected = 'selected';", context);
  const hostile = '<img src=x onerror=alert(1)> ' + '很长的会话名称'.repeat(20);
  snapshot = { ...snapshot, revision: 2, eventSeq: 2,
    sessionProfile: { projectName: '重命名项目', sessionName: hostile, labelRevision: 1 } };
  await vm.runInContext('refresh(false)', context);
  assert.equal(document.title, `重命名项目 + ${hostile}`);
  assert.equal(heading.textContent, document.title);
  assert.deepEqual(JSON.parse(vm.runInContext('JSON.stringify({ search: ui.search.value, role: ui.role.value, selected: state.selected })', context)),
    { search: '保留', role: 'backend', selected: 'selected' });
  const { sessionProfile, ...legacy } = snapshot;
  snapshot = { ...legacy, revision: 3, eventSeq: 3 };
  await vm.runInContext('refresh(false)', context);
  assert.equal(document.title, '任务看板');
  assert.equal(heading.textContent, '任务看板');
});


// Read-only usability summary uses the full visible snapshot, and report time never falls back to edits.
test('Usability.webSummaryReportTimeAndScope', async () => {
  const { readFile } = await import('node:fs/promises');
  const vm = await import('node:vm');
  const element = () => ({ textContent: '', value: '', checked: false, hidden: false,
    dataset: {}, children: [], scrollLeft: 0, className: '', addEventListener() {},
    setAttribute() {}, focus() {}, append(...items) { this.children.push(...items); },
    replaceChildren(...items) { this.children = items; }, querySelectorAll() { return []; } });
  const elements = new Map(['summary-ready', 'summary-running', 'summary-attention',
    'filtered-count', 'session-scope-note'].map(id => [id, element()]));
  const heading = element();
  const document = { title: '任务看板', activeElement: null,
    getElementById(id) {
      if (id === 'board-name') return heading;
      if (!elements.has(id)) elements.set(id, element());
      return elements.get(id);
    }, createElement: element, querySelector: () => heading };
  const snapshot = { schemaVersion: 1, boardId: 'usability', generation: 'generation',
    revision: 1, eventSeq: 1, tasks: [
      { id: 'ready', title: '待领取', state: 'open', readiness: 'ready' },
      { id: 'running', title: '执行中', state: 'running', lastReportAt: '2026-11-09T01:00:00.000Z' },
      { id: 'blocked', title: '等待输入', state: 'blocked', updatedAt: '2035-01-01T00:00:00.000Z' },
    ], questions: [] };
  const context = vm.createContext({ document, window: { addEventListener() {} }, AbortController,
    fetch: async () => ({ ok: true, status: 200, json: async () => structuredClone(snapshot) }),
    setTimeout: () => 1, clearTimeout() {}, EventSource: class { addEventListener() {} close() {} } });
  vm.runInContext(legacyProjectionSource(await readFile('packages/task-board/web/app.js', 'utf8')), context);
  await vm.runInContext('refresh(false)', context);
  assert.equal(vm.runInContext('state.snapshot.revision', context), 1,
    'Whole real app must apply the snapshot before checking new usability behavior');
  assert.equal(elements.get('summary-ready').textContent, '1');
  assert.equal(elements.get('summary-running').textContent, '1');
  assert.equal(elements.get('summary-attention').textContent, '1');
  assert.equal(elements.get('session-scope-note').textContent,
    '不同会话仍可能修改相同文件；此板不提供跨会话文件互斥');
  const flatten = item => [item, ...(item.children ?? []).flatMap(flatten)];
  const reports = flatten(elements.get('board')).filter(item =>
    item.className?.split(' ').includes('report-time')).map(item => item.textContent);
  assert.equal(reports.length, 3);
  assert.equal(reports.filter(value => value.includes('未知')).length, 2,
    'A legacy task with updatedAt still has unknown actual report time');
  vm.runInContext("ui.search.value = '执行中'; render();", context);
  assert.equal(elements.get('filtered-count').textContent, '当前显示 1 / 全部 3');
  assert.equal(elements.get('summary-ready').textContent, '1', 'Search does not redefine global ready count');
  assert.equal(elements.get('summary-running').textContent, '1');
});

// Actual public producer marks non-open tasks non-ready; that alone must not imply operational trouble.
test('Usability.webAttentionUsesActualProjectedFacts', async () => {
  const { domainFixture } = await import('./domain-fixture.mjs');
  const { publicSnapshot } = await import('../../packages/task-board/src/coordination/service.mjs');
  const { readFile } = await import('node:fs/promises');
  const vm = await import('node:vm');
  const f = domainFixture();
  f.tx.board = { ...f.tx.board, schemaVersion: 3, boardId: 'actual-attention', boardRevision: 1,
    eventSeq: 1, replayFloor: 0 };
  for (const id of ['running', 'submitted', 'closed', 'canceled', 'blocked']) f.add(id);
  f.claim('running');
  for (const id of ['submitted', 'closed']) {
    const owner = f.claim(id);
    f.submit(owner.owner);
  }
  f.run('accept', { taskId: 'closed', gatesSatisfied: true, evidenceRefs: ['fixture/review#pass'] });
  f.run('release', { taskId: 'closed', writesStopped: true, processStopped: true,
    evidenceRefs: ['fixture/cleanup#stopped'] });
  f.run('cancel', { taskId: 'canceled' });
  const blocked = f.claim('blocked');
  f.run('block', { ...blocked.owner, blocker: 'Actual missing input' });
  f.add('open-blocked', [{ taskId: 'running', gate: 'accepted-result' }]);
  const snapshot = { board: f.tx.board };
  for (const name of ['tasks', 'workers', 'grants', 'assignments', 'reservations',
    'taskResources', 'submissions', 'questions', 'answers', 'dependencies']) snapshot[name] = f.tx[name].list();
  const projected = publicSnapshot(snapshot);
  assert.equal(projected.tasks.find(task => task.id === 'running').readiness, 'blocked',
    'Exercise actual producer semantics: running is not a claim candidate');
  const context = vm.createContext({
    document: { getElementById: () => ({ addEventListener() {} }) },
    window: { addEventListener() {} }, AbortController,
    fetch: () => new Promise(() => {}), setTimeout: () => 0, clearTimeout() {}, projected,
  });
  vm.runInContext(legacyProjectionSource(await readFile('packages/task-board/web/app.js', 'utf8')), context);
  const actual = JSON.parse(vm.runInContext(`
    state.snapshot = projected;
    JSON.stringify(Object.fromEntries(projected.tasks.map(task => [task.id, needsAttention(task)])));
  `, context));
  assert.equal(actual.running, false, 'Healthy assigned work is not attention just because it is not ready');
  assert.equal(projected.tasks.find(task => task.id === 'submitted').cleanupPending, true);
  assert.equal(actual.submitted, true, 'Submitted work still needs its actual pending cleanup');
  assert.equal(actual.closed, false);
  assert.equal(actual.canceled, false);
  assert.equal(actual.blocked, true);
  assert.equal(actual['open-blocked'], true);
});
