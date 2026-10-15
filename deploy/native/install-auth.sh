#!/usr/bin/env bash
# 原生部署 Monster Word 认证后端（PostgreSQL + GoTrue）。
#
# 为什么有这个脚本（而不是只用 docker-compose）：
#   实际要部署的那台服务器（阿里云 101.133.235.110）**没装 Docker**，且只有
#   2 vCPU / 1.6 GiB 内存，上面已经跑着 gallery / landing / aionui / authelia /
#   caddy / cloudflared。再叠一层容器运行时在这个内存水位上没有意义。
#   而 GoTrue 本身就是一个静态 Go 二进制，PostgreSQL 用 apt 装即可 —— 原生部署
#   比容器轻，也和这台机器现有的管理方式（systemd / pm2）一致。
#
# 幂等：重复运行只补缺的部分。**已有 .env 里的密钥不会被重置**，数据库不会被清空。
#
# 用法（在服务器上以 root 运行）：
#   bash install-auth.sh --tarball /tmp/auth-v2.197.0-amd64.tar.xz
#   bash install-auth.sh                 # 二进制已装好时只做校验/补缺
#
# 参数：
#   --tarball <path>   GoTrue 发布包（GitHub release 的 auth-v<ver>-amd64.tar.xz）
#   --version <ver>    版本号，默认 v2.197.0（仅用于校验 tarball 名与日志）
#   --domain <host>    对外域名，默认 auth.cloudbear.cloud
#   --port <port>      GoTrue 监听端口，默认 9999（只绑 127.0.0.1）
#
# ⚠️ 本脚本**不改** Caddy 配置。Caddy 路由是独立一步（见 enable-caddy-route.sh），
#    因为那会动到正在服务 aionui.cloudbear.cloud 的生产配置，需要单独备份+校验+复核。

set -euo pipefail

AUTH_DIR=/opt/mw-auth
AUTH_USER=mw-auth
DB_NAME=mwauth
DB_ROLE=supabase_auth_admin
AUTH_VERSION=v2.197.0
AUTH_PORT=9999
AUTH_DOMAIN=auth.cloudbear.cloud
TARBALL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --tarball) TARBALL="$2"; shift 2 ;;
    --version) AUTH_VERSION="$2"; shift 2 ;;
    --domain) AUTH_DOMAIN="$2"; shift 2 ;;
    --port) AUTH_PORT="$2"; shift 2 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "未知参数：$1"; exit 1 ;;
  esac
done

log() { echo "[install-auth] $*"; }
die() { echo "[install-auth] ❌ $*" >&2; exit 1; }

[ "$(id -u)" = "0" ] || die "必须以 root 运行"
command -v systemctl >/dev/null || die "没有 systemd"

# ── 1. PostgreSQL ─────────────────────────────────────────────
if ! command -v psql >/dev/null 2>&1; then
  log "安装 PostgreSQL…"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq postgresql postgresql-contrib
else
  log "PostgreSQL 已安装：$(psql --version)"
fi
systemctl is-active --quiet postgresql || systemctl start postgresql
systemctl is-active --quiet postgresql || die "PostgreSQL 起不来"

# 低内存调优：这台机器总共 1.6 GiB，且已跑着 5 个服务。
# Ubuntu 默认 shared_buffers 已是 128MB，这里只把并发连接数与排序内存收紧，
# 避免 GoTrue 之外的东西连进来把内存吃掉。
# 注意：psql 必须以 postgres 账户跑 —— root 没有同名数据库角色，
# 直连会报 'role "root" does not exist'（首次跑这个脚本时就是这么挂的）。
PG_VER="$(sudo -u postgres psql -tAc 'show server_version' | cut -d. -f1)"
PG_CONF_D="/etc/postgresql/${PG_VER}/main/conf.d"
if [ -d "$PG_CONF_D" ] && [ ! -f "$PG_CONF_D/mw-auth-tuning.conf" ]; then
  log "写入低内存调优 ${PG_CONF_D}/mw-auth-tuning.conf"
  cat > "$PG_CONF_D/mw-auth-tuning.conf" <<'EOF'
# Monster Word 认证后端：为 1.6GiB 内存的小机器收紧资源占用。
# 只有 GoTrue 会连这个实例，连接数不需要很大。
shared_buffers = 128MB
max_connections = 30
work_mem = 4MB
maintenance_work_mem = 32MB
effective_cache_size = 256MB
EOF
  systemctl restart postgresql
fi

# ── 2. 密钥（已存在则沿用，不重置）────────────────────────────
mkdir -p "$AUTH_DIR"
ENV_FILE="$AUTH_DIR/.env"
if [ -f "$ENV_FILE" ]; then
  log ".env 已存在，沿用其中的密钥（不重置）"
  DB_PASSWORD="$(grep -E '^MW_DB_PASSWORD=' "$ENV_FILE" | cut -d= -f2- || true)"
  JWT_SECRET="$(grep -E '^MW_JWT_SECRET=' "$ENV_FILE" | cut -d= -f2- || true)"
  [ -n "$DB_PASSWORD" ] || die ".env 存在但缺 MW_DB_PASSWORD，请人工确认后再跑"
  [ -n "$JWT_SECRET" ] || die ".env 存在但缺 MW_JWT_SECRET，请人工确认后再跑"
else
  # 只取字母数字：数据库密码要拼进 postgres:// URL，含特殊字符就得 URL 编码，
  # 那是最容易被漏掉的一类配置事故。32 位字母数字 ≈ 190 bit，足够。
  DB_PASSWORD="$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | cut -c1-32)"
  # JWT_SECRET 用 hex：96 个十六进制字符，不会有任何转义问题。
  JWT_SECRET="$(openssl rand -hex 48)"
  log "已生成新的数据库密码与 JWT 密钥"
fi

# ── 3. 角色与数据库 ───────────────────────────────────────────
# 用 DO 块做幂等：角色已存在则只改密码（保证与 .env 一致）。
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

# 数据库不存在才建。**已存在则一个字节都不动**（业主明确要求不碰已有数据）。
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
  log "创建数据库 $DB_NAME（owner=$DB_ROLE）"
  sudo -u postgres createdb -O "$DB_ROLE" "$DB_NAME"
else
  log "数据库 $DB_NAME 已存在，保持不动"
fi

# ⚠️ auth schema 必须**我们自己**建。GoTrue 的迁移脚本不会建它：
#   migrations/00_init_auth_schema.up.sql 一上来就是 `CREATE TABLE IF NOT EXISTS auth.users`，
#   库里没有 auth schema 时直接报 `ERROR: schema "auth" does not exist (SQLSTATE 3F000)`
#   并且 migrate 以非 0 退出（serve 起不来）。
#   官方自建栈里这个 schema 是 supabase/postgres 镜像预置的 —— 原生部署没有那层镜像，
#   所以这是最容易漏掉的一步。pgcrypto/uuid-ossp 一并预置，避免后续迁移缺扩展。
log "确保 auth schema 与扩展存在…"
sudo -u postgres psql -v ON_ERROR_STOP=1 -q -d "$DB_NAME" <<EOF
CREATE SCHEMA IF NOT EXISTS auth AUTHORIZATION $DB_ROLE;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
GRANT ALL ON SCHEMA public TO $DB_ROLE;
EOF

# ⚠️ 还必须有 search_path。GoTrue 的 SQL 用的是**不带 schema 前缀**的表名
#   （`users`、`identities` …），完全依赖连接的 search_path 去找 auth schema。
#   不设的话表明明建好了、health 也是 200，但每个业务接口都 500：
#     relation "users" does not exist (SQLSTATE 42P01)
#   官方镜像里这个 search_path 是预置的 —— 原生部署要自己设。
#   作用域限定在 mwauth 库，不影响这台机器上的其它数据库。
log "设置 $DB_ROLE 在 $DB_NAME 上的 search_path…"
sudo -u postgres psql -v ON_ERROR_STOP=1 -q -d "$DB_NAME" \
  -c "ALTER ROLE $DB_ROLE IN DATABASE $DB_NAME SET search_path = auth, public;"

# ── 4. 二进制与迁移 ───────────────────────────────────────────
if [ -n "$TARBALL" ]; then
  [ -f "$TARBALL" ] || die "找不到 tarball：$TARBALL"
  log "从 $TARBALL 安装二进制与迁移…"
  TMP="$(mktemp -d)"
  tar -xJf "$TARBALL" -C "$TMP"
  [ -x "$TMP/auth" ] || die "包里没有 auth 可执行文件"
  [ -d "$TMP/migrations" ] || die "包里没有 migrations 目录（GoTrue 启动时要用它建表）"
  install -m 0755 "$TMP/auth" "$AUTH_DIR/auth"
  # 迁移目录**原子替换**（2026-10-15 审计 R3-S07）：旧顺序是
  # 「先 install 新二进制 → rm -rf 旧 migrations → cp -r 新 migrations」，
  # cp 中途失败（磁盘满、SSH 断开、SIGINT）就留下「新二进制 + 迁移目录缺失/不完整」
  # 且**旧目录已删**⇒ ExecStartPre=auth migrate 失败 ⇒ 认证服务起不来、所有用户无法登录，
  # 而且没有回滚路径。
  # 现在：先复制到临时目录并校验，再用 mv 原子换名；旧目录保留成 .prev 以便回滚。
  rm -rf "$AUTH_DIR/migrations.new"
  cp -r "$TMP/migrations" "$AUTH_DIR/migrations.new"
  [ -d "$AUTH_DIR/migrations.new" ] || die "迁移目录复制失败，未改动现有安装"
  [ -n "$(ls -A "$AUTH_DIR/migrations.new" 2>/dev/null)" ] || die "迁移目录为空，未改动现有安装"
  rm -rf "$AUTH_DIR/migrations.prev"
  if [ -d "$AUTH_DIR/migrations" ]; then
    mv "$AUTH_DIR/migrations" "$AUTH_DIR/migrations.prev"
  fi
  mv "$AUTH_DIR/migrations.new" "$AUTH_DIR/migrations"
  rm -rf "$TMP"
  echo "$AUTH_VERSION" > "$AUTH_DIR/VERSION"
  log "迁移目录已原子替换（旧目录保留在 $AUTH_DIR/migrations.prev，回滚就换回来）"
fi

[ -x "$AUTH_DIR/auth" ] || die "$AUTH_DIR/auth 不存在。首次部署请用 --tarball 指定发布包"
[ -d "$AUTH_DIR/migrations" ] || die "$AUTH_DIR/migrations 不存在（GoTrue 启动时会用它建表）"
log "GoTrue 版本：$(cat "$AUTH_DIR/VERSION" 2>/dev/null || echo unknown)"

# ── 5. 运行账户与 .env ────────────────────────────────────────
# 建一个无登录权限的系统账户跑服务，不用 root 跑一个对外收密码的进程。
if ! id "$AUTH_USER" >/dev/null 2>&1; then
  log "创建系统账户 $AUTH_USER"
  useradd --system --no-create-home --shell /usr/sbin/nologin "$AUTH_USER"
fi

log "写入 $ENV_FILE"
cat > "$ENV_FILE" <<EOF
# Monster Word 认证后端配置（由 deploy/native/install-auth.sh 生成）
# ⚠️ 含密钥，权限 640 root:服务账户（GoTrue 启动时要读它，见 install-auth.sh 注释）。

# ── 监听 ──
# 只绑 127.0.0.1：对外入口是 Caddy → Cloudflare 隧道，GoTrue 不直接暴露。
GOTRUE_API_HOST=127.0.0.1
GOTRUE_API_PORT=$AUTH_PORT

# ── 数据库 ──
GOTRUE_DB_DRIVER=postgres
GOTRUE_DB_DATABASE_URL=postgres://$DB_ROLE:$DB_PASSWORD@127.0.0.1:5432/$DB_NAME
GOTRUE_DB_MIGRATIONS_PATH=$AUTH_DIR/migrations

# ── 对外地址（JWT issuer / 邮件链接用）──
API_EXTERNAL_URL=https://$AUTH_DOMAIN/auth/v1
GOTRUE_JWT_ISSUER=https://$AUTH_DOMAIN/auth/v1
GOTRUE_SITE_URL=https://$AUTH_DOMAIN

# ── 认证方式：只开邮箱口令，其余全关 ──
GOTRUE_EXTERNAL_EMAIL_ENABLED=true
GOTRUE_EXTERNAL_PHONE_ENABLED=false
GOTRUE_EXTERNAL_ANONYMOUS_USERS_ENABLED=false
GOTRUE_DISABLE_SIGNUP=false
GOTRUE_PASSWORD_MIN_LENGTH=6

# ⚠️ 必须是 true。本部署没有邮件服务器。
#   若为 false：注册会变成「200 但没有 access_token」的防枚举假成功（存量用户永远
#   迁不过来），且未确认账号可被他人用 signup 直接接管。详见 docs/auth_server_contract.md §5。
GOTRUE_MAILER_AUTOCONFIRM=true
GOTRUE_SMTP_ADMIN_EMAIL=no-reply@$AUTH_DOMAIN

# ── JWT ──
GOTRUE_JWT_SECRET=$JWT_SECRET
GOTRUE_JWT_EXP=3600
GOTRUE_JWT_AUD=authenticated
GOTRUE_JWT_ADMIN_ROLES=service_role
# 不设 GOTRUE_JWT_DEFAULT_GROUP_NAME：该变量已被上游标记为 deprecated 且
# 「not supported by Supabase's GoTrue」，设了不生效还会在每次启动刷一条 warning。

# ── 限流 ──
# GoTrue 内置按 IP 限流，但需要它知道真实客户端 IP。链路是
# Cloudflare → cloudflared(127.0.0.1) → Caddy(127.0.0.1) → GoTrue，
# 不设这一项时所有请求都算在 127.0.0.1 上，等于限流失效。
GOTRUE_RATE_LIMIT_HEADER=x-forwarded-for

# 供运维脚本读取（GoTrue 本身不认这两个变量）
MW_DB_PASSWORD=$DB_PASSWORD
MW_JWT_SECRET=$JWT_SECRET
MW_AUTH_DOMAIN=$AUTH_DOMAIN
EOF
chmod 640 "$ENV_FILE"
# 必须让服务账户能读：GoTrue 启动时会自己从**工作目录**加载 `.env`
#（godotenv 那套），读不到就 fatal 退出 —— 实测报
#   confload.Startup: ReadFile: open .env: permission denied
# 注意它只对「文件存在但读不了」致命；文件不存在是正常跳过。
# 所以这里给 root:服务账户 + 640：密钥仍不对其他用户开放，但进程读得到。
chown "root:$AUTH_USER" "$ENV_FILE"

# ── 6. systemd ───────────────────────────────────────────────
log "安装 systemd 单元"
cat > /etc/systemd/system/mw-auth.service <<EOF
[Unit]
Description=Monster Word 认证后端（GoTrue）
Documentation=file://$AUTH_DIR/README.md
After=network-online.target postgresql.service
Wants=network-online.target
Requires=postgresql.service
# 配置坏了别无限重启刷日志：60 秒内失败 5 次就停下，人工介入。
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
User=$AUTH_USER
Group=$AUTH_USER
WorkingDirectory=$AUTH_DIR
# 用 EnvironmentFile 而不是在单元里写明文密钥：单元文件是 644，
# 密钥放 .env 才能保持 640 且不进 systemctl show 的输出。
EnvironmentFile=$ENV_FILE
# ⚠️ serve 子命令 **不会**自动跑迁移 —— 实测 v2.197.0 直接 serve 起来后库里一张表都没有
#（health 却是 200，只看健康检查会以为部署成功了）。建表要靠 migrate 子命令。
# 放在 ExecStartPre 而不是安装脚本里跑一次：升级换二进制后会自动补新迁移，不会漏。
# migrate 本身幂等（官方描述：create new tables and add missing columns and indexes）。
# 注意：本段是未加引号的 heredoc，注释里**不能出现反引号**（会被当命令替换执行）。
ExecStartPre=$AUTH_DIR/auth migrate
ExecStart=$AUTH_DIR/auth serve
Restart=on-failure
RestartSec=3
# 收紧权限：GoTrue 只需要读自己的目录和连本机数据库。
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$AUTH_DIR
# 日志进 journald，用 journalctl -u mw-auth 看。

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --quiet mw-auth.service
systemctl restart mw-auth.service

# ── 7. 自检 ──────────────────────────────────────────────────
log "等待 GoTrue 就绪（首次启动会跑迁移建表）…"
OK=0
for i in $(seq 1 30); do
  sleep 2
  if curl -sf -m 3 "http://127.0.0.1:$AUTH_PORT/health" >/dev/null 2>&1; then OK=1; break; fi
done

if [ "$OK" != "1" ]; then
  echo ""
  echo "❌ GoTrue 未在 60 秒内就绪。最近日志："
  journalctl -u mw-auth --no-pager -n 40 || true
  exit 1
fi

log "✅ 健康检查通过：$(curl -s -m 3 "http://127.0.0.1:$AUTH_PORT/health")"

# 建表结果抽查：确认迁移真的跑过了
TABLES="$(sudo -u postgres psql -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema='auth'" "$DB_NAME")"
log "auth 模式下已有 $TABLES 张表"
[ "$TABLES" -gt 5 ] || die "auth 模式表数量异常（$TABLES），迁移可能没跑成功"

echo ""
echo "=== 完成 ==="
echo "  服务    : systemctl status mw-auth   /  journalctl -u mw-auth -f"
echo "  本地探活: curl -s http://127.0.0.1:$AUTH_PORT/health"
echo "  配置    : $ENV_FILE  (640 root:服务账户，含密钥)"
echo ""
echo "⚠️ 还差一步：把 $AUTH_DOMAIN 加进 Cloudflare 隧道。"
echo "   控制台路径：Networks → Tunnels → 选中隧道 → 「已发布应用程序路由」标签"
echo "              → 添加路由 → 已发布应用程序 → 子域 auth / 服务 URL http://localhost:8081"
echo "   ⚠️ 别点「主机名路由」标签 —— 那是需要 WARP 客户端的专用路由，对公网访问不生效。"
echo "   详见 deploy/native/README.md §3。"
