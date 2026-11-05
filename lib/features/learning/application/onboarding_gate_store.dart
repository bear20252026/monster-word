// 首启三步角色对话 + 一句承诺：内容口径与「只出现一次」闸门。
//
// 文案自建（不复用任何第三方产品台词）；只出现一次、可跳过，
// 关闭或跳过都落标，之后不再打扰。
import 'package:word_app/core/infrastructure/app_preferences.dart';

/// 一步对话：怪兽的一句主台词 + 一句旁白。
class OnboardingStep {
  const OnboardingStep({required this.line, required this.caption});

  final String line;
  final String caption;
}

/// 三步对话（顺序即展示顺序）。
const List<OnboardingStep> onboardingSteps = <OnboardingStep>[
  OnboardingStep(line: '我是住在这本词书里的小怪兽。', caption: '你学的每个词，都会变成我的力气。'),
  OnboardingStep(line: '我饿的时候只吃尖叫币。', caption: '每学完一组词，我就吃一颗。'),
  OnboardingStep(line: '我记性不好，所以每天只求一小步。', caption: '你今天愿意来，就算是赢了。'),
];

/// 一句承诺（第三步出现；只正向，不惩罚）。
const String onboardingPromise = '我保证：不扣分、不清零、不催你。';

/// 首启引导闸门（application 层持有 SP 读写，presentation 只消费布尔值）。
class OnboardingGateStore {
  const OnboardingGateStore();

  /// 是否已经出现过（关闭或跳过都会置真）。
  bool get done => AppPreferences().getOnboardingDone();

  /// 标记已出现；写入失败由调用方决定是否上报。
  Future<bool> markDone() => AppPreferences().setOnboardingDone();
}
