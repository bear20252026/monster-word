# 原生部署（实际在用的这条路径）

Monster Word 认证后端**已经部署在**业主自己的阿里云服务器上。本文是这台机器的运维手册。

> 为什么不是 `deploy/supabase/`（docker compose）：那台服务器**没装 Docker**，
> 只有 2 vCPU / 1.6 GiB 内存，且上面已经跑着 gallery / landing / aionui / authelia /
> caddy / cloudflared。再叠一层容器运行时在这个内存水位上没有意义。
> 而 GoTrue 本身就是一个静态 Go 二进制 —— 原生部署比容器轻得多。
> `deploy/supabase/` 保留给「有 Docker 的环境」用。

---

## 1. 现状（2026-10-14 部署完成）

| 项 | 值 |
|---|---|
| 服务器 | 阿里云 ECS `101.133.235.110`（Ubuntu 24.04.2 LTS，2 vCPU / 1.6 GiB） |
| 登录方式 | **SSH 密钥**（不是密码）：`~/.ssh/gk-deploy.pem`，用户 `root` |
| 对外域名 | `https://auth.cloudbear.cloud`（已接通，见 §3） |
| 认证服务 | GoTrue `v2.197.0`，systemd 单元 `mw-auth`，监听 `127.0.0.1:9999` |
| 数据库 | PostgreSQL 16.15，库 `mwauth`，角色 `supabase_auth_admin` |
| 网关 | 复用既有 Caddy（`/etc/caddy/Caddyfile`，监听 `:8081`） |
| 安装目录 | `/opt/mw-auth/`（`auth` 二进制、`migrations/`、`.env`、`tools/`） |
| 资源占用 | `auth` 常驻约 **37 MB**；部署后可用内存仍有 ~825 MB |

### 链路

```
客户端 ──HTTPS──▶ Cloudflare 边缘 ──隧道──▶ cloudflared(127.0.0.1:20241)
                                              │
                                              ▼
                                        Caddy(:8081)
                                        host=auth.cloudbear.cloud
                                        strip_prefix /auth/v1
                                              │
                                              ▼
                                        GoTrue(127.0.0.1:9999)
                                              │
                                              ▼
                                        PostgreSQL(127.0.0.1:5432, db=mwauth)
```

**GoTrue 与 PostgreSQL 都只绑 127.0.0.1**，公网没有任何新端口（阿里云安全组也没开 8081，
实测从外网连不上）。对外入口只有 Cloudflare 隧道。

### 与既有服务的关系

**没有动任何既有数据或配置语义**。唯一改动的生产文件是 `/etc/caddy/Caddyfile`，
改动是**追加**一条 `auth.cloudbear.cloud` 的 handler，原有 `aionui` handler 与兜底
404 一行未改（有备份，见 §5）。gallery / landing / aionui 三个 pm2 应用全部 online，
公网 `cloudbear.cloud` 与 `aionui.cloudbear.cloud` 均为 200。

---

## 2. 首次部署做了什么

`install-auth.sh`（幂等，可重复跑）：

1. `apt install postgresql`（16.15）+ 低内存调优（`max_connections=30`、`shared_buffers=128MB`）
2. 生成密钥 → 建角色 `supabase_auth_admin` → 建库 `mwauth`（**已存在则一个字节不动**）
3. 建 `auth` schema + `pgcrypto`/`uuid-ossp` 扩展
4. 设 `supabase_auth_admin` 在本库的 `search_path = auth, public`
5. 装 GoTrue 二进制与 `migrations/`
6. 写 `/opt/mw-auth/.env`（640 root:服务账户，含密钥）
7. 装 systemd 单元并启动（`ExecStartPre` 跑 `auth migrate`）

`enable-caddy-route.sh`：备份 → 插入路由 → `caddy validate` → reload → 回归验证。

### 四个「官方镜像替你做了、原生部署必须自己做」的点（都踩过）

| 现象 | 原因 | 解法 |
|---|---|---|
| 服务反复重启，日志 `open .env: permission denied` | GoTrue 启动时会自己从**工作目录**读 `.env`，读不到即 fatal | `.env` 设 `640 root:服务账户` |
| 服务起来、`/health` 是 200，但库里**一张表都没有** | `serve` **不会**自动跑迁移 | `ExecStartPre=/opt/mw-auth/auth migrate` |
| `migrate` 报 `schema "auth" does not exist` | GoTrue 的迁移脚本不建 schema，官方镜像里是预置的 | 先 `CREATE SCHEMA auth` |
| 表都建好了、`/health` 也 200，但**每个业务接口都 500**（`relation "users" does not exist`） | GoTrue 的 SQL 用不带 schema 前缀的表名，依赖连接的 `search_path` | `ALTER ROLE ... IN DATABASE ... SET search_path = auth, public` |

> 第 3、4 条的组合还制造过一个更难查的状态：迁移记录表 `schema_migrations` 也是按
> `search_path` 解析的，所以中途改 `search_path` 会把记录写进**另一张**同名表，
> 出现「表都在、但迁移记录对不上、于是重放迁移并报 `column "client_id" does not exist`」。
> 遇到这种不一致，最省事的处置是**删库重跑**（见 §5 的重建命令）——前提是确认库里没有业务数据。

---

## 3. Cloudflare 入口（已完成 2026-10-14）

`auth.cloudbear.cloud` 已接通：DNS 解析到 Cloudflare（`172.67.217.241`），
`https://auth.cloudbear.cloud/health` 返回 200。

下面这套操作留档，日后要再加别的子域照此办理。隧道入口是**远程管理**的
（`cloudflared` 用 token 跑，没有本地 `config.yml`），服务器上也没有 Cloudflare API
凭据，所以只能在控制台点。

**操作**（控制台是中文界面，按下面点；英文界面括号里是原文）：

1. Zero Trust → Networks → **Tunnels** → 选中现有隧道（名为 `gallery`）
2. 点 **`已发布应用程序路由`** 标签（Published application routes）
3. 点 **添加路由** → 选 **`已发布应用程序`**（Published application）
4. 填：

   | 字段 | 值 |
   |---|---|
   | 子域 | `auth` |
   | 域 | `cloudbear.cloud`（下拉里选） |
   | 路径 | 留空 |
   | 服务 URL | **`http://localhost:8081`** |

5. 保存（DNS 记录 Cloudflare 会自动建）

> ⚠️ **别点 `主机名路由` 标签**（Hostname routes）。那个标签下的表单长得挺像，但它是
> **专用/私有主机名路由**——页面顶部会提示「此配置要求流量通过 Cloudflare Gateway，
> 用户需要 Cloudflare One Client」，只填「主机名 + 描述」两个字段，是给装了 WARP 客户端
> 的设备访问内网用的，对公网访问不生效。
> 2026-10-14 实际踩过：我第一版手册写的是旧界面的 `Public Hostname` 标签名，
> 而当前界面已把它改名并挪到了「已发布应用程序路由」下。
> 依据：官方文档 <https://developers.cloudflare.com/cloudflare-one/networks/routes/add-routes/>
> 的「Add a published application route」一节（2026-10-12 更新）。

保存后 Cloudflare 会自动创建 DNS 记录并签好边缘证书。

### 验证（已完成）

```bash
curl -s https://auth.cloudbear.cloud/health
# 期望：{"version":"v2.197.0","name":"GoTrue",...}

# 完整端到端：走公网 Cloudflare → cloudflared → Caddy → GoTrue，跑完自动清理测试账号
ssh root@101.133.235.110 'cd /opt/mw-auth/tools && node smoke-test.mjs'
```

2026-10-14 实测：域名接通的当天，**走公网 10/10 通过**；另外从一台外部机器
（业主本机，与服务器不同网络路径）独立复验了注册 / 错误密码 / 中文用户名注册三条，
结果一致；既有站点 `cloudbear.cloud` 与 `aionui.cloudbear.cloud` 均仍为 200。

在没有域名之前，可以先直连后端验证（这条现在也仍然可用，用来区分「后端坏了」还是
「网关坏了」）：

```bash
ssh root@101.133.235.110 'cd /opt/mw-auth/tools && node smoke-test.mjs --base-url http://127.0.0.1:9999'
```

---

## 4. 客户端构建

```bash
flutter build windows \
  --dart-define=AUTH_BASE_URL=https://auth.cloudbear.cloud \
  --dart-define=AUTH_ANON_KEY=any-non-empty-string
```

不传这两个 `--dart-define` 时客户端走**本机模式**（阶段一行为），CI 与本地开发不受影响。

`AUTH_ANON_KEY` 随便填一个非空值即可：本栈不校验 apikey（anon key 本就随客户端二进制
公开，拦不住任何人，只会多一处可能把人锁在门外的配置）。客户端要求它非空才切服务端模式。

---

## 5. 日常运维

```bash
# 状态与日志
systemctl status mw-auth
journalctl -u mw-auth -f

# 重启
systemctl restart mw-auth

# 本地探活
curl -s http://127.0.0.1:9999/health

# 网关回归验证（只读，不改配置）
bash /root/enable-caddy-route.sh --verify-only
```

### 管理员重置某个用户的密码

```bash
cd /opt/mw-auth/tools
node reset-password.mjs 张三              # 生成随机新密码并打印
node reset-password.mjs 张三 NewPass123   # 指定新密码
```

用户名 → 账号地址的反查：

```bash
node account-address.mjs 张三
node account-address.mjs --list     # 自检：与客户端 Dart 算法是否仍一致
```

### 备份

```bash
sudo -u postgres pg_dump -Fc mwauth > /opt/backups/mwauth-$(date +%F).dump
```

⚠️ 这台机器已有 gallery 的备份体系（cron 每天 03:17 / 每周日 04:23 → `/opt/backups/`）。
**认证库不在其中**，需要的话把上面这条加进同一个 cron。

### 回滚 Caddy 改动

```bash
ls -d /root/caddy-backup-*        # 每次改动都会留一份
cp /root/caddy-backup-<时间戳>/Caddyfile /etc/caddy/Caddyfile
systemctl reload caddy
```

### 数据库状态不一致时重建

```bash
systemctl stop mw-auth
sudo -u postgres dropdb mwauth          # ⚠️ 会删掉全部账号
bash /root/install-auth.sh --tarball /tmp/auth-v2.197.0-amd64.tar.xz
```

---

## 6. 升级 GoTrue

```bash
# 1. 在本机（国内直连 GitHub release 会卡在 0 字节，本机走 gh 的 API 通道没问题）
gh release download <新版本 tag> --repo supabase/auth \
  --pattern 'auth-<新版本>-amd64.tar.xz' --dir /tmp
# 2. 传上去（scp 后**必须核对字节数**，见 §7）
scp /tmp/auth-<新版本>-amd64.tar.xz root@101.133.235.110:/tmp/
# 3. 重跑安装脚本（会换二进制与迁移，并在下次启动时自动补新迁移）
ssh root@101.133.235.110 'bash /root/install-auth.sh --tarball /tmp/auth-<新版本>-amd64.tar.xz'
# 4. 跑验收
ssh root@101.133.235.110 'cd /opt/mw-auth/tools && node smoke-test.mjs --base-url http://127.0.0.1:9999'
```

---

## 7. 验证记录（2026-10-14）

| 项 | 结果 |
|---|---|
| `install-auth.sh` 从零跑通（删库后重建） | ✅ 27 张表，`/health` 200 |
| **`smoke-test.mjs` 对真实 GoTrue v2.197.0** | ✅ **10/10 通过** |
| ↳ 密码错 → 400 `invalid_credentials` | ✅ |
| ↳ **用户不存在 → 400 `invalid_credentials`（不是 `user_not_found`）** | ✅ 迁移方案的前提，实测成立 |
| ↳ 重复注册 → 422 `user_already_exists` | ✅ |
| ↳ 注册返回 200 且含 `access_token`（autoconfirm 生效） | ✅ |
| ↳ 中文用户名可注册（哈希派生地址有效） | ✅ |
| ↳ 大小写/空格归一到同一账号 | ✅ |
| `enable-caddy-route.sh --verify-only` | ✅ 新路由通、前缀剥离正确、兜底 404 正常、公网 aionui 与 cloudbear 仍 200 |
| 既有服务未受影响 | ✅ pm2 三个应用 online；公网两个站点 200 |

**全部已验证，无遗留项。** `auth.cloudbear.cloud` 的端到端公网可达已实测（见 §3）。

### 两个操作坑（供下次参考）

1. **`scp` 到这台服务器可能静默截断**：第一次传 9.9 MB 的包只落了 2.0 MB，
   而 `scp` 退出码是 0。**传完必须核对两侧字节数**（`stat -c%s`）。
   另外别用 `echo $?` 取管道退出码 —— 那取到的是最后一个命令的。
2. **本机 Git Bash 没有 `xz`**，`.tar.xz` 要在服务器上解。
