// 今日路线（节点地图）口径：把今日目标拆成 3–5 个可见节点，只让「当前节点」彩色。
//
// 默认关闭灰度开关：镜像关闭时首页与旧版逐像素等价（编译期常量，死代码消除）。
// 节点状态与时长都收在纯函数里，widget 只负责画；数据复用 TodayProgressStore。
import 'dart:math' as math;

import 'package:word_app/features/learning/application/home_next_step.dart';

/// 今日路线开关（灰度）：`flutter run --dart-define=HOME_PATH=true` 才开启。
const bool kPathHome = bool.fromEnvironment('HOME_PATH', defaultValue: false);

/// 热身节点固定词数。
const int homePathWarmupWords = 3;

/// 节点种类（决定点击后的去向）。
enum HomePathNodeKind { warmup, newWords, review, chest }

/// 节点状态：已完成 / 当前 / 待解锁（灰但可点）。
enum HomePathNodeStatus { done, current, upcoming }

/// 一个路线节点。
class HomePathNode {
  const HomePathNode({
    required this.kind,
    required this.label,
    required this.detail,
    required this.status,
    required this.minutes,
  });

  final HomePathNodeKind kind;
  final String label;
  final String detail;
  final HomePathNodeStatus status;

  /// 预计耗时（分钟，至少 1）。
  final int minutes;
}

/// 由今日三态（目标 / 已学 / 待复习）生成 4 个节点：
/// 热身 3 词 → 今日新词 → 到期复习 → 宝箱（全部完成）。
///
/// 当前节点 = 第一个未完成的节点；全部完成时没有 current。
List<HomePathNode> buildHomePathNodes({required int goal, required int learned, required int due}) {
  final safeGoal = math.max(0, goal);
  final safeLearned = math.max(0, learned);
  final safeDue = math.max(0, due);

  final warmDone = safeLearned >= homePathWarmupWords;
  // 未设目标（goal <= 0）视为无需完成，不制造「还差 0 个」的伪任务。
  final goalDone = safeGoal <= 0 || safeLearned >= safeGoal;
  final reviewDone = safeDue <= 0;
  final allDone = warmDone && goalDone && reviewDone;

  final flags = <bool>[warmDone, goalDone, reviewDone, allDone];
  final currentIndex = flags.indexOf(false);

  HomePathNodeStatus statusOf(int index) {
    if (flags[index]) return HomePathNodeStatus.done;
    return index == currentIndex ? HomePathNodeStatus.current : HomePathNodeStatus.upcoming;
  }

  final remainingNew = safeGoal - safeLearned;
  return <HomePathNode>[
    HomePathNode(
      kind: HomePathNodeKind.warmup,
      label: '热身 $homePathWarmupWords 词',
      detail: warmDone ? '已完成' : '先做 $homePathWarmupWords 个词找回手感',
      status: statusOf(0),
      minutes: _minutesFor(math.min(safeLearned, homePathWarmupWords), homeLearnSecondsPerNewWord),
    ),
    HomePathNode(
      kind: HomePathNodeKind.newWords,
      label: '今日新词',
      detail: safeGoal <= 0 ? '未设置目标' : (goalDone ? '已完成' : '还差 $remainingNew 个'),
      status: statusOf(1),
      minutes: _minutesFor(math.max(0, remainingNew), homeLearnSecondsPerNewWord),
    ),
    HomePathNode(
      kind: HomePathNodeKind.review,
      label: '到期复习',
      detail: reviewDone ? '今天没有到期词' : '待复习 $safeDue 个',
      status: statusOf(2),
      minutes: _minutesFor(safeDue, homeReviewSecondsPerWord),
    ),
    HomePathNode(
      kind: HomePathNodeKind.chest,
      label: '宝箱',
      detail: allDone ? '今日路线已走完' : '全部完成后开启',
      status: statusOf(3),
      minutes: homePathWarmupWords * homeLearnSecondsPerNewWord ~/ 60,
    ),
  ];
}

/// 当前第几步（1-based）；全部完成返回 null。
int? homePathCurrentStep(List<HomePathNode> nodes) {
  final index = nodes.indexWhere((node) => node.status == HomePathNodeStatus.current);
  return index < 0 ? null : index + 1;
}

int _minutesFor(int words, int secondsPerWord) {
  if (words <= 0) return 1;
  return math.max(1, (words * secondsPerWord + 59) ~/ 60);
}
