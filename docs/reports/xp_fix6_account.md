# [XP-FIX-6] 账户/登录/设置域：logout 接入 + 登录持久化 + 返回安全化 + 双 pop 修复

## 任务摘要

修复 XP AUD-1 体检报告中的 P1/P2 问题：AppSessionState 登录态持久化、LoginPage 双 pop 修复、MoreSettingsPage logout 接入 + 返回 safePop、AccountProfileState mounted 守卫。

## 修改文件清单

| # | 文件 | 修改内容 |
|---|------|----------|
| 1 | `lib/features/account/presentation/app_session_state.dart` | 登录态 SharedPreferences 持久化；`restore()` 冷启动恢复 |
| 2 | `lib/features/account/presentation/account_feature_providers.dart` | `_AccountFeatureInitializer` 延迟调用 `restore()` |
| 3 | `lib/features/account/presentation/login_page.dart` | 退出对话框 `Navigator.pop` → `NavUtils.safePop`；添加 nav_utils 导入 |
| 4 | `lib/features/settings/presentation/more_settings_page.dart` | logout 接入 `AppSessionState.logout()`；返回按钮 → `NavUtils.safePop` |
| 5 | `lib/features/account/presentation/account_profile_state.dart` | `_disposed` 标记 + `_safeNotify()` 守卫；重写 `dispose()` |
| 6 | `test/pages/account_fix6_test.dart` | **新增** 7 个测试 |

## 逐点变更明细

### 1. app_session_state.dart — 登录态持久化 (P2-1)

| 变更 | 原代码 | 改后 |
|------|--------|------|
| 添加 SharedPreferences | 无 | `import 'shared_preferences.dart'` + `static const _keyIsLoggedIn` |
| `restore()` 方法 | 无 | 从 prefs 读取 `_isLoggedIn` 并 `notifyListeners()` |
| `login()` | 仅内存赋值 | `await _persist()` 写入 prefs |
| `phoneLogin()` | 仅内存赋值 | `await _persist()` 写入 prefs |
| `logout()` | 仅内存赋值 | `_clearPersist()` 异步清除 prefs |
| `_persist()` / `_clearPersist()` | 无 | 新增私有方法 |

### 2. account_feature_providers.dart — restore 初始化

| 变更 | 原代码 | 改后 |
|------|--------|------|
| `_AccountFeatureInitializer` | 无 | StatefulWidget + `addPostFrameCallback` 调用 `restore()` |

### 3. login_page.dart — 双 pop 修复 (P2-4)

| 变更 | 位置 | 原代码 | 改后 |
|------|------|--------|------|
| 退出对话框 | `_showExitConfirmDialog` | `Navigator.pop(context)` | `NavUtils.safePop(context)` |
| 导入 | 文件顶部 | 无 | `import '../../../core/router/nav_utils.dart'` |

### 4. more_settings_page.dart — logout 接入 (P1-1) + safePop (P1-2b)

| 变更 | 位置 | 原代码 | 改后 |
|------|------|--------|------|
| logout | `_showLogoutSheet` L341 | `// TODO: 执行退出登录逻辑` | `context.read<AppSessionState>().logout()` |
| 返回按钮 | `_buildNav` L361 | `Navigator.pop(context)` | `NavUtils.safePop(context)` |
| 导入 | 文件顶部 | 无 | `provider.dart`、`nav_utils.dart`、`app_session_state.dart` |

### 5. account_profile_state.dart — mounted 守卫 (P2-2)

| 变更 | 原代码 | 改后 |
|------|--------|------|
| `_disposed` 字段 | 无 | `bool _disposed = false` |
| `dispose()` | 无 | 覆写，设置 `_disposed = true` + `super.dispose()` |
| `_safeNotify()` | 无 | 检查 `_disposed` 后调用 `notifyListeners()` |
| 所有 `notifyListeners()` | 直接调用 | 改为 `_safeNotify()` |

## 质量门禁

| 门禁 | 结果 |
|------|------|
| `flutter analyze` 5 文件 | ✅ No issues found |
| `flutter test` account_fix6_test.dart | ✅ 7/7 passed |
| 新增测试文件 | ✅ `test/pages/account_fix6_test.dart` |

## 测试覆盖摘要

| 测试 | 验证内容 |
|------|----------|
| login→restore 恢复 | 登录后新实例 restore() 可恢复 isLoggedIn=true |
| logout→restore 不恢复 | 退出后新实例 restore() 保持 isLoggedIn=false |
| dispose 后 notify 安全 | refresh() 在 dispose 后不崩溃 |
| safePop 根路由安全 | 栈底 safePop 不崩溃 |
| logout 清除状态 | logout() 后 isLoggedIn 变 false |
| safePop 根路由不崩溃 | 模拟 pushReplacement 后 safePop 不崩溃 |
| safePop 正常 pop | 有上层路由时 safePop 正常返回 |

## 未修改（保持不动）

- `settings_page.dart` 的返回按钮（P1-2a）：留待 XP-FIX-5 落地
- `lib/core/`、`lib/app/`、`lib/theme/`：不在范围内
- 无 git commit / 无全量 flutter test
