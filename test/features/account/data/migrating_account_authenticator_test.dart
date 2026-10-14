// MigratingAccountAuthenticator 单元测试。
//
// 这是「存量用户无感迁移」的全部逻辑所在，也是最容易做错的地方：
//   - 判据太宽（比如「服务端拒绝就建号」）→ 用户每次打错密码都发一次注册请求，
//     既浪费又会撞限流；
//   - 判据太窄 → 存量用户永远登不上，只能逐个找管理员。
//
// 正确判据只有一条：**本机凭据能校验通过 ⇒ 用户输入的密码是对的 ⇒ 服务端仍拒绝
// ⇒ 服务端确实没有这个账号**。下面把这条判据的正反面都锁死。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/account/application/account_authenticator.dart';
import 'package:word_app/features/account/application/password_auth_store.dart';
import 'package:word_app/features/account/data/migrating_account_authenticator.dart';

/// 可编排的服务端替身：按调用顺序吐预设结果，并记录收到的调用。
class _ScriptedRemote implements AccountAuthenticator {
  _ScriptedRemote({this.signInResults = const [], this.createAccountResults = const []});

  final List<AuthOutcome> signInResults;
  final List<AuthOutcome> createAccountResults;

  final List<String> signInCalls = [];
  final List<String> createAccountCalls = [];

  @override
  AccountScope get scope => AccountScope.remote;

  @override
  Future<AuthOutcome> signIn({required String username, required String password}) async {
    signInCalls.add(username);
    return signInResults.isEmpty ? const AuthOutcome.invalidCredentials() : signInResults.removeAt(0);
  }

  @override
  Future<AuthOutcome> createAccount({required String username, required String password}) async {
    createAccountCalls.add(username);
    return createAccountResults.isEmpty ? const AuthOutcome.invalidCredentials() : createAccountResults.removeAt(0);
  }
}

/// 本机凭据替身。
class _FakeLocalStore implements PasswordAuthStore {
  // 拷贝成可变 map：默认值若是 const {} ，removePassword 会在测试里抛
  // UnsupportedError，把「实现有问题」伪装成「测试写错了」。
  _FakeLocalStore({Map<String, String>? known, this.throwOnRead = false}) : known = {...?known};

  /// 用户名 → 本机保存的密码。
  final Map<String, String> known;
  bool throwOnRead;
  final List<String> removeCalls = [];

  @override
  Future<bool> hasPassword(String username) async {
    if (throwOnRead) throw StateError('secure storage unavailable');
    return known.containsKey(username);
  }

  @override
  Future<bool> verify(String username, String password) async {
    if (throwOnRead) throw StateError('secure storage unavailable');
    return known[username] == password;
  }

  @override
  Future<void> setPassword(String username, String password) async => known[username] = password;

  @override
  Future<void> removePassword(String username) async {
    removeCalls.add(username);
    known.remove(username);
  }
}

void main() {
  group('scope 透传', () {
    test('报告内层实现的 scope（UI 文案据此区分本机/服务端）', () {
      final auth = MigratingAccountAuthenticator(remote: _ScriptedRemote(), localStore: _FakeLocalStore());
      expect(auth.scope, AccountScope.remote);
    });
  });

  group('登录：非 invalidCredentials 一律原样透传', () {
    test('服务端成功 → success，不碰本机凭据、不发注册', () async {
      final remote = _ScriptedRemote(signInResults: [const AuthOutcome.success()]);
      final local = _FakeLocalStore(known: {'alice': 'secret123'});
      final result = await MigratingAccountAuthenticator(
        remote: remote,
        localStore: local,
      ).signIn(username: 'alice', password: 'secret123');

      expect(result.status, AuthStatus.success);
      expect(remote.createAccountCalls, isEmpty);
      expect(local.removeCalls, isEmpty);
    });

    test('网络不通 → networkFailure（不得当成「账号不存在」去建号）', () async {
      final remote = _ScriptedRemote(signInResults: [const AuthOutcome.networkFailure()]);
      final result = await MigratingAccountAuthenticator(
        remote: remote,
        localStore: _FakeLocalStore(known: {'alice': 'secret123'}),
      ).signIn(username: 'alice', password: 'secret123');

      expect(result.status, AuthStatus.networkFailure);
      expect(remote.createAccountCalls, isEmpty, reason: '网络问题绝不能被解释成账号不存在');
    });

    test('限流 → tooManyAttempts（不得当成「账号不存在」去建号）', () async {
      final remote = _ScriptedRemote(signInResults: [const AuthOutcome.tooManyAttempts()]);
      final result = await MigratingAccountAuthenticator(
        remote: remote,
        localStore: _FakeLocalStore(known: {'alice': 'secret123'}),
      ).signIn(username: 'alice', password: 'secret123');

      expect(result.status, AuthStatus.tooManyAttempts);
      expect(remote.createAccountCalls, isEmpty);
    });
  });

  group('登录被拒时的迁移判定', () {
    test('本机凭据校验通过 + 服务端拒绝 → 判定为未迁移，建号成功并清除本机哈希', () async {
      final remote = _ScriptedRemote(
        signInResults: [const AuthOutcome.invalidCredentials()],
        createAccountResults: [const AuthOutcome.success()],
      );
      final local = _FakeLocalStore(known: {'alice': 'secret123'});

      final result = await MigratingAccountAuthenticator(
        remote: remote,
        localStore: local,
      ).signIn(username: 'alice', password: 'secret123');

      expect(result.status, AuthStatus.success);
      expect(remote.createAccountCalls, ['alice']);
      expect(local.removeCalls, ['alice'], reason: '迁到服务端后本机不该再留密码哈希');
    });

    test('本机凭据校验不通过 → 如实回报 invalidCredentials，不发注册', () async {
      final remote = _ScriptedRemote(signInResults: [const AuthOutcome.invalidCredentials()]);
      final local = _FakeLocalStore(known: {'alice': 'right-password'});

      final result = await MigratingAccountAuthenticator(
        remote: remote,
        localStore: local,
      ).signIn(username: 'alice', password: 'typo');

      expect(result.status, AuthStatus.invalidCredentials);
      expect(remote.createAccountCalls, isEmpty, reason: '打错密码不该触发注册请求（否则每次手滑都打一次服务端）');
    });

    test('本机压根没有该用户名（新设备/新用户）→ invalidCredentials，不发注册', () async {
      final remote = _ScriptedRemote(signInResults: [const AuthOutcome.invalidCredentials()]);
      final result = await MigratingAccountAuthenticator(
        remote: remote,
        localStore: _FakeLocalStore(),
      ).signIn(username: 'alice', password: 'secret123');

      expect(result.status, AuthStatus.invalidCredentials);
      expect(remote.createAccountCalls, isEmpty);
    });

    test('建号时发现服务端其实已有该账号 → invalidCredentials，且不清本机凭据', () async {
      // 场景：本机凭据是旧的（服务端改过密码），或确认弹窗期间账号已被建。
      // GoTrue 对已确认账号直接返回 user_already_exists，在写密码之前短路——
      // 所以这里最坏只是「多一次无副作用的失败请求」，不会改掉别人的密码。
      final remote = _ScriptedRemote(
        signInResults: [const AuthOutcome.invalidCredentials()],
        createAccountResults: [const AuthOutcome.invalidCredentials()],
      );
      final local = _FakeLocalStore(known: {'alice': 'secret123'});

      final result = await MigratingAccountAuthenticator(
        remote: remote,
        localStore: local,
      ).signIn(username: 'alice', password: 'secret123');

      expect(result.status, AuthStatus.invalidCredentials);
      expect(local.removeCalls, isEmpty, reason: '没迁成功就不该清本机凭据');
    });

    test('建号遇到网络故障 → 原样回报 networkFailure，不清本机凭据（下次可重试）', () async {
      final remote = _ScriptedRemote(
        signInResults: [const AuthOutcome.invalidCredentials()],
        createAccountResults: [const AuthOutcome.networkFailure()],
      );
      final local = _FakeLocalStore(known: {'alice': 'secret123'});

      final result = await MigratingAccountAuthenticator(
        remote: remote,
        localStore: local,
      ).signIn(username: 'alice', password: 'secret123');

      expect(result.status, AuthStatus.networkFailure);
      expect(local.removeCalls, isEmpty);
    });

    test('本机安全存储不可用 → 保守放弃迁移（无法证明密码正确就不建号）', () async {
      final remote = _ScriptedRemote(signInResults: [const AuthOutcome.invalidCredentials()]);
      final result = await MigratingAccountAuthenticator(
        remote: remote,
        localStore: _FakeLocalStore(known: {'alice': 'secret123'}, throwOnRead: true),
      ).signIn(username: 'alice', password: 'secret123');

      expect(result.status, AuthStatus.invalidCredentials);
      expect(remote.createAccountCalls, isEmpty, reason: '读不到本机证据时不得擅自建号');
    });
  });

  group('直接创建账号', () {
    test('成功 → 清本机凭据', () async {
      final remote = _ScriptedRemote(createAccountResults: [const AuthOutcome.success()]);
      final local = _FakeLocalStore();
      final result = await MigratingAccountAuthenticator(
        remote: remote,
        localStore: local,
      ).createAccount(username: 'newbie', password: 'secret123');

      expect(result.status, AuthStatus.success);
      expect(local.removeCalls, ['newbie']);
    });

    test('失败 → 不清本机凭据', () async {
      final remote = _ScriptedRemote(createAccountResults: [const AuthOutcome.invalidCredentials()]);
      final local = _FakeLocalStore();
      await MigratingAccountAuthenticator(
        remote: remote,
        localStore: local,
      ).createAccount(username: 'newbie', password: 'secret123');
      expect(local.removeCalls, isEmpty);
    });
  });
}
