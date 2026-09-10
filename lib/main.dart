import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:word_app/app/app.dart';
import 'package:word_app/app/app_bootstrap.dart';
import 'package:word_app/core/infrastructure/sentry_bootstrap.dart';

Future<void> main() async {
  // Zone 契约：runZonedGuarded 必须包住 bootstrapApp + runApp 的全部流程。
  // WidgetsFlutterBinding.ensureInitialized()（bootstrapApp 内）与 runApp 一旦
  // 落在不同 zone，Flutter 每次冷启动都会打 Zone mismatch 告警。
  // 守卫：test/regression/regression_zone001_boot_zone_test.dart。
  runZonedGuarded(() => unawaited(_bootstrapAndRun()), (error, stack) {
    debugPrint('[runZonedGuarded] 未捕获异常: $error');
    debugPrint('$stack');
    // 转发到 Sentry（未启用时为 no-op）
    Sentry.captureException(error, stackTrace: stack);
  });
}

Future<void> _bootstrapAndRun() async {
  await bootstrapApp();
  // A-2: 异步异常不再无兜底崩溃；Sentry 接管后未捕获异常同时上报后台（DSN 走 --dart-define）。
  await runAppWithSentry(() {
    runApp(const WordApp()); // 字面必须含这一行，app_structure_test 靠它
  });
}
