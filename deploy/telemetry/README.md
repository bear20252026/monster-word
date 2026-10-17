# 使用统计服务端（mw_telemetry）

接收客户端的使用统计、入库、提供一个只读管理页（**支持按用户查看**）。

> 客户端侧的设计与隐私边界见 [`lib/features/telemetry/README.md`](../../lib/features/telemetry/README.md)。
> **两边一起看**：字段、白名单、频率口径都是成对的，改一边要改另一边。

---

## 1. 为什么与认证后端同机但不同库

同一台服务器（阿里云 ECS）上再跑一个 Node 服务，复用已装好的 PostgreSQL 16，
但**独立库 `mw_telemetry`**：

| | 账号库 `mwauth` | 统计库 `mw_telemetry` |
|---|---|---|
| 数据性质 | 身份数据 | 可丢弃的观测数据 |
| 保留期 | 长期，要能精确恢复 | 日明细 400 天后可归档/删除 |
| 备份策略 | 必须纳入 cron | 可选 |
| 权限 | 只给认证服务 | 只给统计服务 |

混在一个库里，将来做备份策略、权限收紧、甚至迁机时会互相牵制。

## 2. 零依赖

服务只用 Node 内置模块 + 调用 `psql` 子进程，**没有 node_modules**：

- 少一棵依赖树 = 少一份长期维护面（升级、供应链、体积）
- 校验与写入都放在 DB 函数 `mw_ingest` 里（`functions.sql`），Node 只做 HTTP 外壳
- JSON 用 **dollar-quoting** 传给 psql，不做字符串拼接 ⇒ 天然免疫 SQL 注入

代价是每个请求 spawn 一次 psql（约几十毫秒）。对「每设备每天 1 次」的量级完全够用。

## 3. 端点

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/v1/report` | 客户端上报。**无凭据**（见下） |
| GET | `/` | 管理页，Basic Auth |
| GET | `/healthz` | 健康检查 |

### 为什么上报端点没有凭据

客户端二进制里放不住任何密钥 —— 反编译即得，而且 anon 类密钥本就随包公开。
所以防护靠三件事，而不是靠密钥：

1. **严格校验**（DB 函数内）：数值夹紧、日期格式、模块键白名单、条数上限
2. **请求体上限** 256 KB
3. **每 IP 每小时 60 次**限流（正常客户端每天 1 次，留足重试余量）

最坏后果是垃圾数据污染统计 —— 拿不到任何用户信息，也影响不到账号库（独立库）。

## 4. 幂等与去重

主键是 `(device_id, day)`。客户端失败会保留数据下轮补传，重试会重复送同一天，
所以冲突时必须幂等。冲突策略是**取较大值**而不是覆盖：

- 正常补传：后到的是更完整的数据，取较大值等于拿到完整值
- 客户端重装后计数从 0 重新开始：覆盖会把当天已有的时长抹掉，取较大值不会

`book_learned_count` / `book_word_count` 是**状态量**不是累加量，所以用覆盖。

`module_open_counts` 虽是对象，但它是**按天累加量**（当天各模块被打开几次），
所以用 `mw_merge_modules()` **逐键取较大值**：

- 逐键而不是整对象比较：两次上报带的键集合可能不同（第二次那天没打开过词典），
  整对象比较会整块丢掉第一次的键
- ⚠️ 2026-10-15 验收时实测发现早期实现是 `EXCLUDED` 整对象覆盖：
  「先 `{"learn":4,"review":2}` 再 `{"learn":1}`」⇒ 库里变成 `{"learn":1}`，
  `review` 整个键丢了、`learn` 还被改小。已修，`verify-sql.sh` 有 4 条断言锁住。

### 响应码约定

| 情况 | 状态码 | `error` |
|---|---|---|
| 正常 | 200 | —（`{ok,accepted,rejected}`） |
| 请求体不是合法 JSON | 400 | `invalid_json` |
| 库内校验失败（缺 `device_id` / `days` 非数组 / 超 31 天 / 顶层不是对象） | 400 | `invalid_payload` |
| 请求体超过 256 KB | 413 | `payload_too_large` |
| 每 IP 每小时超过 60 次 | 429 | `rate_limited` |
| 路径/方法不对 | 404 | `not_found` |
| 真故障（连不上库、SQL 错、权限） | 500 | `server_error` |

**为什么要把 400 和 500 分开**：不是洁癖 —— 500 会被当成服务故障（告警、Sentry），
而前四种全是**客户端把请求发错了**，与服务端健康无关。混在一起会让脏请求把告警刷满。
实现靠约定：`functions.sql` 里的校验 `RAISE` 一律带 `mw_invalid_input:` 前缀，
`server.mjs` 的 `VALIDATION_MARKER` 据此映射（**改一边要改两边**）。

## 4.1 账号关联与「按人看」（2026-10-14 新增）

业主要求管理端能按人看。客户端上报信封里带 `user_id`（当前登录账号的 UUID），
`usage_daily.user_id` 存下来，`telemetry_users` 记台账。

**统计库里只存 UUID，不存用户名。** 管理页渲染时用**账号库只读角色**直连 `mwauth`
查 `auth.users`，在内存里做 UUID → 用户名 的映射（结果缓存 5 分钟）。
理由：用户名的权威来源是账号库，在统计库再存一份必然漂移（改名后对不上）。
副作用也很好：**统计库万一泄露，里面没有用户名**。

> 🔒 **2026-10-16 审计 P1-4：这里原先走的是「自签 `service_role` JWT + 调 `/admin/users`」。**
> 那条路径要求统计服务持有账号库的 **JWT 签名密钥**，而同一密钥能签出
> `DELETE /admin/users/{id}`、改任意用户密码的令牌 —— 等于把**整个账号库的写权限**
> 交给本机**唯一对公网无鉴权收输入**的进程，而它只需要显示一个用户名。
>
> 现在改为**列级只读角色**：`mw_auth_reader` 只被授予
> `SELECT (id, email, raw_user_meta_data) ON auth.users`，
> 拿不到 `encrypted_password` 与各种 token 列，也无法写入任何东西。
> 越权面从「整个账号体系」缩到「只读两个字段」。
> 建角色与授权见 `install-telemetry.sh` §1.5；连接参数为 `AUTH_PG_DB` / `AUTH_PG_USER` / `AUTH_PG_PASSWORD`。
>
> ⚠️ **不能拿 email 当用户名**：客户端为兼容中文/空格用户名，把它派生成了
> `u<SHA256前24位>@monster-word.internal`（见 `supabase_account_authenticator.accountAddress`），
> 所以 email 是**哈希**、认不出是谁。真实用户名在 `raw_user_meta_data.username`
>（客户端注册时写 `data: {'username': ...}`，该列只有这一个键）。
>
> 顺带：审计 R3-S12 当年修的是「`/admin/users` 分页只拉第一页 ⇒ 第 1001 个之后的账号
> 静默退化成 UUID 前缀」。改成一条 SQL 后**不存在分页**，该问题从根上消失。

映射失败（账号库抖动、只读角色没配）时退化成显示 UUID 前 8 位，并在页面顶部给出警告 ——
**不会**因为名字解析不了就让整页显示空白，让人误以为没数据。

上报格式版本从 v1 升到 **v2**：v1 的数据不可识别到个人，v2 的与账号关联，
服务端据此能区分历史数据的性质。

隐私披露已同步改写（客户端 `legal_documents.dart` §一/§二/§六，`policyVersion` → `2026-10-14.2`）。

## 5. 部署

```bash
# 在服务器上（依赖已装好的 PostgreSQL，即认证后端那套）
scp -i ~/.ssh/gk-deploy.pem deploy/telemetry/*.sql deploy/telemetry/*.mjs \
    deploy/telemetry/install-telemetry.sh root@101.133.235.110:/root/telemetry/
ssh root@101.133.235.110 'cd /root/telemetry && sed -i "s/\r$//" *.sh && bash install-telemetry.sh'
```

脚本会：建角色与库 → 应用 schema 与函数 → 装服务 → 写 `.env`（生成管理密码）
→ 装 systemd → 健康检查 → **端到端自检**（真发一条假数据、验证入库与模块白名单、再删掉）。
管理页密码在脚本输出末尾打印一次。

> ⚠️ **服务连数据库必须走 TCP + 显式角色，不能靠 Unix socket 对等认证。**
> 服务以系统账户 `mw-telemetry` 运行，而数据库角色叫 `mw_telemetry_app`，两者不同名
> ⇒ 对等认证会报 `FATAL: role "mw-telemetry" does not exist`（2026-10-14 首次部署就是这么
> 挂在「服务起来了但 /healthz 全 500」上的）。
> `.env` 里的 `PG_USER` / `PG_PASSWORD` 就是为此，`server.mjs` 会带上 `-w -h 127.0.0.1 -U …`。

### 剩余步骤

**① Caddy 路由 —— 已完成（2026-10-14）**

`stats.cloudbear.cloud` 已在 `/etc/caddy/Caddyfile` 里指到 `127.0.0.1:8080`
（纯反代，**没有** `uri strip_prefix` —— 统计服务的路径就是 `/v1/report`）。
用的是泛化后的 `deploy/native/enable-caddy-route.sh`：

```bash
bash enable-caddy-route.sh --name mwtelemetry --domain stats.cloudbear.cloud \
  --upstream 127.0.0.1:8080 --prefix '' --health-path /healthz --health-expect '"ok":true'
```

（同一个脚本也服务认证路由，默认参数即 auth；加 `--verify-only` 只做回归验证不改配置。）

**② 发版流水线注入 —— 已完成（2026-10-15）**

`release_packages.yml` 的三处构建（APK / AAB / Windows）都已加：

```
--dart-define=STATS_BASE_URL=https://stats.cloudbear.cloud
```

与 `AUTH_BASE_URL` 不同，**这一条缺失或不可达都不影响任何用户可见行为**：统计开关默认
关闭，且上报通道失败时只返回 false（数据留在本地等下轮补传），不会静默丢数据。所以它
不依赖 ③ 先完成 —— 提前注入反而是对的：③ 一旦通了，**已经发出去的版本无需重新发版**。

未注入时客户端**不会**静默成功 —— `HttpUsageStatsUploader` 会返回 false 并报一次配置
错误（静默成功会让数据被标成「已上报」而永久丢失）。

`build.yml`（编译门禁，产物非发布件）**刻意不注入**，以便 CI 持续覆盖「未注入」这条
合法降级路径 —— 那不是疏漏。

**③ Cloudflare 隧道加已发布应用程序路由 —— 已完成（2026-10-15，业主操作）**

> ✅ 业主已加。公网 `https://stats.cloudbear.cloud/healthz` 返回 `{"ok":true}`，
> DNS 解析到 Cloudflare（`172.67.217.241`）。下面保留排查记录与操作路径，
> 便于将来换域名或重建隧道时复用。

> ⚠️ **这一步代码侧无法代劳**：隧道是 token 管理的远程配置，服务器与本地都没有
> Cloudflare API 凭据（`gh secret list` 只有 keystore 与 Sentry DSN）。
> 控制台入口与账号信息如下，已备齐，照做即可。

加之前隧道的 ingress 配置（`journalctl -u cloudflared` 里可复核，当时 version=5）：

```json
{"ingress":[
  {"hostname":"cloudbear.cloud","service":"http://localhost:3000"},
  {"hostname":"www.cloudbear.cloud","service":"http://localhost:3100"},
  {"hostname":"aionui.cloudbear.cloud","service":"http://localhost:8081"},
  {"hostname":"aionui-auth.cloudbear.cloud","service":"http://localhost:9091"},
  {"hostname":"auth.cloudbear.cloud","service":"http://localhost:8081"},
  {"service":"http_status:404"}
]}
```

`stats.cloudbear.cloud` 不在其中，DNS 也解析不到（NXDOMAIN），走公网
`/healthz` 返回 000 —— 服务端本身是好的，缺的只是入口。

操作路径：

Networks → Tunnels → 选中隧道 → **`已发布应用程序路由`** 标签 → 添加路由 →
`已发布应用程序` → 子域 `stats`、域 `cloudbear.cloud`、服务 URL `http://localhost:8081`。

> ⚠️ 别点 `主机名路由` 标签（那是需要 WARP 客户端的专用路由，对公网不生效）。
> 2026-10-14 在这里踩过一次，详见 `deploy/native/README.md` §3。

加完自检（应得 200 + `{"ok":true}`）：

```bash
curl -s https://stats.cloudbear.cloud/healthz
```

（若要用 API 而不是控制台，账号 ID `52eab2ceafe4c07d54bdea60443ad115`、
隧道 ID `f7a1a3c6-6aea-4cc3-b7cb-94827a8a0945`，走
`PUT /accounts/{account_id}/cfd_tunnel/{tunnel_id}/configurations` 重写整份 ingress —— 
注意是**整份覆盖**，必须把上面 5 条既有路由一起带上，漏一条就会打断现有站点。）

## 6. 运维

```bash
systemctl status mw-telemetry
journalctl -u mw-telemetry -f

# 管理页（本地直连预览，不经 Cloudflare）
curl -u admin:<密码> http://127.0.0.1:8080/ | head -40

# 密码在哪
grep ADMIN_PASSWORD /opt/mw-telemetry/.env
```

### 常用查询

```bash
sudo -u postgres psql mw_telemetry
```

```sql
-- 近 14 天
SELECT * FROM usage_daily_summary LIMIT 14;

-- 人均时长趋势（只看有活动的设备）
SELECT day, round(avg(foreground_ms)/60000.0, 1) AS avg_min
FROM usage_daily WHERE foreground_ms > 0 GROUP BY day ORDER BY day DESC LIMIT 30;

-- 模块使用分布（把 JSONB 摊开）
SELECT key, sum(value::int) AS opens
FROM usage_daily, jsonb_each_text(module_open_counts)
WHERE day > current_date - 30 GROUP BY key ORDER BY opens DESC;

-- 留存粗看：首次使用后仍在活跃的设备
SELECT date_trunc('week', first_seen)::date AS cohort, count(*) AS devices
FROM devices GROUP BY 1 ORDER BY 1 DESC LIMIT 12;
```

### 保留期清理

```sql
-- 400 天前的日明细（客户端只保留 180 天，服务端留更久以便做同比）
DELETE FROM usage_daily WHERE day < current_date - 400;
DELETE FROM devices WHERE last_seen < now() - interval '400 days';
```

建议把这条挂进 cron（与 gallery 的备份体系同一个思路）。**清理前先确认已归档**。

### 备份

```bash
sudo -u postgres pg_dump -Fc mw_telemetry > /opt/backups/mw_telemetry-$(date +%F).dump
```

统计库属于可丢弃数据，不备份也可接受；但**保留期清理前**建议先 dump 一次。

## 7. 验证记录（2026-10-14）

数据库层已在服务器的**临时库**里真跑验证过（`verify-sql.sh`，15 项全过，不改动任何已有库）：

```bash
# 在服务器上（需要 psql；会在临时库里建表、跑断言、然后删掉临时库）
scp -i ~/.ssh/gk-deploy.pem deploy/telemetry/schema.sql deploy/telemetry/functions.sql \
    deploy/telemetry/verify-sql.sh root@101.133.235.110:/tmp/tsql/
ssh root@101.133.235.110 'cd /tmp/tsql && sed -i "s/\r$//" verify-sql.sh && bash verify-sql.sh /tmp/tsql'
```

| 项 | 结果 |
|---|---|
| schema + functions 能在真实 PostgreSQL 16 上应用 | ✅ |
| 非法日期被跳过而不是让整批失败 | ✅ 2 条合法接受、2 条非法拒绝 |
| 前台时长夹到 24h / 答对数不超过复习词次 | ✅ |
| 模块键白名单（非法键不入库、合法键保留） | ✅ |
| 设备台账写入 | ✅ |
| **幂等**：重复送同一天不新增行 | ✅ |
| **取较大值**：较小值不覆盖已有较大值 | ✅ |
| 缺 device_id / days 非数组 / 超 31 天 被拒 | ✅ |
| 空 days 正常返回 0 | ✅ |
| 汇总视图数值格式 | ✅（`sum(bigint)` 返回 numeric，已用 round 收口） |
| **服务本体部署 + 安装脚本端到端自检** | ✅ 真写一条测试数据、验白名单、再删掉 |
| 服务健康 / 管理页鉴权 | ✅ `/healthz` 返回 `{"ok":true}`；无凭据 401，带凭据正常渲染 |
| **经 Caddy 的完整上报链路** | ✅ POST `Host: stats.cloudbear.cloud` → `{"ok":true,"accepted":1}`；库内落行正确、非法模块键被剔除、汇总视图算出 30 分钟 / 82.5% |
| Caddy 路由回归（既有 auth / aionui / gallery） | ✅ 均未受影响 |
| Cloudflare 已发布应用程序路由 | ✅ 2026-10-15 业主已加，公网 `/healthz` 返回 `{"ok":true}` |
| **账号关联**（user_id 入库、账号台账、按人汇总视图） | ✅ 6 项断言 |
| **账号关联的幂等细节**（先未登录后登录要补上；已有账号不被空值抹掉） | ✅ |
| **管理页按人显示真实用户名** | ✅ 建真实账号 → 上报 → 页面显示 `percheck10761`，而不是 UUID 或邮箱前缀 |
| 服务本体部署 + 安装脚本端到端自检 | ✅ 含 user_id 入库校验 |
| 发版流水线注入 `STATS_BASE_URL` | ✅ 2026-10-15，三处构建（APK/AAB/Windows）；产物 `libapp.so` 三个 ABI 各 1 处常量已核 |
| 客户端 → 服务端 公网端到端 | ✅ 2026-10-15（见下） |

### 公网端到端验收（2026-10-15，Cloudflare 入口接通后）

全部走 `https://stats.cloudbear.cloud` 公网路径，不是 localhost：

| 项 | 结果 |
|---|---|
| `POST /v1/report` 正常批次（含 1 条非法日期 + 1 个非法模块键） | ✅ `{"ok":true,"accepted":1,"rejected":1}` |
| 同一 device+day 送更小值 | ✅ 标量保持较大值（`foreground_ms` 1800000 未被 600000 覆盖） |
| 同一 device+day 送更大值 + 补上 `user_id` | ✅ 标量更新、**账号从空补上**、`telemetry_users` 台账写入 |
| 非法 JSON → 400 / 未知路径 → 404 / GET 上报端点 → 404 | ✅ |
| 建真实账号 → 上报 → 管理页显示真实用户名 | ✅ 页面渲染 `<b>e2everify1015</b><div class="mono sub">a91da1f5…</div>`（用户名为主、UUID 前缀为辅） |
| 管理页公网访问鉴权 | ✅ 无凭据 401，带 Basic Auth 200 |
| 既有站点回归（auth `/health`、aionui、cloudbear） | ✅ 200 / 200 / 200 |
| 验收残留清理（测试账号、统计行、台账） | ✅ 已全部删除，库内无 e2e 痕迹 |

### 首轮验收查出并修掉的三个缺陷

都是**只在真实公网链路上跑才暴露**的，本地/临时库自检没抓到（第 1 项有断言缺口，
第 2、3 项在 Node 层，`verify-sql.sh` 覆盖不到）：

| 缺陷 | 首轮实测表现 | 处置与复验 |
|---|---|---|
| `module_open_counts` 用整对象覆盖，而它是按天**累加量** | 先送 `{"learn":4,"review":2}` 再送 `{"learn":1}` ⇒ 库里 `{"learn":1}`，`review` 整个键丢失、`learn` 还被改小 | 新增 `mw_merge_modules()` 逐键取较大值（见 §4）。复验：`{"dict":3,"learn":9}` + `{"learn":1,"review":5}` ⇒ `{"dict":3,"learn":9,"review":5}` ✅。`verify-sql.sh` 加 4 条断言 |
| 库内校验失败一律回 500 | 缺 `device_id` ⇒ `500 server_error`，把「客户端发错」记成「服务端故障」 | `RAISE` 加 `mw_invalid_input:` 前缀 + `server.mjs` 的 `VALIDATION_MARKER` 映射 ⇒ 400 `invalid_payload`（见 §4「响应码约定」）。`verify-sql.sh` 加 3 条前缀断言 ✅ |
| 请求体超限时先 `req.destroy()` 再回响应 | 300 KB 的批次 ⇒ **502**（Cloudflare 看到源站连接被掐断），客户端以为网关坏了 | 改成 `req.pause()` 而不是 destroy，让 413 能写出去 ⇒ `413 payload_too_large` ✅ |

> ⚠️ **管理页的用户名解析有 5 分钟缓存**（`nameCache`）。新建账号后立刻刷新管理页会
> 仍显示 UUID 前缀，且**不会**出现告警条（因为解析本身没失败，只是缓存里还没有这个人）。
> 等缓存过期再看即可 —— 这是设计行为，不是故障（首轮验收在这里多绕了一圈）。

服务本体已部署：systemd `mw-telemetry`，监听 `127.0.0.1:8080`，库 `mw_telemetry`。
