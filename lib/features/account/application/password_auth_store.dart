// Monster Word App
//
// 本机账号密码认证端口（application 层）：创建 / 校验 / 找回。
// 实现见 data/secure_password_auth_store.dart（flutter_secure_storage，密码只存
// 盐值 + SHA-256 哈希，永不落明文）。
//
// 语义约定：本 App 无远程账号体系，「账号密码登录」即本机账号——首次登录
// 即创建（用户确认后），忘记密码走绑定手机号的短信验证码找回（复用 SmsCodeService）。

abstract class PasswordAuthStore {
  /// 该用户名是否已创建过本机账号（设置过密码）。
  Future<bool> hasPassword(String username);

  /// 校验密码。未创建账号时返回 false。
  Future<bool> verify(String username, String password);

  /// 该账号绑定的手机号（未绑定返回 null）。手机号格式的用户名注册时自动绑定。
  Future<String?> boundPhone(String username);

  /// 创建或重置密码。[phone] 非空时同时写入绑定手机号。
  Future<void> setPassword(String username, String password, {String? phone});
}
