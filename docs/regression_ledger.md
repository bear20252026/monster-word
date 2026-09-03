# Monster Word 回归测试台账（Regression Ledger）

> 原则：**每个已修复的 bug 必须有对应的永久回归测试**（REG-ID 命名），
> 由 CI（GitHub Actions `dart.yml`：push/PR to main → `flutter test` 失败即阻断合并）强制执行。
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
| REG-NAV-001~004 | 无法前进/多层级返回 | Flutter 无内建 forward | `4a16217` | `test/core/router/navigation_history_test.dart`（前进/返回/分叉作废/弹层过滤） |
| REG-SKIN-001~003 | 一键换肤形态变颜色不变 / 品牌值趋同 | brandThemeMap 缺映射、B 档值被改平 | `d320ceb` | `test/regression/regression_skin_test.dart` |
| REG-DATA-001 | 词库数据缺失/损坏 | 词库精简/回填事故 | `8c9486b` | `test/data_verification_test.dart`（50 本/25k 词校验，CI 前置 `test -s assets/db/wordbook.db.gz`） |
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
