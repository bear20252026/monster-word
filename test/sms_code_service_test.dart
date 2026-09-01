// Monster Word App
//
// SpugSmsCodeService 单元测试：发送/校验/过期/手机号匹配。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:word_app/features/account/data/spug_sms_code_service.dart';

void main() {
  group('SpugSmsCodeService', () {
    test('发送成功后校验通过', () async {
      final sentBodies = <String>[];
      final service = SpugSmsCodeService(
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
        client: MockClient(
          (_) async => http.Response('{}', 200, headers: {'content-type': 'application/json; charset=utf-8'}),
        ),
      );
      expect(service.verifyCode('13800000000', '123456'), '请先获取验证码');
    });

    test('验证码错误', () async {
      final service = SpugSmsCodeService(
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
      final service = SpugSmsCodeService(client: MockClient((_) async => throw Exception('network down')));
      final result = await service.sendCode('13800000000');
      expect(result.ok, isFalse);
      expect(result.message, '网络异常，请检查网络后重试');
    });
  });
}
