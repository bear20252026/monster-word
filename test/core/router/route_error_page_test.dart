// 测试：RouteErrorPage 提供「返回首页」按钮，点击后调用 NavUtils.goHome。
//
// 修复前（AUD-5 P2-6）：错误页面缺少返回首页选项，用户陷入死胡同。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/router/route_error_page.dart';

void main() {
  testWidgets('RouteErrorPage 显示「返回首页」按钮', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RouteErrorPage(routeName: '/test', message: '测试错误'),
      ),
    );

    // 验证错误信息渲染
    expect(find.text('无法打开 /test'), findsOneWidget);
    expect(find.text('测试错误'), findsOneWidget);

    // 验证「返回首页」按钮存在
    expect(find.text('返回首页'), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });

  testWidgets('RouteErrorPage 点击「返回首页」按钮可触发导航', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RouteErrorPage(routeName: '/test', message: '测试'),
                ),
              );
            },
            child: const Text('进入错误页'),
          ),
        ),
      ),
    );

    // 导航到错误页
    await tester.tap(find.text('进入错误页'));
    await tester.pumpAndSettle();

    // 验证错误页渲染
    expect(find.text('返回首页'), findsOneWidget);

    // 点击返回首页按钮（应不抛异常）
    await tester.tap(find.text('返回首页'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
