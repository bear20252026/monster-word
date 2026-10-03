// MonsterPeekOverlay 探头演出：挂载即入演、总时长后自移除、演出中重入忽略
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/widgets/monster_peek_overlay.dart';

/// 最小宿主：无账本语境（ScareCoinStore 缺省，探头形态走默认 0 奶泡）。
Future<void> _pumpHost(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox.expand())));
}

void main() {
  testWidgets('show 后 Overlay 里出现探头演出（phrase 气泡可见）', (tester) async {
    await _pumpHost(tester);
    final hostContext = tester.state(find.byType(Scaffold)).context;

    MonsterPeekOverlay.show(hostContext, phrase: '小怪兽为你欢呼！');
    await tester.pump();

    expect(find.byType(Overlay), findsOneWidget);
    // 气泡在停留段（350ms 滑入完成后）弹出：先泵完滑入段，再泵过停留段起点
    // （t=0 时气泡仍为 shrink），气泡文本才真正入树。
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('小怪兽为你欢呼！'), findsOneWidget);
  });

  testWidgets('演出总时长（350+800+350=1500ms，≤1.6s）后自动滑出并移除', (tester) async {
    await _pumpHost(tester);
    final hostContext = tester.state(find.byType(Scaffold)).context;

    MonsterPeekOverlay.show(hostContext, phrase: '火力全开！');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('火力全开！'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text('火力全开！'), findsNothing);
  });

  testWidgets('演出中重复 show 被串行忽略（不叠层，只有一个气泡）', (tester) async {
    await _pumpHost(tester);
    final hostContext = tester.state(find.byType(Scaffold)).context;

    MonsterPeekOverlay.show(hostContext, phrase: '无可阻挡！');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 60));
    MonsterPeekOverlay.show(hostContext, phrase: '第二次请求');
    await tester.pump();

    expect(find.text('无可阻挡！'), findsOneWidget);
    expect(find.text('第二次请求'), findsNothing);

    // 首场演完后整体清场，被忽略的请求不会补演。
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text('无可阻挡！'), findsNothing);
    expect(find.text('第二次请求'), findsNothing);
  });
}
