# 依赖安全审计报告

> 审计日期：2026-08-24
> 审计人：TokenEngineer
> 项目：Monster Word (word_app) v2.0.0+2

---

## 一、依赖概览

| 类型 | 数量 |
|------|------|
| 直接依赖 | 13 |
| 开发依赖 | 2 |
| 传递依赖 | 50+ |

---

## 二、直接依赖安全分析

### 2.1 高风险依赖

| 依赖 | 版本 | 风险说明 | 建议 |
|------|------|----------|------|
| `encrypt` | ^5.0.3 | AES 加密库，用于签名机制。**注意**：该库已停止维护（archived），可能存在未修复的安全漏洞 | 考虑迁移到 `pointycastle` 或 `encrypt` 的活跃 fork |
| `webview_flutter` | ^4.10.0 | WebView 组件，JavaScript 默认启用可能被利用进行 XSS 攻击 | 确保 WebView 配置禁用不必要的 JavaScript，或使用 `webview_flutter_android` 的安全配置 |

### 2.2 中风险依赖

| 依赖 | 版本 | 风险说明 | 建议 |
|------|------|----------|------|
| `http` | ^1.2.2 | 网络请求库。默认不支持证书固定（certificate pinning），存在 MITM 风险 | 如需高安全性，考虑添加证书固定或使用 `dio` + 证书固定插件 |
| `crypto` | ^3.0.6 | MD5/SHA 加密。MD5 已被证明不安全，不应用于安全场景 | 确保 MD5 仅用于非安全用途（如文件校验），安全场景使用 SHA-256+ |
| `shared_preferences` | ^2.3.3 | 本地存储。数据以明文存储在设备上，root 设备可直接读取 | 敏感数据应加密后存储，或使用 `flutter_secure_storage` |
| `sqflite` | ^2.4.1 | SQLite 数据库。默认不加密，root 设备可直接访问数据库文件 | 如需保护数据，考虑使用 `sqflite_sqlcipher` 进行数据库加密 |

### 2.3 低风险依赖

| 依赖 | 版本 | 说明 |
|------|------|------|
| `flutter` | SDK | 官方框架，安全性由 Google 维护 |
| `cupertino_icons` | ^1.0.8 | 图标字体，无安全风险 |
| `archive` | ^3.6.1 | 解压库，用于解压词库。注意处理恶意构造的压缩文件 |
| `path_provider` | ^2.1.5 | 路径获取，无安全风险 |
| `path` | ^1.9.0 | 路径处理，无安全风险 |
| `provider` | ^6.1.2 | 状态管理，无安全风险 |
| `audioplayers` | ^6.1.0 | 音频播放，无安全风险 |
| `flutter_svg` | ^2.0.17 | SVG 渲染。注意处理恶意构造的 SVG 文件（可能包含脚本） |
| `just_audio` | ^0.9.42 | 音频播放，无安全风险 |
| `http_parser` | ^4.1.2 | HTTP 解析，无安全风险 |

---

## 三、权限分析

### 3.1 Android 权限

当前 `AndroidManifest.xml` 声明的权限：

| 权限 | 用途 | 风险评估 |
|------|------|----------|
| `INTERNET` | 网络访问（http/webview_flutter 依赖） | ✅ 必需，低风险 |

**评估**：权限最小化，仅声明了网络权限，符合最小权限原则。

### 3.2 缺失权限检查

| 场景 | 需要的权限 | 当前状态 |
|------|-----------|----------|
| 音频播放（后台） | `FOREGROUND_SERVICE` | ❌ 未声明（可能影响后台播放） |
| 存储访问（下载/导入） | `READ/WRITE_EXTERNAL_STORAGE` | ❌ 未声明（使用应用私有目录，无需声明） |

---

## 四、传递依赖风险

### 4.1 高传递依赖数的包

| 直接依赖 | 传递依赖数 | 风险说明 |
|----------|-----------|----------|
| `audioplayers` | 8+ | 包含 Android/iOS/Linux/Web/Windows 平台实现，攻击面较大 |
| `webview_flutter` | 5+ | WebView 相关依赖，需关注 WebView 安全配置 |
| `just_audio` | 6+ | 音频播放依赖链 |

### 4.2 已知 CVE 检查

通过代码分析，未发现直接依赖中存在已知 CVE。但需注意：

- `encrypt` 库已停止维护，可能存在未公开的漏洞
- `webview_flutter` 的 WebView 组件历史上曾有安全漏洞，需保持更新

---

## 五、代码安全检查

### 5.1 硬编码密钥/Token

通过 grep 搜索，未发现硬编码的 API key、secret 或 token。

### 5.2 动态代码执行

未发现 `dart:mirrors`、`eval` 或其他动态代码执行。

### 5.3 WebView 安全

WebView 使用需注意：
- 确保加载的 URL 是可信的
- 考虑禁用不必要的 JavaScript
- 注意防止 XSS 攻击

---

## 六、安全建议

### 6.1 立即行动（Critical/High）

| # | 建议 | 优先级 |
|---|------|--------|
| 1 | 评估 `encrypt` 库的替代方案（已停止维护） | High |
| 2 | 确保 WebView 配置安全（禁用不必要的 JavaScript） | High |

### 6.2 短期改进（Medium）

| # | 建议 | 优先级 |
|---|------|--------|
| 3 | 敏感数据使用 `flutter_secure_storage` 替代 `shared_preferences` | Medium |
| 4 | 考虑数据库加密（`sqflite_sqlcipher`） | Medium |
| 5 | 添加证书固定（certificate pinning）防止 MITM | Medium |

### 6.3 长期优化（Low）

| # | 建议 | 优先级 |
|---|------|--------|
| 6 | 定期运行 `flutter pub outdated` 检查依赖更新 | Low |
| 7 | 使用 `dependency_validator` 检查未使用的依赖 | Low |
| 8 | 考虑使用 `renovate` 或 `dependabot` 自动化依赖更新 | Low |

---

## 七、结论

**整体安全评级：🟡 中等**

- ✅ 权限最小化（仅 INTERNET）
- ✅ 无硬编码密钥
- ✅ 无动态代码执行
- ⚠️ `encrypt` 库已停止维护
- ⚠️ 本地存储未加密
- ⚠️ 数据库未加密

**建议**：优先处理 `encrypt` 库的替代方案，评估是否需要数据加密。

---

*审计完成于 2026-08-24 · TokenEngineer*
