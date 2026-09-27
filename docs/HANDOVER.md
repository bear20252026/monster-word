# Monster Word 交接报告（HANDOVER）

> 面向接手维护的新成员。读完本文 + `README.md` + `docs/architecture_boundaries.md`，即可安全上手。
> 成文：2026-09-27，基于当日五轮全面审计（144 项修复）完成后的代码状态。
> 历史过程文档一律在 `docs/reports/`（HISTORICAL 快照，**不是现状**），勿按旧文档行事。

---

## 1. 产品是什么

**Monster Word** 是一款英语单词学习应用，Flutter 构建，发布 **Windows** + **Android** 双端：

- **学习内核**：FSRS 记忆算法调度复习（fsrs6_engine），词库与例句全部离线随包（77 万词条、272 本书），不联网即可完成学习闭环。
- **激励体系**：怪兽养成主线——肚皮储蓄罐签到仪式、聚宝日历、尖叫币经济（答对 +1、兑换保护卡）、金币庆祝动画、怪兽小屋个人中心。
- **多词书**：内置词书分类/封面体系，学习取样随机化（避免整批同首字母）。
- **双端自适应**：Windows 宽屏（悬浮 Dock、桌面导航历史条）与 Android 移动布局分别适配；皮肤系统（星巴克风格 base + 9 套皮肤）带 WCAG 对比度守卫。

包名 `word_app`（工程沿用），产品名 Monster Word。版本号 `X.Y.Z+NNN`（当前发版线见 git tag / pubspec）。

## 2. 技术栈与代码结构

| 层 | 选型 |
|---|---|
| 框架 | Flutter 3.47.0（CI 固定），Dart SDK `^3.13.0` |
| 状态管理 | Provider（ChangeNotifier + MultiProvider 分域 scope，装配集中在 `lib/app/app.dart` + 各 `*_feature_providers.dart`） |
| 数据 | sqflite / sqflite_common_ffi：`wordbook.db`（只读资产库，gzip 随包）+ `user_data.db`（用户库）；SharedPreferences（偏好，经 `PresentationPrefs` 端口）+ flutter_secure_storage（凭证） |
| DI | get_it（仅限组合根与 Provider 工厂，守卫锁定） |
| 通知 | flutter_local_notifications + flutter_timezone（学习提醒） |
| 监控 | Sentry（DSN 走 `--dart-define`，不硬编码） |

```
lib/
  app/            壳层：路由（go_router 风格自研 AppRouter + RouteNames 单源）、组合根、main_shell
  core/           引擎（FSRS/Leitner/超级记忆，干扰项生成器单一真相）、基础设施（两库 + DAO）、
                  仓储实现、音频（5 播放器 + TTS）、application 端口（PresentationPrefs 等）
  features/       垂直功能域：account/book/checkin/content/dictionary/learning/quick_review/
                  scare_coin/search/settings/word_browse——每域 presentation/application/domain/data 四层
  models/         Word / Definition / 句子模型 / definition_text.dart（释义解析单一真相）
  tokens/ theme/  设计 token 单真相（星巴克 preset == token，守卫测试锁定）
  widgets/        共享组件（金币、庆祝、骨架屏等；无业务页面）
test/
  architecture/   13 套守卫测试（67 例）——本项目最有价值的资产，见 §5
  features/ core/ regression/ unit/ data/   回归台账 REG-ID 对应的守护测试
scripts/          词库构建/数据修补（Python；archive/ 为一次性历史脚本）
assets/db/        wordbook.db.gz（只读词库，CI 有基线校验）
```

规模：lib 约 370 文件 / 5 万行；test 约 170 文件 / 1.8 万行（904 例全过）。

## 3. 关键机制（改代码前必读）

1. **词库库是只读资产**：`wordbook.db.gz` 随包分发，首启/升级解压（内存解压 + 临时文件原子替换），版本指纹命中即跳过。任何"给词库建索引/建 FTS"的想法都意味着重建资产发版（搜索 FTS5 改进正卡在这，见 §7）。
2. **用户库写兼容**：Android ≤9 系统 SQLite 为 3.22，**禁用 `INSERT…ON CONFLICT…DO UPDATE`**，累加写用 UPDATE+条件 INSERT（`review_schedule_store._upsertDailyStats`）。
3. **数据完整性口径**：持久化失败必须 `reportSwallowedError`（A/B/C 分级见 `lib/core/utils/swallowed_error_report.dart` 头注释，守卫测试锁定 A 级文件）；账本/存档类"解析失败保留原档，宁丢一条新账不清历史"；收藏 DAO 写路径有串行闸门 + 失败回滚内存索引。
4. **释义解析单一真相**：interpret JSON → 文本只存在于 `lib/models/definition_text.dart`；四选一干扰项只在 `lib/core/engine/distractor_generator.dart`。新增消费方禁止复制逻辑。
5. **SP key 单源**：`user_token`/`user_secret`/`monster_word_user_info` 仅定义于 `app_preferences.dart`；presentation 经 `PresentationPrefs` 端口读写偏好，**不得** import infrastructure（R-prefs 守卫会拦）。
6. **WebView**：`core/web/base_web_page.dart` https-only + 域名白名单（当前为空=全拒）；JS 禁用。
7. **密码**：PBKDF2-HMAC-SHA256 6 万轮（存格式 `pbkdf2-sha256$<n>$<hex>`）；存量单轮哈希登录时透明升级。测试含 RFC 参考向量。
8. **音频缓存**：系统缓存目录（非 Documents）；`audio_players.dart` 主备 URL 逻辑区分绝对/相对地址。

## 4. 质量门禁（每次提交前必跑）

```bash
flutter analyze --no-fatal-infos                                   # 必须 No issues found
dart format --line-length 120 --set-exit-if-changed --output=none .  # 必须 0 changed
flutter test test/architecture/                                    # 67 例守卫必须全过
flutter test                                                       # 全量 904 例必须全过
```

守卫测试（`test/architecture/`）是本仓库的核心资产：import 分层全库扫描、路由名单单源、颜色/字号/圆角/emoji 卫生、fontScale 与 radius 棘轮、TickerProvider、门面直建、吞错分级、词库指纹等——**它们曾连续拦截贡献者（含本审计）的不规范首版方案**，红灯时先读守卫的 reason 文案，不要绕过。回归台账 `docs/regression_ledger.md` 记录每个已修 bug 的 REG-ID 与守护测试位置。

## 5. 2026-09-27 全面审计（五轮 144 项）摘要

六维深扫（内存/错误处理/性能/数据层/安全/代码质量）确认 166 项问题，五轮修复 144 项：

| 轮次 | 重点 | 代表项 |
|---|---|---|
| 一 | 崩溃/数据丢失/死代码 | 弹层控制器提前 dispose、金币账本静默清空、UPSERT 旧 Android 不落盘、~1,050 行死代码删除、CI 签名熔断 + 全端混淆 |
| 二 | 双轨真相/迁移自愈 | 释义三轨合一、干扰项合一、收藏迁移崩溃自愈、PBKDF2 密码升级（存量透明迁移）、测试收敛 |
| 三 | 口径固化 | Sentry 主机派生 DSN、缓存目录迁移、SP key 单源、反馈存档保护、架构/发版文档补录 |
| 四 | 回归加固 | auto_sync 密钥双重防呆、损坏注入回归 9 用例、时区归一化、收藏写闸门 |
| 五 | 边界收口 | 生词本共享缓存（双入口一致）、AppSessionState 全端口化、词库索引实测健康 |

完整报告（166 问题 + 105 提升点清单 + 全部 file:line 证据）：`docs/audit/全面审计报告-2026-09-27.md`。

## 6. 发版流程（简版，详见 `docs/release_checklist.md`）

本地四门禁全绿 → `pubspec.yaml` + `installer.iss` 同 PR 升号 → 合 `main` → `git tag vX.Y.Z+NNN` 推送 → Release Packages workflow 自动出三件套（APK/AAB/Windows Setup，真签名，tag 缺 secrets 熔断）→ GitHub Release 核对 → 装机实测。**禁止 force push**；`scripts/auto_sync.sh` 是日常自动同步通道（含密钥防呆）。

## 7. 已知待办与决策点（接手人关注）

**需要项目所有者操作（代码侧无法代劳）**：

1. **Spug 短信模板码轮换**（最优先、5 分钟）：凭证随包可被盗刷，去 push.spug.cc 控制台轮换模板码并设发送上限；根治需服务端代理（`spug_sms_code_service.dart` 注释已留替换接口，用户已书面接受现风险）。
2. **release keystore 迁出项目目录**：`android/app/*.jks` + `key.properties` 仍在工程内（违反自家 release_pipeline §1.3），建议移至工程外密钥目录 + 高强度密码入管理器 + 仅 CI secrets 签名。
3. **GitHub 仓库设置**：建议开启分支保护（main 禁直推、PR 必审）——携带签名 secrets 的 job 目前对 main push 开放。

**排期中的工程项（`monster-word-全面审计报告-2026-09-27.md` 提升点清单 I1–I105，余 ~66 项）**：

- **与下次词库发版合并**：FTS5 搜索索引（剩余项中对体验影响最大，搜索全表扫根治，必须重建随包资产）+ 搜索基准测试。
- **独立 PR**：MwNavBar 组件化（28 处复制 ~420 行）、统一反馈出口（showMwConfirm 重建 + 56 处迁移）、金币账本 SQLite 化（接口契约变更波及 11 个测试假实现）。
- **需真机/profiler**：动画粒度优化 6 项（拖拽 setState、常驻 ticker 等，先 DevTools 基线后改）。
- **观察项**：new_words 软删行清理（待云同步设计定型）；旧 Android 评分落盘真机验证。
- 已核查关闭（勿重做）：词库索引健康（EXPLAIN 实测）、句库分页（残留全量是学习场景有意设计）、测试装配"去重"（差异即被测行为）。

## 8. 文档地图

| 位置 | 性质 |
|---|---|
| `README.md` | 产品说明 + 快速开始 + 门禁 |
| `docs/HANDOVER.md` | 本文 |
| `docs/architecture_boundaries.md` | **架构边界现行规范**（import 分层/路由/token/数据层口径 §7） |
| `docs/regression_ledger.md` | 回归台账（REG-ID，持续更新） |
| `docs/release_pipeline.md` / `release_checklist.md` / `commit_convention.md` | 发版与协作规范 |
| `docs/motion_spec.md` / `starbucks_tokens_draft.md` / `a11y_*_report.md` | 动效/色板 token 来源与对比度依据（被 lib/ 注释引用） |
| `docs/audit/` | 重大审计报告存档（2026-09-02、2026-09-27 全面审计等） |
| `docs/reports/` | **HISTORICAL 归档 ~220 份**（迁移/评审/修复过程快照；旧路径旧规则，勿当现状） |
