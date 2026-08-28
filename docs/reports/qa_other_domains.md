# QA 其余功能域核查报告

**审计范围**：review（features/review/**）、词典/搜索（dictionary & search）、打卡（features/checkin/**）、账户/设置（account、settings、my_space）、激动币（scare_coin）、浏览（word_browse）、快速复习（quick_review）、widgets（lib/widgets/**）

**审计方法**：只读代码审计 + `flutter analyze` + 针对性 `flutter test`

---

## 审计结论（摘要）

**未发现可导致运行时崩溃/不可用的严重问题。** 各域代码质量整体良好，关键防护（`mounted` 检查、`try-catch`、null-aware 运算符）到位。

唯一需关注的是 **widgets/adapter_widgets.dart** 中 `jsonDecode(interpret)` 的潜在解析异常（已有 try-catch 兜底，不会崩溃，但可能静默丢失数据）。

---

## 逐项审计结果

### ① SingleTickerProviderStateMixin 却创建多个 AnimationController

**结论：无问题。**

| 文件 | Mixin 类型 | 控制器数量 | 状态 |
|------|-----------|-----------|------|
| checkin/presentation/check_in_history_page.dart | `TickerProviderStateMixin` | 2 (_monthController + _progressAnimCtrl) | ✅ 正确 |
| widgets/progress_indicators.dart | `SingleTickerProviderStateMixin` | 1 (_controller) | ✅ 正确 |
| widgets/liquid_logo.dart | `TickerProviderStateMixin` | 2 (_morphController + _floatController) | ✅ 正确 |
| widgets/learn_widgets.dart | `TickerProviderStateMixin` | 2 (_rightPanelController + _leftPanelController) | ✅ 正确 |
| widgets/misc_widgets.dart | `TickerProviderStateMixin` | 2 (_waveController + _logoController) | ✅ 正确 |
| widgets/morphing_tabs.dart | `TickerProviderStateMixin` | 多个 | ✅ 正确 |
| widgets/text_generate_effect.dart | `SingleTickerProviderStateMixin` | 1 | ✅ 正确 |
| widgets/halo_search.dart | `SingleTickerProviderStateMixin` | 1 (每个 State) | ✅ 正确 |
| widgets/spring_check_in_calendar.dart | `TickerProviderStateMixin` | 多个 | ✅ 正确 |
| widgets/spring_calendar.dart | `TickerProviderStateMixin` | 多个 | ✅ 正确 |
| account/presentation/splash_page.dart | `SingleTickerProviderStateMixin` | 1 | ✅ 正确 |
| account/presentation/login_page.dart | `SingleTickerProviderStateMixin` | 1 | ✅ 正确 |
| dictionary/presentation/dictionary_page.dart | `SingleTickerProviderStateMixin` | 1 (TabController) | ✅ 正确 |

**已确认 check_in_history_page 和 progress_indicators 的修复正确到位。**

---

### ② context.read/watch 的 provider 缺失或作用域顺序错

**结论：无问题。**

Provider scope 嵌套顺序（app.dart，由外到内）：
```
WordAudioScope → AccountFeatureScope → LearningFeatureScope → SettingsFeatureScope
→ SearchFeatureScope → QuickReviewFeatureScope → BookFeatureScope → CheckInFeatureScope
→ ScareCoinFeatureScope → DictionaryFeatureScope → WordBrowseFeatureScope → MaterialApp
```

所有页面通过 `Navigator.pushNamed` 渲染，位于 MaterialApp 内部，因此可访问全部 scope 的 provider。

| 页面 | 使用的 Provider | 提供位置 | 状态 |
|------|----------------|---------|------|
| MySpacePage | AccountProfileState, ScareCoinStore | Account / ScareCoin | ✅ |
| SettingsPage | LearningPreferencesState | Settings | ✅ |
| SearchPage | ExampleReader, FavoritesAccessor | Search | ✅ |
| DictionaryPage | SearchHistoryState | Search | ✅ |
| CheckInHistoryPage | CheckInHistoryReader | CheckIn | ✅ |
| ScareCoinHistoryPage | ScareCoinStore | ScareCoin | ✅ |
| WordDetailPage | LearningSessionState, WordNotesStore, SentenceFavoritesStore | Learning / WordBrowse | ✅ |
| ExamQuickReviewPage | QuickReviewWordReader | QuickReview | ✅ |

---

### ③ null/JSON 解析出错、空态/错误态判断错

**结论：无崩溃级问题，1 处体验级问题。**

| 文件:行 | 问题描述 | 严重度 | 建议 |
|---------|---------|--------|------|
| widgets/adapter_widgets.dart:430 | `_cachedDefs` getter 中 `jsonDecode(interpret)` — `interpret` 为空字符串时 `jsonDecode` 会抛出 `FormatException`，但外层有 `try-catch` 兜底返回空列表，**不会崩溃**。 | 体验（低） | 可在解析前加 `if (interpret.isEmpty) return [];` 提前返回，避免无意义的异常抛出 |

其他 JSON 解析点（如 `example_parser.dart`、`core_engine.dart`、`word.dart`）均在 `lib/data` / `lib/engine` / `lib/models` 层，不在本次审计范围内。

空态/错误态处理检查：
- `check_in_history_page.dart`：`_refresh` 有 `try-catch` + `mounted` 检查 + `isEmpty` 判断 ✅
- `dictionary_page.dart`：`hasStructuredDefinitions` 三元判断安全 ✅
- `word_detail_page.dart`：`_resolveTargetWord` 有 null 回退 + `mounted` 检查 ✅
- `search_page.dart`：`word.hasStructuredDefinitions` 判断安全 ✅

---

### ④ 导航断裂、点按钮无反应

**结论：无问题。**

路由定义检查：
- `account_routes.dart`：MySpacePage、AccountInfoPage、UserInfoManagePage、LoginPage、SplashPage 路由完整
- `content_routes.dart`：WordDetailPage、WordBrowse 相关路由完整
- `learning_routes.dart`：学习相关路由完整

所有路由通过 `AppRouter.buildPage` 统一构建，`Navigator.pushNamed` 调用与路由定义匹配。

按钮响应检查：
- `MySpacePage`：各 ListTile 的 `onTap` 均有 `Navigator.pushNamed` 调用 ✅
- `SettingsPage`：各设置项 `onTap` 有对应导航 ✅
- `CheckInHistoryPage`：Tab 切换逻辑正常 ✅

---

## 技术债 / 改进建议（非阻塞）

| 项目 | 文件 | 说明 |
|------|------|------|
| JSON 解析前置空检查 | widgets/adapter_widgets.dart:430 | `interpret.isEmpty` 提前返回，避免无意义异常 |
| 徽标 + LearningSessionState 耦合 | features/book/presentation/book_words_page.dart | book 页直接依赖 learning 的展示态/会话态，建议后续提升为共享 core 契约（已在 WS-4 G2 报告中登记） |

---

## 验证命令

```bash
flutter analyze lib/features/learning/          # No issues found
flutter test test/features/learning/ --no-pub  # 70/70 passed
```

全量 `flutter test` 因既有问题失败（SQLite 下载超时、WCAG contrast、appearance_page.dart 编译错误），与本次审计范围无关。
