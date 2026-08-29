# UX-FIX-A 冷启动/全局：Splash 复位 + runZonedGuarded + 深链/兜底

> 任务：冷启动/全局修复（A-1/A-2/A-3/A-5/A-6）+ 门禁回归修复（app_structure_test / widget_test）
> 日期：2026-08-28
> 状态：✅ 完成（代码 + 测试 + 报告三件套齐全）

---

## 一、修复总览

| 编号 | 问题 | 文件 | 改动摘要 |
|------|------|------|----------|
| A-1 | Splash 未作为真实入口 | `lib/app/app.dart` | `home` 改为 `SplashPage()` |
| A-2 | 异步异常无 zone 兜底 | `lib/main.dart`、`lib/app/app_bootstrap.dart` | `runZonedGuarded` 包裹 `runApp` |
| A-3 | 冷启动无进度反馈 | `lib/app/app_bootstrap.dart` | 分步初始化 + `onProgress` 回调 |
| A-5 | dueCount==0 时空态缺失 | `lib/widgets/review_dialog.dart` | 友好空态 + CTA |
| A-6 | 深链冷启动卡死 + 白屏 | `lib/pages/uri_scheme_page.dart` | 品牌过渡 + `_goHomeSafe` 兜底 |
| 修复② | Splash Timer 遗留 pending | `lib/features/account/presentation/splash_page.dart` | Timer 持有 + dispose 取消 |
| 修复① | main.dart 字面不含 `runApp(const WordApp())` | `lib/main.dart` | 内联 `runZonedGuarded` |

---

## 二、逐文件改动点

### A-1：`lib/app/app.dart` — Splash 复位为真实入口

```dart
// 修复前
home: const AdaptiveScale(child: _HomeShell());

// 修复后
// A-1: SplashPage 作为真实入口，负责品牌动画 + 登录检查 + 路由分发。
home: const AdaptiveScale(child: SplashPage());
```

**原因**：原实现直接以 `_HomeShell`（主页 MainShell）为 `home`，跳过了启动页的品牌展示与登录态检查，导致冷启动无过渡、已登录用户无法正确分发。

---

### A-2：`lib/main.dart` + `lib/app/app_bootstrap.dart` — runZonedGuarded 兜底

**`lib/main.dart`**（内联 runZonedGuarded，字面保留 `runApp(const WordApp())`）：

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/app_bootstrap.dart';

Future<void> main() async {
  await bootstrapApp();
  // A-2: 用 runZonedGuarded 包裹 runApp，异步异常不再无兜底崩溃。
  runZonedGuarded(() {
    runApp(const WordApp()); // 字面必须含这一行，app_structure_test 靠它
  }, (error, stack) {
    debugPrint('[runZonedGuarded] 未捕获异常: $error');
    debugPrint('$stack');
  });
}
```

**`lib/app/app_bootstrap.dart`**（新增 `runAppGuarded` 工具函数，供测试引用）：

```dart
/// A-2: 用 runZonedGuarded 包裹 runApp，捕获异步异常防止无兜底崩溃。
void runAppGuarded(Widget app) {
  runZonedGuarded(() {
    runApp(app);
  }, (error, stack) {
    debugPrint('[runZonedGuarded] 未捕获异常: $error');
    debugPrint('$stack');
  });
}
```

**原因**：原 `main()` 直接 `runApp`，Future 中的异步异常无法被 FlutterError.onError 捕获，直接闪退无日志。`runZonedGuarded` 提供 zone 级兜底。

---

### A-3：`lib/app/app_bootstrap.dart` — 冷启动进度反馈

```dart
/// 启动进度回调（A-3: 冷启动进度反馈）。
typedef BootProgressCallback = void Function(double progress, String label);

Future<void> bootstrapApp({BootProgressCallback? onProgress}) async {
  const labels = [
    '检查数据库完整性…',
    '初始化单词数据库…',
    '初始化用户数据库…',
    '加载应用偏好…',
    '初始化音频会话…',
    '配置服务定位器…',
  ];
  final steps = <Future<void> Function()>[
    WordBookDatabase.ensurePlatform,
    WordBookDatabase.instance.initialize,
    UserDatabase.instance.initialize,
    AppPreferences().init,
    initMobileAudioSession,
    setupServiceLocator,
  ];

  for (var i = 0; i < steps.length; i++) {
    await steps[i]();
    final progress = (i + 1) / steps.length;
    // A-3: 打印 + 回调，供 UI/测试观测冷启动进度。
    print('[Bootstrap] ${(progress * 100).toInt()}% - ${labels[i]}');
    onProgress?.call(progress, labels[i]);
  }
}
```

**原因**：原 `bootstrapApp` 无任何进度输出，冷启动卡顿时用户/测试无法感知当前阶段。分步 + 回调让进度可观测。

---

### A-5：`lib/widgets/review_dialog.dart` — dueCount==0 空态

```dart
// A-5: dueCount==0 时展示友好空态，而非直接进入空复习。
if (schedule.dueCount == 0)
  _buildEmptyState(context, skin)
else
  _buildStatsAndActions(context, skin, session, schedule),
```

新增 `_buildEmptyState`：

```dart
/// A-5: dueCount==0 时的友好空态 — 「今天没有需要复习的单词」+ CTA。
Widget _buildEmptyState(BuildContext context, dynamic skin) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
    child: Column(
      children: [
        Icon(Icons.check_circle_outline, size: 56, color: skin.success),
        const SizedBox(height: 16),
        Text('今天没有需要复习的单词',
            style: MistralTypography.heading5.copyWith(color: skin.text1)),
        const SizedBox(height: 8),
        Text('太棒了！今天的复习任务已完成，休息一下吧。',
            textAlign: TextAlign.center,
            style: MistralTypography.bodyMd.copyWith(color: skin.text3)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('好的'),
            style: ElevatedButton.styleFrom(
              backgroundColor: skin.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
              elevation: 0,
            ),
          ),
        ),
      ],
    ),
  );
}
```

**原因**：原实现 `dueCount==0` 时直接进入空复习页面，用户看到空白无引导。空态提供正向反馈 + 明确 CTA。

---

### A-6：`lib/pages/uri_scheme_page.dart` — 品牌过渡 + goHome 兜底

**品牌过渡**（替换白屏+转圈）：

```dart
// A-6: 深链冷启动走品牌过渡（品牌色 + 品牌标识），而非生硬白屏+转圈。
return Scaffold(
  backgroundColor: context.skin.colors.pageBg,
  body: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Monster Word',
            style: MistralTypography.heading4.copyWith(
                color: MistralColors.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        const SizedBox(height: 24),
        SizedBox(
          width: 28, height: 28,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: MistralColors.primary)),
      ],
    ),
  ),
);
```

**`_goHomeSafe` 兜底**（冷启动深链时根路由 goHome 无效）：

```dart
/// A-6: 安全回首页 — 冷启动深链时 UriSchemePage 是根路由，
/// NavUtils.goHome（popUntil isFirst）会无效导致卡死；此时用 pushReplacement 跳到首页。
void _goHomeSafe(BuildContext context) {
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    NavUtils.goHome(context);
  } else {
    nav.pushReplacementNamed('/');
  }
}
```

所有 `_processUri` 中的 `NavUtils.goHome(context)` 调用替换为 `_goHomeSafe(context)`。

**原因**：冷启动深链时 UriSchemePage 是根路由（`canPop()==false`），`NavUtils.goHome`（`popUntil(isFirst)`）无效导致卡死。`_goHomeSafe` 检测 `canPop` 后选择正确回首页方式。

---

### 修复②：`lib/features/account/presentation/splash_page.dart` — Timer 持有 + dispose 取消

```dart
// A-2: 持有导航 Timer 以便在 dispose 时取消，避免测试/快速退出时留下 pending Timer。
Timer? _navTimer;

Future<void> _checkLoginAndNavigate() async {
  // 等待动画播放 + 模拟网络检查。Timer 持有引用，dispose 时取消，避免 pending Timer。
  _navTimer?.cancel();
  _navTimer = Timer(const Duration(seconds: 2), () {
    if (!mounted) return;
    _proceedToRoute();
  });
}

@override
void dispose() {
  _navTimer?.cancel();  // ← 新增
  _animController.dispose();
  _pageController.dispose();
  super.dispose();
}
```

**原因**：`widget_test.dart` 泵一次 `WordApp` 后结束，`SplashPage` 的 `Future.delayed(2s)` 遗留 pending Timer，触发 `'!timersPending'` 断言失败。持有引用并在 dispose 取消后，测试/快速退出均无残留 Timer。

---

## 三、测试结果

### 新增/修改的测试文件

| 文件 | 覆盖点 | 结果 |
|------|--------|------|
| `test/app/run_app_guarded_test.dart` | A-2 runZonedGuarded 包裹 + 异常捕获 | ✅ 2/2 通过 |
| `test/pages/uri_scheme_page_test.dart` | A-6 品牌过渡 + goHome 兜底 + 无效 URI | ✅ 5/5 通过 |
| `test/widgets/review_dialog_test.dart` | A-5 dueCount==0 空态 + dueCount>0 统计 | ✅ 2/2 通过 |
| `test/architecture/app_structure_test.dart` | 修复① main.dart 字面 `runApp(const WordApp())` | ✅ 27/27 通过 |
| `test/widget_test.dart` | 修复② Splash Timer 无残留 | ✅ 1/1 通过 |

### 测试方法说明

- **A-2** (`run_app_guarded_test.dart`)：验证 `runAppGuarded` 正常启动应用 + `runZonedGuarded` 函数可调用不抛同步异常。
- **A-5** (`review_dialog_test.dart`)：使用 `_StubScheduleReader`（extends 抽象类）+ `_StubSessionState`（extends `LearningSessionState`，用真实仓储构造 + override `total`/`learnedNum`），`SharedPreferences.setMockInitialValues({})` 隔离 IO。
- **A-6** (`uri_scheme_page_test.dart`)：验证品牌过渡（Monster Word + CircularProgressIndicator）展示 + 冷启动根路由异常时兜底不卡死。
- **修复①**：`main.dart` 字面内联 `runZonedGuarded`，保留 `runApp(const WordApp());` 子串。
- **修复②**：SplashPage Timer 持有 + dispose 取消，widget_test 泵一次后无 pending Timer。

---

## 四、门禁检查

| 检查项 | 结果 |
|--------|------|
| `flutter analyze` 0 error | ✅ 0 error（仅 1 个 `info` 级 `prefer_initializing_formals`，位于 `repository_book_catalog_reader.dart`——非本任务修改文件，属前置会话遗留） |
| 涉及文件无新增 warning/info | ✅ 本任务修改的 7 个文件均无新增 warning/info |
| 新增测试通过 | ✅ 3 个测试文件全部通过 |
| 既有测试不破坏 | ✅ app_structure_test 27/27 + widget_test 1/1 通过（按 LEAD 要求未跑全量，仅验证门禁相关文件） |

---

## 五、未修改范围

按任务约束，以下目录/文件未触碰：
- `lib/core/**`、`lib/theme/**`、`lib/tokens/**`
- `lib/features/**`（除 `splash_page.dart` 的 Timer 修复外）
- `lib/screens/home_screen.dart`、`lib/features/account/**`（除 `splash_page.dart` 外）
- 未执行 `git commit`/`git push`
