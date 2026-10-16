// R3-A05 回归：登出后必须离开「已登录界面」。
//
// 缺陷原形（2026-10-15 审计）：`more_settings_page` 的「退出」只做
// `unawaited(context.read<AppSessionController>().logout())`——而 `isLoggedIn`
// 全库唯一消费点是 Splash 页 ⇒ 登出只改内存态 + notifyListeners，
// **界面毫无反应**。用户停留在已登录的 App 里继续用（数据仍记在旧账号名下，
// 与 R3-A01 叠加），退出登录要等下次冷启动才生效。
//
// 修复判据（两条都必须成立）：
//   ① 调用会话控制器的 `logout()`（durable 清理不能被跳过）；
//   ② 之后把导航栈清到只剩登录页——**不能只压一层**，否则按返回键能回到
//      已登出的界面（所以断言的是 `pushNamedAndRemoveUntil` 而非 `pushNamed`）。
//
// 第三条断言针对「登出抛错」分支：宁可跳转（少留态），也不能把用户留在
// 已登录界面里。这是 try/finally 的设计意图，不是偶然行为。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/core/application/wordbook_maintenance_service.dart';
import 'package:word_app/core/auth/app_session_controller.dart';
import 'package:word_app/features/settings/application/update_check_service.dart';
import 'package:word_app/features/settings/domain/version_compare.dart';
import 'package:word_app/features/settings/presentation/more_settings_page.dart';
import 'package:word_app/features/telemetry/application/usage_stats_ports.dart';
import 'package:word_app/theme/skin_system.dart';

/// 记录登出调用次数与抛错行为的最小替身。
///
/// `AppSessionController` 是 `abstract interface class` ⇒ Dart 的 implements
/// **不继承**任何默认实现，两个成员都得写全（少一个就是编译错误）。
class _FakeSession implements AppSessionController {
  _FakeSession({this.throwOnLogout = false});

  final bool throwOnLogout;
  int logoutCalls = 0;

  @override
  bool get isLoggedIn => true;

  @override
  Future<void> logout() async {
    logoutCalls++;
    if (throwOnLogout) throw StateError('durable cleanup boom');
  }
}

class _FakeMaintenance implements WordBookMaintenanceService {
  @override
  Future<DbRebuildResult> forceRebuild() async =>
      const DbRebuildResult(success: true, books: 1, words: 1, links: 1, message: '');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUpdate implements UpdateCheckService {
  @override
  Future<UpdateCheckResult> check({required String currentVersion}) async =>
      const UpdateCheckResult(currentVersion: '9.9.9', latestVersion: '9.9.9', releaseUrl: '', hasUpdate: false);
}

/// 设置页依赖 telemetry 的 application 层窄接口（架构守卫 R4），几行即可。
class _FakeUsageStats implements UsageStatsController {
  bool enabled = false;

  @override
  bool get isEnabled => enabled;

  @override
  Future<void> setEnabled(bool value) async => enabled = value;
}

/// 导航记录：[removedUntilCalled] 为真表示走了 `pushNamedAndRemoveUntil`
/// （清栈语义），为假表示只做了 `pushNamed`（压栈，返回键可回到旧界面）。
class _NavProbe extends NavigatorObserver {
  final pushed = <String>[];
  bool removedUntilCalled = false;
  int popCalls = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) pushed.add(name);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    removedUntilCalled = true;
    super.didRemove(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCalls++;
    super.didPop(route, previousRoute);
  }
}

Future<_NavProbe> _pump(WidgetTester tester, {required _FakeSession session}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final probe = _NavProbe();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<WordBookMaintenanceService>.value(value: _FakeMaintenance()),
        Provider<UsageStatsController>.value(value: _FakeUsageStats()),
        Provider<AppSessionController>.value(value: session),
      ],
      child: MaterialApp(
        navigatorObservers: [probe],
        // 登录页用哨兵 widget 替代真实页面：本测试只关心「栈被清到只剩登录页」，
        // 不关心登录页长什么样（引真实 LoginPage 会拖进 account feature 的
        // 全部依赖，且那是登录流程测试的职责，不是本条回归的职责）。
        routes: {RouteNames.login: (_) => const Scaffold(body: Center(child: Text('登录页哨兵')))},
        home: SkinProvider(
          skin: SkinSystem(),
          child: MoreSettingsPage(updateServiceOverride: _FakeUpdate()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return probe;
}

/// 打开「退出登录」底部弹窗并点「退出」。
Future<void> _tapLogout(WidgetTester tester) async {
  await tester.tap(find.text('退出登录'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('退出'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Monster Word',
      packageName: 'test',
      version: '9.9.9',
      buildNumber: '1',
      buildSignature: 'sig',
    );
  });

  testWidgets('R3-A05：点「退出」→ 调用 logout 并清栈跳转到登录页', (tester) async {
    final session = _FakeSession();
    final probe = await _pump(tester, session: session);

    await _tapLogout(tester);

    expect(session.logoutCalls, 1, reason: '登出必须被真正调用（durable 清理不能跳过）');
    expect(probe.pushed, contains(RouteNames.login), reason: '必须离开更多设置页');
    expect(probe.removedUntilCalled, isTrue, reason: '必须是 pushNamedAndRemoveUntil（清栈）——只压一层的话按返回键又能回到已登出的界面');
    expect(find.text('登录页哨兵'), findsOneWidget);
    expect(find.text('更多设置'), findsNothing, reason: '已登录界面必须从栈里消失');
  });

  testWidgets('R3-A05：登出抛错时仍跳转登录页（宁可少留态，不把用户留在已登录界面）', (tester) async {
    final session = _FakeSession(throwOnLogout: true);
    final probe = await _pump(tester, session: session);

    await _tapLogout(tester);

    expect(session.logoutCalls, 1, reason: '抛错也说明调用发生了');
    expect(find.text('登录页哨兵'), findsOneWidget, reason: 'try/finally 设计意图：清理失败不能把用户留在已登录界面');
    expect(probe.removedUntilCalled, isTrue);
  });

  testWidgets('R3-A05：弹窗点「取消」不登出、不跳转', (tester) async {
    final session = _FakeSession();
    final probe = await _pump(tester, session: session);

    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(session.logoutCalls, 0, reason: '取消不得触发登出');
    expect(probe.pushed, isNot(contains(RouteNames.login)));
    expect(find.text('更多设置'), findsOneWidget, reason: '应停留在设置页');
  });
}
