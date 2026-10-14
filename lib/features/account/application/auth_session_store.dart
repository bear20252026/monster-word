// Monster Word App
//
// 服务端会话端口（application 层）。
//
// 为什么单独一层：**token 存在哪**（平台安全存储）与**什么时候去刷新**（会话策略）
// 是两件事。端口只管「存 / 取 / 清」，刷新策略留在上层，换存储介质不影响策略。
//
// 与 `AppPreferences.userToken` 刻意分开：
//   旧字段（userToken / userSecret）是原版遗留的用户资料缓存，语义是「上次登录的
//   用户信息」，不是「服务端会话」。若复用同一 key，登出清会话会把用户资料一起清掉，
//   反之资料缓存刷新又会覆盖会话。两者必须各有各的 key。
import 'dart:convert';

/// 服务端会话凭据。不可变值对象。
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.userId,
  });

  /// 访问令牌（JWT）。请求服务端能力时作 `Authorization: Bearer`。
  final String accessToken;

  /// 刷新令牌。登出时需用它向服务端吊销（否则「退出」只在本机生效）。
  final String refreshToken;

  /// 访问令牌过期时刻（UTC）。
  final DateTime expiresAt;

  /// 服务端用户 id。用于把本机资料与服务端账号对上。
  final String userId;

  /// 是否已过期。留 60 秒余量，避免请求正好卡在过期瞬间被判 401。
  bool isExpiredAt(DateTime now) => expiresAt.difference(now) <= const Duration(seconds: 60);

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'user_id': userId,
  };

  /// 反序列化。**任何字段缺失或损坏一律返回 null**，不抛异常——
  /// 会话读取失败只应表现为「需要重新登录」，不该让应用起不来。
  ///
  /// [onError] 用于把**真实**的解析异常交给调用方上报（本值对象不直接依赖
  /// Sentry，保持可纯单测）。只在确实解析失败时回调。
  static AuthSession? tryParse(String raw, {void Function(Object error, StackTrace stack)? onError}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (e, s) {
      onError?.call(e, s);
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      onError?.call(FormatException('会话不是 JSON 对象', raw), StackTrace.current);
      return null;
    }

    final access = decoded['access_token'];
    final refresh = decoded['refresh_token'];
    final expiresAt = DateTime.tryParse(decoded['expires_at'] as String? ?? '');
    final userId = decoded['user_id'];

    if (access is! String || access.isEmpty) return _bad('access_token', onError);
    if (refresh is! String || refresh.isEmpty) return _bad('refresh_token', onError);
    if (expiresAt == null) return _bad('expires_at', onError);
    if (userId is! String || userId.isEmpty) return _bad('user_id', onError);

    return AuthSession(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expiresAt.toUtc(),
      userId: userId,
    );
  }

  static AuthSession? _bad(String field, void Function(Object, StackTrace)? onError) {
    onError?.call(FormatException('会话缺少字段 $field'), StackTrace.current);
    return null;
  }
}

/// 会话存储端口。
///
/// 当前消费者：`SupabaseAccountAuthenticator`（登录成功后写入）。
/// [read] / [clear] 由阶段三「启动静默续期 + 登出吊销」消费——与
/// `AccountAuthenticator` 当初先于实现落地同一节奏：先把边界定死，再填消费者。
abstract interface class AuthSessionStore {
  /// 读取已保存的会话；无会话或内容损坏返回 null。
  Future<AuthSession?> read();

  /// 覆盖写入会话。
  Future<void> write(AuthSession session);

  /// 清除会话（登出）。
  Future<void> clear();
}
