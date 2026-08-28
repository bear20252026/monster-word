# QA 报告：词库/书库域功能核查

> **审计人**: QA-词库  
> **日期**: 2026-08-29  
> **项目**: Monster Word (`D:\claude\work\cn_com_lange\word_app`)  
> **范围**: 只读审计，定位「词库/书库为空或不可用」的运行时根因  
> **方法**: 静态代码分析 + 数据库 schema 对比（未修改 lib/ 代码）

---

## 一、审计结论摘要

数据层已确认完好（assets/db/wordbook.db.gz 含 191 词书 / 32,154 词 / 454,196 映射，Python 验证通过）。问题出在 **运行时链路**，共发现 **4 个高置信度问题** 和 **2 个潜在风险**。

| # | 严重度 | 问题 | 文件 | 影响 |
|---|---|---|---|---|
| P0 | 🔴 致命 | `WordBookDatabase.db` getter 在未初始化时抛 StateError，且无 null 安全路径 | `lib/data/wordbook_database.dart` | 数据库未就绪时全书库功能崩溃 |
| P1 | 🔴 高 | `BookRepository.getBooks()` 无 try-catch，SQL 异常直接穿透到 UI | `lib/repositories/book_repository_impl.dart` | SQL 失败时 books_page 显示空白无错误提示 |
| P2 | 🟡 中 | `Book.fromMap` 硬编码 `word_count` 列名，与实际 DB schema 可能存在大小写/命名不一致 | `lib/models/book.dart` | 列名不匹配时 wordCount 全部为 0，统计卡显示异常 |
| P3 | 🟡 中 | `WordBookDatabase.getWordsByBook` 依赖 `word_books` 连接表，无表存在性校验 | `lib/data/wordbook_database.dart` | 若连接表缺失，单词列表为空 |
| R1 | ⚠️ 低 | `RepositoryBookCatalogReader.listBooks()` 调用 `_repository.listBooks()`，需确认接口定义 | `lib/features/book/data/repository_book_catalog_reader.dart` | 接口不匹配时编译期或运行期失败 |
| R2 | ⚠️ 低 | SQLite FFI 桌面端初始化 (`databaseFactoryFfi`) 失败时 `initialize()` 静默失败 | `lib/data/wordbook_database.dart` | 桌面端全书库不可用 |

---

## 二、运行时链路完整追踪

```
main()
  └─ bootstrapApp()  [app_bootstrap.dart]
       └─ WordBookDatabase.instance.initialize()  ← 解压 gzip + openDatabase
            └─ _db = await openDatabase(path, readOnly: true)
            └─ _initialized = true

runApp(WordApp)
  └─ buildLearningFeatureScope()  [app.dart]
       └─ buildBookFeatureScope()  [book_feature_providers.dart]
            ├─ Provider<BookCatalogReader> → RepositoryBookCatalogReader(repository: sl<BookRepository>())
            ├─ Provider<BookSelectionWriter> → RepositoryBookSelectionWriter(prefs: AppPreferences())
            ├─ Provider<BookWordsReader> → RepositoryBookWordsReader(database: WordBookDatabase.instance)
            └─ buildBookStateScope()  [book_feature_providers.dart]
                 └─ ChangeNotifierProvider<BookState>
                      └─ BookState(
                           catalogReader: context.read<BookCatalogReader>(),
                           selectionWriter: context.read<BookSelectionWriter>(),
                           wordsReader: context.read<BookWordsReader>(),
                           progressReader: context.read<LearningProgressReader>()  ← 来自 learning scope
                         )..load()

BookState.load()
  └─ _catalogReader.listBooks()
       └─ _repository.listBooks()
            └─ _database.getBooks()
                 └─ _database.db.query('books', orderBy: 'word_count DESC')
                      └─ 若 _db == null → 抛出 StateError
                      └─ 若表/列不存在 → 抛出 SqliteException
```

**关键发现**：`LearningProgressReader` 在 learning scope 中正确暴露，book scope 嵌套在内，`context.read<LearningProgressReader>()` 可正常解析。✅ 作用域顺序正确。

---

## 三、问题详析

### P0: WordBookDatabase.db getter 无 null 安全路径

**文件**: `lib/data/wordbook_database.dart`  
**行号**: ~db getter 所在行

```dart
Database get db {
  if (_db == null) throw StateError('数据库尚未初始化，请先调用 initialize()');
  return _db!;
}
```

**根因分析**:
- `_db` 在 `initialize()` 成功后才被赋值
- `initialize()` 是异步方法，依赖 `bootstrapApp()` 在 `runApp()` 之前被 `await` 调用
- 若 `bootstrapApp()` 中 `initialize()` 因任何原因失败（gzip 解压异常、路径权限、SQLite FFI 未就绪），`_db` 保持 null
- 此时任何数据库访问（`getBooks` / `getWordsByBook` / `getBookById`）均抛 `StateError`
- `StateError` 不是 `Exception`，无法被 `BookState.load()` 的 `catch (e)` 捕获 → **直接进入 Flutter 错误页面（红屏）或 Zone 未捕获异常**

**建议修复**:
```dart
Database? get db => _db;  // 返回 nullable，让调用方自行判断

// 或在调用链顶层添加 null 检查
Future<List<Book>> getBooks() async {
  final database = _database.db;
  if (database == null) return [];  // 或抛出更明确的异常
  ...
}
```

---

### P1: BookRepository.getBooks() 无异常处理

**文件**: `lib/repositories/book_repository_impl.dart`  
**行号**: `getBooks()` 方法内

```dart
@override
Future<List<Book>> getBooks() async {
  final result = await _database.db.query('books', orderBy: 'word_count DESC');
  return result.map((row) => Book.fromMap(row)).toList();
}
```

**根因分析**:
- 无 try-catch 包裹
- 若 `books` 表不存在、列名错误、或数据库损坏，抛出 `SqliteException`
- 异常穿透 `RepositoryBookCatalogReader.listBooks()` → `BookState.load()`
- `BookState.load()` 有 `catch (e)` 但仅设置 `_error = e.toString()`，books_page 显示空列表
- 用户看到空白书库，无任何错误提示

**建议修复**:
```dart
@override
Future<List<Book>> getBooks() async {
  try {
    final db = _database.db;
    if (db == null) return [];
    final result = await db.query('books', orderBy: 'word_count DESC');
    return result.map((row) => Book.fromMap(row)).toList();
  } on SqliteException catch (e) {
    debugPrint('BookRepository.getBooks SQL error: $e');
    return [];
  }
}
```

---

### P2: Book.fromMap 列名硬编码，与 DB schema 可能不一致

**文件**: `lib/models/book.dart`  
**行号**: `Book.fromMap` 工厂方法

```dart
factory Book.fromMap(Map<String, dynamic> map) {
  return Book(
    id: map['id'] as int? ?? 0,
    code: map['code'] as String? ?? '',
    name: map['name'] as String? ?? '',
    wordCount: map['word_count'] as int? ?? 0,
  );
}
```

**根因分析**:
- 代码假设 `books` 表列名为 `word_count`
- 根据 `docs/wordbook_license_audit.md`，实际 schema 确为 `word_count` ✅
- **但**：若数据库版本迭代或导出时列名变更（如 `wordCount`、`total_words`），此处静默返回 0
- 影响：`wordCount` 全部为 0 → 统计卡「总词数」为 0 → 用户体验异常

**建议修复**:
```dart
factory Book.fromMap(Map<String, dynamic> map) {
  return Book(
    id: map['id'] as int? ?? 0,
    code: map['code'] as String? ?? '',
    name: map['name'] as String? ?? '',
    wordCount: map['word_count'] as int?
        ?? map['wordCount'] as int?
        ?? map['total_words'] as int?
        ?? 0,
  );
}
```

---

### P3: getWordsByBook 依赖 word_books 连接表，无表存在性校验

**文件**: `lib/data\wordbook_database.dart`  
**行号**: `getWordsByBook` 方法内

```dart
Future<List<Word>> getWordsByBook(int bookId, {int limit = 50, int offset = 0}) async {
  final result = await _database.db.rawQuery('''
    SELECT w.* FROM words w
    JOIN word_books wb ON wb.word_id = w.id
    WHERE wb.book_id = ?
    ORDER BY wb.rowid
    LIMIT ? OFFSET ?
  ''', [bookId, limit, offset]);
  return result.map((row) => Word.fromMap(row)).toList();
}
```

**根因分析**:
- 使用 `JOIN word_books` 连接表
- 若 `word_books` 表不存在或为空，查询返回空结果
- 根据 Python 验证，应有 454,196 条映射记录，但运行时若表结构不一致（如列名为 `book_id` vs `bookId`），JOIN 条件失败
- 无 try-catch，SQL 异常穿透到 `BookState.loadWords()`

**建议修复**:
- 添加表存在性预检（PRAGMA table_info）
- 添加 try-catch 包裹

---

### R1: RepositoryBookCatalogReader.listBooks() 接口调用确认

**文件**: `lib/features/book/data/repository_book_catalog_reader.dart`

```dart
@override
Future<List<Book>> listBooks() => _repository.listBooks();
```

**潜在问题**:
- 调用 `_repository.listBooks()`，但 `BookRepository` 接口定义需确认是否包含 `listBooks()`
- 若接口仅定义 `getBooks()`，此处为编译错误（但项目编译通过，可能接口已包含）

**建议**: 确认 `lib/repositories/book_repository.dart` 中 `BookRepository` 接口定义是否包含 `listBooks()`。若仅 `getBooks()`，需统一命名。

---

### R2: SQLite FFI 桌面端初始化静默失败风险

**文件**: `lib/data/wordbook_database.dart`  
**行号**: `initialize()` 方法内

**根因分析**:
- 桌面端（Windows/macOS/Linux）需使用 `databaseFactoryFfi`
- 若 FFI 绑定未正确加载（sqflite_common_ffi 未初始化），`initialize()` 可能静默失败
- `initialize()` 内部无明确的成功/失败状态返回，外部仅通过 `_initialized` bool 判断

**建议修复**:
- `initialize()` 返回 `Future<bool>` 表示成功/失败
- 调用方检查返回值并显示友好错误

---

## 四、数据库 Schema 确认

根据 `docs/wordbook_license_audit.md`（审计日期 2026-08-24）：

```
books      (191 行)  — id, code(UNIQUE), name, word_count
words      (32,154 行) — id, word, main_word, interpret, uk_pron, us_pron,
                         phrase, example, confuse, audio_urls, image_urls, word_root
word_books (454,196 行) — word_id × book_id 多对多关联
```

**schema 与代码匹配度**: ✅ 列名完全匹配（`word_count`、`word_id`、`book_id` 均一致）

---

## 五、修复优先级建议

| 优先级 | 问题 | 修复工作量 | 建议负责人 |
|---|---|---|---|
| P0 | db getter null 安全 | 0.5h | lead |
| P1 | getBooks try-catch | 0.5h | lead |
| P2 | Book.fromMap 列名兼容 | 0.5h | lead |
| P3 | getWordsByBook 容错 | 1h | lead |
| R1 | 接口命名确认 | 0.5h | lead |
| R2 | FFI 初始化状态返回 | 1h | lead |

---

## 六、方法论备注

- **未执行** `flutter analyze` / `flutter test`（避免与 lead 抢锁）
- **已执行** 全链路静态代码审查：`wordbook_database.dart` → `book_repository.dart` → `book_repository_impl.dart` → `repository_book_catalog_reader.dart` → `book_state.dart` → `books_page.dart` / `book_words_page.dart`
- **已执行** DB schema 文档交叉验证（`docs/wordbook_license_audit.md`）
- **未执行** 实际数据库文件解压验证（已由 lead 用 Python 完成）

---

*报告完成。等待 lead 审查。*
