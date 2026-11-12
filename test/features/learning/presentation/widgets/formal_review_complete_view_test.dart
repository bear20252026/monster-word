import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/utils/boss_siege.dart';
import 'package:word_app/features/learning/presentation/widgets/formal_review_state_views.dart';
import 'package:word_app/theme/skin_system.dart';
import 'package:word_app/widgets/confetti.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: SkinProvider(skin: SkinSystem(), child: child),
);

void _noop() {}

void main() {
  testWidgets('头目战完成页：退场台词替换普通收尾文案，庆典只播一次', (tester) async {
    var celebrations = 0;
    await tester.pumpWidget(
      _wrap(
        FormalReviewCompleteView(
          done: 40,
          onReturnHome: _noop,
          bossBattle: true,
          celebrationOverride: () => celebrations++,
        ),
      ),
    );
    await tester.pump(); // 让 post-frame 庆典执行

    expect(find.text(bossVictoryLine), findsOneWidget);
    expect(find.text(siegeVictoryLine), findsNothing);
    expect(celebrations, 1);

    // 父级重建（同一位置同一类型）不得让庆典再播一次：_celebrated 是唯一开关。
    await tester.pumpWidget(
      _wrap(
        FormalReviewCompleteView(
          done: 40,
          onReturnHome: _noop,
          bossBattle: true,
          celebrationOverride: () => celebrations++,
        ),
      ),
    );
    await tester.pump();

    expect(celebrations, 1, reason: '一局只播一次庆典');
  });

  testWidgets('一题没答（done==0）不宣称守城成功', (tester) async {
    await tester.pumpWidget(_wrap(const FormalReviewCompleteView(done: 0, onReturnHome: _noop, bossBattle: true)));

    expect(find.text(bossVictoryLine), findsNothing);
    expect(find.text(siegeQuietLine), findsOneWidget);
  });

  testWidgets('普通复习局保持 v1 文案，不抢头目退场台词', (tester) async {
    var celebrations = 0;
    await tester.pumpWidget(
      _wrap(FormalReviewCompleteView(done: 3, onReturnHome: _noop, celebrationOverride: () => celebrations++)),
    );
    await tester.pump();

    expect(find.text('已把今天到期的单词又牢牢记住了一遍'), findsOneWidget);
    expect(find.text(bossVictoryLine), findsNothing);
    expect(celebrations, 1);
  });

  testWidgets('守城庆典挂爆炸式彩带（设计稿第五节口径）', (tester) async {
    await tester.pumpWidget(_wrap(const FormalReviewCompleteView(done: 40, onReturnHome: _noop, bossBattle: true)));
    await tester.pump();

    final overlay = tester.widget<ConfettiOverlay>(find.byType(ConfettiOverlay));
    expect(overlay.direction, ConfettiDirection.explosion);
    // 彩带层包住了完成环与返回按钮（整个 body）。
    expect(find.descendant(of: find.byType(ConfettiOverlay), matching: find.text('今日复习完成！')), findsOneWidget);
  });
}
