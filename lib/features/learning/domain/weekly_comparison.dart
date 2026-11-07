/// 「上周的我」对比：本周（今天往前 6 天，含今天）vs 上周（再往前 7 天）。
///
/// 纯 Dart + 注入「今天」，便于单元测试；数据来自本地每日学习统计
/// （`fsrs_daily_stats` 的 learn/review 词次），不依赖遥测开关。
class WeeklyComparison {
  const WeeklyComparison({
    required this.thisWeekWords,
    required this.lastWeekWords,
    required this.thisWeekStudyDays,
    required this.lastWeekStudyDays,
  });

  /// 本周学习词次（学新词 + 复习，均按词次计）。
  final int thisWeekWords;

  /// 上周学习词次。
  final int lastWeekWords;

  /// 本周有学习活动的天数（0–7）。
  final int thisWeekStudyDays;

  /// 上周有学习活动的天数（0–7）。
  final int lastWeekStudyDays;

  /// 上周是否有数据可对比；否则应显示「再练一周就能对比」。
  bool get hasLastWeekData => lastWeekStudyDays > 0;

  /// 本周相对上周的词次增量（负数表示少学了）。
  int get wordsDelta => thisWeekWords - lastWeekWords;

  /// 本周相对上周的学习天数增量。
  int get studyDaysDelta => thisWeekStudyDays - lastWeekStudyDays;

  /// 按本地日期聚合两周数据。
  ///
  /// [statsFor] 接收 `YYYY-MM-DD`，返回该天的 `learn` / `review` 词次；
  /// 没有记录时返回空 Map。
  static WeeklyComparison compute({required Map<String, int> Function(String day) statsFor, required DateTime today}) {
    var thisWeekWords = 0;
    var lastWeekWords = 0;
    var thisWeekStudyDays = 0;
    var lastWeekStudyDays = 0;
    for (var i = 0; i < 14; i++) {
      // 用日历日减法（DateTime(y, m, d - i)），避免夏令时导致 24h 减法跳日。
      final day = _dayKey(DateTime(today.year, today.month, today.day - i));
      final stats = statsFor(day);
      final words = (stats['learn'] ?? 0) + (stats['review'] ?? 0);
      if (i < 7) {
        thisWeekWords += words;
        if (words > 0) thisWeekStudyDays++;
      } else {
        lastWeekWords += words;
        if (words > 0) lastWeekStudyDays++;
      }
    }
    return WeeklyComparison(
      thisWeekWords: thisWeekWords,
      lastWeekWords: lastWeekWords,
      thisWeekStudyDays: thisWeekStudyDays,
      lastWeekStudyDays: lastWeekStudyDays,
    );
  }

  static String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
