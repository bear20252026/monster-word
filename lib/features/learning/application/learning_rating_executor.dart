// 第四轮审计 M4（2026-11-17）：学习会话评分执行器下沉 application。
//
// 原 LearningSessionState.rate 内联「FSRS 写 → Leitner 推进」编排（约 20 行），
// 与 review 侧 ReviewSessionRatingExecutor（已下沉）不对称。现镜像同款范式：
// **先落盘，成功后才推进引擎**（P1-02 Durable Command，业主选定「甲」方案）。
// 会话状态保留交互清理、计数、今日已学、索引推进、完成上报与通知。
import 'package:word_app/core/engine/fsrs6_engine.dart' show FsrsRating;
import 'package:word_app/core/engine/leitner_engine.dart';
import 'package:word_app/features/learning/application/review_schedule_writer_port.dart';

/// 学习会话评分执行器。
///
/// 返回 `true` = 已写入且 Leitner 引擎已推进；`false` = 持久化硬失败
/// （连降级日志都写不进），**引擎未推进**，调用方应停在本题让用户重试。
/// 硬失败异常原样上抛由调用方上报（与 review 执行器的 catch-上报口径不同：
/// 学习侧 presentation 既有 FsrsRatingPersistException 专门捕获分支，保留）。
class LearningRatingExecutor {
  LearningRatingExecutor({required this.engine, required this.writerPort});

  final LeitnerCardEngine engine;
  final ReviewScheduleWriterPort writerPort;

  /// 评分：FSRS 持久化成功才推进 Leitner 会话引擎。
  ///
  /// [onAgain] 在 again 评分且持久化成功后回调（调用方记录错词）——
  /// 错词簿属于会话统计，不在执行器职责内，经回调交还 presentation。
  Future<bool> rate({required String word, required FsrsRating rating, void Function()? onAgain}) async {
    // 硬失败（FsrsRatingPersistException）原样上抛：调用方停留当前词，
    // 绝无「假成功」（P1-02）。pendingRetry 是已落降级日志的软成功，照常推进。
    await writerPort.rateWord(word: word, rating: rating);
    switch (rating) {
      case FsrsRating.again:
        engine.iDontKnow();
        onAgain?.call();
      case FsrsRating.hard:
        engine.iMayKnow();
      case FsrsRating.good:
        engine.iReallyKnow();
      case FsrsRating.easy:
        engine.tooEasy();
    }
    return true;
  }
}
