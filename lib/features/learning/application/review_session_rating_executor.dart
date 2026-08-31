import 'package:word_app/core/engine/fsrs6_engine.dart' show FsrsRating;
import 'package:word_app/core/engine/srs_engine.dart' show RecallRating;
import 'package:word_app/core/engine/super_memory_engine.dart';
import 'package:word_app/models/bb_word_process.dart';
import 'package:word_app/features/learning/application/review_rating_writer.dart';

/// 正式复习评分执行器。
///
/// 它在引擎推进前接收已捕获的 [reviewedWord]，将 [RecallRating] 同时映射为
/// 内存引擎命令和 FSRS 写入等级。会话状态负责交互清理、题目再生成、计数和通知。
class ReviewSessionRatingExecutor {
  ReviewSessionRatingExecutor({required this._engine, required this._ratingWriter});

  final SuperMemoryEngine _engine;
  ReviewRatingWriter _ratingWriter;

  void updateRatingWriter(ReviewRatingWriter ratingWriter) {
    _ratingWriter = ratingWriter;
  }

  void rate({required BBWordProcess reviewedWord, required RecallRating rating}) {
    _advanceEngine(rating);
    _ratingWriter.rate(word: reviewedWord.word, rating: _toFsrsRating(rating));
  }

  /// 保留“熟”只推进本地会话、不写入 FSRS 评分的既有语义。
  void markAsKnown() {
    _engine.iReallyKnow();
  }

  void _advanceEngine(RecallRating rating) {
    switch (rating) {
      case RecallRating.again:
        _engine.iDontKnow();
      case RecallRating.hard:
        _engine.iMayKnow();
      case RecallRating.good:
        _engine.iReallyKnow();
      case RecallRating.easy:
        _engine.tooEasy();
    }
  }

  FsrsRating _toFsrsRating(RecallRating rating) => switch (rating) {
    RecallRating.again => FsrsRating.again,
    RecallRating.hard => FsrsRating.hard,
    RecallRating.good => FsrsRating.good,
    RecallRating.easy => FsrsRating.easy,
  };
}
