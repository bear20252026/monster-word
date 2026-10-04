// RollingNumber 滚动数字：中间帧递增、终帧达值、样式透传。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/widgets/rolling_number.dart';

void main() {
  testWidgets('value 变化：中间帧递增，终帧等于目标值', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RollingNumber(value: 10))));

    // 首帧即显示初值。
    expect(find.text('10'), findsOneWidget);

    // 变更目标 → 推进到中段：显示中间值（严格递增且小于终值）。
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RollingNumber(value: 99))));
    await tester.pump(const Duration(milliseconds: 150));
    final midText = tester.widget<Text>(find.byType(Text)).data!;
    final mid = int.parse(midText);
    expect(mid, greaterThan(10), reason: '中段应已开始滚动');
    expect(mid, lessThan(99), reason: '150ms 未到终值');

    // 推进到结束：精确到达 99。
    await tester.pumpAndSettle();
    expect(find.text('99'), findsOneWidget);
  });

  testWidgets('动画中途换目标：从当前显示值继续滚，不跳回旧目标', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RollingNumber(value: 0))));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RollingNumber(value: 100))));
    await tester.pump(const Duration(milliseconds: 150));
    final midway = int.parse(tester.widget<Text>(find.byType(Text)).data!);
    expect(midway, greaterThan(0));
    expect(midway, lessThan(100));

    // 半程改目标：新 tween 起点应是「正在显示的值」，而非旧目标 100 或初始 0（审计 P2-2 次项）。
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RollingNumber(value: 200))));
    await tester.pump();
    expect(int.parse(tester.widget<Text>(find.byType(Text)).data!), midway, reason: '应从当前显示值接续滚动');

    await tester.pumpAndSettle();
    expect(find.text('200'), findsOneWidget);
  });

  testWidgets('style 透传：字号颜色生效', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RollingNumber(value: 7, style: TextStyle(fontSize: 21, color: Color(0xFF123456))),
        ),
      ),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.style?.fontSize, 21);
    expect(text.style?.color, const Color(0xFF123456));
  });
}
