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
//   node smoke-test.mjs --base-url http://127.0.0.1:9999
//                                      # 直接打后端（绕过网关）。用于**域名还没接好之前**
//                                      # 先在服务器上验后端行为 —— 例如在服务器上跑
//                                      #   node smoke-test.mjs --base-url http://127.0.0.1:9999
//
// ⚠️ 这个脚本会**在生产库里建真实账号**，跑完靠 service_role JWT 删掉。
// 而 JWT 需要 `JWT_SECRET` / `MW_JWT_SECRET`（原生部署在 `/opt/mw-auth/.env`），
// 本地一般没有 ⇒ 所以脚本会在**建任何账号之前**先确认清理能力，拿不到就直接中止
// （避免留下孤儿账号；2026-10-15 因为缺这一步，本地跑完在生产留了两条，事后手工删）。
// 想在本地跑完整断言，就用 `--keep` 明确表示「我接受留下测试账号」，
// 或者把本目录连同 `/opt/mw-auth/.env` 一起放到服务器上跑。
//                                      # 注意这样验不到 Caddy 的前缀剥离与 TLS，那两条
//                                      # 由 enable-caddy-route.sh 的回归验证覆盖。

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);

// 按优先级在几个可能的位置找 .env（第一个命中的值优先，不覆盖）：
//   1. ../.env            —— 原生部署（/opt/mw-auth/tools/ → /opt/mw-auth/.env）
//   2. ../supabase/.env   —— 仓库里的 docker compose 路径（deploy/tools/ → deploy/supabase/.env）
//   3. ./.env             —— 当前目录
// 都找不到就只认环境变量。
function loadDotEnv() {
  const out = {};
  const candidates = [join(here, '..', '.env'), join(here, '..', 'supabase', '.env'), join(here, '.env')];
  for (const path of candidates) {
    let text;
    try {
      text = readFileSync(path, 'utf8');
    } catch {
      continue;
    }
    for (const line of text.split(/\r?\n/)) {
      const m = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/.exec(line);
      if (m && !(m[1] in out)) out[m[1]] = m[2].trim().replace(/^["']|["']$/g, '');
    }
  }
  return out;
}

if (args.includes('--insecure')) {
  process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
  console.warn('⚠️  已跳过 TLS 证书校验（--insecure）\n');
}

const env = { ...loadDotEnv(), ...process.env };
// 同时认两套变量名：AUTH_DOMAIN（docker 路径）与 MW_AUTH_DOMAIN（原生部署的
// /opt/mw-auth/.env）。少认一个，脚本放到服务器上就会报「缺少 AUTH_DOMAIN」。
const domain = env.AUTH_DOMAIN || env.MW_AUTH_DOMAIN;

// --base-url 直连后端时不需要域名；否则域名必填。
const baseUrlIdx = args.indexOf('--base-url');
const baseUrlOverride = baseUrlIdx >= 0 ? args[baseUrlIdx + 1] : '';
if (!baseUrlOverride && !domain) {
  console.error('缺少 AUTH_DOMAIN（请设置环境变量，或在 ../.env 里填写），或用 --base-url 指定后端地址');
  process.exit(1);
}

const base = baseUrlOverride ? baseUrlOverride.replace(/\/$/, '') : `https://${domain}/auth/v1`;
// 健康检查在网关的根路径上（Caddy 用 strip_prefix 只剥 /auth/v1），
// 直连后端时则和后端同根。
const healthUrl = baseUrlOverride
  ? `${base.replace(/\/auth\/v1$/, '')}/health`
  : `https://${domain}/health`;
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

// ── 清理能力前置检查：在创建任何账号之前 ───────────────────────
//
// 为什么放在最前：清理靠 service_role JWT 调 admin API 删账号，而 JWT 需要
// `JWT_SECRET` / `MW_JWT_SECRET`。本地跑这个脚本时（没有服务器的 .env）密钥通常
// 不存在 —— 原实现是**跑完全部断言之后**才发现清理不了，于是在**生产库留下孤儿
// 测试账号**（2026-10-15 实际踩到，事后手工删了两条）。
// 所以：先确认清理能力，拿不到就一个账号都别建。
const keepAccounts = args.includes('--keep');
let serviceJwt = '';
if (!keepAccounts) {
  try {
    serviceJwt = execFileSync(process.execPath, [join(here, 'gen-service-jwt.mjs')], {
      encoding: 'utf8',
      env: { ...process.env, ...env },
    }).trim();
  } catch (e) {
    console.error(
      '\n无法生成 service_role JWT（缺 JWT_SECRET / MW_JWT_SECRET）⇒ 跑完删不掉测试账号。\n' +
        '为避免在生产库留下孤儿账号，已在创建任何账号之前中止。可选：\n' +
        '  1. 到服务器上跑（那里有 /opt/mw-auth/.env）：\n' +
        '     ssh … \'set -a; . /opt/mw-auth/.env; set +a; node smoke-test.mjs\'\n' +
        '  2. 显式加 --keep，表示「我就是要保留测试账号」\n' +
        `\n底层错误：${String(e.message ?? e).split('\n')[0]}`,
    );
    process.exit(1);
  }
}

console.log(`\n目标: ${base}\n`);

// ── 异常路径的清理（2026-10-15 审计 R3-S09）──────────────────────
// 主流程是顶层 await，任一断言处抛错（网络抖动、502 让 fetch reject）都会
// 带着**已经创建好的账号**直接退出。旧版只保护了「拿不到 service JWT」这一条路径，
// 其余路径会在生产库留下孤儿账号 —— 今天刚因同类原因手工删过两条。
let cleanedUp = false;
async function cleanupOnFailure(reason) {
  if (cleanedUp || keepAccounts || created.length === 0) return;
  cleanedUp = true;
  console.error(`\n[清理] 异常退出（${reason}）—— 尝试删除本次创建的 ${created.length} 个测试账号`);
  for (const id of created) {
    try {
      const res = await fetch(`${base}/admin/users/${id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${serviceJwt}`, apikey: serviceJwt },
      });
      console.error(`  ${res.ok ? '✓' : '✗'} 删除 ${id}（HTTP ${res.status}）`);
    } catch (e) {
      console.error(`  ✗ 删除 ${id} 失败：${e?.message ?? e}`);
    }
  }
}
process.on('unhandledRejection', (e) => {
  cleanupOnFailure(e?.message ?? e).finally(() => process.exit(1));
});
process.on('uncaughtException', (e) => {
  cleanupOnFailure(e?.message ?? e).finally(() => process.exit(1));
});

// ── 1. TLS 与网关 ──
console.log('[1] TLS 与网关');
try {
  const res = await fetch(healthUrl);
  check('GET /health 可达', res.ok, `HTTP ${res.status}`);
} catch (e) {
  // Node 的 fetch 只抛 "fetch failed"，真正的原因（ENOTFOUND / ECONNREFUSED /
  // 证书错误）在 e.cause 里。不把它带出来，运维只能靠猜。
  const cause = e?.cause ? ` — ${e.cause.code ?? e.cause.message ?? e.cause}` : '';
  check('GET /health 可达', false, `${e?.message ?? e}${cause}`);
  console.error('\n网关不通，后续断言无法进行。逐项排查：');
  console.error('  1. 容器起来了吗：docker compose ps');
  console.error('  2. AUTH_DOMAIN 能解析到这台机器吗：getent hosts ' + domain);
  console.error('  3. 网关日志：docker compose logs caddy');
  console.error('  4. 自签证书要加 --insecure（客户端侧还需信任 Caddy 的根证书）');
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
if (!keepAccounts && created.length > 0) {
  console.log('\n[清理] 删除测试账号');
  let allDeleted = true;
  try {
    for (const id of created) {
      const res = await fetch(`${base}/admin/users/${id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${serviceJwt}`, apikey: serviceJwt },
      });
      check(`删除测试账号 ${id}`, res.ok, `HTTP ${res.status}`);
      if (!res.ok) allDeleted = false;
    }
  } catch (e) {
    allDeleted = false;
    check('删除测试账号', false, String(e.message ?? e));
  }
  if (allDeleted) {
    cleanedUp = true;
  } else {
    // 有没删掉的：再走一遍统一清理（幂等），并把失败如实报出来。
    await cleanupOnFailure('正常清理未全部成功');
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
if (baseUrlOverride) {
  console.log(`（本次是 --base-url 直连后端：${base}）`);
  console.log('注意：这只验了后端行为。网关的前缀剥离与 TLS 由 enable-caddy-route.sh 的回归验证覆盖。');
}
if (domain) {
  console.log(`构建示例：flutter build windows --dart-define=AUTH_BASE_URL=https://${domain} --dart-define=AUTH_ANON_KEY=<任意非空值>`);
}
