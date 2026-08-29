# ARCH-FIX-2 · B1 Feature Providers → Feature 薄适配 (Port 化)

> **任务**: 去除 feature 组合根对 `repositories/`、`data/` 遗留层的直连  
> **日期**: 2026-08-28  
> **涉及 features**: book, search, word_browse, quick_review  

---

## 改动策略

每个 feature 的 adapter 新增 `factory fromServiceLocator()` 工厂构造器，在 adapter 内部通过 `sl<T>()` 解析遗留依赖。Providers 组合根只需引用 adapter，不再 import 遗留层。

---

## 改动清单

### 适配器层 (6 个文件)

| 文件 | 改动 |
|------|------|
| `lib/features/book/data/repository_book_catalog_reader.dart` | +`factory fromServiceLocator()` + 显式注入构造器（positional） |
| `lib/features/search/data/repository_word_search_reader.dart` | 同上 |
| `lib/features/search/data/preferences_search_history_store.dart` | 同上 |
| `lib/features/word_browse/data/repository_word_notes_store.dart` | 同上 |
| `lib/features/word_browse/data/repository_sentence_favorites_store.dart` | 同上 |
| `lib/features/quick_review/data/repository_quick_review_word_reader.dart` | 同上 |

**统一模式**:
```dart
class RepositoryXxx implements XxxPort {
  factory RepositoryXxx.fromServiceLocator() =>
      RepositoryXxx._(sl<LegacyRepository>());
  RepositoryXxx._(this._repository);
  RepositoryXxx(LegacyRepository repository) : _repository = repository;
  final LegacyRepository _repository;
}
```

### 组合根层 (4 个文件)

| 文件 | Before | After |
|------|--------|-------|
| `book_feature_providers.dart` | `import 'repositories/book_repository.dart'; sl<BookRepository>()` | `import 'repository_book_catalog_reader.dart'; .fromServiceLocator()` |
| `search_feature_providers.dart` | `import 'word_repository.dart'; import 'app_preferences.dart'; sl<WordRepository>()` | `.fromServiceLocator()` |
| `word_browse_feature_providers.dart` | `import 'note_repository.dart'; import 'fav_repository.dart'; sl<NoteRepository>()` | `.fromServiceLocator()` |
| `quick_review_feature_providers.dart` | `import 'word_repository.dart'; sl<WordRepository>()` | `.fromServiceLocator()` |

**移除的遗留引用**:
- `repositories/book_repository.dart` (book providers)
- `repositories/word_repository.dart` (search + quick_review providers)
- `repositories/note_repository.dart` (word_browse providers)
- `repositories/fav_repository.dart` (word_browse providers)
- `data/app_preferences.dart` (search providers)
- `core/di/service_locator.dart` (所有 4 个 providers)

### 测试同步 (4 个文件)

| 文件 | 改动 |
|------|------|
| `test/features/book/data/repository_book_catalog_reader_test.dart` | `repository: repo` → positional `repo` |
| `test/features/word_browse/data/repository_word_browse_stores_test.dart` | 同上 (2 处) |
| `test/features/quick_review/data/repository_quick_review_word_reader_test.dart` | 同上 |
| `test/architecture/app_structure_test.dart` | `sl<...Repository>()` → adapter class name 断言 |

---

## 验证结果

| 检查项 | 结果 |
|--------|------|
| `dart analyze` 10 文件 | 0 issues ✅ |
| `flutter test` 全量 | **533/533 all green** ✅ |
| `import_guard_test.dart` | 0 违规 ✅ |

---

## 未改动确认

- ❌ 未触碰 `lib/core/**`、`lib/app/**`、`lib/theme/**`、`lib/tokens/**`
- ❌ 未触碰 `lib/features/learning/**` (B2 归 ARCH-FIX-3)
- ❌ 未触碰 `lib/features/settings/**`、`lib/features/account/**` (已由 ARCH-FIX-1 处理)
- ❌ 未 git commit/push
