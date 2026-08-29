import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/learning/presentation/dictation_session_page.dart';
import 'package:word_app/features/learning/presentation/quick_spell_page.dart';
import 'package:word_app/widgets/session_exit_guard.dart';
import 'package:word_app/theme/skin_system.dart';

void main() {
  // ────────────────────────────────────────────────
  // DictationSessionPage: 空词表降级
  // ────────────────────────────────────────────────

  group('DictationSessionPage 空词表', () {
    testWidgets('空 words 时显示空态页 + 返回首页按钮，不白屏', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SkinProvider(
          skin: SkinSystem(),
          child: DictationSessionPage(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('暂无待学习单词'), findsOneWidget);
      expect(find.text('返回首页'), findsOneWidget);
      expect(find.byIcon(Icons.record_voice_over), findsOneWidget);
    });

    testWidgets('空 words 点击返回首页触发 goHome 回到根路由', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('root')),
          ),
        ),
      ));

      navKey.currentState!.push(MaterialPageRoute(
        builder: (_) => SkinProvider(
          skin: SkinSystem(),
          child: DictationSessionPage(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('暂无待学习单词'), findsOneWidget);

      await tester.tap(find.text('返回首页'));
      await tester.pumpAndSettle();

      expect(find.text('root'), findsOneWidget);
    });
  });

  // ────────────────────────────────────────────────
  // QuickSpellPage: 空词表降级
  // ────────────────────────────────────────────────

  group('QuickSpellPage 空词表', () {
    testWidgets('空 words 时显示空态页 + 返回首页按钮，不白屏', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SkinProvider(
          skin: SkinSystem(),
          child: QuickSpellPage(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('暂无待学习单词'), findsOneWidget);
      expect(find.text('返回首页'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard), findsOneWidget);
    });

    testWidgets('空 words 点击返回首页触发 goHome 回到根路由', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('root')),
          ),
        ),
      ));

      navKey.currentState!.push(MaterialPageRoute(
        builder: (_) => SkinProvider(
          skin: SkinSystem(),
          child: QuickSpellPage(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('暂无待学习单词'), findsOneWidget);

      await tester.tap(find.text('返回首页'));
      await tester.pumpAndSettle();

      expect(find.text('root'), findsOneWidget);
    });
  });

  // ────────────────────────────────────────────────
  // SessionExitGuard: safePop 守卫
  // ────────────────────────────────────────────────

  group('SessionExitGuard', () {
    testWidgets('包裹子 widget 后系统返回弹出退出确认对话框', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('root')),
          ),
        ),
      ));

      navKey.currentState!.push(MaterialPageRoute(
        builder: (_) => SessionExitGuard(
          child: const Scaffold(body: Text('session')),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('session'), findsOneWidget);

      // Simulate system back via handlePopRoute
      await tester.binding.handlePopRoute();
      // Need extra pump for async dialog to appear
      await tester.pump();
      await tester.pumpAndSettle();

      // Should show exit confirmation dialog (default subject = '当前练习')
      expect(find.text('退出当前练习？'), findsOneWidget);
    });

    testWidgets('确认退出后执行 safePop 回到上一页', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('root')),
          ),
        ),
      ));

      navKey.currentState!.push(MaterialPageRoute(
        builder: (_) => SessionExitGuard(
          child: const Scaffold(body: Text('session')),
        ),
      ));
      await tester.pumpAndSettle();

      // Trigger system back → shows dialog
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('退出当前练习？'), findsOneWidget);

      // Tap "暂停并保存" button
      await tester.tap(find.text('暂停并保存'));
      await tester.pumpAndSettle();

      // Should have popped back to root
      expect(find.text('root'), findsOneWidget);
    });
  });
}
