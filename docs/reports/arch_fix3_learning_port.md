# ARCH-FIX-3 状态报告：learning 展示层端口化

## 当前进度

### ✅ 已完成（源码 0 error）

**新建端口（application 层）**：
- `lib/features/learning/application/learning_queue_port.dart` — 队列加载端口
- `lib/features/learning/application/learning_progress_port.dart` — 进度持久化端口（含 `LearningProgress` DTO）
- `lib/features/learning/application/review_schedule_writer_port.dart` — 评分/遗忘写端口
- `lib/features/learning/application/choice_generator_port.dart` — 选项生成端口
- `lib/features/learning/application/favorites_port.dart` — 收藏端口
- `lib/features/learning/application/mastered_writer_port.dart` — 掌握写端口
- `lib/features/learning/application/new_words_writer_port.dart` — 生词写端口

**新建适配器（data 层）**：
- `lib/features/learning/data/repository_learning_queue_port.dart`
- `lib/features/learning/data/repository_learning_progress_port.dart`
- `lib/features/learning/data/repository_review_schedule_writer_port.dart`
- `lib/features\learning/data/repository_choice_generator_port.dart`
- `lib/features/learning/data/repository_favorites_port.dart`
- `lib/features/learning/data/repository_mastered_writer_port.dart`
- `lib/features/learning/data/repository_new_words_writer_port.dart`

**展示层重构**：
- `learning_session_state.dart` — 构造注入 4 个端口（queuePort/progressPort/reviewSchedulePort/choicePort），去掉 `data/learning_progress_repository.dart`、`learning_queue_repository.dart`、`review_schedule_repository.dart`、`domain/choice_generator.dart` 四个直连 import
- `learning_favorites_state.dart` — 构造注入 `FavoritesPort` + `LearningQueuePort`，去掉 `lib/repositories/fav_repository.dart` 直连
- `new_words_state.dart` — 构造注入 `NewWordsWriterPort`，去掉 `lib/repositories/new_word_repository.dart` 直连
- `learning_mastered_state.dart` — 构造注入 `MasteredWriterPort`，去掉 `lib/repositories/mastered_repository.dart` 直连
- `review_word_actions_state.dart` — 构造注入 `FavoritesPort` + `MasteredWordsReader` + `MasteredWriterPort`，去掉两个 `lib/repositories/*` 直连

**DI 装配**：
- `learning_feature_providers.dart` — 全部 7 个端口经 adapter 注册为 Provider
- `service_locator.dart` — `NewWordsWriterPort` 已注册

### ❌ 未完成（测试适配，约 80 error）

以下测试文件仍需同步构造注入（已写好 mock 类在 `book_words_page_fab_test.dart`，但部分旧构造未改完）：

| 文件 | 问题 |
|---|---|
| `test/features/book/presentation/book_words_page_fab_test.dart` | `SpyLearningSessionState` 超类构造未传端口 |
| `test/features/book/presentation/book_words_page_navigation_test.dart` | `LearningFavoritesState`/`NewWordsState` 构造未传端口 |
| `test/features/learning/data/learning_session_starter_contract_test.dart` | `LearningSessionState` 构造未传端口 |
| `test/features/learning/presentation/learn_page_regression_test.dart` | `LearningSessionState` 构造未传端口 |
| `test/features/learning/presentation/learning_collections_state_test.dart` | `LearningFavoritesState`/`NewWordsState`/`LearningMasteredState` 构造未传端口 |
| `test/features/learning/presentation/learning_session_state_test.dart` | `LearningSessionState`/`LearningFavoritesState`/`NewWordsState`/`LearningMasteredState` 构造未传端口 |
| `test/features/learning/presentation/new_words_state_test.dart` | `NewWordsState` 构造未传端口 |
| `test/features/learning/presentation/review_word_actions_state_test.dart` | `ReviewWordActionsState` 构造未传端口 |
| `test/pages/word_detail_fix3_test.dart` | `LearningSessionState` 构造未传端口 |
| `test/pages/word_detail_phrase_root_test.dart` | `LearningSessionState` 构造未传端口 |
| `test/widgets/review_dialog_test.dart` | `LearningSessionState` 构造未传端口 |

### 判定

- `flutter analyze`：源码 0 error，仅测试有 error（约 80 处，全部是构造参数未传/参数名废弃）
- `import_guard_test.dart`：未跑，但源码层 import 方向已正确（presentation → application → data/domain）
- 三件套：未 commit/push（按要求）

## 卡点说明

改动范围聚焦 learning 未扩到其它 feature。卡点是测试文件数量多（11 个），每个需要：
1. 添加 port mock 类
2. 替换构造参数（端口名 + mock 实例）
3. 部分测试（如 `SpyLearningSessionState`）需要额外改超类调用

源码层已全部完成，端口/适配器/装配/展示层均已对齐。剩余工作纯为测试同步，不涉及新设计。
