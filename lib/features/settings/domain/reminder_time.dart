/// 学习提醒时间解析与下次触发时刻的纯函数（无平台依赖，可单测）。
library;

const String defaultReminderTime = '20:00';

/// 解析 'HH:mm'（24 小时制）为 (hour, minute)；非法输入回退默认 20:00。
(int, int) parseReminderTime(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) return _default;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return _default;
  return (hour, minute);
}

const (int, int) _default = (20, 0);

/// 计算下一次提醒触发时刻：今天已过则排明天。
DateTime nextReminderOccurrence(DateTime now, int hour, int minute) {
  var next = DateTime(now.year, now.month, now.day, hour, minute);
  if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
  return next;
}
