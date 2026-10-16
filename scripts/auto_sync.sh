#!/usr/bin/env bash
# ============================================================
# monster-word 自动同步脚本（有修改即提交并推送到 GitHub）
#
# 用法：
#   bash scripts/auto_sync.sh ["自定义提交信息"]
#   bash scripts/auto_sync.sh --direct ["自定义提交信息"]   # 应急：绕过 PR 直推 main
#
# 规范（务必遵守，源于 2026-08-31 事故教训）：
#   1. 只 add 显式路径列表，禁止 git add -A / git add .
#      （.gitignore 一旦失效，-A 会把 500MB+ 安装包塞进仓库）
#   2. dist/ build/ releases/ work/ logs/ 为构建产物，永远不提交
#      （发布渠道是 GitHub Release，由云端 workflow 构建上传）
#   3. 禁止 force push、禁止改动 .gitignore、禁止 rebase 远端历史
#   4. 提交信息格式：
#        自动同步 →  chore(auto): 自动同步 <N> 个文件 — <变更摘要>
#        人工提交 →  <type>(<scope>): <摘要>   （type: feat/fix/refactor/
#                    perf/docs/chore/test，scope 为模块名）
#   5. 推送前必须确认本地领先于 origin/main（防止覆盖他人提交）
#
# 2026-10-16 审计 R3-E03：本脚本原先**直推 main**，这正是「无法开启 main
# 分支保护」的根因 —— 一开保护脚本就当场断掉。现改为走 PR：
#   · 变更推到 `auto-sync/<日期>` 分支，再用 gh 开 PR（同日复用同一分支/PR，
#     幂等，不会叠出一堆 PR）；
#   · CI（analyze-and-test / build-windows）在 PR 上跑，绿了再合并 ⇒ 自动
#     同步这条路径第一次受门禁约束；
#   · 保留 `--direct` 应急出口：CI 挂了/离线时仍能把改动推上去，但它会
#     打印醒目警告，且**在 main 已开保护后会失败**（这是有意的——那时
#     应走 PR 而不是绕过）。
# ============================================================
# 2026-10-15 审计 R3-E07：原来只有 `-uo pipefail`，缺 `-e` ——
# 而下面的每一步都是「防呆/安全校验」，没有 `-e` 意味着中间任何一步失败
# 都只是返回非零、脚本继续往下走，一路 commit + push origin main。
set -euo pipefail
cd "$(dirname "$0")/.."

# ---- 0) 解析参数：--help / --direct / 自定义提交信息 ----
DIRECT_PUSH=0
case "${1:-}" in
  -h|--help)
    cat <<'USAGE'
用法：
  bash scripts/auto_sync.sh ["自定义提交信息"]      # 默认：走 PR（推 auto-sync/<日期> 分支）
  bash scripts/auto_sync.sh --direct [...]          # 应急：绕过 PR 直推 main
  bash scripts/auto_sync.sh --help                  # 显示本帮助

默认路径（走 PR）：
  1) 在 main 上提交本次变更
  2) 推到 auto-sync/<当天日期> 分支（同日多次运行复用同一分支）
  3) 用 gh 开/更新 PR，等 CI 绿了在 GitHub 上合并
  ⚠️ 合并请用 merge commit（本仓惯例，不要 squash）：gh pr merge <n> --merge

应急路径（--direct）：
  直接推 origin/main，跳过 CI 门禁。仅用于 CI 挂掉/离线等需要抢通的场景。
  若 main 已开启分支保护，本路径会失败 —— 那是预期行为，请改用默认路径。

安全校验（两条路径都会执行，失败即中止，不会推送）：
  · 单文件 >90MB 拒绝提交（GitHub 硬限制 100MB）
  · staged 中出现 dist/ build/ releases/ work/ logs/ 路径拒绝
  · staged 中出现 *.jks / *.keystore / android/key.properties 拒绝

守卫测试：bash scripts/test_auto_sync_size_guard.sh
USAGE
    exit 0
    ;;
  --direct)
    DIRECT_PUSH=1
    shift
    ;;
esac

# ---- 0.1) 前置校验：仓库状态健康 ----
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[auto_sync] 错误：不在 git 仓库中"; exit 1
fi
CURRENT_BRANCH="$(git branch --show-current)"
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "[auto_sync] 跳过：当前分支 $CURRENT_BRANCH 不是 main"; exit 0
fi

# ---- 1) 检测变更 ----
CHANGES="$(git status --porcelain -- lib/ test/ pubspec.yaml pubspec.lock \
  analysis_options.yaml docs/ scripts/ assets/db/ windows/ android/app/ \
  2>/dev/null)"
if [ -z "$CHANGES" ]; then
  echo "[auto_sync] 无源码变更，结束"
  exit 0
fi

FILE_COUNT="$(echo "$CHANGES" | wc -l | tr -d ' ')"
echo "[auto_sync] 检测到 $FILE_COUNT 个文件变更："
echo "$CHANGES" | head -10

# ---- 2) 安全校验：绝不提交大文件（>90MB 单文件拦截，GitHub 硬限制 100MB）----
#
# ⚠️ 2026-10-16 仿真时发现**这道防线自建立起一直是空转的**：
# `git status --porcelain` 的每行格式是 `XY <path>`
#（如 `?? lib/big.bin`、` M lib/a.dart`，前两位是状态码 + 一个空格），
# 而原实现直接把**整行**当路径喂给 `[ -f "$f" ]` ⇒ 永远判定「不存在」
# ⇒ 95MB 的新文件能一路提交推送成功。这正是 2026-08-31 事故（500MB+ 安装包）
# 要防的东西，而防线本身是坏的。
# 修法：剥掉前 3 个字符（两个状态位 + 分隔空格）再判。
# 用 `printf '%s'` 而非 echo 以保留可能的前导空格语义（此处路径不含空格，
# 但仍显式去掉状态位才可靠）。
# 单测见本仓 `scripts/test_auto_sync_size_guard.sh`。
while IFS= read -r line; do
  [ -z "$line" ] && continue
  f="${line:3}"                       # 剥掉 "XY " 前缀
  f="${f%\"}"; f="${f#\"}"            # 去掉可能的引号包裹（含特殊字符时 git 会加）
  [ -z "$f" ] && continue
  if [ -f "$f" ]; then
    size="$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null || echo 0)"
    if [ "$size" -gt 94371840 ]; then
      echo "[auto_sync] 错误：$f 约 $((size / 1048576))MB，超过 90MB，拒绝提交"
      echo "[auto_sync] （请确认是否为误加的构建产物；dist/build/releases/work/logs 永不提交）"
      exit 1
    fi
  fi
done <<< "$CHANGES"

# ---- 2.5) 格式化（与 CI dart.yml 的 --line-length 120 对齐；formatter.page_width 已写入 analysis_options）----
#
# ⚠️ 2026-10-16 实测：裸 `dart format` 在**本机**会**挂死**（不是失败，是无限等待）。
# 原因与 memory 里记的 `dart run <file>` 同源：365vpn 让 dartdev 无法创建匿名管道，
# 而裸 `dart` 正是走 dartdev 的启动器。原实现没有超时 ⇒ 整个脚本卡在格式化这一步，
# 既不提交也不报错（本轮真踩：卡了 4 分 55 秒，靠手工杀 dart.exe 才继续）。
#
# 两重防护：
#   ① 优先用 **SDK 内的 dart 二进制**（`.../cache/dart-sdk/bin/dart`）—— 它不经
#      dartdev，本机可用（`dart.exe format --line-length 120` 已被验证可用）；
#   ② 加 `timeout` 兜底，且**失败/超时都不阻断提交** —— 格式化是便利功能，
#      真正的格式门禁在 CI（dart.yml 的 `dart format --set-exit-if-changed`）。
DART_BIN="$(command -v dart 2>/dev/null || true)"
for cand in \
  "${FLUTTER_ROOT:-}/bin/cache/dart-sdk/bin/dart" \
  "${FLUTTER_HOME:-}/bin/cache/dart-sdk/bin/dart" \
  /d/flutter/bin/cache/dart-sdk/bin/dart.exe \
  "$HOME/flutter/bin/cache/dart-sdk/bin/dart" \
  /usr/local/flutter/bin/cache/dart-sdk/bin/dart
do
  if [ -n "$cand" ] && [ -x "$cand" ]; then DART_BIN="$cand"; break; fi
done

# macOS 默认没有 GNU timeout；没有就退回直接调用（CI/Linux 都有）。
TIMEOUT_CMD=""
command -v timeout >/dev/null 2>&1 && TIMEOUT_CMD="timeout 180"

if [ -n "$DART_BIN" ]; then
  echo "[auto_sync] dart format（$DART_BIN）..."
  if ! $TIMEOUT_CMD "$DART_BIN" format lib/ test/ >/dev/null 2>&1; then
    echo "[auto_sync] ⚠️ dart format 未完成或失败 —— 跳过格式化，继续提交（不阻断）"
    echo "[auto_sync]    （本机若因 365vpn 让 dartdev 挂起属已知问题；格式门禁在 CI）"
  fi
else
  echo "[auto_sync] ⚠️ 未找到 dart，跳过格式化（格式门禁在 CI）"
fi
CHANGES="$(git status --porcelain -- lib/ test/ pubspec.yaml pubspec.lock \
  analysis_options.yaml docs/ scripts/ assets/db/ windows/ android/app/ \
  2>/dev/null)"
if [ -z "$CHANGES" ]; then
  echo "[auto_sync] 无源码变更，结束"
  exit 0
fi
FILE_COUNT="$(echo "$CHANGES" | wc -l | tr -d ' ')"

# ---- 3) 提交 ----
if [ $# -ge 1 ] && [ -n "$1" ]; then
  MSG="$1"
else
  SUMMARY="$(echo "$CHANGES" | awk '{print $NF}' | sed 's|.*/||' | sort -u | head -3 | tr '\n' ' ')"
  MSG="chore(auto): 自动同步 ${FILE_COUNT} 个文件 — ${SUMMARY}"
fi

# 审计 I99：android/app/ 内含签名密钥（*.jks）与 key.properties，安全完全
# 依赖 .gitignore 不被改动——这里在脚本层再加一道显式排除，即使 ignore
# 规则被误改也不会把签名身份放进暂存区。
git add lib/ test/ pubspec.yaml pubspec.lock analysis_options.yaml \
  docs/ scripts/ assets/db/ windows/ android/app/ \
  -- ':!android/app/*.jks' ':!android/app/*.keystore' ':!android/app/key.properties' \
  || { echo "[auto_sync] 错误：暂存失败（上面有 git 的原始报错）。此前用 2>/dev/null 把错误吞掉后照样提交，会推上一个部分暂存的提交"; exit 1; }

# 防呆：staged 里若混入 dist/build/releases/work/logs 路径，立即中止
# 断言必须先落盘再 grep（2026-10-15 审计 R3-E07）：`git diff --cached | grep -qE`
# 在 pipefail 下，当输出超过管道缓冲（约 64KB、约千余文件）时 `grep -q` 会提前退出，
# git 收到 SIGPIPE(141) ⇒ 整条管道判非 0 ⇒ **断言恒假放行**。
STAGED="$(mktemp)"
PR_BODY_FILE=""
# ⚠️ 只注册**一个** trap：后面的代码会用到第二个临时文件，
# 于是这里用一个变量统一清理。若在后面再 `trap ... EXIT` 覆盖，容易漏掉
# 前一个文件（POSIX sh 的 EXIT trap 只保留最后一个）。
_cleanup() {
  rm -f "$STAGED"
  [ -n "$PR_BODY_FILE" ] && rm -f "$PR_BODY_FILE"
  return 0
}
trap _cleanup EXIT
git diff --cached --name-only > "$STAGED"

if grep -qE "^(dist/|build/|releases/|work/|logs/)" "$STAGED"; then
  echo "[auto_sync] 错误：staged 中出现构建产物路径，已中止"; exit 1
fi

# 防呆（审计 I99）：staged 中若出现签名密钥/凭证文件，立即中止
if grep -qE '\.(jks|keystore)$|android/key\.properties$' "$STAGED"; then
  echo "[auto_sync] 错误：staged 中出现签名密钥/凭证文件，已中止"; exit 1
fi

git commit -m "$MSG" || { echo "[auto_sync] 提交失败（可能无实质变更）"; exit 1; }
echo "[auto_sync] 已提交: $MSG"

# ---- 4) 推送 ----
#
# R3-E03：默认走 PR。分支名带日期 ⇒ 同一天的多次自动同步**复用同一分支**
#（下面的 `git push` 是快进追加，不是新建），因此不会每天叠出几十个 PR。
SYNC_DATE="$(date +%Y-%m-%d)"
SYNC_BRANCH="auto-sync/${SYNC_DATE}"

if [ "$DIRECT_PUSH" = "1" ]; then
  # ---- 4a) 应急直推 main（--direct）----
  echo "[auto_sync] ⚠️  --direct：绕过 PR 直推 main（应急路径）"
  echo "[auto_sync] ⚠️  若 main 已开分支保护，这一步会被 GitHub 拒绝 —— 那时请改用默认的 PR 路径。"
  git pull --rebase origin main --autostash 2>&1 | tail -1
  if git push origin main 2>&1 | tail -1; then
    echo "[auto_sync] 已推送到 GitHub origin/main ✓"
  else
    echo "[auto_sync] 推送失败，请检查网络/凭据（提交已保留在本地）"
    echo "[auto_sync] 提示：若失败原因是 'protected branch'，说明保护已开，去掉 --direct 即可走 PR。"
    exit 1
  fi
  exit 0
fi

# ---- 4b) 默认：推 auto-sync 分支 + 开/更新 PR ----
# 先对齐远端 main，拿到最新基线（否则 PR 会显示落后、CI 也可能基于旧代码）。
git fetch origin main --quiet
if ! git merge-base --is-ancestor origin/main HEAD; then
  echo "[auto_sync] 本地 main 落后于远端，先 rebase 对齐 ..."
  git pull --rebase origin main --autostash 2>&1 | tail -1
fi

# 分支已存在则切过去复用；否则从当前 main 新建。
if git show-ref --verify --quiet "refs/heads/${SYNC_BRANCH}"; then
  echo "[auto_sync] 复用既有分支 ${SYNC_BRANCH}"
else
  echo "[auto_sync] 新建分支 ${SYNC_BRANCH}"
fi
git checkout -B "${SYNC_BRANCH}" >/dev/null 2>&1

if ! git push -u origin "${SYNC_BRANCH}" 2>&1 | tail -1; then
  echo "[auto_sync] 推送分支失败，请检查网络/凭据（提交已保留在本地 ${SYNC_BRANCH}）"
  exit 1
fi
echo "[auto_sync] 已推送分支 ${SYNC_BRANCH} ✓"

# 回到 main，保持「脚本跑完仍停在 main」这一既有习惯（下一次运行的前置校验
# 要求当前分支是 main）。
git checkout main >/dev/null 2>&1

# 开 PR；已存在则更新 body（幂等）。
if ! command -v gh >/dev/null 2>&1; then
  echo "[auto_sync] ⚠️  未找到 gh CLI，PR 未自动创建。"
  echo "[auto_sync] 请手工开 PR：${SYNC_BRANCH} → main"
  exit 0
fi

EXISTING_PR="$(gh pr list --head "${SYNC_BRANCH}" --state open --json number --jq '.[0].number // empty' 2>/dev/null || true)"
PR_BODY_FILE="$(mktemp)"
{
  echo "本 PR 由 \`scripts/auto_sync.sh\` 自动创建（R3-E03：自动同步改走 PR，好让 CI 门禁生效）。"
  echo
  echo "## 本次包含的提交"
  echo
  echo '```'
  git log --oneline "origin/main..${SYNC_BRANCH}" | head -40
  echo '```'
  echo
  echo "## 合并方式"
  echo
  echo "本仓惯例为 **merge commit**（不要 squash）："
  echo
  echo '```bash'
  echo "gh pr merge <n> --merge"
  echo '```'
} > "$PR_BODY_FILE"

if [ -n "$EXISTING_PR" ]; then
  gh pr edit "$EXISTING_PR" --body-file "$PR_BODY_FILE" >/dev/null 2>&1 || true
  echo "[auto_sync] 已更新既有 PR #${EXISTING_PR} ✓"
else
  if gh pr create --base main --head "${SYNC_BRANCH}" \
      --title "chore(auto): 自动同步 ${SYNC_DATE}" \
      --body-file "$PR_BODY_FILE" >/dev/null 2>&1; then
    echo "[auto_sync] 已创建 PR ✓"
  else
    echo "[auto_sync] ⚠️  PR 创建失败（分支已推上去，可手工开）"
    exit 1
  fi
fi
echo "[auto_sync] 完成。CI 通过后在 GitHub 上合并（--merge）。"
