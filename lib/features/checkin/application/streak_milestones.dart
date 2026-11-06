// 连胜里程碑（7 / 14 / 30 / 50）：跨档判定与「距下一档」口径。
//
// 复刻金币里程碑的守卫范式：跨档取最大、SP 落「已庆祝档位」、存量基线化，
// 只正向——断签不清零历史档位、不做任何扣分或催活提示。
import 'package:word_app/core/utils/milestone_guard.dart';

/// 连胜档位（升序；唯一事实来源在 [MilestoneGuard.streakThresholds]）。
const List<int> streakMilestoneDays = MilestoneGuard.streakThresholds;

/// SP 键：最近一次已庆祝（或已基线化）的连胜档位。
const String streakMilestonePrefKey = MilestoneGuard.lastStreakMilestoneKey;

/// 从 [oldStreak] 变到 [newStreak] 时跨越的最大档位；未跨档/负向返回 null。
int? crossedStreakMilestone(int oldStreak, int newStreak) =>
    MilestoneGuard.crossedThreshold(oldStreak, newStreak, streakMilestoneDays);

/// 下一档（严格大于 [streak]）；已封顶返回 null。
int? nextStreakMilestone(int streak) {
  for (final threshold in streakMilestoneDays) {
    if (streak < threshold) return threshold;
  }
  return null;
}

/// 距下一档还差几天；已封顶返回 null。
int? daysToNextStreakMilestone(int streak) {
  final next = nextStreakMilestone(streak);
  if (next == null) return null;
  final safe = streak < 0 ? 0 : streak;
  return next - safe;
}

/// 庆祝文案（自建，简短正向）。
String streakMilestonePhrase(int milestoneDays) => '连续签到 $milestoneDays 天！';

/// 结算页连胜一行（把连胜当作本局结果的一部分）。
///
/// [streakDays] 为当前连胜；[checkedToday] 为今天是否已签到。
/// 无连胜返回 null（不显示）；未签到时只陈述现状，不催、不吓唬。
String? completionStreakLine({required int streakDays, required bool checkedToday}) {
  if (streakDays <= 0) return null;
  if (!checkedToday) return '连胜 $streakDays 天 · 今天签到可续上';
  final toNext = daysToNextStreakMilestone(streakDays);
  if (toNext == null) return '连胜 $streakDays 天 · 保持住';
  if (toNext == 1) return '连胜 $streakDays 天 · 明天就是第 ${streakDays + 1} 天';
  return '连胜 $streakDays 天 · 再坚持 $toNext 天解锁下一档';
}
