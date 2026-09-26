// FlowIn 有序流动入场行为测试
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/widgets/flow_in.dart';

Widget _host({required Widget child, bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(child: child),
    ),
  );
}

void main() {
  testWidgets('入场前不可见，结束后完全呈现', (tester) async {
    await tester.pumpWidget(
      _host(
        child: FlowIn(
          index: 0,
          child: const ColoredBox(color: Colors.green, child: SizedBox(width: 40, height: 40)),
        ),
      ),
    );

    final initial = tester.widget<Opacity>(find.byType(Opacity));
    expect(initial.opacity, lessThan(0.05));

    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1.0);
  });

  testWidgets('按索引波次：靠后的项起跑更晚', (tester) async {
    await tester.pumpWidget(
      _host(
        child: Column(
          children: [
            FlowIn(index: 0, child: const SizedBox(width: 40, height: 40)),
            FlowIn(index: 8, child: const SizedBox(width: 40, height: 40)),
          ],
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 120));
    final opacities = tester.widgetList<Opacity>(find.byType(Opacity)).toList();
    expect(opacities, hasLength(2));
    // 前 120ms：第一项已起步，第八项仍在等待
    expect(opacities[0].opacity, greaterThan(opacities[1].opacity));

    await tester.pumpAndSettle();
    expect(tester.widgetList<Opacity>(find.byType(Opacity)).every((o) => o.opacity == 1.0), isTrue);
  });

  testWidgets('减弱动态效果时直接呈现最终态', (tester) async {
    await tester.pumpWidget(
      _host(disableAnimations: true, child: FlowIn(index: 3, child: const SizedBox(width: 40, height: 40))),
    );

    expect(find.byType(Opacity), findsNothing);
  });
}
