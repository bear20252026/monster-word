# XP-FIX-4 词书/书库域：DB 健壮性 + getBooks try-catch + fromMap/状态降级 + 路由常量

> **日期**: 2026-08-28
> **任务**: 修复 XP 全盘体检·域4 词书/书库域的 P1/P2/P3
> **范围**: 5 个文件（严格限定）

---

## 改动文件

### 1. `lib/data/wordbook_database.dart` — db getter 健壮性

**改动**:
- 新增 `bool get isInitialized => _initialized && _db != null;` 公开 getter
- 调用方可先检查 `isInitialized` 再访问 `db`，避免 StateError

**原因**: 原 `db` getter 在 `_db == null` 时抛 `StateError`，而 `StateError` 不是 `Exception`，无法被 `catch (e)` 捕获。新增 `isInitialized` 提供安全前置检查。

### 2. `lib/repositories/book_repository_impl.dart` — getBooks/getWordCount try-catch

**改动**:
- `getBooks()`: 添加 `isInitialized` 前置检查 + try-catch，异常时返回空列表并 `debugPrint`
- `getWordCount()`: 添加 `isInitialized` 前置检查 + try-catch，异常时返回 0 并 `debugPrint`
- 新增 `import 'package:flutter/foundation.dart';`（用于 `debugPrint`）

**原因**: SQL 异常（表不存在、列名错误、数据库损坏）不再穿透到 UI，由上层兜底。

### 3. `lib/models/book.dart` — fromMap word_count 降级

**改动**:
- `fromMap` 尝试多种列名：`word_count` → `wordCount` → `total_words`
- 所有列都缺失时降级为 0（不再静默 0，而是明确处理）

**原因**: 不同 schema 版本可能使用不同列名，多列名兼容避免数据丢失。

### 4. `lib/features/book/presentation/book_state.dart` — 状态降级

**改动**:
- `loadWords()`: catch 块新增 `_error = e.toString()` 向 UI 反馈
- `totalWords`: 改为 `(_currentBook?.wordCount ?? 0) > 0 ? _currentBook!.wordCount : _words.length`，优先使用词书自身 wordCount
- `load()`: 新增兜底逻辑，若当前词书不在列表中则清除无效 ID

**原因**: 避免静默失败、误导性统计数据、无效状态残留。

### 5. `lib/features/book/presentation/books_page.dart` — 路由常量

**改动**:
- `'/lib-select'` → `RouteNames.libSelect`
- 新增 `import '../../../core/router/route_names.dart';`

**原因**: 避免路由名变更时字面量失效的维护风险。

---

## 测试

| 测试文件 | 测试用例 | 结果 |
|----------|----------|------|
| `test/features/book/presentation/book_state_test.dart` | loadWords 失败时设置 error 反馈 | ✅ |
| `test/features/book/presentation/book_state_test.dart` | totalWords 优先使用词书 wordCount | ✅ |
| `test/features/book/presentation/book_state_test.dart` | load 时当前词书不在列表中则清除无效 ID | ✅ |
| `test/models/book_frommap_test.dart` | 标准 word_count 列名解析 | ✅ |
| `test/models/book_frommap_test.dart` | word_count 缺失时尝试 wordCount | ✅ |
| `test/models/book_frommap_test.dart` | word_count/wordCount 都缺失时尝试 total_words | ✅ |
| `test/models/book_frommap_test.dart` | 所有列都缺失时降级为 0 | ✅ |
| `test/models/book_frommap_test.dart` | 空 Map 时使用默认值 | ✅ |
| `test/data/wordbook_database_test.dart` | isInitialized 可通过 instance 访问 | ✅ |
| `test/data/wordbook_database_test.dart` | isInitialized 为 false 时可安全跳过 | ✅ |

**运行命令**: `flutter test test/features/book/presentation/book_state_test.dart test/models/book_frommap_test.dart test/data/wordbook_database_test.dart`
**结果**: 16/16 passed ✅

---

## 验证

- `flutter analyze` 8 个文件（5 源码 + 3 测试）→ No issues found!

---

## 未修复项

- **P0 路由名不匹配** (`/book-words` vs `/book_words`): 已由 lead 修复（route_names.dart），不在本任务范围
