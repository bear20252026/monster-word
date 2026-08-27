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


## 词书单词查询边界

`BookWordsReader` 通过 `WordRepository` 加载指定词书的单词；`BookWordsPage` 已覆盖通用列表页的数据源扩展点并从根 `Provider` 获取该读取器，不再为列表查询读取 `LearningState`。开始学习和真题词组交互保持原实现，本轮不改变。

`WordRepository.getWordsByBookId` 现在通过 `word_books` 关联表按既有顺序查询，并保留词书页面原有的 1000 条加载上限。该修正避免将词书关系错误地假设为 `words.book_id`，使页面迁移不会改变实际词书范围或排序。


## 队列分类词表查询边界

`QueueWordLists` 将当前学习队列按既有 FSRS 卡片语义分类：存在卡片即“已学”，不存在卡片即“未学习”，存在卡片且难度不高于 5.0 即“复习中”。分类保留原队列顺序，并由纯领域测试覆盖；`LearningState` 的原有查询方法改为委托该规则，避免同一筛选条件继续分散。

`LearningQueueWordListsState` 是迁移期的只读展示适配器，当前从遗留状态同步分类快照。`MyWordsPage`、`NotLearnedWordsPage` 与 `ReviewingWordsPage` 通过该适配器加载列表，不再直接依赖 `LearningState`。这不改变当前队列和 FSRS 卡片仍由遗留状态维护的事实，只收敛页面读取边界。

本轮改造前的生词本审计确认：历史 `BBUserNewWord` 模型仅保留 JSON 字段约定；用户数据库没有对应数据表；同步服务与后台服务中的生词同步仍是 TODO；组件层的“添加生词”回调没有接入任何实际调用方。该审计结果说明不能把每日新学数量、未学习队列、收藏或手动掌握标记改名为“生词本”。

## 生词本本地持久化边界

生词本现以用户数据库 `new_words` 表作为唯一事实来源。每条记录保存词库 `wordId`、可读文本快照、来源、操作码、创建/更新时间和待同步标记；`add` 表示当前生词，`remove` 为保留给未来同步的软删除操作。数据库版本从 1 升至 2，既有用户数据通过升级路径创建新表，不改变收藏表或已有偏好数据。

`NewWordRepository` 封装记录的新增、移除、状态查询、计数与倒序读取；`NewWordsReader` 以记录顺序批量回查词库模型；`NewWordsState` 负责展示状态与初始化竞态保护。根应用在组合层提供它们，`NewWordsPage` 已不再调用 `LearningState`，其滑动删除会先持久化软删除；足迹页展示实际生词本数量。词典详情页新增独立书签按钮，用于加入或移出生词本，原有星标收藏语义不变。

当前实现是本地手动生词本，不调用尚未实现的远端同步接口。操作码和 `synced_at` 仅为后续同步保留数据合同；接入 API 前必须先确定服务端协议、冲突处理和历史 `BBUserNewWord` 字段映射。


## 每日新学词数设置边界

每日新学词数曾同时由 `LearningState`、`SettingsState` 和 `SettingsPage` 三处读取或写入同一个 `daily_new_words_v1` 键。现在该键仅由 `SettingsState` 负责加载和保存；根应用创建该状态时执行初始化，设置页订阅并调用它更新数值。既有用户的键名和取值保持不变。

`LearningState` 中未被任何学习流程消费的重复字段、加载和写入逻辑已删除。当前每日新学词数尚未接入队列生成策略，因此本轮只收敛设置事实来源，不虚构其对学习会话的影响；当学习策略需要读取该设置时，应经由专门的策略输入或应用服务注入，而不是重新让页面或遗留状态直接读偏好。


## 主复习页候选规则边界

主路由 `/review` 对应的 `ReviewPage` 已改为复用 `ChoiceGenerator` 与 `ChoiceCandidate`。候选项继续遵循与学习流程一致的规则：释义去重、中文释义优先、最多三个干扰项、稳定兜底和随机展示。页面内原有的 JSON 中文释义解析、候选池筛选和兜底文字已删除。

候选规则收敛时未改变复习队列选择、FSRS 评分或持久化。`ReviewPage` 保留自己的 `SuperMemoryEngine`；`ReviewSession` 仍是另一套兼容/演示会话实现。这两条流程的入口、队列和评分合同必须先统一，不能仅因候选生成规则已共享就强行将其合并。


## 正式复习队列读取边界

`ReviewPage` 现在通过 `ReviewQueueState` 读取由 `LearningState` 提供的不可变队列快照，并委托 `ReviewQueueReader` 决定候选词。读取器将既有优先级固定为“FSRS 到期词 → 当前学习队列 → `a` 样本 → `the` 样本”，因此本轮不改变用户在无到期词时仍可进入复习的行为。

这是一次过渡性读取隔离：FSRS 到期判断和当前学习队列的事实来源仍是 `LearningState`，但页面不再同时负责读取旧状态、选择优先级和词库回退查询。评分写入边界已在后续阶段独立迁移，不能直接迁用仅维护内存状态的兼容 `ReviewService`。


## 正式复习评分写入边界

`ReviewPage` 现在将评分提交给 `ReviewRatingWriter`，而不再直接依赖 `LearningState`。应用根通过 `ProxyProvider` 将该写入端口适配到既有的 `LearningState.rate`，因此评分仍以原有顺序更新 FSRS 卡片并写入 `fsrs6_cards_v1`，记录每日学习或复习计数及活跃日期，然后通知展示状态。

这只是依赖反转，不是评分算法替换：`SuperMemoryEngine` 仍先在页面中推进本次会话，`FsrsRating` 的映射、卡片格式、SharedPreferences 键名和统计分类均保持不变。`/review_session` 仍直接使用遗留评分路径，待两条会话的队列和交互合同统一后再另行迁移。


## 复习主入口边界

回顾弹窗的“开始复习”已从 `/review_session` 改为主路由 `/review`。前者会直接以词库搜索样本初始化兼容会话，后者才读取当前 `LearningState` 的 FSRS 到期词，并仅在没有到期词时回退至当前学习队列或词库样本。因此用户从正常回顾入口启动复习时，现会进入已有的正式到期词流程。

`/review_session` 路由仍保留用于兼容和后续审计，但不再是默认用户入口。本轮没有重写其随机样本实现，也没有变更主复习页的评分或排程持久化；这些需要在队列和评分事实来源统一后单独迁移。
