import '../../../engine/fsrs6_engine.dart' show FsrsRating;

/// 正式复习评分的持久化动作。
typedef ReviewRatingPersistence = Future<void> Function(FsrsRating rating);

/// 正式复习评分写入端口。
///
/// 页面仅提交 FSRS 评分；实际卡片更新、统计和持久化由应用根注入的
/// [ReviewRatingPersistence] 负责。这样迁移评分事实来源时无需再次让
/// 页面直接依赖遗留学习状态。
class ReviewRatingWriter {
  const ReviewRatingWriter({required ReviewRatingPersistence writeRating}) : _writeRating = writeRating;

  final ReviewRatingPersistence _writeRating;

  Future<void> rate(FsrsRating rating) => _writeRating(rating);
}
