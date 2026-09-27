# FSRS 学习记录迁移 SQLite 方案（批次 E · 待评审）

> 状态：**E1 已实施（v2.7.56+97，2026-09-04）**。方案经用户批准三项拍板后落地。
> 前置安全网：FSRS-6 引擎 29 项官方公式测试已在位（v2.7.52+93）。
>
> 实施记录：
> - 新增 `lib/features/learning/data/review_schedule_store.dart`（三表 schema、UPSERT 单事务写路径、事务内行数校验的批量导入）
> - `review_schedule_repository.dart` 切换持久化层 + 首启迁移编排（`_migrateFromSpIfNeeded`：损坏行跳过并聚合上报、全成功才写 `fsrs6_migrated_v1` 标记、任何异常降级 SP 模式）
> - SP 空 + SQLite 空的机器直接写标记（避免每次启动空转）
> - 旧 SP key 未删除（只读回滚快照），E2 清理待观察 2~3 版 Sentry 无迁移错误后另批执行
> - 测试：`review_schedule_store_test.dart`（4 用例）+ `review_schedule_migration_test.dart`（6 用例，sqflite_common_ffi 内存库）

## 一、现状与问题

`lib/features/learning/data/review_schedule_repository.dart` 用 3 个 SharedPreferences key 存全部学习记录：

| SP key | 内容 | 写入方式 |
|---|---|---|
| `fsrs6_cards_v1` | 全部 FSRS 卡片（Map<单词, 卡片JSON>） | **每次评分全量 jsonEncode 重写** |
| `daily_stats_v1` | 每日学习/复习计数 | 每次评分全量重写 |
| `active_learn_dates_v1` | 有学习活动的日期集合 | 每次评分全量重写 |

**危害**：每次评分 = 3 次全量 JSON 序列化。词库几千词时每次评分重写数 MB 字符串（慢）；写入中途被杀进程 = 整个 blob 损坏（丢全部学习记录，且 SP 无事务）。

**有利条件**：写入口高度收敛——读只有 `_load()` 一处，写只有 `rateWord`/`forget` 两个方法；内存缓存结构可原样保留，只换持久化层，所有消费方（dueWordsFor/memoryStats/predictionFor 等）零改动。

## 二、表结构（新建独立库文件 `review_schedule.db`）

```sql
CREATE TABLE fsrs_cards (
  word TEXT PRIMARY KEY,
  stability REAL NOT NULL,
  difficulty REAL NOT NULL,
  elapsed_days INTEGER NOT NULL DEFAULT 0,
  scheduled_days INTEGER NOT NULL DEFAULT 0,
  last_review TEXT NOT NULL,            -- ISO8601
  due_date TEXT NOT NULL,
  repetitions INTEGER NOT NULL DEFAULT 0,
  review_count INTEGER NOT NULL DEFAULT 0,
  is_new INTEGER NOT NULL DEFAULT 1,
  short_term_stability REAL NOT NULL DEFAULT 0
);
CREATE INDEX idx_fsrs_cards_due ON fsrs_cards(is_new, due_date);

CREATE TABLE fsrs_daily_stats (
  date TEXT PRIMARY KEY,                -- yyyy-MM-dd
  learn INTEGER NOT NULL DEFAULT 0,
  review INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE fsrs_active_dates (
  date TEXT PRIMARY KEY
);
```

**为什么独立文件而不是挂进 user_database**：wordbook_database 有"检测坏库→删文件重建"逻辑（连带 -wal/-shm 删除）。学习记录绝不能被词库重建误伤，物理隔离最稳。

**为什么保留内存缓存**：dueCount/consecutiveDays/memoryStats 全是全内存计算，改动面最小；换掉的只是持久化读写。

## 三、写路径（性能收益核心）

| 操作 | 现在 | 迁移后 |
|---|---|---|
| 评分 `rateWord` | 3 次全量 jsonEncode（数 MB） | 单事务 3 条语句：`INSERT OR REPLACE` 卡片 1 行 + `INSERT ... ON CONFLICT` 今日统计 + `INSERT OR IGNORE` 活跃日期 —— O(1) |
| `forget` | 全量重写 | `DELETE` 1 行 |
| 加载 `_load` | 1 次全量 jsonDecode | 1 次全量 SELECT（仅启动时一次，量级可接受） |

## 四、首启迁移（核心风险控制）

打开 SQLite 后判断：`fsrs_cards` 表为空 **且** SP `fsrs6_cards_v1` 非空 → 执行迁移：

1. 读 SP blob，逐行解析（**损坏行跳过并上报 Sentry，不中断**）；
2. 单事务批量 INSERT，完成后校验 `COUNT(*)` 与解析成功行数一致；
3. 写迁移标记 `SP['fsrs6_migrated_v1'] = 'done'`；
4. **旧 SP key 本批不删除**，保留为只读回滚快照（清理另列 E2 小批，观察数个版本后执行）。

失败路径：迁移任何一步抛异常 → 不写标记、不删 SP → 本机继续走 SP 模式运行（零损失）+ Sentry 上报，下次启动重试。

## 五、双读过渡与回滚

- **读序**：迁移标记 = done → 读 SQLite；标记非 done 且 SQLite 空 → 读 SP（兼容迁移中途崩溃的机器）。
- **回滚**：若新版本出问题用户装回旧版，旧版读 SP —— 只丢"迁移后新产生的评分"，迁移前的全部历史完好（这就是不删 SP 的原因）。
- **已知取舍**（需你知情接受）：不做双写（双写仍是全量重写，等于没解决性能问题）。回滚窗口的增量丢失 = 装回旧版期间产生的新评分。

## 六、测试计划

| 测试 | 内容 |
|---|---|
| 迁移单测 | 构造 SP 数据（含损坏行/空串/超大 stability）→ 跑迁移 → 断言行数、字段映射、损坏行跳过且上报、标记写入 |
| 回退单测 | 无标记 + SQLite 空 → 走 SP；标记 done → 走 SQLite |
| 读写单测 | rateWord 后重开 DB 再 load，卡片/统计/日期一致；forget 后行删除（ffi in-memory，CI 先例：word_repository_impl_search_test） |
| 引擎网 | A 批 29 项公式测试不受影响（引擎零改动） |
| 既有测试 | review_schedule_repository_test 等 12 处消费方引用逐一适配 |

## 七、批次拆分与发版

- **E1**：SQLite 基础设施 + 迁移逻辑 + repository 切换 + 全部测试（若评审通过，拆 2 个 commit：基础设施/切换）→ 发版 v2.7.56+97
- **E2**（另行排期）：清理 SP 旧 key（观察 2~3 个版本无 Sentry 迁移错误后）

## 八、待你拍板

1. 方案整体是否批准（表结构 / 独立库文件 / 迁移策略 / 不做双写）？
2. 迁移失败时"本机继续用 SP 模式 + Sentry 上报"的降级是否接受？
3. E2 清理旧 key 的观察期（默认 2~3 个版本）是否认可？
