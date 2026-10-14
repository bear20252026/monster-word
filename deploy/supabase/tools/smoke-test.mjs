#!/usr/bin/env node
// 自建认证后端验收脚本（首次部署必跑）。
//
// 逐条验证**客户端契约依赖的每一个行为**。这些断言不是凭空写的——每条都对应
// 客户端代码里的一处假设，且都对着 supabase/auth 上游源码核对过：
//
//   1  TLS 与网关可用
//   2  注册返回 access_token          → 证明 GOTRUE_MAILER_AUTOCONFIRM 真的生效
//                                        （若为 false，注册会变成 200 但无 token 的假成功，
//                                         存量用户永远迁不过来）
//   3  重复注册 → 422 user_already_exists
//                                     → 迁移判定依赖它来区分「已存在」与「真打错了密码」
//   4  正确密码 → 200 + token
//   5  错误密码 → 400 invalid_credentials
//   6  用户不存在 → 400 invalid_credentials（**不是** user_not_found）
//                                     → 上游为防枚举刻意合并了这两种情况。若哪天变成
//                                       user_not_found，说明上游行为变了，客户端的
//                                       迁移逻辑需要重新评估。
//   7  中文用户名可注册              → 证明用户名→地址的哈希派生有效（GoTrue 用
//                                       checkmail.ValidateFormat 校验邮箱，非 ASCII 会被拒）
//   8  大小写/空格归一为同一账号      → 与 SecurePasswordAuthStore 同口径
//
// 用法：
//   node smoke-test.mjs                # 用 ../.env 里的 AUTH_DOMAIN
//   node smoke-test.mjs --insecure     # Caddy 自签证书时跳过 TLS 校验
//   node smoke-test.mjs --keep         # 保留测试账号（默认跑完删除）

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);

function loadDotEnv() {
  const out = {};
  try {
    for (const line of readFileSync(join(here, '..', '.env'), 'utf8').split(/\r?\n/)) {
      const m = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/.exec(line);
      if (m) out[m[1]] = m[2].trim().replace(/^["']|["']$/g, '');
    }
  } catch {
    // 忽略
  }
  return out;
}

if (args.includes('--insecure')) {
  process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
  console.warn('⚠️  已跳过 TLS 证书校验（--insecure）\n');
}

const env = { ...loadDotEnv(), ...process.env };
const domain = env.AUTH_DOMAIN;
if (!domain) {
  console.error('缺少 AUTH_DOMAIN（请设置环境变量，或在 ../.env 里填写）');
  process.exit(1);
}

const base = `https://${domain}/auth/v1`;
const results = [];
let failed = 0;

function check(label, ok, detail = '') {
  results.push({ label, ok, detail });
  if (!ok) failed++;
  console.log(`${ok ? '  ✓' : '  ✗'} ${label}${detail ? `\n      ${detail}` : ''}`);
}

function addressOf(username) {
  return execFileSync(process.execPath, [join(here, 'account-address.mjs'), username], { encoding: 'utf8' })
    .trim()
    .split('\t')[1];
}

async function post(path, body, headers = {}) {
  const res = await fetch(`${base}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    // 非 JSON（反代 HTML 错误页）——保留原文供诊断
  }
  return { status: res.status, json, text };
}

const suffix = randomBytes(4).toString('hex');
const userA = `smoke${suffix}`;
const userCN = `验收${suffix}`;
const password = `pw-${randomBytes(9).toString('base64url')}`;
const created = [];

console.log(`\n目标: ${base}\n`);

// ── 1. TLS 与网关 ──
console.log('[1] TLS 与网关');
try {
  const res = await fetch(`https://${domain}/health`);
  check('GET /health 可达（TLS 握手成功）', res.ok, `HTTP ${res.status}`);
} catch (e) {
  check('GET /health 可达（TLS 握手成功）', false, String(e.message ?? e));
  console.error('\n网关不通，后续断言无法进行。先看 caddy 容器日志：docker compose logs caddy');
  process.exit(1);
}

// ── 2/3. 注册 ──
console.log('\n[2] 注册（首次使用）');
const signup = await post('/signup', { email: addressOf(userA), password, data: { username: userA } });
check(
  '注册返回 200 且含 access_token（autoconfirm 生效）',
  signup.status === 200 && typeof signup.json?.access_token === 'string' && signup.json.access_token.length > 0,
  `HTTP ${signup.status} ${signup.json ? `error_code=${signup.json.error_code ?? '(无)'}` : signup.text.slice(0, 120)}`,
);
if (signup.json?.user?.id) created.push(signup.json.user.id);

console.log('\n[3] 重复注册同一账号');
const dup = await post('/signup', { email: addressOf(userA), password: 'different-password' });
check(
  '重复注册返回 422 且 error_code=user_already_exists',
  dup.status === 422 && dup.json?.error_code === 'user_already_exists',
  `HTTP ${dup.status} error_code=${dup.json?.error_code ?? '(无)'}`,
);

// ── 4/5/6. 登录 ──
console.log('\n[4] 正确密码登录');
const okLogin = await post('/token?grant_type=password', { email: addressOf(userA), password });
check(
  '返回 200 且含 access_token',
  okLogin.status === 200 && typeof okLogin.json?.access_token === 'string',
  `HTTP ${okLogin.status}`,
);

console.log('\n[5] 错误密码登录');
const badLogin = await post('/token?grant_type=password', { email: addressOf(userA), password: 'definitely-wrong' });
check(
  '返回 400 且 error_code=invalid_credentials',
  badLogin.status === 400 && badLogin.json?.error_code === 'invalid_credentials',
  `HTTP ${badLogin.status} error_code=${badLogin.json?.error_code ?? '(无)'}`,
);

console.log('\n[6] 不存在的用户登录（迁移逻辑的前提）');
const ghost = await post('/token?grant_type=password', {
  email: addressOf(`nobody${suffix}`),
  password: 'whatever-123456',
});
check(
  '返回 400 且 error_code=invalid_credentials（不得是 user_not_found）',
  ghost.status === 400 && ghost.json?.error_code === 'invalid_credentials',
  `HTTP ${ghost.status} error_code=${ghost.json?.error_code ?? '(无)'}` +
    (ghost.json?.error_code === 'user_not_found'
      ? '\n      ⚠️ 上游行为已变化：密码授予开始区分「用户不存在」。客户端迁移逻辑需重新评估。'
      : ''),
);

// ── 7/8. 用户名派生 ──
console.log('\n[7] 中文用户名注册（验证地址派生对非 ASCII 有效）');
const cnSignup = await post('/signup', { email: addressOf(userCN), password, data: { username: userCN } });
check(
  '中文用户名可注册（200 + access_token）',
  cnSignup.status === 200 && typeof cnSignup.json?.access_token === 'string',
  `HTTP ${cnSignup.status} error_code=${cnSignup.json?.error_code ?? '(无)'}`,
);
if (cnSignup.json?.user?.id) created.push(cnSignup.json.user.id);

console.log('\n[8] 用户名归一化（大小写 / 首尾空格）');
const normalized = await post('/token?grant_type=password', {
  email: addressOf(`  ${userA.toUpperCase()}  `),
  password,
});
check(
  'ALICE 与 alice 归一到同一账号（能登录成功）',
  normalized.status === 200,
  `HTTP ${normalized.status} error_code=${normalized.json?.error_code ?? '(无)'}`,
);

// ── 清理 ──
if (!args.includes('--keep') && created.length > 0) {
  console.log('\n[清理] 删除测试账号');
  try {
    const jwt = execFileSync(process.execPath, [join(here, 'gen-service-jwt.mjs')], {
      encoding: 'utf8',
      env: { ...process.env, ...env },
    }).trim();
    for (const id of created) {
      const res = await fetch(`${base}/admin/users/${id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${jwt}`, apikey: jwt },
      });
      check(`删除测试账号 ${id}`, res.ok, `HTTP ${res.status}`);
    }
  } catch (e) {
    check('删除测试账号', false, String(e.message ?? e));
  }
}

// ── 汇总 ──
const total = results.length;
const passed = total - failed;
console.log(`\n${'─'.repeat(56)}`);
console.log(`结果：${passed}/${total} 通过`);
if (failed > 0) {
  console.log('\n未通过的断言：');
  for (const r of results.filter((r) => !r.ok)) console.log(`  ✗ ${r.label}`);
  console.log('\n部署尚未满足客户端契约，先不要给用户升级到服务端模式。');
  process.exit(1);
}
console.log('\n全部通过：后端满足客户端契约，可以构建带 AUTH_BASE_URL 的客户端了。');
console.log(`构建示例：flutter build windows --dart-define=AUTH_BASE_URL=https://${domain} --dart-define=AUTH_ANON_KEY=<任意非空值>`);
