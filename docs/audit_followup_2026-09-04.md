# 架构审计跟进清单（2026-09-04）

> 来源：外部复审报告（2026-09-04）。全部 9 项发现已逐条只读核实，  
> 其中 1 项与报告有出入已更正（SrsEngine）。本文件是本批问题的分类事实来源与批次规划。  
> 上一轮遗留见 `docs/remaining_issues_2026-09-03.md`（L4 归位仍挂账）。

## 一、逐条核实结论

| # | 报告发现                                       | 核实       | 备注                                                                                                                                                                                                                                          |
| - | ------------------------------------------ | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | FSRS 全量卡片状态存单个 SharedPreferences JSON blob | ✅ 属实     | review_schedule_repository.dart `_saveCards()` jsonEncode 整个 `_cards` Map 写单个 SP key；dailyStats/activeDates 同理。学习记录事实来源，评分即全量重写                                                                                                             |
| 2 | 56 处 `catch (_)` 空捕获吞错                     | ✅ 属实     | 全库精确 56 处；典型 fav_repository_impl.dart `_loadFavorites` catch 后空块——收藏加载失败静默消失、Sentry 不可见                                                                                                                                                     |
| 3 | presentation 直连数据库单例 3 处                   | ✅ 属实     | word_detail_page.dart:73（getWord 常规读）、book_words_page.dart:98（forceRebuild）、more_settings_page.dart:408（diagnostics + forceRebuild）；违反 architecture_boundaries.md §2                                                                        |
| 4 | 同名双 BookWordsReader                        | ✅ 属实     | features/book/application/ 与 features/learning/application/ 各一个同名类，行为不同（截断 vs 全量），接错线编译期不报错                                                                                                                                                 |
| 5 | 词书加载硬编码 limit: 1000                        | ✅ 属实     | repository_book_words_reader.dart（报告行号 10，实际 15）`getWordsByBookId(bookId, limit: 1000)` 大词书静默截断                                                                                                                                             |
| 6 | SrsEngine 死码（121 行）+ runAppGuarded 易误用     | ⚠️ 部分属实  | **更正**：srs_engine.dart 中 `SrsEngine` 类（:73）确无消费方，但同文件 `RecallRating` 枚举（:9）仍被 review_session_rating_executor / review_session_state / 对应测试 3 处 import——**只能删类不能删文件**，或把 RecallRating 迁至公共位置。runAppGuarded（app_bootstrap.dart:68）仅定义零调用，死码属实 |
| 7 | FSRS/Leitner 引擎公式零直接单测                     | ✅ 属实     | test/ 下无任何 fsrs/leitner/engine 命名测试；fsrs6_engine.dart（对照 py-fsrs 逐公式重写、21 权重、clamp 完善）确实无回归网                                                                                                                                                |
| 8 | share_image_service 在 data 层画 UI           | ✅ 属实     | lib/features/learning/data/share_image_service.dart 用 ui.PictureRecorder/Canvas 绘制分享图，纯 UI 职责放错层                                                                                                                                            |
| 9 | 样板偏重：20 处 fromServiceLocator + 19 个薄壳适配器   | ✅ 属实（低优） | 端口-适配器风格的代价，非缺陷；不建议动                                                                                                                                                                                                                        |

## 二、分类（按风险维度）

### 🔴 P0 数据安全

- **#1 FSRS 状态 blob**：唯一可能造成**不可再生产数据丢失**的问题（学习记录），且性能随词量线性恶化。

### 🟠 P1 可观测性 / 正确性

- **#2 catch (_) 治理**：数据丢失静默化，Sentry 完全盲区。
- **#5 limit 1000 截断**：大词书队列静默缺词，用户可感知的功能错误。

### 🟡 P2 架构纪律

- **#3 presentation 直连 DB**：违反自家边界规则且守卫拦不住（盲区）。
- **#8 share_image_service 放错层**：分层卫生。
- **#4 双 BookWordsReader**：同名异实，接错线风险。

### ⚪ P3 测试网 / 卫生

- **#7 引擎零单测**：无风险欠账，但是 #1 迁移的前置安全网。
- **#6 SrsEngine 类 + runAppGuarded 死码**：低风险清理（注意 RecallRating 保留）。

## 三、批次规划（顺序即依赖：A 先行为 E 上保险）

| 批次                            | 内容                                                                                                                                                                                                                                                                                                                                                                          | 性质   | 风险      |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---- | ------- |
| **A 引擎测试补网 ✅（2026-09-04 完成）** | 已落地 `test/core/engine/fsrs6_engine_test.dart`（29 断言：DECAY/FACTOR 常量、21 权重逐位、S0/D0、R 公式、难度更新、同日短时、回忆/遗忘稳定性、间隔不变量，期望值由 py-fsrs 官方源码逐字复刻计算并 2026-09-04 联网核对）+ `test/core/engine/leitner_engine_test.dart`（12 断言：分桶/升降级/分组/选项池）。**顺带发现并锁定引擎怪癖**：Leitner `lessonIsOver()` 在最后一组学完后恒 false（`_currentGroup` 保留旧组，Java 原版 1:1 行为），App 层零消费、完成判定实际走 `getDataPreparedState`，不改引擎仅注释锁定 | 纯增量  | 零（已完成）  |
| **B 卫生小刀批 ✅（2026-09-04 完成）** | ①limit 1000：learning adapter 去硬编码 + WordRepositoryImpl `limit ?? 50`→`limit ?? -1`（SQLite 无限制语义，接口注释声明 null=全量契约），原锁定截断行为的测试断言（==1000）反转修正（REG-LEARN-001）；②双 Reader：book 侧整体更名 `BookWordListReader`（12 文件），新增 `test/architecture/no_duplicate_port_names_test.dart` 跨 feature 端口重名守卫（REG-ARCH-004）；③share_image_service 迁 learning/presentation（唯一消费方 dashboard_page 同步）；④死码：删 SrsCard/SrsEngine 类（srs_engine.dart 仅存 RecallRating 枚举）+ runAppGuarded 及其测试 | 多点小改 | 低（已完成） |
| **C catch (_) 分级治理 ✅（2026-09-04 完成）** | 56 处三级分类：A 级数据丢失类 13 处（收藏/笔记/掌握词表/金币账本/用户信息/今日学习数/复习启动/收藏掌握持久化）接 `reportSwallowedError`（debugPrint + Sentry captureEvent，isEnabled 守卫防测试环境崩溃）；B 级词条解析降级 ~10 处与 C 级合理降级 ~33 处补豁免注释（不逐条上报防刷屏）；守卫 `test/architecture/swallowed_error_guard_test.dart` 锁定 A 级文件必须调用上报（REG-OBS-001） | 可观测性 | 低-中（已完成） |
| **D 架构违规批**                   | ①word_detail_page:73 改经 port/repository ②forceRebuild/diagnostics 收进 application 管理服务 ③ImportGuard 扩展"presentation 禁 import WordBookDatabase"正向拦截补盲区                                                                                                                                                                                                                        | 架构收口 | 中       |
| **E FSRS 迁 SQLite 专项**        | 表结构（cards/daily_stats/active_dates）+ 首启迁移（读旧 SP blob 导入后清理，SQLite 空回退读 SP 双读过渡）+ 幂等回滚。**依赖批次 A 的测试网**，方案需单独评审                                                                                                                                                                                                                                                               | 数据迁移 | 高（用户数据） |
| 搁置                            | #9 样板精简（风格问题不动）；L4 test/pages 归位（上轮挂账，可随时插入）                                                                                                                                                                                                                                                                                                                                | —    | —       |

## 四、待拍板事项

1. 批次顺序是否按 A→B→C→D→E 执行（还是先做其他）？
2. 批 B 的 limit 1000：**去掉限制全量加载**（大词书内存换正确性，词库 2.5 万词单书最大几千，可接受）还是**改分页/流式**（改动大）？
3. 批 E 单独出方案评审后再动工。

