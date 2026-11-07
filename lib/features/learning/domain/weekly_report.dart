/// L1「本周成长」周报：聚合近 7 天（含今天）本地学习数据。
///
/// 纯 Dart + 注入「今天」，便于单元测试；数据来自 `fsrs_daily_stats`
/// （learn/review 词次 + correct 答对词次），不依赖遥测开关。
class WeeklyReport {
  const WeeklyReport({required this.studyDays, required this.words, required this.correctWords});

  /// 本周有学习活动的天数（0–7）。
  final int studyDays;

  /// 本周学习词次（学新词 + 复习，均按词次计）。
  final int words;

  /// 本周答对的词次（用于正确率）。
  final int correctWords;

  /// 本周是否还没开始学习（用于「本周还没开始」空态，而不是画 0 值图）。
  bool get isEmpty => words == 0;

  /// 正确率百分比（0–100）；没有作答时返回 null（UI 显示「—」）。
  int? get accuracyPercent => words == 0 ? null : (correctWords * 100 / words).round();

  /// 正确率的展示文案。
  String get accuracyText => accuracyPercent == null ? '—' : '$accuracyPercent%';

  static WeeklyReport compute({
    required Map<String, int> Function(String day) statsFor,
    required int Function(String day) correctFor,
    required DateTime today,
  }) {
    var studyDays = 0;
    var words = 0;
    var correctWords = 0;
    for (var i = 0; i < 7; i++) {
      final day = _dayKey(DateTime(today.year, today.month, today.day - i));
      final stats = statsFor(day);
      final dayWords = (stats['learn'] ?? 0) + (stats['review'] ?? 0);
      words += dayWords;
      if (dayWords > 0) studyDays++;
      correctWords += correctFor(day);
    }
    return WeeklyReport(studyDays: studyDays, words: words, correctWords: correctWords);
  }

  static String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
