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

`ReviewPage` 现在通过 `ReviewQueueState` 读取不可变队列快照，并委托 `ReviewQueueReader` 决定候选词。读取器将既有优先级固定为“FSRS 到期词 → 当前学习队列 → `a` 样本 → `the` 样本”，因此本轮不改变用户在无到期词时仍可进入复习的行为。

`ReviewScheduleRepository` 现为正式复习的 FSRS 卡片、到期判断、按词评分、每日统计和活跃日期的唯一事实来源，并继续使用既有 `fsrs6_cards_v1`、`daily_stats_v1` 与 `active_learn_dates_v1` 键。`ReviewQueueState` 仅接收遗留 `LearningState` 维护的当前学习队列，再交给该仓储计算到期词；这是一项刻意保留的兼容边界，而不是让正式页面重新依赖遗留聚合状态。待学习队列本身有独立来源后，只需替换这一输入，不改变正式复习页面或读取器的行为。

## 学习功能域根装配边界

学习功能的 Provider 现集中在 `learning_feature_providers.dart`。其中保留原有创建顺序：独立的复习调度仓储先于兼容 `LearningState`，评分写入端口先于正式 `ReviewSessionState`；音频状态仍为应用级 Provider，读取器仍以依赖容器中的既有实例提供。`WordApp` 只展开该功能域装配清单，再组合主题、壁纸、设置、播放和用户统计等全局状态。

这项拆分不改变任何 Provider 的生命周期或服务定位器注册方式，也不把功能域依赖反向拉回页面。后续迁移某个学习状态时，应修改功能域装配文件及其契约测试，而不是再次向应用根增加具体学习实现类型。


## 正式复习词条操作边界

`ReviewWordActionsState` 现在协调正式 `/review` 的按词收藏与手动掌握操作。它从既有 `FavRepository` 和 `MasteredRepository` 读取不可变展示快照，操作成功后再更新快照并通知页面；复习页顶部星标不再维护未持久化的 `_isFavorited` 本地副本。

收藏仍使用字符串键的 `favorite_words_v1`，手动掌握仍使用字符串键的 `mastered_words_v1`。二者分别独立于用户数据库的 `wordId` 收藏和 FSRS 卡片熟练度。“熟”按钮保留原有本地会话推进，同时为刚作答的词写入幂等的手动掌握标记；它不会反转已存在的手动掌握状态。


## 正式复习会话状态边界

`ReviewSessionState` 现在承接正式 `/review` 的本地题目队列初始化、会话进度和实际作答词捕获。它依赖 `ReviewQueueReader` 取得候选词、依赖 `ReviewSessionQuestionFactory` 将读取层 `Word` 转为过程模型并构造四选一候选项、依赖 `ReviewSessionRatingExecutor` 执行回忆等级到引擎命令及 FSRS 写入的映射；这些职责均不在会话状态中重复实现。`ReviewSessionRatingExecutor` 在推进 `SuperMemoryEngine` 前接收已捕获的实际词条，并通过 `ReviewRatingWriter` 提交对应 FSRS 等级；手动“熟”仍只推进本地引擎而不写入 FSRS。页面不再同时持有引擎、候选项、初始化和评分推进逻辑。

`ReviewSessionState` 还统一了加载与答题交互：它显式区分 loading、ready 和 failed 阶段，保存加载异常供页面显示可重试的错误界面；“看答案后继续”的 good 评分命令仍由该状态编排。错误候选的 300 毫秒反馈定时器、答案揭示、错误选择快照和销毁清理已提取到 `ReviewSessionAnswerState`，使其可以独立测试而不接触 `SuperMemoryEngine` 或 `ReviewRatingWriter`。会话状态只在正确选择后决定 good 评分，并在评分推进、手动掌握或重新初始化前重置交互快照，因此加载失败不会被误渲染为“今日复习完成”，旧题的错误提示也会在题目推进或状态销毁时取消。

`ReviewSessionStarter` 将页面提供的 `ReviewQueueSnapshot` 与 `ReviewSessionState.initialize` 命令组合为专用启动协调器。它不重新实现队列优先级、加载阶段或异常保存：读取规则仍由 `ReviewQueueReader` 决定，`ReviewSessionQuestionFactory` 只负责词条转换和候选构建，成功/失败视图仍由会话状态和 `FormalReviewPageContent` 的快照映射渲染。这样 `ReviewPage` 无需再维护仅用于吞掉已处理加载异常的 `try/catch`，重试入口仍调用同一启动路径。

正式复习的视觉区域已进一步拆分至 `formal_review_widgets.dart`：该文件现在是稳定的聚合导出入口，具体实现按 `formal_review_session_layout.dart`（沉浸式背景与响应式布局）、`formal_review_header.dart`（顶部进度/操作栏）、`formal_review_question.dart`（单词提示、四选一与底部答案动作）、`formal_review_choice_card.dart`（候选卡片）和 `formal_review_state_views.dart`（加载、失败和完成视图）分离。`FormalReviewPageContent` 进一步集中页面级的加载、失败、完成和答题内容分支；`ReviewPage` 只保留路由生命周期、状态组合、回调与导航反馈等协调职责，避免再次演变为包含业务状态与大量视觉细节的超长文件。

展示组件不再导入或直接读取 `ReviewSessionState`。页面把会话的只读快照（进度、候选项、答案显示和错误候选文本）及命令回调映射给布局组件；`ReviewSessionState.selectedWrongChoice` 是来自 `ReviewSessionAnswerState` 的只读反馈快照，题目推进和 FSRS 评分职责仍只留在会话状态中。该调整只改变展示层的依赖方向，不改变横竖屏布局、壁纸、候选反馈、评分、收藏或手动掌握语义。

正式复习页面的其余操作协调也已拆分：`ReviewAudioPlayer` 是正式复习发音的应用端口，根组合层将其适配为既有 `AudioService.playWordAudio`；`ReviewAudioState` 维护播放请求的加载快照并向页面转交失败，页面不再直接通过服务定位器调用音频服务。`ReviewWordDetails` 集中 `BBWordProcess` 到词典页面 `Word` 的字段映射；`FormalReviewMoreOptionsSheet` 则只发出“播放发音/查看详情”意图。页面仍负责路由、SnackBar 和 Navigator 协调，因此没有将 UI 副作用下沉到展示组件或基础设施层。

收藏和手动掌握的页面副作用现由 `ReviewWordActionCoordinator` 统一协调。它以显式 `ReviewWordActionOutcome` 返回“已收藏、已取消收藏、已标记掌握、已存在、无当前词或持久化失败”等结果，保持旧有的操作顺序：收藏在持久化后更新展示快照；“熟”先推进会话，再写入幂等的手动掌握标记。`ReviewWordActionFeedback` 将结果映射为页面可展示的反馈文案与时长，`ReviewPage` 仅决定是否显示 Snackbar。这样不会把持久化调用、异常分支和用户提示再次混进路由页面，也不会混同 `favorite_words_v1`、`mastered_words_v1` 与 FSRS 卡片熟练度。

正式复习已移除原有“撤销”入口：该入口仅减少展示计数，既不会回退 `SuperMemoryEngine`，也不会撤销已经发出的 FSRS 写入或手动掌握操作，继续保留会误导用户。历史 `/review_session` 深链现在由路由层重定向至正式 `/review`，因此旧会话实现不再是可达产品路径。后续如需提供真实撤销，必须先定义可逆的题目推进、FSRS 持久化和手动标记事务合同，而不能重加仅修改计数的按钮。


## 正式复习评分写入边界

`ReviewPage` 现在将评分提交给 `ReviewRatingWriter`，而不再直接依赖 `LearningState`。页面会在 `SuperMemoryEngine` 推进题目之前捕获实际作答词；应用根将写入端口直接适配到 `ReviewScheduleRepository.rateWord`。该命令只更新该词的 FSRS 卡片并写入既有 `fsrs6_cards_v1`，记录每日学习或复习计数及活跃日期，然后通知依赖它的展示状态，不会推进遗留学习队列。

这既是依赖反转，也是一次数据关联修正：原先页面在本地引擎推进后才由 `LearningState.rate` 推断当前词，可能把本题评分写到下一队列词，并在最后一题时遗漏写入。现在 `SuperMemoryEngine` 的推进顺序和 `FsrsRating` 映射保持不变，但持久化评分始终对应本题单词。遗留学习会话仍使用 `LearningState.rate`，保留其 Leitner 联动和队列推进；为兼容未迁出页面，`LearningState.rateReviewWord`、卡片读取和统计读取暂时仅委托调度仓储，不再维护第二份卡片或统计内存状态。历史 `/review_session` 已在路由层重定向，旧页面仅留待后续删除审计，不再承担兼容会话。


## 复习主入口边界

回顾弹窗的“开始复习”已从 `/review_session` 改为主路由 `/review`。前者会直接以词库搜索样本初始化兼容会话，后者才读取当前 `LearningState` 的 FSRS 到期词，并仅在没有到期词时回退至当前学习队列或词库样本。因此用户从正常回顾入口启动复习时，现会进入已有的正式到期词流程。

`/review_session` 的历史名称仍保留以兼容既有深链，但路由现在始终返回正式 `ReviewPage`，不再创建旧 `ReviewSession`。正式 `/review` 已将队列读取与评分提交隔离为专用端口，同时保持原有评分和排程持久化语义；旧页面的随机样本、直接评分调用及占位操作不再属于可达产品行为，可在确认无外部二进制路由依赖后删除源文件。

## 路由功能域边界

应用路由现由 `AppRouter` 作为薄协调器，依次委托 `LearningRoutes`、`ContentRoutes` 与 `AccountRoutes` 构建页面；稳定的深链字符串已移至独立的 `RouteNames`。学习域路由拥有正式 `/review`、历史 `/review_session` 重定向、学习会话和学习工具页的参数解析，因此正式复习的兼容规则不再散落在四百余行的总路由器中。

总协调器继续保留转场策略以及未知路由的友好错误页。各功能域对不属于自身的名称返回空值，对本域必需参数缺失时继续返回相同的友好错误页；这保证了模块化不改变路由名称、默认参数、页面类型或历史复习深链的渐变转场语义。

## 行为契约与结构门禁边界

复习迁移的回归保护现优先使用可执行契约：路由测试覆盖学习、内容、账户、未知路由、历史复习重定向和缺参错误页；队列读取器覆盖既定的到期词与样本兜底优先级；评分执行器覆盖推进前捕获实际词和手动“熟”不写 FSRS；会话启动器、加载阶段映射、答题临时状态以及独立调度仓储均有专用测试。这样页面或模块移动时，业务行为不会再仅因源码字符串位置变化而失去保护。

`app_structure_test.dart` 已从按类名、方法名和文件布局逐项匹配的长清单，收敛为少量高价值的架构负向检查：应用根不得重新导入具体学习实现，正式复习页不得回流到遗留 `LearningState`、题目算法或音频服务定位器，展示组件不得读取会话状态，历史深链不得重新创建 `ReviewSession`。这些约束保护依赖方向而不冻结功能域内部的实现组织。
