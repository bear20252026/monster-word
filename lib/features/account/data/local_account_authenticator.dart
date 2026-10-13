// Monster Word App
//
// 本机账号认证实现（data 层）：把 [PasswordAuthStore] 的存储语义
// （hasPassword / verify / setPassword）适配成 [AccountAuthenticator] 的
// 「登录 / 创建账号」语义。
//
// 分层说明：**策略**在本类（什么算登录成功），**存储**在 PasswordAuthStore
// （盐值+哈希存在哪）。服务端实现只需替换本类，PasswordAuthStore 保持不动。
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/account/application/account_authenticator.dart';
import 'package:word_app/features/account/application/password_auth_store.dart';

class LocalAccountAuthenticator implements AccountAuthenticator {
  const LocalAccountAuthenticator(this._store);

  final PasswordAuthStore _store;

  @override
  AccountScope get scope => AccountScope.local;

  @override
  Future<AuthOutcome> signIn({required String username, required String password}) async {
    final bool exists;
    try {
      exists = await _store.hasPassword(username);
    } catch (e, s) {
      // flutter_secure_storage 的平台调用（系统还原 / Keystore 故障）会抛
      // PlatformException。此前该异常会让登录按钮「点了没反应」，故在此收口。
      reportSwallowedError('本机凭据读取失败（hasPassword）', e, s);
      return const AuthOutcome.localCredentialUnavailable();
    }
    if (!exists) return const AuthOutcome.needsAccountCreation();

    final bool verified;
    try {
      verified = await _store.verify(username, password);
    } catch (e, s) {
      reportSwallowedError('本机凭据读取失败（verify）', e, s);
      return const AuthOutcome.localCredentialUnavailable();
    }
    return verified ? const AuthOutcome.success() : const AuthOutcome.invalidCredentials();
  }

  @override
  Future<AuthOutcome> createAccount({required String username, required String password}) async {
    try {
      // 先确认账号确实不存在，避免「确认弹窗期间账号已被建」时静默覆盖密码
      //（setPassword 每次换新盐，直接覆盖会把原密码作废）。
      if (await _store.hasPassword(username)) {
        return const AuthOutcome.invalidCredentials();
      }
      await _store.setPassword(username, password);
    } catch (e, s) {
      reportSwallowedError('创建本机账号失败', e, s);
      return const AuthOutcome.localCredentialUnavailable();
    }
    return const AuthOutcome.success();
  }
}
