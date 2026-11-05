// 首启引导闸门：三步对话文案齐备；「只出现一次」的读写口径。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/learning/application/onboarding_gate_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppPreferences().init();
  });

  test('三步对话 + 一句承诺齐备（文案自建、只正向）', () {
    expect(onboardingSteps, hasLength(3));
    for (final step in onboardingSteps) {
      expect(step.line.trim(), isNotEmpty);
      expect(step.caption.trim(), isNotEmpty);
    }
    expect(onboardingPromise, contains('不扣分'));
    expect(onboardingPromise, contains('不清零'));
  });

  test('默认未出现；markDone 之后只出现一次', () async {
    const gate = OnboardingGateStore();
    expect(gate.done, isFalse, reason: '新装默认要展示');

    expect(await gate.markDone(), isTrue);
    expect(gate.done, isTrue, reason: '关闭或跳过后落标，不再展示');

    // 再次写入仍为真，不会回退
    await gate.markDone();
    expect(gate.done, isTrue);
  });
}
