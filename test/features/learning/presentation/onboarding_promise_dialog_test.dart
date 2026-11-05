// 首启引导：三步递进、承诺只在最后一步出现、可跳过。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/learning/application/onboarding_gate_store.dart';
import 'package:word_app/features/learning/presentation/onboarding_promise_dialog.dart';
import 'package:word_app/theme/skin_system.dart';

Widget _host() => MaterialApp(
  home: SkinProvider(
    skin: SkinSystem(),
    child: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(onPressed: () => showOnboardingPromiseDialog(context), child: const Text('展示')),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('打开即第 1 步，不提前出现承诺', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('展示'));
    await tester.pumpAndSettle();

    expect(find.text('第 1 / 3 步'), findsOneWidget);
    expect(find.text(onboardingSteps[0].line), findsOneWidget);
    expect(find.text(onboardingPromise), findsNothing);
  });

  testWidgets('下一步递进到第 3 步才出现承诺与主按钮', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('展示'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('第 2 / 3 步'), findsOneWidget);
    expect(find.text(onboardingSteps[1].line), findsOneWidget);
    expect(find.text(onboardingPromise), findsNothing);

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('第 3 / 3 步'), findsOneWidget);
    expect(find.text(onboardingSteps[2].line), findsOneWidget);
    expect(find.text(onboardingPromise), findsOneWidget);
    expect(find.text('开始今天的第一个词'), findsOneWidget);
  });

  testWidgets('跳过：直接关闭，不进入第二步', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('展示'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();

    expect(find.text('第 1 / 3 步'), findsNothing);
    expect(find.text('展示'), findsOneWidget);
  });
}
