# 认证与授权安全审计报告

> 审计人：DevOps（Claude Code）
> 日期：2026-08-24
> 方式：只读代码审计
> 审计范围：登录/注册、会话管理、本地数据保护、权限控制、密码存储

---

## 1. 用户认证机制

### 1.1 登录方式

| 登录方式 | 状态 | 说明 |
|---|---|---|
| 账号密码登录 | ⚠️ 半实现 | UI 完整，但 `login()` 为 TODO stub（直接返回 true） |
| 手机号+验证码登录 | ⚠️ 半实现 | UI 完整，但 `phoneLogin()` 为 TODO stub |
| 第三方登录 | ⚠️ 框架存在 | 微信/QQ/微博/华为入口存在，具体实现待确认 |
| 自动登录 | ❓ 未确认 | `LoginCheckService.check()` 检查 token 有效性（2 秒超时） |

### 1.2 登录状态判断

```dart
// learning_state.dart:495
bool get isLoggedIn => _isLoggedIn;
```

- `_isLoggedIn` 为内存中的 bool 值，**未持久化**
- 应用重启后登录状态丢失（除非 token 有效）
- `LoginCheckService` 通过 `login/verification` API 验证 token

**风险**：`_isLoggedIn` 内存标志可被调试器修改，绕过登录检查。

---

## 2. 会话管理

### 2.1 Token 存储

| 项 | 状态 | 说明 |
|---|---|---|
| Token 存储位置 | ⚠️ SharedPreferences | `AppPreferences.userToken` 键：`user_token` |
| Secret 存储位置 | ⚠️ SharedPreferences | `AppPreferences.userSecret` 键：`user_secret` |
| 加密存储 | ❌ **明文** | SharedPreferences 以明文 XML 存储在设备上 |
| Token 刷新 | ✅ 有 | v3 API 响应中的 `v3_security.token/secret` 自动更新 |
| Token 过期检测 | ✅ 有 | 错误码 `30102`/`30104` 触发账号过期回调 |

### 2.2 Token 生命周期

```
登录 → 服务端返回 token+secret → 存入 SharedPreferences（明文）
  ↓
每次 API 请求 → 从 SharedPreferences 读取 token → 附加到请求参数
  ↓
服务端响应 v3_security → 更新本地 token/secret
  ↓
Token 过期(30102/30104) → 触发 onAccountExpire 回调
```

**风险**：
- Token 明文存储，root 设备或备份可提取
- 无 token 刷新队列，并发请求可能使用过期 token
- `_dealExpireDlgTime` 防抖 120 秒，期间过期请求静默失败

### 2.3 会话隔离

| 项 | 状态 | 说明 |
|---|---|---|
| 多用户支持 | ⚠️ 有框架 | `switchToUser(userId)` 通过 key 前缀隔离 |
| 用户级 key 前缀 | ✅ 有 | `{userId}.xxx` 格式区分不同用户数据 |
| 用户切换安全 | ⚠️ 弱 | 切换用户不清除旧用户的内存缓存 |

---

## 3. 本地数据保护

### 3.1 学习进度数据

| 存储方式 | 数据 | 保护 |
|---|---|---|
| SharedPreferences | 学习进度、设置、用户信息 | ❌ 明文，可任意修改 |
| SQLite (wordbook.db) | 词库数据（只读） | ⚠️ gzip 压缩但无加密 |
| 内存 (LearningState) | 当前学习队列、SRS 卡片 | ❌ 应用退出即丢失 |

**风险**：
- 学习进度（打卡天数、已学单词数、SRS 间隔）可直接通过修改 SharedPreferences 篡改
- 酷币/装备等成就数据可伪造
- 无数据完整性校验（无 HMAC/签名）

### 3.2 数据库安全

| 项 | 状态 | 说明 |
|---|---|---|
| 词库加密 | ❌ 无 | `wordbook.db` 为标准 SQLite，gzip 仅压缩 |
| 数据库签名 | ❌ 无 | 无完整性校验，可替换为恶意数据库 |
| SQL 注入 | ✅ 安全 | 使用 sqflite 参数化查询 |

---

## 4. 权限控制

### 4.1 多用户隔离

| 项 | 状态 | 说明 |
|---|---|---|
| 用户数据隔离 | ⚠️ 逻辑隔离 | 通过 key 前缀 `{userId}.xxx` 隔离 |
| 物理隔离 | ❌ 无 | 所有用户数据在同一个 SharedPreferences 文件中 |
| 权限提升 | ⚠️ 无校验 | 修改 SharedPreferences 可伪造任意用户身份 |

### 4.2 API 权限

| 项 | 状态 | 说明 |
|---|---|---|
| Token 认证 | ✅ 有 | v3 API 自动附加 token |
| 签名校验 | ✅ 有 | 请求参数签名（AES+MD5） |
| 角色控制 | ❌ 无 | 客户端无角色/权限概念 |

---

## 5. 自动登录/记住密码

### 5.1 实现分析

| 项 | 状态 | 说明 |
|---|---|---|
| 记住密码 | ⚠️ 有接口 | `savePassword()`/`getPassword()` 但标记为"已废弃" |
| 密码存储 | ❌ **明文** | SharedPreferences 键 `userPwd` 直接存储密码 |
| 自动登录 | ✅ Token 方式 | 应用启动时通过 `LoginCheckService` 验证 token |
| 生物识别 | ❌ 无 | 无指纹/面容解锁保护 |

### 5.2 密码哈希

```dart
// app_utils.dart:16
static String getPasswordHash(String str) {
  final bytes = utf8.encode(str).toList();
  final b = (bytes.length * 73) & 0xFF;
  for (var i = 0; i < length; i++) {
    bytes[i] = (bytes[i] ^ b) & 0xFF;
  }
  return md5(bytes);
}
```

**分析**：
- XOR 混淆 + MD5 哈希
- XOR 密钥由密码长度派生（`length * 73`），可逆
- MD5 已被认为不安全（碰撞攻击）
- 但此函数**当前未被调用**（login 为 stub）

---

## 6. 密码安全

### 6.1 密码传输

| 项 | 状态 | 说明 |
|---|---|---|
| 传输加密 | ✅ HTTPS | 密码通过 TLS 传输 |
| 应用层加密 | ❌ 无 | 密码明文作为 POST 表单参数 |
| 密码字段 | ⚠️ 日志泄露 | `_traceParams()` 可能打印含密码的请求参数 |

### 6.2 密码存储

| 项 | 状态 | 说明 |
|---|---|---|
| 本地存储 | ❌ 明文 | `savePassword()` 直接写入 SharedPreferences |
| 存储标记 | ✅ 已废弃 | 注释标注"已废弃，保留兼容" |
| 建议 | — | 使用 `flutter_secure_storage` 或完全移除密码本地存储 |

---

## 7. 综合评分

| 维度 | 评分 | 说明 |
|---|---|---|
| 认证机制 | 4/10 | 框架存在但核心逻辑为 stub |
| 会话管理 | 5/10 | 有 token 过期检测，但明文存储 |
| 本地数据保护 | 3/10 | 无加密、无完整性校验 |
| 权限控制 | 4/10 | 逻辑隔离弱，无物理隔离 |
| 密码安全 | 3/10 | 明文存储、弱哈希 |
| **综合** | **3.8/10** | **🟠 中高风险** |

---

## 8. 修复建议

| # | 问题 | 严重度 | 建议 |
|---|---|---|---|
| 1 | Token/Secret 明文存储 | 🔴 高 | 迁移到 `flutter_secure_storage`（Keychain/Keystore） |
| 2 | 密码明文存储 `userPwd` | 🔴 高 | 移除 `savePassword`/`getPassword` 或加密存储 |
| 3 | 学习数据无完整性保护 | 🟠 中 | 添加 HMAC 签名防篡改 |
| 4 | `_isLoggedIn` 未持久化 | 🟠 中 | 基于 token 有效性判断而非内存标志 |
| 5 | 密码哈希弱（XOR+MD5） | 🟡 低 | 若保留密码功能，改用 bcrypt/scrypt |
| 6 | 日志泄露请求参数 | 🟡 低 | Release 包禁用 `print()` |
| 7 | 多用户物理隔离 | 🟡 低 | 每用户独立 SharedPreferences 文件 |

---

*审计完成：DevOps（Claude Code）· 2026-08-24 · 只读审计*
