// 真机（Android 模拟器）端到端：用**真实的** `SupabaseAccountAuthenticator`
// 打真实服务端，验证「客户端真实实现 ↔ 服务端契约」一致。
//
// 与 `deploy/tools/smoke-test.mjs` 的区别：那个是 Node 复刻客户端算法；
// 这个是**真的跑客户端代码**（含 Dart 的 SHA-256 派生、HTTP 组装、错误码映射）。
//
// 运行：
//   flutter test integration_test/e2e_real_auth_test.dart -d emulator-5554 \
//     --dart-define=AUTH_BASE_URL=https://auth.cloudbear.cloud
//
// ⚠️ 会在生产库建一个真实账号，跑完需清理（测试会打印 userId）。
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:word_app/features/account/application/account_authenticator.dart';
import 'package:word_app/features/account/application/auth_session_store.dart';
import 'package:word_app/features/account/data/supabase_account_authenticator.dart';

/// 内存会话存储：只验证「成功后写入了什么」，不碰真实 secure storage。
class _MemorySessionStore implements AuthSessionStore {
  AuthSession? saved;
  int writes = 0;

  @override
  Future<AuthSession?> read() async => saved;

  @override
  Future<void> write(AuthSession session) async {
    saved = session;
    writes++;
  }

  @override
  Future<void> clear() async {
    saved = null;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const baseUrl = String.fromEnvironment('AUTH_BASE_URL');
  final stamp = DateTime.now().millisecondsSinceEpoch;
  // 含中文 + 空格，顺带验「非 ASCII 用户名」这条设计目标。
  final username = 'e2e真机 $stamp';
  final password = 'Probe${stamp}Aa1!';

  // ⚠️ 未注入 AUTH_BASE_URL 时**自动跳过**，而不是失败：
  // 本测试会打真实服务端并在生产库建账号，不该在无配置的 CI/本地被误触发。
  final skipReason = baseUrl.isEmpty ? '需要 --dart-define=AUTH_BASE_URL=<服务端地址>' : null;

  testWidgets('真实认证器 ↔ 真实服务端：注册/登录/归一化/错误码', (tester) async {
    expect(baseUrl, isNotEmpty, reason: '必须注入 --dart-define=AUTH_BASE_URL');

    final store = _MemorySessionStore();
    final auth = SupabaseAccountAuthenticator(baseUrl: baseUrl, anonKey: 'e2e-probe', sessionStore: store);

    // 1) 派生地址：确定性 + 格式
    final addr = SupabaseAccountAuthenticator.accountAddress(username);
    final addrNormalized = SupabaseAccountAuthenticator.accountAddress('  ${username.toUpperCase()}  ');
    expect(addr, addrNormalized, reason: '归一化（trim+lowercase）后必须派生到同一地址');
    expect(
      RegExp(r'^u[0-9a-f]{24}@monster-word\.internal$').hasMatch(addr),
      isTrue,
      reason: '地址必须是 u<24位hex>@内部域名，实际：$addr',
    );

    // 2) 注册（首次使用）
    final created = await auth.createAccount(username: username, password: password);
    expect(created.ok, isTrue, reason: '注册应成功，实际 status=${created.status} message=${created.message}');
    expect(store.writes, 1, reason: '成功后必须写入会话');
    final userId = store.saved?.userId;
    expect(userId, isNotNull);
    // 打印出来供人工清理生产库里的这个测试账号
    // ignore: avoid_print
    print('[E2E] 已创建测试账号 userId=$userId username=$username');

    // 3) 同一用户名再登录（证明服务端认这个派生地址）
    final login = await auth.signIn(username: username, password: password);
    expect(login.ok, isTrue, reason: '登录应成功，实际 status=${login.status}');

    // 4) 归一化登录：大写 + 首尾空格 → 同一账号
    final loginNormalized = await auth.signIn(username: '  ${username.toUpperCase()}  ', password: password);
    expect(loginNormalized.ok, isTrue, reason: '归一化后应能登录同一账号');

    // 5) 错误密码 → invalidCredentials
    final badPassword = await auth.signIn(username: username, password: 'definitely-wrong');
    expect(badPassword.status, AuthStatus.invalidCredentials);

    // 6) 重复注册 → 也收敛为 invalidCredentials（不暴露「已存在」，防用户名枚举）
    final duplicate = await auth.createAccount(username: username, password: password);
    expect(duplicate.status, AuthStatus.invalidCredentials);
  }, skip: skipReason != null);
}
