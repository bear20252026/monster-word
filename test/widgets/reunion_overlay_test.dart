// ReunionOverlay 回家仪式：门缝演出/自动关/防重入。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/widgets/reunion_overlay.dart';

Future<void> _pumpHost(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox.expand())));
}

void main() {
  testWidgets('show 后门缝与文案可见，2s 后自动移除', (tester) async {
    await _pumpHost(tester);
    final hostContext = tester.state(find.byType(Scaffold)).context;

    showReunionOverlay(hostContext, absentDays: 5);
    await tester.pump();
    // 滑入段完成（300ms）后文案完整可见。
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.textContaining('我就知道你会回来'), findsOneWidget);
    expect(find.textContaining('5 天不见'), findsOneWidget);

    // 总时长 300+1200+400=1900ms（≤2s 预算）后自移除。
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();
    expect(find.textContaining('我就知道你会回来'), findsNothing);
  });

  testWidgets('演出中重复 show 被串行忽略', (tester) async {
    await _pumpHost(tester);
    final hostContext = tester.state(find.byType(Scaffold)).context;

    showReunionOverlay(hostContext, absentDays: 3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    showReunionOverlay(hostContext, absentDays: 9);
    await tester.pump();

    expect(find.textContaining('3 天不见'), findsOneWidget);
    expect(find.textContaining('9 天不见'), findsNothing);
  });
}
