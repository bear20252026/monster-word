# Git 健康检查报告

> 检查日期：2026-08-24
> 仓库路径：`D:\claude\work\cn_com_lange\word_app`
> 检查人：DocReviewer (Monster world)

---

## 一、仓库概览

| 指标 | 数值 |
|------|------|
| 总提交数 | 48 |
| 贡献者数 | 18（团队协作模式） |
| 当前分支 | main |
| 未提交修改 | 4 个文件 |
| 未跟踪文件 | 62 个文件 |

---

## 二、提交历史分析

### 2.1 提交规范

提交信息整体规范，遵循 Conventional Commits 格式：

| 类型 | 数量 | 示例 |
|------|------|------|
| `feat` | ~12 | `feat(widget): add SbCard` |
| `refactor` | ~15 | `refactor(home): apply Starbucks styling` |
| `fix` | ~8 | `fix(data): clean 129 misencoded phonetic chars` |
| `tune` | 1 | `tune(learn): shake convergence + option spacing` |
| `test` | 1 | `test(a11y): add WCAG contrast guard` |

**评价**：提交信息清晰、分类明确，有利于追溯。

### 2.2 贡献者分布

团队采用多 Agent 协作，18 位贡献者各有明确职责（QA、FontScout、DocReviewer、ComponentEngineer 等）。所有提交均使用团队邮箱（`@monsterworld.team`），无匿名提交。

---

## 三、问题发现

### 3.1 严重 — release/ 目录包含构建产物

初始提交（`e88e958`）中包含了完整的 Windows 构建产物：

```
release/原应用词/word_app.exe
release/原应用词/flutter_windows.dll
release/原应用词/sqlite3.dll
release/原应用词/audioplayers_windows_plugin.dll
release/原应用词/dartjni.dll
release/原应用词/data/app.so
release/原应用词/data/flutter_assets/assets/db/wordbook.db.gz
...（共约 15 个二进制文件）
```

**风险**：
- 二进制文件膨胀仓库体积（DLL/EXE 通常数 MB 至数十 MB）
- 构建产物不应入库，应通过 CI/CD 产出
- 包含完整的 wordbook.db.gz 副本

**建议**：从 git 历史中移除 `release/` 目录（`git filter-branch` 或 BFG），并在 `.gitignore` 中添加 `release/`。

### 3.2 中等 — wordbook.db.gz 的 .gitignore 不一致

`.gitignore` 第 26 行声明忽略 `assets/db/wordbook.db.gz`，但该文件已被追踪（`git ls-files` 可见）。`.gitignore` 只对未追踪文件生效——已追踪文件不受影响。

**建议**：若要忽略该文件，需先 `git rm --cached assets/db/wordbook.db.gz`。若需保留追踪（如词库数据需版本化），则从 `.gitignore` 中移除该行以避免混淆。

### 3.3 中等 — 62 个未跟踪文件

`docs/` 目录下有约 55 个未提交的 markdown 文件（各团队 Agent 产出的研究报告），以及 `scripts/` 目录。

**风险**：这些文件仅存在于工作区，未入库保存。若工作区损坏或分支切换，可能丢失。

**建议**：批量提交 docs/ 文件，按功能分批 commit（如 `docs(a11y): add contrast reports`、`docs(design): add token specs` 等）。

### 3.4 低 — 4 个未提交的修改文件

| 文件 | 改动来源 |
|------|----------|
| `docs/qa_baseline.md` | 【重构64】数值统一 |
| `docs/vector_library_design.md` | 【重构64】归档标记 |
| `lib/screens/home_screen.dart` | 其他 Agent 改动 |
| `lib/theme/skin_system.dart` | 其他 Agent 改动 |

**建议**：及时提交，避免与后续改动冲突。

---

## 四、安全检查

### 4.1 敏感信息

| 检查项 | 结果 |
|--------|------|
| .env 文件 | ❌ 未发现 |
| 密钥文件 (.key/.pem/.p12) | ❌ 未发现 |
| Keystore 文件 (.jks/.keystore) | ❌ 未发现 |
| 密码/凭据硬编码 | ❌ 未发现（grep 检查） |
| API 密钥泄露 | ❌ 未发现 |

**评价**：安全状况良好，无敏感信息泄露。

### 4.2 生成文件

`.g.dart`、`.freezed.dart` 等代码生成文件未入库 ✅。

---

## 五、.gitignore 评估

| 项目 | 状态 | 说明 |
|------|------|------|
| Flutter 构建产物 | ✅ | `.dart_tool/`、`build/` 已忽略 |
| IDE 配置 | ✅ | `.idea/`、`.vscode/` 已忽略 |
| Android 产物 | ✅ | `android/.gradle/`、`android/app/build/` |
| iOS 产物 | ✅ | `ios/Pods/` |
| OS 文件 | ✅ | `.DS_Store`、`Thumbs.db` |
| **release/ 构建产物** | ❌ | **未忽略，且已被追踪** |
| ***.db.gz** | ⚠️ | 声明忽略但已被追踪（不一致） |
| **scripts/** | ❌ | 未忽略（可能需要） |

---

## 六、综合评分

| 维度 | 得分 | 说明 |
|------|------|------|
| 提交规范 | 95/100 | Conventional Commits，信息清晰 |
| 安全性 | 95/100 | 无敏感信息泄露 |
| 二进制管理 | 40/100 | release/ 构建产物入库，db.gz 不一致 |
| .gitignore | 70/100 | 覆盖大部分场景，缺 release/ |
| 文件追踪 | 60/100 | 62 个文件未入库，4 个修改未提交 |
| **综合** | **72/100** | 提交质量高，但构建产物和未追踪文件需处理 |

---

## 七、优先修复建议

### P0 — 立即处理

1. **移除 release/ 目录**：从 git 追踪中移除构建产物（`git rm -r --cached release/`），添加到 `.gitignore`。若需清理历史，使用 BFG Repo-Cleaner。
2. **统一 wordbook.db.gz 追踪策略**：决定是保留追踪（版本化词库）还是忽略（通过其他方式分发），消除 .gitignore 不一致。

### P1 — 本周内

3. **批量提交 docs/**：将 55+ 个未提交的文档分批 commit，避免丢失。
4. **提交当前修改**：4 个修改文件需及时入库。

### P2 — 持续改进

5. **添加 scripts/ 到 .gitignore 或正式追踪**：明确 scripts/ 目录的定位。
6. **考虑 Git LFS**：若 wordbook.db.gz 等二进制文件需版本化，建议使用 Git LFS 避免仓库膨胀。
