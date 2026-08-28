import '../domain/checkin_status.dart';

/// 签到状态读取端口。
///
/// 只读，不产生任何副作用。
/// 由 data 层适配器实现，由 presentation 层消费。
abstract class CheckinStatusReader {
  /// 获取当前签到状态快照。
  Future<CheckinStatus> getStatus();

  /// 获取所有已签到日期集合（YYYY-MM-DD）。
  Future<Set<String>> getCheckinDates();

  /// 获取当前连续签到天数。
  Future<int> getStreakDays();

  /// 今天是否已签到。
  Future<bool> hasCheckedInToday();
}
