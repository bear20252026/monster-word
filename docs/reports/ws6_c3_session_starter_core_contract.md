# WS-6 C3: 「启动会话」动作提升为共享 core 契约（只写不读）

> 目标：book 词书页的「开始学习」不再触碰可变会话状态 `LearningSessionState`，改为只依赖 `lib/core/learning` 的只写契约 `LearningSessionStarter`。
> 规则同 C1 `LearningFavoritesStore`、C2 `NewWordsStore`：features 只 import core 契约，由 learning 功能域暴露实现。

## 变更
1. **新 core 契约** `lib/core/learning/learning_session_starter.dart`
   - `abstract class LearningSessionStarter`（**非** `ChangeNotifier`，纯动作契约）。
   - `Future<void> startBookSession(Book book, {int? limit, bool shuffle = true})`。
   - 只写不读：调用方只发起“启动会话”，不读取会话来推进/翻卡等。
2. **learning/data 适配器** `lib/features/learning/data/learning_session_starter_impl.dart`
   - `class LearningSessionStarterImpl implements LearningSessionStarter`，内部 hold 一个 `LearningSessionState`。
   - `startBookSession` → `_session.loadBook(book, limit: limit, shuffle: shuffle)` 原先样委托。
3. **learning feature scope 暴露** `learning_feature_providers.dart`
   - 在 `LearningSessionState` 之后新增
     `ProxyProvider<LearningSessionState, LearningSessionStarter>(update: (_, s, _) => LearningSessionStarterImpl(s))`。
   - 因为输出 `LearningSessionStarter` **非 Listenable**，普通 `ProxyProvider` 即可（不会有 C2 的 Listenable 断言问题）。
4. **book 改用契约** `book_words_page.dart`
   - `_startLearning`：`final session = context.read<LearningSessionState>(); await session.loadBook(book, limit: 50);`
     改为 `await context.read<LearningSessionStarter>().startBookSession(book, limit: 50);`。
   - 删除 `import ...learning/presentation/learning_session_state.dart`，改 import core 契约。
5. **测试对齐** `book_words_page_fab_test.dart`
   - 两处 `ChangeNotifierProvider<LearningSessionState>.value(spySession)` 之后补
     `ProxyProvider<LearningSessionState, LearningSessionStarter>(update: (_, s, _) => LearningSessionStarterImpl(s))`；
     生产装配与测试装配一致。FAB 断言依旧走 `spySession.loadBook` 计数（委托可穿透）。
6. **新增测试** `test/features/learning/data/learning_session_starter_contract_test.dart`（2 例）
   - `_SpySession extends LearningSessionState` 记录 `loadBook` 参数（不透传 super 避免真实副作用）。
   - 验证 `startBookSession` 原样转发 book / limit / shuffle；省略 option 时用会话缺省值（limit=null, shuffle=true）。
   - 由于 `LearningSessionState` 构造器会读 `UserPreferences`/`shared_preferences`，`setUp` 内
     `SharedPreferences.setMockInitialValues({})` + `TestWidgetsFlutterBinding.ensureInitialized()`。

## 关键设计取舍：为什么用独立适配器而非 Session 自身实现契约
- `LearningSessionState` 是承载大量可变状态的对象（被 ~13 个文件消费）。设计约定“本轮不动其本体”，且
  “features 只依赖 core 契约”。
- 若让 `LearningSessionState implements LearningSessionStarter` 并复用同一实例（`update: (_, s, _) => s`），
  会触发 C2 的同款 Listenable 断言——运行时 `s` 仍是 `ChangeNotifier`，`ProxyProvider` 拒绝；而
  `ListenableProxyProvider` 要求输出 `R extends Listenable?`，`LearningSessionStarter` 不满足，编译不过。
- 因此用独立、非 Listenable 的 `LearningSessionStarterImpl` 包装会话，输出可控且无断言；这也让
  “只写动作”与“可读可变状态”在类型上清晰分离（动作契约**不含任何读取面**）。

## 质量门
- `flutter analyze` → `No issues found!`
- `flutter test` → `00:27 +389: All tests passed!`（含新增 2 例）

## 后续
- WS-3 import_guard（临时搁置，待 UI/链路收尾后统一做依赖守卫）。
