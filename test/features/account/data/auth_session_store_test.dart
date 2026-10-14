// AuthSession 值对象单元测试。
//
// 重点在**容错**：会话是缓存，任何损坏都应表现为「需要重新登录」，
// 而不是抛异常让应用起不来。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/account/application/auth_session_store.dart';

void main() {
  AuthSession sample({int expiresInSeconds = 3600}) => AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.utc(2026, 10, 14, 12).add(Duration(seconds: expiresInSeconds)),
    userId: 'user-uuid',
  );

  group('AuthSession 序列化', () {
    test('toJson → tryParse 往返一致', () {
      final original = sample();
      final restored = AuthSession.tryParse(jsonEncodeOf(original));
      expect(restored, isNotNull);
      expect(restored!.accessToken, original.accessToken);
      expect(restored.refreshToken, original.refreshToken);
      expect(restored.userId, original.userId);
      expect(restored.expiresAt, original.expiresAt);
    });

    test('过期时间统一按 UTC 存，避免跨时区读回偏移', () {
      final local = AuthSession(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime(2026, 10, 14, 12), // 本地时间
        userId: 'u',
      );
      final restored = AuthSession.tryParse(jsonEncodeOf(local))!;
      expect(restored.expiresAt.isUtc, isTrue);
      expect(restored.expiresAt, local.expiresAt.toUtc());
    });
  });

  group('AuthSession 容错（损坏一律返回 null，不上抛）', () {
    test('非 JSON', () {
      expect(AuthSession.tryParse('not json at all'), isNull);
    });

    test('JSON 但不是对象', () {
      expect(AuthSession.tryParse('[1,2,3]'), isNull);
    });

    test('缺 access_token', () {
      expect(AuthSession.tryParse('{"refresh_token":"r","expires_at":"2026-10-14T12:00:00Z","user_id":"u"}'), isNull);
    });

    test('缺 refresh_token', () {
      expect(AuthSession.tryParse('{"access_token":"a","expires_at":"2026-10-14T12:00:00Z","user_id":"u"}'), isNull);
    });

    test('缺 expires_at', () {
      expect(AuthSession.tryParse('{"access_token":"a","refresh_token":"r","user_id":"u"}'), isNull);
    });

    test('缺 user_id', () {
      expect(
        AuthSession.tryParse('{"access_token":"a","refresh_token":"r","expires_at":"2026-10-14T12:00:00Z"}'),
        isNull,
      );
    });

    test('字段类型不对（数字冒充字符串）', () {
      expect(
        AuthSession.tryParse(
          '{"access_token":123,"refresh_token":"r","expires_at":"2026-10-14T12:00:00Z","user_id":"u"}',
        ),
        isNull,
      );
    });

    test('expires_at 不是合法时间', () {
      expect(
        AuthSession.tryParse('{"access_token":"a","refresh_token":"r","expires_at":"tomorrow","user_id":"u"}'),
        isNull,
      );
    });

    test('解析失败时把真实异常交给调用方上报', () {
      final reported = <Object>[];
      AuthSession.tryParse('not json', onError: (e, _) => reported.add(e));
      expect(reported, hasLength(1));
      expect(reported.single, isA<FormatException>());
    });

    test('解析成功时不触发 onError', () {
      var called = false;
      AuthSession.tryParse(jsonEncodeOf(sample()), onError: (_, _) => called = true);
      expect(called, isFalse);
    });
  });

  group('AuthSession 过期判定', () {
    final now = DateTime.utc(2026, 10, 14, 12);

    test('未到期且余量充足 → 未过期', () {
      expect(sample(expiresInSeconds: 3600).isExpiredAt(now), isFalse);
    });

    test('剩余不足 60 秒 → 视为已过期（避免请求正好卡在过期瞬间）', () {
      expect(sample(expiresInSeconds: 30).isExpiredAt(now), isTrue);
    });

    test('已过期', () {
      expect(sample(expiresInSeconds: -1).isExpiredAt(now), isTrue);
    });
  });
}

/// 测试内的小工具：走 toJson + jsonEncode（值对象本身不暴露 encode）。
String jsonEncodeOf(AuthSession session) => jsonEncode(session.toJson());
