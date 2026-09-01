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
