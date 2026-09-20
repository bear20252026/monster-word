import 'package:word_app/core/infrastructure/app_preferences.dart';

/// presentation 可见的偏好读取门面（R-prefs：禁直接 import infrastructure）。
///
/// 装配边界（*_feature_providers）负责 create；页面经 `context.read<PresentationPrefs>()` 消费。
class PresentationPrefs {
  PresentationPrefs({AppPreferences? prefs}) : _p = prefs ?? AppPreferences();

  /// 装备架条目数（hero + 收藏陈列 2 行；profile 装备卡片共用）。
  static const int equipRackCount = 3;

  final AppPreferences _p;

  int get todayLearned => _p.getTodayLearned();

  int get redeemedBadgeCount => _p.redeemedBadgeCount();

  bool get showSimilarWords =>
      _p.getBool(AppPreferences.showSimilarWordsKey, defaultValue: AppPreferences.defaultShowSimilarWords);

  bool get showRoots => _p.getBool(AppPreferences.showRootsKey, defaultValue: AppPreferences.defaultShowRoots);

  String get mnemonicOrder =>
      _p.getString(AppPreferences.mnemonicOrderKey, defaultValue: AppPreferences.defaultMnemonicOrder);

  int get dailyGoal => UserPreferences().getDailyGoal();

  Future<bool> setDailyGoal(int value) => UserPreferences().setDailyGoal(value);

  bool get dailyGoalPromptShown => _p.getBool(AppPreferences.dailyGoalPromptShownKey, defaultValue: false);

  Future<void> markDailyGoalPromptShown() => _p.setBool(AppPreferences.dailyGoalPromptShownKey, true);

  /// 随身听播放顺序（与 PlayOrderPage.prefKey 同源）
  String getPlayOrder() => _p.getString('stereo.play_order');

  Future<void> setPlayOrder(String name) => _p.setString('stereo.play_order', name);
}
