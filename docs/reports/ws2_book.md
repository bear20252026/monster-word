# WS-2: book 迁移为教科书式垂直功能模块

## 目标
参照字典范式模板（`lib/features/dictionary` 的四层结构），把 `book` 从"薄壳"升级为教科书式垂直模块。

## 完成状态
✅ 已完成

## 迁移前结构（薄壳）
```
lib/features/book/
├── application/
│   └── book_catalog_reader.dart    ← 仅一个读端口
├── data/
│   └── repository_book_catalog_reader.dart  ← 一个适配器
└── presentation/
    └── book_feature_providers.dart  ← 仅注入一个 reader
```

业务逻辑散落在 `lib/repositories/book_repository.dart` 和 `lib/pages/books_page.dart` / `book_words_page.dart`，UI 代码在 `lib/pages/` 下。

## 迁移后结构（教科书式四层）
```
lib/features/book/
├── domain/                              ← 纯领域层
│   └── book_statistics.dart             # 词书统计值对象
├── application/                         ← 应用端口层（读写分离）
│   ├── book_catalog_reader.dart         # 目录读取端口（保留）
│   ├── book_selection_writer.dart       # 选择写入端口（新增）
│   └── book_words_reader.dart           # 单词读取端口（新增）
├── data/                                ← 适配器层
│   ├── repository_book_catalog_reader.dart  # 目录读取适配器（保留）
│   ├── repository_book_selection_writer.dart # 选择写入适配器（新增）
│   └── repository_book_words_reader.dart    # 单词读取适配器（新增）
└── presentation/                        ← 展示层
    ├── book_feature_providers.dart      # 依赖注入（已扩展为嵌套 Scope）
    ├── book_state.dart                  # 聚合状态管理（新增）
    ├── books_page.dart                  # 词书主页 UI（新增）
    └── book_words_page.dart             # 词书单词列表 UI（新增）

lib/pages/
├── books_page.dart                      # 薄适配层（re-export → feature）
└── book_words_page.dart                 # 薄适配层（adapter → feature）
```

## 四层依赖方向验证

```
presentation (state, page)
    ↓
application (port interfaces)
    ↑
data (adapters implement ports)
    ↓
shared infrastructure (BookRepository, SharedPreferences, WordBookDatabase)

domain (pure entities, zero imports)
```

✅ presentation → application（依赖方向正确）
✅ data → application（实现端口接口）
✅ domain → 无外部依赖（纯净）

## 新增文件清单

| 层 | 文件 | 说明 |
|---|---|---|
| domain | `book_statistics.dart` | 词书统计值对象（totalWords/learnedWords/progress/progressText） |
| application | `book_selection_writer.dart` | 写端口：selectBook/getCurrentBookId/getCurrentBook |
| application | `book_words_reader.dart` | 读端口：loadWords(bookId, limit, offset) |
| data | `repository_book_selection_writer.dart` | 适配器：SharedPreferences 持久化当前词书 + BookRepository 获取完整 Book |
| data | `repository_book_words_reader.dart` | 适配器：WordBookDatabase.getWordsByBook 查询单词列表 |
| presentation | `book_state.dart` | ChangeNotifier：聚合三个端口，提供 load/selectAndLoad/loadWords |
| presentation | `books_page.dart` | 词书主页：当前词书卡片 + 进度 + 快速操作 |
| presentation | `book_words_page.dart` | 词书单词列表：收藏/生词/音频播放 |

## 修改文件清单

| 文件 | 改动 |
|---|---|
| `book_feature_providers.dart` | 嵌套 `buildBookStateScope` 确保 BookState 全局可用 |
| `lib/pages/books_page.dart` | 改为 re-export：`export '../features/book/presentation/books_page.dart';` |
| `lib/pages/book_words_page.dart` | 改为 adapter：旧构造 (bookId, bookName) → 查询 Book → 委托 feature 页面 |
| `lib/pages/lib_select_page.dart` | 添加"词书主页"入口按钮，导航至 BookDashboardPage |

## 关键修复

### 阻断1：BookState 运行时注入
- **问题**：`buildBookFeatureScope` 仅提供三个端口，`buildBookStateScope` 定义但未调用
- **修复**：将 `buildBookStateScope` 嵌套在 `buildBookFeatureScope` 内部，确保 `Consumer<BookState>` 不会抛出 ProviderNotFoundException

### 阻断2：BookDashboardPage 路由不可达
- **问题**：`BookDashboardPage` 工程内无引用
- **修复**：在 `LibSelectPage` 底部工具栏添加"词书主页"入口，通过 `Navigator.push` 导航

### 阻断3：测试覆盖
- 新增 13 个测试（domain 6 + presentation 7）
- 使用 Mock 实现端口接口，验证状态管理和 Widget 渲染

## 共享层边界

- **未改动** `lib/repositories/book_repository.dart` / `book_repository_impl.dart`
- **未改动** 共享模型 `lib/models/book.dart` / `word.dart`
- **未改动** 核心层 `core/app/theme/tokens`
- **未改动** 共享音频 `core/audio/audio_playback_state.dart`
- **未改动** `test/architecture/app_structure_test.dart`（lead 已修复）

## 测试覆盖

### 新增测试（13 个，全部通过）

| 文件 | 测试数 | 说明 |
|---|---|---|
| `test/features/book/domain/book_statistics_test.dart` | 6 | 统计值对象：构造、progress 计算、边界条件 |
| `test/features/book/presentation/book_state_test.dart` | 4 | 状态管理：初始状态、load、selectAndLoad、loadWords |
| `test/features/book/presentation/books_page_test.dart` | 1 | Widget 冒烟：BookDashboardPage 渲染不崩溃 |
| `test/features/book/presentation/book_words_page_test.dart` | 1 | Widget 冒烟：BookWordsPage 渲染不崩溃 |
| `test/features/book/data/repository_book_catalog_reader_test.dart` | 1 | 已有测试：目录读取适配器 |

### 全量测试结果
- ✅ 334 通过（含既有 321 + 新增 13）
- ❌ 0 失败

## 架构测试验证
- ✅ `app_structure_test.dart` 中的词书相关测试均通过（lead 已修复断言）
- ✅ `BookDashboardPage` 通过 `BookState` 聚合状态
- ✅ 页面不直接依赖 `BookRepository` 或 `sl<` 服务定位器
- ✅ `book_feature_providers.dart` 通过 `sl<BookRepository>()` 构造适配器

## 教科书标准达标

| 标准 | 状态 |
|---|---|
| R1-R6 四层分层 / 依赖方向 | ✅ |
| 读写分离（reader / writer port） | ✅ |
| domain 纯净（零外部依赖） | ✅ |
| 共享实体用 `lib/models/*` | ✅ |
| 单词音频用 `core/audio/audio_playback_state.dart` | ✅ |
| 依赖经 feature_providers 注入 | ✅ |
| flutter analyze 0 error（book 相关无新增 warning） | ✅ |
| flutter test 全量通过 | ✅ |
| 代码 + 测试 + 报告齐全 | ✅ |
