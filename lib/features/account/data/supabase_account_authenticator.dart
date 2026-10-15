// Monster Word App
//
// 服务端账号认证实现（data 层）：对接自建 Supabase 的 GoTrue 认证端点。
//
// 本类只做**协议适配**——把 HTTP 状态码 / error_code 翻译成 [AuthStatus]。
// 它不做 UI、不抛异常、不猜业务（「是不是还没迁移」由 MigratingAccountAuthenticator
// 判断）。契约见 `docs/auth_server_contract.md`，其中错误码表逐条对照过
// supabase/auth 上游源码，不是照文档抄的。
//
// 三个容易踩的上游事实（都已在源码中确认）：
//   1. 密码授予**不区分**「用户不存在」与「密码错」，两者都返回
//      400 `invalid_credentials`（防用户名枚举）。所以**不能**靠登录响应判断
//      「该建号了」——`AuthStatus.needsAccountCreation` 在服务端模式下永不返回。
//   2. 注册已存在账号返回 **422 `user_already_exists`**（autoconfirm 开启时）。
//      本类按端口契约把它收敛为 `invalidCredentials`，不向用户暴露「该用户名已存在」。
//   3. `GOTRUE_MAILER_AUTOCONFIRM` 必须为 true。若为 false，注册已存在账号会返回
//      **200 但响应体里没有 access_token**（一个防枚举的假成功）。故 200 响应必须
//      校验 access_token 存在，否则判为服务端配置错误——不能当成登录成功。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/account/application/account_authenticator.dart';
import 'package:word_app/features/account/application/auth_session_store.dart';

/// HTTP 响应（只保留本适配器需要的两个字段）。
class AuthHttpResponse {
  const AuthHttpResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

/// 测试注入缝：发一个 POST 并拿回状态码 + 响应体。
/// 生产实现见 [SupabaseAccountAuthenticator._post]。
typedef AuthHttpPost = Future<AuthHttpResponse> Function(Uri url, Map<String, String> headers, String body);

class SupabaseAccountAuthenticator implements AccountAuthenticator {
  SupabaseAccountAuthenticator({
    required String baseUrl,
    required this.anonKey,
    required this.sessionStore,
    this.emailDomain = defaultEmailDomain,
    this.postOverride,
  }) : // 容忍尾部斜杠：`https://x/` 与 `https://x` 必须拼出同一个 URL，
       // 否则会请求 `//auth/v1/token`，部分反代会直接 404。
       baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  /// 服务端根地址，如 `https://auth.example.com`（**必须 HTTPS**，内网可用内部 CA）。
  final String baseUrl;

  /// Supabase anon key。公开无妨（受 RLS 约束）；
  /// **service_role key 绝不可下发到客户端**。
  final String anonKey;

  /// 用户名映射出的「邮箱」域名。不可投递、也无需邮箱服务器。
  final String emailDomain;

  /// 会话存储。登录/建号成功后写入；失败一律不外抛（见 `AuthSessionStore`）。
  final AuthSessionStore sessionStore;

  /// 测试注入：绕过真实 HTTP。
  final AuthHttpPost? postOverride;

  /// 默认内部域名。带 `-` 与 `.`，符合 GoTrue 的邮箱格式校验（`checkmail.ValidateFormat`）。
  static const String defaultEmailDomain = 'monster-word.internal';

  static const Duration _timeout = Duration(seconds: 10);

  @override
  AccountScope get scope => AccountScope.remote;

  /// 用户名 → 服务端账号地址（确定性派生）。
  ///
  /// 为什么不直接用 `用户名@域名`：本 App 的用户名只校验长度（3–32），不限制字符集，
  /// 存量用户里可能有中文、空格、`@`。GoTrue 会用 `checkmail.ValidateFormat` 校验邮箱，
  /// 非 ASCII 一律拒绝 ⇒ 这些用户**注册必然失败**且原因难以自诊。
  /// 故取用户名归一化后的 SHA-256 前 24 位十六进制（96 bit）作为 local-part：
  /// 恒为合法 ASCII 邮箱、定长、确定性。真实用户名随注册写入 `user_metadata`，
  /// 管理员在后台按它认人（配套脚本见 `deploy/supabase/tools/account-address.mjs`）。
  ///
  /// 归一化与 `SecurePasswordAuthStore` 保持一致（`trim().toLowerCase()`），
  /// 否则本机认为「同一个账号」的两个写法会在服务端变成两个账号。
  static String accountAddress(String username, {String domain = defaultEmailDomain}) {
    final normalized = username.trim().toLowerCase();
    final digest = sha256.convert(utf8.encode(normalized)).toString();
    return 'u${digest.substring(0, 24)}@$domain';
  }

  /// 本实例配置下的地址（供测试与诊断使用）。
  String addressFor(String username) => accountAddress(username, domain: emailDomain);

  @override
  Future<AuthOutcome> signIn({required String username, required String password}) async {
    return _exchange(
      path: '/auth/v1/token?grant_type=password',
      payload: {'email': addressFor(username), 'password': password},
      // 登录失败即 invalid_credentials（见文件头事实 1），
      // 是否「其实还没迁移」由 MigratingAccountAuthenticator 用本机凭据判定。
      onRejected: const AuthOutcome.invalidCredentials(),
    );
  }

  @override
  Future<AuthOutcome> createAccount({required String username, required String password}) async {
    return _exchange(
      path: '/auth/v1/signup',
      payload: {
        'email': addressFor(username),
        'password': password,
        // 管理员在后台靠它认人（地址是哈希，认不出是谁）。
        'data': {'username': username.trim()},
      },
      // 已存在 → 422 user_already_exists。按端口契约收敛为 invalidCredentials：
      // 不向用户暴露「该用户名已存在」，避免把登录页变成用户名枚举探针。
      onRejected: const AuthOutcome.invalidCredentials(),
    );
  }

  /// 两个端点的共同骨架：发请求 → 成功则存会话 → 失败则按错误码分类。
  Future<AuthOutcome> _exchange({
    required String path,
    required Map<String, dynamic> payload,
    required AuthOutcome onRejected,
  }) async {
    final AuthHttpResponse response;
    try {
      response = await _post(Uri.parse('$baseUrl$path'), {
        'Content-Type': 'application/json',
        // 与 Supabase Cloud 的调用约定保持一致（Cloud 要求 apikey）。
        // 自建栈默认不校验它——留着是为了日后迁云时客户端一行不用改。
        'apikey': anonKey,
      }, jsonEncode(payload));
    } on TimeoutException catch (e, s) {
      reportSwallowedError('认证请求超时', e, s);
      return const AuthOutcome.networkFailure();
    } on SocketException catch (e, s) {
      reportSwallowedError('认证请求网络不可达', e, s);
      return const AuthOutcome.networkFailure();
    } catch (e, s) {
      // 传输层之外的意外（TLS 握手、编码等）：归为服务端故障，提示「稍后重试」。
      reportSwallowedError('认证请求异常', e, s);
      return const AuthOutcome.serverFailure();
    }

    if (response.statusCode == 200) {
      final session = _parseSession(response.body);
      if (session == null) {
        // 200 但没有 access_token：`GOTRUE_MAILER_AUTOCONFIRM=false` 的典型症状
        // （防枚举假成功）。绝不能当登录成功——那会让用户以为登录了其实没有会话。
        reportSwallowedError(
          '认证 200 响应缺少 access_token（疑似 GOTRUE_MAILER_AUTOCONFIRM 未开启）',
          // ⚠️ 不要把 response.body 放进错误对象（2026-10-15 审计 R3-A06）：
          // reportSwallowedError 用 '$context: $error' 字符串化，而
          // FormatException.toString() 会把 source 带出来 ⇒ **access_token 的 JWT
          // 前缀会进第三方 Sentry**（其隐私政策明确说不含账号资料）。
          // 只报状态码就够定位了。
          FormatException('200 响应不是令牌响应（status=${response.statusCode}）'),
          StackTrace.current,
        );
        return const AuthOutcome.serverFailure();
      }
      await sessionStore.write(session);
      return const AuthOutcome.success();
    }

    return _classifyFailure(response.statusCode, response.body, onRejected);
  }

  /// HTTP 失败 → [AuthStatus]。映射表见 `docs/auth_server_contract.md` §3。
  AuthOutcome _classifyFailure(int status, String body, AuthOutcome onRejected) {
    // 429 不细分错误码：GoTrue 有多个 429 码（请求限流 / 邮件限流 / 短信限流），
    // 对用户而言都是「太频繁」，细分只会在上游加新码时漏掉。
    if (status == 429) return const AuthOutcome.tooManyAttempts();
    if (status >= 500) return const AuthOutcome.serverFailure();

    // 401/403 在正常路径上不该出现：它几乎只意味着网关侧配置有问题
    // （例如启用了 apikey 门禁而客户端密钥不对）。给一句能指向「找管理员」的文案，
    // 否则用户会一直重试一个永远失败的动作。
    if (status == 401 || status == 403) {
      return const AuthOutcome(AuthStatus.serverFailure, message: '服务端拒绝了请求（客户端密钥配置可能有误），请联系管理员');
    }

    switch (_errorCode(body)) {
      case 'invalid_credentials':
      case 'user_already_exists':
      case 'email_exists':
        return onRejected;
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return const AuthOutcome.tooManyAttempts();
      case 'validation_failed':
        // 例如服务端密码策略比客户端严（客户端只校验 6–64 位）。
        // 不能并进「账号或密码不正确」——那会让用户反复重输同一个密码，
        // 而真正的动作是「换一个更复杂的密码」。
        return const AuthOutcome(AuthStatus.serverFailure, message: '服务端拒绝了该请求（密码可能不满足服务端策略），请换一个更复杂的密码');
      case 'email_not_confirmed':
        // autoconfirm 开启时不该出现；出现即服务端配置问题，别让用户白改密码。
        return const AuthOutcome(AuthStatus.serverFailure, message: '账号尚未激活，请联系管理员');
      case 'user_banned':
        return const AuthOutcome(AuthStatus.serverFailure, message: '账号已被停用，请联系管理员');
      case 'signup_disabled':
        return const AuthOutcome(AuthStatus.serverFailure, message: '服务端已关闭注册，请联系管理员');
      default:
        return const AuthOutcome.serverFailure();
    }
  }

  /// 从错误响应体里取 `error_code`（GoTrue 的 `HTTPError` JSON 字段名，勿改）。
  String? _errorCode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      final code = decoded['error_code'];
      return code is String ? code : null;
    } catch (_) {
      // 非 JSON 响应体（如反代返回的 HTML 错误页）→ 交给调用方按状态码兜底。
      return null;
    }
  }

  /// 解析成功响应为会话。字段名见 GoTrue `AccessTokenResponse`。
  AuthSession? _parseSession(String body) {
    final Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      json = decoded;
    } catch (e, s) {
      // 只报类型、不报原文（2026-10-15 审计 R3-A06）：jsonDecode 抛的 FormatException
      // **自带 source（= 响应体）**，而 reportSwallowedError 会把它字符串化 ⇒
      // access_token 的 JWT 前缀会进第三方 Sentry。
      reportSwallowedError('认证成功响应解析失败（${e.runtimeType}；响应体刻意不入日志）', StateError('认证响应不是合法 JSON'), s);
      return null;
    }

    final accessToken = json['access_token'];
    final refreshToken = json['refresh_token'];
    if (accessToken is! String || accessToken.isEmpty) return null;
    if (refreshToken is! String || refreshToken.isEmpty) return null;

    final userId = (json['user'] is Map<String, dynamic>) ? (json['user'] as Map<String, dynamic>)['id'] : null;
    if (userId is! String || userId.isEmpty) return null;

    // expires_in 是相对秒数；缺失时按 1 小时（契约 §4 的约定值）兜底，
    // 宁可保守也不要让 token 被当成「永不过期」。
    final expiresIn = json['expires_in'];
    final seconds = expiresIn is int && expiresIn > 0 ? expiresIn : 3600;

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: seconds)),
      userId: userId,
    );
  }

  Future<AuthHttpResponse> _post(Uri url, Map<String, String> headers, String body) async {
    final override = postOverride;
    if (override != null) return override(url, headers, body);

    final client = HttpClient();
    try {
      final request = await client.postUrl(url).timeout(_timeout);
      headers.forEach(request.headers.set);
      request.write(body);
      final response = await request.close().timeout(_timeout);
      final text = await response.transform(utf8.decoder).join().timeout(_timeout);
      return AuthHttpResponse(response.statusCode, text);
    } finally {
      client.close(force: true);
    }
  }
}
