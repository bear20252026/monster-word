import 'package:word_app/core/engine/fsrs6_engine.dart' show FsrsRating;
import 'package:word_app/core/engine/srs_engine.dart' show RecallRating;
import 'package:word_app/core/engine/super_memory_engine.dart';
import 'package:word_app/models/mw_word_process.dart';
import 'package:word_app/features/learning/application/review_rating_writer.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

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

  void rate({required MwWordProcess reviewedWord, required RecallRating rating}) {
    _advanceEngine(rating);
    // 持久化 Future 未接也未处理：引擎已推进而 FSRS 写失败只产生
    // unhandled async error，评分静默丢失。接住并上报（会话不阻断）。
    _ratingWriter
        .rate(word: reviewedWord.word, rating: _toFsrsRating(rating))
        .then<void>((_) {}, onError: (Object e, StackTrace s) => reportSwallowedError('FSRS 评分写入失败', e, s));
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
