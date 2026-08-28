# 学习模块迁移状态

## 当前架构结论

学习域已不再存在或装配 `LearningState`。原先集中持有学习队列、会话推进、FSRS、收藏、手动掌握、账号占位、偏好持久化和展示数据的聚合状态已被物理删除；生产页面与功能域 Provider 均不得重新导入或创建它。

目前的边界按业务事实拆分：可变学习会话由 `LearningSessionState` 唯一拥有，正式复习排程由 `ReviewScheduleRepository` 唯一拥有，收藏和手动掌握分别由独立状态与仓储拥有，账号与引导由账户功能域拥有，学习偏好由设置功能域拥有，发音播放由播放器功能域拥有。所有词书、主学习、沉浸刷词、拼写、单词机和学习会话入口均使用专用会话；应用根只组合账户、学习、设置和播放器功能域作用域，不感知其内部的具体状态类型。

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
| 账号资料读取与编辑 | `AccountProfileState` + `AccountProfileRepository` | 提供不含认证凭据的资料快照；昵称、微信名、个人 ID、签名、头像和手机号统一通过账户功能域持久化。 |
| 单词发音请求、加载与播放标识 | `AudioPlaybackState` + `AudioService` | 播放器功能域唯一入口；共享设备服务不直接暴露给页面，迟到的异步播放回调不会覆盖停止或新播放命令。 |
| 学习提醒、发音、拼写、节奏与题型偏好 | `LearningPreferencesState` + `LearningPreferencesRepository` | 设置功能域唯一入口；保留旧四项设置键，并持久化原先仅留在设置页内存中的选项。 |
| 签到历史日期、连续天数与奖励展示 | `CheckInHistoryReader` + `CheckInService` | 签到功能域的只读页面端口；不复制签到记录、不改变签到奖励和持久化语义。 |

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

登录和启动页已使用账户域的 `AppSessionState`，保留本地登录占位、输入校验、频率限制、动画等待和首次引导分流。账户资料页、资料管理页、个人中心和我的空间统一使用 `AccountProfileState` 的同一可订阅快照，昵称、微信名、个人 ID 和签名编辑不再由页面重新读取再写回 `UserService`。资料状态不暴露 token 或 secret；旧同步资料接口因始终返回默认空 Bean 已删除。回顾弹窗组合 `LearningSessionState` 与 `ReviewScheduleRepository`；词典弹窗组合 `LearningFavoritesState`。这些展示组件不再依赖全局学习聚合状态。

## 播放器与统计边界

`AudioPlaybackState` 是词典、学习、搜索、拼写和词条详情页的唯一播放命令入口。它保存当前词与当前外部音频地址，并以请求序号隔离并发播放、停止和恢复操作；恢复播放仍使用原始外部音频地址。`AudioService` 保持为应用级设备资源，但只由播放器功能域和正式复习音频适配器使用，页面不得直接通过服务定位器调用它。

旧 `PlayerState`、`UserStatsState`、`StatsService` 和 `StatsRepository` 及其实现已经删除。前者是与播放器功能域平行的全局展示状态；后者没有生产消费者，且其“学习/复习总量”与 `ReviewScheduleRepository` 及 `LearningQueueState` 已迁移的统计读模型平行。删除不会修改正式复习每日统计、FSRS 或学习队列统计的既有语义。

## 词条浏览边界

`word_browse` 功能域为词条详情页提供 `WordNotesStore` 与 `SentenceFavoritesStore` 两个应用端口。页面仅通过端口读取、写入和删除笔记，或查询、切换例句收藏；`NoteRepository` 和 `FavRepository` 仍分别是既有笔记和例句收藏的唯一持久化事实来源，适配器不缓存或复制这些数据。

应用根通过 `buildWordBrowseFeatureScope` 集中构造上述适配器。词条详情页和句库页面不得重新导入 `NoteRepository`、`FavRepository` 或服务定位器；句库页面的列表、类型化记录映射和批量删除也统一通过 `SentenceFavoritesStore` 完成，结构测试对此保留负向门禁。该边界不改变 `favorite_words_v1`、`mastered_words_v1`、用户数据库 wordId 收藏和 FSRS 熟练度之间既有的不同事实模型。

## 搜索功能域边界

`search` 功能域为搜索页提供 `WordSearchReader` 与 `SearchHistoryStore` 两个应用端口。单词查询通过 `RepositoryWordSearchReader` 委托既有 `WordRepository`，历史记录通过 `PreferencesSearchHistoryStore` 委托既有 `AppPreferences`；适配器不创建新的词库或历史事实来源。搜索页只读取这些端口，并继续通过 `LearningFavoritesState` 和 `AudioPlaybackState` 使用各自已有的收藏与播放边界。

应用根通过 `buildSearchFeatureScope` 集中装配搜索依赖。搜索页不得重新导入 `WordRepository`、`AppPreferences` 或服务定位器；架构测试对此保留负向门禁。搜索历史仍属于搜索功能域，不应为了统一设置而并入学习偏好状态。

## 字典功能域边界

`dictionary` 功能域为词典页提供 `DictionaryContentReader`，统一读取派生词、同义词和真题例句。`ServiceDictionaryContentReader` 委托现有 `DictionaryService`，不复制词库或字典内容事实；词典页不再直接访问 `DictionaryService.instance`。应用根通过 `buildDictionaryFeatureScope` 装配该端口，架构测试对页面直连服务保留负向门禁。

## 快速复习功能域边界

`quick_review` 功能域为考试速刷页提供 `QuickReviewWordReader`。`RepositoryQuickReviewWordReader` 保留原有空查询、按 ID 倒序和最多 50 个候选词的速刷行为，并委托既有 `WordRepository`；该端口不复用正式复习的 FSRS 到期队列，也不改变正式复习评分和排程事实。

应用根通过 `buildQuickReviewFeatureScope` 装配速刷词源端口。`ExamQuickReviewPage` 只通过该端口加载词源，页面仍负责速刷会话内的计时、选项生成和本地结果展示；架构测试对 `WordRepository` 和服务定位器直连保留负向门禁。

## 词书功能域边界

`book` 功能域为词书选择页和词书内容页提供 `BookCatalogReader`。`RepositoryBookCatalogReader` 继续委托既有 `BookRepository` 读取词书目录，并提供按 ID 查找能力；适配器不缓存或复制词书数据，也不改变学习队列、学习会话或词书数据库的事实模型。

应用根通过 `buildBookFeatureScope` 集中装配目录读取端口。`LibSelectPage` 通过端口加载和筛选词书，`BookWordsPage` 通过端口解析当前词书后再调用 `LearningSessionState` 启动学习，`HomeScreen` 的直接开始学习入口也通过同一端口读取第一本词书。词语导出页、词书选择页的听写/拼写入口以及泛听模式选择页复用学习功能域提供的 `BookWordsReader` 加载当前词书单词，不直接依赖 `LearningQueueRepository`。这些页面只消费只读词源，学习队列状态仍由 `LearningSessionState` 负责；词书相关页面和首页不得重新导入 `BookRepository`、`LearningQueueRepository` 或服务定位器，架构测试对此保留负向门禁。

## 尖叫币账本功能域边界

`scare_coin` 功能域为尖叫币历史页、弹性签到日历和资料页余额卡提供 `ScareCoinStore`。`PreferencesScareCoinStore` 集中承接既有 `scare_coin.balance`、`scare_coin.history`、`scare_coin.last_checkin` 和 `scare_coin.checkin_dates` 键，保留每日一次签到、奖励流水排序及最近 200 条保留策略，不改变已有用户数据格式。

尖叫币账本与 `CheckInService` 的签到记录、正式复习 FSRS 统计以及用户资料保持独立；本次只是把原先位于页面文件中的账本实现移动到数据适配器，不把不同语义的签到、余额和学习统计合并。页面和组件只消费 `ScareCoinStore`，应用根通过 `buildScareCoinFeatureScope` 统一装配。

## 设置偏好边界

`LearningPreferencesState` 是设置页唯一可订阅状态，`LearningPreferencesRepository` 是其唯一持久化边界。每日新学、自动发音、音标显示和深色模式继续使用既有 `daily_new_words_v1`、`auto_play_audio_v1`、`show_phonetic_v1`、`dark_mode_v1` 键；提醒、发音类型、例句发音、拼写、学习与复习节奏、题型和助记开关使用独立语义键。设置页不再保存这些值的本地副本，所有交互均以状态快照渲染并通过命令持久化。

主题皮肤、壁纸、账户、搜索历史和学习进度仍属于各自功能域，不能为了“统一设置”而把它们重新并入学习偏好状态。已删除的 `SettingsState` 及其服务定位器注册不得恢复。

## 功能域装配与回归保护

`learning_feature_providers.dart` 依赖顺序为：正式复习排程仓储和队列仓储先创建，随后创建收藏、手动掌握和学习会话状态；队列、统计、收藏/掌握数量、队列分类和正式复习状态均从这些专用依赖组合。`ReviewScheduleReader` 由 `RepositoryReviewScheduleReader` 适配正式复习排程仓储，向详情页、学习会话和回顾弹窗提供只读 FSRS 卡片及今日统计；评分写入仍由 `ReviewRatingWriter` 负责。`LearningCollectionsState` 使用 `ChangeNotifierProxyProvider2<LearningFavoritesState, LearningMasteredState, LearningCollectionsState>` 装配，不再依赖兼容代理。播放器功能域单独提供 `AudioService` 和 `AudioPlaybackState`，应用根不再创建旧播放器状态或无消费者统计状态。旧 `LearnState`、`LearnService`、`ReviewState`、`ReviewService`、`PlayerState`、`UserStatsState`、`StatsService` 和 `StatsRepository` 及其实现均已删除，因此不会再形成平行的学习、复习、播放或统计事实来源。

结构测试保留少量高价值负向门禁：尖叫币页面、日历和资料卡不得重新持有 `ScareCoinLedger` 或直接访问 `SharedPreferences`；应用根和生产 Provider/页面不得导入或创建 `LearningState`、`LearnState`、`ReviewState`、`SettingsState`、`PlayerState` 或 `UserStatsState`，相应遗留服务和仓储均不得恢复；账户资料展示和编辑页面不得直连 `UserService` 或调用同步空资料读取；设置页不得重新保存学习偏好本地副本或遗留的“待持久化”开关；播放页面不得直连 `AudioService`；正式复习页不得回流题目算法、会话状态或服务定位器；FSRS 展示页面和回顾弹窗不得直连 `ReviewScheduleRepository`；展示组件不得直接读取复习会话状态；历史深链不得重新创建旧 `ReviewSession`。学习状态测试覆盖专用会话加载与评分、只读队列与快照隔离、退出清理、空收藏队列保护、收藏状态和掌握状态的刷新/切换/计数，以及学习偏好旧键兼容和新字段持久化；账户资料测试覆盖统一加载与字段级保存；播放器测试覆盖播放、停止竞争和携带外部地址的恢复。

后续新增需求应首先定位其事实模型，并在该功能域的仓储、应用服务或专用状态中实现。不得以“方便页面读取”为由重新创建跨域聚合状态，或将会话、FSRS、手动标记、收藏、账号和持久化职责重新塞入单一 `ChangeNotifier`。
