# [XP AUD-2] 全盘体检：学习/复习/会话流程域

## 审计范围

学习/复习/会话全链路：`LearningSessionState`、`ReviewSessionState`、`LearningQueueState`、`ReviewQueueState`、`SessionExitGuard`、`LibSelectPage` 会话启动、`LearnPage`、`ReviewPage`、`WordMachinePage`、`DictationSessionPage`、`SpellSessionPage`、`SentenceQuizPage`、`QuickSpellPage`、`ListeningPlayerPage`、`ImmersiveSwipePage`。

## 发现汇总

| 级别 | 数量 | 说明 |
|------|------|------|
| P0 | 1 | 会话状态机空索引越界 |
| P1 | 5 | async 后无 mounted 守卫、退出会话 Navigator.pop 无安全守卫 |
| P2 | 6 | setState after dispose 风险、空词表未优雅降级 |
| P3 | 4 | 代码一致性、冗余逻辑 |

---

## P0 — 致命崩溃

### P0-1: `LearningSessionState.rate()` 异步空索引越界
- **文件**: `lib/features/learning/presentation/learning_session_state.dart:94-117`
- **现象**: `rate()` 是 `async` 方法，`await _reviewSchedule.rateWord()` 后 `_currentIndex++`。但 `next()` 是同步的，可能在 `rate()` 的 await 间隙被调用，导致 `_currentIndex` 双重推进或越界。更关键的是，`rate()` 在 `await` 后调用 `_regenerateChoices()` → `ChoiceGenerator.generate()` 可能在队列为空时触发索引问题。
- **根因**: `rate()` 是 async 但无防重入守卫，用户快速连点可在 await 间隙触发第二次调用。
- **修复建议**: 在 `rate()` 中添加 `_isRating` 布尔守卫或改为同步评分 + 后台 flush。

---

## P1 — 高风险运行时问题

### P1-1: `LearnPage` 退出按钮未用 `NavUtils.safePop`
- **文件**: `lib/pages/learn_page.dart:137`（顶部返回按钮）、`lib/pages/learn_page.dart:256`（底部退出按钮）
- **现象**: 使用 `Navigator.pop(context)` 而非 `NavUtils.safePop(context)`。虽然 Task APP-2 已修复 4 个核心页面，但 learn_page 的这两处未被覆盖。
- **根因**: 遗漏范围。
- **修复**: 改为 `NavUtils.safePop(context)`。

### P1-2: `ReviewPage` 退出按钮未用 `NavUtils.safePop`
- **文件**: `lib/pages/review_page.dart:89`（顶部返回按钮）
- **现象**: 使用 `Navigator.pop(context)`，同 P1-1。
- **根因**: 同 P1-1 遗漏。
- **修复**: 改为 `NavUtils.safePop(context)`。

### P1-3: `LearningSessionState.rate()` await 后 notifyListeners 无 mounted 检查
- **文件**: `lib/features/learning/presentation/learning_session_state.dart:109-116`
- **现象**: `rate()` 是 async，在 `await _reviewSchedule.rateWord()` 之后调用 `_regenerateChoices()` 和 `notifyListeners()`。如果用户在 await 期间退出页面（触发 dispose），`notifyListeners()` 会抛 `FlutterError (A ChangeNotifier was used after being disposed)`。
- **根因**: ChangeNotifier 没有 `mounted` 属性，无法直接检查。但 Provider 的 `ChangeNotifierProvider` 会在 widget 被移除时调用 `dispose()`，而 await 可能在 dispose 之后完成。
- **修复**: 在 `rate()` 中捕获 disposed 后的 `notifyListeners()` 异常，或使用 `_disposed` 布尔标记。

### P1-4: `DictationSessionPage._checkAnswer()` / `_nextWord()` 异步操作后无 mounted 守卫
- **文件**: `lib/pages/dictation_session_page.dart`
- **现象**: `initState` 中调用 `_loadWords()` 异步方法，在 Future 完成后调用 `setState()`。如果用户在加载期间退出页面，`setState` 会在 unmounted widget 上触发。
- **根因**: 异步回调后未检查 `mounted`。
- **修复**: 在 `setState` 前添加 `if (!mounted) return;` 守卫。

### P1-5: `QuickSpellPage._loadWords()` 异步操作后无 mounted 守卫
- **文件**: `lib/pages/quick_spell_page.dart`
- **现象**: 同 P1-4，`initState` 中异步加载完成后直接 `setState()`。
- **根因**: 同 P1-4。
- **修复**: 在 `setState` 前添加 `if (!mounted) return;` 守卫。

---

## P2 — 中风险 / 体验缺陷

### P2-1: `SpellSessionPage` 空词表无优雅降级
- **文件**: `lib/pages/spell_session_page.dart`
- **现象**: 如果传入的单词列表为空，页面可能直接显示空白或无法交互。未看到空列表检查 + 友好提示的空态页。
- **根因**: 未做空列表入参守卫。
- **修复**: 在 initState 中检查 `widget.words.isEmpty`，显示"暂无待复习单词"空态页。

### P2-2: `SentenceQuizPage` 空词表无优雅降级
- **文件**: `lib/pages/sentence_quiz_page.dart`
- **现象**: 同 P2-1，传入空单词列表时无友好降级。
- **修复**: 同 P2-1。

### P2-3: `DictationSessionPage` 空词表无优雅降级
- **文件**: `lib/pages/dictation_session_page.dart`
- **现象**: 同 P2-1。
- **修复**: 同 P2-1。

### P2-4: `QuickSpellPage` 空词表无优雅降级
- **文件**: `lib/pages/quick_spell_page.dart`
- **现象**: 同 P2-1。
- **修复**: 同 P2-1。

### P2-5: `LearningSessionState._loadProgress()` 初始加载与新会话竞态
- **文件**: `lib/features/learning/presentation/learning_session_state.dart:160-171`
- **现象**: 构造函数调用 `unawaited(_loadProgress())`。如果用户在构造后立即调用 `loadBook()`（触发 `_replaceQueue` → `_queueGeneration++`），`_loadProgress()` 回来时 generation 已变，过期进度被丢弃——这是正确的。但 `_loadProgress()` 读取 `_queue.length` 时 `_queue` 可能为空（构造后尚未 loadBook），`clamp(0, _queue.length - 1)` 在空列表时 `_queue.length - 1 = -1`，`clamp(0, -1)` 返回 0，不会崩溃但语义不准确。
- **根因**: 空列表 clamp 边界未处理。
- **修复**: 在 `_loadProgress()` 中添加 `if (_queue.isEmpty) return;`。

### P2-6: `SessionExitGuard` 在 `dispose` 时弹出 WillPopScope 但无法保证用户已完成确认
- **文件**: `lib/widgets/session_exit_guard.dart`
- **现象**: 使用 `WillPopScope`（Flutter 已废弃，应迁移到 `PopScope`）。虽然功能正常，但 Flutter 3.x 已标记 `WillPopScope` 为 deprecated。
- **根因**: 未迁移至 `PopScope`。
- **修复**: 将 `WillPopScope` 替换为 `PopScope`。

---

## P3 — 代码质量 / 一致性

### P3-1: `LearnPage`/`ReviewPage` 未对齐 APP-2 导航安全化
- **文件**: `lib/pages/learn_page.dart:137,256`、`lib/pages/review_page.dart:89`
- **现象**: APP-2 任务已将 `word_detail_page`、`word_machine_page`、`listening_player_page`、`immersive_swipe_page` 的 `Navigator.pop` 统一为 `NavUtils.safePop`/`goHome`，但 `learn_page` 和 `review_page` 仍使用原始 `Navigator.pop`。
- **修复**: 统一迁移。

### P3-2: `SessionExitGuard` 使用废弃的 `WillPopScope`
- **文件**: `lib/widgets/session_exit_guard.dart:28`
- **现象**: `WillPopScope` 已废弃，Flutter 推荐 `PopScope`。
- **修复**: 迁移至 `PopScope`。

### P3-3: `LearningSessionState._loadProgress()` 构造即 fire-and-forget 异步
- **文件**: `lib/features/learning/presentation/learning_session_state.dart:28`
- **现象**: `unawaited(_loadProgress())` 在构造函数中 fire-and-forget，错误仅 debugPrint 不传播。UI 可能在进度加载完成前渲染空白索引 0。
- **修复**: 可接受（已经是防御式），但建议在 `_loadProgress` 完成后 `notifyListeners()` 一次以刷新 UI。

### P3-4: `ReviewSessionState.initialize()` 中 `_engine.totalNum` 延迟赋值
- **文件**: `lib/features/learning/presentation/review_session_state.dart:74`
- **现象**: `_total = _engine.totalNum` 在 `init` 完成后赋值，但 `total` getter 在加载期间返回 0，可能让进度条短暂显示 0/0。
- **修复**: 加载阶段可用 `isLoading` 守卫 UI 展示。

---

## 10 维检查点覆盖

| # | 维度 | 状态 | 关键发现 |
|---|------|------|----------|
| 1 | 会话索引推进 | ⚠️ | P0-1: rate() async 竞态 |
| 2 | 完成回跳 | ✅ | 已有 isComplete 检查 + 导航 |
| 3 | 进度竞态 | ⚠️ | P2-5: 空列表 clamp |
| 4 | currentWord null | ✅ | 所有页面均有 null 检查 |
| 5 | 返回黑屏 | ⚠️ | P1-1/P1-2: learn/review 未迁移 safePop |
| 6 | 逐级回首页 | ✅ | dictation/word_machine/immersive 已用 goHome |
| 7 | 空词表降级 | ⚠️ | P2-1~P2-4: 4 个会话页缺空态 |
| 8 | provider 齐全 | ✅ | LearningFeatureProviders 覆盖完整 |
| 9 | setState after dispose | ⚠️ | P1-3~P1-5: async 后无 mounted |
| 10 | ModalRoute.of | ✅ | 仅 word_detail 使用，已有 null 守卫 |

---

## 修复优先级建议

| 优先级 | 任务 | 工作量 |
|--------|------|--------|
| 立即 | P0-1 rate() 竞态守卫 | 小 |
| 立即 | P1-1/P1-2 learn/review safePop 迁移 | 小 |
| 立即 | P1-3~P1-5 async mounted 守卫 | 中 |
| 高 | P2-1~P2-4 空词表降级 x4 | 中 |
| 中 | P2-6 WillPopScope → PopScope | 中 |
| 低 | P3-1~P3-4 一致性 | 小 |
