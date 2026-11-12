// 命名仪式性格选择：落库、进程缓存同步、破壳后台词预览、引导闸门合并。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/app/router/app_router.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/core/utils/monster_identity_prefs.dart';
import 'package:word_app/core/utils/monster_personality.dart';
import 'package:word_app/core/utils/monster_speech.dart';
import 'package:word_app/features/account/presentation/monster_hatching_page.dart';
import 'package:word_app/features/learning/application/onboarding_gate_store.dart';

/// 页面整体可滚动（小屏一屏放不下）：点击前先滚到可见。
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _hatch(WidgetTester tester, {VoidCallback? onFinished}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MonsterHatchingPage(onFinished: onFinished),
      // 引导经命名路由串演（R4 路由契约），测试装配同款路由生成。
      onGenerateRoute: (settings) =>
          AppRouter.buildPageRoute(settings, AppRouter.buildPage(settings) ?? const SizedBox.shrink()),
    ),
  );
  for (final label in ['敲三下（0/3）', '敲三下（1/3）', '敲三下（2/3）']) {
    await _tapVisible(tester, find.text(label));
  }
}

/// 引导对话已串演：点「跳过」关闭（跳过也落标，与生产口径一致）。
Future<void> _dismissOnboarding(WidgetTester tester) async {
  await tester.pumpAndSettle();
  expect(find.text('跳过'), findsOneWidget, reason: '破壳后应串演首启引导');
  await tester.tap(find.text('跳过'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // 引导闸门走 AppPreferences（非裸 SP），须显式初始化。
    await AppPreferences().init();
    MonsterSpeech.resetForTest();
  });

  tearDown(() {
    MonsterIdentityPrefs.resetForTest();
    MonsterSpeech.resetForTest();
  });

  testWidgets('选倔强性格：落库 + 进程缓存同步 + 引导闸门合并', (tester) async {
    var finished = false;
    await _hatch(tester, onFinished: () => finished = true);

    // 破壳后出现性格选择卡与按性格的第一句话。
    expect(find.byKey(const Key('personality_stubborn')), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('personality_stubborn')));

    await _tapVisible(tester, find.text('开始冒险！'));
    await _dismissOnboarding(tester);
    expect(finished, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('monster_personality'), 'stubborn');
    expect(prefs.getString('monster_name'), '咕噜');
    expect(MonsterSpeech.currentPersonality, MonsterPersonality.stubborn, reason: '保存后进程缓存即刻生效');
    expect(const OnboardingGateStore().done, isTrue, reason: '引导并入仪式后首页不再二弹');
  });

  testWidgets('默认不选 = 活泼（老口径兼容）', (tester) async {
    await _hatch(tester, onFinished: () {});
    await _tapVisible(tester, find.text('开始冒险！'));
    await _dismissOnboarding(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('monster_personality'), 'lively');
    expect(MonsterSpeech.currentPersonality, MonsterPersonality.lively);
  });

  testWidgets('破壳后换性格：第一句话跟着换（当场听见差异）', (tester) async {
    await _hatch(tester, onFinished: () {});

    // 先选安静，记下台词；再换活泼，台词必须来自另一组。
    await _tapVisible(tester, find.byKey(const Key('personality_calm')));
    final calmLines = personalityTemplates[MonsterPersonality.calm]![SpeechSlot.dailyGreeting]!.toSet();
    final livelyLines = personalityTemplates[MonsterPersonality.lively]![SpeechSlot.dailyGreeting]!.toSet();

    await _tapVisible(tester, find.byKey(const Key('personality_lively')));

    // 页面上当前展示的第一句话应属活泼组（无占位符子集）。
    final shown = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => livelyLines.contains(s) || calmLines.contains(s))
        .toList();
    expect(shown, isNotEmpty);
    expect(shown.every(livelyLines.contains), isTrue, reason: '换性格后预览台词必须来自新性格组');
  });

  testWidgets('引导已完成：破壳后不再重演', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_promise_done_v1': true});
    await AppPreferences().init();
    var finished = false;
    await _hatch(tester, onFinished: () => finished = true);
    await _tapVisible(tester, find.text('开始冒险！'));

    expect(find.text('跳过'), findsNothing, reason: '引导已完成不得重演');
    expect(finished, isTrue);
  });

  testWidgets('性格写失败：可见提示 + 可重试（四写全查语义）', (tester) async {
    MonsterIdentityPrefs.saveOverride = ({required String name, MonsterPersonality? personality}) async =>
        throw StateError('sp disk full');
    await _hatch(tester, onFinished: () {});
    await _tapVisible(tester, find.byKey(const Key('personality_calm')));
    await _tapVisible(tester, find.text('开始冒险！'));

    expect(find.text('名字没记上，再点一次「开始冒险」试试'), findsOneWidget);
    expect(find.text('开始冒险！'), findsOneWidget, reason: '不得软锁');

    MonsterIdentityPrefs.resetForTest();
    await _tapVisible(tester, find.text('开始冒险！'));
    await _dismissOnboarding(tester);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('monster_personality'), 'calm', reason: '重试保留所选性格');
  });
}
