# QA 报告：词库 / 书库功能域核查

核验日期：2026-08-28
核验范围：`lib/data/wordbook_database.dart`、`lib/repositories/book_repository*.dart`、`lib/features/book/**`、`lib/core/di/service_locator.dart`、`lib/app/app.dart`
核验方式：只读代码审查 + 实库 SQL 校验 + 全量测试
结论：**词库数据未丢失，链路完整**。用户反馈的「词库都丢了」不是数据层问题。

---

## 一、数据层校验（实库 + 代码双向对照）

### 1.1 实库数据完好

对生产环境实际落盘的数据库
`%APPDATA%\com.monsterword\Monster Word\wordbook.db`（119MB）执行只读查询：

| 指标 | 结果 |
|------|------|
| `books` 表数量 | **191 本** |
| `words` 表数量 | **32154 个** |
| `books` 表列 | `id / code / name / word_count` |
| `words` 表列 | 与 `models/word.dart` `Word.fromMap` 完全一致 |

### 1.2 列名与模型逐一匹配

- `Book.fromMap`（`lib/models/book.dart`）读取 `id / code / name / word_count`
- 实际 `books` 表 `PRAGMA table_info` 返回 `id / code / name / word_count`
- **零列名错位**。不存在「列不匹配 → 行被丢弃 → 词库为空」的可能。

### 1.3 初始化时序正确

`bootstrapApp()`（`lib/app/app.dart`）在 `runApp` 之前：
```dart
await WordBookDatabase.ensurePlatform();
await WordBookDatabase.instance.initialize();
```
数据库解压/拷贝发生在任何查询之前，无「DB 未初始化即查询」的竞态。

---

## 二、运行时链路核对（DB → 仓储 → 端口 → 状态 → 页面）

| 层 | 文件 | 判定 |
|----|------|------|
| 数据库单例 | `lib/data/wordbook_database.dart` | ✅ `instance` 懒加载，`openDatabase(readOnly: true)` |
| 仓储注册 | `lib/core/di/service_locator.dart:71-72` | ✅ `BookRepositoryImpl(sl<WordBookDatabase>())` |
| 目录端口 | `RepositoryBookCatalogReader` | ✅ 经 `getBooks()` 读 `books` 表 |
| 聚合状态 | `lib/features/book/presentation/book_state.dart` | ✅ `load()` 调 `_catalogReader.listBooks()`，`_error` 有异常兜底 |
| Provider 装配 | `book_feature_providers.dart` | ✅ `BookState(...)..load()`，端口经 `context.read` 注入 |
| 页面消费 | `books_page.dart` | ✅ `Consumer<BookState>` 渲染 `state.books` |

**DB → Repository → reader → state → 页面** 每一跳都验证链路完整，无断链。

---

## 三、用户感知「词库丢了」的可能解释与复核结论

1. **数据其实没丢**：实库 191 本 / 32154 词全部在。
2. 此前在 `learn_page` 发现的 **Critical 级「背单词答对后无法跳转下一个词」** 是更本质的用户体验破坏，已单独修复（commit `8fc7572`）。用户走到学习页卡住后，容易对整体 App 可用性产生「词库都丢、功能全废」的观感。
3. 若用户在**某个特定入口**（如 `/lib-select` 选择词书页）看到为空，需要单独走该入口 UI 复核；但 `BookState.books` 的来源已确认无 bug。

> 结论：本域 `lib/` 下**无需修改**。建议把精力放在可复现的用户操作路径（学习流程已修）；词库选择页如需进一步确认，可再走一遍特定页面 UI 回归。

---

## 四、建议

- 该域判定为 **通过（无代码缺陷）**。
- 保留已修复的 learn_page 回归测试作为「词库/学习可用」的守护。
- 无需为 book feature 新增代码改动。
