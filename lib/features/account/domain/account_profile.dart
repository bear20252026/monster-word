import '../../../models/user_info_bean.dart';

/// 账号资料值对象（纯领域层）。
///
/// 持有用户在"我的"与"账号信息"页展示的可编辑字段，不含 UI 逻辑。
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
    int? userId,
    String? nickname,
    String? avatar,
    String? phone,
    String? displayId,
    String? wechatName,
    String? signature,
  }) {
    return AccountProfile(
      userId: userId ?? this.userId,
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

  bool get isEmpty => nickname.isEmpty && wechatName.isEmpty && displayId.isEmpty;
}
