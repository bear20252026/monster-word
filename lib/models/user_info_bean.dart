/// 用户信息 Bean
///
/// 从 data/app_preferences.dart 迁移到 models/ 层，
/// 使 Service 层可以不依赖 data/ 层。
class UserInfoBean {
  int userId;
  String nickname;
  String avatar;
  String phone;
  String token;
  String secret;
  String displayId; // 用户自定义 ID（可自由设定）
  String wechatName; // 微信名
  String signature; // 个人签名

  UserInfoBean({
    this.userId = 0,
    this.nickname = '',
    this.avatar = '',
    this.phone = '',
    this.token = '',
    this.secret = '',
    this.displayId = '',
    this.wechatName = '',
    this.signature = '',
  });

  factory UserInfoBean.fromJson(Map<String, dynamic> json) => UserInfoBean(
    userId: (json['userId'] as num?)?.toInt() ?? 0,
    nickname: json['nickname'] ?? '',
    avatar: json['avatar'] ?? '',
    phone: json['phone'] ?? '',
    token: json['token'] ?? '',
    secret: json['secret'] ?? '',
    displayId: json['displayId'] ?? '',
    wechatName: json['wechatName'] ?? '',
    signature: json['signature'] ?? '',
  );

  // MW-61：displayId/wechatName/signature 三键原缺引号（左侧是变量表达式，
  // 实际 JSON key 为字段值本身），fromJson 查 'displayId' 等永远 miss——
  // 三个资料字段当场丢失（保存即丢，非重启才丢）。
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'nickname': nickname,
    'avatar': avatar,
    'phone': phone,
    'token': token,
    'secret': secret,
    'displayId': displayId,
    'wechatName': wechatName,
    'signature': signature,
  };
}
