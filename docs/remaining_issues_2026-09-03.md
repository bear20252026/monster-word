# 遗留问题清单（2026-09-03 更新）

> 对照 `docs/audit/审计报告-2026-09-02.md` 与 `docs/audit/架构复审报告-2026-09-02.md`，
> 经 2026-09-03 只读复核后的真实开口清单。审计主体欠账已全部清零，本文件是剩余事项的唯一事实来源。

## 一、审计闭环总览（截至 v2.7.51+92）

| 编号 | 问题 | 状态 | 收口版本 / 守卫 |
|---|---|---|---|
| S1-S4 | 严重级 4 项 | ✅ 闭环 | release_packages.yml quality-gate / 死文件清理 / service_locator 移除 / 回归测试在位 |
| H1-H3 | 高危 3 项 | ✅ 闭环 | import_checker / 假预览卡删除 / scope 顺序锁（REG-ARCH-003） |
| M1 | feature 缺层豁免未文档化 | ✅ 闭环 | v2.7.51+92：architecture_boundaries.md §1.2 |
| M2/A3 | DI 双轨（presentation 直取 sl<>） | ✅ 闭环 | R6 收口 + 规则测试 |
| M3 | 既有发现 | ✅ 闭环 | 对应批次守卫 |
| M4/A1/⑥-1 | 星巴克主题三处重复且漂移 | ✅ 闭环 | **v2.7.38 收敛**（token 唯一定义点 + preset 全字段引常量）+ `test/architecture/theme_token_consistency_test.dart` 锁定；2026-09-03 全库扫描色值分叉为 0 |
| M5 | features/widgets 硬编码颜色 | ✅ 闭环 | 对应批次守卫；语义色 token 纪律另于 v2.7.50+91 收口（REG-CONTENT-002） |
| M6/A5 | _CoinCard/_EquipCard 双写 | ✅ 闭环 | 共享组件收口批次 |
| M7/A6 | wordbook_database 并发竞态 | ✅ 闭环 | 互斥收口批次 |
| A2 | widgets/ 层 ImportGuard 盲区 | ✅ 闭环 | v2.7.40 起 R-widgets 规则（import_guard.dart） |
| A4/H3 | 11 层 scope 全序未锁 | ✅ 闭环 | REG-ARCH-003 全序断言 |
| L2 | 日期解析双实现 | ✅ 闭环 | v2.7.51+92：date_format_utils 收口（REG-AUDIT-L2） |
| L3 | SP key 散落 | ✅ 闭环 | v2.7.51+92：dailyGoalPromptShownKey 归位（REG-AUDIT-L3） |

## 二、代码侧真实开口

### L4（低优）：test/pages/ 14 个批次命名遗留测试文件归位

唯一剩余审计欠账。`test/pages/` 按修复批次命名（fix6 / ux_fix_b / app1），已摸清全部归属：

| 现文件 | 主消费域 | 建议去向 |
|---|---|---|
| account_fix6_test.dart | account | test/features/account/presentation/ |
| export_readable_test.dart | core/parsers | test/core/parsers/ |
| learn_page_completion_test.dart | 待细看（无直接 feature import） | learning 或 core |
| nav_app1_test.dart | app 导航 | test/app/ |
| nav_safety_simple_test.dart | app 导航 | test/app/ |
| nav_safety_test.dart | app 导航 | test/app/ |
| redemption_center_page_ux_test.dart | scare_coin | test/features/scare_coin/presentation/ |
| session_empty_and_mounted_test.dart | learning | test/features/learning/presentation/ |
| uri_scheme_page_test.dart | core 深链解析 | test/core/ |
| ux_fix_b_home_book_test.dart | models/book | test/models/ |
| ux_fix_c_test.dart | models/word + skin | test/models/ |
| word_detail_fix3_test.dart | dictionary | test/features/dictionary/presentation/ |
| word_detail_phrase_root_test.dart | dictionary | test/features/dictionary/presentation/ |
| word_dictionary_deeplink_test.dart | app/router + dictionary | test/app/ |

执行方式：纯机械 `git mv` + 语义化重命名（如 word_detail_fix3 → 按实际被测行为命名），不改测试逻辑，全量测试验证。可发一版（建议 v2.7.52+93）或仅 push 不发版。

### 可选专项（非欠账）：9 套皮肤 token 化

skin_system 其余 9 套皮肤（bright/dark/pure_black/warm_orange/claude_cream/airbnb_light/nike_mono/apple_light/clickhouse_dark）共约 240 处内联字面量，属 `theme_token_consistency_test.dart` 明确豁免范围（不对应 token 集）。如要收口：按星巴克模式逐皮肤建 token 文件（lib/tokens/<skin>_tokens.dart）→ preset 全字段引常量 → 守卫测试逐皮肤扩展。改动面大（每皮肤 ~30 字段），需逐皮肤视觉验证，建议单独立项分多批。

### 已评估暂缓项

- 裸 TextStyle 全面转换：9+7+4 处分散在 widgets 层，单点收益低、连带回归风险高，暂缓。
- WordRootTab 抽共享：两页共用已一致，抽取防连带回归收益低，暂缓。

## 三、用户侧 / 既有决定事项

| 事项 | 状态 |
|---|---|
| 装机实测积压 v2.7.47~51 | 用户侧待验证：派生/近义按压反馈、句库多选、词详情拓展区块、翻卡手感、语义色（仪表盘/FSRS 四档） |
| core/router 上移 app/ | 用户拍板另列批次（60 文件引用，纯机械） |
| #5 微信提醒开关 | 用户明确不动 |
| 密钥备份仓库提醒 | 用户侧既定不动 |
| v2.7.24~37 真机验证 | 用户积压中 |

## 四、发版状态

- 最新版本：**v2.7.51+92**（commit cafc0df，2026-09-03）
- 产物：`Downloads/monster-word-releases/v2.7.51/`（Setup exe + aab + apk，三项与 Release 资产字节一致）
- CI 门禁：format / analyze 0 issue / 全量 768 用例 / 三流水线全绿
- 当日累计发版：八连发 v2.7.44+85 → v2.7.51+92（UI 割裂点、token 纪律、审计遗留全部清零）
