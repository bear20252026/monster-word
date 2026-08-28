/// 词书统计值对象。
///
/// 封装词书的总量与学习进度，纯数据，无外部依赖。
class BookStatistics {
  const BookStatistics({
    required this.totalWords,
    required this.learnedWords,
  });

  /// 词书总单词数
  final int totalWords;

  /// 已学习单词数
  final int learnedWords;

  /// 未学习单词数
  int get unlearnWords => (totalWords - learnedWords).clamp(0, totalWords);

  /// 学习进度百分比（0.0 ~ 1.0）
  double get progress =>
      totalWords == 0 ? 0.0 : (learnedWords / totalWords).clamp(0.0, 1.0);

  /// 学习进度百分比显示文本（如 "42%"）
  String get progressText => '${(progress * 100).round()}%';

  bool get isCompleted => totalWords > 0 && learnedWords >= totalWords;
}
