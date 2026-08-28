import '../domain/account_profile.dart';

/// 账号资料读写端口（应用层）。
///
/// 定义账号资料的加载与持久化契约，由 data 层适配器实现。
abstract class AccountProfileStore {
  /// 加载当前账号资料。
  Future<AccountProfile> load();

  /// 保存账号资料。
  Future<void> save(AccountProfile profile);
}
