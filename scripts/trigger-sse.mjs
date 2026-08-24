// SSE 实时推送触发脚本：注册 fresh 用户 → 建群 → addMember 拉 uimini → 记账 → 催款×2
// 全程仅用 creator 的 token，不消耗 uimini 的登录限流。
// node scripts/trigger-sse.mjs  (AA_API_BASE 可覆盖)
const api = process.env.AA_API_BASE || 'http://103.11.77.228:3000/api/v1';
const suffix = Date.now().toString(36).slice(-5);
const name = `s2_${suffix}`;

async function post(p, b, t) {
  const r = await fetch(api + p, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(t ? { Authorization: `Bearer ${t}` } : {}) },
    body: JSON.stringify(b),
  });
  const j = await r.json().catch(() => null);
  if (!r.ok || !j || j.code !== 0) throw new Error(`${p} -> ${r.status} ${JSON.stringify(j)}`);
  return j.data;
}

const creator = await post('/auth/register', {
  accountName: name, password: 'pass123ABC', nickname: 'SSE触发者', securityQuestion: 'q', securityAnswer: 'a',
});
const group = await post('/groups', { name: 'SSE实时群', defaultSplitType: 'even' }, creator.accessToken);
await post(`/groups/${group.id}/members`, { accountName: 'uimini' }, creator.accessToken);
const gDetail = await (async () => {
  const r = await fetch(`${api}/groups/${group.id}`, { headers: { Authorization: `Bearer ${creator.accessToken}` } });
  const j = await r.json();
  if (j.code !== 0) throw new Error(`groups/${group.id} -> ${r.status} ${JSON.stringify(j)}`);
  return j.data;
})();
const uiminiId = gDetail.members.find((m) => m.accountName === 'uimini').userId;
const bill = await post('/bills', {
  groupId: group.id, title: 'SSE实时验证', amountCents: 6600, billDate: '2026-08-24',
  category: 'food', splitType: 'even', payerId: creator.user.id,
  participants: [{ userId: creator.user.id }, { userId: uiminiId }],
}, creator.accessToken);
await post(`/bills/${bill.id}/remind`, { userIds: [uiminiId], message: 'SSE实时催款' }, creator.accessToken);
await post(`/bills/${bill.id}/remind`, { userIds: [uiminiId], message: 'SSE实时催款2' }, creator.accessToken);
console.log(`PUSH_DONE group=${group.name} bill=${bill.id} uimini=${uiminiId}`);
