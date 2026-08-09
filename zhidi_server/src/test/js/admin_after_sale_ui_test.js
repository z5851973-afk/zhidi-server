const html = readFile('src/main/resources/static/admin.html');
const scriptMatch = html.match(/<script>([\s\S]*?)<\/script>/);
if (!scriptMatch) throw new Error('admin.html inline script missing');

const ids = {};
for (const match of html.matchAll(/id="([^"]+)"/g)) {
  ids[match[1]] = fakeElement();
}

function fakeElement() {
  return {
    value: '',
    textContent: '',
    innerHTML: '',
    disabled: false,
    style: {},
    dataset: {},
    classList: { add() {}, remove() {} },
    focus() {},
  };
}

const stored = {};
const calls = [];
let failAfterSaleRefresh = false;
let deferredReplyResolve;
globalThis.window = globalThis;
globalThis.document = {
  getElementById(id) { return ids[id] || null; },
  querySelectorAll() { return []; },
};
globalThis.localStorage = {
  getItem(key) { return stored[key] || null; },
  setItem(key, value) { stored[key] = value; },
  removeItem(key) { delete stored[key]; },
};
globalThis.setTimeout = () => 0;
globalThis.confirm = () => true;
globalThis.fetch = (path, options = {}) => {
  calls.push({ path, options });
  if (failAfterSaleRefresh
      && (!options.method || options.method === 'GET')
      && (path === '/api/v1/admin/dashboard'
        || path.startsWith('/api/v1/admin/after-sales'))) {
    return Promise.resolve(apiResponse({}, false, 503, 'REFRESH_UNAVAILABLE'));
  }
  let data = {};
  if (path === '/api/v1/admin/dashboard') {
    data = {};
  } else if (options.method === 'PUT' && path.endsWith('/accept')) {
    data = { id: 'ticket-1', status: 'PLATFORM_PROCESSING' };
  } else if (options.method === 'POST' && path.endsWith('/events')) {
    if (deferredReplyResolve === null) {
      return new Promise(resolve => { deferredReplyResolve = resolve; });
    }
    data = { id: 'event-1' };
  } else if (options.method === 'PUT' && path.endsWith('/resolve')) {
    data = { id: 'ticket-1', status: 'RESOLVED' };
  } else if (options.method === 'PUT' && path.endsWith('/close')) {
    data = { id: 'ticket-1', status: 'CLOSED' };
  } else {
    data = { content: [] };
  }
  return Promise.resolve(apiResponse(data));
};

function apiResponse(
  data,
  ok = true,
  status = 200,
  code = 'OK',
) {
  return {
    ok,
    status,
    text: () => Promise.resolve(JSON.stringify({ code, data })),
  };
}

eval(scriptMatch[1]);
ids.token.value = 'admin-token';

function assertEqual(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

function assertActionState(status, expected) {
  window.selectAfterSale('ticket-1', status);
  assertEqual(ids.acceptAfterSale.disabled, !expected.accept, `${status} accept gate`);
  assertEqual(ids.replyAfterSale.disabled, !expected.reply, `${status} reply gate`);
  assertEqual(ids.resolveAfterSale.disabled, !expected.resolve, `${status} resolve gate`);
  assertEqual(ids.closeAfterSale.disabled, !expected.close, `${status} close gate`);
  assertEqual(ids.deduction.disabled, !expected.resolve, `${status} deduction gate`);
}

async function invoke(element) {
  await element.onclick();
  drainMicrotasks();
}

async function run() {
  assertActionState('OPEN', {
    accept: true, reply: false, resolve: false, close: false,
  });
  assertActionState('PLATFORM_PROCESSING', {
    accept: false, reply: true, resolve: true, close: false,
  });
  assertActionState('RESOLVED', {
    accept: false, reply: false, resolve: false, close: true,
  });
  assertActionState('CLOSED', {
    accept: false, reply: false, resolve: false, close: false,
  });

  ids.afterSaleReply.value = '不能带到新工单的回复';
  ids.resolution.value = '不能带到新工单的方案';
  ids.deduction.value = '88.88';
  ids.afterSaleCloseContent.value = '不能带到新工单的关闭说明';
  window.selectAfterSale('ticket-2', 'PLATFORM_PROCESSING');
  assertEqual(ids.afterSaleReply.value, '', 'switching ticket clears reply draft');
  assertEqual(ids.resolution.value, '', 'switching ticket clears resolution draft');
  assertEqual(ids.deduction.value, '', 'switching ticket clears deduction draft');
  assertEqual(ids.afterSaleCloseContent.value, '', 'switching ticket clears close draft');

  window.selectAfterSale('ticket-1', 'OPEN');
  failAfterSaleRefresh = true;
  await invoke(ids.acceptAfterSale);
  failAfterSaleRefresh = false;
  let action = calls.find(call => call.path.endsWith('/accept'));
  assertEqual(action.path, '/api/v1/admin/after-sales/ticket-1/accept', 'accept path');
  assertEqual(action.options.method, 'PUT', 'accept method');
  assertEqual(
    ids.selectedAfterSaleStatus.value,
    '平台处理中',
    'successful mutation keeps its new state when refresh fails',
  );
  assertEqual(
    ids.toast.textContent,
    '售后工单已受理，可回复双方或提交解决方案；数据刷新失败，请手动刷新',
    'refresh failure must not be reported as mutation failure',
  );

  window.selectAfterSale('ticket-1', 'PLATFORM_PROCESSING');
  ids.afterSaleReply.value = '请师傅三日内返修';
  deferredReplyResolve = null;
  const firstReply = ids.replyAfterSale.onclick();
  drainMicrotasks();
  assertEqual(ids.acceptAfterSale.disabled, true, 'pending disables accept');
  assertEqual(ids.replyAfterSale.disabled, true, 'pending disables reply');
  assertEqual(ids.resolveAfterSale.disabled, true, 'pending disables resolve');
  assertEqual(ids.closeAfterSale.disabled, true, 'pending disables close');
  const replyCallsWhilePending = calls.filter(call => call.path.endsWith('/events')).length;
  await invoke(ids.replyAfterSale);
  assertEqual(
    calls.filter(call => call.path.endsWith('/events')).length,
    replyCallsWhilePending,
    'double click must not repeat reply request',
  );
  deferredReplyResolve(apiResponse({ id: 'event-1' }));
  deferredReplyResolve = undefined;
  drainMicrotasks();
  await firstReply;
  action = calls.find(call => call.path.endsWith('/events'));
  assertEqual(action.options.method, 'POST', 'reply method');
  assertEqual(JSON.parse(action.options.body).content, '请师傅三日内返修', 'reply content');

  window.selectAfterSale('ticket-1', 'PLATFORM_PROCESSING');
  ids.resolution.value = '返修并扣减履约质保金';
  ids.deduction.value = '30.50';
  await invoke(ids.resolveAfterSale);
  action = calls.find(call => call.path.endsWith('/resolve'));
  const resolution = JSON.parse(action.options.body);
  assertEqual(action.options.method, 'PUT', 'resolve method');
  assertEqual(resolution.resolution, '返修并扣减履约质保金', 'resolution body');
  assertEqual(resolution.warrantyDeductionAmount, 30.5, 'warranty deduction body');

  window.selectAfterSale('ticket-1', 'PLATFORM_PROCESSING');
  ids.resolution.value = '金额输入错误时不应发请求';
  ids.deduction.value = '0';
  const resolveCallsBeforeInvalidInput = calls.filter(
    call => call.path.endsWith('/resolve'),
  ).length;
  await invoke(ids.resolveAfterSale);
  const resolveCallsAfterInvalidInput = calls.filter(
    call => call.path.endsWith('/resolve'),
  ).length;
  assertEqual(
    resolveCallsAfterInvalidInput,
    resolveCallsBeforeInvalidInput,
    'zero warranty deduction must be rejected before request',
  );
  assertEqual(ids.toast.textContent, '质保金扣减金额必须大于 0', 'invalid deduction feedback');

  window.selectAfterSale('ticket-1', 'PLATFORM_PROCESSING');
  ids.resolution.value = '小数超过两位时不应发请求';
  ids.deduction.value = '0.001';
  const resolveCallsBeforeExcessPrecision = calls.filter(
    call => call.path.endsWith('/resolve'),
  ).length;
  await invoke(ids.resolveAfterSale);
  assertEqual(
    calls.filter(call => call.path.endsWith('/resolve')).length,
    resolveCallsBeforeExcessPrecision,
    'warranty deduction with over two decimals must be rejected',
  );
  assertEqual(
    ids.toast.textContent,
    '质保金扣减金额最多保留 2 位小数',
    'excess precision feedback',
  );

  window.selectAfterSale('ticket-1', 'RESOLVED');
  ids.afterSaleCloseContent.value = '双方已确认处理完成';
  await invoke(ids.closeAfterSale);
  action = calls.find(call => call.path.endsWith('/close'));
  assertEqual(action.options.method, 'PUT', 'close method');
  assertEqual(JSON.parse(action.options.body).content, '双方已确认处理完成', 'close content');

  assertEqual(statusText('OPEN'), '待平台受理', 'OPEN wording');
  assertEqual(statusText('RESOLVED'), '已解决 · 待关闭', 'RESOLVED wording');
  print('admin after-sale UI lifecycle: PASS');
}

let failure;
run().catch(error => { failure = error; });
drainMicrotasks();
if (failure) throw failure;
