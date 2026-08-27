// 由 Claude 团队生成 | Monster Word App

// 数据模型层：翻译自 bean/（v3.2 源码 1:1）
// 文件：CardAction + FloatButtonAction + MasterFilterData

/// 卡片动作（翻译自 CardAction.java）
class CardAction {
  int id;
  int enable;
  int hideclose;
  String image;
  List<CardButton> buttons;

  CardAction({this.id = 0, this.enable = 0, this.hideclose = 0, this.image = '', List<CardButton>? buttons})
    : buttons = buttons ?? [];

  int get cardId => id;
  bool get isHideClose => hideclose == 1;

  factory CardAction.fromJson(Map<String, dynamic> json) => CardAction(
    id: (json['id'] as num?)?.toInt() ?? 0,
    enable: (json['enable'] as num?)?.toInt() ?? 0,
    hideclose: (json['hideclose'] as num?)?.toInt() ?? 0,
    image: json['image'] ?? '',
    buttons: (json['buttons'] as List?)?.map((e) => CardButton.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  );
}

/// 卡片按钮（翻译自 CardAction.CardButton）
class CardButton {
  String name;
  String data;
  int type;

  CardButton({this.name = '', this.data = '', this.type = 0});

  factory CardButton.fromJson(Map<String, dynamic> json) =>
      CardButton(name: json['name'] ?? '', data: json['data'] ?? '', type: (json['type'] as num?)?.toInt() ?? 0);
}

/// 悬浮按钮动作（翻译自 FloatButtonAction.java）
class FloatButtonAction {
  int id;
  int enable;
  int hideclose;
  int reopen;
  int top;
  int right;
  int width;
  int height;
  String image;
  String url;

  FloatButtonAction({
    this.id = 0,
    this.enable = 0,
    this.hideclose = 0,
    this.reopen = 0,
    this.top = 0,
    this.right = 0,
    this.width = 0,
    this.height = 0,
    this.image = '',
    this.url = '',
  });

  bool get isEnabled => enable == 1;
  bool get isHideClose => hideclose == 1;
  bool get isReopen => reopen == 1;

  factory FloatButtonAction.fromJson(Map<String, dynamic> json) => FloatButtonAction(
    id: (json['id'] as num?)?.toInt() ?? 0,
    enable: (json['enable'] as num?)?.toInt() ?? 0,
    hideclose: (json['hideclose'] as num?)?.toInt() ?? 0,
    reopen: (json['reopen'] as num?)?.toInt() ?? 0,
    top: (json['top'] as num?)?.toInt() ?? 0,
    right: (json['right'] as num?)?.toInt() ?? 0,
    width: (json['width'] as num?)?.toInt() ?? 0,
    height: (json['height'] as num?)?.toInt() ?? 0,
    image: json['image'] ?? '',
    url: json['url'] ?? '',
  );
}

/// 掌握筛选数据（翻译自 MasterFilterData.java）
class MasterFilterData {
  static const int filterAll = 0;
  static const int filterSystemMark = 1;
  static const int filterUserMark = 2;

  final int type;
  int count;

  MasterFilterData(this.type, this.count);

  String get title {
    switch (type) {
      case 0:
        return '全部单词';
      case 1:
        return '系统标记';
      case 2:
        return '自主标记';
      default:
        return '';
    }
  }

  String get subtitle => count.toString();
}
