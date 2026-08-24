// 由 Claude 团队生成 | Monster Word App

// 数据模型层：翻译自 bean/（v3.2 源码 1:1）
// 文件：Privileges + Privilege

/// 权限信息（翻译自 Privileges.java）
class Privileges {
  Privilege? collins;
  Privilege? wordroot;

  Privileges({
    this.collins,
    this.wordroot,
  });

  /// 柯林斯是否授权
  bool get isCollinsGranted => collins?.isGranted ?? false;

  /// 柯林斯过期时间
  int get collinsExpireDate => collins?.expireDate ?? 0;

  /// 柯林斯用户类型
  int get collinsUserType => collins?.collinsUserType ?? 0;

  /// 词根是否授权
  bool get isWordRootGranted => wordroot?.isGranted ?? false;

  factory Privileges.fromJson(Map<String, dynamic> json) => Privileges(
        collins: json['collins'] != null
            ? Privilege.fromJson(json['collins'] as Map<String, dynamic>)
            : null,
        wordroot: json['wordroot'] != null
            ? Privilege.fromJson(json['wordroot'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'collins': collins?.toJson(),
        'wordroot': wordroot?.toJson(),
      };
}

/// 单项权限（翻译自 Privileges.Privilege）
class Privilege {
  int granted;
  int expireDate;
  int collinsUserType;
  int userType;

  Privilege({
    this.granted = 0,
    this.expireDate = 0,
    this.collinsUserType = 0,
    this.userType = 0,
  });

  bool get isGranted => granted == 1;

  factory Privilege.fromJson(Map<String, dynamic> json) => Privilege(
        granted: (json['granted'] as num?)?.toInt() ?? 0,
        expireDate: (json['expire_date'] as num?)?.toInt() ?? 0,
        collinsUserType:
            (json['collins_user_type'] as num?)?.toInt() ?? 0,
        userType: (json['user_type'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'granted': granted,
        'expire_date': expireDate,
        'collins_user_type': collinsUserType,
        'user_type': userType,
      };
}
