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
