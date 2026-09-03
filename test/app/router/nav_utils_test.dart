// 由 Claude 团队生成 | Monster Word App
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/app/router/nav_utils.dart';

void main() {
  Future<void> pumpWithRoutes(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Text('ROOT')),
        routes: {
          '/a': (_) => const Scaffold(body: Text('A')),
          '/b': (_) => const Scaffold(body: Text('B')),
        },
      ),
    );
  }

  group('NavUtils.safePop', () {
    testWidgets('在栈中时可逐级 pop', (tester) async {
      await pumpWithRoutes(tester);
      final ctx = tester.element(find.text('ROOT'));
      Navigator.of(ctx).pushNamed('/a');
      await tester.pumpAndSettle();
      Navigator.of(ctx).pushNamed('/b');
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);

      NavUtils.safePop(ctx);
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('在根路由(不可返回)时不弹出 → 不黑屏', (tester) async {
      await pumpWithRoutes(tester);
      final ctx = tester.element(find.text('ROOT'));
      // 初始只有根路由
      NavUtils.safePop(ctx);
      await tester.pumpAndSettle();
      // 根路由仍在，未弹出任何页面
      expect(find.text('ROOT'), findsOneWidget);
    });
  });

  group('NavUtils.goHome', () {
    testWidgets('从深层弹到根路由(逐级回首页)', (tester) async {
      await pumpWithRoutes(tester);
      final ctx = tester.element(find.text('ROOT'));
      Navigator.of(ctx).pushNamed('/a');
      await tester.pumpAndSettle();
      Navigator.of(ctx).pushNamed('/b');
      await tester.pumpAndSettle();

      NavUtils.goHome(ctx);
      await tester.pumpAndSettle();
      expect(find.text('ROOT'), findsOneWidget);
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsNothing);
    });
  });
}
