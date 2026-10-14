#!/usr/bin/env node
// 管理员重置某个用户的登录密码。
//
// 为什么用管理接口而不是直接改数据库：密码哈希算法与参数由 GoTrue 决定
// （bcrypt，参数可能随版本变化）。用 SQL 自己写 `crypt(...)` 在算法换掉之后
// 会**静默**产生一个永远校验不过的密码——用户以为改了，其实登不上。
//
// 用法：
//   node reset-password.mjs <用户名>                    # 生成随机新密码并打印
//   node reset-password.mjs <用户名> <新密码>
//   node reset-password.mjs <用户名> --insecure         # Caddy 自签证书时跳过 TLS 校验
//
// 前置：../.env 里有 JWT_SECRET 与 AUTH_DOMAIN（service JWT 现场签发，不落地）。
//
// ⚠️ 执行后该用户在所有设备上的**已登录会话仍然有效**（改密码不吊销 refresh token）。
//    要强制下线，另需吊销其会话；当前 App 未实现该流程，必要时重建账号。

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';

const here = dirname(fileURLToPath(import.meta.url));

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

const args = process.argv.slice(2);
const insecure = args.includes('--insecure');
const positional = args.filter((a) => !a.startsWith('--'));
const username = positional[0];
let newPassword = positional[1];

if (!username) {
  console.error('用法: node reset-password.mjs <用户名> [新密码] [--insecure]');
  process.exit(1);
}

if (!newPassword) {
  // 24 字符 base64url ≈ 144 bit，够强且可复制粘贴。
  newPassword = randomBytes(18).toString('base64url');
  console.log(`已生成随机新密码：${newPassword}`);
}

if (insecure) {
  process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
  console.warn('⚠️  已跳过 TLS 证书校验（--insecure）——仅限内网自签证书场景。\n');
}

const env = { ...loadDotEnv(), ...process.env };
// 同时认两套变量名：AUTH_DOMAIN（docker 路径）与 MW_AUTH_DOMAIN（原生部署的
// /opt/mw-auth/.env）。少认一个，脚本放到服务器上就会报「缺少 AUTH_DOMAIN」。
const domain = env.AUTH_DOMAIN || env.MW_AUTH_DOMAIN;
if (!domain) {
  console.error('缺少 AUTH_DOMAIN（请设置环境变量，或在 ../.env 里填写）');
  process.exit(1);
}

const base = `https://${domain}/auth/v1`;

// 现场签发 service_role JWT（不落地）
let serviceJwt;
try {
  serviceJwt = execFileSync(process.execPath, [join(here, 'gen-service-jwt.mjs')], {
    encoding: 'utf8',
    env: { ...process.env, ...env },
  }).trim();
} catch (e) {
  console.error('签发 service JWT 失败：', e.message);
  process.exit(1);
}

const authHeaders = { Authorization: `Bearer ${serviceJwt}`, apikey: serviceJwt };

// 用户名 → 账号地址（与客户端同算法）
const address = execFileSync(process.execPath, [join(here, 'account-address.mjs'), username], {
  encoding: 'utf8',
}).trim().split('\t')[1];

console.log(`用户名   : ${username}`);
console.log(`账号地址 : ${address}\n`);

async function findUser() {
  // 分页遍历：GoTrue 管理接口没有按邮箱查询的参数，只能自己找。
  for (let page = 1; page <= 100; page++) {
    const res = await fetch(`${base}/admin/users?page=${page}&per_page=1000`, { headers: authHeaders });
    if (!res.ok) {
      throw new Error(`列举用户失败：HTTP ${res.status} ${await res.text()}`);
    }
    const body = await res.json();
    const users = body.users ?? [];
    const hit = users.find((u) => (u.email ?? '').toLowerCase() === address.toLowerCase());
    if (hit) return hit;
    if (users.length < 1000) return null;
  }
  throw new Error('用户数超过 10 万页上限，请直接用 SQL 处理');
}

const user = await findUser();
if (!user) {
  console.error('找不到该账号。可能原因：');
  console.error('  1. 该用户从未在服务端登录过（存量用户要先用原密码登录一次才会建号）；');
  console.error('  2. 用户名记错了（大小写不敏感，但别多打空格）。');
  console.error('可用 account-address.mjs 反查地址，或列举用户核对。');
  process.exit(2);
}

const res = await fetch(`${base}/admin/users/${user.id}`, {
  method: 'PUT',
  headers: { ...authHeaders, 'Content-Type': 'application/json' },
  body: JSON.stringify({ password: newPassword }),
});

if (!res.ok) {
  console.error(`重置失败：HTTP ${res.status} ${await res.text()}`);
  process.exit(3);
}

console.log(`✅ 已重置「${username}」的密码（user id ${user.id}）。`);
console.log('   请通过安全渠道把新密码告知本人；本终端输出不要留档。');
