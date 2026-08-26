# 学习模块迁移状态

## 本阶段已完成

`lib/features/learning/domain/` 现在承载两项不依赖 Flutter、数据库、Provider 或服务定位器的纯规则：`DefinitionFormatter` 负责从词库 JSON 释义中提取首条中文释义；`ChoiceGenerator` 负责候选去重、中文释义优先、兜底释义和最终随机排序。

`LearnState` 已不再自行解析释义 JSON 或维护四选一干扰项策略。它只将学习会话中的 `Word` 和 `BBWordProcess` 适配为领域候选项，再将领域候选项转换为既有 UI 类型 `WordChoicePair`。这使新学习路径拥有了第一个可单独测试的唯一规则入口。

## 本阶段刻意未改动

`LearningState` 与 `ReviewPage` 仍保留旧的候选生成和释义解析代码。本轮不直接替换它们，以避免旧学习流程、复习评分流程和现有持久化行为同时变化。双轨状态尚未删除，当前只减少新路径继续复制规则的风险。

| 位置 | 当前状态 | 下一步迁移前提 |
|---|---|---|
| `state/learn_state.dart` | 已使用领域规则 | 为状态适配补充集成测试。 |
| `state/learning_state.dart` | 仍为旧实现 | 对比新旧候选生成的边界行为并补回归用例。 |
| `pages/review_page.dart` | 仍为旧实现 | 先抽取 Review session/controller，不能直接在页面内替换算法。 |

## 下一轮目标

下一轮先为 `LearnState` 添加会话级测试，并迁移 `LearningState` 至相同的 `ChoiceGenerator` 与 `DefinitionFormatter`。只有所有学习页面不再引用 `LearningState` 后，才删除旧 Provider；复习页面会在独立的 review feature 迁移中处理。
