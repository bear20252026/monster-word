#!/usr/bin/env bash
# 原生部署 Monster Word 使用统计服务（PostgreSQL + Node 服务 + systemd）。
#
# 与认证后端同一台机器、同一个 PostgreSQL 实例，但**独立库 mw_telemetry**：
# 统计是可丢弃的观测数据，账号是身份数据，两者的备份/保留/权限策略完全不同，
# 混在一个库里将来会互相牵制。
#
# 幂等：重复运行只补缺的。**已有 .env 里的管理密码不会被重置**，数据库不会被清空。
#
# 用法（在服务器上以 root 运行）：
#   bash install-telemetry.sh
#
# 参数：
#   --port <port>    监听端口，默认 8080（只绑 127.0.0.1）
#   --db <name>      库名，默认 mw_telemetry

set -euo pipefail

TELEMETRY_DIR=/opt/mw-telemetry
TELEMETRY_USER=mw-telemetry
DB_NAME=mw_telemetry
DB_ROLE=mw_telemetry_app
LISTEN_PORT=8080
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --port) LISTEN_PORT="$2"; shift 2 ;;
    --db) DB_NAME="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "未知参数：$1"; exit 1 ;;
  esac
done

log() { echo "[install-telemetry] $*"; }
die() { echo "[install-telemetry] ❌ $*" >&2; exit 1; }

[ "$(id -u)" = "0" ] || die "必须以 root 运行"
command -v systemctl >/dev/null || die "没有 systemd"
command -v psql >/dev/null || die "没有 psql —— 请先部署认证后端（deploy/native/install-auth.sh）或 apt install postgresql"
command -v node >/dev/null || die "没有 node"

# ── 1. 角色与库 ──────────────────────────────────────────────
mkdir -p "$TELEMETRY_DIR"
ENV_FILE="$TELEMETRY_DIR/.env"

if [ -f "$ENV_FILE" ]; then
  log ".env 已存在，沿用其中的密码（不重置）"
  DB_PASSWORD="$(grep -E '^MW_DB_PASSWORD=' "$ENV_FILE" | cut -d= -f2- || true)"
  ADMIN_PASSWORD="$(grep -E '^ADMIN_PASSWORD=' "$ENV_FILE" | cut -d= -f2- || true)"
  [ -n "$DB_PASSWORD" ] || die ".env 存在但缺 MW_DB_PASSWORD，请人工确认后再跑"
  [ -n "$ADMIN_PASSWORD" ] || die ".env 存在但缺 ADMIN_PASSWORD，请人工确认后再跑"
else
  # 同认证后端：只取字母数字，避免拼进 URL 时要 URL 编码
  DB_PASSWORD="$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | cut -c1-32)"
  ADMIN_PASSWORD="$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | cut -c1-24)"
  log "已生成数据库密码与管理页密码"
fi

log "配置角色 $DB_ROLE 与数据库 $DB_NAME…"
sudo -u postgres psql -v ON_ERROR_STOP=1 -q <<EOF
DO \$\$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$DB_ROLE') THEN
    ALTER ROLE $DB_ROLE WITH LOGIN PASSWORD '$DB_PASSWORD';
  ELSE
    CREATE ROLE $DB_ROLE WITH LOGIN PASSWORD '$DB_PASSWORD';
  END IF;
END
\$\$;
EOF

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
  log "创建数据库 $DB_NAME（owner=$DB_ROLE）"
  sudo -u postgres createdb -O "$DB_ROLE" "$DB_NAME"
else
  log "数据库 $DB_NAME 已存在，保持不动"
fi

# 函数里用了 pgcrypto 之外的标准能力，但 mw_ingest 会写 JSONB 与正则，
# 都是 PG 内置；这里只需要保证角色能在 public 下建表。
sudo -u postgres psql -v ON_ERROR_STOP=1 -q -d "$DB_NAME" \
  -c "GRANT ALL ON SCHEMA public TO $DB_ROLE;"

# ── 2. 表与函数 ──────────────────────────────────────────────
log "应用 schema.sql 与 functions.sql…"
# 用 mw_telemetry_app 身份执行：这样建出来的表属主就是它，运行时不需要超级用户。
PGPASSWORD="$DB_PASSWORD" psql -h 127.0.0.1 -U "$DB_ROLE" -d "$DB_NAME" \
  -v ON_ERROR_STOP=1 -q -f "$SRC_DIR/schema.sql"
PGPASSWORD="$DB_PASSWORD" psql -h 127.0.0.1 -U "$DB_ROLE" -d "$DB_NAME" \
  -v ON_ERROR_STOP=1 -q -f "$SRC_DIR/functions.sql"

# ── 3. 服务代码 ──────────────────────────────────────────────
log "安装服务到 $TELEMETRY_DIR…"
install -m 0644 "$SRC_DIR/server.mjs" "$TELEMETRY_DIR/server.mjs"
install -m 0644 "$SRC_DIR/schema.sql" "$TELEMETRY_DIR/schema.sql"
install -m 0644 "$SRC_DIR/functions.sql" "$TELEMETRY_DIR/functions.sql"

log "写入 $ENV_FILE"
cat > "$ENV_FILE" <<EOF
# Monster Word 使用统计服务配置（由 deploy/telemetry/install-telemetry.sh 生成）
# ⚠️ 含密码，权限 640 root:服务账户。不要进仓库、不要贴聊天记录。

PG_DB=$DB_NAME
LISTEN_PORT=$LISTEN_PORT
# Caddy 反代过来，客户端真实 IP 在 X-Forwarded-For 里 —— 不开这个限流会退化成
# 「所有请求都算 127.0.0.1 一个来源」，等于限流失效。
TRUST_PROXY=1

ADMIN_USER=admin
ADMIN_PASSWORD=$ADMIN_PASSWORD

# 供运维脚本读取（服务本身不认这个变量）
MW_DB_PASSWORD=$DB_PASSWORD
MW_TELEMETRY_DB=$DB_NAME
EOF
chmod 640 "$ENV_FILE"

# ── 4. 运行账户与 systemd ────────────────────────────────────
if ! id "$TELEMETRY_USER" >/dev/null 2>&1; then
  log "创建系统账户 $TELEMETRY_USER"
  useradd --system --no-create-home --shell /usr/sbin/nologin "$TELEMETRY_USER"
fi
chown -R "root:$TELEMETRY_USER" "$TELEMETRY_DIR"
chmod 750 "$TELEMETRY_DIR"

log "安装 systemd 单元"
cat > /etc/systemd/system/mw-telemetry.service <<EOF
[Unit]
Description=Monster Word 使用统计服务
Documentation=file://$TELEMETRY_DIR/README.md
After=network-online.target postgresql.service
Wants=network-online.target
Requires=postgresql.service
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
User=$TELEMETRY_USER
Group=$TELEMETRY_USER
WorkingDirectory=$TELEMETRY_DIR
EnvironmentFile=$ENV_FILE
ExecStart=$(command -v node) $TELEMETRY_DIR/server.mjs
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
# 服务需要 spawn psql 子进程，所以要能执行 /usr/bin/psql；
# ProtectSystem=strict 下可执行文件仍是只读可见的，无需额外放行。
ReadWritePaths=$TELEMETRY_DIR

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --quiet mw-telemetry.service
systemctl restart mw-telemetry.service

# ── 5. 自检 ──────────────────────────────────────────────────
log "等待服务就绪…"
OK=0
for _ in $(seq 1 15); do
  sleep 1
  if curl -sf -m 3 "http://127.0.0.1:$LISTEN_PORT/healthz" >/dev/null 2>&1; then OK=1; break; fi
done
if [ "$OK" != "1" ]; then
  echo ""
  echo "❌ 服务未就绪。最近日志："
  journalctl -u mw-telemetry --no-pager -n 30 || true
  exit 1
fi
log "✅ 健康检查通过"

# 端到端自检：真发一条假数据进去，确认入库函数工作正常，再删掉。
log "端到端自检（写入一条测试数据再删除）…"
TEST_DEVICE="__selftest__$(date +%s)"
curl -sf -m 10 -X POST "http://127.0.0.1:$LISTEN_PORT/v1/report" \
  -H 'Content-Type: application/json' \
  -d "{\"schema_version\":1,\"device_id\":\"$TEST_DEVICE\",\"app_version\":\"0.0.0\",\"app_build\":0,\"platform\":\"selftest\",\"os_version\":\"\",\"locale\":\"\",\"days\":[{\"day\":\"2026-01-01\",\"foreground_ms\":60000,\"session_count\":1,\"module_open_counts\":{\"learn\":1,\"随便写的\":9}}]}" \
  > /dev/null || die "上报自检失败（见 journalctl -u mw-telemetry）"

SELFTEST_ROWS="$(PGPASSWORD="$DB_PASSWORD" psql -h 127.0.0.1 -U "$DB_ROLE" -d "$DB_NAME" -tAc \
  "SELECT count(*) FROM usage_daily WHERE device_id = '$TEST_DEVICE'")"
[ "$SELFTEST_ROWS" = "1" ] || die "自检数据没入库（期望 1 行，实际 $SELFTEST_ROWS）"

# 顺带验证白名单真的生效：非法模块键不该落库
BAD_KEY="$(PGPASSWORD="$DB_PASSWORD" psql -h 127.0.0.1 -U "$DB_ROLE" -d "$DB_NAME" -tAc \
  "SELECT module_open_counts ? '随便写的' FROM usage_daily WHERE device_id = '$TEST_DEVICE'")"
[ "$BAD_KEY" = "f" ] || die "模块白名单未生效（非法键进了库）"

PGPASSWORD="$DB_PASSWORD" psql -h 127.0.0.1 -U "$DB_ROLE" -d "$DB_NAME" -q -c \
  "DELETE FROM usage_daily WHERE device_id = '$TEST_DEVICE'; DELETE FROM devices WHERE device_id = '$TEST_DEVICE';"

echo ""
echo "=== 完成 ==="
echo "  服务    : systemctl status mw-telemetry   /  journalctl -u mw-telemetry -f"
echo "  本地探活: curl -s http://127.0.0.1:$LISTEN_PORT/healthz"
echo "  配置    : $ENV_FILE  (640 root:$TELEMETRY_USER，含密码)"
echo ""
echo "  管理页凭据："
echo "    用户名: admin"
echo "    密码  : $ADMIN_PASSWORD"
echo "    （本地直连预览： curl -u admin:密码 http://127.0.0.1:$LISTEN_PORT/ ）"
echo ""
echo "⚠️ 还差两步（见 deploy/telemetry/README.md）："
echo "   1. Caddy 加一条路由把统计域名指到 127.0.0.1:$LISTEN_PORT"
echo "   2. Cloudflare 隧道加对应的 Public Hostname"
echo "   3. 发版流水线注入 --dart-define=STATS_BASE_URL=https://<统计域名>"
