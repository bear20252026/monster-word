// MilestoneGuard：金币里程碑跨档判定（蓝图 W3「临界值爆发 + 里程碑守卫」）。
//
// 跨档事件的「只庆祝一次」由调用方经 [lastCelebratedKey] 持久化；
// 多档连跨（如 480→1200 同时跨 500 与 1000）取最大档，只庆祝一次。
import 'package:shared_preferences/shared_preferences.dart';

class MilestoneGuard {
  MilestoneGuard._();

  /// 里程碑档位（升序）。
  static const List<int> thresholds = [100, 500, 1000, 5000];

  /// SP 键：最近一次已庆祝（或已基线化）的档位。
  /// 唯一事实来源——签到页与学习页共用，勿在调用方复制字面量。
  static const String lastCelebratedKey = 'monster_last_milestone';

  /// 连胜里程碑档位（升序）：只正向，不设惩罚。
  static const List<int> streakThresholds = [7, 14, 30, 50];

  /// SP 键：最近一次已庆祝（或已基线化）的连胜档位。
  static const String lastStreakMilestoneKey = 'monster_last_streak_milestone';

  /// 读取庆祝基线；无记录（老用户首次进入本机制）时先把当前余额登记为
  /// 基线并返回 null——只庆祝此后的真实跨档，不为存量 300 币补发「第 100 枚」。
  static Future<int?> readBaseline(SharedPreferences prefs, int currentBalance) =>
      readBaselineFor(prefs, lastCelebratedKey, currentBalance);

  /// 读取某档位组的庆祝基线；无记录时把 [currentValue] 登记为基线并返回 null。
  /// 存量基线化：不做「补庆祝」，只庆祝此后的真实跨档。
  static Future<int?> readBaselineFor(SharedPreferences prefs, String key, int currentValue) async {
    final recorded = prefs.getInt(key);
    if (recorded == null) {
      await prefs.setInt(key, currentValue);
      return null;
    }
    return recorded;
  }

  /// 余额从 [oldBalance] 变到 [newBalance] 时跨越的最大里程碑档位；
  /// 未跨档返回 null。负向变动（消费）不庆祝。
  static int? crossedMilestone(int oldBalance, int newBalance) => crossedThreshold(oldBalance, newBalance, thresholds);

  /// 从 [oldValue] 变到 [newValue] 时跨越 [levels] 的最大档位；只认正向。
  static int? crossedThreshold(int oldValue, int newValue, List<int> levels) {
    if (newValue <= oldValue) return null;
    int? crossed;
    for (final t in levels) {
      if (oldValue < t && newValue >= t) {
        crossed = t;
      }
    }
    return crossed;
  }
}
