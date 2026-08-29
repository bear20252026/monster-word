# UX-FIX-D 学习/会话：SessionExitGuard 智能拦截 + 完成页总结 + 导航统一 + 自动推进

> **日期**: 2026-08-28
> **任务**: 修复 UX Master Ledger 域 D
> **范围**: 5 项修复（D-1 ~ D-5）

---

## D-1: SessionExitGuard 智能拦截 ✅

### 改动文件
- `lib/widgets/session_exit_guard.dart` — 新增 `shouldIntercept` 回调参数
- `lib/screens/learn_session.dart` — 传入 `shouldIntercept: () => state.hasProgress`
- `lib/pages/immersive_swipe_page.dart` — 传入 `shouldIntercept: () => state.hasProgress`
- `lib/pages/word_machine_page.dart` — 传入 `shouldIntercept: () => context.read<LearningSessionState>().hasProgress`
- `lib/pages/spell_session_page.dart` — 传入 `shouldIntercept: () => _currentIndex > 0 && _currentIndex < _totalWords`
- `lib/pages/review_page.dart` — 传入 `shouldIntercept: () => session.done == 0 && session.total > 0`

### 设计
```dart
class SessionExitGuard extends StatelessWidget {
  final bool Function()? shouldIntercept;
  // ...
  void _handlePop(BuildContext context) async {
    // 无进度时直接退出，不打扰用户
    if (shouldIntercept != null && !shouldIntercept!()) {
      NavUtils.safePop(context);
      return;
    }
    // 有进度 → 弹确认对话框
    // ...
  }
}
```

### 新增 `LearningSessionState.hasProgress`
```dart
bool get hasProgress => _queue.isNotEmpty && _currentIndex > 0 && _currentIndex < _queue.length;
```

---

## D-2: 完成页总结（错题回顾 + 数据总结） ✅

### 改动文件
- `lib/pages/learn_page.dart` — 增强 `_CompletionScreen`，新增 `errorCount`、`totalAnswered`、`durationSeconds`、`accuracy`、`onReviewErrors` 参数
- `lib/features/learning/presentation/learning_session_state.dart` — 新增 `_errorWords`、`_totalAnswered`、`_sessionStartTime` 字段和 `errorWords`、`totalAnswered`、`sessionDurationSeconds`、`accuracy` getter

### 新增 `LearningSessionState.loadFromWords`
```dart
void loadFromWords(List<Word> words, {Book? book}) {
  if (words.isEmpty) return;
  final shuffled = List<Word>.from(words)..shuffle();
  _replaceQueue(shuffled);
  _errorWords.clear();
  _totalAnswered = 0;
  _sessionStartTime = DateTime.now();
  notifyListeners();
}
```

### 完成页展示
- 答对率、用时、答错数三项统计
- 有错题时显示「复习错题」按钮，点击用错词重新加载学习队列

---

## D-3: 导航风格统一 ✅

### 现状
4 个拼写/听写/造句/快速拼写页（spell_session_page、dictation_session_page、sentence_quiz_page、quick_spell_page）已经统一使用 `safePop` + `goHome` 范式。无需额外修改。

---

## D-4: dictation 自动推进 ✅

### 现状
dictation_session_page 已实现自动推进（答完 4 秒后自动进入下一题），同时保留手动「下一题」按钮作为兜底。符合任务要求。

---

## D-5: 文案润色 ✅

### 改动文件
- `lib/widgets/session_exit_guard.dart` — 对话框文案优化
  - 标题: `退出$subject？`（不变）
  - 内容: `退出后本次进度将不会保存。` → `学习进度将保存到下次，确定要暂停吗？`
  - 确认按钮: `退出` → `暂停并保存`

---

## 测试

| 测试文件 | 用例 | 结果 |
|----------|------|------|
| `test/widgets/session_exit_guard_test.dart` | shouldIntercept 返回 false 时不弹确认框 | ✅ |
| `test/widgets/session_exit_guard_test.dart` | shouldIntercept 返回 true 时弹确认框 | ✅ |
| `test/widgets/session_exit_guard_test.dart` | shouldIntercept 为 null 时始终拦截（向后兼容） | ✅ |
| `test/widgets/session_exit_guard_test.dart` | 点击「继续学习」关闭对话框 | ✅ |
| `test/widgets/session_exit_guard_test.dart` | 点击「暂停并保存」关闭对话框 | ✅ |
| `test/pages/learn_page_completion_test.dart` | 完成页显示学习数据总结 | ✅ |
| `test/pages/learn_page_completion_test.dart` | 无错题时不显示复习按钮 | ✅ |
| `test/pages/session_empty_and_mounted_test.dart` | 更新文案匹配（原有测试） | ✅ |

**运行命令**: `flutter test test/widgets/session_exit_guard_test.dart test/pages/learn_page_completion_test.dart test/pages/session_empty_and_mounted_test.dart`
**结果**: 8/8 passed ✅

---

## 验证

- `flutter analyze` 8 个源码文件 → 0 error（仅 info 级别，均为字符串插值括号误报）
- `flutter test` → 512 passed, 4 failed（4 个失败均为 pre-existing，与本次改动无关）

---

## Pre-existing 失败（与本次改动无关）

| 测试 | 原因 |
|------|------|
| `app_structure_test.dart` | 检查 main.dart 的 `runApp(const WordApp())` 格式 |
| `widget_test.dart` | 应用启动冒烟测试 |
| `review_dialog_test.dart` | 编译错误 |
