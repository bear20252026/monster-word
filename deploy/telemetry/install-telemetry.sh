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
# 记录「用户是否显式传了」：没传时优先沿用 .env 里的旧值（见下面的回读）。
LISTEN_PORT_SET=0
DB_NAME_SET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --port) LISTEN_PORT="$2"; LISTEN_PORT_SET=1; shift 2 ;;
    --db) DB_NAME="$2"; DB_NAME_SET=1; shift 2 ;;
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

  # 端口与库名也要回读（2026-10-15 审计 R3-S06）：旧实现只回读密码，
  # 于是「曾用非默认 --port/--db 部署过，之后按 README 裸跑一次」会把它们
  # **改回默认值并重写整个 .env** ⇒ 端口变了 Caddy 上游 502、库名变了管理页
  # 像「数据全丢」，而脚本自带的自检探的是新端口，**仍报绿**。
  if [ "$LISTEN_PORT_SET" = "0" ]; then
    OLD_PORT="$(grep -E '^LISTEN_PORT=' "$ENV_FILE" | cut -d= -f2- || true)"
    if [ -n "$OLD_PORT" ]; then
      LISTEN_PORT="$OLD_PORT"
      log "沿用 .env 里的 LISTEN_PORT=$LISTEN_PORT"
    fi
  fi
  if [ "$DB_NAME_SET" = "0" ]; then
    OLD_DB="$(grep -E '^MW_TELEMETRY_DB=' "$ENV_FILE" | cut -d= -f2- || true)"
    if [ -n "$OLD_DB" ]; then
      DB_NAME="$OLD_DB"
      log "沿用 .env 里的 MW_TELEMETRY_DB=$DB_NAME"
    fi
  fi
else
  # 同认证后端：只取字母数字，避免拼进 URL 时要 URL 编码
  DB_PASSWORD="$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | cut -c1-32)"
  ADMIN_PASSWORD="$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | cut -c1-24)"
  log "已生成数据库密码与管理页密码"
fi

# ── 解析用户名所需的「账号库只读」凭据 ──────────────────────────
#
# 统计库只存 user_id（UUID），用户名在管理页渲染时向账号库解析 ——
# 用户名的权威来源是账号库，在统计库再存一份必然漂移。
#
# ⚠️ 2026-10-16 审计 P1-4：这里**原先**是从 `/opt/mw-auth/.env` 抄来 JWT 签名密钥
#（`MW_JWT_SECRET`），让统计服务自签 `service_role` 令牌去调 `/admin/users`。
# 那等于把「整个账号库的写权限」（改任意人密码、删账号）交给本机**唯一对公网
# 无鉴权收输入**的进程 —— 而它只需要显示一个用户名。
#
# 现在改为**列级只读角色**：`mw_auth_reader` 只被授予
# `SELECT (id, email, raw_user_meta_data) ON auth.users`，
# 拿不到 `encrypted_password` 与各种 token 列，也无法写入任何东西。
# 于是统计服务**不再持有任何能签发管理令牌的密钥**。
#
# 密码在这里生成一次，之后从 .env 回读（幂等，不重置）。
AUTH_DB_NAME=mwauth
AUTH_READER_ROLE=mw_auth_reader
AUTH_READER_PASSWORD=""
if [ -f "$ENV_FILE" ]; then
  AUTH_READER_PASSWORD="$(grep -E '^AUTH_PG_PASSWORD=' "$ENV_FILE" | cut -d= -f2- || true)"
fi
if [ -z "$AUTH_READER_PASSWORD" ]; then
  AUTH_READER_PASSWORD="$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | cut -c1-32)"
  log "已生成账号库只读角色 $AUTH_READER_ROLE 的密码"
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

# ── 1.5) 账号库的只读角色（2026-10-16 审计 P1-4）────────────────
#
# 管理页要把 user_id 显示成用户名，而用户名在账号库的
# `auth.users.raw_user_meta_data ->> 'username'`。
# 这里只授予**两列**的 SELECT：
#   · 拿不到 `encrypted_password` / `confirmation_token` / `recovery_token` 等敏感列；
#   · 无法 INSERT/UPDATE/DELETE 任何东西。
# ⚠️ email 列也授权，但它是 `u<SHA256前24位>@内部域名` 的**哈希派生地址**
#（客户端为兼容中文/空格用户名而设计），认不出是谁 —— 真实用户名在
# `raw_user_meta_data.username`。服务端取名字时用的是后者。
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$AUTH_DB_NAME'" | grep -q 1; then
  if sudo -u postgres psql -tAc "SELECT to_regclass('auth.users') IS NOT NULL" -d "$AUTH_DB_NAME" | grep -q t; then
    log "配置账号库只读角色 $AUTH_READER_ROLE…"
    sudo -u postgres psql -v ON_ERROR_STOP=1 -q <<EOF
DO \$\$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$AUTH_READER_ROLE') THEN
    ALTER ROLE $AUTH_READER_ROLE WITH LOGIN PASSWORD '$AUTH_READER_PASSWORD';
  ELSE
    CREATE ROLE $AUTH_READER_ROLE WITH LOGIN PASSWORD '$AUTH_READER_PASSWORD';
  END IF;
END
\$\$;
EOF
    # 先收回全部再逐项授予：保证**重复运行也不会累积权限**（幂等且收敛到最小集）。
    sudo -u postgres psql -v ON_ERROR_STOP=1 -q -d "$AUTH_DB_NAME" <<EOF
REVOKE ALL ON SCHEMA auth FROM $AUTH_READER_ROLE;
GRANT CONNECT ON DATABASE $AUTH_DB_NAME TO $AUTH_READER_ROLE;
GRANT USAGE ON SCHEMA auth TO $AUTH_READER_ROLE;
GRANT SELECT (id, email, raw_user_meta_data) ON auth.users TO $AUTH_READER_ROLE;
EOF
  else
    log "⚠️ 账号库 $AUTH_DB_NAME 里没有 auth.users 表 —— 管理页将显示账号标识而非用户名"
    log "   （GoTrue 的迁移还没跑？先确认认证后端部署完成）"
  fi
else
  # 不是致命错误：管理页会退化成显示账号标识前 8 位，其余功能不受影响。
  log "⚠️ 账号库 $AUTH_DB_NAME 不存在 —— 管理页将显示账号标识而非用户名"
  log "   （先把认证后端装好：deploy/native/install-auth.sh）"
fi

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
# systemd 单元里 Documentation=file://$TELEMETRY_DIR/README.md 指向这个文件；
# 不装的话 `systemctl status` 里的文档链接是死链（2026-10-15 审计 R3-S14）。
if [ -f "$SRC_DIR/README.md" ]; then
  install -m 0644 "$SRC_DIR/README.md" "$TELEMETRY_DIR/README.md"
else
  log "⚠️ 未找到 README.md，systemd 的 Documentation 链接会是死链"
fi

log "写入 $ENV_FILE"
cat > "$ENV_FILE" <<EOF
# Monster Word 使用统计服务配置（由 deploy/telemetry/install-telemetry.sh 生成）
# ⚠️ 含密码，权限 640 root:服务账户。不要进仓库、不要贴聊天记录。

PG_DB=$DB_NAME
PG_HOST=127.0.0.1
# 必须显式给角色与密码：服务以系统账户 mw-telemetry 运行，没有同名数据库角色，
# 靠 Unix socket 对等认证会报 role "mw-telemetry" does not exist。
PG_USER=$DB_ROLE
PG_PASSWORD=$DB_PASSWORD
LISTEN_PORT=$LISTEN_PORT
# Caddy 反代过来，客户端真实 IP 在 X-Forwarded-For 里 —— 不开这个限流会退化成
# 「所有请求都算 127.0.0.1 一个来源」，等于限流失效。
TRUST_PROXY=1

ADMIN_USER=admin
ADMIN_PASSWORD=$ADMIN_PASSWORD

# 账号库只读连接（P1-4）：管理页把 user_id 解析成用户名时用。
# 该角色只被授予 auth.users 的 (id, email, raw_user_meta_data) 三列 SELECT —— 无写权限。
# 留空则该功能降级为显示账号标识前 8 位，不影响上报与入库。
AUTH_PG_DB=$AUTH_DB_NAME
AUTH_PG_USER=$AUTH_READER_ROLE
AUTH_PG_PASSWORD=$AUTH_READER_PASSWORD

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

# 清理挂在 EXIT 上（2026-10-15 审计 R3-S13）：旧实现把 DELETE 放在最后一步，
# 中途任一 die 都会把 __selftest__ 设备与 selftest-user-1 台账**永久留在生产统计库**，
# 管理页出现假设备/假用户。现在无论怎么退出都会清。
cleanup_selftest() {
  PGPASSWORD="$DB_PASSWORD" psql -h 127.0.0.1 -U "$DB_ROLE" -d "$DB_NAME" -q -c \
    "DELETE FROM usage_daily WHERE device_id = '$TEST_DEVICE';
     DELETE FROM devices WHERE device_id = '$TEST_DEVICE';
     DELETE FROM telemetry_users WHERE user_id = 'selftest-user-1';" >/dev/null 2>&1 || true
}
trap cleanup_selftest EXIT

# 日期用「昨天」而不是写死的常量：入库函数现在会拒绝 400 天前的日期，
# 写死日期会让这个自检变成定时炸弹（审计 R3-S10）。
SELFTEST_DAY="$(date -d yesterday +%F)"
curl -sf -m 10 -X POST "http://127.0.0.1:$LISTEN_PORT/v1/report" \
  -H 'Content-Type: application/json' \
  -d "{\"schema_version\":2,\"device_id\":\"$TEST_DEVICE\",\"user_id\":\"11111111-2222-4333-8444-555555555555\",\"app_version\":\"0.0.0\",\"app_build\":0,\"platform\":\"selftest\",\"os_version\":\"\",\"locale\":\"\",\"days\":[{\"day\":\"$SELFTEST_DAY\",\"foreground_ms\":60000,\"session_count\":1,\"module_open_counts\":{\"learn\":1,\"随便写的\":9}}]}" \
  > /dev/null || die "上报自检失败（见 journalctl -u mw-telemetry）"

SELFTEST_ROWS="$(PGPASSWORD="$DB_PASSWORD" psql -h 127.0.0.1 -U "$DB_ROLE" -d "$DB_NAME" -tAc \
  "SELECT count(*) FROM usage_daily WHERE device_id = '$TEST_DEVICE'")"
[ "$SELFTEST_ROWS" = "1" ] || die "自检数据没入库（期望 1 行，实际 $SELFTEST_ROWS）"

# 顺带验证账号关联真的入库了
SELFTEST_USER="$(PGPASSWORD="$DB_PASSWORD" psql -h 127.0.0.1 -U "$DB_ROLE" -d "$DB_NAME" -tAc   "SELECT user_id FROM usage_daily WHERE device_id = '$TEST_DEVICE'")"
[ "$SELFTEST_USER" = "11111111-2222-4333-8444-555555555555" ] || die "user_id 没入库（期望合成 UUID，实际 '$SELFTEST_USER'）"

# 顺带验证白名单真的生效：非法模块键不该落库
BAD_KEY="$(PGPASSWORD="$DB_PASSWORD" psql -h 127.0.0.1 -U "$DB_ROLE" -d "$DB_NAME" -tAc \
  "SELECT module_open_counts ? '随便写的' FROM usage_daily WHERE device_id = '$TEST_DEVICE'")"
[ "$BAD_KEY" = "f" ] || die "模块白名单未生效（非法键进了库）"

# 清理由 trap 负责（上面已注册），这里不再手写 DELETE。

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
