// ============================================================
// AA-split API smoke test against a REAL server + PostgreSQL.
// Node >= 18 (uses global fetch). Run:
//   node scripts/smoke-api.mjs
// Server must be running at http://127.0.0.1:3000 (AA_API_BASE to override).
// The smoke users (smoke_alice / smoke_bob) are created fresh each run:
// pre-clean with psql or use unique names via SMOKE_SUFFIX env.
// 注意：注册限制账户名 ≤16 字符（smoke_alice_xxx 已是 18 字符 → 精简前缀）
// ============================================================

const base = process.env.AA_API_BASE || 'http://127.0.0.1:3000/api/v1';
const suffix = process.env.SMOKE_SUFFIX || Date.now().toString(36).slice(-6);
const aliceName = `sa_${suffix}`;
const bobName = `sb_${suffix}`;

const QUESTION_ALICE = '你最好的朋友？';
const QUESTION_BOB = '你的小学？';
const NICKNAME_AFTER = '烟测爱丽丝2';
const GROUP_NAME = '烟测饭友群';
const BILL_TITLE = '烟测火锅';

let passed = 0;
let failed = 0;

async function api(method, path, { body, token } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${base}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const json = await res.json().catch(() => null);
  if (!res.ok || !json || json.code !== 0) {
    const err = new Error(`HTTP ${res.status} body=${JSON.stringify(json)}`);
    err.status = res.status;
    err.json = json;
    throw err;
  }
  return json.data;
}

async function step(name, fn) {
  try {
    await fn();
    console.log(`[PASS] ${name}`);
    passed++;
  } catch (e) {
    console.log(`[FAIL] ${name} -> ${e.message}`);
    failed++;
  }
}

function assert(cond, msg) {
  if (!cond) throw new Error(msg || 'assertion failed');
}

console.log(`API base: ${base}`);
console.log(`== 1. health ==`);
await step('GET /health', async () => {
  const d = await api('GET', '/health');
  assert(d.status, 'no status');
});

console.log(`== 2. register x2 ==`);
let alice, bob;
await step(`register alice (${aliceName})`, async () => {
  alice = await api('POST', '/auth/register', {
    body: {
      accountName: aliceName,
      password: 'abc123ABC',
      nickname: '烟测爱丽丝',
      securityQuestion: QUESTION_ALICE,
      securityAnswer: '小红',
    },
  });
  assert(alice.accessToken, 'no token');
});
await step(`register bob (${bobName})`, async () => {
  bob = await api('POST', '/auth/register', {
    body: {
      accountName: bobName,
      password: 'def456DEF',
      nickname: '烟测鲍勃',
      securityQuestion: QUESTION_BOB,
      securityAnswer: '实验',
    },
  });
});
await step('duplicate register -> 409', async () => {
  const res = await fetch(`${base}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      accountName: aliceName,
      password: 'abc123ABC',
      securityQuestion: 'q',
      securityAnswer: 'a',
    }),
  });
  assert(res.status === 409, `expected 409 got ${res.status}`);
});

const at = alice.accessToken;
const bt = bob.accessToken;

console.log('== 3. auth extra endpoints ==');
await step('GET /auth/security-question', async () => {
  const q = await api('GET', `/auth/security-question?accountName=${aliceName}`);
  assert(q.question === QUESTION_ALICE, `bad question: ${q.question}`);
});
await step('PATCH /auth/me (nickname + empty bio)', async () => {
  const u = await api('PATCH', '/auth/me', {
    token: at,
    body: { nickname: NICKNAME_AFTER, bio: '' },
  });
  assert(u.nickname === NICKNAME_AFTER, `nickname=${u.nickname}`);
  assert(u.bio == null, `bio=${u.bio}`);
});
await step('GET /auth/me reflects update', async () => {
  const u = await api('GET', '/auth/me', { token: at });
  assert(u.nickname === NICKNAME_AFTER, 'me not updated');
});

console.log('== 4. group + invite ==');
let group;
await step('create group', async () => {
  group = await api('POST', '/groups', {
    token: at,
    body: { name: GROUP_NAME, intro: '联调烟测', defaultSplitType: 'even' },
  });
  assert(group.inviteCode?.length === 12, `inviteCode=${group.inviteCode}`);
});
await step('bob join via invite code', async () => {
  const j = await api('POST', '/groups/join', { token: bt, body: { inviteCode: group.inviteCode } });
  assert(j.alreadyJoined === false, `alreadyJoined=${j.alreadyJoined}`);
});
await step('group member count = 2', async () => {
  const g = await api('GET', `/groups/${group.id}`, { token: at });
  assert(g.memberCount === 2, `memberCount=${g.memberCount}`);
});

console.log('== 5. bills ==');
let bill;
await step('create bill (even 22000)', async () => {
  bill = await api('POST', '/bills', {
    token: at,
    body: {
      groupId: group.id,
      title: BILL_TITLE,
      amountCents: 22000,
      billDate: '2026-08-24',
      category: 'food',
      splitType: 'even',
      payerId: alice.user.id,
      participants: [
        { userId: alice.user.id, shareAmountCents: 11000 },
        { userId: bob.user.id, shareAmountCents: 11000 },
      ],
    },
  });
  assert(bill.id, 'no bill id');
});
await step('custom split sum mismatch -> 400', async () => {
  const res = await fetch(`${base}/bills`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${at}` },
    body: JSON.stringify({
      groupId: group.id,
      title: '错账',
      amountCents: 100,
      billDate: '2026-08-24',
      category: 'food',
      splitType: 'custom',
      payerId: alice.user.id,
      participants: [
        { userId: alice.user.id, shareAmountCents: 60 },
        { userId: bob.user.id, shareAmountCents: 60 },
      ],
    }),
  });
  assert(res.status === 400, `expected 400 got ${res.status}`);
});

console.log('== 6. settlement ==');
await step('settlement 1 transfer bob->alice 11000', async () => {
  const s = await api('GET', `/groups/${group.id}/settlement`, { token: at });
  assert(s.transferCount === 1, `count=${s.transferCount}`);
  const t = s.transfers[0];
  assert(t.amountCents === 11000, `amount=${t.amountCents}`);
  assert(t.fromUserId === bob.user.id, `from=${t.fromUserId}`);
  assert(t.toUserId === alice.user.id, `to=${t.toUserId}`);
});

console.log('== 7. remind / notify ==');
await step('remind bob', async () => {
  const r = await api('POST', `/bills/${bill.id}/remind`, {
    token: at,
    body: { userIds: [bob.user.id], message: '快还钱呀～' },
  });
  assert(r.remindedCount === 1, `reminded=${r.remindedCount}`);
});
// 产品调整(v1.7): 新账单不再写通知库,只推静默 SSE 数据事件 → bob 仅剩 remind 这一条通知
await step('bob unread-count = 1 (仅 remind; new_bill 已为静默数据事件)', async () => {
  const n = await api('GET', '/notifications/unread-count', { token: bt });
  assert(n.count === 1, `count=${n.count}`);
});
await step('bob notifications list >= 1 (仅 remind)', async () => {
  const l = await api('GET', '/notifications?page=1&pageSize=100', { token: bt });
  assert(l.list.length >= 1, `list=${l.list.length}`);
});

console.log('== 8. mark paid -> settled ==');
await step('mark bob paid', async () => {
  const p = await api('POST', `/bills/${bill.id}/mark-paid`, {
    token: at,
    body: { userId: bob.user.id, paid: true },
  });
  assert(p.paid === true, 'paid=false');
});
await step('bill settled', async () => {
  const b = await api('GET', `/bills/${bill.id}`, { token: at });
  assert(b.settleStatus === 'settled', `status=${b.settleStatus}`);
});
await step('settlement cleared', async () => {
  const s = await api('GET', `/groups/${group.id}/settlement`, { token: at });
  assert(s.transferCount === 0, `count=${s.transferCount}`);
});

console.log('== 9. statistics / notifications delete ==');
await step('statistics', async () => {
  const st = await api('GET', '/me/statistics', { token: at });
  assert(st.billCount >= 1, `billCount=${st.billCount}`);
});
// 消息删除（v1.0.11）：DELETE /notifications/:id 归属校验 404 + DELETE /notifications 清空
await step('notification delete endpoints', async () => {
  const res = await fetch(`${base}/notifications/00000000-0000-0000-0000-000000000000`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${at}` },
  });
  const j = await res.json().catch(() => null);
  assert(res.status === 404, `expected 404 got ${res.status}`);
  assert(String(j?.message || '').includes('通知不存在'), `message=${j?.message}`);
  const clear = await api('DELETE', '/notifications', { token: at });
  assert(typeof clear.deleted === 'number', `deleted=${clear.deleted}`);
});

console.log('== 10. forgot-password flow ==');
await step('forgot verify -> reset -> relogin', async () => {
  const v = await api('POST', '/auth/forgot/verify', {
    body: { accountName: bobName, securityAnswer: '实验' },
  });
  assert(v.resetToken, 'no resetToken');
  await api('POST', '/auth/forgot/reset', {
    body: { resetToken: v.resetToken, newPassword: 'newPass123' },
  });
  const l = await api('POST', '/auth/login', {
    body: { accountName: bobName, password: 'newPass123' },
  });
  assert(l.accessToken, 'relogin failed');
});

console.log('');
console.log(`RESULT: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
