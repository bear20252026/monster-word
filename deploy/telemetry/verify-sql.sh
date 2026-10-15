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
SELECT mw_ingest('{\"schema_version\":2,\"device_id\":\"dev-1\",\"user_id\":\"11111111-1111-4111-8111-111111111111\",\"app_version\":\"2.13.0\",\"app_build\":129,\"platform\":\"windows\",\"os_version\":\"Windows 10\",\"locale\":\"zh_CN\",\"days\":[
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
check "user_id 入库"   "$([ "$(q "SELECT user_id FROM usage_daily WHERE device_id='dev-1' AND day='2026-10-13'")" = "11111111-1111-4111-8111-111111111111" ] && echo 1 || echo 0)"   "$(q "SELECT user_id FROM usage_daily WHERE device_id='dev-1' AND day='2026-10-13'")"
check "账号台账写入"   "$([ "$(q "SELECT count(*) FROM telemetry_users WHERE user_id='11111111-1111-4111-8111-111111111111'")" = "1" ] && echo 1 || echo 0)" ""
check "按人汇总视图能算"   "$([ "$(q "SELECT active_days::text || '|' || total_minutes::text FROM usage_user_summary WHERE user_id='11111111-1111-4111-8111-111111111111'")" = "2|1470.0" ] && echo 1 || echo 0)"   "$(q "SELECT user_id || '|' || active_days || '|' || total_minutes || '|' || accuracy_pct FROM usage_user_summary")"

run_ingest() { sudo -u postgres psql -q -tA -d "$SCRATCH" -c "SELECT mw_ingest('$1'::jsonb);" > /dev/null; }

# 无 user_id 的上报不该进账号台账
run_ingest '{"device_id":"dev-nouser","days":[{"day":"2026-10-13","session_count":1}]}'
check "无 user_id 的上报不入账号台账"   "$([ "$(q "SELECT count(*) FROM telemetry_users")" = "1" ] && echo 1 || echo 0)"   "$(q "SELECT count(*) FROM telemetry_users")"

# 先未登录、后登录：应把账号补上
run_ingest '{"device_id":"dev-late","days":[{"day":"2026-10-13","session_count":1}]}'
run_ingest '{"device_id":"dev-late","user_id":"22222222-2222-4222-8222-222222222222","days":[{"day":"2026-10-13","session_count":1}]}'
check "先未登录后登录 ⇒ 账号被补上"   "$([ "$(q "SELECT user_id FROM usage_daily WHERE device_id='dev-late'")" = "22222222-2222-4222-8222-222222222222" ] && echo 1 || echo 0)"   "$(q "SELECT user_id FROM usage_daily WHERE device_id='dev-late'")"

# 先有账号、后变空：不该把已有关联抹掉
run_ingest '{"device_id":"dev-late","user_id":"","days":[{"day":"2026-10-13","session_count":1}]}'
check "已有关联不被空值抹掉"   "$([ "$(q "SELECT user_id FROM usage_daily WHERE device_id='dev-late'")" = "22222222-2222-4222-8222-222222222222" ] && echo 1 || echo 0)"   "$(q "SELECT user_id FROM usage_daily WHERE device_id='dev-late'")"

# 超长 user_id 应被截断，而不是让整批失败
# 2026-10-15 审计 R3-S10：user_id 现在必须是 UUID 或空串。
# 超长/非法值**降级为「未绑定账号」**而不是拒整批 —— 当天的使用数据本身是好的。
check "非法 user_id 被降级为空串而不是让整批失败"   "$(sudo -u postgres psql -tA -d "$SCRATCH" -c "SELECT (mw_ingest(jsonb_build_object('device_id','dev-long','user_id',repeat('x',300),'days',jsonb_build_array(jsonb_build_object('day','2026-10-13','session_count',1))))->>'accepted');" | grep -q '^1$' && echo 1 || echo 0)"   "$(q "SELECT length(user_id) FROM usage_daily WHERE device_id='dev-long'")"
check "非法 user_id 入库为空串"   "$([ "$(q "SELECT user_id FROM usage_daily WHERE device_id='dev-long'")" = "" ] && echo 1 || echo 0)"   "$(q "SELECT user_id FROM usage_daily WHERE device_id='dev-long'")"

echo "=== 状态量只在「报文带了该键」时覆盖（R3-S11）==="
# 先写入状态量
run_ingest '{"device_id":"dev-state","days":[{"day":"2026-10-13","book_word_count":4000,"book_learned_count":350}]}'
check "状态量首次入库"   "$([ "$(q "SELECT book_learned_count FROM usage_daily WHERE device_id='dev-state'")" = "350" ] && echo 1 || echo 0)"   "$(q "SELECT book_learned_count FROM usage_daily WHERE device_id='dev-state'")"
# 再送一次**不带这两个键**的上报：不该把已有状态清零
run_ingest '{"device_id":"dev-state","days":[{"day":"2026-10-13","session_count":1}]}'
check "缺字段的补传不清零状态量"   "$([ "$(q "SELECT book_learned_count FROM usage_daily WHERE device_id='dev-state'")" = "350" ] && echo 1 || echo 0)"   "$(q "SELECT book_learned_count FROM usage_daily WHERE device_id='dev-state'")"
# 显式送 0 则要真的写成 0（判据是「键在不在」而不是「值大不大」——换本小词书是合法场景）
run_ingest '{"device_id":"dev-state","days":[{"day":"2026-10-13","book_learned_count":0}]}'
check "显式送 0 时状态量真的被覆盖"   "$([ "$(q "SELECT book_learned_count FROM usage_daily WHERE device_id='dev-state'")" = "0" ] && echo 1 || echo 0)"   "$(q "SELECT book_learned_count FROM usage_daily WHERE device_id='dev-state'")"

echo "=== 台账只在真的接受了数据时才写（R3-S05）==="
run_ingest '{"device_id":"dev-nodata","days":[]}'
check "空 days 不写设备台账"   "$([ "$(q "SELECT count(*) FROM devices WHERE device_id='dev-nodata'")" = "0" ] && echo 1 || echo 0)"   "$(q "SELECT count(*) FROM devices WHERE device_id='dev-nodata'")"
run_ingest '{"device_id":"dev-futuredate","days":[{"day":"2099-01-01","session_count":1}]}'
check "未来日期被拒且不写台账"   "$([ "$(q "SELECT count(*) FROM devices WHERE device_id='dev-futuredate'")" = "0" ] && echo 1 || echo 0)"   "$(q "SELECT count(*) FROM devices WHERE device_id='dev-futuredate'")"

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

echo "=== 模块打开次数的合并策略（逐键取较大值）==="
# 2026-10-15 验收时实测发现：早期实现用 EXCLUDED 整对象覆盖，
# 「先 {"learn":4,"review":2} 再 {"learn":1}」会把 review 整个键丢掉、learn 还被改小。
run_ingest '{"device_id":"dev-mod","days":[{"day":"2026-10-15","module_open_counts":{"learn":4,"review":2}}]}'
run_ingest '{"device_id":"dev-mod","days":[{"day":"2026-10-15","module_open_counts":{"learn":1,"dict":7}}]}'
check "较小的模块计数不覆盖已有较大值" \
  "$([ "$(q "SELECT (module_open_counts->>'learn')::int FROM usage_daily WHERE device_id='dev-mod'")" = "4" ] && echo 1 || echo 0)" \
  "$(q "SELECT module_open_counts FROM usage_daily WHERE device_id='dev-mod'")"
check "本次未带上的模块键不被抹掉" \
  "$([ "$(q "SELECT (module_open_counts->>'review')::int FROM usage_daily WHERE device_id='dev-mod'")" = "2" ] && echo 1 || echo 0)" \
  "$(q "SELECT module_open_counts FROM usage_daily WHERE device_id='dev-mod'")"
check "新增的模块键被并入" \
  "$([ "$(q "SELECT (module_open_counts->>'dict')::int FROM usage_daily WHERE device_id='dev-mod'")" = "7" ] && echo 1 || echo 0)" \
  "$(q "SELECT module_open_counts FROM usage_daily WHERE device_id='dev-mod'")"
# 上面那次幂等上报没带 module_open_counts（被清洗成 {}），合并后不该把已有的键抹掉
check "整批未带模块计数时已有计数保持不变" \
  "$([ "$(q "SELECT (module_open_counts->>'listen')::int FROM usage_daily WHERE device_id='dev-1' AND day='2026-10-13'")" = "1" ] && echo 1 || echo 0)" \
  "$(q "SELECT module_open_counts FROM usage_daily WHERE device_id='dev-1' AND day='2026-10-13'")"

echo "=== 边界与拒绝 ==="
# 校验失败必须带 mw_invalid_input: 前缀 —— 服务端据此回 400 而不是 500（见 server.mjs）。
# 没这个前缀时，客户端把请求发错会被记成「服务端故障」，把告警与 Sentry 刷满。
#
# ⚠️ 取错误文本必须走这个 helper，不能直接 `psql … | grep -q …`：
# 本脚本开了 `set -o pipefail`，而「调用必定失败」的场景里 psql 退出码非零，
# 会让整条管道失败 ⇒ grep 的判定被吃掉，断言恒为假（第一版就是这么误报 3 条的）。
err_of() { sudo -u postgres psql -tA -d "$SCRATCH" -c "$1" 2>&1 || true; }

check "缺 device_id 被拒且带校验前缀" \
  "$(err_of "SELECT mw_ingest('{\"days\":[]}'::jsonb);" | grep -q 'mw_invalid_input: device_id 缺失' && echo 1 || echo 0)" ""
check "days 非数组被拒且带校验前缀" \
  "$(err_of "SELECT mw_ingest('{\"device_id\":\"d\",\"days\":{}}'::jsonb);" | grep -q 'mw_invalid_input: days 必须是数组' && echo 1 || echo 0)" ""
check "超过 31 天被拒且带校验前缀" \
  "$(err_of "SELECT mw_ingest(jsonb_build_object('device_id','d','days',(SELECT jsonb_agg(jsonb_build_object('day','2026-01-01')) FROM generate_series(1,32))));" | grep -q 'mw_invalid_input: days 超过 31 条' && echo 1 || echo 0)" ""
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
