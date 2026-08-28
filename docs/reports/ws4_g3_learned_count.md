# WS-4 G3.2: book 消费 LearningProgressReader 回填统计已学数

## 目标
让词书统计卡的「已学 X / 总量 Y」不再硬编码 0，改为读取 learning 模块提供的真实已学数。

## 前置依赖
- G3.1（learning 侧实现 LearningProgressReader）已完成并提交推送（28df1f6）
- 核心契约：`lib/core/learning/learning_progress_reader.dart`

## 改动范围

### 1. `lib/features/book/presentation/book_state.dart`
- 新增 import：`import '../../../core/learning/learning_progress_reader.dart'`
- 构造函数新增参数：`required LearningProgressReader progressReader`
- `loadWords()` 内调用 `progressReader.countLearnedWords()` 获取真实已学数：
```dart
final learned = await _progressReader.countLearnedWords(_words.map((w) => w.word));
_statistics = BookStatistics(
  totalWords: _currentBook?.wordCount ?? _words.length,
  learnedWords: learned,
);
```

### 2. `lib/features/book/presentation/book_feature_providers.dart`
- 新增 import：`import '../../../core/learning/learning_progress_reader.dart'`
- `buildBookStateScope` 中传入 `progressReader: context.read<LearningProgressReader>()`

### 3. 测试辅助
新建 `test/features/book/test_helpers/fake_learning_progress_reader.dart`：
```dart
class FakeLearningProgressReader implements LearningProgressReader {
  FakeLearningProgressReader({this.learnedCount = 0});
  int learnedCount;
  @override
  Future<int> countLearnedWords(Iterable<String> wordTexts) async => learnedCount;
}
```

### 4. 更新 4 个测试文件
- `book_state_test.dart` - 注入 `FakeLearningProgressReader(learnedCount: 42)`，新增测试断言 `statistics!.learnedWords == 42`
- `book_words_page_test.dart` - 注入 `FakeLearningProgressReader()`
- `book_words_page_navigation_test.dart` - 注入 `FakeLearningProgressReader(learnedCount: 1)`
- `books_page_test.dart` - 注入 `FakeLearningProgressReader()`

## 测试结果
- ✅ 新增测试：1 个（验证 learnedWords 从 progressReader 获取）
- ✅ 全量测试：381/381 通过

## 架构说明
- book 仅依赖 core 契约（`LearningProgressReader`），不 import learning 内部
- Provider 树中 book scope 嵌套于 learning scope 之下，`context.read<LearningProgressReader>()` 向上命中 learning scope 的 Provider
