# WS-6 C2: 生词本状态提升为共享 core 契约（打破 book→learning 展示耦合）

> 目标：让 book 的词卡徽标不再依赖 learning 的 presentation 层具体类型，改为依赖 `lib/core/learning` 的共享契约（规则同 G3 `LearningProgressReader`、C1 `LearningFavoritesStore`）。

## 变更
1. **新 core 契约** `lib/core/learning/new_words_store.dart`
   - `abstract class NewWordsStore extends ChangeNotifier`
   - 能力：`initialized` / `count` / `isNewWord(wordId)` / `initialize()` / `toggleNewWord(Word, {source})`。
2. **learning/presentation 实现契约** `new_words_state.dart`
   - `class NewWordsState extends ChangeNotifier implements NewWordsStore`（方法签名原本就匹配，仅补 `@override` 与 `implements`）。
3. **learning feature scope 暴露契约类型** `learning_feature_providers.dart`
   - 在既有 `ChangeNotifierProvider(create: (_) => sl<NewWordsState>()..initialize())` 之后，新增
     `ListenableProxyProvider<NewWordsState, NewWordsStore>(update: (_, s, _) => s)`，
     把**同一实例**以 core 契约类型暴露。既有 `watch<NewWordsState>()` 消费方零改动。
4. **book 改用契约** `book_words_page.dart`
   - `_WordCard` 徽标：`context.watch<LearningFavoritesState>()`/`NewWordsState()` → `context.watch<LearningFavoritesStore>()`/`NewWordsStore()`；
   - 删除 `import ...learning/presentation/learning_favorites_state.dart` 与 `new_words_state.dart`，改 import core 契约。
5. **测试对齐** `book_words_page_fab_test.dart` / `book_words_page_navigation_test.dart`
   - 每处 `ChangeNotifierProvider<NewWordsState>` 之后补 `ListenableProxyProvider<NewWordsState, NewWordsStore>`；
   - 对应地为 `LearningFavoritesState` 补 `ListenableProxyProvider<LearningFavoritesState, LearningFavoritesStore>`（前一个测试里遗漏，导致徽标读到的是具体类型，与生产装配不一致）。
6. **新增测试** `test/features/learning/data/new_words_store_contract_test.dart`
   - 用 `_FakeNewWordsStore implements NewWordsStore`（core 契约）验证 `isNewWord`/`count`/`toggleNewWord` 的契约行为，从测试侧锁定契约语义。

## 关键修正：Listenable 型输出必须用 `ListenableProxyProvider`
- 现象：改用 `ProxyProvider<X, Y>` 暴露 `LearningFavoritesStore` / `NewWordsStore` 时，运行期抛
  `Provider.debugCheckInvalidValueType`（`Tried to use Provider with a subtype of Listenable/Stream`），
  因为这两个契约都 `extends ChangeNotifier`（即 `Listenable`）。
- 根因：`ProxyProvider` 走 `InheritedProvider` 的默认 `debugCheckInvalidValueType`，拒绝 `Listenable`/`Stream` 值；
  `ChangeNotifierProxyProvider`/`ListenableProxyProvider` 则传 `null` 且使用
  `ListenableProvider._startListening` 订阅输出值，从而允许 `Listenable` 输出并正确向消费方传播通知。
- 修正：学习域里所有“把学习状态以 core 契约类型暴露”的 proxy 统一改为
  `ListenableProxyProvider<ConcreteState, CoreContract>(update: (_, s, _) => s)`。
- 附带修复：C1 的 `ProxyProvider<LearningFavoritesState, LearningFavoritesStore>` 存在同类潜在运行期隐患
  （CI 未覆盖完整装配树所以未触发），本轮一并改为 `ListenableProxyProvider`，属 bug 修复而非行为变更。

## 结果
- 编译期：book 不再 `import` `learning_favorites_state.dart` / `new_words_state.dart`；仅依赖 `core/learning`。
- 运行期：`context.watch<LearningFavoritesStore>()` / `watch<NewWordsStore>()` 经 proxy 拿到与具体状态同一实例，通知传播正常（响应式不回归）。

## 质量门
- `flutter analyze` → `No issues found!`（exit 0）
- `flutter test` → `00:30 +387: All tests passed!`（含新增 2 例）

## 后续（设计见 ws6_design_learning_core_contracts.md）
- C3：`LearningSessionStarter`（book 启动学习动作）。注意 `LearningSessionState` 被 ~13 文件消费，本轮**不动**其本体，仅收敛启动动作，避免大杂烩。
