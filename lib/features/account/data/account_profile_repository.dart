import 'package:word_app/features/account/data/user_service.dart';
import 'package:word_app/features/account/application/account_profile_store.dart';
import 'package:word_app/features/account/domain/account_profile.dart';

/// 基于既有 UserService 的账号资料持久化适配器。
///
/// 实现 [AccountProfileStore] 端口，对旧 `monster_word_user_info` JSON 结构保持兼容；
/// 写入时先读取完整 Bean，再只更新允许账号资料页修改的字段，从而保留认证和其他兼容字段。
class AccountProfileRepository implements AccountProfileStore {
  AccountProfileRepository({required this._userService});

  final UserService _userService;

  @override
  Future<AccountProfile> load() async => AccountProfile.fromBean(await _userService.getUserInfoBean());

  @override
  Future<void> save(AccountProfile profile) async {
    final bean = await _userService.getUserInfoBean();
    bean.nickname = profile.nickname;
    bean.avatar = profile.avatar;
    bean.phone = profile.phone;
    bean.displayId = profile.displayId;
    bean.wechatName = profile.wechatName;
    bean.signature = profile.signature;
    await _userService.setUserInfoBean(bean);
  }
}
