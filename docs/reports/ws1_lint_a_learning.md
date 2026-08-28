# WS-1 Lint A — cleanup lib/features/learning/**

## 任务

修复 `lib/features/learning/**` 下所有 lint 问题：prefer_initializing_formals (~20)、unused_import x2、use_null_aware_elements x1。

## 变更文件

| 文件 | 修复类型 |
|------|----------|
| `application/review_audio_player.dart` | prefer_initializing_formals |
| `application/review_rating_writer.dart` | prefer_initializing_formals |
| `application/review_session_rating_executor.dart` | prefer_initializing_formals |
| `application/review_session_starter.dart` | prefer_initializing_formals |
| `data/learning_queue_repository.dart` | prefer_initializing_formals x2 |
| `data/repository_book_words_reader.dart` | prefer_initializing_formals |
| `data/repository_mastered_words_reader.dart` | prefer_initializing_formals |
| `data/repository_new_words_reader.dart` | unused_import + use_null_aware_elements |
| `data/repository_review_queue_reader.dart` | prefer_initializing_formals |
| `data/repository_review_schedule_reader.dart` | prefer_initializing_formals |
| `presentation/learning_favorites_state.dart` | prefer_initializing_formals |
| `presentation/learning_mastered_state.dart` | prefer_initializing_formals |
| `presentation/learning_queue_state.dart` | unused_import (dart:collection) |
| `presentation/learning_session_state.dart` | prefer_initializing_formals |
| `presentation/new_words_state.dart` | prefer_initializing_formals |
| `presentation/review_audio_state.dart` | prefer_initializing_formals |
| `presentation/review_session_answer_state.dart` | prefer_initializing_formals |
| `presentation/review_session_state.dart` | prefer_initializing_formals |
| `presentation/review_word_action_coordinator.dart` | prefer_initializing_formals |
| `presentation/review_word_actions_state.dart` | prefer_initializing_formals |

## 修复方式

### prefer_initializing_formals（19 处）

统一改为 `this._x` 形式：

```dart
// Before
Foo({required Bar bar}) : _bar = bar;

// After
Foo({required this._bar});
```

注意：构造函数体内有额外逻辑（如 `unawaited(...)` / `_repository.addListener(...)`）时，仅改参数形式、保留 body。

### unused_import（2 处）

- `repository_new_words_reader.dart`：移除 `import '../../../models/new_word_record.dart';`
- `learning_queue_state.dart`：移除 `import 'dart:collection';`

### use_null_aware_elements（1 处）

```dart
// Before
return [
  for (final record in records)
    if (wordsById[record.wordId] case final word?) word,
];

// After
return [
  for (final record in records)
    wordsById[record.wordId],
].whereType<Word>().toList();
```

## 验证

```
flutter analyze lib/features/learning/
No issues found! (ran in 14.4s)

flutter test test/features/learning/ --no-pub
00:10 +70: All tests passed!
```

全量 `flutter test` 因既有问题失败（SQLite 下载超时、WCAG contrast、appearance_page.dart 编译错误），与本次 lint 无关。

## 三件套检查

- [x] `flutter analyze lib/features/learning/` → 0 issues
- [x] `flutter test test/features/learning/` → 70/70 passed
- [x] 报告：`docs/reports/ws1_lint_a_learning.md`
