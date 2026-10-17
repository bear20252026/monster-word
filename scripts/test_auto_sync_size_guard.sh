#!/usr/bin/env bash
# ============================================================
# auto_sync.sh 的「大文件拦截」与「签名密钥拦截」守卫测试。
#
# 为什么需要它（2026-10-16 审计跟进）：
#   `auto_sync.sh` 第 2 步的 90MB 大文件拦截，自 2026-08-31 事故后建立以来
#   **一直是空转的** —— 它把 `git status --porcelain` 的**整行**
#   （格式为 `XY <path>`，含状态位与分隔空格）当作路径喂给 `[ -f "$f" ]`，
#   于是永远判定「文件不存在」，95MB 的新文件能一路 commit + push 成功。
#   而这道防线正是为了防「500MB+ 安装包塞进仓库」那类事故。
#
#   本测试在**临时仓库**里真跑脚本（而不是只做语法检查），
#   分别注入「大文件」「签名密钥」「构建产物」三种输入，断言脚本必须中止。
#
# 用法：bash scripts/test_auto_sync_size_guard.sh
# 退出码：0 = 全部通过；1 = 有断言失败
# ============================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIM_DIR="$(mktemp -d)"
trap 'rm -rf "$SIM_DIR"' EXIT

PASS=0
FAIL=0

ok()   { echo "  ✅ $1"; PASS=$((PASS + 1)); }
bad()  { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }

# ---- 搭一个最小仓库：脚本引用的路径都要存在，否则它会因 pathspec 报错而早退 ----
echo "[setup] 构建临时仓库 $SIM_DIR"
mkdir -p "$SIM_DIR/origin" "$SIM_DIR/repo/scripts"
git init --bare -q "$SIM_DIR/origin"

cd "$SIM_DIR/repo"
git init -q
git config user.email "guard@test"
git config user.name "guard"

mkdir -p lib test integration_test docs assets/db windows android/app
echo "base" > lib/a.dart
echo "t"    > test/t.dart
touch pubspec.yaml pubspec.lock analysis_options.yaml
cp "$REPO_ROOT/scripts/auto_sync.sh" scripts/auto_sync.sh
chmod +x scripts/auto_sync.sh

git add -A
git commit -qm "init"
git branch -M main
git remote add origin "$SIM_DIR/origin"
git push -qu origin main >/dev/null 2>&1

# ---- 桩掉 gh 与 dart，让脚本不依赖网络与 Flutter SDK ----
mkdir -p "$SIM_DIR/bin"
cat > "$SIM_DIR/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "pr list")   echo "" ;;
  "pr create") echo "created" ;;
  "pr edit")   echo "edited" ;;
esac
exit 0
STUB
cat > "$SIM_DIR/bin/dart" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$SIM_DIR/bin/gh" "$SIM_DIR/bin/dart"
export PATH="$SIM_DIR/bin:$PATH"

# ---- 辅助：跑一次脚本，捕获退出码与输出 ----
run_sync() {
  set +e
  OUT="$(bash scripts/auto_sync.sh 2>&1)"
  RC=$?
  set -e
}

reset_repo() {
  git reset -q >/dev/null 2>&1 || true
  rm -f android/app/*.jks lib/*.bin 2>/dev/null || true
  git checkout -q -- . >/dev/null 2>&1 || true
  rm -rf build dist releases work logs 2>/dev/null || true
}

echo ""
echo "[1/4] 大文件（95MB 未跟踪）必须被拦截 —— 这条曾长期空转"
head -c 95000000 /dev/zero > lib/big.bin
run_sync
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "超过 90MB"; then
  ok "已拦截并给出尺寸提示（退出码 $RC）"
else
  bad "未被拦截！退出码=$RC；输出尾部：$(echo "$OUT" | tail -2 | tr '\n' ' ')"
fi
# 反向断言：绝不能已推送
if git ls-remote --exit-code origin "refs/heads/auto-sync/*" >/dev/null 2>&1; then
  bad "拦截后仍有 auto-sync 分支被推送 —— 说明校验发生在提交之后"
else
  ok "拦截发生在推送之前（远端无 auto-sync 分支）"
fi
reset_repo

echo ""
echo "[2/4] 签名密钥（.jks）必须被拦截"
echo "FAKE" > android/app/release.jks
git add -f android/app/release.jks >/dev/null 2>&1
run_sync
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "签名密钥"; then
  ok "已拦截签名密钥（退出码 $RC）"
else
  bad "签名密钥未被拦截！退出码=$RC"
fi
reset_repo

echo ""
echo "[3/4] 正常变更必须走通「推分支 + 开 PR」，且 origin/main 不被触碰"
echo "changed" >> lib/a.dart
MAIN_BEFORE="$(git rev-parse origin/main)"
run_sync
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "已创建 PR"; then
  ok "正常路径成功"
else
  bad "正常路径失败！退出码=$RC；输出：$(echo "$OUT" | tail -3 | tr '\n' ' ')"
fi
if [ "$(git rev-parse origin/main)" = "$MAIN_BEFORE" ]; then
  ok "origin/main 未被直推（这是开启分支保护的前提）"
else
  bad "origin/main 被直推了 —— R3-E03 修复失效"
fi
if [ "$(git branch --show-current)" = "main" ]; then
  ok "脚本结束后仍停在 main（下一次运行的前置校验依赖这点）"
else
  bad "脚本结束后停在 $(git branch --show-current)，不是 main"
fi
reset_repo

echo ""
echo "[4/4] 同日二次运行必须复用分支与 PR（不得叠出多个 PR）"
echo "again" >> lib/a.dart
run_sync
BRANCH_COUNT="$(git ls-remote --heads origin 'refs/heads/auto-sync/*' 2>/dev/null | wc -l | tr -d ' ')"
if [ "$BRANCH_COUNT" = "1" ]; then
  ok "仍只有 1 个 auto-sync 分支"
else
  bad "出现了 $BRANCH_COUNT 个 auto-sync 分支（同日应复用）"
fi
reset_repo

echo ""
echo "============================================"
echo "通过 $PASS 项，失败 $FAIL 项"
echo "============================================"
[ "$FAIL" -eq 0 ] || exit 1
