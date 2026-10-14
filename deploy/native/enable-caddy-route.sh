#!/usr/bin/env bash
# 给现有 Caddy 加上认证后端的路由（auth.<domain> → GoTrue）。
#
# ⚠️ 这个脚本会改**正在服务 aionui.cloudbear.cloud 的生产配置**，所以：
#   1. 先备份（带时间戳，落在 /root/caddy-backup-<ts>/）
#   2. 幂等：已经有这条路由就直接退出，不重复插入
#   3. 改完先 `caddy validate`，不通过就**回滚**，绝不 reload 一个坏配置
#   4. reload 后回归验证：既要新路由通，也要确认 aionui 那条老路由没被打坏
#
# 为什么用 `uri strip_prefix` 而不是 handle_path：
#   两种写法都能剥前缀，但 strip_prefix 的行为更直观（剥完就是 GoTrue 的根路径），
#   而且不依赖 handle_path 的 matcher 参数顺序。副作用是 auth.<domain>/health 也能
#   直接探活，正好给冒烟测试用。
#
# 用法：
#   bash enable-caddy-route.sh [--domain auth.cloudbear.cloud] [--upstream 127.0.0.1:9999] [--dry]
#
# 环境要求：Caddy 以 systemd 服务运行且单元里有 ExecReload（本机 /etc/systemd/system/caddy.service 有）。

set -euo pipefail

CADDYFILE=/etc/caddy/Caddyfile
DOMAIN=auth.cloudbear.cloud
UPSTREAM=127.0.0.1:9999
DRY=0
VERIFY_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --upstream) UPSTREAM="$2"; shift 2 ;;
    --dry) DRY=1; shift ;;
    --verify-only) VERIFY_ONLY=1; shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
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
#   所以本地用 curl 模拟是**必然**拿不到 200 的，把 200 当判据会得到假警报
#   （第一版脚本就是这么误报的）。
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

  # 兜底路由必须还在（否则未知主机不再被 404 挡住）
  local CATCH
  CATCH="$(curl -s -o /dev/null -w '%{http_code}' -m 15 -H "Host: nope.cloudbear.cloud" http://127.0.0.1:8081/ || echo 000)"
  if [ "$CATCH" = "404" ]; then
    log "✅ 兜底路由正常（未知主机 → 404）"
  else
    log "❌ 兜底路由异常（未知主机 → HTTP $CATCH，期望 404）"; FAIL=1
  fi

  # 新路由：GoTrue 的 /health
  local NEW_BODY
  NEW_BODY="$(curl -s -m 15 -H "Host: $DOMAIN" http://127.0.0.1:8081/health || echo '')"
  if echo "$NEW_BODY" | grep -q '"version"'; then
    log "✅ 新路由 $DOMAIN/health 通：$NEW_BODY"
  else
    log "❌ 新路由 $DOMAIN/health 不通（响应：${NEW_BODY:-<空>}）"; FAIL=1
  fi

  # 新路由的前缀剥离：/auth/v1/health 也应到 GoTrue 的 /health
  local PREFIX_BODY
  PREFIX_BODY="$(curl -s -m 15 -H "Host: $DOMAIN" http://127.0.0.1:8081/auth/v1/health || echo '')"
  if echo "$PREFIX_BODY" | grep -q '"version"'; then
    log "✅ /auth/v1/ 前缀剥离正确"
  else
    log "❌ /auth/v1/ 前缀剥离异常（响应：${PREFIX_BODY:-<空>}）"; FAIL=1
  fi

  # 端到端：公网既有站点必须还是 200（这条才是「没打坏生产」的真凭据）。
  # 服务器出网失败时只提示，不算失败 —— 那是网络问题不是配置问题。
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
  if verify; then
    echo "✅ 全部通过"
    exit 0
  fi
  echo "❌ 存在未通过项"
  exit 1
fi

# ── 幂等检查 ──
if grep -qF "$DOMAIN" "$CADDYFILE"; then
  log "$DOMAIN 已在 $CADDYFILE 中，无需改动。改跑回归验证："
  if verify; then
    echo "✅ 全部通过"
    exit 0
  fi
  echo "❌ 存在未通过项"
  exit 1
fi

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/root/caddy-backup-$TS"
mkdir -p "$BACKUP_DIR"
cp -a "$CADDYFILE" "$BACKUP_DIR/Caddyfile"
log "已备份到 $BACKUP_DIR/Caddyfile"

# ── 生成新配置：在最后那个兜底 handle 之前插入 ──
NEW="$(mktemp)"
awk -v domain="$DOMAIN" -v upstream="$UPSTREAM" '
  # 兜底 handle（无 matcher 的那个）之前插入新路由。
  # 用「行首 tab + handle {」精确匹配，避免误伤 handle @aionui {
  !done && /^[[:space:]]*handle[[:space:]]*\{[[:space:]]*$/ {
    print "\t@" "mwauth" " host " domain
    print ""
    print "\thandle @mwauth {"
    print "\t\turi strip_prefix /auth/v1"
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

# ── 校验 → 通过才落盘 ──
log "校验新配置…"
if ! caddy validate --config "$NEW" --adapter caddyfile 2>&1 | tail -5; then
  rm -f "$NEW"
  die "caddy validate 不通过，已放弃改动（原配置未动）"
fi

install -m 0644 "$NEW" "$CADDYFILE"
rm -f "$NEW"
log "已写入 $CADDYFILE"

# ── reload（失败即回滚）──
if ! systemctl reload caddy; then
  log "reload 失败，回滚到备份"
  cp -a "$BACKUP_DIR/Caddyfile" "$CADDYFILE"
  systemctl reload caddy || die "回滚后 reload 仍失败，请人工介入：journalctl -u caddy -n 50"
  die "reload 失败已回滚，原配置已恢复"
fi
log "Caddy 已 reload"

# ── 回归验证（判据与说明见文件上方的 verify 函数）──
sleep 2
echo ""
if verify; then
  echo ""
  echo "=== Caddy 路由已就绪 ==="
  echo "  备份  : $BACKUP_DIR/Caddyfile（要回滚就 cp 回去再 systemctl reload caddy）"
  echo "  还差一步：在 Cloudflare 控制台把 $DOMAIN 加为隧道的 Public Hostname → http://localhost:8081"
  exit 0
fi

echo ""
echo "❌ 回归验证未通过。配置已写入但存在问题，建议先回滚："
echo "   cp $BACKUP_DIR/Caddyfile $CADDYFILE && systemctl reload caddy"
exit 1
