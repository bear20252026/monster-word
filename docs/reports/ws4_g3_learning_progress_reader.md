# [WS-4 G3.1] LearningProgressReader 共享契约实现报告

**日期**: 2026-08-28
**目标**: 在 learning 模块实现 `LearningProgressReader` 契约并在 learning feature scope 暴露

## 完成内容

### 1. 实现类

**`lib/features/learning/data/learning_progress_reader_impl.dart`**（新建）

- 实现 `LearningProgressReader`（`lib/core/learning/learning_progress_reader.dart`，lead 创建的抽象接口）
- 构造器接收 `MasteredRepository`，通过 `getMasteredWords()` 获取全局已掌握词集
- `countLearnedWords(wordTexts)` = `wordTexts.where(masteredWords.contains).length`
- 使用 `required this._masteredRepository` 模式（满足 `prefer_initializing_formals`）

### 2. Provider 装配

**`lib/features/learning/presentation/learning_feature_providers.dart`**（修改）

- 新增 `Provider<LearningProgressReader>.value(value: LearningProgressReaderImpl(masteredRepository: sl<MasteredRepository>()))`
- `MasteredRepository` 通过 `sl<MasteredRepository>()` 注入（与同文件其他 reader 一致）
- 与既有的 `BookWordsReader`、`MasteredWordsReader` 等 Provider 并列

### 3. 测试

**`test/features/learning/data/learning_progress_reader_impl_test.dart`**（新建，5 项）

| 测试 | 验证 |
|------|------|
| countLearnedWords 对交集计数正确 | mastered={apple,banana,cherry,dog,elephant}，输入={apple,banana,cat,dog,fish} → 3 |
| 空词集返回 0 | 输入=[] → 0 |
| 全部已掌握时返回词集总数 | 输入={apple,banana,cherry} → 3 |
| 无交集时返回 0 | 输入={fox,grape,hat} → 0 |
| 空 mastered 词集时返回 0 | mastered={}，输入={apple,banana} → 0 |

## 依赖方向

```
lib/core/learning/learning_progress_reader.dart  (lead 创建的抽象接口)
         ↑ implements
lib/features/learning/data/learning_progress_reader_impl.dart  (本任务创建)
         ↑ depends on
lib/repositories/mastered_repository.dart  (获取全局已掌握词集)
         ↑ injected via
lib/features/learning/presentation/learning_feature_providers.dart  (Provider 暴露)
         ↑ consumed by
lib/features/book/** (后续卡 WS-4 G3)
```

## 验证

| 检查项 | 结果 |
|--------|------|
| `dart analyze learning_progress_reader_impl.dart` | No issues found! |
| `dart analyze learning_feature_providers.dart` | No issues found! |
| `dart analyze learning_progress_reader_impl_test.dart` | No issues found! |
| `flutter test` (全量) | **380 passed, 0 failed** |
| 新测试 | 5/5 全绿 |
