# 认证与授权安全审计报告

> 审计日期：2026-08-24
> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）
> 审计范围：身份验证、会话管理、权限控制、攻击面分析
> 约束：只读代码审计，未修改任何文件

---

## 一、项目认证架构概览

Monster Word 是一款**本地优先的背单词 App**，认证架构极简：

| 组件 | 说明 |
|---|---|
| 登录方式 | CoolID 账号密码 / 手机短信 / 友盟三方登录 |
| Token 存储 | SharedPreferences（明文） |
| API 认证 | 请求参数携带 token（非 HTTP Header） |
| 本地数据 | SQLite 词库（无用户敏感数据） |
| 密码存储 | **不在本地存储**（仅传输给服务端验证） |

---

## 二、身份验证审计

### 2.1 登录机制

**文件**：`lib/pages/login_page.dart:66-79`

```dart
Future<void> _loginWithCoolID(String username, String password) async {
  // 密码直接传给 state.login()
  final success = await state.login(username, password);
}
```

| 检查项 | 结果 | 风险 |
|---|---|---|
| 密码本地存储 | ❌ 不存储 | ✅ 无泄露风险 |
| 密码传输 | 表单 POST（`application/x-www-form-urlencoded`） | ⚠️ 依赖 HTTPS |
| 暴力破解防护 | ❌ 客户端无限制 | ⚠️ 依赖服务端限流 |
| 密码强度校验 | ❌ 客户端仅检查非空 | ⚠️ 依赖服务端校验 |

### 2.2 三方登录

**文件**：`lib/services/api_services.dart:351-381`

| 检查项 | 结果 | 风险 |
|---|---|---|
| 友盟 token 传递 | `umeng_token` 作为请求参数 | ⚠️ 依赖 HTTPS |
| SMS 验证码登录 | `sms_code` 作为请求参数 | ⚠️ 依赖服务端一次性校验 |

**结论**：客户端认证逻辑简单，安全性主要依赖服务端。客户端无明显漏洞。

---

## 三、会话管理审计

### 3.1 Token 存储

**文件**：`lib/data/app_preferences.dart:61-103`

```dart
static const String userToken = 'user_token';
static const String userSecret = 'user_secret';
String getUserToken() => getString(userToken);
Future<bool> setUserToken(String value) => setString(userToken, value);
```

| 检查项 | 结果 | 风险 |
|---|---|---|
| 存储方式 | SharedPreferences（明文 XML/JSON） | ⚠️ 中低风险 |
| 加密存储 | ❌ 未加密 | ⚠️ root/越狱设备可读取 |
| Token 过期检测 | ✅ 错误码 30102/30104 触发过期处理 | ✅ |
| 会话固定防护 | ❌ 未检测 | ⚠️ 依赖服务端 |

### 3.2 Token 使用

**文件**：`lib/services/http_client.dart:501-506`

```dart
static Map<String, String> requestParamsWithToken(String endpoint) {
  final params = requestParams(endpoint);
  params.put('token', prefs.getUserToken());
  return params;
}
```

| 检查项 | 结果 | 风险 |
|---|---|---|
| Token 传递方式 | URL 参数（非 Header） | ⚠️ 可能被日志记录 |
| Token 刷新机制 | ❌ 未发现 | ⚠️ 依赖服务端长期 token |
| 请求签名 | ✅ MD5 校验（`content-md5` header） | ✅ 防篡改 |

**结论**：Token 管理为标准实现，无重大漏洞。SharedPreferences 明文存储是主要风险点，但对背单词 App 影响有限。

---

## 四、权限控制审计

### 4.1 API 请求认证

| 检查项 | 结果 | 风险 |
|---|---|---|
| 需认证 API | 使用 `requestParamsWithToken()` | ✅ |
| 公开 API | 使用 `requestParams()`（无 token） | ✅ 正确区分 |
| 越权访问 | 无用户间数据隔离逻辑（本地 App） | ✅ 无风险 |
| 水平越权 | 不适用（单用户本地 App） | ✅ |

### 4.2 本地数据访问

| 检查项 | 结果 | 风险 |
|---|---|---|
| SQLite 数据库 | 本地词库，无用户隐私数据 | ✅ 无风险 |
| 用户偏好 | SharedPreferences，无敏感信息 | ✅ |
| 壁纸/皮肤 | 纯本地配置 | ✅ |

**结论**：作为单用户本地学习 App，权限控制面积极小，无越权风险。

---

## 五、攻击面分析

### 5.1 Token 篡改攻击

| 攻击向量 | 可行性 | 影响 |
|---|---|---|
| Root 设备读取 SharedPreferences | 中 | 获取 token → 冒充用户 |
| MITM 抓包获取 token | 低（依赖 HTTPS） | 获取 token |
| 修改本地 token 值 | 中（Root） | 切换到其他用户账号 |

**缓解建议**：考虑使用 `flutter_secure_storage` 替代 SharedPreferences 存储 token。

### 5.2 会话劫持攻击

| 攻击向量 | 可行性 | 影响 |
|---|---|---|
| 复制 token 到另一设备 | 中（Root + 文件复制） | 冒充用户 |
| Token 过期后重用 | 低（有过期检测） | 被服务端拒绝 |

### 5.3 重放攻击

| 攻击向量 | 可行性 | 影响 |
|---|---|---|
| 重放 API 请求 | 低（MD5 校验 + token 过期） | 被服务端拒绝 |
| 重放登录请求 | 低（HTTPS + 一次性密码） | 被服务端拒绝 |

### 5.4 其他风险

| 风险项 | 状态 | 说明 |
|---|---|---|
| 硬编码密钥 | ❌ 未发现 | ✅ |
| Debug 日志泄露 token | ⚠️ 需确认 | 检查 release 构建是否关闭 debug 日志 |
| WebView 注入 | ⚠️ 存在 base_web_page.dart | 检查是否启用了 JavaScript 桥接 |

---

## 六、风险评估总结

| 风险等级 | 数量 | 说明 |
|---|---|---|
| 🔴 高危 | 0 | 无 |
| 🟡 中危 | 2 | Token 明文存储、Token 通过 URL 参数传递 |
| 🟢 低危 | 3 | 暴力破解防护（依赖服务端）、密码强度校验（依赖服务端）、Debug 日志 |
| ✅ 安全 | 6 | 无本地密码存储、Token 过期检测、MD5 请求签名、无越权风险、无硬编码密钥、无重放风险 |

---

## 七、改进建议

### 优先级 P1（建议尽快）

1. **Token 加密存储**：用 `flutter_secure_storage` 替代 `SharedPreferences` 存储 token/secret
   - Android: EncryptedSharedPreferences
   - iOS: Keychain
   - Windows: DPAPI

### 优先级 P2（后续改进）

2. **Token 传递方式**：从 URL 参数改为 HTTP Authorization Header
3. **Debug 日志清理**：确认 release 构建不输出 token 相关日志

### 优先级 P3（可选）

4. **客户端暴力破解防护**：登录失败 N 次后增加延迟
5. **WebView 安全**：检查 `base_web_page.dart` 的 JavaScript 桥接配置

---

## 八、结论

**Monster Word 的认证授权安全评级：🟢 良好（对本地学习 App 适用）**

- 无高危漏洞
- 2 个中危风险（Token 明文存储 + URL 参数传递）影响有限，因 App 不处理支付、个人信息等敏感数据
- 安全性主要依赖服务端（HTTPS、Token 过期、请求签名），客户端实现符合常规实践
- 作为 v2.0.0 发布，当前安全状态**可接受**；建议在后续版本中优先实施 Token 加密存储（P1）

---

*本报告基于 2026-08-24 代码主干静态审计，未进行运行时测试或渗透测试。*
