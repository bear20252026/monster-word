// SoundRipple 发音涟漪：pulse 触发后 AnimationController 运行、一轮后自停
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/widgets/sound_ripple.dart';

void main() {
  testWidgets('pulse 后 controller 运行，1.2s 一轮跑完自停', (tester) async {
    final trigger = SoundRippleController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: SoundRipple(trigger: trigger, size: 28)),
        ),
      ),
    );

    final state = tester.state<SoundRippleState>(find.byType(SoundRipple));
    expect(state.controller.isAnimating, isFalse);

    trigger.pulse();
    await tester.pump();
    expect(state.controller.isAnimating, isTrue);

    await tester.pump(const Duration(milliseconds: 1250));
    expect(state.controller.isAnimating, isFalse);
  });

  testWidgets('child 正常渲染（发音图标）', (tester) async {
    final trigger = SoundRippleController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SoundRipple(trigger: trigger, child: Icon(Icons.volume_up_outlined, size: 28)),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
  });
}
