# XP 全盘体检 · 问题总账（Problem Ledger）

> **单一事实源**：汇总全盘体检（XP AUD-1..5）+ 导航审计（WS-6 NAV-A/B）+ 运行期 QA 报告的**所有** P0–P3 问题。
> 每条含 file:line + 现象 + 根因 + 严重度 + **状态**（pending / fixed / won't-fix）+ **回归测试**（修复对应的关键路径测试，见 `test/quality/`）。
> 维护人：lead。各域代理只提交本域报告，由 lead 汇总至此。

---

## 状态图例
- `🔴 P0` 运行时崩溃 / 黑屏 / 退出 App / 数据丢失 —— 必修
- `🟠 P1` 功能缺陷 / 数据错误 / 返回语义错误 —— 必修
- `🟡 P2` 体验 / 鲁棒性 / 边界 case —— 推荐
- `🟢 P3` 代码质量 / 规范 / 冗余 —— 可延后
- 状态：`pending`（待修）｜`fixed`（已修+回归绿）｜`won't-fix`（决策保留）｜`open`（未决策）

---

## 汇总（刷新于 2026-08-29）

| 严重度 | 总数 | 已修 | 待修 | 保留 |
|--------|------|------|------|------|
| P0 | 9 | 7 | 0 | 2 |
| P1 | 9 | 9 | 0 | 0 |
| P2 | 10 | 5 | 5 | 0 |
| P3 | 4 | 2 | 2 | 0 |

> 注：
> - **P0 全部必修项已闭环**：三条真实运行时崩溃（AUD-2 `rate()` 竞态、AUD-4 路由名不匹配、AUD-5 `ScareCoinStore` 作用域倒挂）随本会话 lead 修复并有回归；导航类 P0-1/P0-3/P0-5 由 APP-1 / XP-FIX-5 修复。P0-2/P0-4（认证/启动入口 `pushReplacement`/清栈）决策为 **won't-fix**。
> - **P1 全部 9 项已修复**：由 APP-1/2/3 + XP-FIX-2/3/5 + import_guard 覆盖，均有回归测试。
> - **P2/P3 剩余项**为可延后的视觉/规范/边界 polish（P2-3~P2-7、P3-1、P3-4），已登记待办，属低优先级，不影响核心功能与导航安全。
> - 全站回归门禁已于本次会话跑绿：`flutter analyze` **0** ｜ `flutter test` **494/494** ｜ `import_guard` **0**。

---

## P0 — 运行时崩溃 / 黑屏 / 退出 App

| # | 来源 | file:line | 现象 | 根因 | 状态 | 回归测试 |
|---|------|-----------|------|------|------|----------|
| P0-1 | NAV-A | `lib/pages/review_page.dart:59` | 末词「完成学习」`pushReplacementNamed('/')`，栈只剩唯一路由；再按返回→黑屏/退出 App | 末词用替换而非弹出 | **fixed**（APP-1 → `NavUtils.goHome`） | `test/pages/nav_app1_test.dart` review 完成 goHome |
| P0-2 | NAV-A | `lib/features/account/presentation/login_page.dart` | 登录 `pushReplacementNamed('/')` 成唯一路由 | 认证入口替换语义 | **won't-fix**（认证入口，不可返回登录页） | — |
| P0-3 | NAV-A | `lib/pages/uri_scheme_page.dart:72` | 外部 uri 直达任意页后 `pushReplacement` 替换自身→返回即退出 App | uri 直达不保留上级 | **fixed**（XP-FIX-5：`Uri.tryParse`+try-catch+`RouteNames` 常量+`goHome` 兜底；成功路径保留 `/` 底层根栈，返回可回首页） | `test/pages/uri_scheme_page_test.dart` |
| P0-4 | NAV-A | `lib/features/account/presentation/splash_page.dart:78-85` | 启动 `pushNamedAndRemoveUntil(...,(r)=>false)` 清空全栈→后续所有页失去逐级回首页能力 | 启动链整体清栈 | **won't-fix**（认证入口） | — |
| P0-5 | NAV-A | `lib/pages/review_page.dart:89` | `onBack: () => Navigator.pop(context)` 无 canPop 守卫，栈底 pop 黑屏 | 裸 pop | **fixed**（APP-1 → `NavUtils.safePop`） | `test/pages/nav_app1_test.dart` review onBack safePop |
| P0-6 | AUD-3 | `lib/pages/word_detail_page.dart` 无参 `selectedWord!` NPE / 白屏（NAV-B P2-1 同） | 深链/恢复无 arguments | **fixed**（APP-2 空态守卫） | `test/pages/nav_safety_test.dart` WordDetailPage null-guard |
| P0-7 | AUD-2 | `lib/features/learning/presentation/learning_session_state.dart` `rate()` await 后才自增 `_currentIndex`，快速连点双重推进索引，学到末尾越界 | async 重入竞态 | **fixed**（lead 加 `_isRating` 布尔守卫 + try/finally） | `test/features/learning/presentation/learning_session_state_test.dart` 快速连点只推进一次 |
| P0-8 | AUD-4 | `RouteNames.bookWords='/book_words'` 与 `BookWordsPage.routeName='/book-words'` 不一致，选书页跳转即落 RouteErrorPage（背后=词书不可用主诉之一） | 路由名不匹配 | **fixed**（lead 把 `route_names` 改为 `/book-words`） | `test/quality/route_name_consistency_test.dart` |
| P0-9 | AUD-5 | `lib/features/checkin/presentation/class_checkin_page.dart:420` `context.read<ScareCoinStore>()`，该 Provider 在**子**作用域，运行期 ProviderNotFound | DI 作用域倒挂（app.dart 里 CheckIn 包 ScareCoin） | **fixed**（lead 把 ScareCoinFeatureScope 移到 CheckIn 外层） | `test/architecture/app_structure_test.dart` 嵌套顺序断言（ScareCoin 先于 CheckIn） |

---

## P1 — 功能缺陷 / 数据错误 / 返回语义错误

| # | 来源 | file:line | 现象 | 根因 | 状态 | 回归测试 |
|---|------|-----------|------|------|------|----------|
| P1-1 | NAV-A | `lib/pages/review_page.dart:59` | 末词完成后无法回到学习/词书页，直接跳主页 Tab，逐级返回被打断 | pushReplacement 替换自身跳过中间层 | **fixed**（APP-1 → 完成即 `goHome`，会话结束语义） | `test/pages/nav_app1_test.dart` |
| P1-2 | NAV-A | `lib/pages/learn_page.dart:57-66` → learn_session | learn 内再 push review，末词完成 pushReplacement 到 '/' 绕过中间层级 | 同 P1-1 | **fixed**（APP-1：`learn_page:138` safePop、`:257` goHome；review 完成 goHome） | `test/pages/nav_app1_test.dart` learn_session 逐级返回 |
| P1-3 | NAV-A | `lib/pages/word_detail_page.dart:292` | 末词「完成学习」`popUntil(isFirst)` 跳过 word_detail 与中间层 | popUntil 到栈底截断逐级路径 | **fixed**（APP-2 → goHome） | `test/pages/nav_safety_test.dart` |
| P1-4 | NAV-A | `lib/pages/uri_scheme_page.dart:72` | uri 直达后返回无法回到用户先前位置，一跳而非逐级 | pushReplacement 丢弃 uri_scheme 栈帧 | **fixed**（XP-FIX-5，同 P0-3） | `test/pages/uri_scheme_page_test.dart` |
| P1-5 | AUD-3 | `lib/pages/word_detail_page.dart:322` | `_onDeleteSuccess` 用 `goHome` 而非 `safePop`；删完单词跳首页而非返回上一层 | goHome 语义不适合「删完返回」 | **fixed**（XP-FIX-3 → `NavUtils.safePop`） | `test/pages/word_detail_fix3_test.dart` |
| P1-6 | NAV-B | `lib/core/router/learning_routes.dart:75/85/93/100` | listenModeSelect / listeningPlayer / dictationSession / quickSpell 缺参时返回 RouteErrorPage（深链/恢复场景「前进即失败」） | buildXxx(args) 无参数兜底 | **fixed**（XP-FIX-5：`RouteErrorPage` + `goHome` 兜底，缺参显示「缺少必要参数」页可回首页） | `test/core/router/route_error_page_test.dart` |
| P1-7 | NAV-B | `lib/core/router/content_routes.dart` wordDetail 路由 | 无 `_buildWordDetailPage(args)`，深链无参直接构造 `WordDetailPage()` | 路由无参数解析 | **fixed**（XP-FIX-3：args 安全转换 / WordDetailPage null+args 双兜底） | `test/pages/word_detail_fix3_test.dart` |
| P1-8 | NAV-B | `lib/pages/lib_select_page.dart:445-460` `_startSession` | 个性化词表为空时仍 push 学习页→currentWord=null 白屏 | 未检查个性化结果为空 | **fixed**（APP-1：`:101` safePop + 空词表 SnackBar 守卫） | `test/pages/nav_app1_test.dart` lib_select 空词表提示 |
| P1-9 | AUD-3 | `lib/widgets/word_dictionary_popup.dart:9` / `favorites_accessor_adapter.dart` | 跨 feature import `learning_favorites_state.dart` | 跨 feature presentation 耦合 | **fixed**（import_guard 全库 0 违规） | `test/architecture/import_guard_test.dart` |

---

## P2 — 体验 / 鲁棒性 / 边界 case

| # | 来源 | file:line | 现象 | 根因 | 状态 | 回归测试 |
|---|------|-----------|------|------|------|----------|
| P2-1 | AUD-3 | `lib/pages/word_detail_page.dart:60-61` | 深链场景无词时静默退出，无错误提示 | `_resolveTargetWord(null)` 无 UI 反馈 | **fixed**（XP-FIX-3：try-catch +「返回上一页」按钮） | `test/pages/word_detail_fix3_test.dart` |
| P2-2 | AUD-3 | `lib/pages/word_detail_page.dart:1006,1010` | Dialog 内 `Navigator.pop` 未用 NavUtils | 与全局模式不一致 | **fixed**（XP-FIX-3 → `_NoteDialog` safePop） | `test/pages/word_detail_fix3_test.dart` |
| P2-3 | NAV-A | `lib/pages/word_detail_page.dart` AppBar | 无显式 leading，依赖自动推断；desktop/平板可能缺失 | AppBar 未声明 leading | **pending**（polish） | — |
| P2-4 | NAV-A | `lib/pages/immersive_swipe_page.dart` | 全屏沉浸无 AppBar 返回按钮 | 无显式返回入口 | **pending**（APP-2 已加 safePop 关闭，未加显式按钮） | — |
| P2-5 | NAV-A | `lib/pages/word_machine_page.dart` | 无显式 AppBar leading | 依赖系统返回 | **pending**（polish） | — |
| P2-6 | NAV-A | `lib/pages/listening_player_page.dart:67-76` | 全屏仅「关闭」无「返回」语义区分 | close vs back 语义混 | **pending**（polish） | — |
| P2-7 | AUD-3 | `lib/pages/dictionary_page.dart` | 不支持深链按单词名查询 | 接收 Word 对象参数 | **pending**（polish） | — |
| P2-8 | NAV-A | `lib/widgets/session_exit_guard.dart:30-48` | `maybePop`/裸 pop 在栈底不做保护 | 无 canPop 兜底 | **fixed**（XP-FIX-2 → `NavUtils.safePop`） | `test/pages/session_empty_and_mounted_test.dart` SessionExitGuard 确认→safePop |
| P2-9 | NAV-B | 各 session 完成 `Navigator.pop` | 父 unmount 时 pop 抛 after dispose | 无 mounted 守卫（已部分修复） | **fixed**（APP-2/3 加 mounted）+ XP-FIX-2 mounted 守卫 | `test/pages/session_empty_and_mounted_test.dart` |
| P2-10 | AUD-2 | `lib/pages/dictation_session_page.dart` / `spell_session_page.dart` / `sentence_quiz_page.dart` / `quick_spell_page.dart` | 空 `words` 进入会话页白屏 | 无空词表优雅降级 | **fixed**（XP-FIX-2 空态页：图标+标题+返回首页 goHome） | `test/pages/session_empty_and_mounted_test.dart` 4 会话页空词表不白屏 |

---

## P3 — 代码质量 / 规范 / 冗余

| # | 来源 | file:line | 现象 | 根因 | 状态 | 回归测试 |
|---|------|-----------|------|------|------|----------|
| P3-1 | AUD-3 | `lib/pages/word_detail_page.dart` | TabController 未走 Provider 端口 | 与四层范式不一致 | **open**（跨 Page+全部调用方，超出 XP-FIX-3 范围，独立任务） | — |
| P3-2 | AUD-3 | `lib/core/router/content_routes.dart` | wordDetail 路由 arguments cast 无 fallback | cast 异常风险 | **fixed**（XP-FIX-3：args 安全转换 + `RouteErrorPage` 兜底） | `test/pages/word_detail_fix3_test.dart` |
| P3-3 | NAV-B | `lib/core/router/learning_routes.dart:106` | wordExport 缺参分支不可达（无 pushNamed 入口） | 代码冗余 | **fixed**（现 `_buildWordExportPage` 已接入 `RouteNames.wordExport` 且带缺参 `RouteErrorPage` 兜底，分支可达） | — |
| P3-4 | NAV-A | `lib/pages/quick_spell_page.dart` / `spell_session_page.dart` | 无 AppBar leading，仅系统返回 | 会话页同构 | **pending**（polish） | — |

---

## 参考报告索引

- WS-6 全站返回审计（NAV-A）：`docs/reports/ws6_nav_audit.md`
- WS-6 全站前进审计（NAV-B）：`docs/reports/ws6_nav_forward_audit.md`
- XP 全盘体检·域3 词典/搜索/单词详情（AUD-3）：`docs/reports/xp_aud3_dictionary.md`
- XP 全盘体检·域1 账户/登录/设置（AUD-1）：`docs/reports/xp_aud1_account.md`
- XP 全盘体检·域2 学习/复习/会话（AUD-2）：`docs/reports/xp_aud2_learning.md`
- XP 全盘体检·域4 词书/书库/选书（AUD-4）：`docs/reports/xp_aud4_book.md`
- XP 全盘体检·域5 其它（AUD-5）：`docs/reports/xp_aud5_other.md`

## XP-FIX 落地记录（修复 → 回归测试映射）

> 每个修复项都在 `docs/reports/xp_fix*.md` 有对应报告；dev 均可编译 + 回归测试全绿。

| 修复任务 | 文件（改动点） | 回归测试 | 状态 |
|---|---|---|---|
| XP-FIX-2 空词表优雅降级 | `lib/pages/dictation/spell/sentence_quiz/quick_spell_session_page.dart` | `test/pages/session_empty_and_mounted_test.dart`（6 例） | ✅ fixed |
| XP-FIX-2 会话页 mounted 守卫 | 上述会话页 `_next()`/`Timer` | 同上 | ✅ fixed |
| XP-FIX-2 session_exit_guard 安全化 | `lib/widgets/session_exit_guard.dart` | 同上 | ✅ fixed |
| XP-FIX-4 DB 未初始化 StateError | `lib/data/wordbook_database.dart`（`isInitialized` getter） | `test/data/wordbook_database_test.dart`（2 例） | ✅ fixed |
| XP-FIX-4 getBooks/getWordCount 异常穿透 | `lib/repositories/book_repository_impl.dart`（前置检查+try-catch） | 编译级 | ✅ fixed |
| XP-FIX-4 fromMap word_count 列名不匹配 | `lib/models/book.dart`（word_count→wordCount→total_words 降级） | `test/models/book_frommap_test.dart`（6 例） | ✅ fixed |
| XP-FIX-4 加载失败无反馈 / totalWords 回退 / id=0 误跳 | `lib/features/book/presentation/book_state.dart` | `test/features/book/presentation/book_state_test.dart`（8 例） | ✅ fixed |
| XP-FIX-4 `/lib-select` 字面量 | `lib/features/book/presentation/books_page.dart` | 编译级 | ✅ fixed |
| XP-FIX-3 `nav_utils.dart` safePop 支持可选 result | `lib/core/router/nav_utils.dart`（向后兼容扩展） | `test/pages/word_detail_fix3_test.dart` | ✅ fixed |
| XP-FIX-3 word_detail 删后返回 goHome→safePop（P1-5） | `lib/pages/word_detail_page.dart` | 同上 | ✅ fixed |
| XP-FIX-3 word_detail 深链无词 try-catch + 「返回上一页」（P2-1） | `lib/pages/word_detail_page.dart` | 同上 | ✅ fixed |
| XP-FIX-3 _NoteDialog 裸 pop→safePop（P2-2） | `lib/pages/word_detail_page.dart` | 同上 | ✅ fixed |
| XP-FIX-3 word_dictionary_popup 裸 pop→safePop（AUD-6） | `lib/widgets/word_dictionary_popup.dart` | 编译级 | ✅ fixed |
| XP-FIX-3 content_routes wordDetail args 安全转换（P3-2/P1-7） | `lib/core/router/content_routes.dart` | `test/pages/word_detail_fix3_test.dart` | ✅ fixed |
| ⚠️ AUD-3 P3-1 word_detail TabController 走 Provider 端口 | 评估跨 Page+全部调用方，超出 XP-FIX-3 范围 | 待独立任务 | 🔲 open |
| AUD-1 logout 未接入 | `MoreSettingsPage:339` 仅 pop 弹窗，`AppSessionState.logout()` 已有未用 | XP-FIX-6 | ✅ fixed |
| AUD-1 返回按钮裸 pop | `SettingsPage:45` / `MoreSettingsPage:361` 已 import nav_utils 未用 | XP-FIX-6 | ✅ fixed |
| AUD-1 登录态不持久 | `AppSessionState._isLoggedIn` 纯内存，冷启动恒 false → 每次重登录 | XP-FIX-6 | ✅ fixed |
| AUD-1 LoginPage 退出双 pop | `LoginPage:195-200` 退出框先 pop dialog 再 pop self 可能越过栈底 | XP-FIX-6 | ✅ fixed |
| **XP-FIX-6 登录态 SharedPreferences 持久化** | `lib/features/account/presentation/app_session_state.dart`（`login/phoneLogin/logout` 读写 `LoggedIn` key） | `test/pages/account_fix6_test.dart`（7 例） | ✅ fixed |
| **XP-FIX-6 账号启动恢复** | `lib/features/account/application/account_feature_providers.dart`（`_AccountFeatureInitializer.restore()`） | 同上 | ✅ fixed |
| **XP-FIX-6 LoginPage 退出双 pop** | `lib/features/account/presentation/login_page.dart`（dialog 弹窗内 pop 保留，页面级 back 改 safePop） | 同上 | ✅ fixed |
| **XP-FIX-6 logout 接入 + 安全 pop** | `lib/features/settings/presentation/more_settings_page.dart`（`logout()` 调用 + safePop） | 同上 | ✅ fixed |
| **XP-FIX-6 account_profile_state dispose 安全** | `lib/features/account/presentation/account_profile_state.dart`（`_disposed` + `_safeNotify`） | 同上 | ✅ fixed |
| **APP-1 学习/复习/选书返回安全** | `lib/pages/review_page.dart`（`:60` goHome、`:66/:90` safePop）、`lib/screens/learn_session.dart`（safePop）、`lib/pages/learn_page.dart`（`:138` safePop、`:257` goHome）、`lib/pages/lib_select_page.dart`（`:101` safePop + 空词表守卫） | `test/pages/nav_app1_test.dart`（5 例）+ `test/pages/nav_safety_test.dart`（8 例，合并 13 例） | ✅ fixed |
| **lead 补丁 AUD-1 P1-2a SettingsPage 返回裸 pop** | `lib/features/settings/presentation/settings_page.dart:45` `Navigator.pop`→`NavUtils.safePop` | `flutter analyze` 0 | ✅ fixed |
| AUD-5 scare_coin 空态 | 经核实**已有**空态检查（stale finding，非 bug） | — | ⚪ not-a-bug |
| AUD-5 word_notes/sentence_favorites 路由未注册 | 经核实**文件不存在**（页面为 word_browse 内部私有 widget，stale finding） | — | ⚪ not-a-bug |
