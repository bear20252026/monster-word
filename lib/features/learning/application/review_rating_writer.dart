import 'package:word_app/core/engine/fsrs6_engine.dart' show FsrsRating;

/// 正式复习评分的持久化动作。
typedef ReviewRatingPersistence = Future<void> Function({required String word, required FsrsRating rating});

/// 正式复习评分写入端口。
///
/// 页面同时提交实际作答单词和 FSRS 评分；实际卡片更新、统计和持久化由
/// 应用根注入的 [ReviewRatingPersistence] 负责。这样迁移评分事实来源时无需
/// 再次让页面直接依赖遗留学习状态，也不会在本地会话推进后错写下一词。
class ReviewRatingWriter {
  const ReviewRatingWriter({required this._writeRating});

  final ReviewRatingPersistence _writeRating;

  Future<void> rate({required String word, required FsrsRating rating}) => _writeRating(word: word, rating: rating);
}
