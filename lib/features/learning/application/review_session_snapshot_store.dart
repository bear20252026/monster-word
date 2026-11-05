// 复习会话快照的应用层门面。
//
// 为什么不直接在页面里读写 SharedPreferences：架构守卫 R-prefs 禁止 presentation
// 直触 core/infrastructure/app_preferences.dart。与 BossIntroDayStore 同一收口思路：
// 键名与读写留在 application 层，页面只拿到「有没有可恢复的一局」。
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/learning/application/review_session_snapshot.dart';

/// 只做三件事：读快照（含消毒）、写快照、清快照。
class ReviewSessionSnapshotStore {
  const ReviewSessionSnapshotStore();

  /// 可恢复的一局；没有存档、损坏、超时、词不在当前词书等情况一律返回 null。
  ReviewSessionSnapshot? read({DateTime? now}) {
    final raw = AppPreferences().getReviewSessionSnapshot();
    return decodeReviewSessionSnapshot(raw, now: now ?? DateTime.now());
  }

  /// 写快照。失败不阻断复习（最坏只损失一次恢复机会），但要上报。
  Future<void> write(ReviewSessionSnapshot snapshot) async {
    try {
      await AppPreferences().setReviewSessionSnapshot(snapshot.encode());
    } catch (e, s) {
      reportSwallowedError('复习会话快照写入失败', e, s);
    }
  }

  /// 清快照（本局走完或没有可恢复内容时）。失败同样只上报。
  Future<void> clear() async {
    try {
      await AppPreferences().removeReviewSessionSnapshot();
    } catch (e, s) {
      reportSwallowedError('复习会话快照清理失败', e, s);
    }
  }
}
