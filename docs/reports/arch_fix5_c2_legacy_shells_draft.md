# ARCH-FIX-5 / C2：`lib/pages|screens` 遗留业务壳迁移（READINESS DRAFT — 未开工）

> 状态：🟢 观察项，**尚未开工**。本文为 LEAD 可行性摸底 + 方案草案，供拍板。执行前需 LEAD 出拆分卡并派发，且不擅自改产品代码。

## 1. 背景
- `lib/pages/**` 共 60 个页面文件、`lib/screens/**` 3 个顶层组合屏（home_screen/learn_session/profile_screen）。
- 目标：把仍由 `lib/pages|screens` 承载的业务壳迁入对应 feature 四层（presentation/domain/application/data），消除 `pages/` 作为“第二个展示包”的残留耦合（C2 债）。

## 2. 摸底结论（影响迁移成本）
### 2.1 分档
- **T1 纯 re-export 垫片（机械迁移，低风险）**：至少 14 个文件只是
  `export '../features/<f>/presentation/<page>.dart'`——如
  `check_in_history/class_checkin→features/checkin`、`login/splash/account_info/my_space/user_info→features/account`、
  `settings/more_settings→features/settings`、`books→features/book`、`search→features/search`、
  `dictionary→features/dictionary`、`scare_coin_history→features/scare_coin`、`exam_quick_review→features/quick_review`。
  迁移 = **删垫片 + 把所有 `import '../pages/<x>.dart'` 指向 feature 路径**。
- **T2 仍含真实实现/直连逻辑（需逐页迁移）**：如 `learn_page`（直接 import learning 状态）、`review_page`（import dictionary_page）、`dictation_session_page`/`spell_session_page`/`word_machine_page`/`listening_player_page` 等仍持有页面实现，且可能直接依赖 legacy data/repo。这些是真正的“业务壳”，需搬进对应 feature 四层并走 feature-scoped port。
- **Screens**：`home_screen/learn_session/profile_screen` 是顶层组合，自身可保留或归位，但都引用了 `../pages/*` 垫片（home→learn_page/lib_select/search/word_machine；learn_session→word_detail；profile→appearance/more_settings），迁移时需一并 repoint。

### 2.2 repoint 成本（改动面）
- 路由：`lib/core/router/{account,learning,content}_routes.dart`（account 21 / learning 21 / content 8 处 `../pages/*`）
- 组装根：`lib/app/app.dart`（import `lib_select_page`）
- 组合屏：`lib/screens/*`（5 处）
- 组件：`lib/widgets/review_dialog.dart`（→review_page）
- 页面互引：`lib/pages/*` 之间（appearance→immersive_swipe、lib_select→dictation/quick_spell/word_export、review→dictionary）
- 测试：`test/pages/*` 中按页面名 pump 的用例

## 3. 风险评估
- **import_guard 是硬门禁**：把 legacy 页面移入 feature 后，若仍跨 feature 引内部（如 review→dictionary、learn→learning 内部），会触发“依赖边界违规”。因此 C2 大概率会**先暴露一批 cross-feature 违规**，需要逐条用 port/契约收敛。这正是 C2「低优先、⚠️ 不破坏当前门禁」的原因——当前 `lib/pages` 作为外围壳未被 feature 边界规则覆盖。
- 路由/组装根是大流量改动，需全量回归 + import_guard 0 才能合入。

## 4. 推荐推进方式（若选 A）
- 按 feature 拆分卡片，**逐 feature 收敛**（每卡只动该 feature 的 shim/business-shell + 对应 port/依赖，独立跑门禁）：
  1. C2-account / C2-settings / C2-scare_coin / C2-checkin / C2-book / C2-search / C2-dictionary / C2-quick_review（T1 垫片，优先、机械）
  2. C2-learning-shell（learn/review/dictation/spell/word_machine 等 T2，先补 feature-scoped port，再搬页）
  3. C2-content（immersive_swipe/my_content/my_fav/sentence_detail/word_detail 等）
  4. C2-screens 归位 + 清空 `lib/pages|screens`（最后，删除整个旧包）
- 每卡门禁：`flutter analyze 0` + `flutter test 全量` + `import_guard_test 0`。

## 5. 结论 / 建议
C2 **可行但体量大**：T1 垫片收敛占大头且低风险；T2 真实业务壳才是难点，且会牵出跨 feature 违规需端口化收敛。**建议由 LEAD 出拆分卡逐 feature 派发**，不整包一次性做。若当前优先级转向发布/验收/新功能，C2 可继续挂 🟢 观察。

> 本文件为草案，不含任何产品代码改动；未跑门禁（无代码变化）。执行前请确认 A/B/C。
