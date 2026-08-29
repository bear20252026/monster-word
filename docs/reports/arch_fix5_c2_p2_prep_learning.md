# ARCH-FIX-5 / C2-P2 准备 — Learning 域 Repoint 清单

> 只读梳理，不改代码。列出 `lib/features/learning/**` 中所有仍 import `lib/pages/<页>` 的发生点，以及需 P2 一并处理的外部引用。

## 1. `lib/features/learning/` 内部 → `lib/pages/` 直接 import（7 处）

| # | 文件:行 | 当前 import | P2 repoint 目标 |
|---|---|---|---|
| 1 | `presentation/learn_page.dart:12` | `import '../../../pages/word_detail_page.dart';` | `import '../../dictionary/presentation/word_detail_page.dart';` |
| 2 | `presentation/mastered_words_page.dart:10` | `import '../../../pages/list_words_page.dart';` | `import 'list_words_page.dart';`（随基类迁入后同目录） |
| 3 | `presentation/my_words_page.dart:10` | `import '../../../pages/list_words_page.dart';` | `import 'list_words_page.dart';` |
| 4 | `presentation/new_words_page.dart:11` | `import '../../../pages/list_words_page.dart';` | `import 'list_words_page.dart';` |
| 5 | `presentation/not_learned_words_page.dart:10` | `import '../../../pages/list_words_page.dart';` | `import 'list_words_page.dart';` |
| 6 | `presentation/reviewing_words_page.dart:10` | `import '../../../pages/list_words_page.dart';` | `import 'list_words_page.dart';` |
| 7 | `presentation/review_page.dart:15` | `import '../../../pages/dictionary_page.dart';` | `import '../../dictionary/presentation/dictionary_page.dart';` |

## 2. `lib/pages/` 中仍需迁移的页面（被 learning 依赖）

| 页面 | 当前状态 | 依赖方 | P2 处理方式 |
|---|---|---|---|
| `list_words_page.dart` | **真实实现**（抽象基类，约 300 行） | 5 个 learning 页面（#2-#6） | 迁入 `lib/features/learning/presentation/list_words_page.dart`，lib/pages 改 shim |
| `word_detail_page.dart` | ✅ 已是 shim → `features/dictionary/` | 见 §3 | 仅 repoint，无需迁移 |
| `dictionary_page.dart` | ✅ 已是 shim → `features/dictionary/` | review_page.dart（#7） | 仅 repoint，无需迁移 |

## 3. 外部对 `lib/pages/word_detail_page.dart` 的引用（P2 需一并 repoint）

| 文件:行 | 所属模块 | repoint 目标 |
|---|---|---|
| `lib/core/router/content_routes.dart:10` | router（禁改，但 P2 可动） | `../../features/dictionary/presentation/word_detail_page.dart` |
| `lib/features/book/presentation/book_words_page.dart:11` | book feature | `../../dictionary/presentation/word_detail_page.dart` |
| `lib/screens/learn_session.dart:19` | screens（legacy） | `../../features/dictionary/presentation/word_detail_page.dart` |
| `lib/features/learning/learning/presentation/learn_page.dart:12` | learning（见 #1） | `../../dictionary/presentation/word_detail_page.dart` |

> ⚠️ `content_routes.dart` 在 P1 禁改名单，P2 需协调处理。

## 4. Legacy data/repo 直连（ARCH-FIX-3 后续，P2 可顺带）

| 文件:行 | 当前 import | 说明 |
|---|---|---|
| `data/learning_progress_reader_impl.dart:3` | `import '../../../repositories/mastered_repository.dart';` | 直连 legacy repo |
| `data/learning_progress_repository.dart:5` | `import '../../../data/wordbook_database.dart' show Book;` | 直连 legacy data |
| `data/learning_queue_repository.dart:1` | `import '../../../data/wordbook_database.dart' show WordBookDatabase;` | 直连 legacy data |
| `data/learning_queue_repository.dart:4` | `import '../../../repositories/fav_repository.dart';` | 直连 legacy repo |
| `data/repository_book_words_reader.dart:2` | `import '../../../repositories/word_repository.dart';` | 直连 legacy repo |

## 5. Legacy `core/learning/` store 直连（ARCH-FIX-3 后续）

| 文件:行 | 当前 import |
|---|---|
| `presentation/learning_feature_providers.dart:5` | `import '../../../core/learning/learning_favorites_store.dart';` |
| `presentation/learning_feature_providers.dart:7` | `import '../../../core/learning/learning_session_starter.dart';` |
| `presentation/learning_feature_providers.dart:8` | `import '../../../core/learning/new_words_store.dart';` |
| `presentation/learning_favorites_state.dart:5` | `import '../../../core/learning/learning_favorites_store.dart';` |

## 6. Legacy `engine/` 直连（review 状态机）

| 文件:行 | 当前 import |
|---|---|
| `presentation/review_session_state.dart:3` | `import '../../../engine/core_engine.dart' show WordChoicePair;` |
| `presentation/review_session_state.dart:4` | `import '../../../engine/srs_engine.dart' show RecallRating;` |
| `presentation/review_session_state.dart:5` | `import '../../../engine/super_memory_engine.dart';` |
| `presentation/widgets/formal_review_choice_card.dart:3` | `import '../../../../engine/core_engine.dart' show WordChoicePair;` |
| `presentation/widgets/formal_review_question.dart:3` | `import '../../../../engine/core_engine.dart' show WordChoicePair;` |

## 7. Legacy `state/` 直连

| 文件:行 | 当前 import |
|---|---|
| `presentation/review_page.dart:16` | `import '../../../state/wallpaper_state.dart';` |

---

## 优先级建议

| 优先级 | 范围 | 工作量 |
|---|---|---|
| **P2-A** | §1 + §2：repoint 7 处 `pages/` import + 迁移 `list_words_page.dart` 基类 | 小（机械 repoint + 1 文件迁移） |
| **P2-B** | §3：repoint `word_detail_page.dart` 外部 4 处引用 | 小（纯 repoint，但含 1 个禁改文件需协调） |
| **P2-C** | §4 + §5 + §6 + §7：legacy data/repo/engine/state 直连解耦 | 中（需引入端口/适配器，按 ARCH-FIX-3 模式） |

## 备注

- 所有 `lib/features/learning/` 对 `lib/pages/` 的 import 仅集中在 `presentation/` 层（7 处），data 层无 `pages/` 直连。
- `list_words_page.dart` 是唯一的「被 learning 依赖但仍驻 lib/pages 的真实实现」，且仅被 learning 使用，应迁入 learning 特征。
- 无 learning → 其他 feature 的 `features/<x>/` 反向 import（无跨 feature 污染）。
