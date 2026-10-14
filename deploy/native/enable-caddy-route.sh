#!/usr/bin/env bash
# 给现有 Caddy 追加一条主机名路由（把某个域名指到某个本地上游）。
#
# ⚠️ 这个脚本会改**正在服务生产流量的**配置，所以：
#   1. 先备份（带时间戳，落在 /root/caddy-backup-<ts>/）
#   2. 幂等：域名已经在配置里就直接退出，不重复插入
#   3. 改完先 `caddy validate`，不通过就**放弃改动**，绝不 reload 一个坏配置
#   4. reload 后回归验证：既要新路由通，也要确认既有路由没被打坏
#
# 本脚本由「只服务认证后端」那一版泛化而来。两条路由形状不同 ——
# auth 要剥 /auth/v1 前缀，telemetry 是纯反代 —— 所以前缀剥离做成可选
# （--prefix 传空字符串即不剥）。
#
# 用法：
#   bash enable-caddy-route.sh [选项]
#     --name <matcher>        Caddyfile 里的 matcher 名，默认 mwauth
#     --domain <host>         对外域名，默认 auth.cloudbear.cloud
#     --upstream <host:port>  上游，默认 127.0.0.1:9999
#     --prefix <path>         要剥掉的前缀；传空字符串表示不剥（纯反代）
#     --health-path <path>    回归验证时探的路径，默认 /health
#     --health-expect <text>  响应里应包含的片段，默认 "version"
#     --dry                   只打印改动预览，不落盘
#     --verify-only           不改配置，只跑回归验证
#
# 认证后端（已配置，仅作参考）：
#   bash enable-caddy-route.sh
# 使用统计：
#   bash enable-caddy-route.sh --name mwtelemetry --domain stats.cloudbear.cloud \
#     --upstream 127.0.0.1:8080 --prefix '' --health-path /healthz --health-expect '"ok":true'

set -euo pipefail

CADDYFILE=/etc/caddy/Caddyfile
MATCHER=mwauth
DOMAIN=auth.cloudbear.cloud
UPSTREAM=127.0.0.1:9999
PREFIX=/auth/v1
HEALTH_PATH=/health
HEALTH_EXPECT='"version"'
DRY=0
VERIFY_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --name) MATCHER="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --upstream) UPSTREAM="$2"; shift 2 ;;
    --prefix) PREFIX="$2"; shift 2 ;;
    --health-path) HEALTH_PATH="$2"; shift 2 ;;
    --health-expect) HEALTH_EXPECT="$2"; shift 2 ;;
    --dry) DRY=1; shift ;;
    --verify-only) VERIFY_ONLY=1; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "未知参数：$1"; exit 1 ;;
  esac
done

log() { echo "[caddy-route] $*"; }
die() { echo "[caddy-route] ❌ $*" >&2; exit 1; }

[ "$(id -u)" = "0" ] || die "必须以 root 运行"
[ -f "$CADDYFILE" ] || die "找不到 $CADDYFILE"

# ── 回归验证（也用于 --verify-only）────────────────────────────
#
# ⚠️ 既有路由 aionui 的判据**不是** 200/401。实测（2026-10-14）：
#   authelia 对「不是从真实链路进来的」forward-auth 请求一律回 400 ——
#   连直连 http://127.0.0.1:9091/api/authz/forward-auth 裸请求也是 400。
#   所以本地用 curl 模拟是**必然**拿不到 200 的，把 200 当判据会得到假警报。
# 正确的本地判据只有一条：**路由仍匹配到 aionui 上游** ——
#   既不是兜底 handle 的 404，也不是上游挂掉的 502/503。
# 端到端证据另外取：从服务器访问公网 https://aionui.cloudbear.cloud/ 应为 200。
verify() {
  local FAIL=0

  local OLD_CODE
  OLD_CODE="$(curl -s -o /dev/null -w '%{http_code}' -m 15 -H "Host: aionui.cloudbear.cloud" http://127.0.0.1:8081/ || echo 000)"
  case "$OLD_CODE" in
    404) log "❌ 既有路由 aionui 掉到兜底 404 了 —— 路由没匹配上，配置被改坏"; FAIL=1 ;;
    502|503|000) log "❌ 既有路由 aionui 上游不可达（HTTP $OLD_CODE）"; FAIL=1 ;;
    *) log "✅ 既有路由 aionui 仍匹配到上游（HTTP $OLD_CODE，authelia 对本地模拟请求回 400 属正常）" ;;
  esac

  local CATCH
  CATCH="$(curl -s -o /dev/null -w '%{http_code}' -m 15 -H "Host: nope.cloudbear.cloud" http://127.0.0.1:8081/ || echo 000)"
  if [ "$CATCH" = "404" ]; then
    log "✅ 兜底路由正常（未知主机 → 404）"
  else
    log "❌ 兜底路由异常（未知主机 → HTTP $CATCH，期望 404）"; FAIL=1
  fi

  # 认证路由是本次的「既有路由」之一：改统计路由时它必须不受影响。
  # 若本次改的正是认证路由（DOMAIN 相同）则跳过，由下面「新路由」那段测。
  if [ "$DOMAIN" != "auth.cloudbear.cloud" ]; then
    local AUTH_BODY
    AUTH_BODY="$(curl -s -m 15 -H "Host: auth.cloudbear.cloud" "http://127.0.0.1:8081/auth/v1/health" || echo '')"
    if echo "$AUTH_BODY" | grep -qF '"version"'; then
      log "✅ 既有路由 auth.cloudbear.cloud 正常"
    else
      log "❌ 既有路由 auth.cloudbear.cloud 异常（响应：${AUTH_BODY:0:80}）"; FAIL=1
    fi
  fi

  local NEW_BODY
  NEW_BODY="$(curl -s -m 15 -H "Host: $DOMAIN" "http://127.0.0.1:8081$HEALTH_PATH" || echo '')"
  if echo "$NEW_BODY" | grep -qF "$HEALTH_EXPECT"; then
    log "✅ 新路由 $DOMAIN$HEALTH_PATH 通：${NEW_BODY:0:80}"
  else
    log "❌ 新路由 $DOMAIN$HEALTH_PATH 不通（响应：${NEW_BODY:0:80}）"; FAIL=1
  fi

  if [ -n "$PREFIX" ]; then
    local PREFIX_BODY
    PREFIX_BODY="$(curl -s -m 15 -H "Host: $DOMAIN" "http://127.0.0.1:8081${PREFIX}${HEALTH_PATH}" || echo '')"
    if echo "$PREFIX_BODY" | grep -qF "$HEALTH_EXPECT"; then
      log "✅ $PREFIX 前缀剥离正确"
    else
      log "❌ $PREFIX 前缀剥离异常（响应：${PREFIX_BODY:0:80}）"; FAIL=1
    fi
  fi

  local PUB_AIONUI PUB_GALLERY
  PUB_AIONUI="$(curl -s -o /dev/null -w '%{http_code}' -m 25 https://aionui.cloudbear.cloud/ || echo 000)"
  PUB_GALLERY="$(curl -s -o /dev/null -w '%{http_code}' -m 25 https://cloudbear.cloud/ || echo 000)"
  if [ "$PUB_AIONUI" = "000" ]; then
    log "⚠️ 取不到公网 aionui 状态（出网受限），跳过端到端检查"
  elif [ "$PUB_AIONUI" = "200" ]; then
    log "✅ 公网 aionui.cloudbear.cloud 仍为 200"
  else
    log "❌ 公网 aionui.cloudbear.cloud 返回 $PUB_AIONUI（期望 200）"; FAIL=1
  fi
  if [ "$PUB_GALLERY" = "200" ]; then
    log "✅ 公网 cloudbear.cloud 仍为 200（gallery 未受影响）"
  elif [ "$PUB_GALLERY" != "000" ]; then
    log "⚠️ 公网 cloudbear.cloud 返回 $PUB_GALLERY"
  fi

  return "$FAIL"
}

if [ "$VERIFY_ONLY" = "1" ]; then
  echo "=== 仅验证（不改配置）==="
  if verify; then echo "✅ 全部通过"; exit 0; fi
  echo "❌ 存在未通过项"; exit 1
fi

# ── 幂等检查 ──
if grep -qF "$DOMAIN" "$CADDYFILE"; then
  log "$DOMAIN 已在 $CADDYFILE 中，无需改动。改跑回归验证："
  if verify; then echo "✅ 全部通过"; exit 0; fi
  echo "❌ 存在未通过项"; exit 1
fi

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/root/caddy-backup-$TS"
mkdir -p "$BACKUP_DIR"
cp -a "$CADDYFILE" "$BACKUP_DIR/Caddyfile"
log "已备份到 $BACKUP_DIR/Caddyfile"

NEW="$(mktemp)"
awk -v matcher="$MATCHER" -v domain="$DOMAIN" -v upstream="$UPSTREAM" -v prefix="$PREFIX" '
  # 兜底 handle（无 matcher 的那个）之前插入新路由。
  # 用「行首空白 + handle {」精确匹配，避免误伤 handle @aionui {
  !done && /^[[:space:]]*handle[[:space:]]*\{[[:space:]]*$/ {
    print "\t@" matcher " host " domain
    print ""
    print "\thandle @" matcher " {"
    if (prefix != "") print "\t\turi strip_prefix " prefix
    print "\t\treverse_proxy " upstream
    print "\t}"
    print ""
    done=1
  }
  { print }
  END { if (!done) exit 3 }
' "$CADDYFILE" > "$NEW" || { rm -f "$NEW"; die "没找到兜底 handle 块，$CADDYFILE 结构与预期不符，未改动"; }

log "改动预览（新配置与旧配置的差异）："
diff -u "$CADDYFILE" "$NEW" || true

if [ "$DRY" = "1" ]; then
  rm -f "$NEW"
  log "--dry：已回滚，未改动任何文件"
  exit 0
fi

log "校验新配置…"
if ! caddy validate --config "$NEW" --adapter caddyfile 2>&1 | tail -5; then
  rm -f "$NEW"
  die "caddy validate 不通过，已放弃改动（原配置未动）"
fi

install -m 0644 "$NEW" "$CADDYFILE"
rm -f "$NEW"
log "已写入 $CADDYFILE"

if ! systemctl reload caddy; then
  log "reload 失败，回滚到备份"
  cp -a "$BACKUP_DIR/Caddyfile" "$CADDYFILE"
  systemctl reload caddy || die "回滚后 reload 仍失败，请人工介入：journalctl -u caddy -n 50"
  die "reload 失败已回滚，原配置已恢复"
fi
log "Caddy 已 reload"

sleep 2
echo ""
if verify; then
  echo ""
  echo "=== Caddy 路由已就绪：$DOMAIN → $UPSTREAM ==="
  echo "  备份  : $BACKUP_DIR/Caddyfile（要回滚就 cp 回去再 systemctl reload caddy）"
  echo "  还差一步：在 Cloudflare 控制台把 $DOMAIN 加为隧道的「已发布应用程序路由」"
  echo "            → 添加路由 → 已发布应用程序 → 服务 URL 填 http://localhost:8081"
  echo "            ⚠️ 别点「主机名路由」标签，那是需要 WARP 客户端的专用路由，对公网不生效"
  exit 0
fi

echo "❌ 回归验证未通过。配置已写入但存在问题，建议先回滚："
echo "   cp $BACKUP_DIR/Caddyfile $CADDYFILE && systemctl reload caddy"
exit 1
