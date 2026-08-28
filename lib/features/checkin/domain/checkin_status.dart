/// 签到状态值对象。
///
/// 纯领域实体，聚合签到面板所需的所有只读状态。
class CheckinStatus {
  const CheckinStatus({
    required this.todayChecked,
    required this.streakDays,
    required this.totalDays,
    required this.reward,
  });

  /// 今天是否已签到。
  final bool todayChecked;

  /// 当前连续签到天数。
  final int streakDays;

  /// 历史累计签到天数。
  final int totalDays;

  /// 单次签到奖励尖叫币数。
  final int reward;

  /// 初始空状态。
  const CheckinStatus.empty()
      : todayChecked = false,
        streakDays = 0,
        totalDays = 0,
        reward = 0;
}
