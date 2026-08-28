# WS-6 NAV-A: 全站「返回」语义审计

> 审计范围：全 App 所有页面/会话/全屏组件的进入方式、返回方式、黑屏风险、逐级回首页能力。
> 方法：grep 全量 pushNamed/pushReplacement/pushAndRemoveUntil/popUntil/Navigator.pop + 逐页读取返回键实现。
> ❌ 未改任何 lib/ 代码。

---

## 一、导航架构总览

```
MaterialApp
  └─ home: _HomeShell()
       └─ MainShell (/, 三 Tab 学习/课程/设置, tab 切换非 push)
            ├─ HomeScreen (/home, 整页无底栏, content_routes 返回)
            ├─ 词书/课程 Tab
            └─ 设置 Tab
其它页面全部 Navigator.pushNamed(...) 压栈，返回应 Navigator.pop(context)。
```

- 路由表：`lib/core/router/{app_router, content_routes, learning_routes, account_routes}.dart`
- 推栈入口（进入会话页）：见 `lib/pages/home_page.dart` / `lib/screens/home_screen.dart` 的 `Navigator.pushNamed('/review')` 等
- 关键拦截器：`lib/widgets/session_exit_guard.dart` — `PopScope(canPop: false)` + `onPopInvokedWithResult` 确认后 `Navigator.maybePop`

---

## 二、P0 — 返回黑屏 / 退出 App（最高优先级）

| # | 页面 | 文件:行 | 进入方式 | 返回方式 | 根因 | 严重度 |
|---|------|---------|----------|----------|------|--------|
| 1 | review_page | `lib/pages/review_page.dart:59` | pushNamed('/review') | `pushReplacementNamed('/', ...)` (当 `fromLearnPage && isLastWord`) | 末词「完成学习」用 pushReplacement 把自己替换成 MainShell('/')，栈上只剩唯一路由；若用户再按系统返回键 → 无 route 可 pop → 黑屏（旧版 Flutter）或退出 App（新版 Navigator 静默 drop）。且 `onBack: () => Navigator.pop(context)` (L89) 在栈底 pop 也触发同样问题。 | **P0** |
| 2 | login_page | `lib/features/account/presentation/login_page.dart:170` | pushNamedAndRemoveUntil 清空栈后 push 登录页 | `pushReplacementNamed('/home')` | 登录成功把登录页替换成 HomeScreen；HomeScreen 成为唯一路由。系统返回键 = 退出 App（无上一页）。从「设置→登录」场景尤其明显：用户期望返回设置页，实际直接退出。 | **P0** |
| 3 | uri_scheme_page | `lib/pages/uri_scheme_page.dart:72` | pushNamed (外部 uri scheme 唤醒) | `pushReplacement(MaterialPageRoute(builder: (_) => target))` | 解析目标后 pushReplacement 替换自身为目标页（通常是 MainShell）。若用户从 uri 直达某页后按返回 → 无上一页可退 → 退出 App。 | **P0** |
| 4 | splash_page | `lib/features/account/presentation/splash_page.dart:78-85` | App 启动首页 (home) | `pushNamedAndRemoveUntil('/login', (route) => false)` | 启动页直接清空全部路由并推到 login；后续 login → home 都是替换链。整条启动链没有保留任何历史，任意中间节点返回都只能退出。本身不可返回（启动页），但其「清空栈」语义让后续所有页面失去逐级回首页能力。 | **P0**（间接，影响全链） |
| 5 | review_page | `lib/pages/review_page.dart:89` | — | `onBack: () => Navigator.pop(context)` | FormalReviewHeader 返回按钮直接 pop。若 review_page 已是栈底（例如从 uri_scheme 进入、或由 splash→login→home→pushNamed('/review') 后 review 被 pushReplacement 成唯一路由），pop 无效果/黑屏。缺 `canPop` 守卫。 | **P0** |

### P0 详细说明

**问题本质**：`pushNamedAndRemoveUntil((route) => false)` 与 `pushReplacementNamed('/')` 会把栈压到只剩 1 条路由，导致后续所有系统返回键行为异常。Flutter 旧版 `Navigator.pop` 在唯一路由上 pop 会黑屏（`_RouteEntry` 已被移除但 overlay 未重建）；新版 Navigator 2.0 虽然静默 drop，但在 Android 上系统返回键会直接退出 App，违反用户预期。

**影响面**：
- 启动链 splash → login → home 全部用「替换」语义，用户在任何一层按返回都只能退出；
- 复习完成（末词）用 pushReplacement 替换到主页，返回即退出；
- 外部 uri 直达任意页面后返回即退出。

---

## 三、P1 — 逐级回首页被打断

| # | 页面 | 文件:行 | 现象 | 根因 | 严重度 |
|---|------|---------|------|------|--------|
| 6 | review_page | `lib/pages/review_page.dart:59` | 从学习流程进入复习，末词「完成学习」后无法回到学习页/词书页，直接跳到主页 Tab | `pushReplacementNamed('/')` 把 review 自身替换为 MainShell('/')，栈上 review 之前的所有页（home/learn_session 等）仍存在，但 review 这一层被替换而非弹出；系统返回会从 MainShell 直接退出，跳过了逐级返回路径。 | **P1** |
| 7 | learn_session (via learn_page) | `lib/pages/learn_page.dart:57-66` → pushNamed | learn → 内部再 push review/learn_session，末词完成后 review 用 pushReplacement 到 '/'，中间层级全部被绕过 | 同 #6，栈上 learn_page 还在但系统返回无法回到它（MainShell 是栈底）。 | **P1** |
| 8 | word_detail_page | `lib/pages/word_detail_page.dart:292` | 从学习流程进入 word_detail，末词「完成学习」按钮调用 `Navigator.popUntil(context, (route) => route.isFirst)` | popUntil 到栈底会跳过 word_detail 和所有中间层，直接落到 MainShell（isFirst），用户逐级回退路径被截断。从非学习入口进入时 L298 用 pop，正确。 | **P1** |
| 9 | uri_scheme_page | `lib/pages/uri_scheme_page.dart:72` | 外部 uri 进入任意页面后按返回，无法回到「用户先前在 App 中的位置」 | pushReplacement 把 uri_scheme_page 自身替换为目标页，uri_scheme 自身的路由已被移除，系统返回会退到 uri_scheme 之前的页面（通常是 home），但这不是「逐级」而是「一跳」，且 uri_scheme_page 的临时栈帧已被丢弃，无法恢复。 | **P1** |

### P1 详细说明

**问题本质**：`pushReplacement` 和 `popUntil` 都打破了「压栈顺序 = 返回顺序」的用户心智模型。Android 用户期望系统返回键沿原路径一级级回退，但这些页面让返回「跳跃」或直接到栈底。

---

## 四、P2 — AppBar 返回按钮异常 / 无显式返回

| # | 页面 | 文件:行 | 现象 | 根因 | 严重度 |
|---|------|---------|------|------|--------|
| 10 | word_detail_page | `lib/pages/word_detail_page.dart` (AppBar) | 无显式返回按钮；依赖系统返回键 | AppBar 未声明 `leading`，依赖默认 `automaticallyImplyLeading`（Flutter 自动加返回箭头）。从桌面端/平板布局（`_buildDesktopLayout`）进入时自动 leading 可能缺失或不可见。 | **P2** |
| 11 | listening_player_page | `lib/pages/listening_player_page.dart:67-76` | 全屏播放页，AppBar 仅显示标题和关闭按钮，无「返回」语义区分 | 仅提供「关闭」而非「返回」，用户可能期望逐级回到上一页面但 close 直接 pop。若该页面是栈底则同样黑屏。 | **P2** |
| 12 | immersive_swipe_page | `lib/pages/immersive_swipe_page.dart` | 沉浸式页面，无 AppBar/返回按钮 | 全屏沉浸，用户只能通过系统手势/返回退出；若页面是栈底（如从 uri 直达），返回即退出。 | **P2** |
| 13 | word_machine_page | `lib/pages/word_machine_page.dart` | 无显式 AppBar 返回 | 未声明 leading，依赖系统返回；若为栈底则退出。 | **P2** |

---

## 五、P3 — 低风险 / 设计注意

| # | 页面 | 文件:行 | 现象 | 根因 | 严重度 |
|---|------|---------|------|------|--------|
| 14 | session_exit_guard | `lib/widgets/session_exit_guard.dart:30-48` | PopScope(canPop:false) 拦截系统返回并弹确认 → 确认后 `Navigator.maybePop` | 设计正确（防误退出），但 maybePop 在栈底时不做保护（会黑屏/退出）。不过由 guard 触发说明已在栈中层，风险低。 | **P3** |
| 15 | quick_spell_page | `lib/pages/quick_spell_page.dart` | 无 AppBar leading，仅靠系统返回 | 与其他会话页同构，无特殊风险；但作为会话页若被 pushReplacement 成唯一路由则同 P0。 | **P3** |
| 16 | spell_session_page | `lib/pages/spell_session_page.dart` | 同上 | 同上 | **P3** |

---

## 六、逐页导航清单（Excel 式）

| 页面 | 文件 | 进入方式 | 返回方式 | 可能黑屏 | 逐级回首页 | 根因一句话 | 严重度 |
|------|------|----------|----------|----------|------------|------------|--------|
| review_page | lib/pages/review_page.dart | pushNamed('/review') | pushReplacementNamed('/') (末词) / Navigator.pop (onBack) | ✅ 是 (栈底 pop / 唯一路由) | ❌ 否 (pushReplacement 跳过中间层) | 末词 pushReplacement 到 '/' + onBack 无 canPop 守卫 | P0 |
| login_page | lib/features/account/presentation/login_page.dart | pushNamedAndRemoveUntil 清栈 → push | pushReplacementNamed('/home') | ✅ 是 (home 成唯一路由) | ❌ 否 (启动链全清空) | 登录成功替换为 home，无上一页 | P0 |
| uri_scheme_page | lib/pages/uri_scheme_page.dart | pushNamed (外部唤醒) | pushReplacement → 目标页 | ✅ 是 (直达唯一路由) | ❌ 否 | uri 直达后替换自身，返回即退出 | P0 |
| splash_page | lib/features/account/presentation/splash_page.dart | App 启动 home | pushNamedAndRemoveUntil 清栈 → login | — (本身不可返回) | ❌ 否 (清空全部栈) | 启动链全替换，后续页无逐级回首页能力 | P0 |
| learn_page | lib/pages/learn_page.dart | pushNamed('/learn') | SessionExitGuard → maybePop | ❌ (有 guard) | ⚠️ 部分 (guard 确认后 pop 回 home) | guard 拦截退出，但 pop 后回到 home 而非逐级 | P1 |
| learn_session | lib/screens/learn_session.dart | pushNamed (from learn) | SessionExitGuard → maybePop | ❌ (有 guard) | ⚠️ 部分 | 同 learn_page | P1 |
| word_detail_page | lib/pages/word_detail_page.dart | pushNamed('/word_detail') | popUntil(isLast) / pop | ❌ | ⚠️ 部分 (popUntil 跳级) | 末词 popUntil(isFirst) 跳级回主页 | P1 |
| word_machine_page | lib/pages/word_machine_page.dart | pushNamed | Navigator.pop / 系统返回 | ⚠️ (若栈底) | ✅ 是 (正常 pop) | 正常压栈，无 popReplacement | P3 |
| immersive_swipe_page | lib/pages/immersive_swipe_page.dart | pushNamed | 系统返回 / 手势 | ⚠️ (若栈底) | ✅ 是 | 无 AppBar leading，依赖系统返回 | P2 |
| quick_spell_page | lib/pages/quick_spell_page.dart | pushNamed | Navigator.pop / 系统返回 | ⚠️ (若栈底) | ✅ 是 | 正常会话页 | P3 |
| spell_session_page | lib/pages/spell_session_page.dart | pushNamed | Navigator.pop / 系统返回 | ⚠️ (若栈底) | ✅ 是 | 正常会话页 | P3 |
| listening_player_page | lib/pages/listening_player_page.dart | pushNamed | close 按钮 pop | ⚠️ (若栈底) | ✅ 是 | 全屏播放，仅 close 按钮 | P2 |
| dictionary_page | lib/pages/dictionary_page.dart | pushNamed | Navigator.pop | ❌ | ✅ 是 | 正常压栈 | — |
| home_page | lib/screens/home_page.dart | MainShell (tab) | — (tab 切换) | ❌ | — | 主页，无返回问题 | — |
| home_screen | lib/features/home/presentation/home_screen.dart | content_routes | — | ❌ | — | 内容主页 | — |
| main_shell | lib/shell/main_shell.dart | MaterialApp home | — | ❌ | — | 根 shell，tab 切换不压栈 | — |

---

## 七、修复建议（仅供 lead 决策）

### P0 必修

1. **review_page L59**：末词「完成学习」改 `Navigator.pop(context)` 而非 `pushReplacementNamed('/')`。让系统沿原路逐级返回（review → learn_session → learn_page → home）。
2. **login_page L170**：登录成功改 `Navigator.pop(context)` 返回调用方（如「设置」页），而非 `pushReplacementNamed('/home')`。
3. **uri_scheme_page L72**：`pushReplacement` 改 `Navigator.push`，保留 uri_scheme_page 在栈上；用户返回时先回到 uri_scheme 再回到原页面。
4. **splash_page**：`pushNamedAndRemoveUntil((route) => false)` 改 `pushNamed('/login')`，保留 splash 在栈上（或直接 `pushReplacementNamed('/login')` 仅替换 splash，不清空后续链）。
5. **所有 Navigator.pop 入口**：加 `Navigator.of(context).canPop()` 守卫，栈底时禁用返回按钮或回退到安全行为（不退出 App）。

### P1 推荐

6. **word_detail_page L292**：`popUntil(isFirst)` 改连续 `Navigator.pop(context)` 直到回到调用方，保持逐级语义。
7. **统一会话页退出策略**：所有会话页（review/learn/spell/quick_spell）末词完成统一用 `Navigator.pop` 回到发起方，而非 pushReplacement 到 '/'。

### P2/P3 建议

8. **word_detail_page / immersive_swipe_page / word_machine_page**：显式声明 AppBar `leading: BackButton()`，避免依赖自动推断。
9. **session_exit_guard**：maybePop 失败时（栈底）回退到 `Navigator.of(context).canPop()` 检查，避免静默退出。

---

## 八、关键 grep 结果速查

```bash
# pushReplacement 全量（均为风险点）
lib/pages/review_page.dart:59         pushReplacementNamed('/')
lib/pages/uri_scheme_page.dart:72     pushReplacement(MaterialPageRoute)
lib/features/account/presentation/login_page.dart:170  pushReplacementNamed('/home')
lib/features/account/presentation/splash_page.dart:78-85  pushNamedAndRemoveUntil('/login', (route) => false)

# popUntil 全量
lib/pages/word_detail_page.dart:292   popUntil(isFirst)
lib/app/app_error_widget.dart:36      popUntil(isFirst)
lib/core/router/route_error_page.dart:40  popUntil(isFirst)

# PopScope 全量
lib/widgets/session_exit_guard.dart:30  PopScope(canPop:false)
lib/pages/review_page.dart:55          PopScope(onPopInvoked, 仅 Android 系统退出)
lib/pages/learn_page.dart:57           PopScope(guard 包裹)
lib/screens/learn_session.dart:52      PopScope(guard 包裹)
```

---

审计人：QA其他扫描
日期：2026-08-28
结论：**5 个 P0（黑屏/退出 App）、4 个 P1（逐级回首页被打断）、4 个 P2（返回按钮异常）、3 个 P3（低风险）**。建议统一「压栈 = pop 逐级返回」原则，消除全栈 pushReplacement/pushNamedAndRemoveUntil 清零语义。
