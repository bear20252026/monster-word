# 文件提交与同步规范

> 2026-08-31 制定。源于当日 git 对象库损坏 + `.gitignore` 编码损坏导致 500MB 产物险些入库的事故复盘。

## 一、自动同步机制

- **脚本**：`scripts/auto_sync.sh` —— 检测源码变更 → 显式 add → commit → push
- **定时执行**：WorkBuddy 自动化「monster-word 自动提交推送（每小时）」每小时运行一次
- **手动执行**：`bash scripts/auto_sync.sh ["自定义提交信息"]`
- 无变更时脚本静默退出；有变更自动以 `chore(auto): 自动同步 N 个文件 — <摘要>` 提交

## 二、铁律（违反会造成事故）

| # | 规则 | 原因 |
|---|---|---|
| 1 | 只 add 显式路径列表（`lib/ test/ pubspec.yaml pubspec.lock analysis_options.yaml docs/ scripts/ assets/db/ windows/ android/app/`），**禁止 `git add -A` / `git add .`** | 2026-08-31 `.gitignore` 编码损坏时，`-A` 险些把 1.5GB 安装包提交（aab 104MB 超 GitHub 100MB 限制才被拦截） |
| 2 | 构建产物（`dist/ build/ releases/ work/ logs/`）**永远不进 git**，发布走 GitHub Release 云端构建 | 仓库体积 / 拉取速度 / CI 效率 |
| 3 | **禁止 force push**、禁止 rebase 已推送历史 | 覆盖远端 = 丢工作 |
| 4 | 单文件 >90MB 拒绝提交（脚本已内置拦截） | GitHub 硬限制 100MB |
| 5 | python 写文件必须显式 `encoding='utf-8'` | 曾致 `.gitignore` 变 UTF-16 化失效 |
| 6 | 本地 git 异常先 `git fsck`；对象损坏时最快恢复路径 = `fetch` 远端 + 重建本地 | 2026-08-31 对象库损坏复盘 |

## 三、提交信息格式

```
<type>(<scope>): <摘要>

<正文：动机与要点，面向未来读者解释"为什么">
```

- **type**：`feat` 功能 / `fix` 修复 / `refactor` 重构 / `perf` 性能 / `docs` 文档 / `chore` 杂务 / `test` 测试
- **scope**：模块名（learning / book / audio / wordbook / di / arch / release …）
- **摘要**：一行 ≤50 字，祈使句
- 版本发布：`chore(release): vX.Y.Z+build — 摘要`，tag 指向该 commit

## 四、版本发布流程（人工触发）

1. 确认 `flutter analyze` 0 issue、`flutter test` 全过
2. `pubspec.yaml` 升版本 → commit `chore(release): vX.Y.Z+N`
3. `git tag vX.Y.Z && git push origin vX.Y.Z` → 云端 workflow 自动构建并上传 Release
4. `dist/` 下载产物核对文件名版本与 pubspec 一致

## 五、自动化行为边界

- 自动化只做：同步、提交、推送，以及报告结果
- 自动化不做：force push、删文件、改 `.gitignore`、改脚本自身、rebase
- 推送失败（网络/凭据）时提交保留在本地，等待下次自动重试
