// Monster Word App
//
// 服务端认证配置（编译期注入）。
//
// 用法：
//   flutter build windows \
//     --dart-define=AUTH_BASE_URL=https://auth.example.com \
//     --dart-define=AUTH_ANON_KEY=<anon key>
//
// 未注入时 [AuthServerConfig.isConfigured] 为 false，装配点回退到本机模式
// （`LocalAccountAuthenticator`）。**为什么回退而不是报错**：CI 与本地开发不注入
// 这两个值；若默认就走服务端，所有测试和本地运行都会去连一个不存在的地址，
// 把「没配置」变成「登录坏了」。
//
// 安全：这里只放 **anon key**（公开无妨，受 RLS 约束）。
// service_role key 绝不可出现在客户端，也不要通过 --dart-define 传进来。

/// 编译期注入的服务端认证配置。
class AuthServerConfig {
  const AuthServerConfig({required this.baseUrl, required this.anonKey});

  /// 服务端根地址（不含 `/auth/v1`）。**必须 HTTPS**。
  final String baseUrl;

  /// Supabase anon key。
  final String anonKey;

  /// 从 `--dart-define` 读取。CI 默认空串 ⇒ 本机模式。
  ///
  /// 刻意**不**提供「邮箱域名」的注入项：账号地址由用户名哈希派生，
  /// 域名只要求**恒定**。做成可配置等于给了个「改一下就与所有存量账号失联」
  /// 的开关，没有对应的收益。
  static const AuthServerConfig fromEnvironment = AuthServerConfig(
    baseUrl: String.fromEnvironment('AUTH_BASE_URL'),
    anonKey: String.fromEnvironment('AUTH_ANON_KEY'),
  );

  /// 两项都非空才算配置完成——只配一半（比如漏了 key）应视为未配置，
  /// 否则会连上去被 401 挡下，错误信息比「本机模式」更难自诊。
  bool get isConfigured => baseUrl.trim().isNotEmpty && anonKey.trim().isNotEmpty;
}
