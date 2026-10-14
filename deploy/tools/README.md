# 运维脚本

只跟 HTTP 接口打交道，与部署方式（原生 / 容器）无关。复制整个目录到服务器即可用。

配置查找顺序（第一个命中的值优先，不覆盖）：`../.env` → `../supabase/.env` → `./.env`。
都找不到就只认环境变量。

变量名同时认两套：

| 用途 | docker 路径 | 原生路径 |
|---|---|---|
| JWT 签名密钥 | `JWT_SECRET` | `MW_JWT_SECRET` |
| 对外域名 | `AUTH_DOMAIN` | `MW_AUTH_DOMAIN` |

---

## `smoke-test.mjs` —— 验收门禁

```bash
node smoke-test.mjs                                  # 用 .env 里的 AUTH_DOMAIN
node smoke-test.mjs --insecure                        # 自签证书时跳过 TLS 校验
node smoke-test.mjs --keep                            # 保留测试账号（默认跑完删除）
node smoke-test.mjs --base-url http://127.0.0.1:9999   # 直连后端，绕过网关
```

`--base-url` 的用处：**域名还没接好之前**先在服务器上验后端行为。这样验不到网关的
前缀剥离与 TLS——那两条由 `enable-caddy-route.sh` 的回归验证覆盖。

### 它验什么（每条都对应客户端代码里的一处假设）

| # | 断言 | 为什么必须有 |
|---|---|---|
| 1 | `/health` 可达 | 后端活着 |
| 2 | 注册返回 200 **且含 `access_token`** | 证明 `GOTRUE_MAILER_AUTOCONFIRM=true` 真的生效。为 false 时注册会变成「200 但没有 token」的防枚举假成功，存量用户永远迁不过来 |
| 3 | 重复注册 → 422 `user_already_exists` | 迁移判定靠它区分「已存在」与「真打错了密码」 |
| 4 | 正确密码 → 200 + token | 主路径 |
| 5 | 错误密码 → 400 `invalid_credentials` | |
| 6 | **用户不存在 → 400 `invalid_credentials`（不得是 `user_not_found`）** | 上游为防枚举刻意合并了这两种情况。**迁移方案的前提**：若哪天变成 `user_not_found`，说明上游行为变了，客户端迁移逻辑要重新评估（脚本会专门提示） |
| 7 | 中文用户名可注册 | 证明「用户名 → 哈希派生地址」有效（GoTrue 的邮箱格式校验会拒非 ASCII） |
| 8 | 大小写/空格归一为同一账号 | 与 `SecurePasswordAuthStore` 同口径 |
| 9 | 清理测试账号 | 不留垃圾数据 |

退出码：全绿 0，有失败 1。

---

## `reset-password.mjs` —— 管理员重置密码

```bash
node reset-password.mjs <用户名>                 # 生成随机新密码并打印
node reset-password.mjs <用户名> <新密码>
node reset-password.mjs <用户名> --insecure
```

**为什么走管理接口而不是直接改库**：密码哈希算法与参数由 GoTrue 决定。用 SQL 自己写
`crypt(...)`，在算法换掉之后会**静默**产生一个永远校验不过的密码——用户以为改了，其实登不上。

⚠️ 两点须知：

1. 只对**已迁到服务端**的账号有效。存量用户（阶段一的本机账号）要先用原密码在客户端
   登录一次才会在服务端建号。
2. **重置密码不会踢掉已有会话**。已登录设备上的 refresh token 仍有效直到自然过期。
   当前客户端未实现「登出吊销服务端会话」，要强制下线只能删账号让其重走迁移。

---

## `account-address.mjs` —— 用户名 ↔ 账号地址

```bash
node account-address.mjs 张三 bob        # 用户名 → 地址
node account-address.mjs --list          # 自检：与客户端 Dart 算法是否仍一致
```

服务端存的是 `u<SHA-256(归一化用户名) 前 24 位十六进制>@monster-word.internal`。
用户名只校验长度（3–32）、不限字符集，直接拼 `用户名@域名` 会让中文用户名被 GoTrue 拒，
所以用哈希派生。真实用户名随注册写进 `user_metadata`，管理员靠它认人。

`--list` 的期望值来自客户端 Dart 实现的实际输出——**改动派生算法会让它立刻报警**，
不要在没同步客户端的情况下改。

---

## `gen-service-jwt.mjs` —— 现场签发 service_role JWT

```bash
node gen-service-jwt.mjs
```

打印一个 1 小时有效的 service_role JWT（HS256，`iss` 与 `GOTRUE_JWT_ISSUER` 一致）。

**为什么不存一份在 `.env` 里**：这个 key 等价于整个认证库的读写权。存下来就多一份会
泄露的文件；按需用 `JWT_SECRET` 现签，用完即弃。

⚠️ 输出是密钥，别粘进聊天记录、工单、CI 日志。
