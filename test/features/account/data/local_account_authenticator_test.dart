// LocalAccountAuthenticator 单元测试。
//
// 为什么单独测这一层：它是**策略**（什么算登录成功），而 SecurePasswordAuthStore
// 是**存储**（盐值+哈希存哪）。分开测的价值在于——R2-01 阶段二的服务端实现必须
// 满足同一组行为契约，届时这些断言可以照搬（只换被测实现）。所以下面的断言
// 只依赖 AccountAuthenticator 的对外行为，不碰任何存储细节。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/account/application/account_authenticator.dart';
import 'package:word_app/features/account/application/password_auth_store.dart';
import 'package:word_app/features/account/data/local_account_authenticator.dart';

/// 可控假存储：能分别注入「账号存在」与「安全存储抛异常」两种故障。
class _FakeStore implements PasswordAuthStore {
  _FakeStore({this.exists = false, this.password = 'secret123'});

  bool exists;
  String password;
  bool throwOnHasPassword = false;
  bool throwOnVerify = false;
  bool throwOnSetPassword = false;

  final List<(String, String)> setCalls = [];
  final List<String> removeCalls = [];

  @override
  Future<bool> hasPassword(String username) async {
    if (throwOnHasPassword) throw StateError('secure storage unavailable');
    return exists;
  }

  @override
  Future<bool> verify(String username, String password) async {
    if (throwOnVerify) throw StateError('secure storage unavailable');
    return this.password == password;
  }

  @override
  Future<void> setPassword(String username, String password) async {
    if (throwOnSetPassword) throw StateError('secure storage unavailable');
    setCalls.add((username, password));
    exists = true;
    this.password = password;
  }

  @override
  Future<void> removePassword(String username) async {
    removeCalls.add(username);
    exists = false;
  }
}

void main() {
  group('LocalAccountAuthenticator', () {
    test('scope 为本机（UI 据此告知用户密码不出本机）', () {
      expect(LocalAccountAuthenticator(_FakeStore()).scope, AccountScope.local);
    });

    test('账号不存在 → needsAccountCreation，而不是失败', () async {
      final auth = LocalAccountAuthenticator(_FakeStore(exists: false));
      final result = await auth.signIn(username: 'alice', password: 'secret123');
      expect(result.status, AuthStatus.needsAccountCreation);
      expect(result.ok, isFalse, reason: '尚未建立会话，不能算成功');
    });

    test('密码正确 → success', () async {
      final auth = LocalAccountAuthenticator(_FakeStore(exists: true, password: 'secret123'));
      expect((await auth.signIn(username: 'alice', password: 'secret123')).status, AuthStatus.success);
    });

    test('密码错误 → invalidCredentials（不得混同为服务端故障）', () async {
      final auth = LocalAccountAuthenticator(_FakeStore(exists: true, password: 'secret123'));
      expect((await auth.signIn(username: 'alice', password: 'wrong')).status, AuthStatus.invalidCredentials);
    });

    test('安全存储读失败 → localCredentialUnavailable（不冒充密码错误）', () async {
      final store = _FakeStore(exists: true)..throwOnVerify = true;
      final auth = LocalAccountAuthenticator(store);
      expect(
        (await auth.signIn(username: 'alice', password: 'secret123')).status,
        AuthStatus.localCredentialUnavailable,
        reason: '系统还原/Keystore 故障时提示「密码不正确」会把用户引向无用的重试',
      );
    });

    test('hasPassword 抛异常时同样归类为 localCredentialUnavailable', () async {
      final store = _FakeStore()..throwOnHasPassword = true;
      expect(
        (await LocalAccountAuthenticator(store).signIn(username: 'alice', password: 'secret123')).status,
        AuthStatus.localCredentialUnavailable,
      );
    });

    test('createAccount 成功后该账号即可登录', () async {
      final store = _FakeStore(exists: false);
      final auth = LocalAccountAuthenticator(store);
      expect((await auth.createAccount(username: 'alice', password: 'secret123')).status, AuthStatus.success);
      expect(store.setCalls, [('alice', 'secret123')]);
      expect((await auth.signIn(username: 'alice', password: 'secret123')).status, AuthStatus.success);
    });

    test('createAccount 遇到已存在账号 → 拒绝且不覆盖原密码', () async {
      // setPassword 每次换新盐，直接覆盖会把原密码作废。确认弹窗期间账号被
      // 建出来时，必须拒绝而不是静默重置。
      final store = _FakeStore(exists: true, password: 'original');
      final auth = LocalAccountAuthenticator(store);
      expect((await auth.createAccount(username: 'alice', password: 'attacker')).status, AuthStatus.invalidCredentials);
      expect(store.setCalls, isEmpty, reason: '不得写入');
      expect((await auth.signIn(username: 'alice', password: 'original')).status, AuthStatus.success);
    });

    test('createAccount 写失败 → localCredentialUnavailable', () async {
      final store = _FakeStore(exists: false)..throwOnSetPassword = true;
      expect(
        (await LocalAccountAuthenticator(store).createAccount(username: 'a', password: 'secret123')).status,
        AuthStatus.localCredentialUnavailable,
      );
    });
  });
}
