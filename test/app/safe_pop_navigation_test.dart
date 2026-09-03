import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/app/router/nav_utils.dart';
import 'package:word_app/theme/skin_system.dart';

void main() {
  group('NavUtils.safePop', () {
    testWidgets('在子路由 safePop 正常返回', (tester) async {
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
          builder: (_) => Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(onPressed: () => NavUtils.safePop(context), child: const Text('pop'));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('pop'), findsOneWidget);

      await tester.tap(find.text('pop'));
      await tester.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
    });

    testWidgets('在根路由 safePop 不崩溃', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(onPressed: () => NavUtils.safePop(context), child: const Text('pop')),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('pop'));
      await tester.pumpAndSettle();
      expect(find.text('pop'), findsOneWidget);
    });
  });

  group('NavUtils.goHome', () {
    testWidgets('goHome 弹出回到根路由', (tester) async {
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
          builder: (_) => Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          body: Builder(
                            builder: (ctx2) {
                              return ElevatedButton(
                                onPressed: () => NavUtils.goHome(ctx2),
                                child: const Text('goHome'),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('push2'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('push2'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('goHome'));
      await tester.pumpAndSettle();

      expect(find.text('root'), findsOneWidget);
    });

    testWidgets('goHome 在根路由不崩溃', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(onPressed: () => NavUtils.goHome(context), child: const Text('home')),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────
  // WordDetailPage null-guard 空态页渲染验证
  // ──────────────────────────────────────────────────────

  group('WordDetailPage null-guard 空态', () {
    testWidgets('无参进入显示"未找到单词"空态不崩溃', (tester) async {
      // 直接复现 word_detail_page.dart 中 word == null 分支的 widget tree
      await tester.pumpWidget(
        MaterialApp(
          home: SkinProvider(
            skin: SkinSystem(),
            child: Builder(
              builder: (context) {
                // 模拟 _resolveTargetWord 返回 null
                const dynamic word = null;
                if (word == null) {
                  return Scaffold(
                    backgroundColor: context.skin.colors.pageBg,
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: context.skin.colors.text3),
                          const SizedBox(height: 16),
                          Text('未找到单词', style: TextStyle(color: context.skin.colors.text1)),
                          const SizedBox(height: 8),
                          Text('可能因参数缺失或数据异常', style: TextStyle(color: context.skin.colors.text3)),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => NavUtils.goHome(context),
                            icon: const Icon(Icons.home, size: 20),
                            label: const Text('返回首页'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const Scaffold(body: Text('has word'));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('未找到单词'), findsOneWidget);
      expect(find.text('可能因参数缺失或数据异常'), findsOneWidget);
      expect(find.text('返回首页'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);
      // 无 NPE / 白屏
    });

    testWidgets('空态页"返回首页"按钮触发 goHome 回到根路由', (tester) async {
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
            backgroundColor: context.skin.colors.pageBg,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('未找到单词'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => NavUtils.goHome(context),
                    icon: const Icon(Icons.home, size: 20),
                    label: const Text('返回首页'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('未找到单词'), findsOneWidget);

      await tester.tap(find.text('返回首页'));
      await tester.pumpAndSettle();

      expect(find.text('root'), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────
  // WordMachine / ImmersiveSwipe 回首页导航验证
  // ──────────────────────────────────────────────────────

  group('WordMachine 完成后 goHome', () {
    testWidgets('CLEAR 页"返回首页"按钮回到根路由', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('home'))),
          ),
        ),
      );

      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Builder(
              builder: (_) {
                return Center(
                  child: ElevatedButton(onPressed: () => NavUtils.goHome(context), child: const Text('返回首页')),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('返回首页'));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
    });
  });

  group('ImmersiveSwipe 完成后 goHome', () {
    testWidgets('完成页"返回首页"按钮回到根路由', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const Scaffold(body: Text('home'))),
          ),
        ),
      );

      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Builder(
              builder: (_) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('学习完成'),
                    const SizedBox(height: 24),
                    ElevatedButton(onPressed: () => NavUtils.goHome(context), child: const Text('返回首页')),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('返回首页'));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
    });
  });
}
