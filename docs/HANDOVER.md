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
  architecture/   27 套守卫测试（105 例）——本项目最有价值的资产，见 §5
  features/ core/ regression/ unit/ data/   回归台账 REG-ID 对应的守护测试
scripts/          词库构建/数据修补（Python；archive/ 为一次性历史脚本）
assets/db/        wordbook.db.gz（只读词库，CI 有基线校验）
```

规模：lib 504 文件 / 6.5 万行；test 281 文件 / 2.8 万行。features 16 域。

## 3. 关键机制（改代码前必读）

1. **词库库是只读资产**：`wordbook.db.gz` 随包分发，首启/升级解压（内存解压 + 临时文件原子替换），版本指纹命中即跳过。任何"给词库建索引/建 FTS"的想法都意味着重建资产发版。搜索已改 bigram 倒排索引单栈（`cn_search_index.dart`，P1-6 收口），FTS5 方案已废弃。
2. **用户库写兼容**：Android ≤9 系统 SQLite 为 3.22，**禁用 `INSERT…ON CONFLICT…DO UPDATE`**，累加写用 UPDATE+条件 INSERT（`review_schedule_store._upsertDailyStats`）。
3. **数据完整性口径**：持久化失败必须 `reportSwallowedError`（A/B/C 分级见 `lib/core/utils/swallowed_error_report.dart` 头注释，守卫测试锁定 A 级文件）；账本/存档类"解析失败保留原档，宁丢一条新账不清历史"；收藏 DAO 写路径有串行闸门 + 失败回滚内存索引。
4. **释义解析单一真相**：interpret JSON → 文本只存在于 `lib/models/definition_text.dart`；四选一干扰项只在 `lib/core/engine/distractor_generator.dart`。新增消费方禁止复制逻辑。
5. **SP key 单源**：`user_token`/`user_secret`/`monster_word_user_info` 仅定义于 `app_preferences.dart`；presentation 经 `PresentationPrefs` 端口读写偏好，**不得** import infrastructure（R-prefs 守卫会拦）。
6. **WebView**：`core/web/base_web_page.dart` https-only + 域名白名单（当前为空=全拒）；JS 禁用。
7. **密码**：PBKDF2-HMAC-SHA256 **60 万轮**（审计 R24 升 OWASP 建议；存格式 `pbkdf2-sha256$<n>$<hex>` 自带轮数）；存量单轮哈希与低轮数哈希均在登录验证成功时透明升级，全程后台 isolate 不阻塞 UI。测试含 RFC 参考向量。
8. **音频缓存**：系统缓存目录（非 Documents）；`audio_players.dart` 主备 URL 逻辑区分绝对/相对地址。

## 4. 质量门禁（每次提交前必跑）

```bash
dart format --line-length 120 --set-exit-if-changed --output=none .  # 必须 0 changed（CI 同款）
flutter analyze                                                    # 必须 No issues found（CI 裸 analyze，info 级等同失败）
flutter test test/architecture/                                    # 105 例守卫必须全过
flutter test                                                       # 全量 1675 例必须全过
```

> P2-16（架构审计 2026-11-12）：本地口径已与 CI `dart.yml` 对齐——`analyze` 不再带
> `--no-fatal-infos`（CI 是裸 `flutter analyze`，info 级提示等同失败）；format 用
> `--set-exit-if-changed` 硬门禁。`scripts/auto_sync.sh` 的格式化是便利步骤（本机
> dartdev 可能挂起，失败不阻断提交），**真正的格式门禁在 CI**，勿以本地脚本跳过为准。

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

1. ~~Spug 短信模板码轮换~~ **已整体关闭**（2026-10-13）：登录改为「用户名 + 密码」本机校验，短信登录与短信找回密码一并删除，`spug_sms_code_service.dart` 及其端口、测试、隐私政策披露、网络诊断域名全部移除 —— 仓库与安装包里不再有任何短信调用凭证（R2-01 关闭，依据 Spug 官方文档「验证码发送必须由业务服务端发起，不要把编码放入移动端安装包」）。
   **下一步（需服务端）**：把本机账号升级为服务端账号（自建 Supabase，用户名 + 密码），届时密码由服务端校验、忘记密码由管理员在后台重置。
   **进展（2026-10-14，阶段二）**：客户端侧已完成——`SupabaseAccountAuthenticator`（对接 GoTrue，错误码映射逐条对着上游源码核对）、`MigratingAccountAuthenticator`（存量用户无感迁移）、会话持久化、装配点按 `--dart-define=AUTH_BASE_URL` 切换（不注入即维持本机模式，CI 不受影响）。
   **服务端也已部署并验收**：GoTrue `v2.197.0` 跑在业主自己的阿里云 ECS（`101.133.235.110`，Ubuntu 24.04 / 2 vCPU / 1.6 GiB，**无 Docker** ⇒ 走原生部署而非容器），PostgreSQL 16 库 `mwauth`，复用既有 Caddy + Cloudflare 隧道做入口。`smoke-test.mjs` 对真实 GoTrue **10/10 通过**。
   **服务端与客户端两侧都已就绪（2026-10-14）**：`auth.cloudbear.cloud` 已接通（Cloudflare 隧道 → Caddy → GoTrue），走公网验收 **10/10 通过**；`release_packages.yml` 的三处构建已注入 `AUTH_BASE_URL`，**下次发版即全员切到服务端认证**。
   **回退方式**：删掉那两行 `--dart-define`（`AUTH_BASE_URL` / `AUTH_ANON_KEY`）重发一版即可，不需要改代码。
   **切换后须知**：已登录用户不受影响（登录态在本机）；存量用户不会升级即迁移，而是在下次**显式登录**时才迁移到服务端（判据见 `docs/auth_server_contract.md` §6）。已用 `workflow_dispatch` 手动跑通整条发版链路，并下载产物确认编译期常量真的进了二进制（三个 ABI 的 `libapp.so` 里各 1 处 `https://auth.cloudbear.cloud`）。
   部署与运维手册：`deploy/README.md`、`deploy/native/README.md`；契约：`docs/auth_server_contract.md`。
2. **使用统计（遥测）—— 已全链路打通（2026-10-15）**：客户端采集/上报、服务端接收/汇总/管理页
   （含「按人看」）、发版流水线注入 `STATS_BASE_URL`、Cloudflare 公网入口，全部完成并走过公网验收。
   入口：`https://stats.cloudbear.cloud`（`/healthz` 探活、`/v1/report` 上报、`/` 管理页 Basic Auth）。
   客户端统计开关**默认关闭**（`USAGE_STATS_DEFAULT` 缺省 `off`），要收集需用户在设置里主动开启。
   验收记录与响应码约定见 `deploy/telemetry/README.md` §4/§7；
   埋点落点表与口径见 `lib/features/telemetry/README.md` §6。
3. **release keystore 迁出项目目录**：`android/app/*.jks` + `key.properties` 仍在工程内（违反自家 release_pipeline §1.3），建议移至工程外密钥目录 + 高强度密码入管理器 + 仅 CI secrets 签名。
4. **GitHub 仓库设置**：分支保护**已开启**（main 禁直推、PR 必审，required check = analyze-and-test）。注意 `enforce_admins=false`——管理员仍可绕过直推（2026-11-12 审计 P1-5 指出）；推送一律走 PR。携带签名 secrets 的 job 仅 tag 触发。

**排期中的工程项（`monster-word-全面审计报告-2026-09-27.md` 提升点清单 I1–I105，余 ~66 项）**：

- **与下次词库发版合并**：~~FTS5 搜索索引~~ 已废弃——搜索改 bigram 倒排索引单栈（P1-6，2026-11-12 收口），基准测试见 `test/benchmark/search_benchmark_test.dart`。词库 `ORDER BY word COLLATE NOCASE` 仍缺对应索引（P3-5），加索引须重建随包资产发版。
- **独立 PR**：MwNavBar 组件化（28 处复制 ~420 行）、统一反馈出口（showMwConfirm 重建 + 56 处迁移）、金币账本 SQLite 化（接口契约变更波及 11 个测试假实现）。
- **需真机/profiler**：动画粒度优化 6 项（拖拽 setState、常驻 ticker 等，先 DevTools 基线后改）。
- **观察项**：new_words 软删行清理（待云同步设计定型）；旧 Android 评分落盘真机验证。
- 已核查关闭（勿重做）：词库索引健康（EXPLAIN 实测）、句库分页（残留全量是学习场景有意设计）、测试装配"去重"（差异即被测行为）。

**2026-11-15 全面审计（35 项）修复批次**（报告：`monster-word-全面代码审计报告-2026-11-15.md`）：

- 批次1（P1×5，PR #223）：回放×迁移双应用、熟词竞态、LLM 失败回退、根路由黑屏、token 进 Sentry 脱敏。
- 批次2（PR #224）：任务/XP 非粘性降级、奖励收尾防覆盖（reload 重读）。
- 批次3（PR #225）：IN 分批、词书计数去重、dispose 守卫、记忆消毒、queue 只读、导航 forward 栈、宠物开关闸、词卡 Selector、溢出弹性、音频 https、LLM https 校验。
- 批次4（PR #226）：cn 索引句柄泄漏、http.Client close、下滑重入闸、FutureBuilder 缓存、触控 48dp、副标题弹性。
- 批次5（PR #227，2026-11-16「继续修复剩余项」）：
  - A8 账本回灌水位改「>= + (ms,delta,reason) 去重」防同毫秒丢流水；备份 wal_checkpoint 检查 busy 重试三次、仍 busy 抛错防滞后快照。
  - B8 装配 sync 移 post-frame（sync 幂等），杜绝 build 期 notifyListeners。
  - C6 宠物可见性事件：原生 SetVisibilityCallback → InvokeMethod('petVisibilityChanged') → Dart 流 → 设置页订阅；含宠物自关（OnDestroy）路径；契约守卫新增事件名断言。**真机 Windows 需人工复核开关对齐**。
  - C7 六个死路由注册删除（页面文件保留待产品决策），常量保留埋点历史口径，旧名落错误页。
  - D6 发版流水线 DSN 缺失发 GitHub warning 注解（Android+Windows），不熔断；配置 secret 后自动消失。
  - D7 archive ^3.6.1 → ^4.0.7（实际 4.7.1）：唯一 API 面 GZip 编解码兼容，两处测试去多余 `!`。
  - D5 新增 integration_windows.yml（workflow_dispatch 手动触发，Windows runner 真桌面跑 perf_profile；确认稳定后可升定期）。
- **仍留 owner 的项**：SENTRY_DSN secret 配置（D6 警告消除前提）；Windows 签名证书（#36）；C6 真机复核；integration workflow 首跑确认；死路由页面文件是否删除的产品决策。

**2026-11-16 第二轮审计（24 项）+ 架构亚健康评估 → 结构修复步骤批次**：

- 步骤1（PR #228，P1 前置）：R1 迁移预登记条件化（防评分丢失）、R2 宠物窗口 WM_DESTROY 先快照 quit_on_close 再 Destroy（防 UAF）、R3 Sentry 双层脱敏（reportSwallowedError 收口 + beforeSend 改写 FormatException.value）。
- 步骤2（PR #229，问题2+R4/R5/R6）：奖励队列读-改-写互斥锁、唯一条目 id（同毫秒并发登记不误滤）、grantOnce 幂等结算 + _PartialRewardFailure 部分成功计入。
- 步骤3a（PR #230，问题1）：选择题扩池编排下沉 application/extra_choice_pool.dart（两 Session 同构逻辑合一）。
- 步骤3b（PR #232，问题1）：断点恢复决策下沉 application/learning_resume_planner.dart（sealed 纯函数：None/AtIndex/Rebuild，MW-27+R2-06 全分支表驱动单测）。
- 步骤4（PR #231，问题3b）：ScareCoinStore 拆 4 窄端口（CoinLedger/CheckInCalendar/ProtectionCard/AnswerReward），聚合门面保留（24 消费方+11 fake 零改动）；单实例 Provider.value 五类型暴露（同作用域，共享串行门/降级旗/水位不变）；checkin 三适配器与 missions/learning 发币收窄。
- 步骤5（PR #233，问题3a+M4）：app.dart 15 层手工嵌套 → 有序 scope 闭包列表 + reversed.fold（REG-ARCH-003 文本序守卫零改动）；_HomeShell 三仪式（奖励补发/回家礼/首启引导）下沉 features/home/application/home_startup_coordinator.dart（窄端口+可注入时钟，演出回调留壳层）。
- 排查沉淀：待结算队列存储为**双层编码**（外层 JSON 数组的元素是条目 JSON 字符串），契约测试 reward_queue_format_test.dart 锁定；误写对象数组按空队列处理不崩溃。
- 批次6（PR #234，LLM 安全族）：R7 显式 Request 禁跟随重定向（堵 Bearer 经 302→http 外泄）；R9 空/pending key 拒发正文+解析器读入前如实规则版（upgradePrimary 无缝升级）；R13 LlmClient.close 端口化+聊天/陪伴 dispose 接线；R15 消毒正则词边界/修饰词可重复/「你现在是(?!不)」/零宽替换空格/recordPersona 同口径。
- 批次7（PR #235，UI 状态族）：R8 goHome/错误页回根经 runIgnoringPops（popUntil 只发 didPop，SDK 核验）；R10 colors 走 effectiveThemeId；R11 搜索星标 watch 订阅；R19 装配创建期 silent 预载 due；R20 宠物开关在途忽略事件+isVisible 复核；R21 单词机滚动视图；R22 速刷首屏+切换共用加载序号守卫+加载态保留类型条。
- 批次8（PR #236，词源与安卓）：R12 matchExamBooks 领域纯函数按考试词书取词（PETS4 排除），无匹配回退全库随机+UI 诚实提示；目录端口经组合根注册（R4）；R14 proguard 补 flutter_local_notifications/Gson keep。
- 批次9（PR #237，P3 加固）：R16 索引失效关闭 Future 化+重建前 await；R17 降级日志上限 5000→50000；R18 回灌签名去重改多重集计数（同毫秒真流水不吞、重复回灌幂等）；R23 宠物 moveBy 虚拟屏钳制；R24 PBKDF2 60 万轮+存量透明升级、Inno 锁版 6.4.3、signtool 密码 /pfile、vc_redist 发布者精确匹配、Charter w700 正体映射 BoldItalic（取得正体粗体资产后替换，owner 项）。
- **第二轮审计 24 项至此全部处置完毕**；结构路线图 ①②③④ 全部落地。仍留 owner：R14 真机 release 排程通知复核、R23 真机多屏拖动复核、Charter-Bold 正体资产、签名证书/SENTRY_DSN（见上）。

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

---

## 附录：本地数据损坏恢复手册（审计 I86）

用户数据三层存储的损坏症状与恢复口径（各写入路径已内置"宁丢新账不清历史"保护，本手册针对极端现场的人工介入）：

### SP 快照类（SharedPreferences / %APPDATA% 明文 JSON）

| key | 内容 | 损坏表现 | 恢复 |
|---|---|---|---|
| `scare_coin.history` | 金币账本（≤200 条） | 余额正常但流水为空/不变 | 损坏路径已保护：不覆写、新条目跳账。人工恢复无入口——接受流水缺失，余额为准 |
| `fav_sentence_list` | 收藏例句 SP 快照 | 迁移中止日志（Sentry 有记录） | **原档保留未动**，可手工修 JSON 后卸载重装触发再迁移 |
| `mw.feedback.archive` | 反馈存档（≤50 条） | 提交后存档不变 | 已保护：不覆写，新反馈走 Sentry 兜底 |
| `mastered_words_v1` | 已掌握词表 | 掌握标记丢失 | 无快照备份；toggleMastered 已改等待加载完成，覆盖风险已消除 |
| `favorite_words_v1` | 单词收藏 SP 快照 | —（已迁 SQLite，仅回滚快照） | SQLite 为事实来源，SP 只读 |

### SQLite 类（user_data.db）

- 打开失败 → 自动删坏库重建一次（收藏由 SP 快照重新迁移；FSRS 卡片与统计**不可恢复**——重建前无导出）。
- 收藏迁移崩溃现场 → 下次启动自愈（REG-AUDIT-001），无需人工。
- 手工检查：`scripts/inspect_db.py`。

### 原则

1. 任何"损坏 → 清空重建"路径必须先上报（`reportSwallowedError`）再动作；
2. 修复写路径时保持"解析失败保留原档"口径（REG-AUDIT-003 有损坏注入回归守护）；
3. 新增持久化 key 时在本表登记。
