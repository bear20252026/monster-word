# [XP-FIX-2] 学习/会话域：空词表降级 + async mounted 守卫 + session_exit_guard 安全化

## 任务摘要

修复 XP AUD-2 体检报告中的 P1/P2 问题：4 个会话页空词表优雅降级、async mounted 守卫、SessionExitGuard 裸 pop 安全化。

## 修改文件清单

| # | 文件 | 修改内容 |
|---|------|----------|
| 1 | `lib/pages/dictation_session_page.dart` | 空态页重做（图标+标题+描述+返回首页按钮）；`_next()` 添加 mounted 守卫 |
| 2 | `lib/pages/spell_session_page.dart` | 空态页重做（图标+标题+描述+返回首页按钮） |
| 3 | `lib/pages/sentence_quiz_page.dart` | 空态页重做（图标+标题+描述+返回首页按钮） |
| 4 | `lib/pages/quick_spell_page.dart` | 空态页重做（图标+标题+描述+返回首页按钮）；Timer.periodic `_remaining--` 添加 mounted 守卫 |
| 5 | `lib/widgets/session_exit_guard.dart` | `Navigator.of(context).pop()` → `NavUtils.safePop(context)`；添加 `nav_utils.dart` 导入 |
| 6 | `test/pages/session_empty_and_mounted_test.dart` | **新增** 6 个测试覆盖空词表降级 + SessionExitGuard |

## 逐点变更明细

### 1. dictation_session_page.dart

| 变更 | 文件:行 | 原代码 | 改后 | 原因 |
|------|---------|--------|------|------|
| 空态页重做 | build() 空检查 | 仅文字 "暂无单词" | 图标 + "暂无可听写单词" + 描述 + 返回首页(goHome) | AUD-2 P2-3 |
| mounted 守卫 | `_next():97` | `if (_currentIndex < ...)` | 添加 `if (!mounted) return;` | AUD-2 P1-4 |

### 2. spell_session_page.dart

| 变更 | 文件:行 | 原代码 | 改后 | 原因 |
|------|---------|--------|------|------|
| 空态页重做 | build() 空检查 | 仅文字 "暂无单词" | 图标 + "暂无可拼写单词" + 描述 + 返回首页(goHome) | AUD-2 P2-1 |

### 3. sentence_quiz_page.dart

| 变更 | 文件:行 | 原代码 | 改后 | 原因 |
|------|---------|--------|------|------|
| 空态页重做 | build() 空检查 | AppBar + 仅文字 "暂无可用例句" | 无 AppBar，图标 + "暂无可用例句" + 描述 + 返回首页(goHome) | AUD-2 P2-2 |

### 4. quick_spell_page.dart

| 变更 | 文件:行 | 原代码 | 改后 | 原因 |
|------|---------|--------|------|------|
| 空态页重做 | build() 空检查 | 仅文字 "暂无单词" | 图标 + "暂无可拼写单词" + 描述 + 返回首页(goHome) | AUD-2 P2-4 |
| mounted 守卫 | `_startTimedMode()` Timer.periodic | `setState(() => _remaining--)` 无守卫 | 添加 `else if (mounted)` | AUD-2 P1-5 |

### 5. session_exit_guard.dart

| 变更 | 文件:行 | 原代码 | 改后 | 原因 |
|------|---------|--------|------|------|
| pop 安全化 | L49-51 | `Navigator.of(context).pop()` | `NavUtils.safePop(context)` | AUD-2 |
| 添加导入 | L4 | 无 | `import '../core/router/nav_utils.dart'` | 依赖新增 |

## 质量门禁

| 门禁 | 结果 |
|------|------|
| `flutter analyze` 5 文件 | ✅ No issues found |
| `flutter test` session_empty_and_mounted_test.dart | ✅ 6/6 passed |
| 新增测试文件 | ✅ `test/pages/session_empty_and_mounted_test.dart` |

## 测试覆盖摘要

| 测试 | 验证内容 |
|------|----------|
| DictationSessionPage 空词表渲染 | 空 words → 显示图标 + "暂无可听写单词" + "返回首页"按钮 |
| DictationSessionPage 空词表 goHome | "返回首页"按钮 → goHome 回到根路由 |
| QuickSpellPage 空词表渲染 | 空 words → 显示图标 + "暂无可拼写单词" + "返回首页"按钮 |
| QuickSpellPage 空词表 goHome | "返回首页"按钮 → goHome 回到根路由 |
| SessionExitGuard 对话框 | 系统返回 → 弹出"退出当前练习？"确认对话框 |
| SessionExitGuard safePop | 确认退出 → safePop → 回到根路由 |

## 未修改（保持不动）

- `learning_session_state.dart`：rate 竞态由 lead 已修
- `learn_page.dart` / `review_page.dart`：由 APP-1 负责
- `lib/core/`、`lib/app/`、`lib/theme/`：不在范围内
- 无 git commit / 无全量 flutter test
