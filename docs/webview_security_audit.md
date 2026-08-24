# WebView 安全配置审计报告

> 审计日期：2026-08-24
> 审计人：LicenseReviewer
> 项目：Monster Word v2.0.0+2（D:\claude\work\cn_com_lange\word_app）
> 方法：只读代码审查

---

## 1. 审计结论速览

**🟡 整体风险等级：中**

发现 3 处 WebView 使用，其中 1 处高风险（外部 URL + 无限制 JS），1 处中风险（硬编码 URL + 无限制 JS），1 处低风险（本地 HTML）。

| # | 文件 | 风险 | 问题 |
|---|---|---|---|
| 🔴 W1 | `base_web_page.dart` | **高** | 加载外部 URL + JS 无限制 + 无 URL 白名单 |
| 🟡 W2 | `help_page.dart` | **中** | JS 无限制（URL 硬编码，风险较低） |
| 🟢 W3 | `lock_webview_cache.dart` | **低** | JS 无限制但仅加载本地 HTML |

---

## 2. WebView 使用点详细分析

### 2.1 🔴 高风险：base_web_page.dart

**位置**：`lib/pages/base_web_page.dart:39-60`

```dart
_controller = WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)  // ⚠️ JS 完全开放
  ..setNavigationDelegate(NavigationDelegate(
    onPageStarted: ...,
    onPageFinished: ...,
    onWebResourceError: ...,
    // ⚠️ 无 URL 过滤逻辑
  ));
_controller.loadRequest(Uri.parse(widget.url));  // ⚠️ 直接加载传入 URL
```

**问题分析**：

| 问题 | 说明 | 风险 |
|---|---|---|
| `JavaScriptMode.unrestricted` | JS 完全开放，可执行任意脚本 | 🔴 高 |
| 无 `NavigationDelegate` URL 过滤 | `onNavigationRequest` 未实现，页面可自由跳转 | 🔴 高 |
| URL 来自外部参数 | `widget.url` 由调用方传入，未验证 | 🔴 高 |
| 无 `addJavaScriptChannel` 限制 | 未暴露原生 API（好现象） | 🟢 无 |

**攻击场景**：
- 若 `widget.url` 被注入恶意 URL（如 `javascript:alert(1)`），可执行 XSS
- 页面内 JS 可自由跳转到钓鱼网站
- 加载的外部页面可执行任意 JS 代码

**调用方检查**：

```dart
// 搜索 BaseWebPage 的使用
Navigator.pushNamed(context, '/web', arguments: url);
```

URL 来源需确认是否经过验证。

### 2.2 🟡 中风险：help_page.dart

**位置**：`lib/pages/help_page.dart:31-46`

```dart
_controller = WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)  // ⚠️ JS 完全开放
  ..setNavigationDelegate(NavigationDelegate(
    onPageStarted: ...,
    onPageFinished: ...,
    onWebResourceError: ...,
    // ⚠️ 无 URL 过滤逻辑
  ));

final url = widget.url ?? 'https://www.beingfine.cn/help';  // ✅ 硬编码默认 URL
_controller.loadRequest(Uri.parse(url));
```

**问题分析**：

| 问题 | 说明 | 风险 |
|---|---|---|
| `JavaScriptMode.unrestricted` | JS 完全开放 | 🟡 中 |
| 无 URL 过滤 | `onNavigationRequest` 未实现 | 🟡 中 |
| URL 有默认值 | 硬编码 `beingfine.cn/help`，降低风险 | 🟢 好 |
| URL 可被覆盖 | `widget.url` 参数可传入任意 URL | 🟡 中 |

**风险评估**：由于默认 URL 为硬编码的帮助页面，实际风险较低。但 `widget.url` 参数可被覆盖，需确认调用方是否传入可信 URL。

### 2.3 🟢 低风险：lock_webview_cache.dart

**位置**：`lib/lock/lock_webview_cache.dart:34-38`

```dart
static WebViewController _createController() {
  return WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)  // ⚠️ JS 开放
    ..setBackgroundColor(Colors.transparent);
}
```

**加载内容**：`lock_webview_cache.dart:81` — `loadHtmlString(...)` 加载本地 HTML 模板

**问题分析**：

| 问题 | 说明 | 风险 |
|---|---|---|
| `JavaScriptMode.unrestricted` | JS 开放 | 🟢 低 |
| 加载本地 HTML | 无外部 URL，风险极低 | 🟢 低 |
| 无网络请求 | 纯本地渲染 | 🟢 低 |

**风险评估**：仅加载本地 HTML 模板（例句显示），无外部 URL，无网络请求，风险极低。但 JS 仍可访问 WebView 内部 DOM，建议评估是否真的需要 JS。

---

## 3. 安全配置对比

| 配置项 | base_web_page | help_page | lock_webview_cache |
|---|---|---|---|
| JavaScriptMode | ❌ unrestricted | ❌ unrestricted | ❌ unrestricted |
| NavigationDelegate | ⚠️ 无 URL 过滤 | ⚠️ 无 URL 过滤 | — 未设置 |
| URL 来源 | 🔴 外部参数 | 🟡 硬编码默认 | 🟢 本地 HTML |
| JSChannel | ✅ 未暴露 | ✅ 未暴露 | ✅ 未暴露 |
| URL 白名单 | ❌ 无 | ❌ 无 | — 不需要 |
| HTTPS 强制 | ❌ 未检查 | ❌ 未检查 | — 不适用 |

---

## 4. 修复建议

### 4.1 base_web_page.dart（🔴 高优先级）

```dart
_controller = WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)
  ..setNavigationDelegate(NavigationDelegate(
    // 新增：URL 白名单过滤
    onNavigationRequest: (NavigationRequest request) {
      final uri = Uri.parse(request.url);
      // 允许的域名白名单
      const allowedHosts = [
        'www.beingfine.cn',
        'beingfine.cn',
        'help.beingfine.cn',
      ];
      if (!allowedHosts.contains(uri.host)) {
        return NavigationDecision.prevent;
      }
      // 禁止 javascript: 协议
      if (uri.scheme == 'javascript') {
        return NavigationDecision.prevent;
      }
      return NavigationDecision.navigate;
    },
    onPageStarted: ...,
    onPageFinished: ...,
    onWebResourceError: ...,
  ));
```

### 4.2 help_page.dart（🟡 中优先级）

```dart
// 方案 A：限制 JS（推荐）
..setJavaScriptMode(JavaScriptMode.disabled)

// 方案 B：若需要 JS，添加 URL 白名单（同 base_web_page）
```

### 4.3 lock_webview_cache.dart（🟢 低优先级）

```dart
// 方案 A：禁用 JS（推荐，本地 HTML 不需要 JS）
..setJavaScriptMode(JavaScriptMode.disabled)

// 方案 B：保持现状（风险极低，可接受）
```

### 4.4 通用加固措施

| # | 措施 | 说明 |
|---|---|---|
| 1 | URL 协议检查 | 禁止 `javascript:`、`data:`、`file:` 协议 |
| 2 | 域名白名单 | 仅允许 `beingfine.cn` 及其子域名 |
| 3 | HTTPS 强制 | 拒绝 HTTP 明文 URL |
| 4 | JS 最小化 | 仅在必要时启用 `unrestricted` |
| 5 | 内容安全策略 | 在 HTML 中添加 `<meta http-equiv="Content-Security-Policy">` |

---

## 5. 风险汇总

| 风险 | 等级 | 文件 | 建议 |
|---|---|---|---|
| 外部 URL 无限制加载 | 🔴 高 | base_web_page.dart | 添加 URL 白名单 + 协议检查 |
| JS 无限制（外部页面） | 🔴 高 | base_web_page.dart | 添加 URL 白名单 |
| JS 无限制（帮助页） | 🟡 中 | help_page.dart | 限制 JS 或添加白名单 |
| JS 无限制（本地 HTML） | 🟢 低 | lock_webview_cache.dart | 可选禁用 JS |
| 无 HTTPS 强制 | 🟡 中 | base/help | 添加协议检查 |
| 无 CSP 头 | 🟡 中 | base/help | 添加 CSP meta 标签 |

---

## 6. 工期估算

| 修复项 | 工时 |
|---|---|
| base_web_page URL 白名单 + 协议检查 | 1 小时 |
| help_page JS 限制或白名单 | 0.5 小时 |
| lock_webview_cache JS 评估 | 0.5 小时 |
| 测试验证 | 1 小时 |
| **合计** | **0.5 天** |

---

**总结**：Monster Word 的 WebView 使用存在安全隐患，主要是 `JavaScriptMode.unrestricted` 普遍使用且无 URL 白名单。`base_web_page.dart` 风险最高（加载外部 URL），建议优先修复。`help_page.dart` 风险中等（硬编码 URL 降低实际风险）。`lock_webview_cache.dart` 风险极低（本地 HTML）。全部修复预计 0.5 天。
