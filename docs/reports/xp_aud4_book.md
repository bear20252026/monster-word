# XP AUD-4 全盘体检：词书/书库/选书域

> **审计人**: XP AUD-4
> **日期**: 2026-08-28
> **项目**: Monster Word (`D:\claude\work\cn_com_lange\word_app`)
> **范围**: 词书/书库/选书域（lib/features/book/**、lib/pages/lib_select_page.dart、lib/data/wordbook_database.dart、lib/repositories/book_repository_*.dart、lib/models/book.dart、RouteNames book 段）
> **方法**: 静态代码分析 + 路由/数据流追踪（未修改 lib/ 代码）

---

## 一、审计结论摘要

| # | 严重度 | 问题 | 文件 | 影响 |
|---|---|---|---|---|
| P0 | 🔴 致命 | 路由名不匹配：`/book-words` vs `/book_words`，lib_select_page 跳转失败 | `lib/pages/lib_select_page.dart:78,518` | 用户从选书页点击词书无法进入单词列表 |
| P1 | 🔴 高 | `WordBookDatabase.db` getter 未初始化时抛 StateError，非 Exception 无法被 catch 捕获 | `lib/data/wordbook_database.dart:46-51` | 数据库未就绪时全书库功能崩溃（红屏） |
| P1 | 🔴 高 | `BookRepositoryImpl.getBooks()` 无 try-catch，SQL 异常直接穿透到 UI | `lib/repositories/book_repository_impl.dart` | SQL 失败时 books_page 显示空白无错误提示 |
| P2 | 🟡 中 | `Book.fromMap` 硬编码 `word_count` 列名，列名不匹配时 wordCount 静默为 0 | `lib/models/book.dart` | 统计卡「总词数」为 0，用户体验异常 |
| P2 | 🟡 中 | `BookState.selectAndLoad` 加载单词失败时 `_error` 未设置，用户无反馈 | `lib/features/book/presentation/book_state.dart` | 单词列表加载失败时显示空白，无错误提示 |
| P2 | 🟡 中 | `BookStatistics.totalWords` 在 `_currentBook` 为 null 时回退到 `_words.length`，可能为 0 | `lib/features/book/presentation/book_state.dart:100` | 统计卡显示「已学 0 / 总量 0」，误导用户 |
| P3 | 🟢 低 | `books_page.dart` 导航使用字符串字面量 `'/lib-select'`，应使用 `RouteNames.libSelect` | `lib/features/book/presentation/books_page.dart:124` | 维护风险，路由名变更时易失效 |
| P3 | 🟢 低 | `BookState.load()` 中 `_currentBookId > 0` 判断可能跳过有效 ID 为 0 的词书 | `lib/features/book/presentation/book_state.dart:69` | 极端情况下当前词书无法恢复 |

---

## 二、运行时链路追踪

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
            └─ buildBookStateScope()
                 └─ ChangeNotifierProvider<BookState>
                      └─ BookState(
                           catalogReader: context.read<BookCatalogReader>(),
                           selectionWriter: context.read<BookSelectionWriter>(),
                           wordsReader: context.read<BookWordsReader>(),
                           progressReader: context.read<LearningProgressReader>()
                         )..load()

BookState.load()
  └─ _catalogReader.listBooks()
       └─ _repository.listBooks()
            └─ _database.getBooks()
                 └─ _database.db.query('books', orderBy: 'word_count DESC')
                      └─ 若 _db == null → 抛出 StateError
                      └─ 若表/列不存在 → 抛出 SqliteException

BookState.selectAndLoad(book)
  └─ _wordsReader.getWordsByBook(book.id)
       └─ _database.getWordsByBook(book.id)
            └─ db.rawQuery('SELECT w.* FROM words w JOIN word_books wb ...')
  └─ _progressReader.countLearnedWords(wordTexts)
       └─ 返回已学词数
  └─ _statistics = BookStatistics(learnedWords: learned, totalWords: book.wordCount)
```

---

## 三、问题详析

### P0: 路由名不匹配 — lib_select_page 跳转失败

**文件**: `lib/pages/lib_select_page.dart:78` 和 `lib/pages/lib_select_page.dart:518`
**现象**: 用户从选书页点击词书无法进入单词列表

```dart
// lib_select_page.dart:78
Navigator.pushNamed(context, BookWordsPage.routeName, arguments: book);

// lib_select_page.dart:516-520
Navigator.pushNamed(
  context,
  BookWordsPage.routeName,
  arguments: {'bookId': book.id, 'bookName': book.name},
);
```

**根因**:
- `BookWordsPage.routeName = '/book-words'`（带连字符）— 定义在 `lib/features/book/presentation/book_words_page.dart:25`
- 路由注册使用 `RouteNames.bookWords = '/book_words'`（带下划线）— 定义在 `lib/core/router/route_names.dart`
- `lib/core/router/learning_routes.dart:40` 注册的是 `RouteNames.bookWords`（`/book_words`）
- `lib/core/router/app_router.dart` 的 `onGenerateRoute` 匹配 `/book_words` → `BookWordsPage`
- 但 `lib_select_page.dart` 导航到 `/book-words`，路由表中无此条目 → 进入 `RouteErrorPage`（"页面不存在"）

**影响**: 用户从选书页点击任意词书均无法进入单词列表，功能完全不可用。

**建议修复**: 统一路由名。将 `BookWordsPage.routeName` 改为 `RouteNames.bookWords`（`/book_words`），或在 `lib_select_page.dart` 中使用 `RouteNames.bookWords`。

---

### P1: WordBookDatabase.db getter 无 null 安全路径

**文件**: `lib/data/wordbook_database.dart:46-51`
**现象**: 数据库未初始化时全书库功能崩溃

```dart
Database get db {
  if (_db == null) {
    throw StateError('数据库尚未初始化，请先调用 initialize()');
  }
  return _db!;
}
```

**根因**:
- `_db` 在 `initialize()` 成功后才被赋值
- `initialize()` 是异步方法，依赖 `bootstrapApp()` 在 `runApp()` 之前被 `await` 调用
- 若 `initialize()` 因任何原因失败（gzip 解压异常、路径权限、SQLite FFI 未就绪），`_db` 保持 null
- 此时任何数据库访问（`getBooks` / `getWordsByBook` / `getBookById`）均抛 `StateError`
- `StateError` 不是 `Exception`，无法被 `BookState.load()` 的 `catch (e)` 捕获 → 直接进入 Flutter 错误页面（红屏）或 Zone 未捕获异常

**影响**: 数据库初始化失败时，整个应用崩溃。

**建议修复**: 将 getter 改为 nullable 返回，或在调用链顶层添加 null 检查。

---

### P1: BookRepositoryImpl.getBooks() 无异常处理

**文件**: `lib/repositories/book_repository_impl.dart`
**现象**: SQL 失败时 books_page 显示空白无错误提示

```dart
@override
Future<List<Book>> getBooks() async {
  final result = await _database.db.query('books', orderBy: 'word_count DESC');
  return result.map((row) => Book.fromMap(row)).toList();
}
```

**根因**:
- 无 try-catch 包裹
- 若 `books` 表不存在、列名错误、或数据库损坏，抛出 `SqliteException`
- 异常穿透 `RepositoryBookCatalogReader.listBooks()` → `BookState.load()`
- `BookState.load()` 有 `catch (e)` 但仅设置 `_error = e.toString()`，books_page 显示空列表
- 用户看到空白书库，无任何错误提示

**影响**: SQL 失败时用户看到空白书库，无法定位问题。

**建议修复**: 在 `getBooks()` 中添加 try-catch，返回空列表并记录错误。

---

### P2: Book.fromMap 列名硬编码

**文件**: `lib/models/book.dart`
**现象**: 列名不匹配时 wordCount 静默为 0

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

**根因**:
- 代码假设 `books` 表列名为 `word_count`
- 根据 `docs/wordbook_license_audit.md`，实际 schema 确为 `word_count` ✅
- **但**：若数据库版本迭代或导出时列名变更（如 `wordCount`、`total_words`），此处静默返回 0
- 影响：`wordCount` 全部为 0 → 统计卡「总词数」为 0 → 用户体验异常

**影响**: 列名不匹配时统计卡显示异常。

**建议修复**: 添加列名兼容性处理（尝试多种列名），或使用 `map.containsKey` 检查。

---

### P2: BookState.selectAndLoad 加载单词失败时无错误反馈

**文件**: `lib/features/book/presentation/book_state.dart`
**现象**: 单词列表加载失败时显示空白，无错误提示

```dart
// selectAndLoad 方法中
try {
  _words = await _wordsReader.getWordsByBook(book.id, limit: 50);
  _statistics = BookStatistics(
    learnedWords: learned,
    totalWords: _currentBook?.wordCount ?? _words.length,
  );
} catch (e) {
  _words = const [];
  // ← 这里没有设置 _error = e.toString()
}
```

**根因**: catch 块仅清空 `_words`，未设置 `_error`，UI 层无法显示错误状态。

**影响**: 单词列表加载失败时用户看到空白列表，无错误提示。

**建议修复**: 在 catch 块中添加 `_error = e.toString()`。

---

### P2: BookStatistics.totalWords 回退逻辑不准确

**文件**: `lib/features/book/presentation/book_state.dart:100`
**现象**: 统计卡显示「已学 0 / 总量 0」，误导用户

```dart
totalWords: _currentBook?.wordCount ?? _words.length,
```

**根因**: 当 `_currentBook` 为 null（加载失败）时，回退到 `_words.length`，而 `_words` 可能为空（刚清空），导致 totalWords 为 0。

**影响**: 统计卡显示「已学 0 / 总量 0」，误导用户认为词书无单词。

**建议修复**: 在 `_currentBook` 为 null 时使用上次已知的 totalWords，或显示为「--」。

---

### P3: books_page.dart 导航使用字符串字面量

**文件**: `lib/features/book/presentation/books_page.dart:124`
**现象**: 维护风险，路由名变更时易失效

```dart
onTap: () => Navigator.pushNamed(context, '/lib-select'),
```

**影响**: 若路由名变更，此处不会编译报错，但运行时会失败。

**建议修复**: 使用 `RouteNames.libSelect` 常量。

---

### P3: BookState.load() 中 _currentBookId > 0 判断

**文件**: `lib/features/book/presentation/book_state.dart:69`
**现象**: 极端情况下当前词书无法恢复

```dart
if (_currentBookId > 0) {
  _currentBook = await _catalogReader.findById(_currentBookId);
}
```

**影响**: 若词书 ID 为 0（极端情况），无法恢复当前词书。

**建议修复**: 改为 `if (_currentBookId >= 0)` 或根据实际 ID 范围调整。

---

## 四、验证通过项

| 检查项 | 状态 | 说明 |
|--------|------|------|
| LearningProgressReader 作用域 | ✅ | book scope 嵌套在 learning scope 内，`context.read<LearningProgressReader>()` 可正常解析 |
| BookWordsPage 构造参数 | ✅ | 路由 handler 使用 `BookWordsPage(bookId: args.id, bookName: args.name)` 匹配薄适配 |
| 点击词跳详情 | ✅ | `book_words_page.dart` 中 `_WordCard` 有 `onTap` → `Navigator.pushNamed(context, WordDetailPage.routeName, arguments: word)` |
| 空书库/空书列表 | ✅ | `books_page.dart` 和 `book_words_page.dart` 均有空状态处理 |
| Provider 齐全 | ✅ | `book_feature_providers.dart` 正确暴露 `BookCatalogReader`、`BookSelectionWriter`、`BookWordsReader`、`BookState` |
| 返回/逐级回首页 | ✅ | 导航栈正常，可逐级返回 |

---

## 五、修复优先级建议

1. **P0 立即修复**: 路由名不匹配（`/book-words` vs `/book_words`）— 影响核心用户流程
2. **P1 尽快修复**: `WordBookDatabase.db` getter null 安全 + `BookRepositoryImpl.getBooks()` 异常处理
3. **P2 计划修复**: `Book.fromMap` 列名兼容 + `selectAndLoad` 错误反馈 + `totalWords` 回退逻辑
4. **P3 技术债**: 字符串字面量路由名 + `_currentBookId > 0` 判断
