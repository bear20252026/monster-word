// REG-START-001~003：启动 → 引导 → 主页 全链路回归
// 用户实测 bug（2026-08-30）：①引导页走完点「开始使用」后又见 Splash 卡死
// ②每次重启都强制重看引导（hasShownInitGuide 未持久化）
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/features/account/presentation/app_session_state.dart';
import 'package:word_app/features/account/presentation/splash_page.dart';
import 'package:word_app/theme/skin_system.dart';

Widget _host(AppSessionState session) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppSessionState>.value(value: session),
      ChangeNotifierProvider<SkinSystem>(create: (_) => SkinSystem()),
    ],
    child: MaterialApp(
      // 与真实 app 相同的结构约束：home 会恒占 '/' 路由，
      // 必须用 initialRoute + onGenerateRoute，'/' 映射主页
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        final name = settings.name ?? '/';
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => switch (name) {
            '/splash' => const SplashPage(),
            '/login' => const Text('LOGIN_PAGE'),
            _ => const Text('MAIN_PAGE'),
          },
        );
      },
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('REG-START-001: 已登录首启 → Splash 2秒 → 引导页 → 下一步×2 → 开始使用 → 主页', (tester) async {
    final session = AppSessionState();
    await session.restore();
    await session.login('user', 'pass'); // 已登录、未看引导
    expect(session.hasShownInitGuide, isFalse);

    await tester.pumpWidget(_host(session));
    await tester.pump(const Duration(milliseconds: 300)); // Splash 动画中
    expect(find.text('Monster Word'), findsOneWidget); // 还在 Splash

    await tester.pump(const Duration(seconds: 3)); // 越过 2 秒 Timer
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    // 进入引导页第一页
    expect(find.text('科学记忆'), findsOneWidget);
    expect(session.hasShownInitGuide, isTrue, reason: '进入引导页即应持久化已展示标记');

    // 下一步 ×2（科学记忆 → 沉浸学习 → 持续进步）
    await tester.tap(find.text('下一步'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('沉浸学习'), findsOneWidget);
    await tester.tap(find.text('下一步'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('持续进步'), findsOneWidget);

    // 开始使用 → 主页
    debugPrint(
      'PROBE before tap: 持续进步=${find.text('持续进步').evaluate().length}, 开始使用=${find.text('开始使用').evaluate().length}',
    );
    await tester.tap(find.text('开始使用'), warnIfMissed: false);
    await tester.pump();
    debugPrint(
      'PROBE after tap pump0: MAIN=${find.text('MAIN_PAGE').evaluate().length}, 引导页=${find.text('持续进步').evaluate().length}',
    );
    await tester.pump(const Duration(milliseconds: 600));
    debugPrint(
      'PROBE after pump600: MAIN=${find.text('MAIN_PAGE').evaluate().length}, 引导页=${find.text('持续进步').evaluate().length}, Splash=${find.text('Monster Word').evaluate().length}',
    );
    expect(find.text('MAIN_PAGE'), findsOneWidget, reason: '点「开始使用」后必须进入主页，不得卡在 Splash/引导页');
  });

  testWidgets('REG-START-002: hasShownInitGuide 持久化——重启后不再重看引导', (tester) async {
    // 第一次启动看完引导
    final session = AppSessionState();
    await session.restore();
    await session.login('user', 'pass');
    await session.setHasShownInitGuide(true);

    // 模拟重启：新实例从 SharedPreferences 恢复
    final session2 = AppSessionState();
    await session2.restore();
    expect(session2.isLoggedIn, isTrue);
    expect(session2.hasShownInitGuide, isTrue, reason: '引导标记未持久化会导致每次重启都强制重看引导页');
  });

  testWidgets('REG-START-003: 未登录 → Splash 2秒 → 登录页（fail-safe 路径）', (tester) async {
    final session = AppSessionState();
    await session.restore(); // 未登录

    await tester.pumpWidget(_host(session));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('LOGIN_PAGE'), findsOneWidget);
  });
}
