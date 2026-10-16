# 文件提交与同步规范

> 2026-08-31 制定。源于当日 git 对象库损坏 + `.gitignore` 编码损坏导致 500MB 产物险些入库的事故复盘。
> 2026-10-16 更新「自动同步」一节（R3-E03 改走 PR）与第 4 条铁律的现状说明。

## 一、自动同步机制

- **脚本**：`scripts/auto_sync.sh` —— 检测源码变更 → 显式 add → commit → 推 `auto-sync/<日期>` 分支 → 开/更新 PR
- **手动执行**：`bash scripts/auto_sync.sh ["自定义提交信息"]`
- **应急直推**：`bash scripts/auto_sync.sh --direct [...]`（跳过 PR 直推 main；main 开分支保护后会失败，这是有意的）
- 无变更时脚本静默退出；有变更自动以 `chore(auto): 自动同步 N 个文件 — <摘要>` 提交

### 为什么改走 PR（2026-10-16，审计 R3-E03）
原先脚本**直推 main**，而这正是「无法开启 main 分支保护」的根因 —— 一开保护脚本就当场断掉。
现在改成：变更推到 `auto-sync/<日期>` 分支 → 用 `gh` 开 PR → CI 在 PR 上跑 → 绿了再合并。
于是**自动同步这条路径第一次受门禁约束**（此前它绕过 CI 直接进 main）。

- **同日幂等**：同一天的多次运行复用同一分支与 PR（走 `gh pr edit`），不会叠出一堆 PR。
- **合并方式**：本仓惯例是 **merge commit**（非 squash）—— `gh pr merge <n> --merge`。
- **合并前请确认 CI 绿**：`gh pr checks <n>`。

> ⚠️ 若把本脚本挂到**定时任务**上，请知悉它现在会产生 PR（需要有人定期合并），
> 而不是像以前那样静默直推。不希望产生待合并 PR 时，请用 `--direct`（前提是 main 未开保护）。

## 二、铁律（违反会造成事故）

| # | 规则 | 原因 |
|---|---|---|
| 1 | 只 add 显式路径列表（`lib/ test/ pubspec.yaml pubspec.lock analysis_options.yaml docs/ scripts/ assets/db/ windows/ android/app/`），**禁止 `git add -A` / `git add .`** | 2026-08-31 `.gitignore` 编码损坏时，`-A` 险些把 1.5GB 安装包提交（aab 104MB 超 GitHub 100MB 限制才被拦截） |
| 2 | 构建产物（`dist/ build/ releases/ work/ logs/`）**永远不进 git**，发布走 GitHub Release 云端构建 | 仓库体积 / 拉取速度 / CI 效率 |
| 3 | **禁止 force push**、禁止 rebase 已推送历史 | 覆盖远端 = 丢工作 |
| 4 | 单文件 >90MB 拒绝提交 | GitHub 硬限制 100MB。⚠️ 该拦截在 2026-10-16 前**一直是空转的**（详见下方注） |
| 5 | python 写文件必须显式 `encoding='utf-8'` | 曾致 `.gitignore` 变 UTF-16 化失效 |
| 6 | 本地 git 异常先 `git fsck`；对象损坏时最快恢复路径 = `fetch` 远端 + 重建本地 | 2026-08-31 对象库损坏复盘 |

> **关于第 4 条（2026-10-16 实证）**：原先文档写「脚本已内置拦截」，但用临时仓库真跑后发现
> **这道防线自建立以来从未生效过** —— 脚本把 `git status --porcelain` 的**整行**
>（格式 `XY <path>`，含状态位与分隔空格）当作路径喂给 `[ -f "$f" ]`，于是恒判「文件不存在」，
> 95MB 的新文件能一路 commit + push 成功。
> 已修（剥掉前 3 个字符再判）并立守卫 `scripts/test_auto_sync_size_guard.sh`（7 断言，
> 已在 CI 里跑）。这条的教训是通用的：**「配了拦截」不等于「拦截会触发」，必须真跑一次
> 带违规样本的输入来证明它变红。**

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
