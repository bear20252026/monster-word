# WS-6 APP-3 · 听写/拼写/造句/快速拼写页导航安全化

## 问题

4 个练习/会话页在退出或完成时直接调用 `Navigator.pop(context)`，存在两个风险：
1. 根路由 `pop` 导致黑屏（`canPop = false` 时 pop 无效/异常）。
2. 异步完成后 `pop` 时 widget 已 `unmounted`，引发 `setState() called after dispose` 异常。

## 修复方案

复用 `NavUtils.safePop`（canPop 守卫）和 `NavUtils.goHome`（popUntil 到根），替换直接 `Navigator.pop`。

### 改动明细

| 文件 | 修复前 | 修复后 | 场景 |
|---|---|---|---|
| **dictation_session_page.dart** | L215 `Navigator.pop(context)` | `NavUtils.safePop(context)` | 关闭按钮 |
| | L427 `Navigator.pop(context)` | `NavUtils.goHome(context)` | 完成返回 |
| **spell_session_page.dart** | L122 `Navigator.pop(context)` | `NavUtils.safePop(context)` | 完成弹窗返回 |
| | L306 `Navigator.pop(context)` | `NavUtils.safePop(context)` | 返回按钮 |
| **sentence_quiz_page.dart** | L78 `Navigator.pop(context)` | `if (!mounted) return; NavUtils.goHome(context)` | 测验完成 |
| | L96 `Navigator.pop(context)` | `NavUtils.safePop(context)` | 关闭按钮 |
| | L155 `Navigator.pop(context)` | `NavUtils.safePop(context)` | 返回按钮 |
| **quick_spell_page.dart** | L237 `Navigator.pop(context)` | `NavUtils.safePop(context)` | 返回按钮 |
| | L541 `Navigator.pop(context)` | `NavUtils.goHome(context)` | 完成返回 |

### 原则

- 返回/关闭按钮 → `safePop`（canPop 守卫，根路由不崩）
- 完成/回到首页 → `goHome`（popUntil 到根，不管在第几层都安全）
- 异步回调 → 先 `if (!mounted) return;`，再导航
- 会话逻辑（索引推进/下一题/状态）不变，只动导航进出栈

## 测试结果

| 指标 | 数值 |
|---|---|
| flutter analyze | 4 文件 0 error，0 新增 warning/info |
| 新增测试 | 4 个（`test/pages/nav_safety_simple_test.dart`）|
| 测试结果 | 4 passed / 0 failed |

### 测试覆盖

| 测试 | 验证 |
|---|---|
| safePop on child route | 子路由 safePop 正常返回父路由 |
| safePop at root | 根路由 safePop 不崩溃 |
| goHome pops to root | 多层嵌套 goHome 回到根路由 |
| goHome at root | 根路由 goHome 不崩溃 |

## 改动文件清单

| 文件 | 变化 |
|---|---|
| `lib/pages/dictation_session_page.dart` | 新增 NavUtils import + 2 处 Navigator.pop 替换 |
| `lib/pages/spell_session_page.dart` | 新增 NavUtils import + 2 处 Navigator.pop 替换 |
| `lib/pages/sentence_quiz_page.dart` | 新增 NavUtils import + 3 处 Navigator.pop 替换 + mounted 守卫 |
| `lib/pages/quick_spell_page.dart` | 新增 NavUtils import + 2 处 Navigator.pop 替换 |
| `test/pages/nav_safety_simple_test.dart` | 新增 4 个测试 |
| `docs/reports/ws6_app3_session_nav.md` | 本报告 |
