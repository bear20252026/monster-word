# WS-3: 依赖边界守卫 import_guard（接入 + 清零违规）

> 目标：把《TEAM_COLLABORATION_FRAMEWORK.md》§2 的手写依赖断言升级为一条**可数据驱动的 import 守卫**，
> 并让整个 `lib/**/*.dart` 通过该守卫（零违规）。
> 归属：`lib/core/import_guard.dart` + `test/architecture/import_guard_test.dart`（lead 独占 core/）。

## 交付物
1. **`lib/core/import_guard.dart`** —— 纯 Dart、无 IO、无 Flutter 的**规则引擎**。
   - `const ImportGuard()`，方法 `List<String> check({required String from, required String to})`。
   - 输入为 `lib/` 相对逻辑路径（如 `features/account/presentation/x.dart`、`core/scare_coin/...`）；
     外部依赖保留前缀（`package:flutter/...`、`dart:...`），仅受 R5 领域纯净规则约束。
   - 编码规则：
     - **R4 跨功能隔离**：`features/<A>/**` 不得 import `features/<B>/**`（A≠B）。
     - **R-core**：`core/**` 不得 import `features/**`。
     - **R3 分层只向内**（同一 feature 内）：domain 不得依赖 application/data/presentation；
       application 不得依赖 data/presentation；data 不得依赖 presentation。
     - **R5 领域纯净**：domain 不得依赖 `package:flutter/*` / `dart:ui`。
2. **`test/architecture/import_guard_test.dart`** —— 9 例。
   - 8 例：对上述每条规则的**纯逻辑单测**（含正例：同功能内部、feature→core/models、legacy→feature）。
   - 1 例：**全库扫描 harness** —— 遍历 `lib/**/*.dart`，解析 `import`/`export`（含相对 → 逻辑路径），
     喂给 `ImportGuard`，断言零违规；违规时输出每条位置便于修复。
   - 该 harness 让依赖边界成为可回归的 **CI 门禁**，取代手写断言（`app_structure_test.dart` 仍在但仅作行为级约束）。

## 为让守卫通过所做的收口（溯源 → 接入）
扫描发现并清零两类违规：
1. **R4 跨功能违规**：`ScareCoinStore` 被 account / checkin / 多页共享，原先散落在
   `features/scare_coin/application/`。按 WS-6 契约范式提升为**共享 contract**：
   - `lib/core/scare_coin/scare_coin_store.dart`（接口，含 `checkInReward/balance/chainDates/streak/history/...`）。
   - `ScareCoinEntry`（领域值对象）下沉 `lib/models/scare_coin_entry.dart`。
   - 清理孤儿文件：`features/scare_coin/application/scare_coin_store.dart`、
     `features/scare_coin/application/scare_coin_entry.dart`、`features/scare_coin/domain/scare_coin_entry.dart`。
   - 改造消费方：account / checkin / scare_coin 内部 / dashboard / profile_screen /
     spring_check_in_calendar 等一律改 import `core/scare_coin/...` 与 `models/scare_coin_entry.dart`。
2. **R3 分层违规**：`features/learning/data/learning_session_starter_impl.dart` 反向依赖
   `presentation/learning_session_state.dart`。因该适配器属**组合根**（包装展示层状态），
   移到 `features/learning/presentation/learning_session_starter_impl.dart`，相应更新
   `learning_feature_providers.dart`、`book_words_page_fab_test.dart`、
   `learning_session_starter_contract_test.dart` 的 import。

## 质量门
- `flutter analyze` → `No issues found!`
- `flutter test` → `00:30 +398: All tests passed!`（新增 import_guard 9 例）
- 全库 import 扫描 → **0 依赖边界违规**（R3/R4/R5 + core 纯净）。

## 说明
- `ImportGuard` 保持纯净可单测（不做文件 IO）；文件遍历/URI 解析放在测试 harness，便于在 CI 中原样运行。
- legacy 薄适配（`lib/pages/*` 仅 re-export feature 页面）视为允许 —— R4 只针对 feature 之间，
  `lib/pages` 不作为规则源，避免误伤既有路由适配层。
