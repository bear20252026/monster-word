# XP AUD-3 · 全盘体检：词典/搜索/单词详情域

## 审计范围

- `lib/pages/word_detail_page.dart`
- `lib/pages/dictionary_page.dart`（薄 re-export）
- `lib/features/search/**`（search_page / example_reader / word_search_reader）
- `lib/widgets/word_dictionary_popup.dart`
- `lib/features/dictionary/**`（domain / application / data / presentation）
- `lib/core/router/content_routes.dart` wordDetail/search 段
- ExampleParser / PhraseParser 消费者

## 审计清单

### P0 — 运行时崩溃 / 黑屏

**无 P0 发现。** 已有的 `NavUtils.safePop` / `NavUtils.goHome` / `mounted` 守卫覆盖了主要退出路径。

---

### P1 — 功能缺陷 / 数据错误

| # | 文件:行 | 现象 | 根因 | 严重度 |
|---|---|---|---|---|
| 1 | `word_detail_page.dart:322` | `_onDeleteSuccess` 调用 `NavUtils.goHome` 而不是 `safePop`；若从搜索结果页 push 进入，完成删除后直接跳首页而非返回搜索列表 | `goHome` 语义是 popUntil 根路由，不适合"删完返回上一层"场景 | P1 |

### P2 — 体验 / 鲁棒性

| # | 文件:行 | 现象 | 根因 | 严重度 |
|---|---|---|---|---|
| 1 | `word_detail_page.dart:60-61` | `_resolveTargetWord(null)` 在深链场景下若传入的 extra 为空，返回 null 后静默退出（不显示错误/提示） | `_loadExtra` / `_loadNotes` 中 `if (word == null) return;` 无 UI 反馈 | P2 |
| 2 | `word_detail_page.dart:1006,1010` | `Navigator.pop(context)` / `Navigator.pop(context, controller.text)` 未使用 NavUtils 安全封装 | Dialog 内 pop 一般安全（dialog 有独立路由），但与全局模式不一致 | P2 |
| 3 | `word_dictionary_popup.dart:9` | 直接 import `learning_favorites_state.dart`（跨 feature presentation 边界） | 虽然 popup 属 widgets 层，但此依赖方向在 WS-2 search 迁移时已明确为违规模式 | P2 |
| 4 | `search_page.dart`（feature） | `favorites_accessor_adapter.dart` 同样 import `learning_favorites_state.dart` | data 适配器层封装可接受，但形成双向学习→搜索依赖链 | P2 |
| 5 | `dictionary_page.dart` (feature) | `DictionaryPage` 直接接收 `Word` 对象参数，不支持深链按单词名查询 | 深链 `/dictionary?word=hello` 需外部先查询 Word 对象再传入；`content_routes.dart` 中未定义 dictionary 路由 | P2 |

### P3 — 代码质量 / 规范

| # | 文件:行 | 现象 | 根因 | 严重度 |
|---|---|---|---|---|
| 1 | `word_detail_page.dart` | 使用 `SingleTickerProviderStateMixin` + `_tabController` 直接管理，未走 Provider 端口 | 功能正确但与教科书式四层范式不一致 | P3 |
| 2 | `content_routes.dart` | `wordDetail` 路由从 `settings.arguments as Map<String, dynamic>?` 取数据，安全但无 fallback | 若 arguments 类型不匹配会抛出 cast 异常 | P3 |

---

## 正面确认（无问题）

- ✅ `search_page.dart`（feature）通过 `ExampleReader` / `WordSearchReader` / `SearchHistoryStore` / `FavoritesAccessor` 四端口运行，不直连 data 层
- ✅ `DictionaryDetailState` 正确使用 `DictionarySearchReader` 端口
- ✅ `word_detail_page.dart` 所有 async 回调均有 `mounted` 守卫（L54, L64, L74, L82, L861, L1171, L1188, L1191）
- ✅ `content_routes.dart` wordDetail 路由有 `if (args == null)` null 检查
- ✅ `ExampleParser.parse()` / `PhraseParser.flatItems()` 对空输入返回空列表（安全）
- ✅ `SearchPage.routeName = '/search'` 正确维护
- ✅ `DictionaryPage.routeName = '/dictionary'` 正确维护
- ✅ `RouteErrorPage` 作为 404 fallback 合理

## 建议修复优先级

| 优先级 | 项 | 建议 |
|---|---|---|
| P1-1 | `_onDeleteSuccess` goHome → safePop | 改为 `NavUtils.safePop(context)` |
| P2-1 | 深链无词静默退出 | 添加错误提示 UI 或 fallback |
| P2-3 | word_dictionary_popup 跨 feature import | 后续 batch 考虑抽取 shared favorites port |
