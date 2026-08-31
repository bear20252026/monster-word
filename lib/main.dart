import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:word_app/app/app.dart';
import 'package:word_app/app/app_bootstrap.dart';
import 'package:word_app/core/infrastructure/sentry_bootstrap.dart';

Future<void> main() async {
  await bootstrapApp();
  // A-2: 用 runZonedGuarded 包裹 runApp，异步异常不再无兜底崩溃。
  // Sentry 接管后：未捕获异常会同时上报 Sentry 后台（DSN 走 --dart-define）。
  await runAppWithSentry(() {
    runZonedGuarded(
      () {
        runApp(const WordApp()); // 字面必须含这一行，app_structure_test 靠它
      },
      (error, stack) {
        debugPrint('[runZonedGuarded] 未捕获异常: $error');
        debugPrint('$stack');
        // 转发到 Sentry（未启用时为 no-op）
        Sentry.captureException(error, stackTrace: stack);
      },
    );
  });
}
