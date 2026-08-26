// 由 Claude 团队生成 | Monster Word App
// CheckInService — 签到业务逻辑

/// 签到服务接口
abstract class CheckInService {
  /// 执行签到
  Future<bool> checkIn();

  /// 今天是否已签到
  Future<bool> hasCheckedInToday();

  /// 获取连续签到天数
  Future<int> getStreakDays();

  /// 获取签到记录
  Future<List<DateTime>> getCheckInRecords();

  /// 获取所有签到日期（字符串格式 YYYY-MM-DD）
  Future<Set<String>> getCheckinDates();

  /// 获取连续签到天数（与 getStreakDays 相同，别名）
  Future<int> getStreak();

  /// 获取签到奖励数量
  int get checkInReward;
}
