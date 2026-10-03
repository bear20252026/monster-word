// MonsterMood：怪兽五档心情机 v0（蓝图 W4「它活着」）。
//
// 数据红线（蓝图「怪兽是你的镜子」）：只映射事实（到期数/连击/离开天数），
// 不映射评价；数据不可得一律 calm，不猜。FSRS 的遗忘预测不许说破——
// overdue 只取「已到期」的天数事实，不预测。
//
// 取数口径（全部只读）：
// - overdueDays：LearningStatisticsState.dueCount > 0 的持续天数——
//   v0 简化：dueCount 与昨日快照比较不可得，改用「dueCount 阈值」近似
//   （>0 且 <40 视为 1-2 天级；≥40 视为 3+ 天级——40 约等于两天的正常量）。
//   精确化留待持久化「首见 due 日期」（后续 W5）。
// - todayCombo：LearningSessionState.combo（会话内连击）。
// - returnedAfterGap：ScareCoinStore.checkinDates 最后日期距今天数。
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';

/// 怪兽心情档（映射 painter 待机参数，见 profile_screen 接线）。
enum MonsterMood {
  /// 今日连对 ≥5：蹦跳频率提高。
  excited,

  /// 正常节奏：现状（默认）。
  calm,

  /// 有到期词 1-2 天级：呼吸放慢、蹦跳减半。
  sleepy,

  /// 到期词积压 3 天级+：停跳、轻微左右踱步。
  worried,
}

/// 心情解析（纯函数核心 + 异步取数适配）。
class MonsterMoodResolver {
  MonsterMoodResolver({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// 纯函数核心（表驱动测试锚点）。
  static MonsterMood resolve({required int dueCount, required int todayCombo, required bool returnedAfterGap}) {
    // 回归惊喜优先：刚回家先开心（负向数据不出场）。
    if (returnedAfterGap) return MonsterMood.excited;
    // 积压分级（近似口径见文件头）。
    if (dueCount >= 40) return MonsterMood.worried;
    if (dueCount > 0) return MonsterMood.sleepy;
    if (todayCombo >= 5) return MonsterMood.excited;
    return MonsterMood.calm;
  }

  /// 异步取数适配：任何一路读取失败按「不可得」降级（不猜）。
  Future<MonsterMood> resolveFrom({
    required int Function()? dueCountReader,
    required int Function()? todayComboReader,
    required Future<Set<String>> Function()? checkinDatesReader,
  }) async {
    final due = _safeInt(dueCountReader);
    final combo = _safeInt(todayComboReader);
    var gap = false;
    if (checkinDatesReader != null) {
      try {
        final dates = await checkinDatesReader();
        gap = _hasGap(dates, _now());
      } catch (_) {
        // 签到数据不可得 → gap 维持 false（不影响其它通道）。
      }
    }
    if (due == null && combo == null && !gap) return MonsterMood.calm;
    return resolve(dueCount: due ?? 0, todayCombo: combo ?? 0, returnedAfterGap: gap);
  }

  int? _safeInt(int Function()? reader) {
    if (reader == null) return null;
    try {
      return reader();
    } catch (_) {
      return null;
    }
  }

  /// 签到日期集合中最近一次距今天 ≥3 天（且有过签到）→ 回归。
  bool _hasGap(Set<String> dates, DateTime today) {
    if (dates.isEmpty) return false;
    DateTime? last;
    for (final raw in dates) {
      final d = DateTime.tryParse(raw);
      if (d == null) continue;
      if (last == null || d.isAfter(last)) last = d;
    }
    if (last == null) return false;
    final today0 = DateTime(today.year, today.month, today.day);
    final last0 = DateTime(last.year, last.month, last.day);
    return today0.difference(last0).inDays >= 3;
  }
}

/// ProfileScreen 接线用的取数聚合（ScareCoinStore 可空，测试最小装配）。
Future<MonsterMood> resolveMonsterMood({
  required int Function()? dueCountReader,
  required int Function()? todayComboReader,
  ScareCoinStore? store,
  DateTime Function()? now,
}) {
  final resolver = MonsterMoodResolver(now: now);
  return resolver.resolveFrom(
    dueCountReader: dueCountReader,
    todayComboReader: todayComboReader,
    checkinDatesReader: store?.checkinDates,
  );
}
