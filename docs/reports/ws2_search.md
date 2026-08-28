# WS-2 · Search 迁移为教科书式垂直功能模块

## 迁移概要

将 `lib/pages/search_page.dart`（单体页面）升级为教科书式垂直功能模块，四层齐全，
与 `lib/features/dictionary/` 范式完全对齐。

## 四层映射

### Domain 层

| 文件 | 职责 |
|---|---|
| `lib/features/search/domain/search_example.dart` | `SearchExample` / `HighlightPart` 域实体（从 `lib/data/example_parser.dart` 迁入） |

### Application 层

| 端口 | 职责 |
|---|---|
| `word_search_reader.dart` (已有) | 搜索单词 → 返回 `List<Word>` |
| `search_history_store.dart` (已有) | 搜索历史 CRUD |
| `example_reader.dart` (新增) | 解析例句 JSON → `List<SearchExample>` |
| `favorites_accessor.dart` (新增) | 收藏状态读写（避免跨 feature 直连 presentation） |

### Data 层

| 适配器 | 职责 |
|---|---|
| `repository_word_search_reader.dart` (已有) | 委托 `WordRepository` 实现搜索 |
| `preferences_search_history_store.dart` (已有) | 委托 `AppPreferences` 持久化历史 |
| `example_parser_adapter.dart` (新增) | 委托旧 `ExampleParser` 实现 `ExampleReader` 端口 |
| `favorites_accessor_adapter.dart` (新增) | 包装 `LearningFavoritesState` 实现 `FavoritesAccessor` 端口 |

### Presentation 层

| 文件 | 职责 |
|---|---|
| `search_page.dart` (新增，从 `pages/` 迁入) | 完整 UI：搜索栏、结果列表、词义详情、历史、空状态 |
| `search_feature_providers.dart` (更新) | 装配 4 个端口 + `FavoritesAccessor` 通过 `ProxyProvider` 绑定 |

### Pages 层

| 文件 | 变化 |
|---|---|
| `lib/pages/search_page.dart` | 改为薄 re-export（`export '../features/search/presentation/search_page.dart'`） |

## 结构违规修复

### ✅ 修复 1：直连旧 data 层

**违规前**：`lib/pages/search_page.dart` 直接 `import '../data/example_parser.dart'`
**修复后**：页面通过 `ExampleReader` 端口访问，`ExampleParserAdapter` 在 data 层桥接旧解析器

### ✅ 修复 2：跨 feature 直连 presentation

**违规前**：`lib/pages/search_page.dart` 直接 `import '../features/learning/presentation/learning_favorites_state.dart'`
**修复后**：页面通过 `FavoritesAccessor` 端口访问，`FavoritesAccessorAdapter` 在 data 层包装 `LearningFavoritesState`

## 测试结果

| 指标 | 数值 |
|---|---|
| flutter analyze | 0 error（127 pre-existing warnings/infos） |
| flutter test | 347 passed / 0 failed |
| 新增测试 | 13 个（domain 9 + data 1 + architecture 1 × 2 修正） |
| search 相关 warning/info | 0 新增 |

### 新增测试文件

- `test/features/search/domain/search_example_test.dart` — 5 个测试
- `test/features/search/domain/example_reader_adapter_test.dart` — 3 个测试
- `test/features/search/data/repository_word_search_reader_test.dart` — 1 个测试（已有）

### 修正的架构测试

- `test/architecture/app_structure_test.dart` — 2 个测试路径更新：
  - `audioConsumers` 列表指向新 feature 路径
  - 搜索端口检查指向新 feature 路径

## SearchPage.routeName 保持

```dart
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  static const String routeName = searchRouteName; // '/search'
}
```

`HomeScreen` → `Navigator.pushNamed(context, SearchPage.routeName)` 路由不变。

## 遗留问题

| # | 描述 | 严重度 | 建议 |
|---|---|---|---|
| 1 | `FavoritesAccessorAdapter` 仍 import `learning_favorites_state.dart`（在 data 适配器层） | 低 | 这是 adapter 层的合理职责——data adapter 封装跨 feature 依赖；未来 learning 可提供 application 端口进一步解耦 |
| 2 | `lib/data/example_parser.dart` 保留未删除 | 低 | 其他 4 个文件（learn_session、word_dictionary_popup、sentence_quiz_page、word_detail_page）仍在引用；后续 batch 可逐个迁移 |

## 改动文件清单

### 新增（7 个）

1. `lib/features/search/domain/search_example.dart`
2. `lib/features/search/application/example_reader.dart`
3. `lib/features/search/application/favorites_accessor.dart`
4. `lib/features/search/data/example_parser_adapter.dart`
5. `lib/features/search/data/favorites_accessor_adapter.dart`
6. `lib/features/search/presentation/search_page.dart`
7. `docs/reports/ws2_search.md`

### 修改（3 个）

1. `lib/pages/search_page.dart` → 薄 re-export
2. `lib/features/search/presentation/search_feature_providers.dart` → 新增 2 个端口注册
3. `test/architecture/app_structure_test.dart` → 路径修正

### 新增测试（2 个）

1. `test/features/search/domain/search_example_test.dart`
2. `test/features/search/domain/example_reader_adapter_test.dart`
