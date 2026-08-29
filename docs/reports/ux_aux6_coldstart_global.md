# UX-AUX-6 冷启动/首屏/引导 + 全局空态错误兜底审计报告

**审计人**: QA-背单词  
**日期**: 2026-08-29  
**范围**: 冷启动流程、首屏引导、全局异常兜底、加载反馈、深链处理  
**约束**: 只读审计，不修改 lib/

---

## 问题 1（High）：Splash 页被绕过，冷启动直接进入首页

### 用户痛点

用户打开 App 后**看不到品牌 Splash 动画、登录检查、首次使用引导**，直接看到首页内容。首次使用引导页（3 页科学记忆/沉浸学习/持续进步介绍）永远不会展示。

### 文件与行号

- `lib/app/app.dart:131` — `home: const AdaptiveScale(child: _HomeShell())`
- `lib/features/account/presentation/splash_page.dart` — 完整的 Splash + 引导页实现
- `lib/core/router/content_routes.dart:26-27` — Splash 路由已注册但未被使用

### 根因分析

`app.dart` 的 `MaterialApp.home` 直接指向 `_HomeShell()`，跳过了 `SplashPage`。`SplashPage` 虽然在路由表中注册（`/splash`），但没有被任何地方作为初始路由启动。

`SplashPage` 内部有完整的逻辑：
1. 1.5s 品牌动画（LiquidLogo + 流星雨背景）
2. 2s 延迟检查登录状态
3. 首次启动时显示 3 页引导（科学记忆/沉浸学习/持续进步）
4. 未登录跳转登录页

但这些全部被绕过了。

### 建议修复

将 `app.dart:131` 的 `home` 改为 `SplashPage`：

```dart
home: const AdaptiveScale(child: SplashPage()),
```

或在 `_HomeShell` 的 `initState` 中检查是否首次启动，若首次则导航到 `/splash`。

---

## 问题 2（High）：异步异常无 `runZonedGuarded` 兜底

### 用户痛点

异步代码（`Future.delayed`、网络请求回调、`SharedPreferences` 操作）中抛出的未捕获异常会导致**应用静默崩溃或白屏**，用户看不到任何错误提示。

### 文件与行号

- `lib/app/app_bootstrap.dart:26-45` — 全局错误处理配置

### 根因分析

`_configureGlobalErrorHandling()` 配置了三个层级的错误捕获：

1. `ErrorWidget.builder` → 替换为 `AppBuildErrorPage`（Widget 构建错误）— **有效**
2. `FlutterError.onError` → 打印日志 + `FlutterError.presentError` — **有效但只打印**
3. `platformDispatcher.onError` → 仅 `debugPrint` + `return true` — **吞掉异常**

缺少 `runZonedGuarded` 包裹 `main()`，这意味着：
- `async` 函数中未 `try-catch` 的异常（如 `await SharedPreferences.getInstance()` 在极端情况下失败）不会被捕获
- `Timer`、`Stream` 回调中的异常同样无兜底

### 建议修复

在 `main.dart` 中用 `runZonedGuarded` 包裹：

```dart
Future<void> main() async {
  runZonedGuarded(() async {
    await bootstrapApp();
    runApp(const WordApp());
  }, (error, stack) {
    debugPrint('[GlobalError] Uncaught: $error\n$stack');
  });
}
```

---

## 问题 3（Medium）：冷启动加载链无进度反馈

### 用户痛点

App 启动时依次初始化数据库、Preferences、音频会话、ServiceLocator（共 5 个 `await`），期间**用户看到白屏或首页闪现**，不知道 App 是否在加载。

### 文件与行号

- `lib/app/app_bootstrap.dart:14-24` — `bootstrapApp()` 顺序初始化
- `lib/main.dart:6-9` — `main()` 调用链

### 根因分析

`bootstrapApp()` 串行执行 5 个异步初始化：

```dart
await WordBookDatabase.ensurePlatform();    // 平台初始化
await WordBookDatabase.instance.initialize(); // 数据库
await UserDatabase.instance.initialize();     // 用户数据库
await AppPreferences().init();                // SharedPreferences
await initMobileAudioSession();               // 音频会话
await setupServiceLocator();                  // DI 注册
```

这些步骤没有进度回调，`MaterialApp` 在 `bootstrapApp()` 完成后才启动，用户在初始化期间看到的是**上一次 App 的快照（Android）或白屏（iOS）**。

### 建议修复

方案 A：在 `bootstrapApp()` 中发送进度事件，用原生 splash 展示进度  
方案 B：用 `FlutterNativeSplash` 保持原生 splash 直到 `runApp` 完成  
方案 C：将非关键初始化（音频、ServiceLocator）改为延迟加载，只在首次使用时初始化

---

## 问题 4（Medium）：首页 Learn 按钮在无词书时体验不佳

### 用户痛点

新用户首次打开首页点击「Learn」，如果本地无词书数据，只看到一个短暂的 SnackBar「暂无词书，请先添加词书」，**没有引导用户去哪里添加词书**。

### 文件与行号

- `lib/screens/home_screen.dart:139-162` — `_startLearning()` 方法

### 根因分析

```dart
Future<void> _startLearning(BuildContext context) async {
  final state = context.read<LearningSessionState>();
  if (state.queue.isNotEmpty) { /* 直接开始 */ return; }
  final books = await context.read<BookCatalogReader>().listBooks();
  if (books.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('暂无词书，请先添加词书')),
    );
    return;
  }
  // ...
}
```

问题：
1. SnackBar 自动消失后用户不知如何操作
2. 没有引导跳转到词书选择页（`LibSelectPage`）
3. 新用户不知道「添加词书」意味着什么

### 建议修复

SnackBar 增加「去选择」操作按钮，引导用户跳转到词书选择页：

```dart
 ScaffoldMessenger.of(context).showSnackBar(
   SnackBar(
     content: const Text('暂无词书，请先选择词书'),
     action: SnackBarAction(
       label: '去选择',
       onPressed: () => Navigator.pushNamed(context, '/lib_select'),
     ),
   ),
 );
```

---

## 问题 5（Medium）：Review 弹窗无空态处理

### 用户痛点

用户点击「Review」按钮时，如果今日无待复习单词，弹窗仍显示「0 词」且「开始复习」按钮可点击，点击后进入复习页面但可能无内容。

### 文件与行号

- `lib/widgets/review_dialog.dart:86-119` — Review 弹窗统计与进度条
- `lib/widgets/review_dialog.dart:148-153` — 「开始复习」按钮

### 根因分析

`_ReviewDialog` 始终显示统计卡片和两个按钮（继续学习/开始复习），**不检查 `dueCount` 是否为 0**。当 `dueCount == 0` 时：
- 统计显示「今日复习 0 词」
- 「开始复习」按钮仍然可点击
- 进度条为 0%

用户点击「开始复习」后进入 `ReviewPage`，如果 `ReviewSessionState` 初始化时发现无待复习单词，行为不确定。

### 建议修复

当 `dueCount == 0` 时，隐藏「开始复习」按钮或显示「今日已完成复习」的友好提示：

```dart
if (schedule.todayReviewCount > 0)
  Expanded(child: ElevatedButton.icon(... '开始复习' ...))
else
  Expanded(child: Text('今日复习已完成 ✓', style: ...))
```

---

## 问题 6（Medium）：URI 深链冷启动无品牌过渡

### 用户痛点

通过 `monsterword://learn` 或 `monsterword://review` 深链冷启动时，用户看到 `UriSchemePage` 的空白页面 + 加载圈，**没有品牌感**，也不确定 App 是否在响应。

### 文件与行号

- `lib/pages/uri_scheme_page.dart:27-30` — URI 处理页面 UI

### 根因分析

`UriSchemePage` 的 `build` 方法直接返回一个 `Scaffold` + `CircularProgressIndicator`，没有品牌元素：

```dart
return Scaffold(
  backgroundColor: context.skin.colors.pageBg,
  body: Center(child: CircularProgressIndicator(color: MistralColors.primary)),
);
```

深链冷启动时，用户在 App 初始化期间看到的是这个空白加载页，而非品牌 Splash。

### 建议修复

在 `UriSchemePage` 中添加品牌 Logo 或使用 Splash 页面的视觉元素，让用户感知到 App 正在加载。

---

## 问题 7（Low）：`AppBuildErrorPage` 的「返回首页」按钮在深层路由可能失效

### 用户痛点

Widget 构建错误时显示的错误页点击「返回首页」可能无法真正回到首页，因为 `popUntil((route) => route.isFirst)` 在某些路由栈状态下可能不按预期工作。

### 文件与行号

- `lib/app/app_error_widget.dart:33-38` — 错误页返回逻辑

### 根因分析

```dart
onPressed: () {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.popUntil((route) => route.isFirst);
  }
},
```

当错误发生在根路由（`isFirst` 为 true）时，`canPop()` 返回 false，按钮点击无效果。用户被卡在错误页无法离开。

### 建议修复

增加兜底：当 `canPop()` 为 false 时，使用 `pushReplacementNamed('/')` 强制重建首页：

```dart
onPressed: () {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.popUntil((route) => route.isFirst);
  } else {
    navigator.pushReplacementNamed('/');
  }
},
```

---

## 问题 8（Low）：全局加载指示器样式不统一

### 用户痛点

不同页面的 loading 状态视觉不一致：有的用 `CircularProgressIndicator()` 默认色，有的用 `MistralColors.primary`，有的用 `skin.colors.accent`，有的 `strokeWidth: 2`，有的默认。用户在页面间切换时感受到视觉跳跃。

### 文件与行号

多个页面，部分示例：

- `lib/pages/lib_select_page.dart:162` — `CircularProgressIndicator()` 无颜色
- `lib/pages/uri_scheme_page.dart:29` — `CircularProgressIndicator(color: MistralColors.primary)`
- `lib/features/book/presentation/book_words_page.dart:58` — `CircularProgressIndicator()` 无颜色
- `lib/pages/learn_page.dart:343` — `CircularProgressIndicator(strokeWidth: 2, color: colors.text2)`
- `lib/features/learning/presentation/widgets/formal_review_state_views.dart:11` — `CircularProgressIndicator()` 无颜色

### 根因分析

没有全局统一的 loading 组件或 loading 主题。每个页面自行创建 `CircularProgressIndicator`，导致颜色、尺寸、strokeWidth 各不相同。

### 建议修复

创建一个全局的 `AppLoadingIndicator` 组件，统一颜色（`skin.colors.accent`）、尺寸和 stroke width，各页面引用该组件。

---

## 问题 9（Info）：Provider 嵌套层级过深但无功能影响

### 用户痛点

无直接影响（用户不可见），但 10 层 `buildXxxScope` 嵌套增加了维护成本。

### 文件与行号

- `lib/app/app.dart:36-65` — 10 层 Provider 嵌套

### 根因分析

```dart
return buildWordAudioScope(
  child: buildAccountFeatureScope(
    child: buildLearningFeatureScope(
      child: buildSettingsFeatureScope(
        // ... 10 层
```

这是功能域各自独立 Provider 装配的结果。功能上无问题，但嵌套过深影响可读性。

### 建议修复

可考虑使用 `MultiProvider` 合并或重组，但这不是用户可见问题，优先级低。

---

## 总结

| # | 严重度 | 问题 | 用户影响 |
|---|--------|------|---------|
| 1 | **High** | Splash 页被绕过，冷启动直接进首页 | 首次引导永远不展示，品牌感缺失 |
| 2 | **High** | 缺少 `runZonedGuarded` 兜底 | 异步异常导致白屏/静默崩溃 |
| 3 | Medium | 冷启动加载链无进度反馈 | 初始化期间白屏，用户不知是否在加载 |
| 4 | Medium | Learn 按钮无词书时无引导 | SnackBar 消失后用户不知如何操作 |
| 5 | Medium | Review 弹窗无空态处理 | 待复习为 0 时仍可点击「开始复习」 |
| 6 | Medium | 深链冷启动无品牌过渡 | 空白加载页，无品牌感 |
| 7 | Low | 错误页「返回首页」在根路由失效 | 错误后可能卡死在错误页 |
| 8 | Low | 加载指示器样式不统一 | 页面间 loading 视觉跳跃 |
| 9 | Info | Provider 嵌套过深 | 维护成本，用户不可见 |
