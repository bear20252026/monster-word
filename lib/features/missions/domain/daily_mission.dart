// M2（D1/D2）：每日任务的产品口径与纯函数。
//
// 这里刻意不 import Flutter / 存储 / 时间以外的任何东西：
// 任务生成、目标计算、完成判定都是纯函数，单测可以直接覆盖边界
//（到期不足 20、跨天、正确率 80 边界），不需要数据库或 Provider。

/// 固定的三条任务：学 10 新词 / 复习 20 到期词 / 一局正确率 ≥ 80%。
const int dailyLearnNewWordsTarget = 10;
const int dailyReviewDueTarget = 20;
const int dailyAccuracyTargetPercent = 80;

/// D2：每条固定 5 币；三条全部完成 = 15 币/天（天然满足日上限）。
const int dailyMissionCoinReward = 5;
const int dailyMissionDailyCoinCap = dailyMissionCoinReward * 3;

enum DailyMissionId {
  learnNew('learn_new'),
  reviewDue('review_due'),
  sessionAccuracy('session_accuracy');

  const DailyMissionId(this.key);

  /// 持久化用的稳定键（写进 `daily_missions.task_id`，不可随枚举名改动）。
  final String key;

  static DailyMissionId? fromKey(String key) {
    for (final id in DailyMissionId.values) {
      if (id.key == key) return id;
    }
    return null;
  }
}

/// 任务展示文案。标题里的数字来自当天的目标，而不是写死的 20。
class DailyMissionDefinition {
  const DailyMissionDefinition({required this.id, required this.title});

  final DailyMissionId id;
  final String title;
}

/// 复习任务的当日目标：`min(20, 已复习 + 尚未到期数)`。
///
/// 「已复习 + 尚未到期」= 今天这批评测里属于到期词的总量，用户复习推进时
/// 这个和保持不变；新卡当天到期会让目标变大（封顶 20），符合「不足 20 按实际数」。
/// 两者都为 0 时返回 null：既可能是「今天真的没有到期词」，也可能是调度还没加载，
/// 此时不判定完成（宁可待完成，也不误发 5 币）。
int? reviewMissionTarget({required int reviewedToday, required int dueNow}) {
  final total = reviewedToday + dueNow;
  if (total <= 0) return null;
  return total > dailyReviewDueTarget ? dailyReviewDueTarget : total;
}

/// 某条任务的当日目标；复习任务在无法确定时返回 null。
int? dailyMissionTarget(DailyMissionId id, {required int reviewedToday, required int dueNow}) {
  switch (id) {
    case DailyMissionId.learnNew:
      return dailyLearnNewWordsTarget;
    case DailyMissionId.reviewDue:
      return reviewMissionTarget(reviewedToday: reviewedToday, dueNow: dueNow);
    case DailyMissionId.sessionAccuracy:
      return dailyAccuracyTargetPercent;
  }
}

/// 完成判定：进度达到目标即完成；目标不可得（null）一律未完成。
bool isDailyMissionComplete({required int progress, required int? target}) {
  if (target == null) return false;
  return progress >= target;
}

/// 按当天进度构建三条任务的展示定义（顺序固定：新词 → 复习 → 正确率）。
List<DailyMissionDefinition> dailyMissionDefinitions({required int? reviewTarget}) {
  return [
    const DailyMissionDefinition(id: DailyMissionId.learnNew, title: '学 $dailyLearnNewWordsTarget 个新词'),
    DailyMissionDefinition(
      id: DailyMissionId.reviewDue,
      title: reviewTarget == null ? '复习到期词' : '复习 $reviewTarget 个到期词',
    ),
    const DailyMissionDefinition(id: DailyMissionId.sessionAccuracy, title: '一局正确率 ≥ $dailyAccuracyTargetPercent%'),
  ];
}

/// 本地时区日期键（yyyy-MM-dd）。跨天以本地 0 点为界（决策单技术默认）。
String dailyMissionDayKey(DateTime time) {
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  return '${time.year}-$month-$day';
}

/// 会话正确率（0–100）。没有答题（answered <= 0）时返回 null，不参与任务判定。
int? sessionAccuracyPercent({required int answered, required int correct}) {
  if (answered <= 0) return null;
  return ((correct / answered) * 100).round().clamp(0, 100);
}
