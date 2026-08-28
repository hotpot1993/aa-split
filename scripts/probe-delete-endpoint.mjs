// 临时探针：验证线上服务端是否已部署 DELETE /notifications 系列接口
// （注册一次性账号 → 登录 → DELETE /notifications → 打印状态码与响应体）
const BASE = 'https://api.hotpot1993.top/api/v1';
const stamp = Date.now().toString(36);
const account = `probe${stamp}`;

async function call(method, path, token, body) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  let json = null;
  try { json = await res.json(); } catch { /* ignore */ }
  return { status: res.status, json };
}

const reg = await call('POST', '/auth/register', null, {
  accountName: account,
  password: 'probe123ABC',
  nickname: '探针',
  securityQuestion: 'q',
  securityAnswer: 'a',
});
console.log('register:', reg.status, JSON.stringify(reg.json).slice(0, 120));
const token = reg.json?.data?.accessToken;

const readAll = await call('POST', '/notifications/read-all', token);
console.log('POST read-all(新旧版本都有):', readAll.status, JSON.stringify(readAll.json).slice(0, 160));

const delAll = await call('DELETE', '/notifications', token);
console.log('DELETE /notifications(仅新版本有):', delAll.status, JSON.stringify(delAll.json).slice(0, 160));

const delOne = await call('DELETE', `/notifications/00000000-0000-0000-0000-000000000000`, token);
console.log('DELETE /notifications/:id(仅新版本有):', delOne.status, JSON.stringify(delOne.json).slice(0, 160));
