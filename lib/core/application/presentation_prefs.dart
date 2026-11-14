import 'package:word_app/core/application/llm_client.dart';
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

  // ── 怪兽桌面宠物（P3-3：monster_presence 移 companion 前的 SP 收口，R-prefs）──

  static const String _monsterPosXKey = 'monster_pos_x';
  static const String _monsterPosYKey = 'monster_pos_y';
  static const String _monsterLastVisitKey = 'monster_last_home_visit';

  /// 怪兽上次停靠位置（归一化 0~1）；从未拖过返回 null。
  ({double x, double y})? monsterPosition() {
    if (!_p.containsKey(_monsterPosXKey) || !_p.containsKey(_monsterPosYKey)) return null;
    return (x: _p.getDouble(_monsterPosXKey), y: _p.getDouble(_monsterPosYKey));
  }

  /// 松手才写盘（归一化比例，换分辨率仍落同一相对位置）。
  Future<void> setMonsterPosition(double xRatio, double yRatio) async {
    await _p.setDouble(_monsterPosXKey, xRatio);
    await _p.setDouble(_monsterPosYKey, yRatio);
  }

  /// 怪兽上次「回家」的日键（welcomeBack 主动迎接用）；从未记录返回 null。
  String? monsterLastHomeVisit() {
    final v = _p.getString(_monsterLastVisitKey);
    return v.isEmpty ? null : v;
  }

  Future<void> setMonsterLastHomeVisit(String dayKey) => _p.setString(_monsterLastVisitKey, dayKey);

  // ── 学习伴侣 AI 化 · LLM 配置（R-prefs：presentation 经本门面读，key 走安全存储）──

  bool get llmEnabled => _p.getLlmEnabled();
  Future<void> setLlmEnabled(bool value) => _p.setLlmEnabled(value);

  String get llmBaseUrl => _p.getLlmBaseUrl();
  Future<void> setLlmBaseUrl(String value) => _p.setLlmBaseUrl(value);

  String get llmModel => _p.getLlmModel();
  Future<void> setLlmModel(String value) => _p.setLlmModel(value);

  /// 当前 LLM 配置快照（key 不在此对象，由 LlmCredentials 安全存储单独管理）。
  LlmConfig get llmConfig => LlmConfig(enabled: llmEnabled, baseUrl: llmBaseUrl, model: llmModel);
}
