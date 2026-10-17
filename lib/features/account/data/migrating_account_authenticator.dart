// Monster Word App
//
// 存量用户无感迁移（data 层装饰器）。
//
// ## 要解决的问题
//
// 本机账号体系自 v2.7.24+65 起就已发布，`v2.12.2+128` 里仍在——**存量用户是真实的**，
// 不是理论情况。这些账号只存在本机，服务端没有。
//
// 而 GoTrue 的密码授予**故意不区分**「用户不存在」与「密码错」（都返回
// 400 `invalid_credentials`，防用户名枚举）。于是客户端收到拒绝时无法判断：
// 是密码打错了，还是这个账号还没迁到服务端？
//
// ## 判定依据
//
// 不再靠猜，而是用**本机已有的证据**：如果本机安全存储里存着这个用户名的凭据、
// 且用户输入的密码能通过本机校验，那用户输入的密码**就是对的**——那么服务端
// 仍然拒绝，只可能是服务端没有这个账号 ⇒ 可以安全地建号。
//
// 反过来，本机凭据校验不通过（或本机压根没这个用户名）⇒ 不迁移，如实回报
// 「账号或密码不正确」。**不做「先 signup 试探」**：那会在用户每次打错密码时
// 都发一次注册请求，既浪费又会让限流把正常用户拦在门外。
//
// ## 安全性
//
// 建号路径不会覆盖已有账号的密码（GoTrue 对已确认账号直接返回
// `user_already_exists`，在写入密码之前短路）。所以即使判定失误，最坏结果是
// 「多一次无副作用的失败请求」，不会把别人的账号密码改掉。
//
// ## 覆盖不到的情况
//
// 换了新设备、且服务端还没有该账号的存量用户，无法迁移（本机没有可用的凭据证据）。
// 这类用户需管理员在后台预置账号——见 `docs/auth_server_contract.md` §6。
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/account/application/account_authenticator.dart';
import 'package:word_app/features/account/application/password_auth_store.dart';

class MigratingAccountAuthenticator implements AccountAuthenticator {
  const MigratingAccountAuthenticator({required this.remote, required this.localStore});

  /// 服务端实现（`SupabaseAccountAuthenticator`）。
  final AccountAuthenticator remote;

  /// 阶段一的本机凭据存储。**只读**用于迁移判定，成功后删除。
  final PasswordAuthStore localStore;

  @override
  AccountScope get scope => remote.scope;

  @override
  Future<AuthOutcome> signIn({required String username, required String password}) async {
    final outcome = await remote.signIn(username: username, password: password);
    if (outcome.status != AuthStatus.invalidCredentials) return outcome;

    // 服务端拒绝。先确认「用户输入的密码本身是对的」——这是迁移判定的全部依据。
    if (!await _isKnownLocalPassword(username, password)) return outcome;

    final created = await remote.createAccount(username: username, password: password);
    if (created.ok) {
      await _forgetLocalCredential(username);
      // 审计 R3-A09：这次「登录成功」其实是一次**迁移** —— 用户输入的仍是自己一直在用的
      // 那组用户名密码，登录成功后并不知道自己顺带拥有了一个云账号（此后换设备可直接登录）。
      // 置位 migrated 让 UI 能给出一次性告知；登录成功的语义本身不变。
      return const AuthOutcome.success(migrated: true);
    }
    return created;
  }

  @override
  Future<AuthOutcome> createAccount({required String username, required String password}) async {
    final outcome = await remote.createAccount(username: username, password: password);
    if (outcome.ok) await _forgetLocalCredential(username);
    return outcome;
  }

  /// 本机是否存有该用户名、且 [password] 能通过本机校验。
  Future<bool> _isKnownLocalPassword(String username, String password) async {
    try {
      if (!await localStore.hasPassword(username)) return false;
      return await localStore.verify(username, password);
    } catch (e, s) {
      // 本机安全存储不可用（系统还原 / Keystore 故障）时**无法证明**密码正确。
      // 保守放弃迁移：此时服务端确实拒绝了这组凭据，如实回报「账号或密码不正确」
      // 比「凭一段读不到的证据擅自建号」安全。存储故障本身已上报。
      reportSwallowedError('迁移判定时本机凭据读取失败（放弃迁移）', e, s);
      return false;
    }
  }

  /// 迁移成功后清掉本机哈希：账号已在服务端，本机不该再留密码（见端口注释）。
  Future<void> _forgetLocalCredential(String username) async {
    try {
      await localStore.removePassword(username);
    } catch (e, s) {
      // 登录/建号已经成功，此时报错会把用户引向无效的「重试」。
      // 残留的本机哈希不会让服务端校验失效（服务端才是权威），
      // 只是隐私上不够干净——上报待下次迁移时再清。
      reportSwallowedError('迁移后本机凭据清除失败（残留无害）', e, s);
    }
  }
}
