# 安全与隐私审计报告

> 审计人：DataEngineer（Monster world）· 2026-08-24
> 项目：word_app（Monster Word）
> 方法：只读代码审计

---

## 一、网络请求安全

### 1.1 传输层

| 项目 | 状态 | 说明 |
|---|---|---|
| HTTPS | ⚠️ 部分 | `http_client.dart` 使用 `https://sapi.beingfine.cn`（v1/v3），但 `api_services.dart:90-91` 定义了 `http://api.beingfine.cn/` 和 `http://img.beingfine.cn/`（HTTP 明文） |
| 证书校验 | ✅ | Flutter http 包默认校验证书（无自定义 SSLSocketFactory 跳过） |
| 超时控制 | ✅ | 30 秒默认超时，可配置 |

### 1.2 认证与签名

| 项目 | 状态 | 说明 |
|---|---|---|
| Token 传输 | ⚠️ | Token 通过 URL query 参数传输（`requestParamsWithToken` 添加 `token` 参数），URL 参数会被服务器日志、代理记录 |
| 签名机制 | ⚠️ | `sign = md5(sorted_params + secret)` — MD5 已不推荐用于安全场景；且 secret 为硬编码常量 |
| API 密钥 | 🔴 **高风险** | `api_services.dart:94` 硬编码 `_userSecret = 'iscooler'`；`crypto_utils.dart:16-24` 硬编码默认 AES 密钥 `'iscooler'`；`http_client.dart:136` 硬编码 IV `'1pat2rqs'` |

### 1.3 敏感数据传输

| 数据 | 传输方式 | 风险 |
|---|---|---|
| 用户 token | URL query 参数 | 中 — URL 被日志/缓存/Referer 泄露 |
| 用户 secret | 响应 `v3_security` 字段返回后本地存储 | 中 — 明文存储 |
| 手机号 | POST body（`phone_number` 参数） | 低 — body 不会被 URL 记录 |
| 短信验证码 | POST body（`sms_code` 参数） | 低 — 同上 |
| 学习数据 | POST body（sync_file） | 低 — 同上 |

---

## 二、本地存储安全

### 2.1 SharedPreferences 明文存储

| 键 | 类型 | 敏感度 | 说明 |
|---|---|---|---|
| `user_token` | String | 🔴 高 | 用户认证 token，明文存储 |
| `user_secret` | String | 🔴 高 | API 加密 secret，明文存储 |
| `key_userId` | String | 中 | 用户 ID |
| `userPwd` | String | 🔴 高 | 密码（已废弃但仍可读写，`app_preferences_ext.dart:768`） |
| `userInfo` | String (JSON) | 中 | 用户信息 Bean（含 userId/nickname/avatar/phone） |
| `key_last_login_info` | String | 中 | 登录信息 |
| `srs_cards_v1` | String (JSON) | 低 | 学习进度 |
| `fav_sentence_list` | String (JSON) | 低 | 收藏例句 |

**问题**：所有敏感信息以明文存储在 SharedPreferences 中。Android 上 SharedPreferences 文件位于 `/data/data/<package>/shared_prefs/`，root 设备可直接读取。

### 2.2 SQLite 数据库

| 数据库 | 加密 | 风险 |
|---|---|---|
| wordbook.db | ❌ 无加密 | 低 — 只读词库，非敏感数据 |
| user_data.db | ❌ 无加密 | 中 — 包含用户收藏/学习进度 |
| notes.db | ❌ 无加密 | 中 — 包含用户笔记 |
| TrackLog.db（日志） | ❌ 无加密 | 中 — 包含用户行为追踪数据 |

**建议**：考虑使用 `sqflite_sqlcipher` 替代 `sqflite` 对用户数据库加密。

---

## 三、日志泄漏检查

### 3.1 print/debugPrint 语句

| 文件 | 行号 | 内容 | 风险 |
|---|---|---|---|
| `http_client.dart:305/535` | `print('$_logTag request: $uri')` | 🔴 可能泄漏含 token 的完整 URL |
| `http_client.dart:469/751` | `print('$_logTag RequestParams: ${params.toString()}')` | 🔴 泄漏所有请求参数（含 token/secret/sign） |
| `http_client.dart:87/113` | `print('CoolHttpResponse parse JsonError: $e')` | 低 — 解析错误 |
| `http_client.dart:150-153` | `failTrace()` 打印错误详情 | 低 — 仅错误时触发 |
| `api_services.dart:623` | `print('$_logTag: 链式同步开始')` | 低 — 状态日志 |
| `statistics.dart:138` | 已注释 | ✅ 无风险 |

**关键问题**：`_traceParams` 在每次请求时打印完整参数列表，包含 `token`、`sign`、`secret` 等敏感字段。在 release 构建中应禁用。

---

## 四、第三方包数据收集

### 4.1 依赖包清单

| 包 | 版本 | 数据收集 | 风险 |
|---|---|---|---|
| `sqflite` | 2.4.1 | 无 | ✅ |
| `shared_preferences` | 2.3.3 | 无 | ✅ |
| `http` | 1.2.2 | 无 | ✅ |
| `audioplayers` | 6.1.0 | 无 | ✅ |
| `just_audio` | 0.9.42 | 无 | ✅ |
| `webview_flutter` | 4.10.0 | ⚠️ WebView 可加载外部 URL | 中 — 需确保只加载可信 URL |
| `crypto` | 3.0.6 | 无 | ✅ |
| `encrypt` | 5.0.3 | 无 | ✅ |
| `path_provider` | 2.1.5 | 无 | ✅ |
| `flutter_svg` | 2.0.17 | 无 | ✅ |

**无已知数据收集型 SDK**（无 Firebase、无友盟统计 SDK、无广告 SDK）。原版 Java 代码中的友盟（Umeng）SDK 未被移植。

---

## 五、权限使用

### 5.1 Android 权限

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

仅 `INTERNET` 一个权限，✅ 最小权限原则。

### 5.2 权限必要性

| 权限 | 必要性 | 说明 |
|---|---|---|
| INTERNET | ✅ 必要 | API 请求 + 音频流播放 + WebView |

无多余权限（无 CAMERA/LOCATION/CONTACTS/STORAGE 等）。

---

## 六、用户学习数据保护

### 6.1 数据访问控制

| 数据 | 访问控制 | 风险 |
|---|---|---|
| 学习进度 | 基于 user_id 隔离（`user_process_history` 表按 `user_id` 过滤） | 中 — 无加密，root 可读 |
| 收藏/笔记 | 本地 SQLite，无远程同步 | 低 — 纯本地 |
| 学习统计 | SharedPreferences（`daily_stats_v1`），本地 | 低 — 纯本地 |

### 6.2 远程同步

| 数据 | 同步目标 | 加密 |
|---|---|---|
| 学习进度 | `sapi.beingfine.cn/v3/BB_SyncLexisProcess` | ⚠️ v3 响应加密（AES），但请求参数明文 |
| 用户生词 | `sapi.beingfine.cn/v3/SyncUserVocabulary` | 同上 |
| 每日统计 | `sapi.beingfine.cn/v3/bb/user-stat/learn-duration` | 同上 |

---

## 七、风险汇总与建议

### 🔴 高风险（建议发布前修复）

| # | 问题 | 位置 | 建议 |
|---|---|---|---|
| H1 | 硬编码 API 密钥 `'iscooler'` | `api_services.dart:94`, `crypto_utils.dart:16-24` | 运行时从安全存储读取，或混淆/分段存储 |
| H2 | 硬编码加密 IV `'1pat2rqs'` | `http_client.dart:136/515` | 同上 |
| H3 | Token/Secret 明文存储 | `app_preferences.dart` (user_token/user_secret) | 使用 `flutter_secure_storage` 替代 |
| H4 | 密码字段仍可读写 | `app_preferences_ext.dart:768` (`userPwd`) | 废弃该字段，迁移后清除 |

### ⚠️ 中风险（建议尽快修复）

| # | 问题 | 位置 | 建议 |
|---|---|---|---|
| M1 | 请求参数含 token 被 print 输出 | `http_client.dart:469/751` | Release 构建移除 `_traceParams` 或用 `kDebugMode` 守卫 |
| M2 | 完整 URL（含 token）被 print 输出 | `http_client.dart:305/535` | 同上 |
| M3 | HTTP 明文端点定义 | `api_services.dart:90-91` | 统一使用 HTTPS |
| M4 | Token 通过 URL 参数传输 | `http_client.dart` GET 请求 | 敏感操作改用 POST + body 或 Header Authorization |
| M5 | MD5 用于签名 | `crypto_utils.dart` | 升级为 HMAC-SHA256 |

### ℹ️ 低风险（可后续优化）

| # | 问题 | 说明 |
|---|---|---|
| L1 | SQLite 用户数据库无加密 | 考虑 sqflite_sqlcipher |
| L2 | WebView 无 URL 白名单 | 确保只加载可信 URL |
| L3 | 日志追踪系统（LogTracker）可收集用户行为 | 发布前确认是否启用 |

---

## 八、结论

应用**无多余权限**、**无数据收集型第三方 SDK**、**纯本地学习数据隔离**，基础安全面良好。

主要风险集中在：
1. **硬编码密钥**（H1/H2）— 来自原版 v3.2 反编译代码的遗留
2. **明文存储凭证**（H3/H4）— SharedPreferences 不适合存敏感信息
3. **调试日志泄漏**（M1/M2）— print 语句在 release 构建中仍会输出

建议发布前优先处理 H1-H4 高风险项。

---

*产出：DataEngineer · 2026-08-24 · 基于 lib/ 只读代码审计*
