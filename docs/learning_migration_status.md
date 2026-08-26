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
