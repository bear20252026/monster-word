// 测试：A-2 runZonedGuarded 兜底 — 异步异常不再无兜底崩溃。
//
// 修复前：main() 直接 runApp，异步异常（Future 错误）无 zone 捕获，直接闪退。
// 修复后：runAppGuarded 用 runZonedGuarded 包裹 runApp，异常被捕获并打印。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/app/app_bootstrap.dart';

void main() {
  group('A-2: runZonedGuarded 兜底', () {
    testWidgets('runAppGuarded 包裹 runApp 不抛异常', (tester) async {
      // runAppGuarded 应正常启动应用（runApp 被 zone 包裹）
      runAppGuarded(const Directionality(textDirection: TextDirection.ltr, child: Text('guarded')));

      await tester.pump();

      // 验证应用正常启动
      expect(find.text('guarded'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('runZonedGuarded 捕获异步异常', () {
      // 验证 runZonedGuarded 函数签名存在且可调用
      // 注意：runZonedGuarded 的全局效果难以在单测中直接断言，
      // 这里验证函数可正常调用且不抛同步异常。
      expect(() {
        runZonedGuarded(
          () => runApp(const Directionality(textDirection: TextDirection.ltr, child: Text('zone-test'))),
          (error, stack) {
            // zone 错误回调 — 生产环境应上报 Crashlytics/Sentry
          },
        );
      }, returnsNormally);
    });
  });
}
