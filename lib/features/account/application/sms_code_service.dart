// Monster Word App
//
// 短信验证码服务端口（application 层）：发送 + 校验。
// 实现见 data/spug_sms_code_service.dart（App 直连 Spug Push，用户已确认接受
// 模板码随包分发的风险；后续迁移服务端代理时仅需替换实现，页面无需改动）。

/// 发送结果：ok=false 时 message 为用户可读原因。
typedef SmsSendResult = ({bool ok, String message});

abstract class SmsCodeService {
  /// 向手机号发送验证码。成功后验证码进入待校验状态（有效期 5 分钟）。
  Future<SmsSendResult> sendCode(String phone);

  /// 校验用户输入。通过返回 null；否则返回用户可读错误信息。
  String? verifyCode(String phone, String code);
}
