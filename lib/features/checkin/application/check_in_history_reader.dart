/// 签到历史页面所需的只读应用端口。
///
/// 该端口不复制签到记录，也不改变签到服务的奖励和持久化语义。
abstract interface class CheckInHistoryReader {
  /// 获取所有已签到日期，格式为 YYYY-MM-DD。
  Future<Set<String>> getCheckedDates();

  /// 获取当前连续签到天数。
  Future<int> getStreak();

  /// 获取单次签到展示奖励。
  int get checkInReward;
}
