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
}
