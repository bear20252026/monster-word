// 第四轮审计 M18（2026-11-18）：复习调度 SP 键常量单一事实来源。
//
// 此前 journal / migration / sp_codec 为取键常量反向 import 仓储类
// （ReviewScheduleRepository），形成「辅助件 → 仓储」倒挂依赖。键本质是
// 持久化契约、与仓储实现无关，抽到本文件后四者（仓储 + 三辅助件）同层
// 平行引用，倒挂消除。仓储仍保留同名静态别名转发，既有调用方不破。
//
// ⚠️ 键字符串是磁盘/SP 兼容契约，**只可搬家不可改值**：改值会让旧用户的
// 学习记录、迁移标记、应急备份、降级日志全部读不到。

/// FSRS 卡片快照（SP blob，降级模式与旧版回滚用）。
const String kFsrsCardsPrefKey = 'fsrs6_cards_v1';

/// 每日学习/复习词次统计。
const String kDailyStatsPrefKey = 'daily_stats_v1';

/// L1：每日答对词次（与 dailyStats 分开存，旧数据缺该键时按 0 计）。
const String kDailyCorrectPrefKey = 'daily_correct_v1';

/// 活跃学习日期集合（连续天数/日历用）。
const String kActiveDatesPrefKey = 'active_learn_dates_v1';

/// SP→SQLite 首启迁移完成标记（'done'）。
const String kFsrsMigratedMarkerKey = 'fsrs6_migrated_v1';

/// H2：E2 清 SP 前把快照挪到此应急备份 key（不清除），供库损坏时人工恢复。
const String kFsrsEmergencyBackupKey = 'fsrs6_emergency_backup_v1';

/// P1-01：SQLite 故障降级期间的评分意图日志（SP StringList，逐条 JSON）。
/// SQLite 恢复后按序幂等回放（fsrs_rating_log 主键去重），成功后清空。
const String kFsrsDegradedJournalKey = 'fsrs6_degraded_journal_v1';

/// 降级日志容量上限（与键同属日志持久化契约，故随键单源）。
///
/// 审计 R17（2026-11-16）：上限 5000→50000。DB marker=done 后恢复只靠回放，
/// 降级期评分超上限最旧被丢（极端场景永久丢失）。每条日志 ~150B，5 万条 // scale-ok: SP 日志容量预算估算，非词库规模断言
/// ≈7.5MB SP 体积——降级本身是罕见故障态，用一次性体积换评分不丢；
/// 超限仍丢最旧并上报（可观测取舍不变）。
const int kFsrsDegradedJournalCap = 50000;
