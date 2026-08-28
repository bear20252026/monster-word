# WS-6 C1: 收藏状态提升为共享 core 契约（打破 search→learning 展示耦合）

> 目标：让 search 的 data 层不再依赖 learning 的 presentation 层具体类型，改为依赖 `lib/core/learning` 的共享契约（规则同 G3 `LearningProgressReader`）。

## 变更
1. **新 core 契约** `lib/core/learning/learning_favorites_store.dart`
   - `abstract class LearningFavoritesStore extends ChangeNotifier`
   - 能力：`favoriteWords` / `favoriteCount` / `isLoading` / `isFavorite(word)` / `refresh()` / `toggle(word)`。
2. **learning/presentation 实现契约** `learning_favorites_state.dart`
   - `class LearningFavoritesState extends ChangeNotifier implements LearningFavoritesStore`（方法签名原本就匹配，仅补 `@override` 与 `implements`）。
3. **learning feature scope 暴露契约类型** `learning_feature_providers.dart`
   - 在既有 `ChangeNotifierProvider<LearningFavoritesState>` 之后，新增
     `ProxyProvider<LearningFavoritesState, LearningFavoritesStore>(update: (_, s, _) => s)`，
     把**同一实例**以 core 契约类型暴露。既有 `watch<LearningFavoritesState>()` 消费方（my_fav/learn_page/menu 等）零改动。
4. **search data 改用契约** `favorites_accessor_adapter.dart`
   - 字段类型 `LearningFavoritesState` → `LearningFavoritesStore`；删除 `import ...learning/presentation/...`，改 import core 契约。
5. **search feature scope** `search_feature_providers.dart`
   - `ProxyProvider<LearningFavoritesState, FavoritesAccessor>` → `ProxyProvider<LearningFavoritesStore, FavoritesAccessor>`；删除 learning/presentation import，改 import core 契约。
6. **新增测试** `test/features/search/data/favorites_accessor_adapter_test.dart`
   - 用 `_FakeFavoritesStore implements LearningFavoritesStore`（core 契约）验证 `FavoritesAccessorAdapter` 的 `isFavorite`/`toggle` 委托——从测试侧锁定 search 只依赖 core 契约。

## 结果
- 编译期：search 不再 `import` 任何学习 presentation 类型；仅依赖 `core/learning`。
- 运行期：`context.watch<LearningFavoritesStore>()` / `read` 可经 proxy 拿到与 `LearningFavoritesState` 同一实例，通知传播正常（响应式不回归）。

## 质量门
- `flutter analyze` → `No issues found!`（exit 0）
- `flutter test` → `00:25 +385: All tests passed!`（含新增 2 例）

## 后续（设计见 ws6_design_learning_core_contracts.md）
- C2：`NewWordsStore`（book 新词徽标）。
- C3：`LearningSessionStarter`（book 启动学习动作）。注意 `LearningSessionState` 被 ~13 文件消费，本轮**不动**其本体，仅收敛启动动作，避免大杂烩。
