-- 把 GoTrue 连接用的角色密码对齐到 .env 里的 POSTGRES_PASSWORD。
--
-- 为什么需要：supabase/postgres 镜像预置了 supabase_auth_admin 角色（不需要我们创建），
-- 但它的初始密码是镜像内置值。GoTrue 用 GOTRUE_DB_DATABASE_URL 里的密码连库，
-- 两者必须一致。
--
-- 为什么不让 GoTrue 直接用 postgres 超级用户：那样认证服务就有了删库权限，
-- 一旦 GoTrue 出现漏洞，影响面从「auth 模式」扩大到「整个库」。用最小权限角色
-- 是官方自建栈的做法。
--
-- ⚠️ 本文件只在**数据目录为空**（首次启动）时被 postgres 入口脚本执行一次。
--    之后修改 .env 里的 POSTGRES_PASSWORD 不会自动同步，需要手动执行：
--      docker compose exec db psql -U postgres -c "ALTER USER supabase_auth_admin WITH PASSWORD '新密码';"
--    并同步改 .env 后 docker compose up -d auth。
\set pgpass `echo "$POSTGRES_PASSWORD"`

ALTER USER supabase_auth_admin WITH PASSWORD :'pgpass';
