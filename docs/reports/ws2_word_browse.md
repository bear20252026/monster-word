# WS-2 · Word Browse 教科书式垂直模块核对报告

## 概要

word_browse 模块结构已基本就位，无需大规模迁移。本报告核对四层依赖方向、
补全端口契约测试并撰写文档。

## 四层映射

### Domain 层

**无需独立 domain/。** 值对象 `FavSentenceData` / `SentenceData`（`lib/models/sentence_models.dart`）和 `WordNote`（`lib/models/word_note.dart`）均位于共享 `lib/models/*`，
符合框架 R5 约定（feature 可引用共享实体，无需复制定义）。

### Application 层（端口）

| 端口 | 职责 |
|---|---|
| `SentenceFavoritesStore` | 例句收藏 CRUD：`isFavorite` / `toggle` / `list` / `remove` |
| `WordNotesStore` | 单词笔记 CRUD：`listForWord` / `add` / `update` / `deleteById` |

### Data 层（适配器）

| 适配器 | 实现端口 | 委托 |
|---|---|---|
| `RepositorySentenceFavoritesStore` | `SentenceFavoritesStore` | `FavRepository` |
| `RepositoryWordNotesStore` | `WordNotesStore` | `NoteRepository` |

### Presentation 层

| 文件 | 职责 |
|---|---|
| `word_browse_feature_providers.dart` | `buildWordBrowseFeatureScope` — `MultiProvider` 注入两个端口 |

## 依赖方向核对

```
presentation (providers) → application (ports) → domain (models/* 共享)
                                ↑
                              data (adapters)
```

✅ 全部文件遵循 `data → application` 依赖方向。  
✅ application 端口仅依赖共享 `lib/models/*`（不依赖具体 data 实现）。  
✅ presentation 仅导入 data 适配器用于装配，不反向依赖。  
✅ 无跨 feature 直连违规。

## 端口清单

| # | 端口 | 方法 |
|---|---|---|
| 1 | `SentenceFavoritesStore.isFavorite` | `Future<bool>` |
| 2 | `SentenceFavoritesStore.toggle` | `Future<bool>` (wordId, sentenceId, english, chinese, source) |
| 3 | `SentenceFavoritesStore.list` | `Future<List<FavSentenceData>>` |
| 4 | `SentenceFavoritesStore.remove` | `Future<bool>` (wordId, sentenceId) |
| 5 | `WordNotesStore.listForWord` | `Future<List<WordNote>>` (wordId) |
| 6 | `WordNotesStore.add` | `Future<void>` (WordNote) |
| 7 | `WordNotesStore.update` | `Future<void>` (WordNote) |
| 8 | `WordNotesStore.deleteById` | `Future<void>` (noteId) |

## 测试结果

| 指标 | 数值 |
|---|---|
| flutter analyze | 0 error（127 pre-existing warnings/infos，0 新增） |
| flutter test 全量 | 359 passed / 0 failed |
| 新增测试 | 12 个 |

### 新增测试文件

| 文件 | 测试数 | 覆盖 |
|---|---|---|
| `test/features/word_browse/application/sentence_favorites_store_test.dart` | 6 | 端口契约：isFavorite / toggle / remove / list |
| `test/features/word_browse/application/word_notes_store_test.dart` | 6 | 端口契约：listForWord / add / update / deleteById |

### 已有测试（未修改）

| 文件 | 测试数 | 覆盖 |
|---|---|---|
| `test/features/word_browse/data/repository_word_browse_stores_test.dart` | 3 | data 适配器：RepositorySentenceFavoritesStore / RepositoryWordNotesStore |

## 遗留

| # | 描述 | 严重度 |
|---|---|---|
| 1 | data 适配器 `prefer_initializing_formals` info lint | 低（pre-existing） |
| 2 | 无 domain/ 目录（值对象在共享 models，符合框架约定） | 无 |

## 改动文件清单

### 新增（3 个）

1. `test/features/word_browse/application/sentence_favorites_store_test.dart`
2. `test/features/word_browse/application/word_notes_store_test.dart`
3. `docs/reports/ws2_word_browse.md`

### 修改

无 — 源代码未改动（结构已就位，仅补测试 + 报告）。
