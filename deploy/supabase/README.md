# 自建认证后端（R2-01 阶段二）—— Docker 路径

> ⚠️ **这条路径不是实际在用的那条。** 业主的服务器（阿里云 ECS，2 vCPU / 1.6 GiB）
> **没装 Docker**，实际部署走的是 [`../native/`](../native/README.md)（PostgreSQL +
> GoTrue 二进制 + systemd），后端已验收 10/10 通过。
> 本目录保留给「有 Docker 的环境」，以及日后迁到 Supabase Cloud 时的配置对照。
> **本目录的 compose / Caddyfile / init SQL 未实际启动验证过**（交付环境 Docker daemon 未运行）。

给 Monster Word 提供**用户名 + 密码的服务端校验**。取代阶段一「密码哈希存本机、
本机自己校验」的做法——那种做法的问题不是哈希算法弱，而是**校验方和被校验方在同一台
设备上**：谁拿到设备谁就能改密码。

三个容器，只做认证这一件事：

```
客户端 ──HTTPS──▶ caddy ──/auth/v1/*──▶ auth (GoTrue) ──▶ db (PostgreSQL)
                 TLS 终止 + 前缀路由      密码校验 / 建号 / 签发会话
```

刻意**不含** Studio / PostgREST / Realtime / Storage：本 App 只需要认证，官方全家桶
会带来数倍内存占用和一个额外的 Web 管理后台入口。管理员重置密码走 `../tools/reset-password.mjs`。

---

## 1. 部署

### 1.1 前置

- Linux + Docker Engine 20.10+ 与 `docker compose` v2（`docker compose version` 能跑即可）
- 一个内网能解析到这台机器的域名，例如 `auth.example.internal`
- 端口 443 / 80 可用（或改 `.env` 里的 `HTTPS_PORT`）

### 1.2 起服务

```bash
cd deploy/supabase
cp .env.example .env

# 生成 JWT 签名密钥
openssl rand -base64 48        # 填到 .env 的 JWT_SECRET
openssl rand -base64 24        # 填到 .env 的 POSTGRES_PASSWORD

# 填好 AUTH_DOMAIN 后启动
docker compose up -d

# 看启动情况（首次会拉镜像 + 跑 GoTrue 迁移，约 1~2 分钟）
docker compose ps
docker compose logs -f auth
```

`auth` 启动时会自动在库里建好 `auth` 模式与全部表，**不需要手动跑迁移**。

### 1.3 验收（必做）

```bash
cd deploy/tools
node smoke-test.mjs --insecure      # Caddy 自签证书时必须带 --insecure
```

这个脚本逐条验证**客户端代码依赖的每一个服务端行为**（9 条断言），每条都对着
GoTrue 上游源码核对过。**全绿之前不要把客户端切到服务端模式。**

### 1.4 客户端构建

```bash
flutter build windows \
  --dart-define=AUTH_BASE_URL=https://auth.example.internal \
  --dart-define=AUTH_ANON_KEY=any-non-empty-string
```

> **关于 `AUTH_ANON_KEY`**：本栈不校验 apikey（anon key 本就随客户端二进制公开，
> 拦不住任何人，只会多一处可能把人锁在门外的配置）。客户端要求这一项非空才切换到
> 服务端模式，所以随便填一个非空值即可。若日后迁到 Supabase Cloud，把它换成 Cloud 的
> anon key。
>
> 想启用 apikey 门禁：`caddy/Caddyfile` 里有一段注释掉的 matcher，取消注释并设置
> `AUTH_ANON_KEY` 环境变量即可。

不传这两个 `--dart-define` 时客户端走**本机模式**（阶段一行为），所以 CI 与本地开发
不受影响。

---

## 2. 运维

### 2.1 用户忘了密码 → 管理员重置

```bash
cd deploy/tools
node reset-password.mjs 张三 --insecure          # 生成随机新密码并打印
node reset-password.mjs 张三 NewPass123 --insecure   # 指定新密码
```

⚠️ 两点必须知道：

1. **只对已迁到服务端的账号有效。** 存量用户（阶段一的本机账号）要先用原密码在
   客户端登录一次，才会在服务端建号；之后才能重置。
2. **重置密码不会踢掉已有会话。** 已登录设备上的 refresh token 仍然有效，直到自然
   过期。要强制下线，目前只能在后台删除该账号让其重新走一遍迁移。

### 2.2 用户名 → 服务端账号地址

服务端存的不是用户名，而是 `u<SHA-256(归一化用户名) 前 24 位>@monster-word.internal`。

```bash
node account-address.mjs 张三          # 用户名 → 地址
node account-address.mjs --list        # 自检：与客户端算法是否仍一致
```

用户名只校验长度（3–32）、不限字符集，直接拼 `用户名@域名` 会让中文用户名被 GoTrue
的邮箱格式校验拒掉（`checkmail.ValidateFormat` 只认 ASCII），所以用哈希派生。
`--list` 的期望值来自客户端 Dart 实现的实际输出，**改动派生算法会让它立刻报警**。

### 2.3 常用排查

```bash
docker compose logs -f auth caddy          # 认证 / 网关日志
docker compose exec db psql -U postgres -c \
  "select count(*) as unconfirmed from auth.users where confirmed_at is null;"
docker compose exec db psql -U postgres -c \
  "select id, email, created_at, last_sign_in_at from auth.users order by created_at desc limit 20;"
docker compose restart auth
```

**上面那条 `unconfirmed` 查询必须恒为 0。** 见 §4。

### 2.4 备份

必须备份的是数据库卷：

```bash
docker compose exec db pg_dump -U postgres -d postgres -Fc > backup-$(date +%F).dump
```

Caddy 卷（`caddy-data`）存的是自签 CA 私钥与证书；丢了只是所有客户端要重新信任一次
新证书，不是数据丢失。

---

## 3. 客户端信任（自签证书）

Caddy 用 `tls internal` 自建 CA 时，客户端必须信任这个 CA：

**Windows**：把 Caddy 的根证书装进「受信任的根证书颁发机构」。

```bash
docker compose exec caddy cat /data/caddy/pki/authorities/local/root.crt > caddy-root.crt
```

**Android**：系统会把它当「用户级 CA」，而 **targetSdk 24+ 的应用默认不信任用户级 CA**。
需要给 App 加一个 network security config：

```xml
<!-- android/app/src/main/res/xml/network_security_config.xml -->
<network-security-config>
    <domain-config>
        <domain includeSubdomains="true">auth.example.internal</domain>
        <trust-anchors>
            <certificates src="system" />
            <certificates src="user" />
        </trust-anchors>
    </domain-config>
</network-security-config>
```

并在 `AndroidManifest.xml` 的 `<application>` 上加
`android:networkSecurityConfig="@xml/network_security_config"`。

> 仓库里**没有**默认加上这个配置：那会让所有用户的 App 都信任任意用户级 CA，
> 为一个内网部署牺牲全体用户的安全基线。只在确实需要自签证书的分支上加。
>
> 更省事的替代方案：用内部 CA 签一张该域名的证书（把 `caddy/Caddyfile` 里的
> `tls internal` 换成 `tls /path/cert.pem /path/key.pem`），或直接用公网域名让
> Caddy 自动申请 Let's Encrypt 证书——两者都不需要改客户端。

---

## 4. 安全约束（改动配置前先读）

| 约束 | 原因 |
|---|---|
| `GOTRUE_MAILER_AUTOCONFIRM` **必须为 true** | 本部署没有邮件服务器。设为 false 会导致：① 注册返回「200 但没有 access_token」的防枚举假成功 → 存量用户永远迁不过来；② **未确认账号可被任何人用 signup 直接接管**（GoTrue 对未确认账号不返回 `user_already_exists`，而是静默确认并发会话）。所以 §2.3 的 `unconfirmed` 查询必须恒为 0。 |
| `GOTRUE_JWT_SECRET` 不得泄露 | 泄露等于任何人可伪造登录态。改动会让所有 token 立即失效。 |
| `JWT_SECRET` / `POSTGRES_PASSWORD` 不进仓库 | `.env` 已在 `.gitignore` 内。 |
| 只暴露 caddy 的 443/80 | `db` 与 `auth` 都只在 compose 内网可达（`expose`，未映射端口）。 |
| 数据库密码改动要手动同步角色 | `db/init/01-auth-role.sql` 只在数据目录为空时执行一次。改 `POSTGRES_PASSWORD` 后需手动 `ALTER USER supabase_auth_admin ...`。 |
| 不做「用户名是否存在」查询接口 | 那等于送出一个用户名枚举接口。客户端已按「是否存在只由登录结果体现」设计。 |

---

## 5. 与客户端契约的对应

完整契约见 [`docs/auth_server_contract.md`](../../docs/auth_server_contract.md)。
其中错误码表是**对着 supabase/auth 上游源码逐条核对**的，不是照文档抄的——
有两处与直觉相反，已在契约里写明：

- 密码授予**不区分**「用户不存在」与「密码错」，两者都是 400 `invalid_credentials`
  （防枚举）。所以客户端不能靠登录响应判断「该建号了」。
- 注册已存在账号返回 **422 `user_already_exists`**（autoconfirm 开启时），
  而不是 400。

存量用户的无感迁移因此改用「本机凭据能否校验通过」作为判据，见
`lib/features/account/data/migrating_account_authenticator.dart`。

---

## 6. 本目录的验证状态（如实说明）

| 项 | 状态 |
|---|---|
| 用户名 → 地址派生（`account-address.mjs`） | ✅ 已用客户端 Dart 实现的真实输出逐条比对（8 个自检向量全中，含中文/空格/`@`/emoji） |
| `gen-service-jwt.mjs` | ✅ 已本地验签并解出声明，`iss` 与 compose 的 `GOTRUE_JWT_ISSUER` 一致 |
| `docker-compose.yml` / `Caddyfile` / `db/init` | ⚠️ **未实际启动验证**（交付环境 Docker daemon 未运行）。镜像版本与关键环境变量取自官方自建栈 `supabase/supabase/docker/docker-compose.yml`。**首次部署必须跑 `smoke-test.mjs` 作为验收门禁。** |
| `smoke-test.mjs` / `reset-password.mjs` | ⚠️ 未对真实服务端跑过（同上），逻辑与断言已按上游源码核对。 |

若 `smoke-test.mjs` 有断言不通过，先看它打印的 `error_code` 与 `HTTP status`——
脚本会把实际值与期望值一起打出来，足以定位是配置问题还是上游行为变化。
