# 账号认证服务端契约（R2-01 阶段二）

> 状态：**待实现**（阶段一「移除短信链路」已上线，见 PR #132）。
> 客户端侧已按本契约抽好端口：`lib/features/account/application/account_authenticator.dart`，
> 服务端就绪后只需在 `account_feature_providers.dart` 换一行装配。
>
> 技术选型：**自建 Supabase**（用户名 + 密码）。用户名映射为
> `username@<内部域名>`（Supabase 以邮箱为标识；内部域名不可投递、也无需邮箱服务器）。

---

## 1. 为什么要服务端

阶段一之前，密码哈希存在客户端安全存储里、由客户端自己校验。问题不是「哈希算法弱」
（PBKDF2-SHA256 6 万轮是够的），而是**校验方和被校验方在同一台设备上**——任何自助
通道都等于「谁拿到设备谁就能改密码」。账号体系要成为真正的边界，校验必须搬到服务端。

服务端同时承接两个阶段一遗留：

| 阶段一做法 | 阶段二做法 |
|---|---|
| 忘记密码 → 提示联系管理员 | 管理员在 Supabase 后台重置 |
| 账号仅存在于本机 | 账号在服务端；本机只缓存会话 token |

---

## 2. 端点

### 2.1 登录

```
POST /auth/v1/token?grant_type=password
Content-Type: application/json

{ "email": "<username>@<内部域名>", "password": "<明文密码>" }
```

成功（200）：

```json
{
  "access_token": "<JWT>",
  "refresh_token": "<opaque>",
  "expires_in": 3600,
  "user": { "id": "<uuid>" }
}
```

### 2.2 创建账号（首次使用）

```
POST /auth/v1/signup
Content-Type: application/json

{ "email": "<username>@<内部域名>", "password": "<明文密码>" }
```

成功（200）：同 2.1 的响应体。

### 2.3 刷新 / 登出

- 刷新：`POST /auth/v1/token?grant_type=refresh_token`
- 登出：`POST /auth/v1/logout`（服务端吊销 refresh token）

---

## 3. 错误码 → 客户端 `AuthStatus` 映射（**必须遵守**）

客户端会按状态码分流，**不能一律当「登录失败」**——否则用户无法区分「该改密码」还是
「该重试网络」。

| 服务端情形 | HTTP / 错误码 | 客户端 `AuthStatus` | 用户可见文案 |
|---|---|---|---|
| 密码错 | 400 `invalid_grant` | `invalidCredentials` | 账号或密码不正确 |
| 用户不存在 | 400 `user_not_found` | `needsAccountCreation` | （不提示，转创建流程） |
| 请求过频 / 被限流 | 429 | `tooManyAttempts` | 尝试过于频繁，请稍后再试 |
| 服务端故障 | 5xx | `serverFailure` | 服务暂时不可用，请稍后重试 |
| 网络不可达 | —（客户端判定） | `networkFailure` | 网络异常，请检查网络后重试 |

**注意**：`user_not_found` 只允许出现在**登录**响应里。**不要**提供
`GET /users/exists` 之类的独立查询——那是送出一个用户名枚举接口。客户端已按
「是否存在只由登录结果体现」设计（`signIn` 返回 `needsAccountCreation`）。

---

## 4. 会话与离线

业主决策：**登录一次、之后离线可用**。

- `access_token` 有效期建议 1 小时；`refresh_token` 建议 30 天。
- 客户端持久化 refresh token 到平台安全存储，启动时静默续期。
- **续期失败不得阻断使用**：应用是本地优先的，学习数据都在本机；只有需要服务端
  的能力（多端同步等）才要求在线。
- 登出必须**服务端吊销** refresh token（否则「退出登录」只在本机生效）。

---

## 5. 安全要求

| 项 | 要求 |
|---|---|
| 传输 | 仅 HTTPS；内网部署也要证书（可用内部 CA） |
| 密码哈希 | 由 Supabase Auth 负责（bcrypt）。**客户端不得再自行校验密码** |
| 限流 | 按用户名 + 按 IP 双维度。Supabase 内置限流，需在后台调好阈值 |
| 账号锁定 | 连续失败达阈值锁定并返回 429（客户端映射 `tooManyAttempts`） |
| 密码强度 | 客户端已校验 6–64 位；服务端应再校验一次（客户端校验不是边界） |
| RLS | 后续同步表必须开 RLS：`auth.uid() = user_id`，否则一个用户能读到所有人的数据 |
| 匿名 key | 客户端内置的是 **anon key**（公开无妨，受 RLS 约束）；**service_role key 绝不可下发到客户端** |

---

## 6. 现有用户迁移（无感）

阶段一的账号只存在本机，服务端没有这些用户。迁移策略：

1. 用户输入原用户名 + 原密码。
2. 服务端返回 `user_not_found` → 客户端弹「首次使用，将在服务端创建账号」确认。
3. 用户确认 → 调 `signup`，用**同一个密码**建号。
4. 此后密码由服务端校验；本机不再保存密码哈希。

**用户视角**：输入同一个密码即可，与阶段一「首次使用创建本机账号」的确认步骤
完全一致 —— 没有额外的迁移动作。

**取舍（需业主知晓）**：这条路径意味着「先到先得」——谁先用某个用户名注册，谁就
拥有它。内部应用可接受；若要收紧，需要管理员预置账号名单（服务端加白名单校验），
这会多一步运维流程。**当前按「先到先得」实现**。

---

## 7. 客户端接入点

服务端就绪后，**只改这一处**：

```dart
// lib/features/account/presentation/account_feature_providers.dart
Provider<AccountAuthenticator>(
  create: (context) => SupabaseAccountAuthenticator(...),  // ← 换成本实现
),
```

新增 `SupabaseAccountAuthenticator implements AccountAuthenticator`，需满足：

- `scope` → `AccountScope.remote`（UI 据此把「创建账号」弹窗措辞改为「密码会提交给服务端」）
- `signIn` / `createAccount` → 按 §2、§3 调用并映射错误码
- **不做 UI 交互**、**不抛异常**（失败一律返回 `AuthOutcome`）
- 负责持久化 access/refresh token

UI 层（`login_page.dart`）与端口本身**不需要改动**。

---

## 8. 验收测试（服务端实现必须通过）

以下断言在 `test/features/account/data/local_account_authenticator_test.dart` 里已按
本机实现写好，服务端实现应照搬同一组（只换被测实现）：

- 账号不存在 → `needsAccountCreation`（不是失败）
- 密码正确 → `success`
- 密码错误 → `invalidCredentials`
- 限流 → `tooManyAttempts`
- 5xx → `serverFailure`
- 网络不可达 → `networkFailure`
- 创建账号遇到已存在 → `invalidCredentials` 且**不覆盖原密码**
