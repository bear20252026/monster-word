# 背单词流程域功能核查报告

**审查人**: QA-背单词  
**日期**: 2026-08-29  
**范围**: `lib/features/learning/**`、`lib/pages/learn_page.dart`、相关 Provider 与状态  
**目标**: 定位「背单词时无法跳转到下一个单词」的根因

---

## 问题 1（Critical）：LearnPage 答对后缺少「下一词」触发机制

### 问题描述

在 `/learn` 页面（`LearnPage`）中，用户答对单词后，界面显示绿色确认态 + 弹跳动画 + 彩带庆祝，但**不会自动跳转到下一个单词**，也**没有提供任何按钮让用户前进**。用户被永久卡在当前单词。

### 文件与行号

- `lib/pages/learn_page.dart:431-451` — `_QuizAreaState._onChoice()` 方法

### 根因分析

`_onChoice()` 在用户答对时（`isCorrect == true`）的处理逻辑：

```dart
// learn_page.dart:435-446
if (isCorrect) {
  setState(() {
    _correctIndex = i;
    _wrongIndex = -1;
  });
  _bounceController.forward(from: 0);
  _checkController.forward(from: 0);
  _confettiController.play();
  // 不自动跳转，等用户点击"查看详解"按钮   ← 注释说明了设计意图
}
```

**问题核心**：代码注释明确写着「等用户点击"查看详解"按钮」，但整个 `_QuizArea` 和 `_LearnPageState` 中**不存在这个按钮**。设计意图中的跳转路径（答对 → 查看详解 → 字典详情页 → 下一词）在实现时被遗漏了。

对比同一项目中其他学习页面的正确实现：

| 页面 | 答对后的处理 | 是否正常跳转 |
|------|-------------|-------------|
| `word_machine_page.dart:122-134` | `state.rate(FsrsRating.good)` → 800ms 后 `_nextWord()` | 正常 |
| `immersive_swipe_page.dart:62-69` | `state.rate(FsrsRating.good)` | 正常 |
| `review_page.dart` (ReviewSessionState) | `selectChoice()` → `rate(RecallRating.good)` | 正常 |
| **`learn_page.dart`** | 仅设置 `_correctIndex`，**不调用 rate/next** | **卡死** |

### 唯一的变通路径

用户可以通过顶部弹出菜单的「跳过当前单词」选项前进，但该选项调用的是 `state.rate(FsrsRating.again)`（`learn_page.dart:176`），语义上将答对的单词标记为「again」（不会），这是错误的评分。

### 建议修复

在 `_QuizAreaState._onChoice()` 的 `isCorrect` 分支中，答对后应导航到 `WordDetailPage`（已存在，且有 `fromLearn: true` 参数支持「下一词」按钮）：

```dart
if (isCorrect) {
  setState(() {
    _correctIndex = i;
    _wrongIndex = -1;
  });
  _bounceController.forward(from: 0);
  _checkController.forward(from: 0);
  _confettiController.play();

  // 答对后延迟跳转到字典详情页
  Future.delayed(const Duration(milliseconds: 600), () {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WordDetailPage(word: widget.word, fromLearn: true),
      ),
    );
  });
}
```

或者，如果不想要详情页中间步骤，可以直接调用 `state.rate(FsrsRating.good)` 推进：

```dart
if (isCorrect) {
  // ... 动画 ...
  Future.delayed(const Duration(milliseconds: 800), () {
    if (!mounted) return;
    widget.state.rate(FsrsRating.good);
  });
}
```

---

## 问题 2（Medium）：`_loadProgress()` 异步竞态可能导致索引错位

### 问题描述

`LearningSessionState` 构造函数中通过 `unawaited(_loadProgress())` 异步加载上次保存的学习进度。如果用户启动新会话时，`_loadProgress()` 尚未完成，可能导致 `_currentIndex` 被旧进度覆盖。

### 文件与行号

- `lib/features/learning/presentation/learning_session_state.dart:28` — `unawaited(_loadProgress())`
- `lib/features/learning/presentation/learning_session_state.dart:153-162` — `_loadProgress()` 方法
- `lib/features/learning/presentation/learning_session_state.dart:172-174` — `_replaceQueue()` 重置 `_currentIndex = 0`

### 根因分析

时序问题：

1. `LearningSessionState()` 创建 → `unawaited(_loadProgress())` 开始异步读取 SharedPreferences
2. `loadBook()` 被调用 → `_replaceQueue()` 设置 `_currentIndex = 0` → `notifyListeners()`
3. `_loadProgress()` 完成 → `_currentIndex = saved.currentIndex`（可能 > 0）

虽然 `currentWord` 使用了 `_currentIndex.clamp(0, _queue.length - 1)` 防止越界崩溃，但如果旧进度的 `_currentIndex` 大于新队列长度，用户会看到最后一个单词而非第一个。

### 建议修复

在 `_replaceQueue()` 中增加一个标记，确保 `_loadProgress()` 完成后不再覆盖新会话的索引：

```dart
bool _progressLoaded = false;

Future<void> _loadProgress() async {
  try {
    final saved = await _progressRepository.load();
    if (saved != null && !_progressLoaded) {
      _currentIndex = saved.currentIndex;
      notifyListeners();
    }
  } catch (error) {
    debugPrint('Load progress error: $error');
  } finally {
    _progressLoaded = true;
  }
}

void _replaceQueue(List<Word> queue) {
  _queue = queue;
  _currentIndex = 0;
  _progressLoaded = true; // 新会话覆盖旧进度
  // ...
}
```

---

## 问题 3（Low）：`rate()` 到达末尾后无完成信号

### 问题描述

`LearningSessionState.rate()` 在 `_currentIndex` 到达队列末尾时，会将其 clamp 到 `_queue.length - 1`，但不触发任何「学习完成」信号。UI 层通过 `currentWord == null` 判断完成，但 `currentWord` 在末尾时仍返回最后一个单词。

### 文件与行号

- `lib/features/learning/presentation/learning_session_state.dart:88-110` — `rate()` 方法
- `lib/features/learning/presentation/learning_session_state.dart:52` — `currentWord` getter

### 根因分析

```dart
Future<void> rate(FsrsRating rating) async {
  // ...
  _currentIndex++;
  if (_currentIndex >= _queue.length) {
    _currentIndex = _queue.length - 1;  // clamp 到最后一个，不设 null
  }
  _regenerateChoices();
  notifyListeners();
}
```

而 `LearnPage` 通过 `word == null` 判断完成：

```dart
body: word == null
    ? _CompletionScreen(skin: skin)
    : SafeArea(child: ...)
```

由于 `rate()` 永远不会将 `_queue` 清空或设置 `_currentIndex` 越界，`currentWord` 永远不为 null，完成页面永远不会显示。

### 建议修复

在 `rate()` 中，当 `_currentIndex >= _queue.length` 时清空队列或设置完成标记：

```dart
_currentIndex++;
if (_currentIndex >= _queue.length) {
  _currentBook = null;
  _queue = [];
  _currentIndex = 0;
  _choices = [];
  notifyListeners();
  return;
}
```

或者在 `_QuizArea` 中检查 `state.hasMoreWords` 来显示完成态。

---

## 问题 4（Info）：Provider 注入链完整，无缺失

### 检查结果

经核查 `learning_feature_providers.dart` 中的 Provider 装配：

| Provider | 类型 | 状态 |
|----------|------|------|
| `LearningSessionState` | `ChangeNotifierProvider` | 正常 |
| `LearningSessionStarter` | `ProxyProvider<LearningSessionState, LearningSessionStarter>` | 正常，持有 session 实例 |
| `LearningQueueState` | `ChangeNotifierProxyProvider<LearningSessionState, ...>` | 正常，`synchronizeFrom` 在 session 变化时触发 |
| `LearningFavoritesState` → `LearningFavoritesStore` | `ListenableProxyProvider` | 正常 |

- `ProxyProvider` 顺序正确（`LearningSessionState` 先于 `LearningSessionStarter` 和 `LearningQueueState`）
- `ListenableProxyProvider` 的 `update` 回调正确转发了状态实例
- 不存在 proxy 未提供或 Read/ProxyProvider 顺序错误的问题

WS-3/WS-6 重构（`LearningSessionStarterImpl` 从 data 移到 presentation、Store 提到 core）**未破坏运行时注入**。

---

## 总结

| # | 严重度 | 问题 | 影响 |
|---|--------|------|------|
| 1 | **Critical** | `_onChoice()` 答对后不调用 `rate()`/`next()`，也无导航到详情页 | 用户答对后卡死，无法前进 |
| 2 | Medium | `_loadProgress()` 异步竞态可能覆盖新会话索引 | 新会话可能跳到错误的单词 |
| 3 | Low | `rate()` 到末尾无完成信号 | 完成页面可能不显示 |

**问题 1 是「背单词时无法跳转到下一个单词」的直接根因。**
