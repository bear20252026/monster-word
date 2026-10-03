// PetalBadge 花齿义项序号徽章：渲染存在性测试
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/widgets/petal_badge.dart';

void main() {
  testWidgets('缺省渲染序号数字与花齿 painter', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: PetalBadge(index: 3))),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    final painters = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
    expect(painters.any((p) => p.painter is PetalFlowerPainter), isTrue);
  });

  testWidgets('自定义 child 优先于缺省序号，size 生效', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PetalBadge(index: 2, size: 20, child: Text('A'))),
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('2'), findsNothing);
    final badge = tester.getSize(find.byType(PetalBadge));
    expect(badge.width, 20);
    expect(badge.height, 20);
  });
}
