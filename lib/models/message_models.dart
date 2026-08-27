// 由 Claude 团队生成 | Monster Word App

// 数据模型层：翻译自 bean/（v3.2 源码 1:1）
// 文件：MessageData + MessageSetData

/// 消息数据（翻译自 MessageData.java）
class MessageData {
  int newsId;
  String label;
  String title;
  String content;
  String icon;
  String image;
  String clickTip;
  int actionType;
  String actionData;
  int dataType;
  int read;
  int time;

  MessageData({
    this.newsId = 0,
    this.label = '',
    this.title = '',
    this.content = '',
    this.icon = '',
    this.image = '',
    this.clickTip = '',
    this.actionType = 0,
    this.actionData = '',
    this.dataType = 0,
    this.read = 0,
    this.time = 0,
  });

  bool get hasRead => read == 1;
  void markHasRead() => read = 1;

  factory MessageData.fromJson(Map<String, dynamic> json) => MessageData(
    newsId: (json['news_id'] as num?)?.toInt() ?? 0,
    label: json['label'] ?? '',
    title: json['title'] ?? '',
    content: json['content'] ?? '',
    icon: json['icon'] ?? '',
    image: json['image'] ?? '',
    clickTip: json['click_tip'] ?? '',
    actionType: (json['action_type'] as num?)?.toInt() ?? 0,
    actionData: json['action_data'] ?? '',
    dataType: (json['data_type'] as num?)?.toInt() ?? 0,
    read: (json['read'] as num?)?.toInt() ?? 0,
    time: (json['time'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'news_id': newsId,
    'label': label,
    'title': title,
    'content': content,
    'icon': icon,
    'image': image,
    'click_tip': clickTip,
    'action_type': actionType,
    'action_data': actionData,
    'data_type': dataType,
    'read': read,
    'time': time,
  };
}

/// 消息集合数据（翻译自 MessageSetData.java）
class MessageSetData {
  List<MessageData> list;

  MessageSetData([List<MessageData>? list]) : list = list ?? [];

  List<MessageData> get messageList => list;
  int get count => list.length;

  MessageData? getItem(int i) {
    if (i >= 0 && i < list.length) return list[i];
    return null;
  }

  /// 追加更多数据
  void addMoreData(MessageSetData other) {
    list.addAll(other.list);
  }

  /// 刷新插入新数据（插入到头部）
  void addRefreshNewData(MessageSetData other) {
    for (int i = other.list.length - 1; i > 0; i--) {
      list.insert(0, other.list[i]);
    }
  }

  factory MessageSetData.fromJson(Map<String, dynamic> json) => MessageSetData(
    (json['list'] as List?)?.map((e) => MessageData.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  );
}
