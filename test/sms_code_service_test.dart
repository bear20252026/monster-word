// Monster Word App
//
// SpugSmsCodeService 单元测试：发送/校验/过期/手机号匹配 + 发送节流。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/features/account/data/spug_sms_code_service.dart';

/// 发送相关用例统一关闭节流：节流状态持久化在 SharedPreferences，若不关闭，
/// 同一测试进程内对同一手机号的多次 sendCode 会被冷却窗口拦下（假红）。
const SmsSendThrottle _noThrottle = SmsSendThrottle.disabled();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpugSmsCodeService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('发送成功后校验通过', () async {
      final sentBodies = <String>[];
      final service = SpugSmsCodeService(
        throttle: _noThrottle,
        client: MockClient((request) async {
          sentBodies.add(request.body);
          return http.Response(
            jsonEncode({'code': 200, 'msg': '请求成功', 'request_id': 'r1'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final result = await service.sendCode('13800000000');
      expect(result.ok, isTrue);
      expect(sentBodies.single, contains('"to":"13800000000"'));

      // 从请求体中取出实际发送的验证码回填校验
      final sentCode = (jsonDecode(sentBodies.single) as Map<String, dynamic>)['code'] as String;
      expect(sentCode, matches(RegExp(r'^\d{6}$')));
      expect(service.verifyCode('13800000000', sentCode), isNull);
    });

    test('接口返回非 200 时发送失败并透出原因', () async {
      final service = SpugSmsCodeService(
        throttle: _noThrottle,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'code': 400, 'msg': '手机号格式错误'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      final result = await service.sendCode('13800000000');
      expect(result.ok, isFalse);
      expect(result.message, '手机号格式错误');
    });

    test('未发送时校验直接拒绝', () {
      final service = SpugSmsCodeService(
        throttle: _noThrottle,
        client: MockClient(
          (_) async => http.Response('{}', 200, headers: {'content-type': 'application/json; charset=utf-8'}),
        ),
      );
      expect(service.verifyCode('13800000000', '123456'), '请先获取验证码');
    });

    test('验证码错误', () async {
      final service = SpugSmsCodeService(
        throttle: _noThrottle,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'code': 200, 'msg': '请求成功', 'request_id': 'r1'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      await service.sendCode('13800000000');
      expect(service.verifyCode('13800000000', '000000'), '验证码错误');
    });

    test('手机号与验证码不匹配', () async {
      final sentBodies = <String>[];
      final service = SpugSmsCodeService(
        throttle: _noThrottle,
        client: MockClient((request) async {
          sentBodies.add(request.body);
          return http.Response(
            jsonEncode({'code': 200, 'msg': '请求成功', 'request_id': 'r1'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await service.sendCode('13800000000');
      final sentCode = (jsonDecode(sentBodies.single) as Map<String, dynamic>)['code'] as String;
      expect(service.verifyCode('13900000000', sentCode), '手机号与验证码不匹配');
    });

    test('超过 5 分钟有效期后过期', () async {
      var fakeNow = DateTime(2026, 9, 1, 12);
      final sentBodies = <String>[];
      final service = SpugSmsCodeService(
        now: () => fakeNow,
        throttle: _noThrottle,
        client: MockClient((request) async {
          sentBodies.add(request.body);
          return http.Response(
            jsonEncode({'code': 200, 'msg': '请求成功', 'request_id': 'r1'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await service.sendCode('13800000000');
      final sentCode = (jsonDecode(sentBodies.single) as Map<String, dynamic>)['code'] as String;

      fakeNow = fakeNow.add(const Duration(minutes: 5, seconds: 1));
      expect(service.verifyCode('13800000000', sentCode), '验证码已过期，请重新获取');
    });

    test('网络异常时返回友好提示', () async {
      final service = SpugSmsCodeService(
        throttle: _noThrottle,
        client: MockClient((_) async => throw Exception('network down')),
      );
      final result = await service.sendCode('13800000000');
      expect(result.ok, isFalse);
      expect(result.message, '网络异常，请检查网络后重试');
    });
  });

  group('SmsSendThrottle（P0-01 仓库侧加固）', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('同号冷却窗口内拒绝再次发送，窗口过后放行', () async {
      final throttle = SmsSendThrottle();
      final now = DateTime(2026, 10, 11, 10);
      expect(await throttle.check('13800000000', now), isNull);
      await throttle.record('13800000000', now);

      final blocked = await throttle.check('13800000000', now.add(const Duration(seconds: 30)));
      expect(blocked, isNotNull);
      expect(blocked, contains('频繁'));

      expect(await throttle.check('13800000000', now.add(const Duration(seconds: 61))), isNull);
    });

    test('冷却按手机号隔离', () async {
      final throttle = SmsSendThrottle();
      final now = DateTime(2026, 10, 11, 10);
      await throttle.record('13800000000', now);
      expect(await throttle.check('13900000000', now), isNull);
    });

    test('每日上限封顶', () async {
      final throttle = SmsSendThrottle(cooldown: Duration.zero, dailyLimit: 3);
      final now = DateTime(2026, 10, 11, 10);
      for (var i = 0; i < 3; i++) {
        expect(await throttle.check('13800000000', now), isNull);
        await throttle.record('13800000000', now);
      }
      final blocked = await throttle.check('13800000000', now);
      expect(blocked, isNotNull);
      expect(blocked, contains('上限'));
    });

    test('跨日重置每日计数', () async {
      final throttle = SmsSendThrottle(cooldown: Duration.zero, dailyLimit: 1);
      final day1 = DateTime(2026, 10, 11, 10);
      await throttle.record('13800000000', day1);
      expect(await throttle.check('13800000000', day1), contains('上限'));
      expect(await throttle.check('13800000000', DateTime(2026, 10, 12, 10)), isNull);
    });

    test('禁用态恒放行（测试/特殊环境）', () async {
      const throttle = SmsSendThrottle.disabled();
      final now = DateTime(2026, 10, 11, 10);
      await throttle.record('13800000000', now);
      expect(await throttle.check('13800000000', now), isNull);
    });

    test('节流拦截时 sendCode 不发网络请求', () async {
      var requested = false;
      final throttle = SmsSendThrottle();
      final now = DateTime(2026, 10, 11, 10);
      await throttle.record('13800000000', now);

      final service = SpugSmsCodeService(
        throttle: throttle,
        now: () => now,
        client: MockClient((_) async {
          requested = true;
          return http.Response('{}', 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );
      final result = await service.sendCode('13800000000');
      expect(result.ok, isFalse);
      expect(requested, isFalse);
    });
  });
}
