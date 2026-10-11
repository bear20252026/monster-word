import 'package:word_app/core/engine/fsrs6_engine.dart';

/// Port: review schedule mutations (rate / forget).
/// Presentation states depend on this abstraction, not on
/// `data/review_schedule_repository.dart` directly.

/// 评分持久化结果状态（P1-02 Durable Command，定义于 application 层供端口双方共用）。
///
/// - saved：已持久化成功（durable commit 先于内存提交）。
/// - pendingRetry：持久化暂失败，但评分意图已写入降级日志，
///   SQLite 恢复后幂等回放，不丢数据。UI 可提示「进度将在恢复后补记」。
enum FsrsRatingOutcome { saved, pendingRetry }

/// 评分持久化硬失败（内存未提交，评分未落任何持久层）。
/// 定义在 application 层：presentation 捕获它时不依赖 data 实现。
class FsrsRatingPersistException implements Exception {
  FsrsRatingPersistException(this.message);
  final String message;

  @override
  String toString() => 'FsrsRatingPersistException: $message';
}

abstract class ReviewScheduleWriterPort {
  Future<FsrsRatingOutcome> rateWord({required String word, required FsrsRating rating});

  Future<void> forget(String word);
}
