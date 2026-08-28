# WS-6 设计：将 learning 展示状态提升为共享 core 契约（消除跨 feature 展示耦合）

> 状态：待 WS-1（lint 清理）完成后派发。WS-1 由 2163 负责 `lib/features/learning/**`，为避免与 lint 改动冲突，WS-6 严格排在 WS-1 之后串行执行。
> 范式样本：同 WS-4 G3 的 `LearningProgressReader`（`lib/core/learning/learning_progress_reader.dart`）。

## 动机

Batch 2/WS-4 G2 登记的技术债：多个 feature 直连 `learning/presentation` 内部状态，违反「跨 feature 仅依赖 core 契约」的约束。

**证实的耦合点（grep 实测）：**

| 消费方 | 直连的 learning/presentation 类型 | 位置 |
|---|---|---|
| search/data/favorites_accessor_adapter.dart | `LearningFavoritesState` | `:11`（字段）、`:13`（构造） |
| book/presentation/book_words_page.dart | `LearningSessionState` | `:29`（`_startLearning`） |
| book/presentation/book_words_page.dart | `LearningFavoritesState` | `:95`（`_WordCard` 徽标） |
| book/presentation/book_words_page.dart | `NewWordsState` | `:96`（`_WordCard` 徽标） |

另：`lib/pages/`、`lib/screens/`、`lib/widgets/` 大量直接 `watch/read<LearningSessionState>()`（如 word_detail、immersive_swipe、learn_session、word_machine、sentence_quiz、spell_session、lib_select、my_fav、foot_mark、review_dialog、word_dictionary_popup、learn_page 等）。这些属「页面消费全局状态」，虽跨层但属原 `lib/pages` 遗留；是否纳入本次以「是否可低成本、无破坏地契约化」为界，避免大杂烩。

## 目标（教科书六边形）

- `learning` 把"收藏状态""新词状态""会话启动"通过 **core 契约**暴露。
- 消费方（search / book / 各页面）只依赖 `lib/core/learning/*`，编译期不再 import `learning/presentation` 具体类型。
- 依赖方向保持 `presentation → application → domain`，core 为共享、单向。

## 拆解（3 个核心契约，镜像 G3）

### C1｜收藏状态 → `LearningFavoritesStore`（core，ChangeNotifier 版）
- core：`lib/core/learning/learning_favorites_store.dart`
  - `abstract class LearningFavoritesStore extends ChangeNotifier`
  - `bool isFavorite(String word)`、`Future<void> toggleFavorite(String word)`、`Iterable<String> get favoriteWords`、可选 `loadFavoriteWords(...)`。
  - 用 ChangeNotifier 而非纯接口，因徽标需响应式 `watch`。
- learning/data：`lib/features/learning/data/repository_learning_favorites_store.dart`
  - 实现 core 契约，读 `FavRepository` + `LearningQueueRepository`（现有 `LearningFavoritesState` 内部逻辑搬入）。
- learning/presentation/learning_feature_providers.dart：以 `ChangeNotifierProvider<LearningFavoritesStore>.value` 暴露（替换/包装现有 `LearningFavoritesState`）。
- 消费方改：
  - `search/data/favorites_accessor_adapter.dart`：改持 core 契约（`FavoritesAccessorAdapter(this._favorites)` → `FavoritesAccessorAdapter(this._favoritesStore)`，内部 `isFavorite`→`_favoritesStore.isFavorite`、写走 `toggleFavorite`），`search_feature_providers.dart:26-27` 改注入 core 契约。
  - `book/presentation/book_words_page.dart:95`：`context.watch<LearningFavoritesStore>()`。
  - `my_fav_page.dart`、`learn_session.dart`、`learn_page.dart`、`word_dictionary_popup.dart`、`learning_collections_state.dart`、`learning_feature_providers.dart` 一并改读 core 契约。
- 保留 `LearningFavoritesState` 为薄 re-export shim（或直接替换并更新所有引用），避免破坏旧调用方。

### C2｜新词状态 → `NewWordsStore`（core，ChangeNotifier 版）
- core：`lib/core/learning/new_words_store.dart`（`bool isNewWord(String id)` 等）
- learning/data 实现 + providers 暴露。
- `book/.../book_words_page.dart:96` 改 `context.watch<NewWordsStore>()`。

### C3｜会话启动 → `LearningSessionStarter`（core，只写不读；避免暴露巨型可变 session）
- core：`lib/core/learning/learning_session_starter.dart`
  - `Future<void> startBookSession(Book book, {int limit})`（或 `loadBook`）。
- learning/data 实现（内部 hold `LearningSessionState` 或直接装配）＋ learning presentation 暴露。
- `book/.../book_words_page.dart:29` 改 `context.read<LearningSessionStarter>().startBookSession(book, limit: 50)`。
- 注意：`LearningSessionState` 本身仍被 `lib/pages`/`lib/screens` 大量消费，属「页面消费全局状态」；若强行契约化全部读写会变成大杂烩，本轮**不动** `LearningSessionState` 本体，仅把 book 的启动动作收敛到 C3 契约，其余保持现状并注明。

## 串行纪律（吸取 G3/G2 教训）
- 每契约一个任务、一人专享；前一个落地 + 测试绿 + lead 审查通过，才派下一个。
- 严格避免与 WS-1 交叉（WS-1 动 `lib/features/learning/**`，2163 正改 —— 本轮绝不并行）。
- 任何 teammates 不得在派发前预改 `lib/core/`（lead 专属）或越界改他人文件。

## 质量门
- `flutter analyze` 0 error（WS-1 完成后累计 0 issue 目标）。
- `flutter test` 全绿（新增 C1/C2/C3 契约测试，仿 `learning_progress_reader_impl_test.dart`）。
- 边界：core/、app/、theme/、tokens/ 仅 lead；app_structure_test.dart 仅 lead。
