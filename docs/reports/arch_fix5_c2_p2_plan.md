# ARCH-FIX-5 / C2-P2 收尾方案（lead 规划）

> 状态：**lead 已规划**。执行前置 = P1d（3061）交回，全部 `lib/pages/*.dart` 变为 re-export 垫片。
> 红线：P2 是**串行**阶段。P1 并行把逻辑迁进 feature，P2 才能安全地 repoint import + 删 shim + 更新测试 + 跑全量门禁。
> 本文只规划；实际执行由 lead 亲自串行完成（不开并行 teammate），或由单一 TEAMMATE 发起并经 lead 复核。

---

## 0. 目标

彻底消除 `lib/pages/*` 与 `lib/screens/*` 里的「遗留真壳」，让所有业务页面只存在于 `lib/features/<feature>/presentation/`；`lib/pages` 的 `export` 垫片删除；`import_guard`（R1/R3/R4/R5）0 违规；`app_structure_test` 改读 feature 源。

## 1. 前置事实（已实测确认）

- P1 全部分支已把逻辑迁入 feature，`lib/pages` 现为**纯 export 垫片**（除 infra 外）。经 Grep `^export ` vs `^import ` 实测（P1d 落地后）：
  - **已迁为垫片**：50 个（books/account_info/check_in_history/class_checkin/courses/dashboard/... 全表见 disk）。
  - **仍为真壳（P1d 后仅 2 个 infra）**：base_web / uri_scheme。其余 9 个 P1d 已迁成垫片（appearance / user_item_modify / wallpaper_select / sms / class_activity / list_words / spell_check / collins_detail_intro）+ book_words（**保留为 router adapter**，非垫片）。
  - base_web / uri_scheme 属 **infra**（webview 基类 + 深层链处理），P2 应归 `lib/core/web/` / `lib/core/router/`，不进 feature。

### ⚠️ P1d 落地后的归属争议（lead 已决策）
- **`list_words_page.dart`（抽象基类）**：P1d 迁入 `lib/features/book/presentation/list_words_page.dart`，但其 5 个使用者全是 **learning** 页面（mastered_words / my_words / new_words / not_learned_words / reviewing_words_page）。P2 若把 learning 的 import repoint 到 book 将**违反 R4 跨 feature import**。
  - **lead 决策**：基类归属 **learning** → `lib/features/learning/presentation/list_words_page.dart`。P2 执行时把该文件从 `features/book/presentation/` 移到 `features/learning/presentation/`，`lib/pages/list_words_page.dart` 垫片改为 export learning 版。
- **learning 内的跨 feature 引用（P2 必须处理，且不违反 R4）**：
  - `lib/features/learning/presentation/learn_page.dart` → `../../../pages/word_detail_page.dart`（真源 = `features/dictionary/presentation/word_detail_page.dart`）。
  - `lib/features/learning/presentation/review_page.dart` → `../../../pages/dictionary_page.dart`（真源 = `features/dictionary/presentation/dictionary_page.dart`）。
  - P2 需经**路由字符串 / 端口**解耦（走 RouteNames + Navigator），不得直接 import 跨 feature presentation，否则被 import_guard R4 拦截。 
- `test/architecture/app_structure_test.dart`（466 行）**大量 readAsStringSync 读取 `lib/pages/*.dart` 与 `lib/screens/*.dart` 源码做断言**（如 :44 `lib/state/learning_state.dart`、:51-67 `lib/pages/immersive_swipe_page.dart` 等 migratedPages、:74-75 book_words adapter+feature、:113 spell_session、:160 settings adapter、:185 word_detail、:203 exam_quick_review、:217 word_export、:257 my_fav_sentence、:300+ ports、:363 scare_coin page/dashboard/my_space、:401 review_page、:458 learning_routes）。 → **删 shim 前必须先把这些断言 repoint 到 feature 源**，否则门禁直接红。
- `lib/core/import_guard.dart`：R4 禁止跨 feature import；R3 分层向内；R-core core 不得反向依赖 features。**注意：尚未禁止 feature→pages、pages→core 等跨层 import**，因为 pages 顶层级不属于 feature 层。P2 里若保留任何 `pages/` 引用将绕过守卫，P2 应彻底清掉。

## 2. 执行步骤（串行）

### Step 1 — 快照 & 基线
1. `git status` 确认工作区干净（P1 已交回未 commit，P1d 也交回后），`git diff --stat` 记录本轮 P2 变更。
2. 记录 `git rev-parse HEAD` 作为基准提交点。

### Step 2 — 全量门禁基线（跑一次，拿"当前是否绿"）
```powershell
flutter analyze
flutter test
```
> 注意：P1 期间未跑全量（并行共享工作区）。P2 是串行独占，允许全量。若基线已红（如 P1 造成 app_structure_test 失败），先记录失败清单，作为 P2 必修项。

### Step 3 — 更新 app_structure_test 读取 feature 源（先做，防后续删 shim 崩）
逐个把测试里 `File('lib/pages/<x>.dart')` 的断言改为对应 `File('lib/features/<f>/presentation/<x>_page.dart')`。原则：
- 若断言的是「页面用某某 State/端口」→ 读 feature presentation 页。
- 若断言的是「lib/pages 是薄适配/纯 export」→ 保留对 lib/pages 的读取，但改为断言 `isNot(contains 业务逻辑)` 或删掉（P2 会删文件）。
- 若断言的是「某遗留栈已删除」（`existsSync isFalse`）→ 保持不变（这些是 P1 已验证的真删除）。
- 新增一条 `import_guard` 强断言：feature 内不得再 import `../../../pages/` 或 `../pages/`（防回潮）。

### Step 4 — repoint 所有 import 到 feature 路径（删 shim 的前提）
用 Grep 找到所有 `import '.../pages/<x>.dart'` 的地方（router / app / screens / widgets / 其它 feature），统一改为 feature 路径。注意：
- `lib/core/router/**`、`lib/app/app.dart` 这些**之前 P1 禁止动**的文件，**现在 P2 允许动**（它们是 import 的源头）。
- 相同页面可能被多处 import；导出符号（类名 / routeName）必须保持不变（shim 只是 re-export，类名没变，故 repoint 不破坏调用方）。
- 禁止新增跨 feature import（R4）；若 repoint 途中发现 A feature 要 import B feature 页面 → 必须走端口/路由字符串 / 迁到共享层，否则违反 import_guard。

### Step 5 — 删除 shim
删掉所有 `lib/pages/*.dart` 里纯 `export '../features/...'` 的垫片（P1 已迁的那 50 个）。保留：
- infra 类（base_web / uri_scheme）→ 迁到 `lib/core/web/` 或 `lib/core/deeplink/` 后删页（由 P1d 判定，若 P1d 已标 infra 则在 P2 move 到 core）。
- `lib/screens/**`：逐个检查，若只是壳也删；若是真正的多层导航容器（home_screen 等），评估是否重构为 feature 内或保留。
- **删除前**：`git grep "pages/<该文件>"` 确保 0 引用，否则会编译错。

### Step 6 — 清理目录
- `lib/pages/`、`lib/screens/` 清空后删除目录（若全空）。
- 若仍有未迁移残留（Grep `^import ` 发现有真实逻辑的 page）→ 回退到 Step 4 处理，绝不硬删。

### Step 7 — 全量门禁
```powershell
flutter analyze              # 0 issues
flutter test                 # 全绿
flutter test test/architecture/import_guard_test.dart   # 0 违规
```
- `import_guard_test` 是硬门禁，P2 改动后必须 0 违规。
- 若 `app_structure_test` 因删除 `lib/pages` 断言失败 → 回到 Step 3 补 repoint。

## 3. 判定（完成 = 四件套）
1. `flutter analyze` 0 error/0 info。
2. `flutter test` 全量全绿（含 app_structure_test / import_guard_test）。
3. `lib/pages/`、`lib/screens/` 已清理（或仅剩 LEAD 批准的 infra），`import_guard` 0 违规。
4. 报告 `docs/reports/arch_fix5_c2_p2.md`：Step 清单 + 改动 diff 概览 + 门禁结果。

## 4. 风险与回滚
- 最大的坑：**测试断言先于删 shim**。顺序不能反（Step 3 → Step 4 → Step 5）。
- 回滚：每步执行前 `git status`；若中途红，用 `git stash` 或 checkout 到 Step 基准点。**严禁 git reset --hard / force push。**
- 跨 feature import（R4）：这是新增 feature 边界后最容易暴露的问题，repaint 时发现即停，先问 lead 设计端口或归属。

## 5. 与设计规范任务的关系
本阶段是**纯架构（Coupling/Packaging）**收尾，与 UX-FIX-B（Apple/Claude 设计语言）正交。UX-FIX-B 是 doc 先行 + 主题预设，不影响 C2 的 import 边界。可并行推进，但 UX-FIX-B 若涉及删/改 theme/tokens 文件，须在 P2 全量门禁绿之后再动，避免混合改动。
