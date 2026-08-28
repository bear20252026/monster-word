# XP AUD-6 · 跨切面反模式 Grep 扫描报告

> **审计范围**: `lib/` 全库  
> **扫描日期**: 2026-08-28  
> **扫描规则**: 10 条  
> **审计人**: Aion CLI  

---

## 摘要

| 级别 | 数量 | 说明 |
|------|------|------|
| P0   | 0    | 无致命级 |
| P1   | 2    | 导航黑屏 + 硬编码路由 |
| P2   | 4    | context.read 安全 + mounted 防护 |
| P3   | 3    | 代码质量 & 可维护性 |
| **合计** | **9** | |

---

## P1 — 高优先级

### P1-1 裸 `Navigator.pop()` 未走 NavUtils.safePop

**扫描规则**: `Rule 1 — Navigator\.pop\(`

**发现**: `lib/` 内约 **12 处** `Navigator.of(context).pop()` 直接调用，未经过 `NavUtils.safePop()`。其中部分在 Modal/Dialog 内（弹窗关闭，安全），部分在页面级导航中（有黑屏风险）。

**需要修复的文件** (页面级弹窗退出):

| 文件 | 行号 | 上下文 |
|------|------|--------|
| `lib/features/settings/presentation/settings_page.dart` | 432 | `onTap: () => Navigator.of(context).pop()` |
| `lib/widgets/session_exit_guard.dart` | 49 | `Navigator.of(context).pop()` |
| `lib/widgets/special_widgets.dart` | 303, 313, 349 | 3处直 pop |
| `lib/widgets/word_dictionary_popup.dart` | 210 | `Navigator.of(context).pop()` |
| `lib/features/account/presentation/user_info_manage_page.dart` | 153 | `Navigator.pop(ctx)` |

**安全的** (Modal/Dialog 关闭，栈底不会被 pop):
- `lib/widgets/image_widgets.dart:163` — 弹窗内的关闭按钮
- `lib/widgets/sb_modal.dart:153` — ModalSheet 关闭按钮
- `lib/widgets/review_dialog.dart:133, 152` — Review 弹窗关闭

**建议**: 页面级 `pop` 替换为 `NavUtils.safePop(context)`，弹窗内可保留。

---

### P1-2 硬编码路由字符串

**扫描规则**: `Rule 7 — 硬编码路由`

**发现**: `route_names.dart` 已定义路由常量，但多处仍使用字符串字面量。

| 文件 | 行号 | 硬编码值 | 应用常量 |
|------|------|----------|----------|
| `lib/pages/uri_scheme_page.dart` | 50 | `'/learn'` | `RouteNames.learn` |
| `lib/pages/uri_scheme_page.dart` | 53 | `'/review'` | `RouteNames.review` |
| `lib/pages/my_fav_page.dart` | 268 | `'/word_detail'` | 无专用常量，应添加 |
| `lib/pages/list_words_page.dart` | 228 | `'/word_detail'` | 同上 |
| `lib/pages/lib_select_page.dart` | 376 | `'/immersive_swipe'` | 无专用常量 |
| `lib/pages/personal_stereo_page.dart` | 72 | `'/play_order'` | 无专用常量 |
| `lib/features/book/presentation/book_words_page.dart` | 31 | `'/immersive_swipe'` | 同上 |
| `lib/features/book/presentation/books_page.dart` | 124 | `'/lib-select'` | 无专用常量 |
| `lib/features/account/presentation/my_space_page.dart` | 256, 263, 270, 326 | `'/appearance'`, `'/settings'`, `'/more_settings'`, `'/scare_coin_history'` | 均缺常量 |
| `lib/screens/profile_screen.dart` | 251 | `'/scare_coin_history'` | 缺常量 |
| `lib/screens/home_screen.dart` | 329 | `'/check_in_history'` | 缺常量 |
| `lib/widgets/review_dialog.dart` | 134 | `'/learn'` | `RouteNames.learn` |

**影响**: 重命名路由时容易遗漏，编译器不报错。  
**建议**: 先在 `route_names.dart` 补全缺失常量，再批量替换。

---

## P2 — 中优先级

### P2-1 `context.read` 无 scope 保护

**扫描规则**: `Rule 3 — context\.read[<(]`

**发现**: `lib/` 内约 **120+ 处** `context.read<T>()` 调用。

**分布**:
- `lib/services/` — ~50 处 (api_services.dart, http_client.dart 等)
- `lib/pages/` — ~40 处
- `lib/widgets/` — ~20 处
- `lib/screens/` — ~10 处

**高风险场景**:  
- 在 `async` 回调中使用 `context.read`，页面可能已退出  
- `lib/pages/word_machine_page.dart` — 异步操作后 context.read  
- `lib/pages/word_detail_page.dart` — 多处异步 context.read

**建议**: 优先对 session pages (learn/review/spell/dictation) 中的 async context.read 加 `mounted` 检查或提取到 `didChangeDependencies`。

---

### P2-2 部分 async 回调缺少 `mounted` 守护

**扫描规则**: `Rule 4 — setState after dispose`

**发现**: 库内 **大量** async 回调已有 `mounted` 检查（~90+ 处），整体习惯较好。但以下文件仍有遗漏：

| 文件 | 缺失场景 |
|------|----------|
| `lib/pages/list_words_page.dart` | `setState` 在 async 回调中，仅 1 处有 mounted |
| `lib/pages/sms_page.dart:41` | `if (!mounted) return false` — 但后续路径未全守护 |
| `lib/features/account/presentation/user_info_manage_page.dart:153` | `Navigator.pop(ctx)` 仅用了 `if (ctx.mounted)`，但 ctx 与 this.mounted 不一致 |

**建议**: 全局搜索 `setState(` 但无对应 `mounted` 的 async 代码路径。

---

### P2-3 `SingleTickerProviderStateMixin` 多 AnimationController 风险

**扫描规则**: `Rule 6`

**发现**: 30 个文件使用 `SingleTickerProviderStateMixin`，其中大部分只有 1 个 AnimationController（安全）。

**需要关注的文件** (可能有多个 controller):

| 文件 | 原因 |
|------|------|
| `lib/pages/learn_page.dart` | 有 2+ AnimationController，应使用 `TickerProviderStateMixin` |
| `lib/pages/sentence_quiz_page.dart` | 2 个 AnimationController |
| `lib/widgets/morphing_tabs.dart` | 多个 controller + ticker |
| `lib/widgets/spring_check_in_calendar.dart` | 多个 controller |

**建议**: 有 2+ AnimationController 的文件改用 `TickerProviderStateMixin`。

---

## P3 — 低优先级

### P3-1 路由参数强制解包 `settings.arguments!` 

**扫描规则**: `Rule 9`

**发现**: **0 处** `settings.arguments!` 强制解包 ✅ — 全库已安全处理。

---

### P3-2 不安全的 `as` 类型转换

**扫描规则**: `Rule 8`

**发现**: `lib/` 内约 **130+ 处** `as` 类型转换。

**分类**:
- ✅ **安全** (~110 处): JSON 反序列化中的 `as String? ?? ''`、`as Map<String, dynamic>?` 等，均有 fallback
- ⚠️ **有风险** (~20 处):

| 文件 | 行号 | 表达式 | 风险 |
|------|------|--------|------|
| `lib/core/router/learning_routes.dart` | 112, 125, 134 | `entry as Word` | 路由参数可能非 Word |
| `lib/pages/learn_page.dart` | 287, 534 | `word.parsedDefinitions as List`, `defs.first as Map<String, String>` | 运行时类型不匹配 |
| `lib/services/http_client.dart` | 310, 328, 506, 524 | `requestParams as CoolParams?` | 已有 fallback |

**建议**: 对 `entry as Word` 等无 fallback 的转换加 `try-catch` 或使用 `as?` + 空值处理。

---

### P3-3 空数据传递到 session 页面

**扫描规则**: `Rule 10`

**发现**: 未发现明显的空列表直接传入 session 页面。session 入口（LearnSession, DictationSessionPage 等）均在 push 前有长度检查。

**已验证的安全路径**:
- `lib/screens/learn_session.dart` — 入口有 `words.isEmpty` 检查
- `lib/pages/dictation_session_page.dart` — 入口有 empty 检查
- `lib/pages/quick_spell_page.dart` — 入口有 empty 检查
- `lib/pages/spell_session_page.dart` — 入口有 empty 检查

---

## 扫描规则执行结果汇总

| # | 规则 | 结果 |
|---|------|------|
| 1 | 裸 `Navigator.pop()` | ⚠️ 12 处，页面级 5 处需修复 |
| 2 | `ModalRoute.of` in `initState` | ✅ 0 处 |
| 3 | `context.read` 无 scope | ⚠️ 120+ 处，部分 async 高风险 |
| 4 | `setState` after `dispose` | ⚠️ 3 文件有遗漏 |
| 5 | `pushReplacement` / `popUntil` | ✅ 0 处 |
| 6 | `SingleTickerProviderStateMixin` | ⚠️ 4 文件可能有多 controller |
| 7 | 硬编码路由字符串 | ⚠️ 12+ 处 |
| 8 | 不安全 `as` 转换 | ⚠️ ~20 处有风险 |
| 9 | `settings.arguments!` | ✅ 0 处 |
| 10 | 空数据传入 session | ✅ 0 处 |

---

## 修复优先级建议

1. **P1-1** (裸 pop) + **P1-2** (硬编码路由): 建议下一轮迭代修复，约 17 处改动
2. **P2-1** (context.read) + **P2-2** (mounted): 建议在 session pages 重构时顺带修复
3. **P2-3** (TickerProvider): 低风险，可排期修复
4. **P3-x**: 建议在长期维护中逐步清理
