# 学习模块迁移状态

## 当前架构结论

学习域已不再存在或装配 `LearningState`。原先集中持有学习队列、会话推进、FSRS、收藏、手动掌握、账号占位、偏好持久化和展示数据的聚合状态已被物理删除；生产页面与功能域 Provider 均不得重新导入或创建它。

目前的边界按业务事实拆分：可变学习会话由 `LearningSessionState` 唯一拥有，正式复习排程由 `ReviewScheduleRepository` 唯一拥有，收藏和手动掌握分别由独立状态与仓储拥有，账号与引导由账户功能域拥有。所有词书、主学习、沉浸刷词、拼写、单词机和学习会话入口均使用专用会话；应用根只组合账户和学习功能域作用域，不感知学习域内部的具体状态类型。

| 责任 | 当前唯一入口 | 说明 |
|---|---|---|
| 当前学习队列、索引、翻卡、候选与学习评分 | `LearningSessionState` | 会话唯一可变拥有者，统一初始化 Leitner 引擎并推进会话。 |
| 词书/收藏队列加载与只读词书查询 | `LearningQueueRepository` | 保留词书查询上限、收藏解析和队列回退语义。 |
| 学习进度偏好 | `LearningProgressRepository` | 保留 `current_book_v1`、`current_index_v1`、`queue_snapshot_v1` 的键和值结构。 |
| FSRS 卡片、到期判断、评分和每日统计 | `ReviewScheduleRepository` | 使用既有 FSRS 与每日统计存储键，是正式复习的唯一事实来源。 |
| 单词字符串收藏 | `LearningFavoritesState` + `FavRepository` | 使用 `favorite_words_v1`，负责刷新、切换、计数与完整词条解析。 |
| 手动掌握标记 | `LearningMasteredState` + `MasteredRepository` | 使用 `mastered_words_v1`，负责刷新、切换、集合与计数。 |
| 收藏/掌握数量展示 | `LearningCollectionsState` | 只组合 `LearningFavoritesState` 与 `LearningMasteredState` 的只读数量。 |
| 账号会话与首次引导 | `AppSessionState` | 位于账户功能域，不得回流至学习域。 |

## 学习会话与队列读取边界

`LearningSessionState` 组合 `LearningQueueRepository`、`LearningProgressRepository` 和 `ReviewScheduleRepository`。它负责词书加载、收藏词学习、当前词、四选一候选、Leitner 推进、学习评分和进度保存；学习评分会以已捕获的实际当前词写入排程仓储，再推进会话索引。页面不得同时维护另一份可变队列、索引或候选生成规则。

`LearningQueueState` 从会话状态获得不可变 `LearningQueueSnapshot`。正式复习队列、学习统计和队列分类词表仅组合该快照与 `ReviewScheduleRepository`，不得读取可变会话列表并在展示层自行推导状态。快照复制词条列表，避免展示侧在一次刷新间隔内观察到未同步变更。

`LearningQueueRepository` 与 `LearningQueueWordSource` 集中词书加载、收藏词解析、当前队列回退和可选乱序。生产适配器仍使用既有词库和收藏仓储，因此词书查询的 `limit: 1000`、`offset: 0`，以及收藏词优先从完整词库解析、无法解析时回退当前队列的行为保持不变。空收藏词加载必须保留当前词书和队列。

## 正式复习边界

正式 `/review` 由 `ReviewSessionState` 协调本地题目会话、加载阶段与答题进度，`ReviewQueueReader` 固定队列优先级为“FSRS 到期词 → 当前学习队列 → `a` 样本 → `the` 样本”。历史 `/review_session` 深链仍保留名称，但路由层始终重定向至正式 `/review`；不可达旧会话实现已删除。

`ReviewSessionRatingExecutor` 必须在 `SuperMemoryEngine` 推进前捕获实际作答词，并经 `ReviewRatingWriter` 写入 `ReviewScheduleRepository`。因此评分始终关联本题词条，而不会错写到下一词或漏写最后一词。展示组件不读取 `ReviewSessionState`；页面将只读快照和命令回调映射给布局组件。

旧 `ReviewState`、`ReviewService` 及其服务定位器注册已经删除。它们曾维护另一套字符串队列、引擎推进和候选生成接口，却没有生产页面消费者；保留会重新引入与正式复习会话和 FSRS 排程平行的事实来源。正式复习现仅由 `ReviewSessionState`、`ReviewSessionRatingExecutor`、`ReviewQueueReader`、`ReviewRatingWriter` 和 `ReviewScheduleRepository` 组成。

“熟”操作仅推进正式复习的本地会话，并幂等写入手动掌握标记；它不写入 FSRS。原有伪撤销入口已删除，因为它既不能回退引擎，也不能撤销已提交的持久化操作。将来若提供真实撤销，必须先定义题目推进、FSRS 持久化和手动标记的可逆事务合同。

## 收藏、手动掌握与 FSRS 的事实模型隔离

`favorite_words_v1`、`mastered_words_v1`、用户数据库中按 `wordId` 保存的收藏关系，以及 FSRS 卡片熟练度表达的是不同身份模型和业务语义，**不得为了减少代码而自动合并、回填或相互覆盖**。

`LearningFavoritesState` 是字典、搜索和收藏词页面的收藏状态；它持久化后更新本地快照并通知订阅者。`LearningMasteredState` 是手动掌握词状态；它以 `MasteredRepository` 作为唯一持久化边界，并提供刷新、切换、集合查询和计数。`LearningCollectionsState` 不保存或写入任何集合，只从前两者组合展示数量。

FSRS 卡片熟练度不等于 `mastered_words_v1`。已删除的旧 `LearnState.isMastered` 曾错误地将会话内临时卡片与手动掌握按钮耦合；现在该按钮只使用 `LearningMasteredState`，FSRS 指示器只从 `ReviewScheduleRepository` 读取。二者不得共用同一字段、缓存或写入路径。按 `wordId` 的用户数据库收藏通道继续服务其自身的数据模型，在定义可靠映射与冲突策略前不与字符串收藏自动同步。

## 词表、账户和展示迁移边界

词典、搜索和收藏词页面已直接使用 `LearningFavoritesState`；词条详情、句子测验、词书启动、主学习、沉浸刷词、拼写、单词机和学习会话页直接使用 `LearningSessionState`；词书导出页、随身听页和词书列表查询直接使用 `LearningQueueRepository`。通用 `ListWordsPage` 不再提供遗留学习状态的默认数据源，子类必须显式采用所属的词书、掌握、生词或队列分类读取端口。

`MasteredWordsReader` 组合 `MasteredRepository` 与 `WordRepository`，将手动掌握的字符串标记解析为完整单词模型。`BookWordsReader` 使用既有 `word_books` 关联表读取词书范围和顺序。`NewWordsState` 和用户数据库 `new_words` 表仍独立承载生词本，不得将学习数量、收藏、手动掌握或未学习队列改名为“生词本”。

登录和启动页已使用账户域的 `AppSessionState`，保留本地登录占位、输入校验、频率限制、动画等待和首次引导分流。回顾弹窗组合 `LearningSessionState` 与 `ReviewScheduleRepository`；词典弹窗组合 `LearningFavoritesState`。这些展示组件不再依赖全局学习聚合状态。

## 功能域装配与回归保护

`learning_feature_providers.dart` 依赖顺序为：正式复习排程仓储和队列仓储先创建，随后创建收藏、手动掌握和学习会话状态；队列、统计、收藏/掌握数量、队列分类和正式复习状态均从这些专用依赖组合。`LearningCollectionsState` 使用 `ChangeNotifierProxyProvider2<LearningFavoritesState, LearningMasteredState, LearningCollectionsState>` 装配，不再依赖兼容代理。旧 `LearnState`、`LearnService`、`ReviewState`、`ReviewService` 及其服务定位器注册和空学习模块均已删除，因此不会再形成平行的学习或复习队列、FSRS 卡片或进度持久化。

结构测试保留少量高价值负向门禁：应用根和生产 Provider/页面不得导入或创建 `LearningState`、`LearnState` 或 `ReviewState`，三类遗留状态及 `LearnService`、`ReviewService` 均不得恢复；正式复习页不得回流题目算法、会话状态或服务定位器；展示组件不得直接读取复习会话状态；历史深链不得重新创建旧 `ReviewSession`。学习状态测试覆盖专用会话加载与评分、只读队列与快照隔离、退出清理、空收藏队列保护、收藏状态和掌握状态的刷新/切换/计数。

后续新增需求应首先定位其事实模型，并在该功能域的仓储、应用服务或专用状态中实现。不得以“方便页面读取”为由重新创建跨域聚合状态，或将会话、FSRS、手动标记、收藏、账号和持久化职责重新塞入单一 `ChangeNotifier`。
