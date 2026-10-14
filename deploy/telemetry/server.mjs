// Monster Word 使用统计服务。
//
// 两个职责：
//   POST /v1/report   接收客户端上报（匿名、无凭据）
//   GET  /            管理页（Basic Auth 保护），展示汇总
//   GET  /healthz     健康检查
//
// 为什么零依赖（只用 node 内置模块 + 调用 psql 子进程）：
//   这台服务器上少一棵 npm 依赖树，就少一份长期维护面（升级、供应链、node_modules
//   体积）。入库的校验与写入都放在 DB 函数 mw_ingest 里（见 functions.sql），
//   Node 侧只做 HTTP 外壳 —— 校验逻辑只有一处，不会出现「Node 校验了 SQL 没校验」的缝。
//
// ⚠️ 上报端点**没有凭据**，这是有意的：客户端二进制里放不住任何密钥
//    （反编译即得，且 anon 类密钥本就公开）。所以防护靠：
//      1. 严格校验（DB 函数里，含数值夹紧与白名单）
//      2. 请求体大小上限
//      3. 每 IP 限流
//   垃圾数据最坏只能污染统计，拿不到任何用户信息，也影响不到账号库（独立库）。
//
// 环境变量：
//   PG_DB           目标库名，默认 mw_telemetry
//   LISTEN_PORT     监听端口，默认 8080（只绑 127.0.0.1，由 Caddy 反代）
//   ADMIN_USER      管理页用户名，默认 admin
//   ADMIN_PASSWORD  管理页密码，**必须设置**，否则管理页直接 503 而不是无密码开放
//   TRUST_PROXY     1 = 从 X-Forwarded-For 取客户端 IP（Caddy 后面必须开）

import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';

const PG_DB = process.env.PG_DB || 'mw_telemetry';
// ⚠️ 必须走 TCP + 显式角色，不能靠 Unix socket 的对等认证：
//   服务以系统账户 mw-telemetry 运行，而数据库角色叫 mw_telemetry_app，
//   两者不同名 ⇒ 对等认证会报 `role "mw-telemetry" does not exist`（实测踩过）。
const PG_HOST = process.env.PG_HOST || '127.0.0.1';
const PG_USER = process.env.PG_USER || '';
const PG_PASSWORD = process.env.PG_PASSWORD || '';
const PORT = Number(process.env.LISTEN_PORT || 8080);
const ADMIN_USER = process.env.ADMIN_USER || 'admin';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || '';
const TRUST_PROXY = process.env.TRUST_PROXY === '1';
// 账号服务（用于把 user_id 解析成用户名，供管理页「按人看」）。
// 只在上报里存 UUID，名字在渲染时向账号服务要 —— 用户名的权威来源是那边，
// 在统计库里再存一份必然漂移（改名后对不上）。
const AUTH_ADMIN_URL = process.env.AUTH_ADMIN_URL || '';
const AUTH_JWT_SECRET = process.env.AUTH_JWT_SECRET || '';
const AUTH_ISSUER = process.env.AUTH_ISSUER || '';
const PSQL = process.env.PSQL_BIN || '/usr/bin/psql';

const MAX_BODY_BYTES = 256 * 1024;   // 31 天 × 十几项，几十 KB 足够；留 4 倍余量
const RATE_LIMIT_PER_HOUR = 60;      // 每 IP 每小时上报次数（正常客户端每天 1 次）

// ── 限流：内存计数，够用且不引入 Redis ────────────────────────
// 重启即清零。对「每天 1 次」的正常流量，它的作用是挡住脚本刷接口，
// 不是精确计费，所以内存实现完全够。
const buckets = new Map();
function rateLimited(ip) {
  const now = Date.now();
  const hourAgo = now - 3600_000;
  const hits = (buckets.get(ip) || []).filter((t) => t > hourAgo);
  if (hits.length >= RATE_LIMIT_PER_HOUR) {
    buckets.set(ip, hits);
    return true;
  }
  hits.push(now);
  buckets.set(ip, hits);
  // 顺手清理空桶，避免长期运行后 Map 无限增长
  if (buckets.size > 5000) {
    for (const [k, v] of buckets) if (v.every((t) => t <= hourAgo)) buckets.delete(k);
  }
  return false;
}

function clientIp(req) {
  if (TRUST_PROXY) {
    const fwd = req.headers['x-forwarded-for'];
    if (typeof fwd === 'string' && fwd.length > 0) return fwd.split(',')[0].trim();
  }
  return req.socket.remoteAddress || 'unknown';
}

// ── psql ─────────────────────────────────────────────────────
// 用 dollar-quoting 传 JSON，而不是字符串拼接：dollar 引号内的内容 PostgreSQL
// 不做任何转义处理，因此天然免疫 SQL 注入（分隔符本身是随机生成的，
// payload 里不可能预先包含它）。
function psql(sql) {
  return new Promise((resolve, reject) => {
    // -w = 绝不交互式要密码。缺凭据时立刻失败，而不是挂住等输入
    //（systemd 下没有 stdin，挂住会变成「服务活着但请求全超时」这种难查的状态）。
    const args = ['-w', '-h', PG_HOST];
    if (PG_USER) args.push('-U', PG_USER);
    args.push('-d', PG_DB, '-tA', '-v', 'ON_ERROR_STOP=1', '-f', '-');
    const child = spawn(PSQL, args, {
      stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env, PGPASSWORD: PG_PASSWORD },
    });
    let out = '';
    let err = '';
    child.stdout.on('data', (d) => (out += d));
    child.stderr.on('data', (d) => (err += d));
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) resolve(out.trim());
      else reject(new Error((err || `psql exited ${code}`).slice(0, 500)));
    });
    child.stdin.end(sql);
  });
}

async function ingest(payload) {
  const tag = `$mw${randomUUID().replace(/-/g, '')}$`;
  const sql = `SELECT mw_ingest(${tag}${JSON.stringify(payload)}${tag}::jsonb);`;
  const out = await psql(sql);
  return JSON.parse(out);
}

// ── 账号名解析 ────────────────────────────────────────────────
//
// 用 service_role JWT 调账号服务的 admin API（签法与 deploy/tools/gen-service-jwt.mjs
// 一致：HS256，payload 带 role=service_role 与 iss=账号服务的 issuer）。
// 结果缓存 5 分钟：管理页是低频人工查看，没必要每次刷新都去拉全量用户表。
let nameCache = { at: 0, map: new Map(), error: null };

function mintServiceJwt() {
  const b64url = (buf) => Buffer.from(buf).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'HS256', typ: 'JWT' };
  const payload = { role: 'service_role', iss: AUTH_ISSUER, iat: now, exp: now + 3600 };
  const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  return `${signingInput}.${createHmac('sha256', AUTH_JWT_SECRET).update(signingInput).digest('base64url')}`;
}

async function fetchUserNames() {
  if (!AUTH_ADMIN_URL || !AUTH_JWT_SECRET) {
    return { map: new Map(), error: '未配置 AUTH_ADMIN_URL / AUTH_JWT_SECRET' };
  }
  if (Date.now() - nameCache.at < 5 * 60 * 1000) return nameCache;

  try {
    const token = mintServiceJwt();
    const res = await fetch(`${AUTH_ADMIN_URL}/admin/users?page=1&per_page=1000`, {
      headers: { Authorization: `Bearer ${token}`, apikey: token },
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) {
      // 保留上一次成功的缓存：账号服务临时抖动不该让管理页整页显示 UUID
      nameCache = { ...nameCache, error: `账号服务返回 HTTP ${res.status}` };
      return nameCache;
    }
    const body = await res.json();
    const list = Array.isArray(body) ? body : (body.users ?? []);
    const map = new Map();
    for (const u of list) {
      if (!u?.id) continue;
      // ⚠️ admin API 返回的键是 **user_metadata**（GoTrue 的 API 层命名），
      // 不是数据库列名 raw_user_meta_data —— 第一版按列名读，结果一律拿不到，
      // 全部退化成邮箱前缀（实测：管理页显示 u16cfbeee… 而不是用户名）。
      // 两个都试一遍，免得将来 GoTrue 改回去。
      const meta = u.user_metadata ?? u.raw_user_meta_data ?? {};
      // 客户端注册时把用户名放在 raw_user_meta_data.username；退回邮箱本地部分。
      const name = meta.username || (typeof u.email === 'string' ? u.email.split('@')[0] : '');
      map.set(u.id, name || '(未命名)');
    }
    nameCache = { at: Date.now(), map, error: null };
  } catch (e) {
    nameCache = { ...nameCache, error: `账号服务不可达：${e?.message ?? e}` };
  }
  return nameCache;
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > MAX_BODY_BYTES) {
        reject(new Error('请求体过大'));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

// ── 管理页 ───────────────────────────────────────────────────
function checkAdminAuth(req) {
  if (!ADMIN_PASSWORD) return 'unconfigured';
  const header = req.headers.authorization || '';
  if (!header.startsWith('Basic ')) return 'missing';
  let decoded;
  try {
    decoded = Buffer.from(header.slice(6), 'base64').toString('utf8');
  } catch {
    return 'bad';
  }
  const idx = decoded.indexOf(':');
  if (idx < 0) return 'bad';
  const user = decoded.slice(0, idx);
  const pass = decoded.slice(idx + 1);
  // 定时比较，避免按字符比较带来的时序侧信道
  const a = Buffer.from(`${user}:${pass}`);
  const b = Buffer.from(`${ADMIN_USER}:${ADMIN_PASSWORD}`);
  if (a.length !== b.length || !timingSafeEqual(a, b)) return 'bad';
  return null;
}

function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}

async function adminPage() {
  const summary = JSON.parse(
    await psql(`SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) FROM (SELECT * FROM usage_daily_summary LIMIT 60) t;`)
  );
  const devices = JSON.parse(
    await psql(`SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) FROM (
                  SELECT device_id, first_seen, last_seen, platform, app_version
                  FROM devices ORDER BY last_seen DESC LIMIT 100) t;`)
  );
  const totals = JSON.parse(
    await psql(`SELECT row_to_json(t) FROM (
                  SELECT count(*) AS device_count,
                         count(*) FILTER (WHERE last_seen > now() - interval '1 day') AS active_1d,
                         count(*) FILTER (WHERE last_seen > now() - interval '7 days') AS active_7d
                  FROM devices) t;`)
  );

  const perUser = JSON.parse(
    await psql(`SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) FROM (
                  SELECT * FROM usage_user_summary ORDER BY total_minutes DESC NULLS LAST LIMIT 200) t;`)
  );
  const unbound = JSON.parse(
    await psql(`SELECT row_to_json(t) FROM (
                  SELECT count(DISTINCT device_id) AS devices, round(sum(foreground_ms)/60000.0, 1) AS minutes
                  FROM usage_daily WHERE user_id = '') t;`)
  );
  const { map: names, error: nameError } = await fetchUserNames();

  // 名字解析不到就退回短 UUID —— 宁可难看也不要显示空白让人以为没数据。
  const displayName = (id) => names.get(id) || `${String(id).slice(0, 8)}…`;
  const userRows = perUser
    .map(
      (u) => `<tr>
        <td><b>${esc(displayName(u.user_id))}</b><div class="mono sub">${esc(String(u.user_id).slice(0, 8))}…</div></td>
        <td class="n">${esc(u.active_days)}</td>
        <td class="n">${esc(u.devices)}</td>
        <td class="n">${esc(u.total_minutes)}</td>
        <td class="n">${esc(u.avg_minutes_per_active_day ?? '—')}</td>
        <td class="n">${esc(u.total_words_reviewed)}</td>
        <td class="n">${u.accuracy_pct === null ? '—' : esc(u.accuracy_pct) + '%'}</td>
        <td>${esc(u.last_active_day)}</td>
      </tr>`
    )
    .join('');

  const rows = summary
    .map(
      (r) => `<tr>
        <td>${esc(r.day)}</td>
        <td class="n">${esc(r.active_devices)}</td>
        <td class="n">${esc(r.total_minutes)}</td>
        <td class="n">${esc(r.avg_minutes_per_device)}</td>
        <td class="n">${esc(r.total_sessions)}</td>
        <td class="n">${esc(r.total_study_sessions)}</td>
        <td class="n">${esc(r.total_words_reviewed)}</td>
        <td class="n">${r.accuracy_pct === null ? '—' : esc(r.accuracy_pct) + '%'}</td>
      </tr>`
    )
    .join('');

  const devRows = devices
    .map(
      (d) => `<tr>
        <td class="mono">${esc(String(d.device_id).slice(0, 12))}…</td>
        <td>${esc(d.platform)}</td>
        <td>${esc(d.app_version)}</td>
        <td>${esc(String(d.first_seen).slice(0, 10))}</td>
        <td>${esc(String(d.last_seen).slice(0, 16).replace('T', ' '))}</td>
      </tr>`
    )
    .join('');

  return `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>Monster Word 使用统计</title>
<style>
  body{font:14px/1.6 system-ui,-apple-system,'Segoe UI',sans-serif;margin:0;padding:24px;background:#fafaf8;color:#2c2c2a}
  h1{font-size:18px;font-weight:500;margin:0 0 4px}
  h2{font-size:15px;font-weight:500;margin:28px 0 8px}
  .muted{color:#5f5e5a;font-size:13px;margin:0 0 16px}
  .cards{display:flex;gap:12px;flex-wrap:wrap;margin:16px 0}
  .card{background:#fff;border:1px solid #e5e3dc;border-radius:10px;padding:12px 16px;min-width:120px}
  .card b{display:block;font-size:22px;font-weight:500}
  .card span{color:#5f5e5a;font-size:12px}
  table{border-collapse:collapse;width:100%;background:#fff;border:1px solid #e5e3dc;border-radius:10px;overflow:hidden}
  th,td{text-align:left;padding:8px 10px;border-bottom:1px solid #efede6;font-size:13px}
  th{background:#f4f2ec;font-weight:500}
  td.n{text-align:right;font-variant-numeric:tabular-nums}
  td.mono{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12px}
  tr:last-child td{border-bottom:none}
  .sub{color:#8a8880;font-size:11px;margin-top:2px}
  .warn{background:#FAEEDA;border:1px solid #BA7517;color:#633806;border-radius:8px;padding:8px 12px;font-size:13px}
</style></head><body>
<h1>Monster Word 使用统计</h1>
<p class="muted">使用统计（与账号关联，供按用户查看），不含学习内容。上报频率为每设备每日最多一次。
用户名在渲染时向账号服务解析，统计库本身只存账号标识。</p>
<div class="cards">
  <div class="card"><b>${esc(totals.device_count)}</b><span>累计设备</span></div>
  <div class="card"><b>${esc(totals.active_1d)}</b><span>近 1 日活跃</span></div>
  <div class="card"><b>${esc(totals.active_7d)}</b><span>近 7 日活跃</span></div>
</div>
<h2>按用户</h2>
${nameError ? `<p class="warn">⚠️ 用户名解析不可用（${esc(nameError)}）—— 下表显示的是账号标识前 8 位。</p>` : ''}
<table><thead><tr>
  <th>用户</th><th class="n">活跃天数</th><th class="n">设备数</th><th class="n">总时长(分)</th>
  <th class="n">日均(分)</th><th class="n">复习词次</th><th class="n">正确率</th><th>最近活跃</th>
</tr></thead><tbody>${userRows || '<tr><td colspan="8" class="muted">暂无数据</td></tr>'}</tbody></table>
${unbound && unbound.devices > 0 ? `<p class="muted">另有未绑定账号的 ${esc(unbound.devices)} 台设备、${esc(unbound.minutes)} 分钟（本机模式或未登录时上报，无法归属到人）。</p>` : ''}

<h2>按天汇总</h2>
<table><thead><tr>
  <th>日期</th><th class="n">活跃设备</th><th class="n">总时长(分)</th><th class="n">人均(分)</th>
  <th class="n">打开次数</th><th class="n">学习会话</th><th class="n">复习词次</th><th class="n">正确率</th>
</tr></thead><tbody>${rows || '<tr><td colspan="8" class="muted">暂无数据</td></tr>'}</tbody></table>
<h2>设备</h2>
<table><thead><tr><th>设备标识</th><th>平台</th><th>版本</th><th>首次</th><th>最近</th></tr></thead>
<tbody>${devRows || '<tr><td colspan="5" class="muted">暂无数据</td></tr>'}</tbody></table>
</body></html>`;
}

// ── 路由 ─────────────────────────────────────────────────────
const server = createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const send = (code, body, type = 'application/json; charset=utf-8', extra = {}) => {
    res.writeHead(code, { 'Content-Type': type, 'Cache-Control': 'no-store', ...extra });
    res.end(body);
  };

  try {
    if (url.pathname === '/healthz') {
      await psql('SELECT 1;');
      return send(200, JSON.stringify({ ok: true }));
    }

    if (url.pathname === '/v1/report' && req.method === 'POST') {
      const ip = clientIp(req);
      if (rateLimited(ip)) return send(429, JSON.stringify({ ok: false, error: 'rate_limited' }));

      const raw = await readBody(req);
      let payload;
      try {
        payload = JSON.parse(raw);
      } catch {
        return send(400, JSON.stringify({ ok: false, error: 'invalid_json' }));
      }
      const result = await ingest(payload);
      return send(200, JSON.stringify(result));
    }

    if (url.pathname === '/' && req.method === 'GET') {
      const authFail = checkAdminAuth(req);
      if (authFail === 'unconfigured') {
        return send(503, '管理页未配置密码（设置 ADMIN_PASSWORD 后再访问）', 'text/plain; charset=utf-8');
      }
      if (authFail) {
        return send(401, '需要认证', 'text/plain; charset=utf-8', { 'WWW-Authenticate': 'Basic realm="mw-telemetry"' });
      }
      return send(200, await adminPage(), 'text/html; charset=utf-8');
    }

    return send(404, JSON.stringify({ ok: false, error: 'not_found' }));
  } catch (e) {
    // 上报端点的错误一律 4xx/5xx + 简短原因：客户端只会据此写退避，不解析内容。
    // 详细信息写服务日志，不回给客户端（避免把 SQL 报错泄露出去）。
    console.error('[telemetry]', req.method, url.pathname, '→', e?.message ?? e);
    return send(500, JSON.stringify({ ok: false, error: 'server_error' }));
  }
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`[telemetry] listening on 127.0.0.1:${PORT} (db=${PG_DB}@${PG_HOST} as ${PG_USER || '<peer>'}, admin_user=${ADMIN_USER})`);
  if (!ADMIN_PASSWORD) console.warn('[telemetry] ⚠️ 未设置 ADMIN_PASSWORD，管理页将返回 503');
});
