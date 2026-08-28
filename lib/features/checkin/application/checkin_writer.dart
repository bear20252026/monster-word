/// 签到写入端口。
///
/// 产生副作用（执行签到并更新状态）。
/// 由 data 层适配器实现，由 presentation 层消费。
abstract class CheckinWriter {
  /// 执行今日签到。
  ///
  /// 返回 true 表示签到成功，false 表示今天已签到。
  Future<bool> checkIn();

  /// 获取当前连续签到天数。
  Future<int> getStreak();
}
