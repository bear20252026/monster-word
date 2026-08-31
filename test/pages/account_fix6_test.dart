import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/router/nav_utils.dart';
import 'package:word_app/features/account/presentation/app_session_state.dart';
import 'package:word_app/features/account/application/account_profile_state.dart';
import 'package:word_app/features/account/application/account_profile_store.dart';
import 'package:word_app/features/account/domain/account_profile.dart';

// ──── Minimal fakes ────

class _FakeProfileStore implements AccountProfileStore {
  AccountProfile _profile = const AccountProfile.empty();
  @override
  Future<AccountProfile> load() async => _profile;
  @override
  Future<void> save(AccountProfile profile) async {
    _profile = profile;
  }
}

// ──── Tests ────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ────────────────────────────────────────────────
  // AppSessionState: 登录持久化
  // ────────────────────────────────────────────────

  group('AppSessionState 登录持久化', () {
    testWidgets('login 后 restore 可恢复登录态', (tester) async {
      final state = AppSessionState();

      // 初始未登录
      expect(state.isLoggedIn, isFalse);

      // 登录
      await state.login('user', 'pass');
      expect(state.isLoggedIn, isTrue);

      // 新建实例模拟冷启动 → restore
      final restored = AppSessionState();
      expect(restored.isLoggedIn, isFalse); // 还未 restore
      await restored.restore();
      expect(restored.isLoggedIn, isTrue);
    });

    testWidgets('logout 后 restore 保持未登录', (tester) async {
      final state = AppSessionState();
      await state.login('user', 'pass');
      expect(state.isLoggedIn, isTrue);

      state.logout();
      expect(state.isLoggedIn, isFalse);

      // 新实例 restore 应为 false
      final restored = AppSessionState();
      await restored.restore();
      expect(restored.isLoggedIn, isFalse);
    });
  });

  // ────────────────────────────────────────────────
  // AccountProfileState: mounted 守卫
  // ────────────────────────────────────────────────

  group('AccountProfileState mounted 守卫', () {
    testWidgets('dispose 后 notifyListeners 不崩溃', (tester) async {
      final store = _FakeProfileStore();
      final state = AccountProfileState(profileStore: store);

      await state.refresh();
      expect(state.isLoading, isFalse);

      // 模拟 dispose
      state.dispose();

      // dispose 后再调用 refresh 不应崩溃
      // (refresh 内部的 _safeNotify 会跳过通知)
      await state.refresh();
      expect(state.isLoading, isFalse);
    });
  });

  // ────────────────────────────────────────────────
  // MoreSettingsPage: 返回 safePop + logout
  // ────────────────────────────────────────────────

  group('MoreSettingsPage 安全返回', () {
    testWidgets('safePop 不会在根路由崩溃', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(onPressed: () => NavUtils.safePop(context), child: const Text('返回')),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();
      // 不崩溃
      expect(find.text('返回'), findsOneWidget);
    });

    testWidgets('logout 调用后 isLoggedIn 变为 false', (tester) async {
      final state = AppSessionState();
      await state.login('user', 'pass');
      expect(state.isLoggedIn, isTrue);

      state.logout();
      expect(state.isLoggedIn, isFalse);
    });
  });

  // ────────────────────────────────────────────────
  // LoginPage: 双 pop 修复
  // ────────────────────────────────────────────────

  group('LoginPage 安全退出', () {
    testWidgets('safePop 在根路由不崩溃', (tester) async {
      // 模拟登录页在栈底（pushReplacement 场景）
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Column(
                  children: [
                    const Text('login'),
                    ElevatedButton(
                      onPressed: () {
                        // 模拟退出对话框的"确定"
                        NavUtils.safePop(context);
                      },
                      child: const Text('退出'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('退出'));
      await tester.pumpAndSettle();
      // 栈底 safePop 不崩溃
      expect(find.text('login'), findsOneWidget);
    });

    testWidgets('safePop 在有上层路由时正常 pop', (tester) async {
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
            body: Column(
              children: [
                const Text('login page'),
                ElevatedButton(onPressed: () => NavUtils.safePop(context), child: const Text('退出')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('退出'));
      await tester.pumpAndSettle();

      expect(find.text('root'), findsOneWidget);
    });
  });
}
