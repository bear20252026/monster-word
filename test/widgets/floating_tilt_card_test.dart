// FloatingTiltCard 桌面悬浮（指针倾斜/抬升/眩光）行为测试
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/widgets/floating_tilt_card.dart';

const _cardKey = ValueKey('tilt-card');

Future<TestGesture> _hoverMouse(WidgetTester tester, Offset target) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse, pointer: 7);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(target);
  return gesture;
}

void main() {
  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 100,
              height: 80,
              child: FloatingTiltCard(
                key: _cardKey,
                borderRadius: BorderRadius.circular(8),
                cursor: SystemMouseCursors.click,
                // SizedBox.expand 让 ColoredBox 撑满卡片（有尺寸才可被指针命中，
                // 真实页面中封面 Container 自带撑满的 child，同此理）。
                child: const ColoredBox(color: Colors.teal, child: SizedBox.expand()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Transform tiltTransform(WidgetTester tester) =>
      tester.widget<Transform>(find.descendant(of: find.byKey(_cardKey), matching: find.byType(Transform)));

  testWidgets('静止时无抬升、无眩光', (tester) async {
    await pumpCard(tester);

    expect(tiltTransform(tester).transform.storage[13], moreOrLessEquals(0));
    // 眩光/光带两层 Opacity 均为 0
    final glows = tester.widgetList<Opacity>(find.byType(Opacity)).map((o) => o.opacity);
    expect(glows, everyElement(0));
  });

  testWidgets('悬停时朝指针倾斜并抬升，眩光出现', (tester) async {
    await pumpCard(tester);

    // 指针停在卡片偏右上：应有 rotateY（m0 偏离 1）与抬升（ty < 0）
    final center = tester.getCenter(find.byKey(_cardKey));
    final gesture = await _hoverMouse(tester, center + const Offset(30, -20));
    // 第一帧投递 hover 并启动动画，第二帧推进时钟至完成
    await tester.pump();
    await tester.pumpAndSettle();

    final storage = tiltTransform(tester).transform.storage;
    expect(storage[0], isNot(moreOrLessEquals(1.0)));
    expect(storage[13], lessThan(0));

    // 眩光/光带不透明度 > 0
    final glows = tester.widgetList<Opacity>(find.byType(Opacity)).map((o) => o.opacity);
    expect(glows.any((o) => o > 0), isTrue);

    // 移出后回落
    await gesture.moveTo(const Offset(5, 5));
    await tester.pumpAndSettle();
    final rest = tiltTransform(tester).transform.storage;
    expect(rest[13], moreOrLessEquals(0));
    expect(rest[0], moreOrLessEquals(1.0));
  });

  testWidgets('减弱动态效果时无指针动效，仅保留可点光标', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 100,
                height: 80,
                child: FloatingTiltCard(
                  key: _cardKey,
                  cursor: SystemMouseCursors.click,
                  child: const ColoredBox(color: Colors.teal, child: SizedBox.expand()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 卡片子树内无 Transform / Opacity 动效层
    expect(find.descendant(of: find.byKey(_cardKey), matching: find.byType(Transform)), findsNothing);
    expect(find.descendant(of: find.byKey(_cardKey), matching: find.byType(Opacity)), findsNothing);

    // MouseRegion 保留且光标仍可点
    final region = tester.widget<MouseRegion>(
      find.descendant(of: find.byKey(_cardKey), matching: find.byType(MouseRegion)),
    );
    expect(region.cursor, SystemMouseCursors.click);
  });
}
