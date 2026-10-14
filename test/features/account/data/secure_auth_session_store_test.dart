// SecureAuthSessionStore 单元测试。
//
// flutter_secure_storage 的 setMockInitialValues 提供测试背板，走真实实现逻辑。
// 关注点：整包原子读写、损坏内容自愈、以及**与旧 userToken 字段互不干扰**。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/account/application/auth_session_store.dart';
import 'package:word_app/features/account/data/secure_auth_session_store.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  AuthSession session() => AuthSession(
    accessToken: 'access',
    refreshToken: 'refresh',
    expiresAt: DateTime.utc(2026, 10, 14, 12),
    userId: 'user-1',
  );

  group('SecureAuthSessionStore', () {
    test('无会话时 read 返回 null', () async {
      expect(await SecureAuthSessionStore().read(), isNull);
    });

    test('写入后可原样读回（四个字段都在）', () async {
      final store = SecureAuthSessionStore();
      await store.write(session());
      final restored = await store.read();
      expect(restored, isNotNull);
      expect(restored!.accessToken, 'access');
      expect(restored.refreshToken, 'refresh');
      expect(restored.userId, 'user-1');
      expect(restored.expiresAt, DateTime.utc(2026, 10, 14, 12));
    });

    test('clear 后读不到', () async {
      final store = SecureAuthSessionStore();
      await store.write(session());
      await store.clear();
      expect(await store.read(), isNull);
    });

    test('覆盖写入不残留旧值', () async {
      final store = SecureAuthSessionStore();
      await store.write(session());
      await store.write(
        AuthSession(
          accessToken: 'access2',
          refreshToken: 'refresh2',
          expiresAt: DateTime.utc(2026, 10, 15),
          userId: 'user-2',
        ),
      );
      final restored = await store.read();
      expect(restored!.accessToken, 'access2');
      expect(restored.userId, 'user-2');
    });

    test('内容损坏 → 返回 null 并顺手清除（避免每次启动白读一次）', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        SecureAuthSessionStore.storageKey: '{"access_token":"a"}', // 缺字段
      });
      final store = SecureAuthSessionStore();
      expect(await store.read(), isNull);
      // 第二次读：已被清掉，不应再报损坏
      expect(await store.read(), isNull);
      expect(await const FlutterSecureStorage().read(key: SecureAuthSessionStore.storageKey), isNull);
    });

    test('key 与旧 userToken/userSecret 完全隔离（登出清会话不误伤资料缓存）', () {
      // 直接锁 key 本身：复用同一 key 会让「退出登录」把用户资料一起清掉，
      // 或反过来让资料缓存刷新覆盖掉会话。
      expect(SecureAuthSessionStore.storageKey, isNot(AppPreferences.userToken));
      expect(SecureAuthSessionStore.storageKey, isNot(AppPreferences.userSecret));
    });

    test('存的是一整包 JSON（会话原子性：不存在半新半旧）', () async {
      await SecureAuthSessionStore().write(session());
      final raw = await const FlutterSecureStorage().read(key: SecureAuthSessionStore.storageKey);
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded.keys.toSet(), {'access_token', 'refresh_token', 'expires_at', 'user_id'});
    });
  });
}
