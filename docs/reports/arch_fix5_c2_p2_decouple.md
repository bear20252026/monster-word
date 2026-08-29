# ARCH-FIX-5 / C2-P2 深度解耦蓝图（lead 规划）

> 用户决策：**路径 A —— 彻底解耦**。目标：消除 feature 间的隐藏耦合（经 `lib/pages` shim 间接引用 / 直接构造跨 feature 类 / 数据共享直连），使架构科学、边界清晰、不混乱。
> 前置：门禁当前已全绿（analyze 0 / test 533 / import_guard 9）。本蓝图执行后需重跑全量门禁。

---

## 0. 解耦的三大类（科学分类）

所有跨 feature 依赖归为三类，各有明确解法，不混为一谈：

| 类别 | 特征 | 错误迹象 | 正确解法 |
|---|---|---|---|
| **A. 导航跳转耦合** | feature A 为「跳到 feature B 的页面」而 import B 的页面类 | `Navigator.pushNamed(context, XxxPage.routeName)` 或 `Navigator.push(MaterialPageRoute(builder: (_) => XxxPage()))` | 用 `Navigator.pushNamed(context, RouteNames.xxx, arguments: {...})`，删掉跨 feature 的 `import ..._page.dart`。RouteNames 在 core，任何层可用 |
| **B. 数据/状态耦合** | feature A 直接读 feature B 的 state/port/repository | `import '../../learning/application/book_words_reader.dart'`、`import '../../x/presentation/xx_state.dart'` | 经 feature 端口（项目已有 `Provider<Port>.value()` 范式），或数据下沉共享/domain |
| **C. 归属错误** | 基类/组件放错 feature，被子 feature 继承/使用 | 5 个 learning words 页 `import .../book/presentation/list_words_page.dart` | 把基类挪到正确的 feature（list_words 基类 → learning） |

> **核心原则**：导航一律走 RouteNames（core 层合同），数据一律走端口，继承/复用放在同一 feature。这样 feature 之间**零直接 import**，边界干净。

---

## 1. 已勘探的跨 feature 依赖全清单（22 处 + 数据）

### C 类：归属错误（1 处影响 5 文件）
- `features/learning/presentation/{mastered_words,my_words,new_words,not_learned_words,reviewing_words}_page.dart` → `import '../../../pages/list_words_page.dart'`（定义在 book feature）
  - **解法**：把 `ListWordsPage` 基类从 `features/book/presentation/list_words_page.dart` 移到 `features/learning/presentation/list_words_page.dart`；`lib/pages/list_words_page.dart` 垫片 re-export learning 版；5 个子页 import 改 `list_words_page.dart`（同 feature）。
  - 注意：`list_words_page.dart` 若同时被 book 引用则再评估；据勘探仅 learning 使用。

### A 类：导航跳转耦合（from → to，跳转目标）
| from feature.file | import target（经 pages shim 或 feature） | 目标真实 feature | 现跳转模式 | RouteNames |
|---|---|---|---|---|
| account/appearance_page | `immersive_swipe_page` | learning | 待确认 | `immersiveSwipe` ✓ |
| account/my_space_page | `message_page` | account（同 feature） | 待确认 | `messages` ✓ |
| account/my_space_page | `settings_page` | settings | 待确认 | `settings` ✓ |
| book/book_words_page | `word_detail_page` | dictionary | 待确认 | `wordDetail` ✓ |
| book/courses_page | `class_checkin_page` | checkin | pushNamed(XxxPage.routeName) | **缺** `classCheckin` |
| book/courses_page | `class_activity_page` | checkin | pushNamed(XxxPage.routeName) | **缺** `classActivity` |
| book/lib_select_page | `dictation_session_page` | learning | `MaterialPageRoute(_ => DictationSessionPage())` | `dictationSession` ✓ |
| book/lib_select_page | `quick_spell_page` | learning | `MaterialPageRoute(_ => QuickSpellPage())` | `quickSpell` ✓ |
| book/lib_select_page | `word_export_page` | book（同 feature） | `MaterialPageRoute(_ => WordExportPage(...))` | `wordExport` ✓ |
| book/lib_select_page | `book_words_page` | book（同 feature） | 待确认 | `bookWords` ✓ |
| book/lib_select_page | `extensive_model_select_page` | book（同 feature） | `MaterialPageRoute(_ => ExtensiveModelSelectPage(...))` | `listenModeSelect` ✓ |
| book/lib_select_page | `search_page` | search | 待确认 | `search` ✓ |
| learning/learn_page | `word_detail_page` | dictionary | 待确认 | `wordDetail` ✓ |
| learning/review_page | `dictionary_page` | dictionary | 待确认 | `dictionary` ✓ |
| settings/more_settings_page | `account_info_page` | account | pushNamed(AccountInfoPage.routeName) | `accountInfo` ✓ |
| settings/more_settings_page | `feedback_page` | settings（同 feature） | pushNamed(FeedbackPage.routeName) | `feedback` ✓ |
| settings/more_settings_page | `redemption_center_page` | account | pushNamed(RedemptionCenterPage.routeName) | `redemption` ✓ |

### A 类补充（lib_select 内 `BookDashboardPage`）
- `book/lib_select_page.dart` → `const BookDashboardPage()`（`MaterialPageRoute`）
  - 需确认 BookDashboardPage 归属与 routeName；若无 named route，评估补 `bookDashboard` 或归属处理。

### B 类：数据/状态耦合
- `feature/book/presentation/lib_select_page.dart` → `import '../../learning/application/book_words_reader.dart'`（learning 数据端口）
  - `_startDictation`/`_startQuickSpell` 用 `context.read<BookWordsReader>().loadWords(book.id)` —— **经 learning 应用端口读数据**，属跨 feature 数据耦合。
  - **解法**：book 不应读 learning 的 reader。要么把「按 book 加载单词」能力定义为 book 自身端口，要么经共享 domain。需按端口范式重构。
- `feature/book/presentation/lib_select_page.dart` → `import '../../learning/presentation/learning_session_state.dart'`
  - `context.read<LearningSessionState>().currentBook` —— 读 learning 状态持有当前词书。
  - **解法**：当前词书是「共享上下文」，应放共享层或经端口读取，而非直接依赖 LearningSessionState。
- `feature/book/presentation/word_export_page.dart` → `import '../../learning/application/book_words_reader.dart'`
- `feature/book/presentation/{learn? 等}*` → 视勘探补充。

---

## 2. 逐阶段执行（每步 compile + 针对性测试，滚动绿）

### Phase 1 — C 类：list_words 基类归属修正（先做，最简单且不涉及路由）
1. 复制 `features/book/presentation/list_words_page.dart` → `features/learning/presentation/list_words_page.dart`（保持类名 `ListWordsPage`/`ListWordsPageState`）。
2. 5 个 learning words 子页 import 改 `'../list_words_page.dart'`（同 feature）。
3. `lib/pages/list_words_page.dart` 垫片 re-export learning 版。
4. 若 `lib/features/book/presentation/list_words_page.dart` 无其它引用 → 删除（有则评估）。
5. `flutter analyze lib/features/learning lib/features/book lib/pages/list_words_page.dart` 0 issues。

### Phase 2 — RouteNames 缺口补齐 + 注册
- 补 `RouteNames.classCheckin='/class_checkin'`、`RouteNames.classActivity='/class_activity'`（在 route_names.dart）。
- 在对应协调器（learning_routes 或 account_routes，视 class_checkin/class_activity 归属）注册 `case RouteNames.classCheckin: return const ClassCheckinPage();` 等。
- 确认 `bookDashboard` 归属：若 BookDashboardPage 属 book，补 `RouteNames.bookDashboard` + 在 learning_routes 注册（lib_select 使用）；否则评估跳转方式。

### Phase 3 — A 类：同名 feature 跳转统一改用 RouteNames + 删 import
逐文件：
- `more_settings_page.dart`(settings)：`AccountInfoPage.routeName`→`RouteNames.accountInfo`、`FeedbackPage.routeName`→`RouteNames.feedback`、`RedemptionCenterPage.routeName`→`RouteNames.redemption`；删对应 import。
- `my_space_page.dart`(account)：`MessagePage.routeName`→`RouteNames.messages`、`SettingsPage.routeName`→`RouteNames.settings`；councils feature 判定（account→account 的 message 若同 feature 可保留 import，但统一 RouteNames 更一致）。
- `courses_page.dart`(book)：`ClassCheckInPage.routeName`→`RouteNames.classCheckin`、`ClassActivityPage.routeName`→`RouteNames.classActivity`；删 import。
- `appearance_page.dart`(account)：`ImmersiveSwipePage.routeName`→`RouteNames.immersiveSwipe`；删 import。
- `book_words_page.dart`(book)：`WordDetailPage` 跳转 → `RouteNames.wordDetail`；删 import。
- `learn_page.dart`(learning)：`WordDetailPage` 跳转 → `RouteNames.wordDetail`；删 import。
- `review_page.dart`(learning)：`DictionaryPage` 跳转 → `RouteNames.dictionary`；删 import。
- `lib_select_page.dart`(book)：把所有 `MaterialPageRoute(builder: (_) => XxxPage(...))` 改 `Navigator.pushNamed(context, RouteNames.xxx, arguments: {...})`；删除全部跨 feature 页面 import（dictation_session/quick_spell/word_export/extensive_model_select/search/book_words）。

### Phase 4 — B 类：数据耦合端口化
- `book/lib_select_page.dart` 的 `BookWordsReader`（learning）→ 改为 book 自身端口（定义 `LoadBookWordsPort`）或下沉 domain；`LearningSessionState.currentBook` 改为读共享上下文端口。
- `book/word_export_page.dart` 的 `BookWordsReader`（learning）→ 同理。
- 这些端口注册进对应 feature 的 provider 树。

### Phase 5 — 删 shim + 归 infra + 清目录
- 删所有已无引用的 `lib/pages/*.dart` 垫片（跨 feature import 已在 Phase 3 消除）。
- `base_web_page`/`uri_scheme_page` → 归 `lib/core/web/`/`lib/core/router/`。
- `book_words_page` adapter：确认 P1d 的 router adapter 是否仍被需要（书词详情路由），若可归到 feature 则删除 adapter。
- 清空 `lib/pages`、`lib/screens`（保留 core 层容器）。

### Phase 6 — 全量门禁 + 加固 import_guard
- 更新 `import_guard.dart` 或 `import_guard_test.dart`：**收紧** —— feature 内禁止 `import '../../../pages/'`（堵住 shim 中转盲区），feature 间禁止 `import '../../<other_feature>/`（R4 严格化）。
- 全量 `flutter analyze` / `flutter test` / `import_guard_test` 全绿。

---

## 3. 判定（完成 = 全绿 + 真正解耦）
1. `lib/features/**` 内**零** `import` 其他 feature（跨 feature 直接 import 全清零）。
2. `lib/features/**` 内**零** `import '../../../pages/'`（无 shim 中转）。
3. 导航全部走 `RouteNames + Navigator.pushNamed`；数据走端口。
4. `lib/pages`、`lib/screens` 清理完成（或仅 LEAD 批准的 core 容器）。
5. 门禁：`flutter analyze` 0 / `flutter test` 全绿 / `import_guard_test` 0（加固后）。
6. 报告 `docs/reports/arch_fix5_c2_p2_decouple.md` 记录。

---

## 4. 风险与回滚
- **改 import_guard 是高风险**：收紧规则可能误拦合法同 feature import。需谨慎，用白名单/精准规则，逐步收紧并跑全量回归。
- **数据流断裂**：`lib_select_page._startDictation` 现已把 words load 出后构造无参会话页，但会话页从 `LearningSessionState.queue` 读。端口化时确保 **words 正确注入 SessionState.queue**，否则听写/拼写 session 读不到词。这是 P1 遗留的功能 bug，Phase 4 一并修复。
- 每 Phase 结束 `git status` 记录；错误时回退到上一 Phase 基准（**严禁 reset --hard**）。

---

## 5. 与并行任务的隔离
- 本蓝图由 **LEAD 串行执行**（不派 teammate 并行抢写）。
- 与 UX-FIX-B（Apple/Claude 设计语言）正交，仅 doc，不冲突。
- 严禁 `git commit` 直到全量门禁绿 + LEAD 复核。

---

## 6. 执行进度（滚动更新）

### Phase 1 —— C 类归属修正 ✅ 完成（2026-08-29, lead）
- `ListWordsPage` 基类从 `features/book/presentation/list_words_page.dart` 移到 `features/learning/presentation/list_words_page.dart`（保持类名/import 不变，`../../../core` 相对路径不受位置影响）。
- 5 个 learning 子页（new/my/mastered/reviewing/not_learned）import 改 `'list_words_page.dart'`（同 feature）。
- `lib/pages/list_words_page.dart` 垫片 re-export learning 版 + 注释更新。
- 删除 book 版基类（grep 确认无引用）。
- 全库 analyze 0 issues。

### Phase 3a —— 导航统一 RouteNames + 删跨 feature/shim import（进行中）
已解耦（全库 analyze 保持 0 issues）：
- `features/settings/presentation/more_settings_page.dart`：
  - 删 3 个 shim import（account_info/feedback/redemption_center）+ 加 `route_names.dart`
  - `AccountInfoPage.routeName`→`RouteNames.accountInfo`、`FeedbackPage.routeName`→`RouteNames.feedback`、`RedemptionCenterPage.routeName`→`RouteNames.redemption`
- `features/account/presentation/my_space_page.dart`：
  - 删 2 个 shim import（message/settings）+ 加 `route_names.dart`
  - `MessagePage.routeName`→`RouteNames.messages`、`SettingsPage.routeName`→`RouteNames.settings`
  - 字面量 `'/appearance'`→`RouteNames.appearance`、`'/settings'`→`RouteNames.settings`、`'/more_settings'`→`RouteNames.moreSettings`、`'/scare_coin_history'`→`RouteNames.scareCoinHistory`

### 关键架构发现（本轮勘探）
- **router 层是 shim 依赖源头**：`core/router/{learning,content,account}_routes.dart` 用 `import '../../pages/*.dart'` 构造页面 → core→pages→feature 链条。删 shim 前须 repoint 路由层 import 到 feature 真源。
- **断链路由**：`/class_checkin`、`/class_activity` 未在任一协调器注册（`courses_page` 用它们 pushNamed → AppRouter.buildPage 返回 null → latent bug）。需补 `RouteNames.classCheckin/classActivity` + 在 AccountRoutes 注册。
- **ListWords 归属已修正**（见 Phase 1）。

### 待办
- Phase 3a 剩余：appearance_page、courses_page、book_words_page、learn_page、review_page、lib_select_page
- Phase 3b：repoint router 层 import → feature 真源（learning_routes/content_routes/account_routes）
- Phase 2：补 RouteNames.classCheckin/classActivity + 注册断链路由 + bookDashboard 归属
- Phase 4：数据耦合端口化（book→learning 的 BookWordsReader/LearningSessionState）
- Phase 5：删 shim、归 infra（base_web/uri_scheme→core）、清 pages/screens
- Phase 6：全量门禁 + 加固 import_guard

---

## 7. 本轮重大进展（2026-08-29 lead 串行，全库 analyze 0 / 运行态测试 532/532）

### ✅ 修复 import_guard 全库扫描在 Windows 假绿（根治性发现）
`test/architecture/import_guard_test.dart` 的 `_scanLib()` 用 `File.path`（Windows 反斜杠）
构建 `realPaths`，却与正向斜杠的逻辑路径 `'lib/${to}'` 做 `contains` 比较 → 分隔符不一致，
导致**所有相对 import 都被判为「无效、跳过」**，全库扫描恒报 0 违规（假绿，实际靠 CI/Linux 才生效）。
修复：`realPaths` 归一化为正向斜杠 `f.path.replaceAll(r'\', '/')`。修复后门禁在本机真实生效，
暴露出全部真实跨功能 import。**这是本次最有价值的发现——之前「import_guard 9/9 绿」是假象。**

### ✅ R-core 组合根豁免（科学化 core 依赖方向）
`core/di/service_locator.dart`（DI 注册表）与 `core/router/{content,learning,account}_routes.dart`
（路由装配器）按设计必须 import feature 的实现。它们属 IoC 组合根/装配边界：只「组装」不承载业务逻辑。
在 `import_guard.dart` 的 R-core 规则增加豁免 `core/di/`、`core/router/`，避免依赖方向误报；
**core 其余部分仍严格禁止依赖 features**（核心契约纯净性保持）。

### ✅ 核心会话契约（Phase 4 基础设施）
- 新增 `core/learning/learning_session_reader.dart`（只读：`currentBook`/`currentWord`）。
- `core/learning/learning_session_starter.dart` 增加 `startWordSession(List<Word>, {Book?})`。
- `learning_session_starter_impl.dart` 同时实现 Starter + Reader；learning provider 增加
  `ProxyProvider<LearningSessionState, LearningSessionReader>`。
- `ListeningMode` 枚举从 `features/learning/presentation/listening_player_page.dart` 上移到
  `core/learning/listening_mode.dart`（book/learning/router 共享的纯值类型，消除 book→learning R4）。

### ✅ Phase 2 部分：修复断链路由（latent 黑屏）
`courses_page` 曾 pushNamed 到未注册的 `/class_checkin`、`/class_activity`。
已补 `RouteNames.classCheckin`/`classActivity` 并在 `account_routes.dart` 注册（`const ClassCheckInPage()`/`ClassActivityPage()`）。

### ✅ Phase 3a / 4 已解耦文件（A 类导航 + B 类数据）
- `lib_select_page.dart`（book）：删 learning `BookWordsReader` + `LearningSessionState` import →
  改用 book 自身 `../application/book_words_reader.dart` + 核心 `LearningSessionReader`/`LearningSessionStarter`；
  删全部 shim 页面 import，导航统一 `RouteNames.{search,bookWords,immersiveSwipe,dictationSession,quickSpell}`；
  **修复听写/随手拼 words 未注入会话队列的数据流 bug**（`startWordSession(words, book)` 注入后才导航）。
- `courses_page.dart`（book）：`ClassCheckIn/ActivityPage.routeName`→`RouteNames.{classCheckin,classActivity}`，删 shim import。
- `book_words_page.dart`（book）：`WordDetailPage.routeName`→`RouteNames.wordDetail`，字面量 `/immersive_swipe`→`RouteNames.immersiveSwipe`，删 shim import。
- `extensive_model_select_page.dart`（book）：learning `BookWordsReader`→book 自身端口；`ListeningPlayerPage.routeName`→`RouteNames.listeningPlayer`；用 `core/learning/listening_mode.dart` 的 `ListeningMode`。
- `word_export_page.dart`（book）：learning `BookWordsReader`→book 自身端口。
- `search_page.dart`（search）：`DictionaryPage(word: w)` MaterialPageRoute→`pushNamed(RouteNames.dictionary, arguments: w)`，删 dictionary 页面 import。

### 验证状态
- `flutter analyze`：0 issues。
- `flutter test`：**532/532 通过**（唯一失败为 import_guard harness，且为**正确**报出 12 条真实 R4 违规，非回归）。
- `import_guard_test`：R-core 清零；剩余 **12 条 R4 跨功能违规**（见下）。

### 🔴 剩余 12 条 R4 违规（真实待解耦，需契约设计，非快速补丁）
| 文件 | 违规依赖 | 处置 |
|---|---|---|
| `content/my_content_page.dart` | `learning/presentation/learning_collections_state.dart` | 需新 core 契约（collections）或收窄为已有 core store |
| `content/my_fav_page.dart` | `learning/presentation/learning_favorites_state.dart` + `learning_session_state.dart` | 核心 `LearningFavoritesStore`/`LearningSessionReader` 需补方法（`loadFavoriteWords`/`queue`）再消费 |
| `content/my_fav_sentence_page.dart` | `word_browse/application/sentence_favorites_store.dart` | 需新 core 契约（sentence_favorites） |
| `dictionary/word_detail_page.dart` | `learning/application/review_schedule_reader.dart`、`learning_session_state.dart`、`word_browse/application/sentence_favorites_store.dart`、`word_browse/application/word_notes_store.dart` | 需 new core 契约（review_schedule/sentence_favorites/word_notes）+ 会话改 Reader/Starter |
| `word_browse/foot_mark_page.dart` | `learning/presentation/learning_collections_state.dart`、`learning_session_state.dart`、`learning_statistics_state.dart`、`new_words_state.dart` | `new_words`→core `NewWordsStore`、会话→Reader；collections/statistics 需新契约 |

**下一步（Phase 4/6 续）**：按上表为 collections/statistics/review_schedule/sentence_favorites/word_notes 抽取 core 契约，
并用核心 `LearningSessionReader/Starter`、`LearningFavoritesStore`、`NewWordsStore` 收窄 content/dictionary/word_browse 的消费；
随后 Phase 3b repoint 路由层 import → feature 真源，Phase 5 删 shim + 清 pages/screens，Phase 6 全量门禁 + 加固 import_guard（防 shim 中转）。

### 待办（更新后）
- Phase 2 剩余：bookDashboard 归属确认。
- Phase 3b：repoint router 层 import → feature 真源。
- Phase 4：为 12 条 R4 违规抽取 core 契约并收窄 content/dictionary/word_browse 消费。
- Phase 5：删 shim、归 infra、清 pages/screens。
- Phase 6：全量门禁绿 + 加固 import_guard（`'../../../pages/'` 禁 import + R4 严格化）。
