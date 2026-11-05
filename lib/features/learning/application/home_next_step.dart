// 首页主卡的「下一步」口径：把今日目标 / 已学 / 待复习三件事收敛成一个动作 + 一句时长预期。
//
// 放在 application 层做纯函数，是为了让「主按钮显示什么、下一步是哪件事」可单测，
// 而不是散在 widget 的 build 里靠 if 硬编码。时间口径与既有文案一致：
// 复习约 14 秒/词、新词约 20 秒/词（见 home_hero 旧的「约 X 分钟能救回来」）。
import 'dart:math' as math;

/// 达标后「再来一组」的巩固词数（自建口径，不引入外部产品的数值）。
const int homeExtraPracticeCount = 5;

/// 单次复习一个到期词的估算秒数（与首页既有预警文案同源）。
const int homeReviewSecondsPerWord = 14;

/// 学一个新词的估算秒数。
const int homeLearnSecondsPerNewWord = 20;

/// 首页主卡的下一步动作。
enum HomeNextAction {
  /// 有到期词：先救回它们（时间敏感，优先于开新词）。
  reviewDue,

  /// 今天还没开始：开第一组。
  learnFirst,

  /// 已在推进但未达标：继续。
  continueLearning,

  /// 今日达标：再练一组巩固（只正向，不惩罚）。
  extraPractice,
}

/// 一张主卡要展示的全部口径（文案 + 时长都在这里定，widget 只负责画）。
class HomeNextStep {
  const HomeNextStep({
    required this.action,
    required this.headline,
    required this.ctaLabel,
    required this.estimatedMinutes,
    required this.primaryIsReview,
    required this.secondaryLabel,
  });

  final HomeNextAction action;

  /// 主标题（进程/目标句），UI 会在后面补「· 约 X 分钟」。
  final String headline;

  /// 一键开始按钮文案。
  final String ctaLabel;

  /// 估算分钟数（向上取整；0 表示无需估算）。
  final int estimatedMinutes;

  /// 主按钮是否指向复习（false 则指向学习）。
  final bool primaryIsReview;

  /// 副入口文字链（null 表示不展示）。
  final String? secondaryLabel;

  /// 带时长的主标题，例如「还差 10 个词 · 约 4 分钟」。
  String get title => estimatedMinutes > 0 ? '$headline · 约 $estimatedMinutes 分钟' : headline;
}

/// 只吃三个事实，算出「下一步」。
HomeNextStep resolveHomeNextStep({required int goal, required int learned, required int due}) {
  final safeGoal = math.max(0, goal);
  final safeLearned = math.max(0, learned);
  final safeDue = math.max(0, due);
  final remaining = math.max(0, safeGoal - safeLearned);
  final done = safeGoal > 0 && safeLearned >= safeGoal;

  if (safeDue > 0) {
    return HomeNextStep(
      action: HomeNextAction.reviewDue,
      headline: '先救回 $safeDue 个到期词',
      ctaLabel: '先救回 $safeDue 个到期词',
      estimatedMinutes: _minutesFor(safeDue * homeReviewSecondsPerWord),
      primaryIsReview: true,
      secondaryLabel: '继续学新词',
    );
  }
  if (done) {
    return HomeNextStep(
      action: HomeNextAction.extraPractice,
      headline: '今日目标已完成',
      ctaLabel: '再练 $homeExtraPracticeCount 个巩固',
      estimatedMinutes: _minutesFor(homeExtraPracticeCount * homeLearnSecondsPerNewWord),
      primaryIsReview: false,
      secondaryLabel: null,
    );
  }
  return HomeNextStep(
    action: safeLearned <= 0 ? HomeNextAction.learnFirst : HomeNextAction.continueLearning,
    headline: '还差 $remaining 个词',
    ctaLabel: safeLearned <= 0 ? '开始今天的第一组' : '继续今天的学习',
    estimatedMinutes: _minutesFor(remaining * homeLearnSecondsPerNewWord),
    primaryIsReview: false,
    secondaryLabel: null,
  );
}

int _minutesFor(int seconds) {
  if (seconds <= 0) return 0;
  return (seconds / 60).ceil();
}
