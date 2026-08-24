// ============================================================
// SSE realtime check against a running server.
//   1. create 2 users + group + bill (bob owes)
//   2. bob opens GET /notifications/stream (SSE, token in query)
//   3. alice POST /bills/:id/remind -> expect an SSE data: event
//
// Run: node scripts/sse-check.mjs  (AA_API_BASE to override)
// ============================================================
const base = process.env.AA_API_BASE || 'http://127.0.0.1:3000/api/v1';
const suffix = Date.now().toString(36).slice(-6);

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
    throw new Error(`HTTP ${res.status} ${JSON.stringify(json)}`);
  }
  return json.data;
}

const alice = await api('POST', '/auth/register', {
  body: {
    accountName: `sse_alice_${suffix}`,
    password: 'abc123ABC',
    nickname: 'Alice',
    securityQuestion: 'q?',
    securityAnswer: 'a',
  },
});
const bob = await api('POST', '/auth/register', {
  body: {
    accountName: `sse_bob_${suffix}`,
    password: 'def456DEF',
    nickname: 'Bob',
    securityQuestion: 'q?',
    securityAnswer: 'a',
  },
});
const group = await api('POST', '/groups', {
  token: alice.accessToken,
  body: { name: 'SSE Check Group', defaultSplitType: 'even' },
});
await api('POST', '/groups/join', {
  token: bob.accessToken,
  body: { inviteCode: group.inviteCode },
});
const bill = await api('POST', '/bills', {
  token: alice.accessToken,
  body: {
    groupId: group.id,
    title: 'SSE Bill',
    amountCents: 2000,
    billDate: '2026-08-24',
    category: 'food',
    splitType: 'even',
    payerId: alice.user.id,
    participants: [
      { userId: alice.user.id },
      { userId: bob.user.id },
    ],
  },
});

console.log('opening SSE stream for bob ...');
const ctrl = new AbortController();
const res = await fetch(`${base}/notifications/stream?access_token=${bob.accessToken}`, {
  headers: { Accept: 'text/event-stream' },
  signal: ctrl.signal,
});
if (!res.ok) throw new Error(`SSE HTTP ${res.status}`);
console.log('SSE connected, reading frames ...');
const reader = res.body.getReader();
console.log('stream open; registering frame consumer ...');
const framePromise = readFrame(ctrl, reader);

console.log('triggering remind from alice ...');
await api('POST', `/bills/${bill.id}/remind`, {
  token: alice.accessToken,
  body: { userIds: [bob.user.id], message: 'SSE ping' },
});

const event = await framePromise;
console.log(`SSE EVENT: ${JSON.stringify(event)}`);
if (event.type !== 'remind' || event.refId !== bill.id) {
  console.log('FAIL: unexpected event payload');
  process.exit(1);
}
ctrl.abort();
console.log('PASS: SSE realtime event received');
process.exit(0);

function readFrame(ctrl, reader) {
  const decoder = new TextDecoder();
  let buf = '';
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      ctrl.abort();
      reject(new Error('timeout: no SSE event within 15s'));
    }, 15000);
    (async () => {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buf += decoder.decode(value, { stream: true });
        const lines = buf.split('\n');
        buf = lines.pop() ?? '';
        for (const line of lines) {
          if (line.startsWith('data:')) {
            const payload = line.slice(5).trim();
            if (payload) {
              clearTimeout(timer);
              resolve(JSON.parse(payload));
              return;
            }
          }
        }
      }
    })().catch(reject);
  });
}
