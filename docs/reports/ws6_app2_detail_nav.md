# [WS-6 APP-2] 单词详情/背单词机/聆听/沉浸页导航安全化 + 空参数守卫

## 任务摘要

将 4 个高频页面的返回/退出/完成导航统一改为安全模式（`NavUtils.safePop` / `NavUtils.goHome`），并为 word_detail 页添加无参空态守卫，消除白屏 / NPE 崩溃风险。

## 修改文件清单

| # | 文件 | 修改内容 |
|---|------|----------|
| 1 | `lib/pages/word_detail_page.dart` | 返回按钮 → safePop；完成学习 → goHome / safePop；**无参守卫：word==null 时渲染空态页** |
| 2 | `lib/pages/word_machine_page.dart` | B 键返回 → safePop；CLEAR 页"返回首页" → goHome |
| 3 | `lib/pages/listening_player_page.dart` | 关闭按钮 → safePop |
| 4 | `lib/pages/immersive_swipe_page.dart` | 顶部关闭 → safePop；完成页"返回首页" → goHome |
| 5 | `test/pages/nav_safety_test.dart` | **新增** 8 个测试覆盖 safePop / goHome / 空态渲染 |

## 逐点变更明细

### 1. word_detail_page.dart

| 位置 | 原代码 | 改后 | 说明 |
|------|--------|------|------|
| 顶部返回按钮 | `Navigator.pop(context)` | `NavUtils.safePop(context)` | 防止栈底崩溃 |
| "完成学习"（最后一个单词） | `Navigator.popUntil(context, (route) => route.isFirst)` | `NavUtils.goHome(context)` | 统一语义 |
| "下一词" | `Navigator.pop(context)` | `NavUtils.safePop(context)` | 防止栈底崩溃 |
| "返回"（非学习流程） | `Navigator.pop(context)` | `NavUtils.safePop(context)` | 防止栈底崩溃 |
| **无参守卫** | `if (word == null) return const Scaffold(body: Center(child: Text('暂无单词')));` | **完整空态页**：`search_off` 图标 + "未找到单词" + "可能因参数缺失或数据异常" + "返回首页"按钮（goHome） | 深链 / 恢复场景不再白屏 / NPE |

### 2. word_machine_page.dart

| 位置 | 原代码 | 改后 |
|------|--------|------|
| CLEAR 页"返回首页" | `Navigator.pop(context)` | `NavUtils.goHome(context)` |
| B 键（返回） | `Navigator.pop(context)` | `NavUtils.safePop(context)` |

### 3. listening_player_page.dart

| 位置 | 原代码 | 改后 |
|------|--------|------|
| 关闭按钮（左上角 X） | `Navigator.pop(context)` | `NavUtils.safePop(context)` |

### 4. immersive_swipe_page.dart

| 位置 | 原代码 | 改后 |
|------|--------|------|
| 顶部关闭按钮 | `Navigator.pop(context)` | `NavUtils.safePop(context)` |
| 完成页"返回"按钮 | `Navigator.pop(context)` + label `'返回'` | `NavUtils.goHome(context)` + label `'返回首页'` |

## 质量门禁

| 门禁 | 结果 |
|------|------|
| `flutter analyze` 4 文件 | ✅ No issues found |
| `flutter test test/pages/nav_safety_test.dart` | ✅ 8/8 passed |
| 新增测试文件 | ✅ `test/pages/nav_safety_test.dart` |

## 测试覆盖摘要

| 测试 | 验证内容 |
|------|----------|
| safePop 子路由 | 正常 pop 回到父级 |
| safePop 根路由 | 不崩溃、不白屏 |
| goHome 多层嵌套 | popUntil 回到根路由 |
| goHome 根路由 | 不崩溃 |
| **word_detail 空态渲染** | word==null 时显示"未找到单词"+ 图标 + "返回首页"按钮 |
| **word_detail 空态 goHome** | "返回首页"按钮触发 goHome 回到根路由 |
| **word_machine CLEAR goHome** | CLEAR 页"返回首页"回到根路由 |
| **immersive_swipe 完成 goHome** | 完成页"返回首页"回到根路由 |

## 未修改（保持不动）

- 路由名 / 公开类名：未改变
- lib/core/router/nav_utils.dart：lead 已完成，直接复用
- 其它页面：不在本次范围内
- 无 git commit / 无全量 flutter test
