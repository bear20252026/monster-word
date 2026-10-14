// SupabaseAccountAuthenticator 单元测试。
//
// 为什么这组测试重要：这个类的全部价值就是把 HTTP 状态码 / error_code 翻译成
// 用户能据此行动的分类。翻错一个码，用户就会被引向**错误的动作**——
// 把「服务端密码策略拒绝」说成「密码不正确」会让人反复重输同一个密码。
// 故这里逐条锁死映射，并覆盖上游源码里确认过的几个反直觉行为。
//
// 契约见 docs/auth_server_contract.md §3。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/account/application/account_authenticator.dart';
import 'package:word_app/features/account/application/auth_session_store.dart';
import 'package:word_app/features/account/data/supabase_account_authenticator.dart';

/// 内存会话存储替身。
class _FakeSessionStore implements AuthSessionStore {
  AuthSession? stored;
  int writeCount = 0;

  @override
  Future<AuthSession?> read() async => stored;

  @override
  Future<void> write(AuthSession session) async {
    stored = session;
    writeCount++;
  }

  @override
  Future<void> clear() async => stored = null;
}

/// 记录请求并按预设脚本应答。
class _ScriptedHttp {
  _ScriptedHttp(this.statusCode, this.body);

  int statusCode;
  String body;

  final List<Uri> urls = [];
  final List<Map<String, String>> headers = [];
  final List<String> bodies = [];

  Future<AuthHttpResponse> call(Uri url, Map<String, String> h, String b) async {
    urls.add(url);
    headers.add(h);
    bodies.add(b);
    return AuthHttpResponse(statusCode, body);
  }
}

/// GoTrue 错误响应体（字段名取自上游 `apierrors.HTTPError` 的 json tag）。
String gotrueError(int status, String code, String msg) =>
    jsonEncode({'code': status, 'error_code': code, 'msg': msg});

/// GoTrue 成功响应体（字段名取自上游 `tokens.AccessTokenResponse`）。
String gotrueToken({String access = 'access-jwt', String refresh = 'refresh-opaque', int expiresIn = 3600}) => jsonEncode({
  'access_token': access,
  'token_type': 'bearer',
  'expires_in': expiresIn,
  'expires_at': 1790000000,
  'refresh_token': refresh,
  'user': {'id': 'user-uuid-1'},
});

void main() {
  late _FakeSessionStore sessionStore;

  setUp(() => sessionStore = _FakeSessionStore());

  SupabaseAccountAuthenticator build(_ScriptedHttp http) => SupabaseAccountAuthenticator(
    baseUrl: 'https://auth.example.com',
    anonKey: 'anon-key',
    sessionStore: sessionStore,
    postOverride: http.call,
  );

  group('scope 与端点', () {
    test('scope 为 remote（UI 据此把创建账号弹窗改成「密码会提交给服务端」）', () {
      expect(build(_ScriptedHttp(200, gotrueToken())).scope, AccountScope.remote);
    });

    test('登录打 /auth/v1/token?grant_type=password，带 apikey 与 JSON 体', () async {
      final http = _ScriptedHttp(200, gotrueToken());
      await build(http).signIn(username: 'alice', password: 'secret123');

      expect(http.urls.single.toString(), 'https://auth.example.com/auth/v1/token?grant_type=password');
      expect(http.headers.single['apikey'], 'anon-key');
      expect(http.headers.single['Content-Type'], 'application/json');
      final sent = jsonDecode(http.bodies.single) as Map<String, dynamic>;
      expect(sent['email'], SupabaseAccountAuthenticator.accountAddress('alice'));
      expect(sent['password'], 'secret123');
    });

    test('注册打 /auth/v1/signup，并把真实用户名放进 user_metadata（地址是哈希，认不出人）', () async {
      final http = _ScriptedHttp(200, gotrueToken());
      await build(http).createAccount(username: '小明', password: 'secret123');

      expect(http.urls.single.toString(), 'https://auth.example.com/auth/v1/signup');
      final sent = jsonDecode(http.bodies.single) as Map<String, dynamic>;
      expect((sent['data'] as Map<String, dynamic>)['username'], '小明');
    });

    test('baseUrl 带尾斜杠不会拼出 //auth/v1', () async {
      final http = _ScriptedHttp(200, gotrueToken());
      final auth = SupabaseAccountAuthenticator(
        baseUrl: 'https://auth.example.com/',
        anonKey: 'anon-key',
        sessionStore: sessionStore,
        postOverride: http.call,
      );
      await auth.signIn(username: 'alice', password: 'secret123');
      expect(http.urls.single.toString(), 'https://auth.example.com/auth/v1/token?grant_type=password');
    });
  });

  group('账号地址派生（任意用户名都要产出合法邮箱）', () {
    // GoTrue 用 checkmail.ValidateFormat 校验邮箱，非 ASCII 一律拒绝。
    // 而本 App 的用户名只校验长度（3–32），不限制字符集——所以不能直接拼用户名。
    final validEmail = RegExp(r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$");

    test('中文用户名也产出合法 ASCII 邮箱', () {
      final addr = SupabaseAccountAuthenticator.accountAddress('小明同学');
      expect(validEmail.hasMatch(addr), isTrue, reason: addr);
      expect(addr.contains('@'), isTrue);
      expect(addr.split('@').length, 2, reason: '用户名里的特殊字符不得再拼出第二个 @');
    });

    test('含空格、@、引号等特殊字符的用户名同样安全', () {
      for (final name in ['a b c', 'a@b', 'x"y', "o'brien", 'a/b', 'emoji🙂']) {
        expect(validEmail.hasMatch(SupabaseAccountAuthenticator.accountAddress(name)), isTrue, reason: name);
      }
    });

    test('确定性：同一用户名恒得同一地址（否则存量用户永远登不上）', () {
      expect(
        SupabaseAccountAuthenticator.accountAddress('alice'),
        SupabaseAccountAuthenticator.accountAddress('alice'),
      );
    });

    test('归一化与 SecurePasswordAuthStore 一致：trim + 小写视为同一账号', () {
      final base = SupabaseAccountAuthenticator.accountAddress('alice');
      expect(SupabaseAccountAuthenticator.accountAddress('  alice  '), base);
      expect(SupabaseAccountAuthenticator.accountAddress('ALICE'), base);
      expect(SupabaseAccountAuthenticator.accountAddress('Alice'), base);
    });

    test('不同用户名不碰撞', () {
      expect(
        SupabaseAccountAuthenticator.accountAddress('alice'),
        isNot(SupabaseAccountAuthenticator.accountAddress('alica')),
      );
    });

    test('长度恒定为 u + 24 位十六进制（96 bit），不会撞 GoTrue 的 255 字符上限', () {
      final local = SupabaseAccountAuthenticator.accountAddress('x' * 32).split('@').first;
      expect(local.length, 25);
      expect(local.startsWith('u'), isTrue);
    });
  });

  group('成功路径', () {
    test('登录成功 → success，且会话被持久化', () async {
      final http = _ScriptedHttp(200, gotrueToken(access: 'jwt-1', refresh: 'rt-1', expiresIn: 7200));
      final result = await build(http).signIn(username: 'alice', password: 'secret123');

      expect(result.status, AuthStatus.success);
      expect(result.ok, isTrue);
      expect(sessionStore.writeCount, 1);
      expect(sessionStore.stored!.accessToken, 'jwt-1');
      expect(sessionStore.stored!.refreshToken, 'rt-1');
      expect(sessionStore.stored!.userId, 'user-uuid-1');
    });

    test('expires_in 换算成绝对过期时刻', () async {
      await build(_ScriptedHttp(200, gotrueToken(expiresIn: 3600))).signIn(username: 'alice', password: 'p');
      final remaining = sessionStore.stored!.expiresAt.difference(DateTime.now().toUtc());
      expect(remaining.inMinutes, closeTo(60, 1));
    });

    test('expires_in 缺失时按 1 小时兜底，不得当成永不过期', () async {
      final body = jsonEncode({
        'access_token': 'a',
        'refresh_token': 'r',
        'user': {'id': 'u'},
      });
      await build(_ScriptedHttp(200, body)).signIn(username: 'alice', password: 'p');
      final remaining = sessionStore.stored!.expiresAt.difference(DateTime.now().toUtc());
      expect(remaining.inMinutes, closeTo(60, 1));
    });

    test('200 但响应体没有 access_token → serverFailure（不得当登录成功）', () async {
      // GOTRUE_MAILER_AUTOCONFIRM=false 时的防枚举假成功：200 + 脱敏 user，无会话。
      // 若当成功，用户会「以为登录了」但实际没有会话。
      final body = jsonEncode({'id': 'u', 'email': 'u123@monster-word.internal'});
      final result = await build(_ScriptedHttp(200, body)).createAccount(username: 'alice', password: 'p');
      expect(result.status, AuthStatus.serverFailure);
      expect(sessionStore.writeCount, 0, reason: '不得写入半截会话');
    });

    test('200 但响应体不是 JSON → serverFailure', () async {
      final result = await build(_ScriptedHttp(200, '<html>gateway</html>')).signIn(username: 'alice', password: 'p');
      expect(result.status, AuthStatus.serverFailure);
    });
  });

  group('失败分类（映射表逐条锁定）', () {
    test('密码错 400 invalid_credentials → invalidCredentials', () async {
      final http = _ScriptedHttp(400, gotrueError(400, 'invalid_credentials', 'Invalid login credentials'));
      expect((await build(http).signIn(username: 'alice', password: 'bad')).status, AuthStatus.invalidCredentials);
    });

    test('账号不存在也是 400 invalid_credentials → invalidCredentials（服务端不区分，防枚举）', () async {
      // 上游源码：models.IsNotFoundError(err) 时返回的仍是 invalid_credentials。
      // 所以服务端模式下 needsAccountCreation 永不返回——「该建号了」由
      // MigratingAccountAuthenticator 用本机凭据判定，不靠这个响应。
      final http = _ScriptedHttp(400, gotrueError(400, 'invalid_credentials', 'Invalid login credentials'));
      final result = await build(http).signIn(username: 'brand-new-user', password: 'secret123');
      expect(result.status, AuthStatus.invalidCredentials);
      expect(result.status, isNot(AuthStatus.needsAccountCreation));
    });

    test('注册已存在 422 user_already_exists → invalidCredentials（收敛，不暴露用户名存在）', () async {
      final http = _ScriptedHttp(422, gotrueError(422, 'user_already_exists', 'User already registered'));
      expect((await build(http).createAccount(username: 'alice', password: 'p')).status, AuthStatus.invalidCredentials);
    });

    test('429 → tooManyAttempts', () async {
      final http = _ScriptedHttp(429, gotrueError(429, 'over_request_rate_limit', 'Too many requests'));
      expect((await build(http).signIn(username: 'alice', password: 'p')).status, AuthStatus.tooManyAttempts);
    });

    test('429 且错误码陌生 → 仍归 tooManyAttempts（上游加新码不得漏判）', () async {
      final http = _ScriptedHttp(429, gotrueError(429, 'some_future_code', 'x'));
      expect((await build(http).signIn(username: 'alice', password: 'p')).status, AuthStatus.tooManyAttempts);
    });

    test('5xx → serverFailure', () async {
      for (final status in [500, 502, 503]) {
        final http = _ScriptedHttp(status, gotrueError(status, 'unexpected_failure', 'boom'));
        expect(
          (await build(http).signIn(username: 'alice', password: 'p')).status,
          AuthStatus.serverFailure,
          reason: 'HTTP $status',
        );
      }
    });

    test('400 validation_failed 不得说成「密码不正确」——真正的动作是换更强的密码', () async {
      final http = _ScriptedHttp(400, gotrueError(400, 'validation_failed', 'Password too weak'));
      final result = await build(http).createAccount(username: 'alice', password: 'secret123');
      expect(result.status, isNot(AuthStatus.invalidCredentials));
      expect(result.status, AuthStatus.serverFailure);
      expect(result.message, contains('密码'));
    });

    test('email_not_confirmed → 提示联系管理员（服务端配置问题，不该让用户白改密码）', () async {
      final http = _ScriptedHttp(400, gotrueError(400, 'email_not_confirmed', 'Email not confirmed'));
      final result = await build(http).signIn(username: 'alice', password: 'p');
      expect(result.status, isNot(AuthStatus.invalidCredentials));
      expect(result.message, contains('管理员'));
    });

    test('user_banned → 提示账号已停用', () async {
      final http = _ScriptedHttp(400, gotrueError(400, 'user_banned', 'User is banned'));
      expect((await build(http).signIn(username: 'alice', password: 'p')).message, contains('停用'));
    });

    test('signup_disabled → 提示服务端已关闭注册', () async {
      final http = _ScriptedHttp(422, gotrueError(422, 'signup_disabled', 'Signups not allowed'));
      expect((await build(http).createAccount(username: 'alice', password: 'p')).message, contains('注册'));
    });

    test('非 JSON 错误体（反代 HTML 错误页）→ 按状态码兜底为 serverFailure', () async {
      final http = _ScriptedHttp(403, '<html>Forbidden</html>');
      expect((await build(http).signIn(username: 'alice', password: 'p')).status, AuthStatus.serverFailure);
    });

    test('401/403 → serverFailure 且提示找管理员（指向网关密钥配置问题）', () async {
      for (final status in [401, 403]) {
        final http = _ScriptedHttp(status, gotrueError(status, 'no_authorization', 'Invalid API key'));
        final result = await build(http).signIn(username: 'alice', password: 'p');
        expect(result.status, AuthStatus.serverFailure, reason: 'HTTP $status');
        expect(result.message, contains('管理员'), reason: 'HTTP $status：不该让用户反复重试一个永远失败的动作');
      }
    });
  });

  group('网络层', () {
    test('连接不可达 → networkFailure（不是 serverFailure，用户该查网络而非等待）', () async {
      final auth = SupabaseAccountAuthenticator(
        baseUrl: 'https://auth.example.com',
        anonKey: 'anon-key',
        sessionStore: sessionStore,
        postOverride: (_, _, _) async => throw const SocketException('connection refused'),
      );
      expect((await auth.signIn(username: 'alice', password: 'p')).status, AuthStatus.networkFailure);
    });

    test('超时 → networkFailure', () async {
      final auth = SupabaseAccountAuthenticator(
        baseUrl: 'https://auth.example.com',
        anonKey: 'anon-key',
        sessionStore: sessionStore,
        postOverride: (_, _, _) async => throw TimeoutException('too slow'),
      );
      expect((await auth.signIn(username: 'alice', password: 'p')).status, AuthStatus.networkFailure);
    });

    test('其它意外异常 → serverFailure', () async {
      final auth = SupabaseAccountAuthenticator(
        baseUrl: 'https://auth.example.com',
        anonKey: 'anon-key',
        sessionStore: sessionStore,
        postOverride: (_, _, _) async => throw StateError('unexpected'),
      );
      expect((await auth.signIn(username: 'alice', password: 'p')).status, AuthStatus.serverFailure);
    });

    test('失败时不得写入会话', () async {
      final http = _ScriptedHttp(400, gotrueError(400, 'invalid_credentials', 'Invalid login credentials'));
      await build(http).signIn(username: 'alice', password: 'bad');
      expect(sessionStore.writeCount, 0);
    });
  });
}
