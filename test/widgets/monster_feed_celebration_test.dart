// MonsterFeedCelebration 吃币庆祝：渲染存在性与 >12 截断 +N 断言。
// 组件不依赖皮肤系统（MonsterIcon 内部对 SkinProvider 有裸 MaterialApp 兜底），可直接泵。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/widgets/coin_swallow_celebration.dart';
import 'package:word_app/widgets/monster_feed_celebration.dart';
import 'package:word_app/widgets/monster_icon.dart';

void main() {
  testWidgets('coinCount=5：怪兽 + 5 枚金币渲染，无截断徽标', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: MonsterFeedCelebration(coinCount: 5))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byType(MonsterIcon), findsOneWidget);
    expect(find.byType(CoinBadge), findsNWidgets(5));
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('coinCount=15：只飞 12 枚金币，显示 +3 截断徽标', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: MonsterFeedCelebration(coinCount: 15))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    // 12 枚实飞金币全程挂载（透明度控显隐），多余 3 枚折算成「+3」徽标。
    expect(find.byType(CoinBadge), findsNWidgets(12));
    expect(find.text('+3'), findsOneWidget);
  });
}
