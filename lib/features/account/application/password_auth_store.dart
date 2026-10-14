// Monster Word App
//
// 本机账号密码认证端口（application 层）：创建 / 校验 / 找回。
// 实现见 data/secure_password_auth_store.dart（flutter_secure_storage，密码只存
// 盐值 + SHA-256 哈希，永不落明文）。
//
// 语义约定：本 App 无远程账号体系，「账号密码登录」即本机账号——首次登录
// 即创建（用户确认后）。2026-10-13 移除短信链路后，忘记密码不再有自助通道，
// 改为提示联系管理员（服务端账号体系上线后由后台重置，见 R2-01 阶段二）。

abstract class PasswordAuthStore {
  /// 该用户名是否已创建过本机账号（设置过密码）。
  Future<bool> hasPassword(String username);

  /// 校验密码。未创建账号时返回 false。
  Future<bool> verify(String username, String password);

  /// 创建或重置密码。
  Future<void> setPassword(String username, String password);

  /// 删除本机凭据（含旧散键）。
  ///
  /// 为什么必须有：账号迁到服务端后，本机不该再留密码哈希——否则
  /// 「密码只提交给服务端校验」这句披露就成了假话（R2-23 同类问题）。
  /// 迁移成功时由 `MigratingAccountAuthenticator` 调用。
  Future<void> removePassword(String username);
}
