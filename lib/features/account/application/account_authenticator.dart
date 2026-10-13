// Monster Word App
//
// 账号认证端口（application 层）：登录的**唯一入口**。
//
// 为什么要有这一层：把「密码在哪里校验」从 UI 抽出来。
//   - 当前实现：本机校验（`LocalAccountAuthenticator` → `SecurePasswordAuthStore`）
//   - R2-01 阶段二：服务端校验（自建 Supabase）。届时**只换装配点**，
//     UI 与调用方一行不改。
//
// 契约要点（服务端实现必须遵守，完整规范见 `docs/auth_server_contract.md`）：
//   1. **不提供「用户名是否存在」的独立查询**——那等于送出一个用户名枚举接口。
//      账号不存在时由 [signIn] 返回 [AuthStatus.needsAccountCreation]。
//   2. [signIn] / [createAccount] 内**不做任何 UI 交互**；需要用户确认创建账号时
//      返回状态，由调用方弹窗，再调 [createAccount]。
//   3. 失败必须**分类**返回，不能一律「登录失败」——UI 要区分「密码错」（让用户
//      改）与「网络不通」（让用户重试），否则会把用户引向错误动作。
//   4. 会话凭据由实现方负责持久化（本机模式无 token；服务端模式写 token）。

/// 账号数据存放位置。
///
/// 暴露给 UI 不是为了实现细节泄漏，而是**用户有权知道密码去了哪里**——
/// 「首次使用将创建账号」的弹窗措辞必须据此区分本机 / 服务端。
enum AccountScope {
  /// 账号与密码哈希只存在本机安全存储，不上传。
  local,

  /// 账号在服务端，密码经 TLS 提交给服务端校验。
  remote,
}

/// 登录结果分类。
///
/// 刻意不用 `bool`：调用方需要按原因给出不同提示与不同后续动作。
enum AuthStatus {
  /// 认证成功，会话已建立。
  success,

  /// 账号不存在，需要用户确认后创建。
  needsAccountCreation,

  /// 账号或密码不正确。
  invalidCredentials,

  /// 本机安全存储不可用（平台异常 / 系统还原）。**重试无用**，需引导用户。
  localCredentialUnavailable,

  /// 网络不可达。
  networkFailure,

  /// 服务端返回错误（5xx / 响应不符合契约）。
  serverFailure,

  /// 尝试过于频繁，被限流。
  tooManyAttempts,
}

/// 认证结果。不可变值对象。
class AuthOutcome {
  const AuthOutcome(this.status, {this.message});

  const AuthOutcome.success() : this(AuthStatus.success);

  const AuthOutcome.needsAccountCreation() : this(AuthStatus.needsAccountCreation);

  const AuthOutcome.invalidCredentials() : this(AuthStatus.invalidCredentials);

  const AuthOutcome.localCredentialUnavailable() : this(AuthStatus.localCredentialUnavailable);

  const AuthOutcome.networkFailure() : this(AuthStatus.networkFailure);

  const AuthOutcome.serverFailure() : this(AuthStatus.serverFailure);

  const AuthOutcome.tooManyAttempts() : this(AuthStatus.tooManyAttempts);

  final AuthStatus status;

  /// 可直接展示给用户的文案；为 null 时由调用方按 [status] 取默认文案。
  /// 服务端实现可用它回传服务端给出的具体原因（如「账号已被锁定至 14:30」）。
  final String? message;

  bool get ok => status == AuthStatus.success;
}

/// 账号认证端口。
abstract interface class AccountAuthenticator {
  /// 账号数据存放位置（UI 据此决定文案与合规提示）。
  AccountScope get scope;

  /// 用用户名 + 密码登录。
  ///
  /// 账号不存在时返回 [AuthStatus.needsAccountCreation]，**不抛异常**；
  /// 调用方确认后再调 [createAccount]。
  Future<AuthOutcome> signIn({required String username, required String password});

  /// 创建账号（首次使用）。已存在时返回 [AuthStatus.invalidCredentials]
  /// （不暴露「该用户名已存在」这一事实，避免用户名枚举）。
  Future<AuthOutcome> createAccount({required String username, required String password});
}
