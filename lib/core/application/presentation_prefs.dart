import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';

/// presentation 可见的偏好读取门面（R-prefs：禁直接 import infrastructure）。
///
/// 装配边界（*_feature_providers）负责 create；页面经 `context.read<PresentationPrefs>()` 消费。
class PresentationPrefs {
  PresentationPrefs({AppPreferences? prefs}) : _p = prefs ?? AppPreferences();

  /// 装备架条目数（hero + 收藏陈列 2 行；profile 装备卡片共用）。
  static const int equipRackCount = 3;

  /// 会话清理用 SP key（审计 I62 单一事实来源在 app_preferences.dart；
  /// R-prefs 要求 presentation 经本端口引用，不得直触 infrastructure）。
  static const String sessionUserInfoKey = kUserInfoPrefsKey;
  static const String sessionTokenKey = AppPreferences.userToken;
  static const String sessionSecretKey = AppPreferences.userSecret;

  /// 已兑换收藏章键前缀（单一事实来源：AppPreferences；兑换页与 redeemedBadgeCount 共用）。
  static const String redeemedBadgePrefix = AppPreferences.redeemedBadgePrefix;

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

  // ── 会话态（审计 I8：AppSessionState 经本端口消费，R-prefs 禁直触 SP）──

  static const String _sessionLoggedInKey = 'session_is_logged_in';
  static const String _initGuideShownKey = 'session_init_guide_shown';

  /// 确保底层 SP 就绪（幂等；测试环境无 bootstrap 预热，写前必须调用）。
  Future<void> ensureReady() => _p.init();

  bool getSessionLoggedIn() => _p.getBool(_sessionLoggedInKey, defaultValue: false);

  Future<void> markSessionLoggedIn() => _p.setBool(_sessionLoggedInKey, true);

  bool getInitGuideShown() => _p.getBool(_initGuideShownKey, defaultValue: false);

  Future<void> setInitGuideShown(bool value) => _p.setBool(_initGuideShownKey, value);

  /// 登出清理：只清「会话态 + 凭证」，保留本地资料（MW-62）。
  ///
  /// 当前无服务端账号体系——monster_word_user_info 是昵称/头像/签名的
  /// 【唯一副本】，登出删除后无法从任何地方恢复。会话数据（登录标记）
  /// 与本地资料（LocalProfile）是两个概念：登出只清前者；资料的清除
  /// 属「删除账号/清除本机数据」的显式动作，另行入口。
  /// 失败不抛出（登出语义不阻断），上报保持可观测。
  Future<void> clearSessionData() async {
    await ensureReady();
    try {
      await _p.remove(_sessionLoggedInKey);
      await _p.remove(AppPreferences.userToken);
      await _p.remove(AppPreferences.userSecret);
      // MW-62：不再 remove(kUserInfoPrefsKey)——本地资料保留。
      // 引导标记同样保留（展示过一次即可，与登录态无关）。
    } catch (e, s) {
      reportSwallowedError('会话数据清理失败', e, s);
    }
  }

  /// 随身听播放顺序（与 PlayOrderPage.prefKey 同源）
  String getPlayOrder() => _p.getString('stereo.play_order');

  Future<void> setPlayOrder(String name) => _p.setString('stereo.play_order', name);
}
