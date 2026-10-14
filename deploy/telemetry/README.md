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

## 4.1 账号关联与「按人看」（2026-10-14 新增）

业主要求管理端能按人看。客户端上报信封里带 `user_id`（当前登录账号的 UUID），
`usage_daily.user_id` 存下来，`telemetry_users` 记台账。

**统计库里只存 UUID，不存用户名。** 管理页渲染时用 service_role JWT 调账号服务的
`GET /admin/users`，在内存里做 UUID → 用户名 的映射（结果缓存 5 分钟）。
理由：用户名的权威来源是账号服务，在统计库再存一份必然漂移（改名后对不上）。
副作用也很好：**统计库万一泄露，里面没有用户名**。

映射失败（账号服务抖动、密钥没配）时退化成显示 UUID 前 8 位，并在页面顶部给出警告 ——
**不会**因为名字解析不了就让整页显示空白，让人误以为没数据。

> ⚠️ **踩过的坑：GoTrue 的 admin API 返回的键是 `user_metadata`，不是数据库列名
> `raw_user_meta_data`。**
> 第一版按列名读，结果 `username` 一律取不到，全部退化成邮箱本地部分
> （实测管理页显示 `u16cfbeee…` 而不是用户名 `percheck2847`）。
> 代码里两个键都试一遍。

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

### 还差两步

**① Caddy 路由 —— 已完成（2026-10-14）**

`stats.cloudbear.cloud` 已在 `/etc/caddy/Caddyfile` 里指到 `127.0.0.1:8080`
（纯反代，**没有** `uri strip_prefix` —— 统计服务的路径就是 `/v1/report`）。
用的是泛化后的 `deploy/native/enable-caddy-route.sh`：

```bash
bash enable-caddy-route.sh --name mwtelemetry --domain stats.cloudbear.cloud \
  --upstream 127.0.0.1:8080 --prefix '' --health-path /healthz --health-expect '"ok":true'
```

（同一个脚本也服务认证路由，默认参数即 auth；加 `--verify-only` 只做回归验证不改配置。）

**② Cloudflare 隧道加 Public Hostname —— 待做**

Networks → Tunnels → 选中隧道 → **`已发布应用程序路由`** 标签 → 添加路由 →
`已发布应用程序` → 子域 `stats`、域 `cloudbear.cloud`、服务 URL `http://localhost:8081`。

> ⚠️ 别点 `主机名路由` 标签（那是需要 WARP 客户端的专用路由，对公网不生效）。
> 2026-10-14 在这里踩过一次，详见 `deploy/native/README.md` §3。

**③ 发版流水线注入 —— 待做（等 ② 通了再做）**

`release_packages.yml` 的三处构建加：

```
--dart-define=STATS_BASE_URL=https://stats.cloudbear.cloud
```

未注入时客户端**不会**静默成功 —— `HttpUsageStatsUploader` 会返回 false 并报一次
配置错误（静默成功会让数据被标成「已上报」而永久丢失）。

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
| Cloudflare Public Hostname | ⏳ 待做（见 §5 ②） |
| **账号关联**（user_id 入库、账号台账、按人汇总视图） | ✅ 6 项断言 |
| **账号关联的幂等细节**（先未登录后登录要补上；已有账号不被空值抹掉） | ✅ |
| **管理页按人显示真实用户名** | ✅ 建真实账号 → 上报 → 页面显示 `percheck10761`，而不是 UUID 或邮箱前缀 |
| 服务本体部署 + 安装脚本端到端自检 | ✅ 含 user_id 入库校验 |
| 客户端 → 服务端 公网端到端 | ⏳ 待 Cloudflare 入口 + `STATS_BASE_URL` 注入 |

服务本体已部署：systemd `mw-telemetry`，监听 `127.0.0.1:8080`，库 `mw_telemetry`。
