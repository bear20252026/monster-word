# XP AUD-1 全盘体检：账户/登录/主页/设置域

> 只读审计 — 登录/闪屏/主页壳/账户/设置域。输出 P0–P3 清单（file:line + 现象 + 根因 + 严重度）。
> 参考维度：返回不黑屏/逐级回首页、无参/空态不 NPE、provider 齐全、setState after dispose、ModalRoute.of 在 initState、会话状态生命周期、设置持久化、异步错误边界。
> ❌ 未改 lib 代码、未 git commit/push、未跑全量 flutter test。

---

## 严重度定义

| 等级 | 含义 |
|------|------|
| **P0** | 必现崩溃 / 数据丢失 / 正常使用即黑屏 |
| **P1** | 功能失效 / 常见竞态崩溃 / 会话生命周期断裂 |
| **P2** | UX 降级 / 违反安全约定（低概率触发） |
| **P3** | 代码卫生 / 最佳实践偏差（无即时影响） |

---

## P0 — 必现崩溃 / 黑屏

> 本域未发现 P0。所有 `pushReplacementNamed` 均出现在认证入口（splash → main/login、login → main），属任务约定正常模式，不触发黑屏。

---

## P1 — 功能失效 / 常见竞态崩溃

### P1-1 · logout 不跳转 — 会话状态生命周期断裂

- **位置**：`lib/features/settings/presentation/more_settings_page.dart` L342-343
- **现象**：用户确认登出后，`Navigator.pop(ctx)` 关闭对话框，`context.read<AppSessionState>().logout()` 将 `_isLoggedIn` 置 false 并通知监听者 — **但没有任何导航动作**。用户仍停留在 MoreSettings 页面（MainShell 登录态壳内），可继续进入 MySpace / AccountInfo 等依赖会话的页面，触发资料加载失败（无 token）或展示空态。
- **根因**：`AppSessionState.logout()`（`app_session_state.dart` L38-42）仅重置状态 + 持久化清除，不负责导航；调用方 `more_settings_page.dart` 也未在 logout 后跳转到 splash/login。MainShell 也未监听 `isLoggedIn` 变化做自动重定向。
- **预期**：logout 后应 `pushReplacementNamed(LoginPage.routeName)` 或 `goHome` + 跳 splash，清空导航栈，避免用户在无效会话内继续操作。
- **严重度**：**P1**（功能失效 — 登出后仍留在登录态壳内，会话生命周期断裂）

### P1-2 · LearningPreferencesState.notifyListeners after dispose — 退出设置页竞态崩溃

- **位置**：`lib/features/settings/presentation/learning_preferences_state.dart` L45-58（`initialize`）、L77-90（`_update`）
- **现象**：`initialize()` 内 `await _reader.load()` 后直接调用 `notifyListeners()`；`_update()` 内 `await _writer.save(next)` 后直接调用 `notifyListeners()`。若用户在偏好加载/保存过程中退出设置页，`LearningPreferencesState` 被 dispose，后续 `notifyListeners()` 抛出 **"A ChangeNotifier was used after being disposed"**。
- **根因**：`LearningPreferencesState` 没有 `_disposed` 标志和 `_safeNotify()` 守卫。对比同域 `AccountProfileState`（`account_profile_state.dart` L19-27）已正确实现 `_disposed` + `_safeNotify()` 模式，本状态未复用该模式。
- **预期**：复用 `AccountProfileState` 的 `_disposed`/`_safeNotify()` 模式，或在 `dispose()` 中取消未完成异步。
- **严重度**：**P1**（常见竞态崩溃 — 退出设置页时若偏好正在加载/保存即崩溃）

---

## P2 — UX 降级 / 违反安全约定

### P2-1 · MySpace 返回键使用 raw Navigator.pop — 未用 safePop

- **位置**：`lib/features/account/presentation/my_space_page.dart` L56
- **现象**：AppBar 返回按钮 `onPressed: () => Navigator.pop(context)`。MySpace 由 MainShell 经 `pushNamed` 入栈，当前场景下 pop 可正常返回 MainShell。但若未来 MySpace 被其他入口（如推送深链、快捷方式）作为根路由启动，pop 将导致黑屏。
- **根因**：未复用 `NavUtils.safePop`（canPop 守卫）。违反 WS-6 APP-1 确立的「返回/关闭 → safePop」统一规则。
- **预期**：`onPressed: () => NavUtils.safePop(context)`。
- **严重度**：**P2**（当前低风险 — 总是 pushed；但违反安全约定，未来可能黑屏）

### P2-2 · AccountInfo 返回键使用 raw Navigator.pop — 未用 safePop

- **位置**：`lib/features/account/presentation/account_info_page.dart` L127
- **现象**：AppBar 返回按钮 `onPressed: () => Navigator.pop(context)`。AccountInfo 由 MySpace push，当前安全。
- **根因**：同 P2-1，未复用 `NavUtils.safePop`。
- **预期**：`onPressed: () => NavUtils.safePop(context)`。
- **严重度**：**P2**（同 P2-1）

### P2-3 · UserInfoManage 返回键使用 raw Navigator.pop — 未用 safePop

- **位置**：`lib/features/account/presentation/user_info_manage_page.dart` L98
- **现象**：AppBar 返回按钮 `onPressed: () => Navigator.pop(context)`。UserInfoManage 由 AccountInfo push，当前安全。
- **根因**：同 P2-1，未复用 `NavUtils.safePop`。
- **预期**：`onPressed: () => NavUtils.safePop(context)`。
- **严重度**：**P2**（同 P2-1）

---

## P3 — 代码卫生 / 最佳实践

> 本域无影响即时功能的 P3 问题。以下补充观察供参考：

- **splash_page.dart L71-72**：`setState(() => _showGuide = true)` 在 `await session.setHasShownInitGuide(true)` 之前，且 L62 有 `if (!mounted) return;` 守卫，无 setState-after-dispose 风险。✅
- **login_page.dart L102-139**：`_doLogin()` 内 `if (mounted) setState(...)` 双重守卫。✅
- **my_space_page.dart L202-215**：`_refreshProfile()` 内 `if (!mounted) return;` 守卫。✅
- **account_profile_state.dart L19-27**：`_disposed` + `_safeNotify()` 模式正确，无 notifyListeners-after-dispose 风险。✅
- **ModalRoute.of 在 initState**：本域所有页面均未在 initState 中调用 `ModalRoute.of`。✅
- **Provider 齐全**：`AppSessionState`、`AccountProfileState` 均由 `buildAccountFeatureScope`（`account_feature_providers.dart` L12）在 `app.dart` L37 注入，覆盖所有账户/设置页面。✅
- **空态 NPE 守卫**：`my_space_page.dart` L179、`user_info_manage_page.dart` L62-74 均对 `profile.nickname.isEmpty` 做了空态分支。✅
- **认证入口 pushReplacement**：`splash_page.dart` L84/L89、`login_page.dart` L154 均为认证入口，按约定保留。✅

---

## 汇总

| 等级 | 数量 | 关键问题 |
|------|------|----------|
| P0 | 0 | — |
| P1 | 2 | logout 不跳转（会话生命周期断裂）；LearningPreferencesState notifyListeners after dispose（退出设置页竞态崩溃） |
| P2 | 3 | MySpace / AccountInfo / UserInfoManage 返回键未用 safePop（违反 WS-6 APP-1 统一规则） |
| P3 | 0 | — |

**建议修复优先级**：P1-1（logout 跳转）→ P1-2（LearningPreferencesState 复用 _safeNotify 模式）→ P2-1/2/3（三页面返回键改 safePop）。
