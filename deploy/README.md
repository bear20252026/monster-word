# 自建认证后端 —— 两条部署路径

给 Monster Word 提供**用户名 + 密码的服务端校验**（R2-01 阶段二）。
取代阶段一「密码哈希存本机、本机自己校验」的做法——那种做法的问题不是哈希算法弱，
而是**校验方和被校验方在同一台设备上**：谁拿到设备谁就能改密码。

| 路径 | 用在哪 | 状态 |
|---|---|---|
| [`native/`](native/README.md) | **实际在用的这条**。业主自己的阿里云 ECS（Ubuntu 24.04，2 vCPU / 1.6 GiB，**无 Docker**） | ✅ 已部署，后端 10/10 验收通过 |
| [`supabase/`](supabase/README.md) | 有 Docker 的环境；或日后迁到 Supabase Cloud 的对照参考 | ⚠️ 本机 Docker daemon 未运行，未实测 |
| [`tools/`](tools/README.md) | 两条路径共用的运维脚本（只跟 HTTP 接口打交道，与部署方式无关） | ✅ 已实测 |

**先读哪份**：部署这台机器看 `native/README.md`；只想了解认证接口与契约看
[`../docs/auth_server_contract.md`](../docs/auth_server_contract.md)。

---

## 运维脚本（`tools/`）

| 脚本 | 用途 |
|---|---|
| `smoke-test.mjs` | **验收门禁**：逐条验证客户端契约依赖的服务端行为。全绿之前不要把客户端切到服务端模式 |
| `reset-password.mjs` | 管理员重置某个用户的密码（走管理接口，不直接改库——哈希算法由 GoTrue 决定） |
| `account-address.mjs` | 用户名 → 服务端账号地址反查（服务端存的是哈希派生地址，认不出是谁） |
| `gen-service-jwt.mjs` | 现场签发 service_role JWT（用完即弃，不落地） |

脚本会在 `../.env`、`../supabase/.env`、`./.env` 三处按优先级找配置，所以放在
`deploy/tools/`（配 docker 路径的 `.env`）或服务器上的 `/opt/mw-auth/tools/`
（配原生路径的 `.env`）都能直接用。

---

## 架构（两条路径共用的契约）

```
客户端 ──HTTPS──▶ 网关 ──/auth/v1/*──▶ GoTrue ──▶ PostgreSQL
                  TLS 终止 + 前缀路由   密码校验 / 建号 / 签发会话
```

客户端只认一个编译期常量：`AUTH_BASE_URL`（不含 `/auth/v1`）。
不注入即走**本机模式**，CI 与本地开发不受影响。

服务端只暴露 `/auth/v1/*` 一个前缀，路径约定与 Supabase Cloud 完全一致 ——
日后若迁到 Cloud，客户端一行都不用改。
