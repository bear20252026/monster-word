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

  /// 评分：**先落盘，成功后才推进引擎**（业主 2026-10-17 选定「甲」方案）。
  ///
  /// 返回 `true` = 已写入且引擎已推进；`false` = 写入失败，**引擎未推进**，
  /// 调用方应停在本题让用户重试。
  ///
  /// 原实现是「先 `_advanceEngine` 再 fire-and-forget 写库」：UI 立刻翻到下一题、
  /// 计入已复习，而写库失败只留一条 swallowed-error ⇒ 用户看到「复习完成」，
  /// 记录却没保存（审计 P1-04）。`rateWord` 内部已有两步降级（SQLite → SP 日志），
  /// 走到这里失败意味着连降级日志都写不进 —— 这种时候假装成功伤害最大。
  Future<bool> rate({required MwWordProcess reviewedWord, required RecallRating rating}) async {
    try {
      await _ratingWriter.rate(word: reviewedWord.word, rating: _toFsrsRating(rating));
    } catch (error, stack) {
      reportSwallowedError('FSRS 评分写入失败（本题不推进，等用户重试）', error, stack);
      return false;
    }
    _advanceEngine(rating);
    return true;
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
