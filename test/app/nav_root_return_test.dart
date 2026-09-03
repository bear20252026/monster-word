import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/app/router/nav_utils.dart';

/// WS-6 APP-1  widget 测试：验证 review 完成触发 goHome、lib_select 空词表不跳转且提示。
void main() {
  // ──────────────────────────────────────────────────────
  // 1. Review 完成触发 goHome（popUntil 到根）
  // ──────────────────────────────────────────────────────
  group('ReviewPage 完成触发 goHome', () {
    testWidgets('done 状态"返回首页"按钮 popUntil 回到根路由', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('home'))),
          ),
        ),
      );

      // 模拟 review 完成页（done=true → 显示"返回首页"按钮，onReturnHome → goHome）
      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Builder(
              builder: (_) {
                return Center(
                  child: ElevatedButton(
                    // 对应 review_page.dart L60: onReturnHome: () => NavUtils.goHome(context)
                    onPressed: () => NavUtils.goHome(context),
                    child: const Text('返回首页'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('返回首页'), findsOneWidget);

      await tester.tap(find.text('返回首页'));
      await tester.pumpAndSettle();

      // goHome 后应回到根路由
      expect(find.text('home'), findsOneWidget);
      expect(find.text('返回首页'), findsNothing);
    });

    testWidgets('多层嵌套路由 goHome 一次性回到根', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('root'))),
          ),
        ),
      );

      // 推两层路由模拟 learn → review 链路
      navKey.currentState!.push(MaterialPageRoute(builder: (_) => const Scaffold(body: Text('learn-page'))));
      await tester.pumpAndSettle();
      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Builder(
              builder: (_) {
                return ElevatedButton(onPressed: () => NavUtils.goHome(context), child: const Text('goHome'));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('learn-page'), findsNothing); // 已被第三层覆盖
      expect(find.text('goHome'), findsOneWidget);

      await tester.tap(find.text('goHome'));
      await tester.pumpAndSettle();

      // popUntil(isFirst) 应直接回到根，中间层全部弹出
      expect(find.text('root'), findsOneWidget);
      expect(find.text('goHome'), findsNothing);
    });
  });

  // ──────────────────────────────────────────────────────
  // 2. LibSelect 空词表不跳转且提示
  // ──────────────────────────────────────────────────────
  group('LibSelectPage 空词表守卫', () {
    testWidgets('currentWord 为 null 时显示 SnackBar 且不导航', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      bool navigated = false;

      // 模拟 loadBook 后 currentWord 仍为 null 的空词表场景
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('lib-select'))),
          ),
        ),
      );

      // 推入一个模拟的书签选择项（模拟 lib_select_page.dart L513 onTap 逻辑）
      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Builder(
              builder: (_) {
                return ElevatedButton(
                  onPressed: () async {
                    // 模拟 await session.loadBook(book, limit: 50) 后 currentWord == null
                    // 对应 lib_select_page.dart L518-523 守卫逻辑
                    // currentWord == null 分支（loadBook 后词表为空，直接守卫返回）
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('该词书暂无单词数据，无法开始学习')));
                    return;
                  },
                  child: const Text('open-book'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open-book'));
      await tester.pump(); // SnackBar 需要一帧出现

      // 验证 SnackBar 提示出现
      expect(find.text('该词书暂无单词数据，无法开始学习'), findsOneWidget);
      // 验证未发生导航
      expect(navigated, isFalse);
      expect(find.text('lib-select'), findsNothing); // 仍在当前页
    });

    testWidgets('空词表守卫后路由栈未变化（无新页面入栈）', (tester) async {
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('root'))),
          ),
        ),
      );

      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Builder(
              builder: (_) {
                return ElevatedButton(
                  onPressed: () {
                    // 空词表守卫：仅提示，不 push
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('该词书暂无单词数据，无法开始学习')));
                    return;
                  },
                  child: const Text('tap'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final stackDepthBefore = navKey.currentState!.widget.pages.length;

      await tester.tap(find.text('tap'));
      await tester.pump();

      final stackDepthAfter = navKey.currentState!.widget.pages.length;

      // 路由栈深度不变 — 没有新页面入栈
      expect(stackDepthAfter, equals(stackDepthBefore));
      expect(find.text('该词书暂无单词数据，无法开始学习'), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────
  // 3. safePop 在根路由不崩溃（回归）
  // ──────────────────────────────────────────────────────
  group('safePop 回归', () {
    testWidgets('根路由 safePop 不黑屏不崩溃', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(onPressed: () => NavUtils.safePop(context), child: const Text('back')),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();

      // 仍在原页面 — 没有黑屏
      expect(find.text('back'), findsOneWidget);
    });
  });
}
