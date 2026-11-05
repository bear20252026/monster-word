// 围城条带 HUD：敌列数量必须等于「剩余未答数」，且只吃两个整数入参。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/utils/boss_siege.dart';
import 'package:word_app/features/learning/presentation/widgets/boss_siege_header.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/widgets/monster_icon.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: SkinProvider(
    skin: SkinSystem(),
    child: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('未答：敌列 = 全部到期数，文案报真实剩余', (tester) async {
    await tester.pumpWidget(_wrap(const BossSiegeHeader(done: 0, total: 5)));

    expect(find.byType(MonsterIcon), findsNWidgets(5));
    expect(find.text('门外还有 5 只在转悠'), findsOneWidget);
  });

  testWidgets('答掉 3 题：敌列少 3 只（done 驱动，不另设计数器）', (tester) async {
    await tester.pumpWidget(_wrap(const BossSiegeHeader(done: 0, total: 5)));
    expect(find.byType(MonsterIcon), findsNWidgets(5));

    await tester.pumpWidget(_wrap(const BossSiegeHeader(done: 3, total: 5)));
    expect(find.byType(MonsterIcon), findsNWidgets(2));
    expect(find.text('门外还有 2 只在转悠'), findsOneWidget);
  });

  testWidgets('全清：敌列空场 + 守住陈述', (tester) async {
    await tester.pumpWidget(_wrap(const BossSiegeHeader(done: 8, total: 8)));

    expect(find.byType(MonsterIcon), findsNothing);
    expect(find.text(siegeNarrative(SiegeTier.cleared, 0)), findsOneWidget);
  });

  testWidgets('超过 12 只：画满 12 只并进 +N（不把答题区挤没）', (tester) async {
    await tester.pumpWidget(_wrap(const BossSiegeHeader(done: 0, total: 37)));

    expect(find.byType(MonsterIcon), findsNWidgets(maxVisibleMarauders));
    expect(find.text('+${37 - maxVisibleMarauders}'), findsOneWidget);
    // 37 只仍是「围城」档；≥40（与心情机 worried 同阈值）才升到大军压境。
    expect(find.text('门口围着 37 只捣蛋兽'), findsOneWidget);
  });

  testWidgets('≥40 只升到大军压境档', (tester) async {
    await tester.pumpWidget(_wrap(const BossSiegeHeader(done: 0, total: legionDueThreshold)));

    expect(find.text('大军压境：40 只捣蛋兽堵在门口'), findsOneWidget);
  });

  testWidgets('total<=0 时空场：一题没得答就不摆敌人', (tester) async {
    await tester.pumpWidget(_wrap(const BossSiegeHeader(done: 0, total: 0)));

    expect(find.byType(MonsterIcon), findsNothing);
    expect(find.textContaining('捣蛋兽'), findsNothing);
  });

  testWidgets('bossActive=false：只有 v1 喽啰行，不出现头目行与细进度条', (tester) async {
    await tester.pumpWidget(_wrap(const BossSiegeHeader(done: 0, total: legionDueThreshold)));

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text(bossNarrative(remaining: legionDueThreshold)), findsNothing);
  });

  testWidgets('bossActive：头目行 + 步数标签 + 2px 细进度条一起出现', (tester) async {
    const label = '第 1 / 40 步 · 还剩 40 步';
    await tester.pumpWidget(
      _wrap(const BossSiegeHeader(done: 0, total: legionDueThreshold, bossActive: true, stepLabel: label)),
    );

    // 1 只头目 + 12 只喽啰（40 只时敌列封顶）。
    expect(find.byType(MonsterIcon), findsNWidgets(1 + maxVisibleMarauders));
    expect(find.text(bossNarrative(remaining: legionDueThreshold)), findsOneWidget);
    expect(find.text(label), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('大军压境：40 只捣蛋兽堵在门口'), findsOneWidget);
  });

  testWidgets('头目行随 done 推进：步数文案与细进度条同步', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const BossSiegeHeader(done: 39, total: legionDueThreshold, bossActive: true, stepLabel: '第 40 / 40 步 · 还剩 1 步'),
      ),
    );

    expect(find.text('第 40 / 40 步 · 还剩 1 步'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, closeTo(39 / legionDueThreshold, 1e-9));
  });

  testWidgets('护盾段：容量 4 段；done 跨 10 后第一段变灰，其余保持强调色', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const BossSiegeHeader(
          done: 9,
          total: legionDueThreshold,
          bossActive: true,
          shieldSegments: 0,
          shieldCapacity: 4,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('boss-shield-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('boss-shield-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('boss-shield-4')), findsNothing);
    expect(_segmentColor(tester, 0), _segmentColor(tester, 1), reason: '未裂开时四段同色');

    await tester.pumpWidget(
      _wrap(
        const BossSiegeHeader(
          done: 10,
          total: legionDueThreshold,
          bossActive: true,
          shieldSegments: 1,
          shieldCapacity: 4,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(_segmentColor(tester, 0), isNot(_segmentColor(tester, 1)), reason: '第一段裂开变灰');
  });

  testWidgets('当日首次入场：pendingIntro 保持冻结，450ms 后交回协调层转 active', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      _wrap(
        BossSiegeHeader(
          done: 0,
          total: legionDueThreshold,
          bossActive: true,
          bossIntroPending: true,
          shieldSegments: 0,
          shieldCapacity: 4,
          stepLabel: '第 1 / 40 步 · 还剩 40 步',
          onIntroFinished: () => finished++,
        ),
      ),
    );

    final fade = tester.widget<FadeTransition>(find.byKey(const ValueKey('boss-intro-fade')));
    expect(fade.opacity.value, 0, reason: '入场从透明开始');
    await tester.pump(const Duration(milliseconds: 200));
    expect(finished, 0, reason: '450ms 未到，仍在入场');
    expect(fade.opacity.value, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(finished, 1, reason: '入场演完只回调一次');
  });

  testWidgets('reduce-motion：跳过 450ms 动画，立即交回 active', (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

    var finished = 0;
    await tester.pumpWidget(
      _wrap(
        BossSiegeHeader(
          done: 0,
          total: legionDueThreshold,
          bossActive: true,
          bossIntroPending: true,
          shieldSegments: 0,
          shieldCapacity: 4,
          onIntroFinished: () => finished++,
        ),
      ),
    );

    await tester.pump();
    expect(finished, 1);
    final fade = tester.widget<FadeTransition>(find.byKey(const ValueKey('boss-intro-fade')));
    expect(fade.opacity.value, 1, reason: '降级为直接显示');
  });
}

Color? _segmentColor(WidgetTester tester, int index) {
  final box = tester.widget<AnimatedContainer>(find.byKey(ValueKey('boss-shield-$index')));
  final decoration = box.decoration;
  return decoration is BoxDecoration ? decoration.color : null;
}
