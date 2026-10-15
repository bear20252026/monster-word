-- 使用统计的入库函数。
--
-- 为什么把校验与写入放进数据库函数，而不是写在 Node 里：
--   1. **原子**：一批 31 天要么全进要么全不进，不会因为中途异常留下半批；
--   2. **零依赖**：Node 侧不需要 pg 驱动（这台机器上少一棵 npm 依赖树，
--      就少一份长期维护面），只需要 psql 把 JSON 递进来；
--   3. 校验只有一处，不会出现「Node 校验了、SQL 没校验」的缝。
--
-- ⚠️ 服务端**不信任客户端**：客户端有 clamped()，这里必须自己再夹一次。
--    一条脏数据足以让所有聚合报表变形，而排查成本远高于在这里多写几行。
--
-- 幂等：本文件可重复执行。

-- 把任意输入夹到 [lo, hi]。非数字 → 0（而不是报错：旧客户端少传字段不该让整批失败）。
CREATE OR REPLACE FUNCTION mw_clampi(v jsonb, lo INTEGER, hi INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE n BIGINT;
BEGIN
  IF v IS NULL OR jsonb_typeof(v) = 'null' THEN RETURN GREATEST(lo, 0); END IF;
  BEGIN
    n := (v #>> '{}')::bigint;
  EXCEPTION WHEN others THEN
    RETURN GREATEST(lo, 0);
  END;
  IF n < lo THEN RETURN lo; END IF;
  IF n > hi THEN RETURN hi; END IF;
  RETURN n::integer;
END;
$$;

-- 取字符串并截断。用于 platform / os_version 这类自由文本。
CREATE OR REPLACE FUNCTION mw_clamps(v jsonb, max_len INTEGER)
RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE t TEXT;
BEGIN
  IF v IS NULL OR jsonb_typeof(v) <> 'string' THEN RETURN ''; END IF;
  t := v #>> '{}';
  IF length(t) > max_len THEN t := left(t, max_len); END IF;
  RETURN t;
END;
$$;

-- 只保留白名单里的模块键，并给值夹上限。
-- 白名单与客户端 UsageDailyStats.knownModules 保持一致 —— 两边都要有：
-- 客户端丢是为了不把内容泄露出去，服务端丢是为了不信任客户端。
CREATE OR REPLACE FUNCTION mw_sanitize_modules(v jsonb)
RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE out jsonb := '{}'::jsonb; k TEXT; cnt INTEGER := 0;
BEGIN
  IF v IS NULL OR jsonb_typeof(v) <> 'object' THEN RETURN '{}'::jsonb; END IF;
  FOR k IN SELECT jsonb_object_keys(v) LOOP
    EXIT WHEN cnt >= 20;
    IF k = ANY (ARRAY['learn','review','listen','dict','whiteboard','book','content','community','profile']) THEN
      out := out || jsonb_build_object(k, mw_clampi(v -> k, 0, 1000000));
      cnt := cnt + 1;
    END IF;
  END LOOP;
  RETURN out;
END;
$$;

-- 逐键取较大值地合并两天的模块打开次数。
--
-- 为什么需要它（2026-10-15 验收时实测发现）：
-- `module_open_counts` 是**按天累加量**（当天各模块被打开几次），与
-- `foreground_ms` / `words_reviewed` 同类，因此合并策略必须同样是「取较大值」。
-- 早期实现直接 `EXCLUDED.module_open_counts` 覆盖，实测：
--   先送 {"learn":4,"review":2}，再送 {"learn":1}
--   → 库里变成 {"learn":1}，`review` 整个键丢了、`learn` 还被改小。
-- 触发场景与其它累加量一致：客户端重装/本地计数归零后的一次补传。
--
-- 逐键而不是整对象比较：两次上报带的键集合可能不同（例如第二次那天没打开过词典），
-- 整对象比较会整块丢掉第一次的键。
CREATE OR REPLACE FUNCTION mw_merge_modules(a jsonb, b jsonb)
RETURNS jsonb
LANGUAGE sql IMMUTABLE
AS $$
  SELECT COALESCE(jsonb_object_agg(k, GREATEST(av, bv)), '{}'::jsonb)
  FROM (
    SELECT k,
           COALESCE((COALESCE(a, '{}'::jsonb) -> k)::text::int, 0) AS av,
           COALESCE((COALESCE(b, '{}'::jsonb) -> k)::text::int, 0) AS bv
    FROM jsonb_object_keys(COALESCE(a, '{}'::jsonb) || COALESCE(b, '{}'::jsonb)) AS keys(k)
  ) t;
$$;

-- 主入口。payload 形如客户端 UsageStatsReport.toJson()。
-- 返回 {"ok":true,"accepted":N,"rejected":M}
CREATE OR REPLACE FUNCTION mw_ingest(payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_device_id TEXT;
  v_day       jsonb;
  v_day_str   TEXT;
  v_days      INTEGER;
  v_accepted  INTEGER := 0;
  v_rejected  INTEGER := 0;
  v_platform  TEXT;
  v_app_ver   TEXT;
  v_schema    INTEGER;
  v_user_id   TEXT;
BEGIN
  -- 校验失败一律带 `mw_invalid_input:` 前缀，服务端据此回 **400** 而不是 500。
  -- 为什么区分：这类错误是**客户端把请求发错了**，与服务端健康无关；
  -- 混进 500 会让「服务故障」的告警与 Sentry 被脏请求刷满（2026-10-15 验收时实测
  -- 缺 device_id 返回 500 server_error，就是这里没有标记导致的）。
  -- 前缀是服务端与数据库之间的约定，改动时两边要一起改（server.mjs 的 VALIDATION_MARKER）。
  IF payload IS NULL OR jsonb_typeof(payload) <> 'object' THEN
    RAISE EXCEPTION 'mw_invalid_input: payload 必须是对象';
  END IF;

  v_device_id := mw_clamps(payload -> 'device_id', 64);
  IF v_device_id = '' THEN
    RAISE EXCEPTION 'mw_invalid_input: device_id 缺失';
  END IF;

  IF jsonb_typeof(payload -> 'days') <> 'array' THEN
    RAISE EXCEPTION 'mw_invalid_input: days 必须是数组';
  END IF;
  v_days := jsonb_array_length(payload -> 'days');
  IF v_days > 31 THEN
    RAISE EXCEPTION 'mw_invalid_input: days 超过 31 条上限（客户端应分批）';
  END IF;

  -- 账号标识。空串 = 没有可关联的账号（本机模式/未登录），不是错误。
  -- 只收 UUID 不用户名：用户名由管理页向账号服务解析，避免两处漂移。
  v_user_id  := mw_clamps(payload -> 'user_id', 64);
  v_platform := mw_clamps(payload -> 'platform', 32);
  v_app_ver  := mw_clamps(payload -> 'app_version', 32);
  v_schema   := mw_clampi(payload -> 'schema_version', 0, 1000);

  FOR v_day IN SELECT * FROM jsonb_array_elements(payload -> 'days')
  LOOP
    v_day_str := mw_clamps(v_day -> 'day', 10);

    -- 日期必须真的是 YYYY-MM-DD 且能解析。坏日期直接跳过这一条而不是整批失败：
    -- 一批里混进一条坏数据时，丢掉其余正常的日子代价更大。
    IF v_day_str !~ '^\d{4}-\d{2}-\d{2}$' THEN
      v_rejected := v_rejected + 1;
      CONTINUE;
    END IF;
    BEGIN
      PERFORM v_day_str::date;
    EXCEPTION WHEN others THEN
      v_rejected := v_rejected + 1;
      CONTINUE;
    END;

    INSERT INTO usage_daily (
      device_id, user_id, day,
      foreground_ms, session_count, study_session_count,
      words_reviewed, words_correct, new_words_learned,
      book_word_count, book_learned_count, streak_days, coins_earned,
      module_open_counts,
      app_version, app_build, platform, os_version, locale, schema_version
    ) VALUES (
      v_device_id, v_user_id, v_day_str::date,
      mw_clampi(v_day -> 'foreground_ms', 0, 86400000),
      mw_clampi(v_day -> 'session_count', 0, 100000),
      mw_clampi(v_day -> 'study_session_count', 0, 100000),
      mw_clampi(v_day -> 'words_reviewed', 0, 1000000),
      -- 答对数不得超过复习词次，否则正确率会 >100%
      LEAST(mw_clampi(v_day -> 'words_correct', 0, 1000000), mw_clampi(v_day -> 'words_reviewed', 0, 1000000)),
      mw_clampi(v_day -> 'new_words_learned', 0, 1000000),
      mw_clampi(v_day -> 'book_word_count', 0, 1000000),
      mw_clampi(v_day -> 'book_learned_count', 0, 1000000),
      mw_clampi(v_day -> 'streak_days', 0, 100000),
      mw_clampi(v_day -> 'coins_earned', 0, 10000000),
      mw_sanitize_modules(v_day -> 'module_open_counts'),
      v_app_ver,
      mw_clampi(payload -> 'app_build', 0, 1000000),
      v_platform,
      mw_clamps(payload -> 'os_version', 120),
      mw_clamps(payload -> 'locale', 20),
      v_schema
    )
    -- 补传/重试会重复送同一天 ⇒ 必须幂等。用「取较大值」而不是「覆盖」：
    -- 同一天两次上报里，数值更全的那次通常是后到的完整数据；但若客户端重装了、
    -- 计数从 0 重新开始，覆盖会把当天已有的时长抹掉。取较大值对两种情形都安全。
    -- 例外：book_word_count / book_learned_count 是**状态量**（当前词书规模与已学数），
    -- 不是累加量，所以用覆盖；module_open_counts 虽是对象但属累加量，逐键取较大值。
    ON CONFLICT (device_id, day) DO UPDATE SET
      -- 只在本次带上了账号时覆盖：先未登录后登录要能补上，
      -- 而「先有账号、后来又变空」不该把已有关联抹掉。
      user_id             = CASE WHEN EXCLUDED.user_id <> '' THEN EXCLUDED.user_id ELSE usage_daily.user_id END,
      foreground_ms       = GREATEST(usage_daily.foreground_ms, EXCLUDED.foreground_ms),
      session_count       = GREATEST(usage_daily.session_count, EXCLUDED.session_count),
      study_session_count = GREATEST(usage_daily.study_session_count, EXCLUDED.study_session_count),
      words_reviewed      = GREATEST(usage_daily.words_reviewed, EXCLUDED.words_reviewed),
      words_correct       = GREATEST(usage_daily.words_correct, EXCLUDED.words_correct),
      new_words_learned   = GREATEST(usage_daily.new_words_learned, EXCLUDED.new_words_learned),
      book_word_count     = EXCLUDED.book_word_count,
      book_learned_count  = EXCLUDED.book_learned_count,
      streak_days         = GREATEST(usage_daily.streak_days, EXCLUDED.streak_days),
      coins_earned        = GREATEST(usage_daily.coins_earned, EXCLUDED.coins_earned),
      module_open_counts  = mw_merge_modules(usage_daily.module_open_counts, EXCLUDED.module_open_counts),
      app_version         = EXCLUDED.app_version,
      app_build           = EXCLUDED.app_build,
      platform            = EXCLUDED.platform,
      os_version          = EXCLUDED.os_version,
      locale              = EXCLUDED.locale,
      schema_version      = EXCLUDED.schema_version,
      received_at         = now();

    v_accepted := v_accepted + 1;
  END LOOP;

  INSERT INTO devices (device_id, platform, app_version, last_seen)
  VALUES (v_device_id, v_platform, v_app_ver, now())
  ON CONFLICT (device_id) DO UPDATE SET
    last_seen   = now(),
    platform    = EXCLUDED.platform,
    app_version = EXCLUDED.app_version;

  -- 账号台账：只记 UUID 与时间，不记用户名（名字由管理页向账号服务解析）。
  IF v_user_id <> '' THEN
    INSERT INTO telemetry_users (user_id, last_seen) VALUES (v_user_id, now())
    ON CONFLICT (user_id) DO UPDATE SET last_seen = now();
  END IF;

  RETURN jsonb_build_object('ok', true, 'accepted', v_accepted, 'rejected', v_rejected);
END;
$$;
