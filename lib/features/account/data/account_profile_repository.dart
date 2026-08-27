import '../../../models/user_info_bean.dart';
import '../../../services/user_service.dart';

/// 账号资料的展示与编辑快照。
///
/// 认证凭据不属于个人资料展示状态，因此不会从 [UserInfoBean] 暴露到页面或 Provider。
class AccountProfile {
  const AccountProfile({
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.phone,
    required this.displayId,
    required this.wechatName,
    required this.signature,
  });

  const AccountProfile.empty()
    : userId = 0,
      nickname = '',
      avatar = '',
      phone = '',
      displayId = '',
      wechatName = '',
      signature = '';

  final int userId;
  final String nickname;
  final String avatar;
  final String phone;
  final String displayId;
  final String wechatName;
  final String signature;

  AccountProfile copyWith({
    String? nickname,
    String? avatar,
    String? phone,
    String? displayId,
    String? wechatName,
    String? signature,
  }) {
    return AccountProfile(
      userId: userId,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      phone: phone ?? this.phone,
      displayId: displayId ?? this.displayId,
      wechatName: wechatName ?? this.wechatName,
      signature: signature ?? this.signature,
    );
  }

  factory AccountProfile.fromBean(UserInfoBean bean) {
    return AccountProfile(
      userId: bean.userId,
      nickname: bean.nickname,
      avatar: bean.avatar,
      phone: bean.phone,
      displayId: bean.displayId,
      wechatName: bean.wechatName,
      signature: bean.signature,
    );
  }
}

/// 账号资料的读写端口，供状态与测试替身使用。
abstract class AccountProfileStore {
  Future<AccountProfile> load();
  Future<void> save(AccountProfile profile);
}

/// 基于既有 [UserService] 的账号资料持久化适配器。
///
/// 对旧 `monster_word_user_info` JSON 结构保持兼容；写入时先读取完整 Bean，再只更新
/// 允许账号资料页修改的字段，从而保留认证和其他兼容字段。
class AccountProfileRepository implements AccountProfileStore {
  AccountProfileRepository({required UserService userService}) : _userService = userService;

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
