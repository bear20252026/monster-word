# WS-4 G2 — BookWordsPage 开始学习 FAB

## 任务

在 `BookWordsPage` 添加"开始学习"悬浮按钮，调用 `LearningSessionState.loadBook(book, limit: 50)` 后导航到 `/immersive_swipe`。

## 变更文件

| 文件 | 变更 |
|------|------|
| `lib/features/book/presentation/book_words_page.dart` | 新增 import + `_startLearning` 方法 + FAB |
| `test/features/book/presentation/book_words_page_fab_test.dart` | 新增 widget 测试（2 个用例） |

## 代码变更

### 1. import（book_words_page.dart）

```dart
import '../../../features/learning/presentation/learning_session_state.dart';
```

### 2. `_startLearning` 方法

```dart
Future<void> _startLearning(BuildContext context) async {
  final session = context.read<LearningSessionState>();
  await session.loadBook(book, limit: 50);
  if (!context.mounted) return;
  Navigator.pushNamed(context, '/immersive_swipe');
}
```

### 3. Scaffold FAB

```dart
floatingActionButton: FloatingActionButton.extended(
  onPressed: () => _startLearning(context),
  icon: const Icon(Icons.play_arrow),
  label: const Text('开始学习'),
),
```

## 设计要点

- **Provider 嵌套复用**：book scope 嵌套在 learning scope 下，`context.read<LearningSessionState>()` 在 book 页面内可用，无需新增依赖。
- **context.mounted 防护**：`await` 后检查 `context.mounted`，避免异步间隙的 `BuildContext` 失效。
- **limit: 50**：与 `LearningQueueRepository.loadBook` 默认 `limit = 50` 一致，保证单次学习加载完整词书词表。

## 测试

### 测试策略

`LearningSessionState` 是 concrete class，构造时会调用 `_loadProgress()`（使用 SharedPreferences）。测试中：
- 使用 `SharedPreferences.setMockInitialValues({})` 初始化
- 创建 `SpyLearningSessionState` 继承并重写 `loadBook`，记录调用参数，不执行真实队列/进度副作用

### 用例

| 用例 | 验证点 |
|------|--------|
| renders 开始学习 FAB | `FloatingActionButton` + 文案 `开始学习` 渲染 |
| tapping FAB calls loadBook(book, limit: 50) and navigates to /immersive_swipe | `loadBookCallCount == 1`、`loadedBook == testBook`、`loadedLimit == 50`、`navigatedRoute == '/immersive_swipe'` |

### 运行结果

```
flutter test test/features/book/presentation/book_words_page_fab_test.dart
00:00 +2: All tests passed!

flutter test  # 全量
00:20 +383: All tests passed!
```

## 三件套检查

- [x] `flutter analyze` 0 error，本文件无新增 warning/info
- [x] `flutter test` 全量通过（381 → 383，新增 2 个用例，无回归）
- [x] 代码 + 测试 + 报告齐全
