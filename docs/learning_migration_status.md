# 学习模块迁移状态

## 本阶段已完成

`lib/features/learning/domain/` 现在承载两项不依赖 Flutter、数据库、Provider 或服务定位器的纯规则：`DefinitionFormatter` 负责从词库 JSON 释义中提取首条中文释义；`ChoiceGenerator` 负责候选去重、中文释义优先、兜底释义和最终随机排序。

`LearnState` 与 `LearningState` 均不再自行解析释义 JSON 或维护四选一干扰项策略。两者只将学习会话中的 `Word` 和 `BBWordProcess` 适配为领域候选项，再将领域候选项转换为既有 UI 类型 `WordChoicePair`。这让两条学习路径共享同一个可单独测试的规则入口。

## 本阶段刻意未改动

`ReviewPage` 仍保留旧的候选生成和释义解析代码。本轮不直接替换复习页，以避免复习评分流程和现有持久化行为同时变化。`LearningState` 也尚未删除：它仍被大量页面用于词书、学习统计、收藏、掌握状态和 FSRS 展示；本轮只让它与 `LearnState` 共享学习候选规则。

| 位置 | 当前状态 | 下一步迁移前提 |
|---|---|---|
| `state/learn_state.dart` | 已使用领域规则并补充会话级测试 | 为状态适配补充更多边界测试。 |
| `state/learning_state.dart` | 已共享领域规则，仍承担遗留聚合职责 | 先迁移页面读写面，再删除旧 Provider。 |
| `pages/review_page.dart` | 仍为旧实现 | 先抽取 Review session/controller，不能直接在页面内替换算法。 |

## 下一轮目标

下一轮先迁移 `LearningState` 的页面读写面，按功能而非全局替换 Provider。只有所有学习页面不再引用 `LearningState` 后，才删除旧 Provider；复习页面会在独立的 review feature 迁移中处理。

## 学习会话状态边界

学习会话页面只可读取 `LearnState`：`LearnPage`、`LearnSession` 和 `WordMachinePage` 的当前词、四选一候选、前进/跳转、评分和发音行为统一由该状态提供。页面不得新增对 `LearningState` 的会话操作调用，也不得直接重新实现候选或评分规则。

`LearningState` 在迁移期只保留为跨页面的遗留聚合状态，继续服务于词书元数据、统计、收藏、掌握标记和已有 FSRS 展示。将来每迁移一个页面，应优先把它的会话行为切到 `LearnState`；只有其余读写职责也具备独立入口后，才能缩减或删除该旧状态。

本轮已将 `WordMachinePage` 迁入该会话边界。它继续使用原有的评分、候选、跳转、发音和像素风 UI 流程，但不再直接读取 `LearningState`。仍直接依赖遗留状态的页面以词书、统计、收藏、搜索和复习页面为主，后续会按这些功能域分别迁移。

## 学习统计状态边界

首页与仪表盘现通过 `LearningStatisticsState` 读取当前词书、队列总数、待复习数、已学习数、FSRS 分层统计和今日统计。该状态向页面提供不可变快照，页面不再直接监听 `LearningState`。

这是一个过渡适配层：快照暂时从遗留状态同步，以保证当前展示数值与原实现完全一致。现有 `UserStatsState`、`StatsService` 和 `UserRepository` 尚不具备完整的 FSRS 分层统计与当前词书数据，不能直接替代；当真实统计查询服务补齐后，只需替换适配层的数据来源，不应再回退页面依赖。

## 当前词与候选一致性

学习页面展示的当前词以状态队列索引为唯一来源。`LearnState` 与 `LearningState` 生成四选一候选时均以该当前词作为正确项，不能使用 Leitner 引擎的内部当前词；引擎初始化会随机组内顺序，直接读取它会使页面题干与正确候选不一致。`LearnState.choices` 回归测试覆盖了加载和切词后“恰有一个正确候选”的约束。

## 收藏与掌握展示边界

`LearningCollectionsState` 向展示层提供收藏数与掌握数的不可变快照。`MyContentPage` 已通过该状态显示单词本数量，不再直接监听 `LearningState`。

本轮刻意不迁移收藏与掌握的写入操作。仓库当前存在按单词字符串的 `FavRepository`、遗留 `LearningState` 的 SharedPreferences 集合，以及按 wordId 的用户数据库通道；虽然 `FavRepository` 与遗留状态复用 `favorite_words_v1`，其余路径尚未统一。写入迁移必须先确定唯一事实来源与数据同步策略，不能在仅展示层的低风险改造中贸然合并。

## 单词收藏事实来源

单词字符串维度的收藏现以 `FavRepository` 为唯一事实来源。`LearningState` 不再维护第二份 `favorite_words_v1` 内存集合或直接写入该键；其收藏查询、切换、计数和收藏词表查询均委托给仓储。这样遗留状态、新学习状态和学习服务共用同一份字符串收藏集合，已有用户数据因存储键不变而继续可见。

`mastered_words_v1` 仍由 `LearningState` 维护；按 `wordId` 的用户数据库收藏表仍服务于字典/数据库通道。二者与字符串收藏的身份模型不同，本轮不做自动合并或数据回填，后续必须先定义跨身份映射与冲突策略。

## 掌握标记事实来源

`MasteredRepository` 现以 `mastered_words_v1` 为掌握标记的唯一字符串存储来源。`LearningState` 已删除重复集合和直接 SharedPreferences 写入，改为委托该仓储完成查询、切换、计数和已掌握词列表筛选。兼容测试覆盖已有键数据的加载和后续写入。

`LearnState.isMastered` 目前表达的是会话内 FSRS 卡片状态，与手动的 `mastered_words_v1` 标记不是同一语义；本轮不将二者强行合并。足迹页的“已掌握单词”计数已迁移至集合展示状态，其余页面的学习统计、词表查询和会话交互会在后续按语义分别迁移。

## 已掌握词表查询边界

`MasteredWordsReader` 组合 `MasteredRepository` 与 `WordRepository`，负责把手动掌握的字符串标记解析为完整单词模型。`MasteredWordsPage` 已通过该读取器加载数据，不再调用 `LearningState.getMasteredWords()`；单词仓储新增批量文本查询接口以隔离数据库细节。

通用 `ListWordsPage` 新增上下文数据源扩展点，默认仍兼容其他词表页的 `LearningState` 读取；`MasteredWordsPage` 覆盖该扩展点并从根 `Provider` 获取读取器，因此页面不再依赖遗留状态或全局依赖容器。后续若迁移更多词表页，应继续替换各自的数据源，而不是将不同业务语义重新塞回通用页面基类。
