# 账号认证服务端契约（R2-01 阶段二）

> 状态：**客户端已就绪，服务端待部署**。
> - 客户端端口：`lib/features/account/application/account_authenticator.dart`
> - 服务端实现：`lib/features/account/data/supabase_account_authenticator.dart`
> - 迁移装饰器：`lib/features/account/data/migrating_account_authenticator.dart`
> - 部署与运维：`deploy/supabase/`（compose + 验收脚本 + 运维手册）
>
> 技术选型：**自建 Supabase（GoTrue）**，用户名 + 密码。用户名映射为
> `u<SHA-256(归一化用户名) 前 24 位十六进制>@monster-word.internal`（见 §2.4）。
>
> ⚠️ **本文件 §3 的错误码表是逐条对照 supabase/auth 上游源码核对的**，不是照文档抄的。
> 初版曾写「用户不存在 → 400 `user_not_found`」，这在密码授予里**根本不成立**——
> 该错误码只出现在 `/user`、管理接口、`/recover`、外部 OAuth 里，密码授予为了防用户名
> 枚举刻意把它合并进了 `invalid_credentials`。这一条错误会直接导致存量用户永远无法迁移
> （详见 §6）。改动本文件时请同样对着源码核，不要凭印象。

---

## 1. 为什么要服务端

阶段一之前，密码哈希存在客户端安全存储里、由客户端自己校验。问题不是「哈希算法弱」
（PBKDF2-SHA256 6 万轮是够的），而是**校验方和被校验方在同一台设备上**——任何自助
通道都等于「谁拿到设备谁就能改密码」。账号体系要成为真正的边界，校验必须搬到服务端。

服务端同时承接两个阶段一遗留：

| 阶段一做法 | 阶段二做法 |
|---|---|
| 忘记密码 → 提示联系管理员 | 管理员用 `tools/reset-password.mjs` 重置 |
| 账号仅存在于本机 | 账号在服务端；本机只缓存会话 token |

---

## 2. 端点

### 2.1 登录

```
POST /auth/v1/token?grant_type=password
Content-Type: application/json

{ "email": "<派生地址>", "password": "<明文密码>" }
```

成功（200）：

```json
{
  "access_token": "<JWT>",
  "token_type": "bearer",
  "expires_in": 3600,
  "expires_at": 1790000000,
  "refresh_token": "<opaque>",
  "user": { "id": "<uuid>" }
}
```

> 字段名取自上游 `tokens.AccessTokenResponse` 的 json tag，勿改。

### 2.2 创建账号（首次使用）

```
POST /auth/v1/signup
Content-Type: application/json

{ "email": "<派生地址>", "password": "<明文密码>", "data": { "username": "<原始用户名>" } }
```

- 账号不存在 → 200，响应体同 §2.1（`GOTRUE_MAILER_AUTOCONFIRM=true` 时立即签发会话）
- 账号已存在 → **422 `user_already_exists`**
- `data.username` 是给管理员认人用的：派生地址是哈希，后台看不出是谁。

### 2.3 刷新 / 登出

- 刷新：`POST /auth/v1/token?grant_type=refresh_token`
- 登出：`POST /auth/v1/logout`（服务端吊销 refresh token）

### 2.4 用户名 → 账号地址（派生规则）

```
归一化 = username.trim().toLowerCase()        ← 与 SecurePasswordAuthStore 同口径
摘要   = SHA-256(UTF-8(归一化))
地址   = "u" + 摘要前 24 位十六进制 + "@monster-word.internal"
```

**为什么不直接拼 `用户名@域名`**：本 App 的用户名只校验长度（3–32），不限字符集，
存量用户里可能有中文、空格、`@`。GoTrue 用 `checkmail.ValidateFormat` 校验邮箱，
非 ASCII 一律拒绝 ⇒ 这些用户**注册必然失败**，且错误信息难以自诊。哈希派生恒为合法
ASCII 邮箱、定长（25 字符 local-part）、确定性。

**域名刻意做成不可配置**：它只要求恒定。做成可配置等于给了一个「改一下就与所有存量
账号失联」的开关，没有对应收益。

**大小写不敏感**：`Abc` / `abc` / ` ABC ` 是同一个账号——与阶段一本机账号的口径一致，
否则本机认为同一个账号的两种写法会在服务端变成两个账号。

运维侧配套脚本：`deploy/supabase/tools/account-address.mjs`（带自检向量，与 Dart 实现
逐条比对过）。

---

## 3. 错误码 → 客户端 `AuthStatus` 映射（**必须遵守**）

客户端按状态码分流，**不能一律当「登录失败」**——否则用户无法区分「该改密码」还是
「该重试网络」。

| 服务端情形 | HTTP / `error_code` | 客户端 `AuthStatus` | 用户可见文案 |
|---|---|---|---|
| 密码错 | 400 `invalid_credentials` | `invalidCredentials` | 账号或密码不正确 |
| **用户不存在** | **400 `invalid_credentials`** | `invalidCredentials` | （同上，见下方说明） |
| 注册时账号已存在 | 422 `user_already_exists` | `invalidCredentials` | 账号或密码不正确 |
| 密码不满足服务端策略 | 400 `validation_failed` | `serverFailure` + message | 服务端拒绝了该请求（密码可能不满足服务端策略）… |
| 请求过频 / 被限流 | 429（`over_request_rate_limit` 等） | `tooManyAttempts` | 尝试过于频繁，请稍后再试 |
| 账号未确认 | 400 `email_not_confirmed` | `serverFailure` + message | 账号尚未激活，请联系管理员 |
| 账号被停用 | 400 `user_banned` | `serverFailure` + message | 账号已被停用，请联系管理员 |
| 服务端关闭注册 | 422 `signup_disabled` | `serverFailure` + message | 服务端已关闭注册，请联系管理员 |
| 服务端故障 | 5xx | `serverFailure` | 服务暂时不可用，请稍后重试 |
| 网络不可达 | —（客户端判定） | `networkFailure` | 网络异常，请检查网络后重试 |

### 三条与直觉相反、但必须按实际情况实现的地方

1. **`user_not_found` 在密码授予里不存在。** 上游 `ResourceOwnerPasswordGrant`：
   ```go
   if err != nil {
       if models.IsNotFoundError(err) {
           return apierrors.NewBadRequestError(apierrors.ErrorCodeInvalidCredentials, InvalidLoginMessage)
       }
   ```
   用户不存在与密码错**返回完全一样的响应**（防用户名枚举）。因此：
   - 客户端在服务端模式下**永不**返回 `AuthStatus.needsAccountCreation`；
   - 「该建号了」的判断改由本机凭据承担，见 §6。

2. **注册已存在账号是 422 而不是 400**，且只在 `user.IsConfirmed()` 时短路
   （`GOTRUE_MAILER_AUTOCONFIRM=true` 下新建账号立即确认，所以正常情况都走这条）。
   客户端按端口契约把它**收敛为 `invalidCredentials`**，不向用户暴露「该用户名已存在」——
   避免把登录页变成用户名枚举探针。

3. **`validation_failed` 不能并进「密码不正确」。** 它的典型触发是服务端密码策略比客户端
   严（客户端只校验 6–64 位）。并进去会让用户反复重输同一个密码，而真正的动作是
   「换一个更复杂的密码」。故单独映射并带 message。

**不要**提供 `GET /users/exists` 之类的独立查询——那是送出一个用户名枚举接口。
（注意：`/signup` 本身对已存在账号返回 422，客观上也是个存在性探针。内部应用可接受；
若要收紧，只能靠 §5 的限流。这一点已知并接受。）

---

## 4. 会话与离线

业主决策：**登录一次、之后离线可用**。

- `access_token` 有效期 1 小时（`GOTRUE_JWT_EXP=3600`）；`refresh_token` 建议 30 天。
- 客户端把整包会话（access + refresh + expiresAt + userId）**原子地**存在平台安全存储的
  单一 key 里（`mw.auth.session.v1`），与旧 `userToken`/`userSecret` 字段刻意分开：
  后者是原版遗留的用户资料缓存，复用同一 key 会让「退出登录」误清资料缓存。
- **续期失败不得阻断使用**：应用是本地优先的，学习数据都在本机；只有需要服务端的能力
  （多端同步等）才要求在线。

### 已实现 / 未实现（如实标注）

| 项 | 状态 |
|---|---|
| 登录成功后持久化会话 | ✅ 已实现（`SupabaseAccountAuthenticator` → `AuthSessionStore.write`） |
| 启动时静默续期（`refresh_token` 换新） | ❌ **未实现**。需要给 `AccountAuthenticator` 端口加 `refresh()`，牵动全部实现者与 UI 分流；留作阶段三 |
| 登出时服务端吊销 refresh token | ❌ **未实现**。当前登出只清本机会话，服务端 refresh token 到期前仍有效 |

后两项未实现期间的实际影响：**用户不会因此登不上**（本地优先），但「退出登录」在
服务端意义上不彻底。`AuthSessionStore` 的 `read()` / `clear()` 就是为这两项预留的接口。

---

## 5. 安全要求

| 项 | 要求 |
|---|---|
| 传输 | 仅 HTTPS。内网自签证书时客户端需信任该 CA（Android 还要 network_security_config，见部署手册 §3） |
| 密码哈希 | 由 GoTrue 负责（bcrypt）。**客户端不得再自行校验密码**（迁移判定的本机校验是唯一例外，且只用于「是否已迁移」，不产出登录态） |
| 限流 | GoTrue 内置**按 IP** 限流，需设 `GOTRUE_RATE_LIMIT_HEADER=x-forwarded-for` 才能取到真实客户端 IP。**按用户名的维度 GoTrue 不提供**——原先写的「双维度」是过高的承诺，实际靠客户端登录页的每分钟尝试上限兜底 |
| 账号锁定 | 连续失败达阈值后由限流返回 429（客户端映射 `tooManyAttempts`）。GoTrue **没有**「锁定 N 分钟」的独立机制 |
| 密码强度 | 客户端校验 6–64 位；服务端 `GOTRUE_PASSWORD_MIN_LENGTH=6` 再校验一次（客户端校验不是边界） |
| RLS | 后续若加同步表必须开 RLS：`auth.uid() = user_id`，否则一个用户能读到所有人的数据。**当前部署不含 PostgREST，尚无此类表** |
| anon key | 客户端内置的是 anon key（公开无妨）。**service_role key 绝不可下发到客户端**；自建栈里管理员用的 service JWT 由 `tools/gen-service-jwt.mjs` 现场签发，不落地 |
| **`GOTRUE_MAILER_AUTOCONFIRM` 必须为 true** | 本部署无邮件服务器。若为 false：① 注册会变成「200 但没有 access_token」的防枚举假成功 → 存量用户永远迁不过来；② **未确认账号可被任何人用 signup 直接接管**（GoTrue 对未确认账号不返回 `user_already_exists`，而是静默确认并签发会话）。故运维上必须保证 `select count(*) from auth.users where confirmed_at is null` **恒为 0** |

---

## 6. 现有用户迁移（无感）

本机账号体系自 **v2.7.24+65** 起就已发布，`v2.12.2+128` 里仍在——存量用户是真实的。
这些账号只存在本机，服务端没有。

### 6.1 判据

服务端拒绝（400 `invalid_credentials`）时无法区分「密码打错」与「账号还没迁过来」。
判据不靠猜，用**本机已有的证据**：

> 本机安全存储里存着这个用户名的凭据、且用户输入的密码能通过本机校验
> ⇒ 用户输入的密码**就是对的** ⇒ 服务端仍拒绝 ⇒ 服务端确实没有这个账号 ⇒ 可以安全建号。

反之（本机凭据校验不过、或本机压根没这个用户名）⇒ 不迁移，如实回报「账号或密码不正确」。

**不做「先 signup 试探」**：那会在用户每次打错密码时都发一次注册请求，既浪费又会撞限流。

### 6.2 流程

```
用户输入 用户名 + 原密码
        │
        ├─ signIn ──▶ 200 ──────────────────────▶ 登录成功（老用户）
        │
        └─ 400 invalid_credentials
                │
                ├─ 本机凭据校验不通过 ─────────▶ 「账号或密码不正确」（真的打错了）
                │
                └─ 本机凭据校验通过
                        │
                        ├─ createAccount ──▶ 200 ─▶ 迁移完成 + 删除本机哈希（存量用户）
                        │
                        └─ 422 user_already_exists ─▶ 「账号或密码不正确」
                                                     （服务端已有该账号，密码确实不对）
```

**用户视角**：输入同一个密码即可，没有任何额外的迁移动作，也没有「首次使用将创建账号」
之外的确认弹窗（该弹窗是阶段一就有的）。

### 6.3 安全性

- 建号路径**不会覆盖已有账号的密码**：GoTrue 对已确认账号在写密码之前就返回
  `user_already_exists`。即使判据失误，最坏结果也只是「多一次无副作用的失败请求」。
- 迁移成功后删除本机哈希（`PasswordAuthStore.removePassword`）：否则「密码只提交给服务端
  校验」这句披露就成了假话。

### 6.4 覆盖不到的情况（需运维兜底）

**换了新设备、且服务端还没有该账号的存量用户**无法自动迁移——本机没有可用的凭据证据。
这类用户会看到「账号或密码不正确」。兜底方式：管理员用 `tools/reset-password.mjs` 或
直接为其预置账号。

**取舍（需业主知晓）**：迁移路径意味着「先到先得」——谁先用某个用户名注册，谁就拥有它。
内部应用可接受。若要收紧，需管理员预置账号名单，多一步运维流程。

---

## 7. 客户端接入点

装配点只有一处（`lib/features/account/presentation/account_feature_providers.dart`），
**已实现**：

```dart
final localStore = context.read<PasswordAuthStore>();
const config = AuthServerConfig.fromEnvironment;
if (!config.isConfigured) return LocalAccountAuthenticator(localStore);   // 本机模式
return MigratingAccountAuthenticator(
  remote: SupabaseAccountAuthenticator(
    baseUrl: config.baseUrl,          // --dart-define=AUTH_BASE_URL
    anonKey: config.anonKey,          // --dart-define=AUTH_ANON_KEY
    sessionStore: context.read<AuthSessionStore>(),
  ),
  localStore: localStore,
);
```

**未注入 `--dart-define` 时走本机模式**（阶段一行为），所以 CI 与本地开发不受影响。
配置只配一半（比如漏了 key）也视为未配置——否则会连上去被 401 挡下，错误信息比
「本机模式」更难自诊。

UI 层（`login_page.dart`）与端口本身**不需要改动**：它已按 `auth.scope` 区分弹窗措辞
（`AccountScope.local` → 「仅存本机，不上传」；`remote` → 「密码会通过加密连接提交给
服务端用于校验」）。

---

## 8. 验收

### 8.1 客户端行为（CI 自动跑）

| 文件 | 覆盖 |
|---|---|
| `test/features/account/data/supabase_account_authenticator_test.dart` | §3 映射表逐条 + 地址派生（中文/空格/`@`/emoji）+ 200 无 `access_token` 必须判失败 |
| `test/features/account/data/migrating_account_authenticator_test.dart` | §6 判据的正反面：网络/限流**不得**被解释成「账号不存在」 |
| `test/features/account/data/auth_session_store_test.dart` | 会话序列化容错（损坏一律返回 null） |
| `test/features/account/data/secure_auth_session_store_test.dart` | 整包原子读写、损坏自愈、key 与旧字段隔离 |
| `test/features/account/data/local_account_authenticator_test.dart` | 本机模式（阶段一行为不回退） |

### 8.2 服务端行为（部署后必跑）

`deploy/supabase/tools/smoke-test.mjs` —— 9 条断言，逐条对应上表的服务端侧：

- `/health` 可达（TLS 握手成功）
- 注册返回 200 且**含 access_token**（证明 `GOTRUE_MAILER_AUTOCONFIRM` 真的生效）
- 重复注册 → 422 `user_already_exists`
- 正确密码 → 200 + token
- 错误密码 → 400 `invalid_credentials`
- **用户不存在 → 400 `invalid_credentials`（不得是 `user_not_found`）** ← 迁移方案的前提
- 中文用户名可注册（证明地址派生对非 ASCII 有效）
- 大小写/首尾空格归一为同一账号
- 清理测试账号

**全绿之前不要把客户端切到服务端模式。**
