#!/usr/bin/env bash
# 在服务器的**临时库**里验证 schema.sql + functions.sql 真的能跑。
# 不碰任何已有库；跑完删掉临时库。不改动任何已有库。
set -euo pipefail

SCRATCH=mw_telemetry_selftest_$$
SRC="${1:?用法: verify-sql.sh <sql 所在目录>}"

cleanup() { sudo -u postgres dropdb --if-exists "$SCRATCH" >/dev/null 2>&1 || true; }
trap cleanup EXIT

fail=0
check() { if [ "$2" = "1" ]; then echo "ok   $1"; else echo "FAIL $1  → $3"; fail=$((fail+1)); fi; }

echo "=== 建临时库 $SCRATCH ==="
sudo -u postgres createdb "$SCRATCH"
sudo -u postgres psql -q -v ON_ERROR_STOP=1 -d "$SCRATCH" -f "$SRC/schema.sql"
sudo -u postgres psql -q -v ON_ERROR_STOP=1 -d "$SCRATCH" -f "$SRC/functions.sql"
echo "schema + functions 应用成功"

echo "=== 正常上报（含脏数据与非法模块键）==="
RESULT="$(sudo -u postgres psql -tA -d "$SCRATCH" -c "
SELECT mw_ingest('{\"schema_version\":2,\"device_id\":\"dev-1\",\"user_id\":\"user-aaa\",\"app_version\":\"2.13.0\",\"app_build\":129,\"platform\":\"windows\",\"os_version\":\"Windows 10\",\"locale\":\"zh_CN\",\"days\":[
  {\"day\":\"2026-10-13\",\"foreground_ms\":1800000,\"session_count\":3,\"study_session_count\":2,\"words_reviewed\":40,\"words_correct\":33,\"new_words_learned\":12,\"book_word_count\":1000,\"book_learned_count\":120,\"streak_days\":5,\"coins_earned\":30,\"module_open_counts\":{\"learn\":3,\"listen\":1,\"随便写的键\":9}},
  {\"day\":\"not-a-date\",\"foreground_ms\":1000},
  {\"day\":\"2026-13-45\",\"foreground_ms\":1000},
  {\"day\":\"2026-10-14\",\"foreground_ms\":99999999999,\"words_reviewed\":10,\"words_correct\":999}
]}'::jsonb);")"
echo "  → $RESULT"

ACC="$(echo "$RESULT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["accepted"])')"
REJ="$(echo "$RESULT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["rejected"])')"
check "接受了 2 条合法日期" "$([ "$ACC" = "2" ] && echo 1 || echo 0)" "accepted=$ACC"
check "拒绝了 2 条非法日期" "$([ "$REJ" = "2" ] && echo 1 || echo 0)" "rejected=$REJ"

q() { sudo -u postgres psql -tA -d "$SCRATCH" -c "$1"; }

check "前台时长被夹到 24h" \
  "$([ "$(q "SELECT foreground_ms FROM usage_daily WHERE day='2026-10-14'")" = "86400000" ] && echo 1 || echo 0)" \
  "$(q "SELECT foreground_ms FROM usage_daily WHERE day='2026-10-14'")"
check "答对数不超过复习词次" \
  "$([ "$(q "SELECT words_correct FROM usage_daily WHERE day='2026-10-14'")" = "10" ] && echo 1 || echo 0)" \
  "$(q "SELECT words_correct FROM usage_daily WHERE day='2026-10-14'")"
check "非法模块键被白名单丢弃" \
  "$([ "$(q "SELECT module_open_counts ? '随便写的键' FROM usage_daily WHERE device_id='dev-1' AND day='2026-10-13'")" = "f" ] && echo 1 || echo 0)" \
  "$(q "SELECT module_open_counts FROM usage_daily WHERE device_id='dev-1' AND day='2026-10-13'")"
check "合法模块键保留" \
  "$([ "$(q "SELECT (module_open_counts->>'learn')::int FROM usage_daily WHERE device_id='dev-1' AND day='2026-10-13'")" = "3" ] && echo 1 || echo 0)" \
  "$(q "SELECT module_open_counts FROM usage_daily WHERE device_id='dev-1' AND day='2026-10-13'")"
check "设备台账写入" \
  "$([ "$(q "SELECT count(*) FROM devices WHERE device_id='dev-1'")" = "1" ] && echo 1 || echo 0)" ""

echo "=== 账号关联（管理端「按人看」）==="
check "user_id 入库"   "$([ "$(q "SELECT user_id FROM usage_daily WHERE device_id='dev-1' AND day='2026-10-13'")" = "user-aaa" ] && echo 1 || echo 0)"   "$(q "SELECT user_id FROM usage_daily WHERE device_id='dev-1' AND day='2026-10-13'")"
check "账号台账写入"   "$([ "$(q "SELECT count(*) FROM telemetry_users WHERE user_id='user-aaa'")" = "1" ] && echo 1 || echo 0)" ""
check "按人汇总视图能算"   "$([ "$(q "SELECT active_days::text || '|' || total_minutes::text FROM usage_user_summary WHERE user_id='user-aaa'")" = "2|1470.0" ] && echo 1 || echo 0)"   "$(q "SELECT user_id || '|' || active_days || '|' || total_minutes || '|' || accuracy_pct FROM usage_user_summary")"

run_ingest() { sudo -u postgres psql -q -tA -d "$SCRATCH" -c "SELECT mw_ingest('$1'::jsonb);" > /dev/null; }

# 无 user_id 的上报不该进账号台账
run_ingest '{"device_id":"dev-nouser","days":[{"day":"2026-10-13","session_count":1}]}'
check "无 user_id 的上报不入账号台账"   "$([ "$(q "SELECT count(*) FROM telemetry_users")" = "1" ] && echo 1 || echo 0)"   "$(q "SELECT count(*) FROM telemetry_users")"

# 先未登录、后登录：应把账号补上
run_ingest '{"device_id":"dev-late","days":[{"day":"2026-10-13","session_count":1}]}'
run_ingest '{"device_id":"dev-late","user_id":"user-bbb","days":[{"day":"2026-10-13","session_count":1}]}'
check "先未登录后登录 ⇒ 账号被补上"   "$([ "$(q "SELECT user_id FROM usage_daily WHERE device_id='dev-late'")" = "user-bbb" ] && echo 1 || echo 0)"   "$(q "SELECT user_id FROM usage_daily WHERE device_id='dev-late'")"

# 先有账号、后变空：不该把已有关联抹掉
run_ingest '{"device_id":"dev-late","user_id":"","days":[{"day":"2026-10-13","session_count":1}]}'
check "已有关联不被空值抹掉"   "$([ "$(q "SELECT user_id FROM usage_daily WHERE device_id='dev-late'")" = "user-bbb" ] && echo 1 || echo 0)"   "$(q "SELECT user_id FROM usage_daily WHERE device_id='dev-late'")"

# 超长 user_id 应被截断，而不是让整批失败
check "超长 user_id 被截断而不是让整批失败"   "$(sudo -u postgres psql -tA -d "$SCRATCH" -c "SELECT (mw_ingest(jsonb_build_object('device_id','dev-long','user_id',repeat('x',300),'days',jsonb_build_array(jsonb_build_object('day','2026-10-13','session_count',1))))->>'accepted');" | grep -q '^1$' && echo 1 || echo 0)"   "$(q "SELECT length(user_id) FROM usage_daily WHERE device_id='dev-long'")"

echo "=== 幂等：重复送同一天，取较大值 ==="
sudo -u postgres psql -q -tA -d "$SCRATCH" -c "
SELECT mw_ingest('{\"device_id\":\"dev-1\",\"platform\":\"windows\",\"days\":[{\"day\":\"2026-10-13\",\"foreground_ms\":60000,\"session_count\":1,\"words_reviewed\":5}]}'::jsonb);" > /dev/null
check "重复上报不新增行（主键幂等）" \
  "$([ "$(q "SELECT count(*) FROM usage_daily WHERE device_id='dev-1' AND day='2026-10-13'")" = "1" ] && echo 1 || echo 0)" \
  "$(q "SELECT count(*) FROM usage_daily")"
check "较小的值不覆盖已有较大值" \
  "$([ "$(q "SELECT foreground_ms FROM usage_daily WHERE device_id='dev-1' AND day='2026-10-13'")" = "1800000" ] && echo 1 || echo 0)" \
  "$(q "SELECT foreground_ms FROM usage_daily WHERE device_id='dev-1' AND day='2026-10-13'")"
# 注意：boolean::text 在 PostgreSQL 里是 'true'/'false'；psql 直接打印 boolean 列才是 't'/'f'。
# 第一版按 't' 比，于是误报失败。
check "设备 last_seen 被刷新" \
  "$([ "$(q "SELECT CASE WHEN last_seen > first_seen THEN 'yes' ELSE 'no' END FROM devices WHERE device_id='dev-1'")" = "yes" ] && echo 1 || echo 0)" \
  "$(q "SELECT first_seen = last_seen FROM devices WHERE device_id='dev-1'")"

echo "=== 边界与拒绝 ==="
check "缺 device_id 被拒" \
  "$(sudo -u postgres psql -tA -d "$SCRATCH" -c "SELECT mw_ingest('{\"days\":[]}'::jsonb);" >/dev/null 2>&1 && echo 0 || echo 1)" ""
check "days 非数组被拒" \
  "$(sudo -u postgres psql -tA -d "$SCRATCH" -c "SELECT mw_ingest('{\"device_id\":\"d\",\"days\":{}}'::jsonb);" >/dev/null 2>&1 && echo 0 || echo 1)" ""
check "超过 31 天被拒" \
  "$(sudo -u postgres psql -tA -d "$SCRATCH" -c "SELECT mw_ingest(jsonb_build_object('device_id','d','days',(SELECT jsonb_agg(jsonb_build_object('day','2026-01-01')) FROM generate_series(1,32))));" >/dev/null 2>&1 && echo 0 || echo 1)" ""
# 第一版写成 "$(q "..." = "0" && ...)"，`= "0"` 落在了命令替换内部，
# 变成给 psql 传了额外参数而不是做比较 —— 于是永远为假。
check "空 days 正常返回 0" \
  "$([ "$(q "SELECT (mw_ingest('{\"device_id\":\"dev-empty\",\"days\":[]}'::jsonb)->>'accepted')")" = "0" ] && echo 1 || echo 0)" \
  "$(q "SELECT mw_ingest('{\"device_id\":\"dev-empty2\",\"days\":[]}'::jsonb)")"

echo "=== 汇总视图 ==="
echo "  $(q "SELECT day || ' | 活跃 ' || active_devices || ' | 分钟 ' || total_minutes || ' | 正确率 ' || coalesce(accuracy_pct::text,'—') FROM usage_daily_summary LIMIT 3" | tr '\n' ' ')"

echo ""
if [ "$fail" = "0" ]; then echo "全部通过"; else echo "$fail 项失败"; exit 1; fi
