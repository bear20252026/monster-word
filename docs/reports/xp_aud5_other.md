# XP AUD-5 全盘体检：激动币 / 打卡 / 浏览收藏 / 快速复习 / 其它域

> **审计人**: QA-词库  
> **日期**: 2026-08-29  
> **项目**: Monster Word (`D:\claude\work\cn_com_lange\word_app`)  
> **范围**: 只读审计，覆盖 scare_coin / checkin / word_browse / quick_review / 跨切关注点  
> **方法**: 静态代码分析（未修改 lib/ 代码，未跑全量测试）  
> **参考**: `docs/reports/quality_program.md` 10 维检查点

---

## 一、审计结论摘要

共发现 **P0 问题 1 个、P1 问题 4 个、P2 问题 6 个、P3 问题 5 个**。

| 严重度 | 数量 | 关键问题 |
|--------|------|----------|
| 🔴 P0 | 1 | `class_checkin_page.dart` 直接 `context.read<ScareCoinStore>()` 但 ScareCoinStore 不在作用域 |
| 🟠 P1 | 4 | 打卡历史页 `context.read<CheckInHistoryReader>().checkInReward` 在 build 中读 ChangeNotifier 不触发重建；`exam_quick_review_page.dart` 在 initState 中直接读 provider 触发副作用；`check_in_history_page.dart` 动画控制器 dispose 异常风险；`scare_coin_history_page.dart` 空态判断缺失 |
| 🟡 P2 | 6 | 多个页面 `Navigator.pop(context)` 裸弹无返回值；`ModalRoute.of(context)` 未做空值保护；`word_notes_page.dart` 未注册路由；`sentence_favorites_page.dart` 未注册路由；`uri_scheme_page.dart` 深链解析异常处理；`route_error_page.dart` 兜底路由 |
| 🟢 P3 | 5 | 代码风格/命名不一致；部分 provider 未使用 `select` 优化重建；`TickerProviderStateMixin` 使用检查 |

---

## 二、P0 级问题（致命 — 运行时崩溃）

### P0-1: `class_checkin_page.dart` 直接读取 `ScareCoinStore` 但不在作用域

**文件**: `lib/features/checkin/presentation/class_checkin_page.dart:420`  
**现象**: 运行时 `ProviderNotFoundException: Could not find the correct Provider<ScareCoinStore>`  
**根因分析**:
- `class_checkin_page.dart` 在 `initState` 和 `build` 中调用 `context.read<ScareCoinStore>()`
- `ScareCoinStore` 注册在 `lib/features/scare_coin/presentation/scare_coin_feature_providers.dart` 的 `buildScareCoinFeatureScope` 中
- 但 `class_checkin_page.dart` 是 `checkin` feature 的页面，**不在 `scare_coin` 的 scope 内**
- `ScareCoinStore` 是 `scare_coin` feature 的内部状态，未提升到共享 core 层
- 打卡页面与激动币页面是独立的 feature scope，无法跨 scope 访问

**建议修复**:
1. 将 `ScareCoinStore` 提升为 `lib/core/scare_coin/scare_coin_store.dart` 共享契约（与 `LearningProgressReader` 同模式）
2. 或在 `checkin_feature_providers.dart` 中通过 `context.read<ScareCoinStore>()` 从父级 scope 获取（需确保 scope 嵌套正确）
3. 或在 `class_checkin_page.dart` 中通过 service locator `sl<ScareCoinStore>()` 获取

---

## 三、P1 级问题（高 — 功能异常）

### P1-1: `check_in_history_page.dart` 在 build 中读 ChangeNotifier 不触发重建

**文件**: `lib/features/checkin/presentation/check_in_history_page.dart:585`  
**现象**: 签到成功后 UI 不更新尖叫币数量，需手动刷新  
**根因分析**:
```dart
'签到成功 +${context.read<CheckInHistoryReader>().checkInReward} 尖叫币',
```
- `context.read<T>()` 在 `build` 方法中**不会订阅**该 ChangeNotifier
- 当 `CheckInHistoryReader` 状态变化时，此 widget 不会重建
- 应使用 `context.watch<T>()` 或 `Consumer<T>` 包裹

**建议修复**:
```dart
final reward = context.watch<CheckInHistoryReader>().checkInReward;
'签到成功 +$reward 尖叫币',
```

### P1-2: `exam_quick_review_page.dart` 在 initState 中直接读 provider 触发副作用

**文件**: `lib/features/quick_review/presentation\exam_quick_review_page.dart:46,136`  
**现象**: 页面初始化时可能触发 `loadWords()` 多次调用，导致状态竞争  
**根因分析**:
```dart
@override
void initState() {
  super.initState();
  context.read<QuickReviewWordReader>().loadWords().then((words) { ... });
}
```
- `initState` 中直接调用 `context.read<QuickReviewWordReader>().loadWords()` 是异步副作用
- 若 widget 快速重建（如热重载、父级 setState），可能多次触发 `loadWords()`
- 应使用 `WidgetsBinding.instance.addPostFrameCallback` 延迟到首帧后执行
- 应添加 `_mounted` 检查防止异步回调时 widget 已销毁

**建议修复**:
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      context.read<QuickReviewWordReader>().loadWords().then((words) {
        if (mounted) { ... }
      });
    }
  });
}
```

### P1-3: `check_in_history_page.dart` 动画控制器 dispose 异常风险

**文件**: `lib/features/checkin/presentation/check_in_history_page.dart`  
**现象**: 动画控制器可能在 widget 已 dispose 后仍调用 `setState` 或 `notifyListeners`  
**根因分析**:
- 页面使用 `SingleTickerProviderStateMixin` 管理动画
- 若异步回调（如网络请求、定时器）在动画执行期间完成，可能触发 `setState` 时 controller 已 dispose
- 缺少 `if (mounted)` 检查保护

**建议修复**:
- 在所有异步回调中添加 `if (mounted)` 检查
- 在 `dispose()` 中取消所有定时器和异步操作

### P1-4: `scare_coin_history_page.dart` 空态判断缺失

**文件**: `lib/features/scare_coin/presentation/scare_coin_history_page.dart`  
**现象**: 当用户无激动币记录时，列表区域显示空白而非友好空态提示  
**根因分析**:
- 页面直接渲染 `ListView.builder`，未判断 `scareCoinEntries.isEmpty`
- 用户看到空白区域，误以为加载失败

**建议修复**:
```dart
if (scareCoinEntries.isEmpty) {
  return const Center(child: Text('暂无激动币记录'));
}
```

---

## 四、P2 级问题（中 — 体验缺陷）

### P2-1: 多个页面 `Navigator.pop(context)` 裸弹无返回值

**文件**: 多个页面（`my_fav_page.dart`、`list_words_page.dart`、`word_export_page.dart` 等）  
**现象**: 无法向上一页面传递结果，如删除成功后上一页面无法刷新  
**根因分析**:
- `Navigator.pop(context)` 不带参数，无法传递操作结果
- 应使用 `Navigator.pop(context, result)` 返回操作结果

**建议修复**: 在需要返回结果的场景使用 `Navigator.pop(context, true)` 或返回具体数据。

### P2-2: `ModalRoute.of(context)` 未做空值保护

**文件**: `lib/pages/my_fav_page.dart`、`lib/pages/list_words_page.dart`  
**现象**: 若页面不在 Navigator 栈顶（如被其他页面覆盖），`ModalRoute.of(context)` 返回 null，触发 NPE  
**根因分析**:
- `ModalRoute.of(context)` 在页面不在栈顶时返回 null
- 直接调用 `ModalRoute.of(context)!.settings.arguments` 会抛出 `Null check operator used on a null value`

**建议修复**:
```dart
final route = ModalRoute.of(context);
if (route == null) return;
final arguments = route.settings.arguments;
```

### P2-3: `word_notes_page.dart` 未注册路由

**文件**: `lib/features/word_browse/presentation/word_notes_page.dart`  
**现象**: 无法通过路由名 `/word_notes` 导航到此页面  
**根因分析**:
- `word_notes_page.dart` 定义了 `routeName = '/word_notes'`
- 但在 `app_router.dart` 或 `route_names.dart` 中未找到对应路由注册
- 只能通过直接构造函数调用，无法通过深链或命名路由访问

**建议修复**: 在 `route_names.dart` 和 `app_router.dart` 中注册此路由。

### P2-4: `sentence_favorites_page.dart` 未注册路由

**文件**: `lib/features/word_browse/presentation/sentence_favorites_page.dart`  
**现象**: 同 P2-3，无法通过路由名导航  
**根因分析**: 同 P2-3

### P2-5: `uri_scheme_page.dart` 深链解析异常处理

**文件**: `lib/pages/uri_scheme_page.dart`  
**现象**: 深链参数缺失或格式错误时可能抛出未捕获异常  
**根因分析**:
- 深链解析逻辑中缺少 try-catch 包裹
- 参数缺失时直接访问 `uri.queryParameters['key']` 可能返回 null
- 未做空值保护直接类型转换

**建议修复**: 添加 try-catch 和空值保护，解析失败时跳转到 `RouteErrorPage`。

### P2-6: `route_error_page.dart` 兜底路由

**文件**: `lib/core/router/route_error_page.dart`  
**现象**: 错误页面缺少返回首页的导航选项  
**根因分析**:
- `RouteErrorPage` 仅显示错误信息，未提供「返回首页」或「重试」按钮
- 用户陷入死胡同，只能强制退出应用

**建议修复**: 添加「返回首页」按钮，使用 `Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false)`。

---

## 五、P3 级问题（低 — 代码质量）

### P3-1: 代码风格/命名不一致

**文件**: 多个文件  
**现象**: 部分文件使用 `camelCase`，部分使用 `snake_case` 命名变量  
**建议修复**: 统一使用 Dart 官方推荐的 `camelCase` 命名风格。

### P3-2: 部分 provider 未使用 `select` 优化重建

**文件**: `scare_coin_history_page.dart`、`check_in_history_page.dart`  
**现象**: 使用 `context.watch<T>()` 监听整个 ChangeNotifier，当不相关字段变化时触发不必要的重建  
**建议修复**: 使用 `context.watch<T>().select((value) => value.specificField)` 精确订阅。

### P3-3: `TickerProviderStateMixin` 使用检查

**文件**: `check_in_history_page.dart`  
**现象**: 页面使用 `SingleTickerProviderStateMixin` 但可能未正确 dispose AnimationController  
**建议修复**: 确保 `dispose()` 中调用 `_animationController.dispose()`。

### P3-4: `exam_quick_review_page.dart` 缺少 `mounted` 检查

**文件**: `lib/features/quick_review/presentation/exam_quick_review_page.dart`  
**现象**: 异步回调中未检查 `mounted` 直接调用 `setState`  
**建议修复**: 在所有 `setState` 调用前添加 `if (mounted)` 检查。

### P3-5: `word_export_page.dart` 导出逻辑异常处理

**文件**: `lib/pages/word_export_page.dart`  
**现象**: 文件导出失败时未显示错误提示  
**建议修复**: 添加 try-catch 包裹导出逻辑，失败时显示 SnackBar 提示。

---

## 六、域详细审计

### 6.1 scare_coin（激动币）

| 检查点 | 状态 | 说明 |
|--------|------|------|
| Provider 注册 | ✅ | `ScareCoinStore` 在 `scare_coin_feature_providers.dart` 注册 |
| 空态处理 | ❌ | 无空态判断（P1-4） |
| 路由注册 | ✅ | `/scare_coin_history` 已注册 |
| 异常处理 | ✅ | 数据层有 try-catch |
| dispose | ✅ | 无动画控制器 |

### 6.2 checkin（打卡）

| 检查点 | 状态 | 说明 |
|--------|------|------|
| Provider 注册 | ⚠️ | `ScareCoinStore` 跨域访问（P0-1） |
| 空态处理 | ✅ | 有历史记录空态 |
| 路由注册 | ✅ | `/check_in_history` 已注册 |
| 异常处理 | ✅ | 网络请求有 try-catch |
| dispose | ⚠️ | 动画控制器 dispose 风险（P1-3） |
| build 中读 ChangeNotifier | ❌ | 不触发重建（P1-1） |

### 6.3 word_browse（浏览收藏）

| 检查点 | 状态 | 说明 |
|--------|------|------|
| Provider 注册 | ✅ | `SentenceFavoritesStore`、`WordNotesStore` 已注册 |
| 空态处理 | ✅ | 有收藏/笔记空态 |
| 路由注册 | ❌ | `word_notes_page`、`sentence_favorites_page` 未注册（P2-3/P2-4） |
| 异常处理 | ✅ | 数据层有保护 |
| dispose | ✅ | 无动画控制器 |

### 6.4 quick_review（快速复习）

| 检查点 | 状态 | 说明 |
|--------|------|------|
| Provider 注册 | ✅ | `QuickReviewWordReader` 已注册 |
| 空态处理 | ✅ | 有单词列表空态 |
| 路由注册 | ✅ | `/exam_quick_review` 已注册 |
| 异常处理 | ⚠️ | initState 中副作用（P1-2） |
| dispose | ⚠️ | 缺少 mounted 检查（P3-4） |

### 6.5 跨切关注点

| 检查点 | 状态 | 说明 |
|--------|------|------|
| Navigator.pop 裸弹 | ⚠️ | 多个页面无返回值（P2-1） |
| ModalRoute.of 空值保护 | ⚠️ | 未做空值保护（P2-2） |
| context.read/watch 作用域 | ❌ | `class_checkin_page` 跨域读 ScareCoinStore（P0-1） |
| SessionExitGuard | ✅ | 会话退出保护已实现 |
| 未注册路由 | ❌ | `word_notes_page`、`sentence_favorites_page`（P2-3/P2-4） |
| RouteErrorPage 兜底 | ⚠️ | 缺少返回首页按钮（P2-6） |
| URI 深链 | ⚠️ | 异常处理不完善（P2-5） |

---

## 七、修复优先级建议

| 优先级 | 问题 | 工作量 | 建议 |
|--------|------|--------|------|
| 🔴 立即修复 | P0-1: ScareCoinStore 跨域访问 | 2h | 提升为 core 契约 |
| 🟠 本迭代修复 | P1-1: build 中读 ChangeNotifier | 0.5h | 改用 watch |
| 🟠 本迭代修复 | P1-2: initState 副作用 | 0.5h | postFrameCallback |
| 🟠 本迭代修复 | P1-3: 动画控制器 dispose | 1h | 添加 mounted 检查 |
| 🟠 本迭代修复 | P1-4: 空态判断缺失 | 0.5h | 添加空态 UI |
| 🟡 下迭代修复 | P2-1~P2-6 | 3h | 逐项修复 |
| 🟢 技术债 | P3-1~P3-5 | 2h | 代码质量优化 |

---

## 八、方法论备注

- **未执行** `flutter test`（避免与 lead 抢锁）
- **已执行** 全链路静态代码审查：scare_coin / checkin / word_browse / quick_review 全部文件
- **已执行** 跨切关注点扫描：Navigator.pop、ModalRoute.of、context.read/watch、路由注册
- **未执行** 运行时验证（需 lead 修复后跑测试）

---

*报告完成。等待 lead 审查。*
