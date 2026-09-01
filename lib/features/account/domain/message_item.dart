// 由 Claude 团队生成 | Monster Word App

// 消息中心领域实体：本地消息条目。
class MessageItem {
  final String id;
  final String title;
  final String content;
  final String time;
  final bool isRead;

  /// 去重键：同一 key 只保留一条（如打卡提醒按日期、里程碑按天数）。
  /// 为空表示不参与去重（如用户自定义消息）。
  final String? dedupeKey;

  const MessageItem({
    required this.id,
    required this.title,
    required this.content,
    required this.time,
    this.isRead = false,
    this.dedupeKey,
  });

  MessageItem markRead() =>
      MessageItem(id: id, title: title, content: content, time: time, isRead: true, dedupeKey: dedupeKey);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'content': content,
    'time': time,
    'isRead': isRead,
    if (dedupeKey != null) 'dedupeKey': dedupeKey,
  };

  factory MessageItem.fromJson(Map<String, dynamic> json) => MessageItem(
    id: json['id'] as String,
    title: json['title'] as String,
    content: json['content'] as String,
    time: json['time'] as String,
    isRead: (json['isRead'] as bool?) ?? false,
    dedupeKey: json['dedupeKey'] as String?,
  );
}
