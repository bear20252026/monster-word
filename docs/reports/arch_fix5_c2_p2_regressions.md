# ARCH-FIX-5 / C2-P2 前置：P1 回归 error 精确清单

> 触发：P2 Step 2 全量门禁基线，`flutter analyze` 报 **9 error**。
> 根因：P1 并行迁移把 learning 会话页改为**无参构造 + 端口注入**（从 `LearningSessionState.queue` 读词表），但两个**P1 期间未授权修改的调用方**没同步：
> 1. `lib/core/router/learning_routes.dart`（P1 禁止动的核心路由）
> 2. `test/pages/session_empty_and_mounted_test.dart`（P1 禁全量测试，故漏跑）

## 精确 error 清单（flutter analyze，9 个）

| # | 位置 | 错误 |
|---|---|---|
| 1 | `lib/core/router/learning_routes.dart:99:45` | `int` 不能赋给 `String`（ExtensiveModelSelectPage.bookId 现为 String） |
| 2 | `lib/core/router/learning_routes.dart:126:33` | named param `words` 未定义（DictationSessionPage 无参构造） |
| 3 | `lib/core/router/learning_routes.dart:126:47` | named param `bookName` 未定义 |
| 4 | `lib/core/router/learning_routes.dart:135:27` | named param `words` 未定义（QuickSpellPage 无参构造） |
| 5 | `lib/core/router/learning_routes.dart:135:41` | named param `bookName` 未定义 |
| 6 | `test/pages/session_empty_and_mounted_test.dart:19:39` | `words` 未定义（DictationSessionPage） |
| 7 | `test/pages/session_empty_and_mounted_test.dart:43:39` | `words` 未定义 |
| 8 | `test/pages/session_empty_and_mounted_test.dart:66:33` | `words` 未定义（QuickSpellPage） |
| 9 | `test/pages/session_empty_and_mounted_test.dart:90:33` | `words` 未定义 |

## 修复方案（P2 执行）

### A. `lib/core/router/learning_routes.dart`
- **:99** `ExtensiveModelSelectPage(bookId: bookId, bookName: ...)` → `bookId` 传 `String`：
  `bookId: map['bookId'] as String? ?? ''`（原为 `(map['bookId'] as num?)?.toInt()`）。注意 `ExtensiveModelSelectPage` 现位于 `features/book/`，learning_routes 对其 import 属跨 feature，P2 需一并解决（见下）。
- **:126** `DictationSessionPage(words: words, bookName: ...)` → `DictationSessionPage()`（无参）。`_buildDictationSessionPage` 的 `words` 解析与整个方法可删除，直接 return `const DictationSessionPage()`。
- **:135** `QuickSpellPage(words: words, bookName: ...)` → `QuickSpellPage()`（无参）。`_buildQuickSpellPage` 同理。

### B. `test/pages/session_empty_and_mounted_test.dart`
- **:19, :43** `DictationSessionPage(words: const [])` → `const DictationSessionPage()`。
- **:66, :90** `QuickSpellPage(words: const [])` → `const QuickSpellPage()`。
- ⚠️ 空态降级测试仍有效：页面从 `LearningSessionState.queue`（空）读取即空态，测试需注入**空队列的 LearningSessionState**。若直接无参构造会因缺失 Provider 报错，P2 时按 feature 现有测试范式注入 `Provider<LearningSessionState>`。

### C. 跨 feature import 隐患（P2 一并处理）
- `learning_routes.dart:5-24` 仍 `import '../../pages/*.dart'`（走 shim）。P2 应改为 import feature 真源。
- `ExtensiveModelSelectPage`（features/book）里 `import '../../learning/presentation/listening_player_page.dart'` —— **book→learning 跨 feature**，违反 R4，P2 需解耦（端口 or 迁共享）。
- `features/learning/presentation/list_words_page.dart` 归属：P1d 放 book，但被 learning 5 页使用 → P2 挪到 learning（lead 已决策）。

## 状态
- 以上均为 P2 范围（改 `lib/core/router/**`、更新测试、删 shim、repoint）。
- P1 期间禁跑全量门禁，故这些回归未被发现。P2 Step 2 基线 `flutter analyze` 已捕捉。
- 修复后重跑全量 `flutter analyze` + `flutter test` + `import_guard_test` 确认全绿。
