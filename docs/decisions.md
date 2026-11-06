# 决策记录

> 本文件只记录「已经拍板、会影响实现或排期」的决策，按确认日期追加，不重写历史。
> 背景对比与备选方案不在此展开，见对应依据文档；本文只写结论与推翻成本。

## 2026-11-06 · B2/B4 决策备忘确认

依据：`decision-memo.md`（2026-11-06 工作区交付件，未纳入仓库）第 1–3 节；
相关代码：`lib/features/learning/presentation/learning_session_state.dart`、`lib/features/learning/presentation/review_session_state.dart`、`lib/features/learning/application/streak_milestones.dart`、`lib/features/learning/application/home_path.dart`、`lib/app/app.dart`。

| 决策 | 日期 | 理由 | 影响范围 | 若推翻需要做什么 |
|---|---|---|---|---|
| **云同步本版不立项，只保留设计稿**；未来若启动，按 A 档起步（学习进度 + 资产 + 计数，不含 FSRS 卡片与复习日志） | 2026-11-06 | 离线优先是产品定位；FSRS 日志冲突成本远高于收益，且会拖慢发版 | 本版无代码改动；`new_words` 软删清理继续挂起（不写清理逻辑） | 需先补服务端事件账本、设备 ID、回滚方案与隐私披露，再排期（估算 10–12 人日）；范围升级到 B 档需额外协议设计 |
| **「一次会话完成」以「队列走完」为主口径**；目标达成与有效学习降为属性字段；KPI 走 telemetry 日聚合，Sentry 只做链路上下文 | 2026-11-06 | 现有唯一守卫已按此实现且只上报一次，口径统一成本最低；避免 Sentry 采样污染 KPI | `LearningSessionState`（`wasLastWord`）、`ReviewSessionState._reportSessionCompletedIfDone`、`UsageStatsRecorder.recordStudySession` | 改口径需同时改两处守卫与 `usage_stats_daily` 聚合字段；若新增「放弃会话」KPI，需补历史数据口径说明 |
| **B3 连胜里程碑只庆祝、不发币**；备查数值 7→+20、14→+50、30→+120、50→+300 仅记档不实现 | 2026-11-06 | 奖励值属产品口径，先防通胀；里程碑本身已提供正向反馈 | `lib/features/checkin/application/streak_milestones.dart`、`treasure_checkin_page.dart`（按只庆祝实现，无发放入口） | 发币需接入 `ScareCoinStore` 发放入口与幂等键（`milestone_guard` 已落档位）、每日上限与回滚；备查数值可直接采用 |
| **B5 今日路线 `HOME_PATH` 默认关闭**，保持关闭一个版本；真机走查后再评估是否默认开 | 2026-11-06 | 信息架构改动大，关闭时首页与旧版逐像素一致，风险可控 | `lib/features/learning/application/home_path.dart`（`kPathHome`）、`home_screen.dart` 的 `if (kPathHome)` 分支 | 默认开前需真机走查（小屏/横屏/深色）与一版灰度观察；改默认值一行，但需补验收记录 |
| **B4 首启三步对话仅首次使用（无 `last_visit`）弹出**，判定条件不变 | 2026-11-06 | 老用户升级不打扰；跳过与完成都落标，只出现一次 | `lib/app/app.dart` 的首次使用分支、`onboarding_promise_done_v1`、`onboarding_promise_dialog.dart` | 若要让老用户也看一次：改为只按标记缺失判定，并说明「升级用户补看一次」的产品意图与回滚方式（删标记即可重看） |

### 仍待拍板

第 3、4、5、7、8、10、13 条（同步冲突策略/触发方式、`new_words` 清理时点、复习页是否计入会话、「未完成会话」上报、结算称号阈值、每日目标口径）仍按备忘中的推荐值待定，确认后再追加到本文件。
