-- Monster Word 使用统计库（mw_telemetry）
--
-- ⚠️ 与账号库 mwauth **分开**：两者生命周期完全不同（账号是身份数据，要长期保留、
--    要能精确恢复；统计是可丢弃的观测数据，有保留期）。混在一个库里，将来做备份
--    策略、权限收紧、甚至迁到别的机器时都会互相牵制。
--
-- 设计要点：
--   1. 主键 (device_id, day)：同一天重复上报（客户端补传、重试）天然幂等，
--      不会因为重试产生重复行。这是「客户端失败就保留数据下轮补传」能成立的前提。
--   2. **没有 user_id 列**。设备标识是本地随机生成的，不与账号关联 —— 这是本功能
--      的隐私前提（见客户端 lib/features/telemetry/README.md）。日后若要按人看，
--      必须先改隐私披露，再加列。
--   3. 所有计数列都有 DEFAULT 0 且 NOT NULL：客户端旧版本可能少传字段，
--      缺列不该让整批上报失败。
--   4. 数值列都给了 CHECK 上限：客户端有 clamped()，但**服务端不能信任客户端**，
--      写入前必须自己再夹一次（否则一条脏数据会让所有聚合报表变形）。
--
-- 幂等：本文件可重复执行。

CREATE TABLE IF NOT EXISTS usage_daily (
  device_id           TEXT        NOT NULL,
  day                 DATE        NOT NULL,

  -- 使用情况
  foreground_ms       BIGINT      NOT NULL DEFAULT 0 CHECK (foreground_ms >= 0 AND foreground_ms <= 86400000),
  session_count       INTEGER     NOT NULL DEFAULT 0 CHECK (session_count >= 0 AND session_count <= 100000),
  study_session_count INTEGER     NOT NULL DEFAULT 0 CHECK (study_session_count >= 0 AND study_session_count <= 100000),

  -- 学习行为（聚合量，不含任何学习内容）
  words_reviewed      INTEGER     NOT NULL DEFAULT 0 CHECK (words_reviewed >= 0 AND words_reviewed <= 1000000),
  words_correct       INTEGER     NOT NULL DEFAULT 0 CHECK (words_correct >= 0 AND words_correct <= 1000000),
  new_words_learned   INTEGER     NOT NULL DEFAULT 0 CHECK (new_words_learned >= 0 AND new_words_learned <= 1000000),
  book_word_count     INTEGER     NOT NULL DEFAULT 0 CHECK (book_word_count >= 0 AND book_word_count <= 1000000),
  book_learned_count  INTEGER     NOT NULL DEFAULT 0 CHECK (book_learned_count >= 0 AND book_learned_count <= 1000000),
  streak_days         INTEGER     NOT NULL DEFAULT 0 CHECK (streak_days >= 0 AND streak_days <= 100000),
  coins_earned        INTEGER     NOT NULL DEFAULT 0 CHECK (coins_earned >= 0 AND coins_earned <= 10000000),

  -- 各模块打开次数。用 JSONB 而不是拆列：模块集合会随功能演进变化。
  -- 客户端有白名单（UsageDailyStats.knownModules），服务端再做一次键数上限校验。
  module_open_counts  JSONB       NOT NULL DEFAULT '{}'::jsonb,

  -- 上报那一刻的环境（信封字段）
  app_version         TEXT        NOT NULL DEFAULT '',
  app_build           INTEGER     NOT NULL DEFAULT 0,
  platform            TEXT        NOT NULL DEFAULT '',
  os_version          TEXT        NOT NULL DEFAULT '',
  locale              TEXT        NOT NULL DEFAULT '',
  schema_version      INTEGER     NOT NULL DEFAULT 1,

  received_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

  PRIMARY KEY (device_id, day)
);

-- 按天出报表（日活、总时长）是最常用的查询。
CREATE INDEX IF NOT EXISTS idx_usage_daily_day ON usage_daily (day);

-- 设备台账：日活去重、看留存都靠它，不必每次去重扫 usage_daily。
CREATE TABLE IF NOT EXISTS devices (
  device_id   TEXT        PRIMARY KEY,
  first_seen  TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen   TIMESTAMPTZ NOT NULL DEFAULT now(),
  platform    TEXT        NOT NULL DEFAULT '',
  app_version TEXT        NOT NULL DEFAULT ''
);

CREATE INDEX IF NOT EXISTS idx_devices_last_seen ON devices (last_seen);

-- 每日汇总视图：管理页直接用，省得每次写一遍聚合 SQL。
-- 正确率在没有任何答题时显示 NULL 而不是 0（0% 与「没答过」是两件事）。
--
-- 注意 sum(bigint) 在 PostgreSQL 里返回 **numeric**，所以 `sum(x)/1000/60` 会得到
-- 1440.0000000000000000 这种一长串零。这里统一用 round(..., 1) 收口。
CREATE OR REPLACE VIEW usage_daily_summary AS
SELECT
  day,
  count(DISTINCT device_id)                                            AS active_devices,
  round(sum(foreground_ms) / 60000.0, 1)                               AS total_minutes,
  round(avg(foreground_ms) / 60000.0, 1)                               AS avg_minutes_per_device,
  sum(session_count)                                                   AS total_sessions,
  sum(study_session_count)                                             AS total_study_sessions,
  sum(words_reviewed)                                                  AS total_words_reviewed,
  sum(new_words_learned)                                               AS total_new_words,
  CASE WHEN sum(words_reviewed) > 0
       THEN round(100.0 * sum(words_correct) / sum(words_reviewed), 1)
       ELSE NULL END                                                   AS accuracy_pct
FROM usage_daily
GROUP BY day
ORDER BY day DESC;

-- 保留期清理用。客户端保留 180 天明细，服务端同日粒度保留 400 天，
-- 之后由运维按需聚合归档再删（清理脚本见 README）。
COMMENT ON TABLE usage_daily IS 'Monster Word 按设备按天的使用统计。不含任何学习内容，不含账号身份。';
