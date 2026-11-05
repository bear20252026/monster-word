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
