# 网络安全审计报告：Monster Word App

> 审计人：DevOps（Claude Code）
> 日期：2026-08-24
> 方式：只读代码审计，未执行任何攻击或修改
> 审计范围：`lib/services/http_client.dart`、`lib/services/api_services.dart`、`lib/utils/crypto_utils.dart`、`android/app/src/main/AndroidManifest.xml`

---

## 1. 传输层安全（HTTPS / MITM 防御）

### 1.1 HTTPS 使用

| 项 | 状态 | 说明 |
|---|---|---|
| API 基础 URL | ✅ 全部 HTTPS | `https://sapi.beingfine.cn/v1` 和 `/v3` |
| 硬编码协议 | ✅ 无 HTTP | 所有 URL 均以 `https://` 开头 |

### 1.2 证书固定（Certificate Pinning）

| 项 | 状态 | 说明 |
|---|---|---|
| 证书固定 | ❌ **未实现** | 使用 Flutter `http` 包默认 TLS 验证，无自定义 `SecurityContext` |
| 自签名证书 | ✅ 不接受 | `http` 包默认拒绝无效证书 |

**风险**：中间人攻击者使用受信任 CA 签发的伪造证书可拦截流量。企业级应用建议实施证书固定。

**建议**：如需防御 MITM，可通过 `HttpClient` + `SecurityContext` 实施证书固定，或使用 `dio` + `certificate_pinning` 插件。

### 1.3 代理检测

| 项 | 状态 | 说明 |
|---|---|---|
| 代理检测 | ❌ 空实现 | `CoolHttpDnsManager.detectIfProxyExist()` 始终返回 `false` |

---

## 2. DNS 安全

### 2.1 DNS 解析

| 项 | 状态 | 说明 |
|---|---|---|
| HTTPDNS | ❌ 空实现 | `CoolHttpDnsManager` 为 stub，未集成阿里云 HTTPDNS |
| DNS 缓存 | ❌ 空 Map | `_dnsCache` 始终为空 |
| 域名验证 | ❌ 无 | 未对响应域名做二次验证 |
| 备用域名 | ❌ 无 | 仅硬编码 `sapi.beingfine.cn` 一个域名 |

**风险**：DNS 劫持可将请求导向恶意服务器。无 HTTPDNS 和备用域名，单点故障风险高。

**建议**：
- 集成 HTTPDNS（如阿里云/腾讯云）
- 添加备用域名降级策略
- 实施域名验证（检查响应中的域名证书 SAN）

---

## 3. API 安全

### 3.1 速率限制

| 项 | 状态 | 说明 |
|---|---|---|
| 客户端速率限制 | ❌ **无** | 无请求频率限制、无防抖机制 |
| 账号过期防抖 | ✅ 有 | `_dealExpireDlgTime` 120 秒内不重复弹窗（但非速率限制） |

**风险**：恶意调用方可在客户端侧无限频率发送请求。

**建议**：客户端添加请求间隔限制（如 100ms 最小间隔），服务端应实施真正的速率限制。

### 3.2 输入验证

| 项 | 状态 | 说明 |
|---|---|---|
| 参数编码 | ✅ 有 | `Uri.encodeComponent()` 对 GET 参数编码 |
| 参数签名 | ✅ 有 | `CoolParams.getParamsSign()` 使用 MD5 签名 |
| 输入校验 | ❌ **无** | `RequestParams.put()` 不做任何输入验证，直接存储 |

**风险**：客户端未校验输入长度、格式、特殊字符，可能传递恶意数据到服务端。

### 3.3 错误信息泄露

| 项 | 状态 | 说明 |
|---|---|---|
| 错误日志 | ⚠️ **过多** | `print()` 输出完整 URL、参数、响应体、异常堆栈 |
| 错误码常量 | ✅ 有 | 定义了 15 个业务错误码常量 |
| failTrace() | ⚠️ 泄露 | 输出 `data_kind`、`result_code`、`error_info`、`error_message` |

**风险**：Release 包中 `print()` 输出包含敏感信息（token、签名、用户数据），可通过 logcat/调试器捕获。

**建议**：
- Release 包禁用 `print()`（使用 `kReleaseMode` 判断或 `logger` 包）
- 移除 `_traceParams()` 中的完整参数输出

---

## 4. 请求签名与重放攻击

### 4.1 签名机制

| 项 | 状态 | 说明 |
|---|---|---|
| v1 签名 | ✅ MD5 | `CoolParams.getParamsSign()` — 参数排序后拼接，MD5 哈希 |
| v3 签名 | ✅ AES+MD5 | `WdTransAction.generateSign()` — 参数排序→AES CBC 加密→Base64→MD5 |
| 签名附带 | ✅ 自动 | `postAppendSign()` / `appendParamSign()` 自动追加 `sign` 参数 |

### 4.2 时间戳/Nonce

| 项 | 状态 | 说明 |
|---|---|---|
| 时间戳 | ✅ 有 | v3 请求自动附加 `timestamp`（毫秒级 Unix 时间戳） |
| Nonce | ❌ **无** | 无随机数防重放 |
| 请求有效期 | ❌ **无** | 服务端未验证时间戳窗口（客户端侧无法确认） |

**风险**：相同参数+时间戳的请求可被重放。签名基于参数内容，不含 nonce，攻击者可截获并重发请求。

**建议**：
- 添加 `nonce`（UUID 或随机字符串）到签名参数
- 服务端验证时间戳窗口（如 ±5 分钟）
- 签名中包含 nonce + timestamp

### 4.3 加密密钥管理

| 项 | 状态 | 说明 |
|---|---|---|
| AES 密钥 | 🔴 **硬编码** | 默认密钥 `"iscooler"` 硬编码在源码中 |
| AES IV | 🔴 **硬编码** | IV `[1,0x70,97,0x74,2,0x72,0x71,0x73]` 硬编码 |
| v3 Secret | ✅ 动态 | 从服务端 `v3_security.secret` 获取，本地存储 |
| Token 存储 | ✅ SharedPreferences | `AppPreferences` 存储，非明文文件 |

**风险**：默认 AES 密钥可被逆向工程提取，用于解密所有 v1 API 流量。

---

## 5. 数据加密

### 5.1 传输加密

| 项 | 状态 | 说明 |
|---|---|---|
| 传输层 | ✅ TLS | 全部 HTTPS |
| 应用层（v1） | ❌ 无加密 | `data_body` 明文传输 |
| 应用层（v3） | ✅ AES CBC | `data_body` 使用 AES CBC 加密，key 从服务端动态获取 |

### 5.2 本地存储加密

| 项 | 状态 | 说明 |
|---|---|---|
| SharedPreferences | ❌ 明文 | 键值对以明文存储在设备上 |
| 词库文件 | ✅ gzip 压缩 | `wordbook.db.gz` 非明文（但非加密） |
| 敏感数据 | ⚠️ token 明文 | 用户 token 和 secret 存储在 SharedPreferences 明文中 |

**建议**：使用 `flutter_secure_storage`（Keychain/Keystore）存储 token 和 secret。

---

## 6. Android 权限

| 项 | 状态 | 说明 |
|---|---|---|
| INTERNET 权限 | ✅ 已添加 | 主 Manifest 已有（【重构59】修复） |
| 其他权限 | ✅ 最小化 | 无多余权限声明 |

---

## 7. 综合评分

| 维度 | 评分 | 说明 |
|---|---|---|
| 传输安全 | 7/10 | HTTPS 全覆盖，但无证书固定 |
| DNS 安全 | 3/10 | HTTPDNS 空实现，单域名 |
| API 安全 | 5/10 | 有签名但无速率限制，日志泄露 |
| 重放防御 | 4/10 | 有时间戳但无 nonce |
| 密钥管理 | 3/10 | AES 密钥硬编码，token 明文存储 |
| 数据加密 | 6/10 | v3 有应用层加密，v1 明文 |
| **综合** | **4.7/10** | **🟠 中低风险** |

---

## 8. 修复建议优先级

| # | 问题 | 严重度 | 建议 |
|---|---|---|---|
| 1 | AES 密钥硬编码 `"iscooler"` | 🔴 高 | 迁移到动态密钥或混淆存储 |
| 2 | Release 包 `print()` 泄露敏感信息 | 🔴 高 | 用 `kReleaseMode` 禁用或替换为 `logger` |
| 3 | Token/Secret 明文存储 | 🟠 中 | 迁移到 `flutter_secure_storage` |
| 4 | 无 nonce 防重放 | 🟠 中 | 添加 UUID nonce 到签名参数 |
| 5 | HTTPDNS 空实现 | 🟡 低 | 集成 HTTPDNS 或备用域名 |
| 6 | 无客户端速率限制 | 🟡 低 | 添加请求间隔限制 |
| 7 | 无证书固定 | 🟡 低 | 按安全需求决定是否实施 |

---

## 9. 说明

本报告基于**静态代码审计**，未执行任何实际攻击测试。所有发现均来自代码阅读，不构成对生产环境的安全评估。实际安全状况需结合服务端配置、网络环境、设备安全状态综合判断。

---

*审计完成：DevOps（Claude Code）· 2026-08-24 · 只读审计*
