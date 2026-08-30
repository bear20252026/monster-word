# Monster Word 代码结构健康评估报告

> 评估日期：2026-08-30 ｜ 范围：lib/ 314 个 dart 文件（约 45,000 行）、test/ 653 用例
> 评估方式：架构评审 agent 全量扫描 + 关键文件人工抽查（行数均已复核）

## 总体判断

**架构骨架在同类项目中属上游水准**：分层清晰（features 内 presentation/application/data/domain）、
端口-适配器模式落地、有 import 守卫测试与架构测试锁边界、跨模块直接 import 全库仅 4 条且全部合法。
真正的债集中在**翻译迁移遗产**：两个巨型页面、双壳层共存、三套 DI 机制并存。均有低风险收敛路径。

---

## 🔴 高风险（2 项）

### H1. 巨型页面：word_detail_page.dart（1346 行，build() 约 766 行）
- **位置**：`lib/features/dictionary/presentation/word_detail_page.dart:143-909`
- **问题**：单 build() 堆积释义/音标/例句/词根/形近词/笔记/FSRS 统计 7 大块，内嵌 8 个私有组件类；5 处 setState 整树重建；文件内还有例句收藏+播放逻辑（应属 application 层）
- **影响**：无法局部复用与测试；任何改动都在最高冲突文件上
- **建议**：按区块拆 `_PhoneticSection`/`_ExamplesSection`/`_RootsSection` 等独立文件；笔记逻辑抽 `WordNotesState extends ChangeNotifier`（`word_notes_store.dart` 端口已备）；例句收藏挪入既有 `SentenceFavoritesStore`

### H2. 双壳层共存：遗留 `lib/screens/` 仍在主路由上
- **位置**：`lib/screens/home_screen.dart`（540 行）、`learn_session.dart`（803 行）、`profile_screen.dart`；引用点 `core/router/content_routes.dart:23`、`learning_routes.dart:47`、`app/app.dart`
- **问题**：新壳 `app/main_shell.dart` 已建但未接管全部入口；`learn_session.dart` 与 features/learning 的 38 个页面功能重叠
- **连带死代码**：`glass_widgets.dart`、`word_dictionary_popup.dart`、`spring_calendar.dart`、`spring_check_in_calendar.dart`、`testimonial_slider.dart`、`text_reveal_card.dart`、`daily_goal_picker.dart`、`review_dialog.dart` 8 个组件**仅被遗留壳层引用**
- **建议**：制定 screens/ → features/ 迁移清单与路由切换计划，完成后删除遗留壳层及 8 个伴生组件（约 -2000 行）

---

## 🟡 中风险（7 项）

### M1. 三套依赖注入机制并存
- **位置**：`core/di/service_locator.dart`（get_it，50 处 `sl<>`）/ 各 `*_feature_providers.dart`（MultiProvider）/ `app.dart` 顶层
- **建议**：立规——页面依赖走 Provider scope，跨 feature 基础设施走 get_it，写进 import_guard 注释

### M2. 组合根反向注册 presentation 对象
- **位置**：`core/di/service_locator.dart:38` 注册 `features/learning/presentation/new_words_state.dart`
- **建议**：移入 `learning_feature_providers.dart`；sl 只注册端口实现

### M3. 仓库双"家"：`core/repositories/` + `core/learning/`、`core/scare_coin/` 未并入 features
- **建议**：定迁移完成态标准，import_guard 加"core/{learning,scare_coin} 禁止新增引用者"

### M4. 部分模块分层不完整 + 越层 import
- **位置**：`word_detail_page.dart:14`（presentation 直接 import data/dictionary_extra.dart）；`dashboard_page.dart`；`content` 无 application/data
- **建议**：越层改走 application 端口；`*_feature_providers.dart` 更名 `*_feature_scope.dart` 并声明为装配文件

### M5. UI 反馈无统一出口，复制扩散
- **数据**：ScaffoldMessenger 45 处/28 文件、showDialog 50 处、Top 单文件 7 处 SnackBar
- **建议**：`widgets/common/` 补 `showMwToast`/`showMwDialog`，新代码强制走 helper

### M6. 超长 build() 共 22 个（>100 行）
- **Top**：`lib_select_page.dart:83`（280 行）、`spell_check_page.dart:84`（165 行）、`screens/learn_session.dart:68`（163 行）
- **建议**：规约"build() > 80 行必须拆 _buildXxx"，可加一条架构测试固化

### M7. 音频层 Java 式静态单例 + 全局可变状态
- **位置**：`core/audio/audio_players.dart`（753 行，27 处 static，`setNeedPlay` 直写可变字段）
- **建议**：以 `audio_service.dart` 为唯一门面 DI 化；已有 REG-AUDIO-001 回归哨兵，迁移有安全网

---

## 🟢 低风险（4 项）

### L1. 翻译残留注释
- `audio_players.dart`（15+ 处"原版 xxx.java"方法级注释）、`user_info_bean.dart`（Bean 命名）、`bb_word_process.dart`（BB 前缀）
- **建议**：溯源注释收敛到文件头一次；`user_info_bean.dart` 择机更名

### L2. 命名前缀不统一
- `sb_card`(5 处引用)/`sb_button`(1 处)/`sb_modal`(1 处) 与 `mw_*` 前缀并存；sb_button 近乎闲置
- **建议**：统一并入 `widgets/common/` 的 mw_ 家族或删除闲置件

### L3. 可变 static TextStyle
- `tokens/design_tokens.dart:101` 起 static TextStyle 非 const，运行时可被突变
- **建议**：改 const；顺带缓存 `theme/wallpaper_data.dart:174-178` 每次重建 List 的 getter

### L4. 测试覆盖冷热不均
- learning 29 / checkin 12 vs account 2 / quick_review 2 / scare_coin·settings·word_browse 各 3；account 恰有 5 个 TODO 未完成功能
- **建议**：未完成功能补齐或下线前，先补 account 基础测试

---

## 做得好的（保持）

- 跨 feature 直接 import 全库仅 4 条，全部走对方 application 端口（合法通道）
- `import_guard_test.dart` + `lib/core/import_guard.dart`：R4/R-core/R6 规则测试化
- domain 层零反向依赖；models/ 零反向依赖
- `app.dart`（311 行）是组合根而非 God class
- 无被注释掉的大段死代码块

## Top 5 优先行动

| # | 行动 | 消除的问题 | 预估收益 |
|---|------|-----------|---------|
| 1 | 拆 word_detail_page（7 区块 → 独立文件，笔记/收藏逻辑入 ChangeNotifier） | H1, M4 | 最高维护风险点解除 |
| 2 | screens/ 迁移退役 + 删 8 个伴生组件 | H2, L2 部分 | -2000 行死重 |
| 3 | DI 约定成文 + new_words_state 移出 service_locator | M1, M2 | 装配路径单一化 |
| 4 | common 补 toast/dialog helper + build() 行数架构测试 | M5, M6 | 止住复制扩散 |
| 5 | 音频 DI 化 + core/{learning,repositories} 迁移路线图 | M7, M3 | 消全局可变状态 |
