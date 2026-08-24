# 网络安全审计报告

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）
> 日期：2026-08-24
> 范围：lib/services/http_client.dart、lib/services/api_services.dart、lib/pages/ WebView 使用
> 方法：只读代码审查

---

## 一、总览

| 维度 | 状态 | 风险等级 |
|---|---|---|
| HTTPS 强制 | ✅ 全部 HTTPS | 🟢 低 |
| 证书验证 | ✅ 系统默认（Flutter http 包） | 🟢 低 |
| MITM 风险 | ✅ 无自签名证书 | 🟢 低 |
| API 签名 | ✅ MD5 参数签名 | 🟡 中 |
| 敏感数据泄露 | ⚠️ 日志打印含 token/URL | 🔴 高 |
| DNS 安全 | ⚠️ HTTPDNS stub 实现 | 🟡 中 |
| 超时处理 | ✅ 30s 超时 + 异常捕获 | 🟢 低 |
| 离线降级 | ⚠️ 无显式降级策略 | 🟡 中 |

---

## 二、详细发现

### 2.1 🔴 高风险：敏感数据日志泄露

**位置**：`lib/services/http_client.dart`

| 行号 | 代码 | 问题 |
|---|---|---|
| 311 | `print('$_logTag request: $uri')` | GET 请求完整 URL 打印（含 token 参数） |
| 330 | `print('$_logTag post request: $uri')` | POST 请求 URL 打印 |
| 475 | `print('$_logTag RequestParams: ${params.toString()}')` | **全部请求参数明文打印**（含 token、sign） |
| 541 | `print('$_logTag request: $uri')` | v3 GET 请求 URL 打印 |
| 560 | `print('$_logTag post request: $uri')` | v3 POST 请求 URL 打印 |
| 757 | `print('$_logTag RequestParams: ${params.toString()}')` | v3 全部参数明文打印 |
| 156 | `print('CoolHttpResponse FAIL: ...')` | 错误响应详情打印 |

**风险**：Release 包中 `print()` 输出会出现在 Android logcat 中，任何有 ADB 权限的人可读取 token、sign、用户数据。

**现状**：`_log()` 函数（line 31-33）已做 `kDebugMode` 守卫，但 **未被使用**——所有 print 调用直接使用 `print()` 而非 `_log()`。

**建议**：将所有 `print()` 替换为 `_log()`，或使用 `logging` 包配合 release 级别过滤。

### 2.2 🟡 中风险：API 签名使用 MD5

**位置**：`lib/services/http_client.dart:253-264`（CoolParams.getParamsSign）

```dart
String getParamsSign() {
  // ... 拼接 key=value ...
  return SecurityUtils.md5String(sb.toString());
}
```

**问题**：MD5 已被密码学界认为不安全（碰撞攻击）。虽然此处用于参数签名而非密码存储，但仍建议升级为 HMAC-SHA256。

**缓解因素**：签名密钥（secret）通过 v3_security 从服务端动态获取，不硬编码在客户端。

### 2.3 🟡 中风险：HTTPDNS 实现为空

**位置**：`lib/services/http_client.dart:990-1026`（CoolHttpDnsManager）

```dart
static void initHttpDns() {
  // ... 空实现 ...
  print('CoolHttpDnsManager: initHttpDns (stub)');
}
```

**问题**：原版使用阿里云 HTTPDNS 防 DNS 劫持，Flutter 版本为空实现。域名解析走系统 DNS，存在 DNS 劫持风险。

**建议**：如需防 DNS 劫持，集成 `alibaba_httpdns` Flutter 插件；否则可接受系统 DNS 风险（大多数 App 不做 HTTPDNS）。

### 2.4 🟡 中风险：无离线降级策略

**位置**：`lib/services/http_client.dart` 全局

**问题**：网络请求失败时直接 `onFailure(CoolHttpResponse())`，无：
- 离线缓存读取
- 请求队列（离线时暂存、上线后重发）
- 用户友好的离线提示

**现状**：词书数据库为本地 SQLite（`assets/db/wordbook.db.gz`），核心学习功能可离线运行。仅登录/同步/发音等依赖网络。

### 2.5 🟢 低风险：HTTPS 配置

**位置**：`lib/services/http_client.dart:278, 492`

```dart
static const String _baseUrl = 'https://sapi.beingfine.cn/v1';
static const String _baseUrl = 'https://sapi.beingfine.cn/v3';
```

**结论**：
- ✅ 全部 API 使用 HTTPS
- ✅ 无 HTTP 降级
- ✅ 无硬编码 IP
- ✅ Flutter `http` 包默认使用系统证书存储，证书验证完整
- ✅ 无自签名证书接受逻辑
- ✅ 无 `badCertificateCallback` 覆盖

### 2.6 🟢 低风险：超时与错误处理

**位置**：`lib/services/http_client.dart:280, 494`

- 连接超时：30 秒（v1 和 v3）
- 登录检查：2 秒短超时
- 文件下载：120 秒读取超时
- 异常捕获：`try-catch` 包裹所有网络调用
- 账号过期处理：自动检测 30102/30104 错误码

**结论**：超时设置合理，异常处理完整。

### 2.7 🟢 低风险：请求参数签名

**位置**：`lib/services/http_client.dart:356-363`（postAppendSign）

```dart
coolParams.put('sign', coolParams.getParamsSign());
```

**结论**：
- ✅ v3 API 自动附加 timestamp + sign
- ✅ sign 基于参数排序 + secret 的 MD5
- ✅ secret 从服务端动态获取（非硬编码）
- ⚠️ 无重放攻击防护（timestamp 未做有效期校验——由服务端负责）

### 2.8 🟢 信息：文件下载 MD5 校验

**位置**：`lib/services/http_client.dart:814-826`

**结论**：文件下载支持 Content-MD5 头校验，下载后自动验证完整性。MD5 不匹配时删除文件并报告错误。

---

## 三、WebView 安全

**位置**：`lib/pages/base_web_page.dart`、`lib/pages/help_page.dart`

| 检查项 | 状态 |
|---|---|
| URL 白名单 | ❌ 无——任何 URL 可加载 |
| JavaScript 控制 | 需检查（Flutter WebView 默认启用 JS） |
| URL Scheme 处理 | ⚠️ `uri_scheme_page.dart` 处理自定义 scheme，需检查注入风险 |
| 本地文件访问 | 需检查 `allowFileAccess` 设置 |

**建议**：限制 WebView 只加载 HTTPS URL，禁用 `allowFileAccess`，对自定义 scheme 做白名单校验。

---

## 四、修复优先级

| 优先级 | 问题 | 建议修复 |
|---|---|---|
| **P0** | 日志泄露 token/参数 | 将所有 `print()` 替换为 `_log()`（已有的 kDebugMode 守卫） |
| **P1** | API 签名 MD5 | 升级为 HMAC-SHA256（需服务端同步） |
| **P1** | WebView URL 白名单 | 添加域名白名单校验 |
| **P2** | HTTPDNS 空实现 | 集成或移除 stub 代码 |
| **P2** | 离线降级 | 添加网络状态检测 + 离线提示 |
| **P3** | 重放攻击防护 | 服务端校验 timestamp 有效期 |

---

## 五、结论

**整体安全等级：🟡 中等**

核心通信链路（HTTPS + 参数签名 + token 认证）设计合理。最严重问题是 **Release 包日志泄露敏感数据**（P0），需立即将 `print()` 替换为 `_log()`。其余为中低风险的加固项。
