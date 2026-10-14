#!/usr/bin/env node
// 生成 service_role JWT（管理员运维用）。
//
// 为什么现场生成而不是存在 .env 里：这个 key 等价于「整个认证库的读写权」。
// 存下来就多一份会泄露的文件；按需用 JWT_SECRET 现签，有效期 1 小时，用完即弃。
//
// 声明结构取自官方自建栈的 .env.example：
//   { "role": "service_role", "iss": "<issuer>", "iat": ..., "exp": ... }
// 其中 iss 必须与 GOTRUE_JWT_ISSUER 一致（见 docker-compose.yml）。
//
// 用法：
//   node gen-service-jwt.mjs                 # 从 ../.env 读 JWT_SECRET / AUTH_DOMAIN
//   JWT_SECRET=xxx AUTH_DOMAIN=a.example node gen-service-jwt.mjs
//
// ⚠️ 输出是密钥，别粘进聊天记录、工单、CI 日志。

import { createHmac } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));

/** 极简 .env 读取（只处理 KEY=VALUE 与 # 注释；值里的引号会去掉）。 */
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

const env = { ...loadDotEnv(), ...process.env };

// 同时认两套变量名：
//   JWT_SECRET / AUTH_DOMAIN   —— docker compose 那套（deploy/supabase/.env）
//   MW_JWT_SECRET / MW_AUTH_DOMAIN —— 原生部署那套（/opt/mw-auth/.env）
// 这样运维脚本可以直接放到 /opt/mw-auth/tools/ 用，不必再维护第二份配置。
const secret = env.JWT_SECRET || env.MW_JWT_SECRET;
const domain = env.AUTH_DOMAIN || env.MW_AUTH_DOMAIN;

if (!secret) {
  console.error('缺少 JWT_SECRET（或 MW_JWT_SECRET）：请设置环境变量，或在 ../.env 里填写');
  process.exit(1);
}
if (!domain) {
  console.error('缺少 AUTH_DOMAIN（或 MW_AUTH_DOMAIN）：请设置环境变量，或在 ../.env 里填写');
  process.exit(1);
}

const b64url = (buf) => Buffer.from(buf).toString('base64url');

const now = Math.floor(Date.now() / 1000);
const header = { alg: 'HS256', typ: 'JWT' };
const payload = {
  role: 'service_role',
  // 与 docker-compose.yml 的 GOTRUE_JWT_ISSUER 一致
  iss: `https://${domain}/auth/v1`,
  iat: now,
  exp: now + 3600,
};

const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
const signature = createHmac('sha256', secret).update(signingInput).digest('base64url');

console.log(`${signingInput}.${signature}`);
