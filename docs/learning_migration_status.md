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
