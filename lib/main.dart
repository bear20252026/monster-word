import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:word_app/app/app.dart';
import 'package:word_app/app/app_bootstrap.dart';

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
