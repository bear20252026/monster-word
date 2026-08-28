# [WS-6 NAV-B] 全站「前进」语义审计报告

**日期**: 2026-08-28
**范围**: 全站所有 Navigator.pushNamed / push / pop / onSessionComplete 触发点
**方法**: grep 所有导航调用 → 逐一点检查路由注册、参数解析、运行期依赖
**路由架构**: `AppRouter.buildPage` 按 `LearningRoutes → ContentRoutes → AccountRoutes → RouteErrorPage` 优先级分发

## 审计总览

| 严重度 | 数量 | 说明 |
|--------|------|------|
| **P0（前进即失败）** | 0 | — |
| **P1（参数缺失即失败）** | 4 | buildXxx(args) 缺参返回 RouteErrorPage |
| **P2（特定条件失败）** | 3 | 空数据 / 竞态 / 边缘 case |
| **P3（潜在风险）** | 2 | 体验差 / 代码冗余 |

---

## P1 — 参数缺失即失败（用户点「前进」→ 看到 RouteErrorPage）

### P1-1: `learning_routes.dart:75` — listenModeSelect 缺参返回 RouteErrorPage

**触发**: `extensive_model_select_page.dart:134` → `_startListeningMode(ListeningMode wordMeaning)` → 但用户可能从其他入口（如 deep link、路由恢复）进入 `/listen-mode-select` 且不传 args。

**根因**: `_buildListenModeSelectPage(args)` 在 `map == null` 时 `return const RouteErrorPage(routeName: 'listen_mode_select', message: '缺少必要参数')`。

**正常 flow**: `lib_select_page` 通过 `MaterialPageRoute` 直接 push `ExtensiveModelSelectPage`，绕过路由表，所以正常 flow 安全。但如果通过 `pushNamed(RouteNames.listenModeSelect)` 进入且无 args → RouteErrorPage。

**严重度**: **P1** — 正常 flow 安全，但 pushNamed 深链/恢复场景下失败。

---

### P1-2: `learning_routes.dart:85` — listeningPlayer 缺参返回 RouteErrorPage

**触发**: 通过 `pushNamed(RouteNames.listeningPlayer)` 进入且无 args → RouteErrorPage。

**根因**: `_buildListeningPlayerPage(args)` 在 `map == null` 时返回错误页。words 为空时仍构建页面但无数据 → 白屏。

**正常 flow**: `extensive_model_select_page.dart` 通过 `MaterialPageRoute` 直接 push，绕过路由表，安全。

**严重度**: **P1** — pushNamed 深链场景失败。

---

### P1-3: `learning_routes.dart:93` — dictationSession 缺参返回 RouteErrorPage

**触发**: 通过 `pushNamed(RouteNames.dictationSession)` 进入且无 args → RouteErrorPage。

**根因**: 同上。`words` 列表为空时页面白屏。

**正常 flow**: `lib_select_page.dart` 通过 `MaterialPageRoute` 直接 push，安全。

**严重度**: **P1** — pushNamed 深链场景失败。

---

### P1-4: `learning_routes.dart:100` — quickSpell 缺参返回 RouteErrorPage

**触发**: 通过 `pushNamed(RouteNames.quickSpell)` 进入且无 args → RouteErrorPage。

**根因**: 同上。

**正常 flow**: `lib_select_page.dart` 通过 `MaterialPageRoute` 直接 push，安全。

**严重度**: **P1** — pushNamed 深链场景失败。

---

## P2 — 特定条件失败

### P2-1: `content_routes.dart:27` — WordDetailPage() 无 arguments 进入时白屏

**触发**: 通过 `pushNamed(RouteNames.wordDetail)` 进入且无 args → `WordDetailPage` 构造无参。

**根因**: `WordDetailPage` 在 `initState` 中通过 `ModalRoute.of(context)?.settings.arguments` 获取 `Word` 对象。无 args → `selectedWord` 为 null → `selectedWord!.word` → Null check 错误。

**正常 flow**: `book_words_page.dart:102` 传了 `arguments: word`，安全。

**严重度**: **P2** — 正常 flow 安全，但深链/恢复场景白屏。

---

### P2-2: `lib_select_page.dart:445-460` — _startSession 个性化词表为空时白屏

**触发**: 用户无已选词且无收藏/已学/已掌握/未学词 → 点「开始学习」→ `_startSession` → push `WordDetailPage(fromLearn: true)` → `LearningSessionState` 无 currentWord → 白屏。

**根因**: `_startSession` 先判断 SelectedWords，再 fallback 到 `LearningPaths.personalized()`，但不检查个性化结果是否为空。如果为空，`LearningSessionState.initialize()` 设置 `currentWord = null` → `_CurrentWordView` 渲染空。

**严重度**: **P2** — 新用户首次进入且无任何学习数据时触发。

---

### P2-3: 多个 session 完成后直接 `Navigator.pop(context)` — parent unmount 风险

**触发点**:
- `sentence_quiz_page.dart` → 最后一题完成 → `Navigator.pop(context)`
- `quick_spell_page.dart` → 最后一词完成 → `Navigator.pop(context)`
- `dictation_session_page.dart` → 最后一词完成 → `Navigator.pop(context)`
- `immersive_swipe_page.dart` → swipe 完成 → `Navigator.pop(context)`
- `word_machine_page.dart` → 会话完成 → `Navigator.pop(context)`

**根因**: pop 后如果 parent widget 已 unmount（如动画过渡中），调用 `Navigator.pop` 可能抛 `setState() called after dispose()` 或 `Looking up a deactivated widget's ancestor`。

**严重度**: **P2** — 极端 edge case（快速操作时触发），但 pop 本身通常安全。

---

## P3 — 潜在风险

### P3-1: `content_routes.dart:27` — WordDetailPage 路由无参数转换

**位置**: `content_routes.dart` → `case RouteNames.wordDetail: return const WordDetailPage();`

**说明**: 此路由直接构造无参 `WordDetailPage()`，没有任何参数解析。但 `WordDetailPage` 依赖 `ModalRoute.of(context)?.settings.arguments` 获取 `Word`。如果通过此路由进入，没有 arguments → P2-1 白屏。目前 `onGenerateRoute` 优先级高于 `routes:` 表，所以此路由定义实际上只在 deep link 时生效。

**严重度**: **P3** — 建议在此处添加参数解析（如 `_buildWordDetailPage(args)`），与 learning_routes 的风格一致。

---

### P3-2: `learning_routes.dart:106` — wordExport 缺参返回 RouteErrorPage

**位置**: `_buildWordExportPage(args)` 在 `map == null` 时返回 `RouteErrorPage`。

**说明**: `word_export_page.dart` 无 `pushNamed` 入口（仅通过 `MaterialPageRoute` push），所以此分支实际不可达。代码冗余但无害。

**严重度**: **P3** — 代码冗余，可考虑移除或加注释说明。

---

## 正常前进路径（审计通过）

以下路径经验证，前进逻辑正确、参数齐全、运行期依赖成立：

| # | 路径 | 触发 | 结果 |
|---|------|------|------|
| 1 | my_space → /settings | pushNamed + routeName | ✅ AccountRoutes 正确注册 |
| 2 | my_space → /more_settings | pushNamed + routeName | ✅ AccountRoutes 正确注册 |
| 3 | more_settings → /account-info | pushNamed + AccountInfoPage.routeName | ✅ AccountRoutes 正确注册 |
| 4 | more_settings → /feedback | pushNamed + FeedbackPage.routeName | ✅ AccountRoutes 返回 `FeedbackPage()` |
| 5 | more_settings → /redemption-center | pushNamed + RedemptionCenterPage.routeName | ✅ AccountRoutes 返回 `RedemptionCenterPage()` |
| 6 | book_words → /word-detail | pushNamed + arguments: word | ✅ BookRoutes 正确传参 |
| 7 | learn_page → WordDetailPage | push + RouteSettings(arguments) | ✅ 传了 arguments |
| 8 | learn_session → WordDetailPage | push + MaterialPageRoute | ✅ 传了 arguments |
| 9 | lib_select → learn_page | push + MaterialPageRoute(WordDetailPage) | ✅ 传了 arguments |
| 10 | lib_select → sentence_quiz | push + MaterialPageRoute | ✅ 无参构造安全 |
| 11 | lib_select → quick_spell | push + MaterialPageRoute(words, bookName) | ✅ 正确传参 |
| 12 | lib_select → dictation | push + MaterialPageRoute(words, bookName) | ✅ 正确传参 |
| 13 | lib_select → immersive_swipe | push + MaterialPageRoute | ✅ 无参构造安全 |
| 14 | lib_select → word_machine | push + MaterialPageRoute | ✅ 无参构造安全 |
| 15 | learn_session → sentence_quiz | push + MaterialPageRoute | ✅ 无参构造安全 |
| 16 | learn_session → quick_spell | push + MaterialPageRoute(words, bookName) | ✅ 正确传参 |
| 17 | learn_session → dictation | push + MaterialPageRoute(words, bookName) | ✅ 正确传参 |
| 18 | learn_session → immersive_swipe | push + MaterialPageRoute | ✅ 无参构造安全 |
| 19 | learn_session → word_machine | push + MaterialPageRoute | ✅ 无参构造安全 |
| 20 | extensive_model → listening_player | push + MaterialPageRoute(words, mode, bookName) | ✅ 正确传参 |
| 21 | extensive_model → dictation | push + MaterialPageRoute(words, bookName) | ✅ 正确传参 |
| 22 | extensive_model → quick_spell | push + MaterialPageRoute(words, bookName) | ✅ 正确传参 |

## 会话流程内部前进（审计通过）

| 页面 | "下一词"/"下一步" 机制 | 结果 |
|------|----------------------|------|
| learn_page | LearningSessionState.nextWord() → setState → 自动刷新 | ✅ 正确 |
| word_machine_page | LearningSessionState.nextWord() → setState → 自动刷新 | ✅ 正确 |
| sentence_quiz_page | currentIndex++ → setState → 自动加载下一题 | ✅ 正确 |
| quick_spell_page | currentIndex++ → setState → 自动加载下一词 | ✅ 正确 |
| dictation_session_page | currentIndex++ → setState → 自动加载下一词 | ✅ 正确 |
| immersive_swipe_page | swipe 手势 → currentIndex++ → 自动加载 | ✅ 正确 |
| spell_session_page | currentIndex++ → setState → 自动加载 | ✅ 正确 |

## 修复优先级建议

| 优先级 | 问题 | 修复方案 |
|--------|------|----------|
| **P1** | learning_routes 4 个 buildXxx 缺参 → RouteErrorPage | 正常 flow 全部通过 MaterialPageRoute 绕过路由表，安全。如需支持 deep link，添加参数校验 |
| **P2** | WordDetailPage 无 arguments 白屏 | 在 `initState` 中处理 `arguments == null` 情况，显示空状态页 |
| **P2** | 空词表 startSession 白屏 | push 前检查 `LearningSessionState.currentWord != null`，空则跳空状态页 |
| **P2** | session pop 后 parent unmount | pop 前检查 `mounted`（Flutter 内置） |
| **P3** | content_routes WordDetailPage 无参数解析 | 添加 `_buildWordDetailPage(args)` |
| **P3** | wordExport 不可达的 RouteErrorPage 分支 | 加注释说明或移除 |
