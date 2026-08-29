# 架构耦合审计报告（Architecture Coupling Audit）

> 目标（用户要求）：**架构科学清晰、不混乱；降耦合；用渠道化（port/adapter + 依赖注入）连接；增强可维护性**。
> 方法：全库 import 扫描 + 对照 `TEAM_COLLABORATION_FRAMEWORK.md`（R1-R8）与 `lib/core/import_guard.dart`（R3/R4/R5/R6）。
> 结论分级：🔴 违规（破坏门禁/明确 R4）、🟡 耦合债（可维护性风险）、🟢 观察项。只读审计，未改任何 lib/。

---

## 一、🔴 现存违规（ImportGuard 覆盖范围内，= 当前门禁被破坏）

### A1. R4 跨 feature 展示层 import（settings → account）
- **位置**：`lib/features/settings/presentation/more_settings_page.dart:9`
  `import '../../../features/account/presentation/app_session_state.dart';`
- **从** `features/settings/presentation/more_settings_page.dart`（feature=settings, layer=presentation）
  **到** `features/account/presentation/app_session_state.dart`（feature=account, layer=presentation）
  → 满足 import_guard R4：`跨功能 import 被禁止(R4)`。
- **根因**：WS-2 settings 迁移时，`more_settings_page` 为读登录态/占位，直接 import 了 account 的 presentation 状态。
- **影响**：① 全库 import_guard 扫描 0 违规的门禁被打破（CI 红灯）；② settings→account 展示层强耦合，改 account 状态会波及 settings。
- **修复（渠道化）**：把 `AppSessionState` 的「登录态」读能力提升为 `core/` 共享契约（如 `core/auth/app_session_reader.dart`），settings 经契约读取；或由 `app/` 装配层注入，禁止 settings import account 内部。

---

## 二、🟡 耦合债（R6 直连遗留仓储 / 展示层直连 data）

### B1. 多个 feature 的 `*_feature_providers.dart` 直接 import 遗留 `repositories/`、`data/`
这些是组合根（composition root），把遗留仓储当 data 实现接入，但**跨入 `lib/repositories/*`、`lib/data/*` 遗留层**，而非 feature 自身的 `data/repository_*`；未走干净 port 抽象，repositories 层仍是全项目共享大杂烩。

| 位置 | 遗留直连 |
|------|---------|
| `features/book/presentation/book_feature_providers.dart:6` | `../../../repositories/book_repository.dart` |
| `features/quick_review/presentation/quick_review_feature_providers.dart:5` | `../../../repositories/word_repository.dart` |
| `features/word_browse/presentation/word_browse_feature_providers.dart:5-6` | `../../../repositories/fav_repository.dart`、`note_repository.dart` |
| `features/search/presentation/search_feature_providers.dart:6-7` | `../../../data/app_preferences.dart`、`../../../repositories/word_repository.dart` |
| `features/learning/presentation/learning_feature_providers.dart:9-10` | `../../../repositories/fav_repository.dart`、`mastered_repository.dart` |
| `features/dictionary/by_name_page`、`book/data/repository_book_words_reader`、`search/data/*`、`checkin/data/*` 等 | `../../../data/wordbook_database.dart`、`user_database.dart`、`repositories/*` |

- **影响**：`repositories/`、`data/` 仍是「全局共享层」，feature 经它间接耦合；改某个 repository 会波及多个 feature。违反框架 §3 迁移方向（`data/ repositories/ → features/<f>/data`）。
- **修复方向**：把各 feature 用到的遗留仓储逻辑迁移/薄适配进 `features/<f>/data/`，presentation 只经 `application/*_reader|writer`（port）触达；repositories/ 逐步清空递减。

### B2. 展示层状态直连本 feature 的 data/domain
| 位置 | 直连 |
|------|------|
| `features/learning/presentation/learning_session_state.dart:9-12` | `import '../../../features/learning/data/learning_progress_repository.dart'`、`learning_queue_repository.dart`、`review_schedule_repository.dart`、`domain/choice_generator.dart` |
| `features/learning/presentation/{learning_favorites_state,new_words_state,learning_mastered_state,review_word_actions_state}.dart` | `../../../repositories/*` |

- **影响**：presentation 状态直接 new/读 data 实现，绕过 application port；状态层与存储耦合，难 mock 难测。
- **修复方向**：状态经 `application/*_reader|writer`（port）访问；data 实现由 feature_providers 注入。`learning_session_state` 改为依赖 `LearningProgressReader`/收藏/生词等 core 契约或 feature port。

---

## 三、🟢 观察项

### C1. Provider 嵌套 11 层（app.dart:36-64）
`WordAudio→Account→Learning→Settings→Search→QuickReview→Book→ScareCoin→CheckIn→Dictionary→WordBrowse→MultiProvider`。
- **影响**：组合根深、`context.read` 跨层查找成本上升、新增 scope 要插到正确层级（易错）；与「渠道化、可维护」冲突。
- **🔍 2026/8/29 跨 scope 类型冲突预分析（只读结论）**：
  - **无任何跨 scope 同名类型冲突**。逐一核验：各 scope 提供的类型（AppSessionController/AppSessionState、BookCatalogReader、BookWordsReader、BookState、WordSearchReader、SearchHistoryStore、ExampleReader、FavoritesAccessor、WordNotesStore、SentenceFavoritesStore、QuickReviewWordReader、CheckInHistoryReader、CheckinStatusReader、CheckinWriter、LearningPreferencesState、ScareCoinStore、Dictionary*Reader/Writer、Learning*Store/Reader/State 等）**类名全部唯一**，无两个 scope 提供同一 `Provider<T>` 的 T。
  - **⚠️ 同名易混淆但非同型**：`learning/application/book_words_reader.dart`（`abstract interface class BookWordsReader`，`loadWords(int bookId)`）与 `book/application/book_words_reader.dart`（`abstract class BookWordsReader`，`loadWords(int bookId,{limit,offset})`）是**两个不同类**，各有 `RepositoryBookWordsReader` 实现，互不冲突（local：learning 侧被 service_locator/lib_select/word_export 等消费，book 侧仅供 book_state）。→ 命名重复是**可维护性小瑕疵**（建议后续统一命名/对齐 API），但不构成 C1 阻断。
  - **🔍 嵌套是真实依赖 DAG，非无序堆积**：book 必须在 learning 内层（消费 learning 祖先的 `LearningProgressReader`，WS-4 G3.2）；checkin 必须在 scare_coin 内层（消费其 `ScareCoinStore`，XP-FIX-5 已把 scare_coin 移到 checkin 外层）；search 的 `FavoritesAccessor` 也依赖 learning 祖先。**ancestor = 上游渠道**，嵌套方向即依赖方向。
- **C1 正解（待 ARCH-FIX-2/3 收敛后实施）**：**不扁平化**。理由：扁平到单个 `MultiProvider` 虽无类型歧义，但会把所有 feature provider 抬为同层，使任何 widget 都能 `context.read` 到任何 feature 的 provider → **全局可达性上升 = 耦合上升**，与降耦合目标相反；同时丢失嵌套方向（=渠道方向）语义。正确做法：**保留嵌套作为显式依赖 DAG**，在 `lib/app/app.dart` 为每层加语义注释「为何该 scope 在此层」（消除「混乱」观感）、并在 `docs/reports/arch_coupling_audit.md` 注明各层依赖关系；如确要降层级，仅把无层间依赖的 scope（WordAudio/Skin/Wallpaper/字典等）并入根级扁平 `MultiProvider`，保留 mutual/ancestor 依赖 scope 的嵌套。

### C2. `lib/pages/`、`lib/screens/` 遗留业务壳
`app.dart` 仍 `import '../pages/lib_select_page.dart'`、`'../screens/home_screen.dart'`、`'../screens/profile_screen.dart'`（app.dart:17-19）——部分页面已迁 feature，仍有壳残留（R1 目标：pages/screens 渐减）。属框架 §3 迁移方向，非新违规。

---

## 四、修复派工（decomposed；按会合后顺序派发，避免与 UX 修复同文件并发）

> ⚠️ 序列化纪律：当前 4 张 UX-FIX 卡（A/B/C/D）在推进中。**架构修复派到 UX 修复落地之后再发**，避免同文件并发；且跨切面（core）串行（R14）。

| 卡 | 修复项 | 文件 | 建议 owner | 前置 |
|----|--------|------|-----------|------|
| ARCH-FIX-1 | ✅ 已完成（commit `f7b28bc`）：A1 settings→account R4 解耦 + 登录态 core 契约（`lib/core/auth/app_session_controller.dart`，settings 经契约读取，account 经 ProxyProvider 以同实例暴露） | `features/settings/**`、`features/account/**`、`lib/core/auth/**` | 2163(lead 代做) | 已交付 |
| ARCH-FIX-2 | B1 遗留 repositories 直连 → feature data 薄适配（book/quick_review/word_browse/search 的 providers） | 各 `features/<f>/data/**` + `repositories/**` 递减 | 3061 | 🟨 已派发（task `01a04b2c-767b-77e3-9ca3-f3dd33c2ac1d`，in_progress；settings 残留已在 ARCH-FIX-1 处理） |
| ARCH-FIX-3 | B2 展示层状态改经 port（learning_session_state 等） | `features/learning/**` | 2903 | 🟨 已派发（task `01a04b2c-76d9-7f53-9c27-69d5f449e165`，pending） |
| ARCH-FIX-4 | C1 provider 嵌套 11 层 → 保留嵌套作显式依赖 DAG + 语义注释 + 可选根级扁平（**不整体扁平化**） | `lib/app/app.dart`（lead 主导，core 归 lead） | lead | ⏸️ 排队：**待 ARCH-FIX-2/3 收敛后**再实施。预分析结论（见 C1）：① 无跨 scope 同名类型冲突，但扁平到单 `MultiProvider` 会抬高全局可达性=耦合↑（与降耦合相反），故反对整体扁平；② 嵌套实为真实依赖 DAG（book→learning、checkin→scare_coin、search→learning），ancestor=上游渠道；③ ARCH-FIX-2/3 正改写相关 providers，同文件并发冲突，须串行。 |

> 每次改动后：`flutter analyze` 0 error + 相关 test 全绿 + `import_guard_test.dart` 全库扫描 **0 违规**（这是本项目架构健康的硬门禁）。

---

## 五、架构健康门禁（本轮起强制执行）

1. `flutter test test/architecture/import_guard_test.dart`：全库扫描 **0 违规**（A1 现破坏此门禁，须最先修）。
2. `flutter analyze` 0 error。
3. `flutter test` 全量通过（不破坏既有测试）。
