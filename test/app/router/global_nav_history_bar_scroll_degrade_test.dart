// 全局前进/返回 pill 背景模糊滚动降级行为测试（perf 2026-09-28）。
// 契约：静止时带 BackdropFilter 毛玻璃；滚动中撤滤镜换近实底；
// 滚动结束 MotionDurations.base 后恢复模糊。
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/app/router/global_nav_history_bar.dart';
import 'package:word_app/app/router/navigation_history.dart';

Future<void> _pumpBar(WidgetTester tester) async {
  // 与生产装配同构：MaterialApp.builder 内包 Navigator（app.dart:157），
  // pill 的 Stack 因此位于 Directionality 之下，滚动通知沿
  // Scrollable → Navigator → builder 层冒泡。
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => GlobalNavHistoryBar(history: NavigationHistoryService.instance, child: child!),
      home: Scaffold(
        body: ListView.builder(itemCount: 200, itemBuilder: (context, i) => ListTile(title: Text('条目 $i'))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// pill 仅桌面端渲染。测试默认平台是 android，覆盖为 windows；
/// debug 变量必须在测试体内恢复（addTearDown 晚于框架不变量校验）。
Future<void> _desktop(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  testWidgets('静止时 pill 带 BackdropFilter 毛玻璃', (tester) async {
    await _desktop(() async {
      await _pumpBar(tester);
      expect(find.byType(GlobalNavHistoryBar), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });

  testWidgets('滚动中撤掉 BackdropFilter，背景转近实底', (tester) async {
    await _desktop(() async {
      await _pumpBar(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -160));
      await tester.pump();

      // 滚动进行中：滤镜已撤（ballistic 未结束，settle 定时器未到期）
      expect(find.byType(BackdropFilter), findsNothing);
      // 近实底：pill 容器 alpha 提到 0.94
      final pillContainer = tester.widget<Container>(
        find.ancestor(of: find.byIcon(Icons.arrow_back_ios_new_rounded), matching: find.byType(Container)).first,
      );
      expect((pillContainer.decoration as BoxDecoration).color!.a, closeTo(0.94, 0.001));
    });
  });

  testWidgets('滚动结束约 base 时长后恢复毛玻璃', (tester) async {
    await _desktop(() async {
      await _pumpBar(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -160));
      await tester.pump();
      expect(find.byType(BackdropFilter), findsNothing);

      // ballistic 结束 → ScrollEnd → 200ms settle 定时器到期恢复
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });
}
