// Monster Word App
//
// Spug Push 短信验证码实现（data 层）。
// App 直连 https://push.spug.cc/sms/<TEMPLATE_CODE>，本地生成并缓存验证码，
// 输入时本地比对（5 分钟有效期）。
// ⚠️ 模板码为调用凭证，随包分发存在被盗刷风险（官方文档建议服务端发起），
// 用户已明确接受此风险；如迁移服务端代理，仅需替换本实现。

import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:word_app/features/account/application/sms_code_service.dart';

class SpugSmsCodeService implements SmsCodeService {
  SpugSmsCodeService({http.Client? client, DateTime Function()? now})
    : _client = client ?? http.Client(),
      _now = now ?? DateTime.now;

  static const _endpoint = 'https://push.spug.cc/sms/yx5N5ygyQeuGKe9nwDB4tA';
  static const _codeLength = 6;
  static const _ttl = Duration(minutes: 5);

  final http.Client _client;
  final DateTime Function() _now;

  String? _pendingPhone;
  String? _pendingCode;
  DateTime? _sentAt;

  @override
  Future<SmsSendResult> sendCode(String phone) async {
    final code = _generateCode();
    try {
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'to': phone, 'code': code}),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['code'] == 200) {
        _pendingPhone = phone;
        _pendingCode = code;
        _sentAt = _now();
        return (ok: true, message: '验证码已发送，请查收短信');
      }
      return (ok: false, message: body['msg']?.toString() ?? '发送失败，请稍后再试');
    } catch (e) {
      return (ok: false, message: '网络异常，请检查网络后重试');
    }
  }

  @override
  String? verifyCode(String phone, String code) {
    if (_pendingCode == null || _sentAt == null) return '请先获取验证码';
    if (_pendingPhone != phone) return '手机号与验证码不匹配';
    if (_now().difference(_sentAt!) > _ttl) return '验证码已过期，请重新获取';
    if (_pendingCode != code) return '验证码错误';
    return null;
  }

  String _generateCode() {
    final random = Random.secure();
    return List.generate(_codeLength, (_) => random.nextInt(10)).join();
  }
}
