#!/usr/bin/env bash
# ============================================================
# monster-word 自动同步脚本（有修改即提交并推送到 GitHub）
#
# 用法：
#   bash scripts/auto_sync.sh ["自定义提交信息"]
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
# ============================================================
set -uo pipefail
cd "$(dirname "$0")/.."

# ---- 0) 前置校验：仓库状态健康 ----
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
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [ -f "$f" ] && [ "$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null)" -gt 94371840 ]; then
    echo "[auto_sync] 错误：$f 超过 90MB，拒绝提交（请确认是否为误加的构建产物）"
    exit 1
  fi
done <<< "$CHANGES"

# ---- 2.5) 格式化（与 CI dart.yml 的 --line-length 120 对齐；formatter.page_width 已写入 analysis_options）----
echo "[auto_sync] dart format ..."
dart format lib/ test/ >/dev/null 2>&1
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

git add lib/ test/ pubspec.yaml pubspec.lock analysis_options.yaml \
  docs/ scripts/ assets/db/ windows/ android/app/ 2>/dev/null

# 防呆：staged 里若混入 dist/build/releases/work/logs 路径，立即中止
if git diff --cached --name-only | grep -qE "^(dist/|build/|releases/|work/|logs/)"; then
  echo "[auto_sync] 错误：staged 中出现构建产物路径，已中止"; exit 1
fi

git commit -m "$MSG" || { echo "[auto_sync] 提交失败（可能无实质变更）"; exit 1; }
echo "[auto_sync] 已提交: $MSG"

# ---- 4) 推送（先拉取对齐，避免非快进失败；绝不 force）----
git pull --rebase origin main --autostash 2>&1 | tail -1
if git push origin main 2>&1 | tail -1; then
  echo "[auto_sync] 已推送到 GitHub origin/main ✓"
else
  echo "[auto_sync] 推送失败，请检查网络/凭据（提交已保留在本地）"
  exit 1
fi
