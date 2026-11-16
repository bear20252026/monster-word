// 签到日历窄端口（结构修复步骤4，2026-11-16）。
//
// 从上帝端口 ScareCoinStore 拆出的「签到日历」能力组。checkin 域的壳适配器
// 改依赖本窄端口，签到语义不再寄生于整个金币账本契约。
// 注意：日历与账本共享同一实现实例（checkIn 是同事务域 + 共享串行闸/水位），
// 拆的是「消费方看到的契约」，不是物理实例。
abstract interface class CheckInCalendar {
  int get checkInReward;

  Future<Set<String>> checkinDates();

  Future<int> streak();

  Future<String> lastCheckInDate();

  bool isSameDay(String isoDate, DateTime time);

  /// 签到：当日已签返回 null（幂等），新签返回签到后余额。
  Future<int?> checkIn();

  /// 手动补签「昨天」：消耗 1 张保护卡，把昨天写进签到日历（只补一天）。
  /// 返回补签后连胜天数；昨天已签/无卡/写失败返回 null（失败不扣卡）。
  Future<int?> makeupYesterday();
}
