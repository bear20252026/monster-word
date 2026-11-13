// 路线地图三态：空数据 / 部分完成 / 全部完成（只有当前节点彩色）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/learning/application/home_path.dart';
import 'package:word_app/features/home/presentation/home_path_map.dart';
import 'package:word_app/theme/skin_system.dart';

Widget _host(List<HomePathNode> nodes, {ValueChanged<int>? onTap}) => MaterialApp(
  home: SkinProvider(
    skin: SkinSystem(),
    child: Scaffold(
      body: HomePathMap(nodes: nodes, onNodeTap: onTap ?? (_) {}),
    ),
  ),
);

Finder _currentDot() => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('path-node-current-'),
);

void main() {
  testWidgets('空数据：热身是唯一当前节点', (tester) async {
    await tester.pumpWidget(_host(buildHomePathNodes(goal: 10, learned: 0, due: 5)));

    expect(find.text('第 1 / 4 步'), findsOneWidget);
    expect(_currentDot(), findsOneWidget);
    expect(find.byKey(const ValueKey('path-node-current-warmup')), findsOneWidget);
    expect(find.text('待复习 5 个'), findsOneWidget);
  });

  testWidgets('部分完成：新词变当前，热身打勾', (tester) async {
    await tester.pumpWidget(_host(buildHomePathNodes(goal: 10, learned: 3, due: 0)));

    expect(find.text('第 2 / 4 步'), findsOneWidget);
    expect(_currentDot(), findsOneWidget);
    expect(find.byKey(const ValueKey('path-node-current-newWords')), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2), reason: '热身与复习均已完成');
  });

  testWidgets('全部完成：没有当前节点，四节点全打勾', (tester) async {
    await tester.pumpWidget(_host(buildHomePathNodes(goal: 10, learned: 10, due: 0)));

    expect(find.text('已走完'), findsOneWidget);
    expect(_currentDot(), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(4));
  });

  testWidgets('节点可点（后续节点不锁死），回调带下标', (tester) async {
    final nodes = buildHomePathNodes(goal: 10, learned: 0, due: 5);
    var tapped = -1;
    await tester.pumpWidget(_host(nodes, onTap: (index) => tapped = index));

    await tester.tap(find.byKey(const ValueKey('path-node-review')));
    await tester.pump();

    expect(tapped, 2);
  });
}
