// NavigationHistoryService 逻辑测试（多层级前进/返回）
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/router/navigation_history.dart';

void main() {
  testWidgets('didPush 入栈后 didPop 记录前进快照，goForward 可恢复', (tester) async {
    final service = NavigationHistoryService.instance;
    service.reset(); // 单例跨测试残留防护

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: service.navigatorKey,
        navigatorObservers: [service.observer],
        routes: {'/': (c) => const Text('home'), '/a': (c) => const Text('a'), '/b': (c) => const Text('b')},
        initialRoute: '/',
      ),
    );
    await tester.pumpAndSettle();
    // 初始无前进、可能可返回
    expect(service.canGoForward, isFalse);
    expect(service.mayGoBack, isFalse);

    // push 两层 → 多层级返回语义
    service.navigatorKey.currentState!.pushNamed('/a');
    await tester.pumpAndSettle();
    service.navigatorKey.currentState!.pushNamed('/b');
    await tester.pumpAndSettle();
    expect(service.canGoForward, isFalse);
    expect(service.currentRouteName, '/b');

    // pop /b → 出现前进项
    service.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(service.canGoForward, isTrue);
    expect(service.currentRouteName, '/a');

    // 再 push /b → 分叉作废前进栈（浏览器语义）
    service.navigatorKey.currentState!.pushNamed('/b');
    await tester.pumpAndSettle();
    expect(service.canGoForward, isFalse);

    // 连续 pop 回根（多层级返回），forward 栈应记录两级
    service.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    service.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(service.canGoForward, isTrue);
    expect(service.historyDepthForTest, 2);

    // goForward 恢复 /a
    service.goForward();
    await tester.pumpAndSettle();
    expect(find.text('a'), findsOneWidget);
    expect(service.canGoForward, isTrue);

    // 再 forward 恢复 /b，栈清空
    service.goForward();
    await tester.pumpAndSettle();
    expect(find.text('b'), findsOneWidget);
    expect(service.canGoForward, isFalse);

    // reset 清空
    service.reset();
    expect(service.canGoForward, isFalse);
  });

  testWidgets('弹层（PageRoute 之外）不进入导航历史', (tester) async {
    final service = NavigationHistoryService.instance;
    service.reset();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: service.navigatorKey,
        navigatorObservers: [service.observer],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(title: Text('dialog')),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // 关闭对话框（didPop 非 PageRoute 不入历史）
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect(service.canGoForward, isFalse);
  });
}
