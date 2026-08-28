/// 签到记录值对象。
///
/// 纯领域实体，不依赖任何框架或基础设施。
/// 代表单次签到行为的结果。
class CheckinRecord {
  const CheckinRecord({
    required this.date,
    required this.reward,
  });

  /// 签到日期（本地日期，不含时区偏移）。
  final DateTime date;

  /// 本次签到获得的尖叫币奖励。
  final int reward;

  /// 日期的 ISO 本地字符串，格式 YYYY-MM-DD。
  String get isoDate =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckinRecord &&
          runtimeType == other.runtimeType &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day;

  @override
  int get hashCode => Object.hash(date.year, date.month, date.day);
}
