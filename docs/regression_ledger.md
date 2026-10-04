# Monster Word 回归测试台账（Regression Ledger）

> 原则：**每个已修复的 bug 必须有对应的永久回归测试**（REG-ID 命名），
> 由 CI（GitHub Actions `dart.yml`：push/PR to main → format+analyze+**flutter test** 失败即阻断；
> `build.yml` 构建前同样跑 analyze+test）强制执行。
> 任何导致回归测试失败的改动，必须先证明 bug 不会复发，否则禁止合入。

## 台账索引

| REG-ID | 症状 | 根因 | 修复 commit | 守护测试 |
|---|---|---|---|---|
| REG-AUDIO-001 | 单词发音静默失效（例句响、单词不响） | `PhoneticAudioPlayer._needPlay` 默认 false 且无调用点，播放前被 `if (!_needPlay) return` 丢弃 | `2eabee0` | `test/regression/regression_audio_test.dart` |
| REG-AUDIO-002 | Android 真机例句无声（Windows 正常） | 词库存 `http://` 明文 URL，Android 9+ 默认禁明文流量 | `2eabee0` | 同上（另见 `test/data/example_parser_test.dart`） |
| REG-AUDIO-003 | 网络音频失败后彻底无声 | 下载失败只回调不兜底 | `2eabee0` | 同上（守护链路前提 + 集成验证；TTS 插件无法纯 Dart 实测） |
| REG-QUIZ-001 | 四选一干扰项混入英文释义、无混淆性 | `extractChinese` 只认 JSON 释义，对纯文本释义（词库主流格式）返回空 | `2eabee0` | `test/regression/regression_quiz_test.dart` |
| REG-QUIZ-002 | GRE 等书四选一残缺、详情页空白 | 词库 55% 空壳词进学习队列（三轮回填后降至 1%，双保险见 REG-DATA） | `2eabee0` | 同上 |
| REG-QUIZ-003 | 选项重复/缺项 | ChoiceGenerator 语义回归 | — | 同上（另见 `learning_choice_rules_test.dart`） |
| REG-NAV-001~004 | 无法前进/多层级返回 | Flutter 无内建 forward | `4a16217` | `test/app/router/navigation_history_test.dart`（前进/返回/分叉作废/弹层过滤） |
| REG-SKIN-001~003 | 一键换肤形态变颜色不变 / 品牌值趋同 | brandThemeMap 缺映射、B 档值被改平 | `d320ceb` | `test/regression/regression_skin_test.dart` |
| REG-DATA-001 | 词库数据缺失/损坏 | 词库精简/回填事故 | `8c9486b` | `test/data_verification_test.dart`（books≥272 基线校验，CI 前置 `test -s assets/db/wordbook.db.gz`） |
| REG-UI-001 | 文字对比度不达标（无障碍退化） | 主题色随意取值 | `d320ceb` | `test/contrast_guard_test.dart`（WCAG AA 4.5:1 全主题守卫） |
| REG-ARCH-001 | 模块间依赖越界 | 分层边界失守 | — | `test/architecture/import_guard_test.dart`（全库扫描） |
| REG-DICT-001 | 词典详情页多区块「页面出错了」（release 真机） | `buildDictionaryDetailScope` 全工程零调用，页面 Consumer 抛 Provider not found（error_boundary.log 实锤） | `305113b` | `test/regression/regression_dictionary_page_test.dart`（裸 push 渲染不崩） |
| REG-DICT-002 | 派生词/近义词跳转后新词头配旧词释义（数据错配） | 跳转用 `Provider.value` 复用同一 DetailState，该实例只 loadWord 过主词 | `305113b` | 同上（跳转后新页释义=新词数据） |
| REG-DOCK-001 | 词书选择页底部工具栏与悬浮 Dock 重叠 | MainShell 悬浮 Dock 于内容之上，页面底部固定内容未预留 Dock 高度 | `305113b` | 同上（clearance = 安全区+16+64 契约锁定） |
| REG-DICT-003（流程） | release 崩溃凭代码推断修复两批未中真因 | 未先读 error_boundary.log 真实异常栈 | `305113b` | 流程约定：release 崩溃排障第一步=读 `%APPDATA%/com.monsterword/Monster Word/logs/error_boundary.log` |
| REG-MSG-001 | 消息页 build 期间调用 setState（itemBuilder 内触发 `_loadMessages()`），且真数据渲染暴露 ListTile 断言（背景色被 DecoratedBox 遮挡） | 假分页骨架在 itemBuilder 中同步触发 setState；ListTile 未包透明 Material | 第十六批 | `test/regression/regression_message_page_test.dart`（裸 push 渲染真实列表无异常） |
| REG-MSG-002 | 消息中心「全部已读」空操作（TODO 壳子） | 页面为静态壳，无数据源 | 第十六批 | 同上（点击后 unreadCount=0 且按钮消失） |
| REG-FDB-001 | 反馈提交为 800ms 假延迟，内容直接丢弃却显示「感谢反馈」 | `_submit` 无任何持久化/上报逻辑 | 第十七批 | `test/regression/regression_feedback_diagnosis_test.dart`（提交后本地存档可读回） |
| REG-FDB-002 | 空内容提交未拦截（假提交流程连带） | 同上 | 第十七批 | 同上（空内容 SnackBar 提示、不进感谢页） |
| REG-NET-001 | 网络诊断硬编码「全部成功」，断网也显示一切正常（误导性假语义） | 诊断步骤为常量列表，无真实检测 | 第十七批 | 同上（mock 失败步骤时页面显示 error 图标与失败文案） |
| REG-MSG-003 | 消息中心入口红点硬编码常显（无未读也亮红点）；另一入口则完全无角标 | my_space 入口红点为静态装饰、未接数据源 | 第十八批 | `test/regression/regression_message_badge_test.dart`（有未读显数字、已读消失、>99 显 99+） |
| REG-UPD-001 | 「检查更新」无任何版本比对，永远弹「已是最新版本」 | 更新弹窗为静态 UI，无远端请求与比较逻辑 | 第十九批 | `test/features/settings/data/github_update_check_service_test.dart`（版本比较纯函数 + Release JSON 解析 + 失败不假装最新） |
| REG-FDB-003 | 「评价应用」提交仅弹SnackBar，无真实动作 | 假提交 | 第十九批 | 同上文件所在批次的页面改造：4-5 星跳 GitHub 仓库页、1-3 星引导应用内反馈 |
| REG-POSTER-001 | 分享海报总词数硬编码 25000，与实际词库不符 | 海报数据源未接统计状态 | 第十九批 | `_sharePoster` 改读 LearningStatisticsState.memoryStats['total']（与统计面板同源，单一事实来源） |
| REG-REM-001 | 「学习提醒」开关空转：切换无任何真实效果 | 无通知调度实现（flutter_local_notifications 缺位） | 第二十批 | `test/regression/regression_study_reminder_test.dart`（开启真调度+诚实提示；权限被拒/调度失败开关回滚；关闭真取消）+ `local_study_reminder_service_test.dart`（调度时刻计算/幂等） |
| REG-CHK-001 | 签到历史页日历恒空、连签天数恒 0（与签到日历不一致） | 双数据源：签到只写尖叫币账本（scare_coin.checkin_dates），另一套 CheckInService（check_in_records_v1/streak_days_v1）只读从不写且 CheckinWriter 零调用方 | 第二十三批（修复）/ 第二十六批（补守护） | `test/regression/regression_checkin_test.dart`（写入→历史/状态读取器同源可读、同日重复签到幂等、三个适配器连签报告一致）；另由 `app_structure_test.dart` 断言 checkin_service.dart 不存在防复活 |
| REG-ARCH-003 | 复审 A4：app.dart 12 层 Provider scope 嵌套顺序仅 1 对有断言，其余靠注释维护——learning 被跨模块消费 189 处，挪位即全库运行时 ProviderNotFound（编译期静默） | 守卫覆盖缺口（非 bug，复审 H3/A4 半修复补全） | 第二十八批（v2.7.39+80） | `test/architecture/app_structure_test.dart` REG-ARCH-003（锁定 buildWordAudioScope→...→buildWordBrowseFeatureScope→SkinSystem MultiProvider 完整链序） |
| REG-ARCH-004 | 复审 A5：尖叫币/装备卡片在 my_space_page 与 profile_screen 双写且已漂移（裸 Container vs MwCard、字符串路由 '/scare_coin_history' vs RouteNames、装备数规则 1+(redeemed>0)+(streak>0) 两处各写一遍、装备徽章两套配色） | 双写无单一事实来源（非 bug，UI 分叉） | 第二十九批（v2.7.41+82） | `test/architecture/app_structure_test.dart` A5（共享组件 lib/widgets/scare_coin_summary_cards.dart 唯一持有：双卡类/双路由/装备数规则仅 1 次，两页面零双写、无字符串路由）；共享组件依赖边界由 ImportGuard R-widgets 锁定 |
| REG-DICT-003 | 词典详情页「例句」tab 整段渲染原始 JSON（{"fid":...} 乱码），「真题」tab 与例句 tab 内容完全相同（双写），dictionary_extra.json 真题数据零消费 | ServiceDictionaryContentReader.getExamExamples 把 word.example 结构化 JSON 当纯文本 split('\n')，未走 ExampleParser | 第三十批（v2.7.45+86） | `test/regression/regression_dictionary_page_test.dart` REG-DICT-003（例句 tab 渲染解析后句子且无 JSON 字段残留、真题 tab 读扩展数据带来源徽章且与例句不双写） |
| REG-DICT-004 | 全库 84%（21,076/25,191）词条 example 为双重编码 JSON（外层多包一层字符串），ExampleParser.parse 一次解码得 String 后 as List 抛 TypeError 被吞——这些词的例句 tab/学习页例句/导出页例句静默为空 | 词库导入管道对该字段重复 json.dumps 一次；解析器无二次解码兼容 | 第三十一批（v2.7.46+87） | `test/data/example_parser_test.dart`（双重编码 parse/parseCollins 二次解码用例 + 损坏原文返回空不渲染原文） |
| REG-DICT-005 | 词典详情页「派生」「近义」tab 仍是裸 GestureDetector 卡片（无按压反馈/无阴影、两 tab 圆角 lg/xl 不一致），空状态是旧式「标题+灰字」灰盒，与精致化后的柯林斯/例句/真题 tab 风格割裂 | 两 tab 未随 v2.7.45 六 tab 一体化改造同步升级（遗留旧实现） | 第三十二批（v2.7.47+88） | `test/regression/regression_dictionary_page_test.dart` REG-DICT-005（两 tab MwCard 卡片化锁定、有音标派生词带发音按钮、空状态统一 _emptyTab 图标化、旧式灰盒标题不得复现） |
| REG-CONTENT-001 | 句库页（例句收藏落点页）例句卡片为裸 GestureDetector+Container：无按压反馈、无阴影、选中态靠 2px 描边，与词典页 MwCard/ExampleTile 风格割裂 | 该页未随 v2.7.45 例句收藏闭环改造同步升级 | 第三十三批（v2.7.48+89） | `test/regression/regression_my_fav_sentence_page_test.dart` REG-CONTENT-001（MwCard 卡片化锁定、编辑态选中 check_circle 不丢、非编辑态 push RouteNames.sentenceDetail 导航契约保持） |
| REG-CONTENT-002 | 语义色硬编码绕过 token：例句学习页「不认识」按钮 Colors.orange、FSRS 记忆预测四档 Colors.red/orange/blue/green、仪表盘统计色 Colors.blue/orange/red/green——与 MistralColors.warning/info/danger/success token 脱钩，主题调整时四处漂移 | 直接写 Material 色名未走 design_tokens（token 纪律缺失） | 第三十五批（v2.7.50+91） | `test/features/content/presentation/sentence_learning_page_test.dart`「不认识」按钮 foregroundColor == MistralColors.warning 锁定；翻卡 ScaleDownOnPress 按压反馈同步落地 |
| REG-DICT-006 | 同一真题数据源（dictionary_extra.examSentences）两套视觉：词典页真题 tab（cardBg/lg 圆角/accent 0.12 徽章在句下）vs 学习侧词详情页「真题例句」区块（cardBgAlt/md 圆角/橙实色徽章在句上）；近义词 Chip 用 0.85 实色+白字，偏离全 App 淡底胶囊规则 | 真题卡两处各自内联实现（双写无单一事实来源） | 第三十四批（v2.7.49+90） | `test/regression/regression_dictionary_page_test.dart` REG-DICT-006（共享 ExamSentenceCard 渲染契约：句子+徽章、徽章文字色=皮肤 accent、空来源无徽章）；两页调用点唯一实现 |
| REG-AUDIT-L2 | 同一紧凑时间串解析逻辑两处双写：句库页 `_formatDate`（yyyyMMdd→MM/dd）与笔记区 `_formatDate`（yyyyMMddHHmmss→yyyy-MM-dd HH:mm）各自手写 substring，规则漂移无守护 | 日期解析散落页面层，未沉淀共享工具（单一事实来源缺失） | 第三十六批（v2.7.51+92） | `test/unit/date_format_utils_test.dart`（formatMonthDay/formatCompactDateTime 正常解析 + 长度不足降级不抛异常锁定）；两页调用点唯一实现 |
| REG-AUDIT-L3 | SP key 裸字符串散落：lib_select_page.dart 两处 `'daily_goal_prompt_shown'` 裸 key 直写，与 AppPreferences 常量体系脱钩，拼写漂移即静默丢数据 | SP key 常量未收口到 AppPreferences（key 管理双轨） | 第三十六批（v2.7.51+92） | `lib/core/infrastructure/app_preferences.dart` 新增 `dailyGoalPromptShownKey` 常量，lib_select_page 调用点改为常量引用；守卫由既有 daily_goal 单元测试承担 |
| REG-LEARN-001 | 词书加载硬编码截断：learning 侧 RepositoryBookWordsReader 硬编码 `limit: 1000`，大词书学习队列静默缺词；且 WordRepositoryImpl `limit ?? 50` 暗坑——漏传 limit 的调用方只会拿到 50 词 | 端口消费方硬编码截断值 + repository 层默认值掩盖语义 | 第三十八批（v2.7.53+94） | `test/features/learning/application/word_list_readers_test.dart` 锁定 loadWords 不传 limit（null=全量）；WordRepositoryImpl 改 `limit ?? -1`（SQLite 无限制语义）并在接口注释声明契约 |
| REG-ARCH-004 | 跨 feature 端口同名双写：learning 与 book 各声明一个 `BookWordsReader`（行为不同：截断 vs 全量），接错线编译期不报错 | 端口命名冲突无守卫 | 第三十八批（v2.7.53+94） | book 侧整体更名 `BookWordListReader`（文件/类/适配器同步）；`test/architecture/no_duplicate_port_names_test.dart` 扫描全部 feature application 层，锁定抽象端口名不得跨 feature 重复 |
| REG-MEM-001 | 词书单词列表页把整书 lightweight `Word` 一次性载入内存（大词书数千条常驻）；`countAllNotes` 每次计数扫描并 jsonDecode 全部笔记键 | 列表浏览与全量加载共用同一端口方法，无分页口径；计数无缓存 | 内存第二批（2026-09-23，PR #57，MEM/F2+U5） | `BookWordListReader` 端口新增 `countWords/loadWordPage/loadWordTexts`（真分页，COUNT 总量口径）；`book_state_test` 锁定首屏窗口=pageSize、`loadMore` 到底收敛且 no-op；`repository_book_word_list_reader_test` 锁定分页拼接==全量、lightweight 无 example；REG-LEARN-001 守卫同步修订为「全量路径无数字截断 + 分页 limit 必须参数化」；`note_repository_impl_test` 锁定写入失效重算 |

| REG-OBS-001 | 56 处 `catch (_)` 空捕获吞错：数据路径异常对 Sentry 完全不可见——典型为收藏加载失败后用户收藏静默"消失"（fav_repository_impl）；同类的还有笔记、已掌握词表、金币账本、用户信息、今日学习数等 13 处 | 空捕获无上报通道，可观测性盲区 | 第三十九批（v2.7.54+95） | 新增 `lib/core/utils/swallowed_error_report.dart`（debugPrint + Sentry captureEvent，isEnabled 守卫）；A 级 13 处接上报，B/C 级 43 处补豁免注释；`test/architecture/swallowed_error_guard_test.dart` 锁定 A 级文件必须调用上报 |

| REG-ARCH-005 | presentation 直连数据库单例 3 处：word_detail_page（getWord 常规读）、book_words_page（forceRebuild + diagnostics）、more_settings_page（forceRebuild），违反 architecture_boundaries.md §2；且 ImportGuard 只拦反向依赖，此类正向直连 CI 拦不住 | 管理操作与查询无 application 入口，页面绕过端口直取单例 | 第四十批（v2.7.55+96） | 新增 `core/application/wordbook_maintenance_service.dart`（诊断/重建唯一入口，类型经 export 转发）+ book/settings providers 注入；word_detail 改走既有 WordRepository Provider 通道（getWordByText 语义等价）；ImportGuard 新增 R-DB 规则 + import_guard_test 用例 |

| REG-LEARN-002 | FSRS 学习记录以 3 个 SP key 全量 blob 存储且每次评分 3 次 jsonEncode 全量重写（词量数千时每次评分重写数 MB）；写入中途被杀 = 整个 blob 损坏丢全部学习记录，且 SP 无事务 | 持久化层选型失误（blob 全量写而非行式存储），写入口高度收敛（load 1 处 + rateWord/forget）具备无损切换条件 | 第四十一批（v2.7.56+97，批次 E1） | 新增 `lib/features/learning/data/review_schedule_store.dart`（独立 review_schedule.db 三表，与词库物理隔离防重建误伤）+ repository 首启事务迁移（损坏行跳过上报、行数校验在事务内、失败降级 SP 下次重试）+ 写路径单事务 O(1)；旧 SP key 保留为只读回滚快照（E2 另批清理）；`test/features/learning/data/review_schedule_store_test.dart`（4 用例）+ `review_schedule_migration_test.dart`（6 用例：迁移/防重复迁移/空数据/损坏降级/往返/SP 模式回写） |

| REG-DOCK-002 | 课程页底部工具栏与悬浮 Dock 几何重叠 | MainShell 悬浮 Dock 覆盖页脚操作区，clearance 预留丢失 | c9b5d2e | `test/regression/regression_dock_clearance_test.dart` |
| REG-START-001~003 | 首启引导/登录 fail-safe 路径回归 | 启动双时间线竞态、引导标记未持久化 | 启动批 | `test/regression/regression_start_flow_test.dart` |
| REG-ZONE-001 | Zone mismatch（Zone.current 与 Flutter 绑定不一致） | bootstrap 未整体包 `runZonedGuarded` | 7ac78c6 | `test/regression/regression_zone001_boot_zone_test.dart` |
| REG-STYLE-001~003 | 精选风格数量/迁移表漂移 | 主题精选集合无守卫 | 风格批 | `test/regression/regression_style_test.dart` |
| REG-EQUIP-001 | 装备架三入口/收藏陈列数据缺失 | 陈列页假数据或路由断线 | 装备架批 | `test/regression/regression_equip001_rack_test.dart` |
| REG-STEREO-001 | 随身听词源空态/连播/播放顺序入口回归 | 播放器与词源装配脱节 | 随身听批 | `test/regression/regression_stereo001_sources_test.dart` |
| REG-LISTEN-001 | 磁带机 UI：旋转/进度/上一首下一首禁用 | 同族化改造后控件契约漂移 | C1 磁带批 | `test/regression/regression_listen001_player_test.dart` |
| REG-SPELL-001 | 快速拼写反馈/计数/空态/超时结束 | 拼写测验脚手架统一后行为回归 | 拼写脚手架批 | `test/regression/regression_spell001_quiz_flow_test.dart` |
| REG-DICT-005b | 词根/例句字段契约：非空 word_root 必须是合法 JSON；非空 example 解析后例句或柯林斯释义至少其一非空（2026-10-03 词库修复批放宽：柯林斯压扁串已结构化复原，def-only 词条 parseCollins 可渲染） | 词库导入字段质量无守卫 | 数据质量批（2026-10-03 修复：771,251 词条 C1-C10 契约全过，80.0→79.0MB） | `test/regression/regression_dict005_fields_test.dart` |
| REG-ARCH-006 | presentation 直取 GetIt / 直连同 feature data / 直触 core 仓储与 AppPreferences | 守卫字符串匹配洞 + 端口模型空心化 | PR #44 + 残债④⑤⑥ | `import_guard.dart` R6-DI(package:get_it)/R3(presentation→data)/R-core-repo/R-prefs + `import_guard_test.dart` |


| REG-LEARN-002b | E1 迁移后旧 SP 回滚快照长期滞留（事实来源双轨） | 观察期后未清理 | batch7（2026-09-20） | SQLite 模式且 marker=done 时删除三 key；降级模式不删；review_schedule_migration_test E2 |
| REG-ARCH-007 | 9 套皮肤 preset 色值与 token 双写漂移风险 | 仅星巴克 token 化 | batch7 | lib/tokens/skin_tokens.dart + theme_token_consistency_test 9 套锁定 |
| REG-TYPE-001 | fontSize 字面量棘轮 44 处 | 未收敛字号 token | batch7 | AppFontSizes.*；font_hygiene_test 上限 1 |
| REG-FSRS-003 | FSRS 迁移 cards/stats 非原子；rateWord 写失败静默 | 三事务拆分 + 无 catch | H1/H3 批（2026-09-20） | `ReviewScheduleStore.migrateFromSp` 单事务 + marker 完成门闩；rateWord/forget 持久化 `reportSwallowedError` |
| REG-FSRS-004 | E2 清 SP 后库损坏无恢复源 | 快照直接删除 | H2 批 | E2 前写入 `fsrs6_emergency_backup_v1`；迁移测试覆盖备份 key |
| REG-ARCH-008 | core→app / domain→infra 盲区 | 守卫只扫 features | M2/M3 批 | ImportGuard R-core-app + R5b + import_guard_test |
| REG-REVIEW-001 | 空复习队列塞入 searchWords 抽样假词 | 回退假队列 | M7 批 | `RepositoryReviewQueueReader` 空态返回 `[]`；`review_queue_reader_test` |


| REG-ARCH-009 | LearningSessionState 与 Provider 双实例门面（M1 残债） | providers 创建 session 未注入 TodayProgressStore/PresentationPrefs | N1 批（2026-09-20） | 装配层先建门面再注入 session；widgets `context.read`；架构测试禁非装配文件直建 |
| REG-OPS-001 | build_full_wordbook 无备份覆盖 assets | H4 只覆盖 expanded 脚本 | N2 批 | 默认 OUT 到 inputs/；`ALLOW_ASSET_OVERWRITE` + `.bak` |
| REG-NAV-005 | 页面 routeName 字面量与 RouteNames 双源 | 无单源守卫 | N3 批 | presentation `routeName = RouteNames.*`；路由表唯一事实来源 |

| REG-ARCH-010 | 守卫断言匹配注释假绿；dictionary 内层第二 PresentationPrefs；E2 备份未自动恢复 | N1 迁移后测试未改；providers 遮蔽；降级只读空 SP | R1–R3 批（2026-09-20） | app_structure 断言 PresentationPrefs.equipRackCount；dictionary 去 create；降级 load 读 emergency_backup |

| REG-NAV-006 | SearchPage 路由双源 | 无全库 RouteNames 守卫 | R4 批 | RouteNames.search + route_name_consistency_test |
| REG-TYPE-002 | fontSize N*fontScale 盲区 | regex 未覆盖 scale | R6 批 | AppFontSizes.* * fontScale + scale 棘轮 0 |
| REG-FSRS-005 | 迁移行数校验语义 | 空迁移/双实现 | R7 批 | migrateFromSp 校验 count≥cards.length |
| REG-SPEECH-001 | 首页怪兽对真实用户报假事实：「钱包里躺着 0 枚尖叫币」「我现在是奶泡形态」「签到 0 天啦」 | 台词变量在调用处硬编码占位值（未接线），且测试把同一组假值渲染结果锁进断言 | 2026-10-04 P2 批（10-03 审计 P2-1） | `test/core/utils/monster_speech_test.dart`（值为 null/键缺失 → 含该占位符模板整条跳过；每槽保底无变量文案不变式）、`test/features/learning/presentation/home_greeting_test.dart`（候选集按注入的真实余额/天数生成；无账本语境不提尖叫币） |
| REG-SPEECH-002 | 点怪兽后 800ms 节拍窗内再点一次，路由栈叠两层「我的空间」（需返回两次） | `_greet` 无重入闸（同区间 overlay 都有 `_playing` 串行门，此处漏） | 2026-10-04 P2 批（P2-6） | `home_greeting_test.dart`（连点两下只推开一层 my_space） |
| REG-ROLL-001 | 顶栏余额滚动动画永不发生，且新余额查询期间闪一下 0 | FutureBuilder 与 RollingNumber 各挂 ValueKey → State 整体重建（快照回退 data==null、tween begin==end）；`didUpdateWidget` 取旧目标而非当前显示值 | 2026-10-04 P2 批（P2-2） | `test/widgets/rolling_number_test.dart`（中途换目标必须从当前显示值接续滚动） |
| REG-CHECKIN-001 | 签到成功路径中段裸 await：取 checkinDates 抛错则 `_busy` 永久 true（按钮软锁到重进页面），且 await 后 setState 缺 mounted | 同步改 async 时未重画错误边界 | 2026-10-04 P2 批（P2-5） | `test/features/checkin/presentation/treasure_checkin_page_test.dart`（checkinDates 抛错仍照常结算） |
| REG-IDENT-001 | 开局命名的怪兽名「只写不读」：`MonsterIdentityPrefs.name()` 全库零消费点，头注释虚报「与 profile 门牌共用」 | 交付即接线缺口 + 注释不实 | 2026-10-04 P2 批（P2-4；类同时从 account/presentation 移至 `core/utils/monster_identity_prefs.dart` 以走跨域合规通道） | `test/features/settings/presentation/monster_room_view_test.dart`（门牌回显真实怪兽名；未破壳不出该行，不把默认名冒充命名） |
| REG-START-002 | 已登录用户可能永久卡死启动页 | `_goToMain` 改 async 后以 `unawaited` 调用，其内部 await 脱离外层 try/catch，而 `_phase` 已置 completed 拒绝一切重入 | 2026-10-04 P2 批（P2-7：改回 try 内 await + `_goToMain` 内部读失败降级进主页） | 守护测试待补（需 SharedPreferences 读抛错注入点）；正常流仍由 `regression_start_flow_test.dart` 覆盖 |
| REG-HATCH-001 | 命名仪式唯一持久化路径无 catch：失败时按钮无 loading 无提示，异常经 zone 变匿名全局错 | 交付即接线缺口的错误边界侧 | 2026-10-04 P2 批（P2-9：try/catch + reportSwallowedError + SnackBar + `_saving` 闸门） | 守护测试待补（SP 写抛错无注入点） |
| REG-FLAME-001 | 首页签到后火苗 ticker 永不停止，残留全天 60fps 空转（AnimatedBuilder 已不在树上） | controller 只启动不回收 | 2026-10-04 P2 批（P2-10：`_reload` 已签/降级分支 `_flameCtrl.stop()`） | 守护测试待补（controller 私有；建议随 I 类常驻 ticker 专测一并做） |
| REG-VOICE-001 | 同一帧内两场仪式双双通过发声闸门 → 系统 TTS 被连续 speak 两次，前一句被后一句截断（台词堆叠） | 「查 `_talking` → await 语音可用性 → 才置位」不是原子占用：两个调用在同一次 await 的交叠期都过了闸 | 2026-10-04「怪兽开口」批（写测试时抓到，非事后补记——占用发声道移到任何 await 之前） | `test/core/utils/monster_voice_test.dart`（发声期间的第二个请求返回 false 且只念一句，结束后闸门复位） |

## 修复新 bug 的流程


1. 修复前先写失败的回归测试（证明 bug 存在）
2. 修复代码使测试转绿
3. 在本台账登记：REG-ID、症状、根因、修复 commit、守护测试路径
4. CI 全绿后合入

## CI 阻断链

```
push/PR → main
  ├─ dart format --set-exit-if-changed   (格式)
  ├─ flutter analyze                     (静态分析, error 阻断)
  ├─ flutter test (全部 636+ 用例)        (单元/组件/回归/守卫, 失败阻断)
  └─ test -s assets/db/wordbook.db.gz    (词库资产存在性)
```
| REG-AUDIT-001 | 收藏词 SQLite 迁移：事务提交与 marker 写入之间崩溃后，每次启动行数校验失败→永久降级 SP 且循环报错 | 迁移校验只看本次插入数，未考虑 DB 已含全集的自愈场景 | 2026-09-27 审计批次（B6） | `test/core/infrastructure/favorite_words_dao_test.dart`（迁移幂等 + REG-AUDIT-001 崩溃现场自愈注入 + 持久化失败回滚） |
| REG-AUDIT-002 | FSRS 每日统计在 Android ≤9 全部静默不落盘（`ON CONFLICT DO UPDATE` 需 SQLite≥3.24，系统库 3.22 抛语法错被上层吞） | UPSERT 语法兼容性 | 同上（B13） | `test/features/learning/data/review_schedule_store_test.dart`（统计累加口径）；API≤28 真机验证待补（I91） |
| REG-AUDIT-003 | 金币账本/反馈存档 JSON 损坏后被"仅含 1 条"的列表覆写清空 | 吞错后继续走覆写路径 | 同上（B1/B2/I56） | `test/features/scare_coin/data/preferences_scare_coin_store_test.dart`（REG-AUDIT-003 损坏不覆写双路径 + 负余额拒绝）、`test/regression/regression_feedback_diagnosis_test.dart`（存档损坏不覆写仍上报）、`test/core/infrastructure/fav_sentence_dao_test.dart`（SP 损坏中止迁移） |
| REG-AUDIT-004 | 设置页"每日新学"弹层输入即崩（控制器在弹窗关闭前被 dispose）；搜索页 300ms 内退出崩（防抖 Timer 未取消） | 生命周期时序 | 同上（A1/A2） | `test/regression/regression_dispose_timing_test.dart`（A1/A2 两条 testWidgets 守护；2026-10-04 复核更新） |
| REG-AUDIT-005 | TTS 文本朗读必然 404（完整 URL 再拼基址）；时区回退名反号（UTC+8 → `Etc/GMT--8` 非法） | URL 拼接与 POSIX 反号语义 | 同上（D2/D3） | `local_study_reminder_service_test.dart`（时区名构造可单测）；音频主备 URL 逻辑待补单测 |
| REG-AUTH-001 | 本机密码哈希为单轮 SHA-256（快速哈希），安全存储被提取后弱口令可秒级爆破 | KDF 缺位 | 同上（J3/I42） | `test/features/account/data/secure_password_auth_store_test.dart`（RFC 2898 参考向量 + 存量透明升级 + 失败不升级） |
| REG-COIN-001 | 兑换耗材在库存被并发填满时扣 200 币、卡未到账、退款不触发（页面预检用陈旧快照，addProtection 满额静默钳制不抛错） | 满额钳制无信号，补偿退款分支不可达 | 2026-10-04 审计批（P1：addProtection 满额抛 StateError + 退款独立 try/catch 上报） | `test/features/scare_coin/data/preferences_scare_coin_store_test.dart`（满额抛错口径）；页面级注入待补 |
| REG-COIN-002 | 补偿退款自身失败被外层 catch(_) 吞掉：扣币已落地、退款未到账且零上报 | 退款路径无第二层保护 | 2026-10-04 审计批（_refund 独立 try/catch + reportSwallowedError） | 守护测试待补（退款 grant 抛错注入） |
| REG-USERDB-001 | user_data.db 打开遇到瞬时文件锁（杀毒/备份软件）即被当损坏删库重建，生词本（无 SP 快照）永久清空 | 打开异常不区分「瞬时 IO」与「真损坏」，且删除前无备份 | 2026-10-04 审计批（P1：先重试一次，判损后改名 .corrupt.bak 留档再重建） | 守护测试待补（需注入文件锁场景） |
| REG-CHECKIN-002 | 签到入账失败 `_busy` 永久 true：按钮软锁到重进页面，异常只进 zone 无提示 | `await store.checkIn()` 无 try/catch/finally | 2026-10-04 审计批 | `test/features/checkin/presentation/treasure_checkin_page_test.dart`（入账抛错 → SnackBar + CTA 可再点） |
| REWARD-001 | 答对奖励「先计数后发币」：发币失败烧掉当日封顶名额；会话结算「先发币后写标记」：标记写失败次日重复发奖 | 两处写序相反且都无回滚 | 2026-10-04 审计批（统一「先持久化防重标记（校验返回值）、发币失败回滚标记」） | `test/features/learning/application/`（待补：setInt 失败/发币抛错注入） |
| REG-VOICE-002 | MonsterVoice 失败降级是死代码：speakChinese 吞错，say() 实际无声仍返回 true，markChineseVoiceUnavailable 不可达 | 错误信号链断裂 | 2026-10-04 审计批（speakChinese rethrow + say catch 标记降级） | `test/core/utils/monster_voice_test.dart`（throwOnSpeak → false）既有用例即守护 |
| REG-SFX-001 | 静音三态切换确认音 2/3 档位听不到（先切档再发声，音量已归零/被短路） | 反馈音时序 | 2026-10-04 审计批（先 fire 再 cycle） | 守护测试待补（SfxPlayer 行为测试，见测试审计 #2） |
| REG-TTS-001 | 随身听 wordMeaning 播放中退出页面：TTS 完成回调把已 dispose 的 State 闭包装回单例（引用泄漏直到下次赋值） | speakWordWithMeaning finally 无条件恢复旧回调 | 2026-10-04 审计批（槽位被清空则不恢复） | 守护测试待补（单例回调时序） |
