// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 本地存储层
// AppPreferences（应用配置）+ UserPreferences（用户配置）
// （GuidePreference 与同名的 UserInfoBean 副本已按审计结论删除，见文件末尾说明）

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 基础 SharedPreferences 封装（BaseSharedPreferences）
abstract class BaseSharedPreferences {
  SharedPreferences? _prefs;

  SharedPreferences get prefs {
    if (_prefs == null) throw StateError('SharedPreferences 未初始化');
    return _prefs!;
  }

  Future<void> init() async {
    // 审计 I8：getInstance 本身是进程级缓存；这里每次重新赋值而非 ??= 缓存
    // ——测试中 setMockInitialValues 会替换底层实例，??= 会让单例持有上一个
    // 测试的陈旧 SP（REG-START-003 踩中：读到残留登录态）。生产环境
    // getInstance 恒返回同一实例，重新赋值行为不变。
    _prefs = await SharedPreferences.getInstance();
  }

  // ── 读操作：未初始化（如测试环境 / 首帧前）时返回默认值，避免 UI 构建期抛 StateError ──
  String getString(String key, {String defaultValue = ''}) => _prefs?.getString(key) ?? defaultValue;

  int getInt(String key, {int defaultValue = 0}) => _prefs?.getInt(key) ?? defaultValue;

  bool getBool(String key, {bool defaultValue = false}) => _prefs?.getBool(key) ?? defaultValue;

  double getDouble(String key, {double defaultValue = 0.0}) => _prefs?.getDouble(key) ?? defaultValue;

  List<String> getStringList(String key, {List<String>? defaultValue}) =>
      _prefs?.getStringList(key) ?? defaultValue ?? [];

  bool containsKey(String key) => _prefs?.containsKey(key) ?? false;
  Set<String> getKeys() => _prefs?.getKeys() ?? const {};

  // ── 写操作：未初始化仍抛错，及时暴露初始化时序问题 ──
  Future<bool> setString(String key, String value) => prefs.setString(key, value);
  Future<bool> setInt(String key, int value) => prefs.setInt(key, value);
  Future<bool> setBool(String key, bool value) => prefs.setBool(key, value);
  Future<bool> setDouble(String key, double value) => prefs.setDouble(key, value);
  Future<bool> setStringList(String key, List<String> value) => prefs.setStringList(key, value);

  Future<bool> remove(String key) => prefs.remove(key);
  Future<bool> clear() => prefs.clear();
}

/// 安全 Token 存储（flutter_secure_storage 封装）
///
/// 将敏感凭证（token/secret）从 SharedPreferences 明文迁移到
/// 平台安全存储（iOS Keychain / Android Keystore）。
class SecureTokenStorage {
  static final SecureTokenStorage _instance = SecureTokenStorage._();
  factory SecureTokenStorage() => _instance;
  SecureTokenStorage._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // 审计 I62：key 与 AppPreferences 常量同源（安全存储与 SP 回退共用同一 key 名）
  static const _keyToken = AppPreferences.userToken;
  static const _keySecret = AppPreferences.userSecret;

  /// 读取 token（安全存储 → 回退 SharedPreferences → 空字符串）
  Future<String> getToken() async {
    String? value;
    try {
      value = await _storage.read(key: _keyToken);
    } catch (e, s) {
      // 审计 I55：平台通道异常（Keystore 故障/系统还原）不中断登录链路
      reportSwallowedError('安全存储读取 token 失败，回退 SP', e, s);
      value = null;
    }
    if (value != null && value.isNotEmpty) return value;
    // 回退：从 SharedPreferences 读取旧值并迁移
    final prefs = AppPreferences();
    value = prefs.getString(_keyToken);
    if (value.isNotEmpty) {
      // 迁移写失败不能打断登录链：保留 SP 旧值下次再迁（成功才清明文）。
      try {
        await _storage.write(key: _keyToken, value: value);
        await prefs.remove(_keyToken); // 清除明文
      } catch (e, s) {
        reportSwallowedError('安全存储迁移写失败（保留 SP 下次重试）', e, s);
      }
    }
    return value;
  }

  /// 写入 token（安全存储）
  Future<void> setToken(String value) async {
    try {
      await _storage.write(key: _keyToken, value: value);
    } catch (e, s) {
      // 审计 I55：写入失败降级为"本次会话有效"，下次冷启动需重新登录
      //（上报可观测；不向上抛——此前异常会打断整个资料保存流程）
      reportSwallowedError('安全存储写入 token 失败', e, s);
    }
  }

  /// 读取 secret（安全存储 → 回退 SharedPreferences → 空字符串）
  Future<String> getSecret() async {
    String? value;
    try {
      value = await _storage.read(key: _keySecret);
    } catch (e, s) {
      reportSwallowedError('安全存储读取 secret 失败，回退 SP', e, s);
      value = null;
    }
    if (value != null && value.isNotEmpty) return value;
    // 回退：从 SharedPreferences 读取旧值并迁移
    final prefs = AppPreferences();
    value = prefs.getString(_keySecret);
    if (value.isNotEmpty) {
      // 迁移写失败不能打断登录链：保留 SP 旧值下次再迁（成功才清明文）。
      try {
        await _storage.write(key: _keySecret, value: value);
        await prefs.remove(_keySecret); // 清除明文
      } catch (e, s) {
        reportSwallowedError('安全存储迁移写失败（保留 SP 下次重试）', e, s);
      }
    }
    return value;
  }

  /// 写入 secret（安全存储）
  Future<void> setSecret(String value) async {
    try {
      await _storage.write(key: _keySecret, value: value);
    } catch (e, s) {
      reportSwallowedError('安全存储写入 secret 失败', e, s);
    }
  }

  /// 清除所有安全存储的凭证
  Future<void> clearAll() async {
    // 审计 I55：登出清理路径，删除失败不阻断登出（与残留风险权衡后上报即可）
    try {
      await _storage.delete(key: _keyToken);
    } catch (e, s) {
      reportSwallowedError('安全存储删除 token 失败', e, s);
    }
    try {
      await _storage.delete(key: _keySecret);
    } catch (e, s) {
      reportSwallowedError('安全存储删除 secret 失败', e, s);
    }
  }
}

/// 应用配置
class AppPreferences extends BaseSharedPreferences {
  /// 每日新学单词数（settings 与 learning 共享 key，架构审计后上提）
  static const dailyNewWordsKey = 'daily_new_words_v1';
  static const todayLearnedKey = 'learning_today_learned_count';
  static const todayLearnedDateKey = 'learning_today_learned_date';

  /// 读取每日新学目标（默认 10，与 LearningPreferencesRepository.defaults 一致）
  int getDailyNewWords() => getInt(dailyNewWordsKey, defaultValue: 10);

  /// 今日已学数（跨天由调用方负责清零）
  int getTodayLearned() => getInt(todayLearnedKey, defaultValue: 0);

  /// 保存今日已学数与日期
  Future<void> setTodayLearned(int count, {required String date}) async {
    await setInt(todayLearnedKey, count);
    await setString(todayLearnedDateKey, date);
  }

  /// 已存日期（用于跨天判断）
  String getTodayLearnedDate() => getString(todayLearnedDateKey);

  /// 「旧 daily_new_words_v1 → daily_learn_goal」一次性迁移完成标记。
  static const todayGoalMigratedKey = 'today_goal_migrated_v1';
  bool get isTodayGoalMigrated => getBool(todayGoalMigratedKey, defaultValue: false);
  Future<void> markTodayGoalMigrated() => setBool(todayGoalMigratedKey, true);

  // ── 助记展示偏好（settings 与 dictionary 共享 key，架构审计后上提）──

  /// 助记段落顺序键（逗号分隔段落名，单词详情页按此排序消费）。
  static const mnemonicOrderKey = 'mnemonic_order_v1';

  /// 形近词（特殊变形）显示开关键。
  static const showSimilarWordsKey = 'show_similar_words_v1';

  /// 词根词缀显示开关键。
  static const showRootsKey = 'show_roots_v1';

  /// 每日目标弹窗「不再提示」键（lib_select 首次进入提示后置位）。
  static const dailyGoalPromptShownKey = 'daily_goal_prompt_shown';

  /// 助记段落默认顺序（与 LearningPreferences.defaults 一致）。
  static const defaultMnemonicOrder = '派生词,词组搭配,特殊变形,词根词缀';

  /// 形近词默认显示（与 LearningPreferences.defaults 一致）。
  static const defaultShowSimilarWords = true;

  /// 词根词缀默认显示（与 LearningPreferences.defaults 一致）。
  static const defaultShowRoots = true;

  // ── 兑换/装备共享（account 与 settings 共享，经 core 中转避免跨功能 import）──

  /// 已兑换收藏章的 SharedPreferences 键前缀（兑换中心/装备架/profile 同源）。
  static const String redeemedBadgePrefix = 'scare_coin.redeemed.';

  /// 装备架条目数（我的装备页与 profile 装备卡片共用，装备架增删条目时同步更新）。
  static const int equipRackCount = 3;

  /// 已兑换收藏章枚数（扫描 prefs 键前缀）。
  int redeemedBadgeCount() => getKeys().where((k) => k.startsWith(redeemedBadgePrefix)).length;

  static final AppPreferences _instance = AppPreferences._();
  factory AppPreferences() => _instance;
  AppPreferences._();

  // === 常量 key（1:1）===
  static const String appConfig = 'app_config_list';
  static const String appLastRunTime = 'key_appRunLastTime';
  static const String appNeedMigrateToV3 = 'app_need_migrate_to_v3';
  static const String userToken = 'user_token';
  static const String userSecret = 'user_secret';
  // R3-D07 待议：本组常量中以下 14 个经全仓核查（Dart/Py/Sh/Mjs/Md）**零代码引用**，
  // 仅被 `docs/reports/data_layer_audit.md` 等历史报告作为「键清单」记载：
  //   userId / bookGroupList / uiTheme / extensiveMode / studyRemindText /
  //   netLineType / lastLoginInfo / historyQuery / appPermissionGrantShow /
  //   keyAppFirstCheckin / keyUserTrackEnable（+ 上方 appConfig / appLastRunTime /
  //   appNeedMigrateToV3）
  // 未随本次一并删除，原因有二：
  //   ① 它们是 SP 键的**唯一命名出处**，删掉后历史报告里的键清单将无处对照，
  //      而 SP 里可能仍残留这些键的实际数据（`ui_theme` 被批1 文档证实曾有 int 写入）；
  //   ② `uiTheme` 是已知的**类型冲突键**（历史文档明确「禁止复用」），
  //      保留声明反而利于继续对这个坑做静态提醒。
  // ⇒ 若要清理，建议连同历史报告一起改为「已废弃键清单」，作为独立一次变更做，
  //   不要在死代码清理里顺手删（那会让报告与代码同时失去锚点）。
  static const String userId = 'key_userId';
  static const String pronounce = 'key_pronounceType';
  static const String uiTheme = 'ui_theme';
  static const String bookGroupList = 'key_group_library_List_v3_2';
  static const String extensiveMode = 'extensive_mode';
  static const String studyRemindText = 'study_remind_text';
  static const String netLineType = 'key_net_line_type';
  static const String searchHistory = 'key_search_history';
  static const String lastLoginInfo = 'key_last_login_info';
  static const String historyQuery = 'history_query';
  static const String appUserRulesAgree = 'app_user_rules_agree';
  static const String appPermissionGrantShow = 'app_permission_grant_show';
  static const String keyAppFirstCheckin = 'key_app_first_checkin';
  static const String keyUserTrackEnable = 'key_user_track_enable';

  // === 皮肤主题持久化（批1新增）===
  static const String skinThemeId = 'skin_theme_id'; // 'bright'|'dark'|'pure_black'
  static const String skinFollowSystem = 'skin_follow_system'; // bool

  /// 获取皮肤主题 ID（空=未设置）
  String getSkinThemeId() => getString(skinThemeId);
  Future<bool> setSkinThemeId(String v) => setString(skinThemeId, v);

  /// 是否跟随系统主题
  bool isSkinFollowSystem() => getBool(skinFollowSystem);
  Future<bool> setSkinFollowSystem(bool v) => setBool(skinFollowSystem, v);

  /// 初始化（getInstance 延迟初始化）
  @override
  Future<void> init() async {
    await super.init();
  }

  // R3-D07：此处原有 getBookGroupList/setBookGroupList、getUserToken、getUserSecret、
  // getUserId/setUserId —— 全部**零调用**，已删除。
  // 其中 getUserToken/getUserSecret 尤其不能留：它们从**明文 SharedPreferences**
  // 读凭证，与 S1「token/secret 只入 SecureTokenStorage」的修复直接冲突；
  // 仅靠 `@Deprecated` 注解挡不住调用（注解不报错、只提示，且本仓 analyzer 的
  // info 级提示在 CI 里等同失败，反而会诱导后来者「顺手改回去让它编过」）。
  // 需要凭证一律走 `SecureTokenStorage().getToken()/getSecret()`。

  /// 发音类型（0=美音 1=英音）
  int getPronounce() => getInt(pronounce);
  Future<bool> setPronounce(int value) => setInt(pronounce, value);

  /// 用户规则同意
  bool isUserRulesAgreed() => getBool(appUserRulesAgree);
  Future<bool> setUserRulesAgreed(bool v) => setBool(appUserRulesAgree, v);

  /// 搜索历史（最近 50 条）
  List<String> getSearchHistory() => getStringList(searchHistory);

  Future<void> addSearchHistory(String word) async {
    final history = getSearchHistory();
    history.remove(word); // 去重
    history.insert(0, word); // 最新的在前
    if (history.length > 50) history.removeLast(); // 最多 50 条
    await setStringList(searchHistory, history);
  }

  Future<void> clearSearchHistory() async {
    await setStringList(searchHistory, []);
  }
}

/// 用户配置
class UserPreferences extends BaseSharedPreferences {
  static final UserPreferences _instance = UserPreferences._();
  factory UserPreferences() => _instance;
  UserPreferences._();

  // === 常量 key（1:1）===
  static const String autoPlay = 'auto_play_voice';
  static const String checkInDate = 'checkIn_date';
  static const String enableLockScreen = 'enable_lock_screen';
  static const String learnedNum = 'learnedCount';
  static const String learnedFinishedGroupList = 'learned_finished_group_list';
  static const String lexisBook = 'library_learning';
  static const String includeNewWord = 'includeNewWord';
  static const String settingLearnStrategy = 'setting_learn_strategy_';
  static const String settingLearnStrategy20Level = 'setting_learn_strategy20_level_';
  static const String defaultShowWordroot = 'default_show_wordroot';
  static const String offlineSpeech = 'offLine_speech';
  static const String lastClickPanel = 'last_click_panel';
  static const String lastClickSimplePanel = 'last_click_simple_panel';
  static const String firstGroupLearnComplete = 'first_group_learn_complete';
  static const String deletedWord = 'firstDelWord';
  static const String shareDate = 'shared_date';
  static const String remindEnable = 'remind_user';
  static const String remindTime = 'remind_time';
  static const String feedbackUnreadCount = 'feedback_unread_count';
  static const String dailyGoal = 'daily_learn_goal';

  @override
  Future<void> init() async {
    await super.init();
  }

  /// 每日学习目标（默认 10 个，范围 1-200）
  int getDailyGoal() => getInt(dailyGoal, defaultValue: 10);
  Future<bool> setDailyGoal(int value) {
    final clamped = value.clamp(1, 200);
    return setInt(dailyGoal, clamped);
  }

  /// 今日已学数量
  int getLearnedNum() => getInt(learnedNum);
  Future<bool> setLearnedNum(int value) => setInt(learnedNum, value);

  /// 已完成学习组列表（JSON 字符串）
  String getLearnedFinishedGroupList() => getString(learnedFinishedGroupList);
  Future<bool> setLearnedFinishedGroupList(String value) => setString(learnedFinishedGroupList, value);

  /// 当前选择的词书（JSON 字符串）
  String getLexisBook() => getString(lexisBook);
  Future<bool> setLexisBook(String value) => setString(lexisBook, value);

  /// 是否包含生词本
  bool isIncludeNewWord() => getBool(includeNewWord);
  Future<bool> setIncludeNewWord(bool v) => setBool(includeNewWord, v);

  /// 学习策略
  String getSettingLearnStrategy() => getString(settingLearnStrategy);
  Future<bool> setSettingLearnStrategy(String value) => setString(settingLearnStrategy, value);

  /// 自动发音
  bool isAutoPlay() => getBool(autoPlay);
  Future<bool> setAutoPlay(bool v) => setBool(autoPlay, v);

  /// 锁屏学单词
  bool isEnableLockScreen() => getBool(enableLockScreen);
  Future<bool> setEnableLockScreen(bool v) => setBool(enableLockScreen, v);

  /// 签到日期
  String getCheckInDate() => getString(checkInDate);
  Future<bool> setCheckInDate(String value) => setString(checkInDate, value);

  /// 学习提醒
  bool isRemindEnable() => getBool(remindEnable);
  Future<bool> setRemindEnable(bool v) => setBool(remindEnable, v);
  String getRemindTime() => getString(remindTime);
  Future<bool> setRemindTime(String value) => setString(remindTime, value);
}

// 死代码清理（2026-10 审计）：
//   · GuidePreference（guide_learn 等四个引导标记）全库零引用，已删除。
//   · **R3-D06：本文件原先自带一个 `UserInfoBean` + `getUserInfoSync/getUserInfo/
//     setUserInfo` 扩展，已整体删除。** 理由不是「没人用」，而是它**会撤销安全
//     修复**：`lib/models/user_info_bean.dart` 才是真正在用的那个，生产路径
//     `user_service_impl.setUserInfoBean` 会把 `token`/`secret` 先送进
//     `SecureTokenStorage` 再把两者清空后才写 SP（安全审计 S1）；而本文件这个
//     副本**少 `signature` 字段且不做任何剥离**，`setUserInfo` 直接把
//     `toJson()`（含 token/secret 明文）写进 SharedPreferences。
//     当时它已零调用方，但**后来者顺手一用就会把明文凭证重新落盘**，且因为
//     同名类存在，`user_service_impl.dart` 一直靠 `hide UserInfoBean` 才没撞上
//     —— 这种「留着但谁也不许碰」的状态只能靠纪律维持，删掉才是根治。
//
//     ⚠️ `kUserInfoPrefsKey`（下方常量）**仍是活的**，别一起删：
//        `presentation_prefs.sessionUserInfoKey` 与 `user_service_impl._userInfoKey`
//        都引用它（审计 I62 的 key 单一事实来源）。
//
// SP 中可能残留旧键值，无消费方、无迁移必要。

// ── 用户信息 SP key ──

/// 用户信息 SP key 单一事实来源（审计 I62：此前在本文件、user_service_impl、
/// app_session_state 三处平行定义，改 key 必须同步多处）。
const String kUserInfoPrefsKey = 'monster_word_user_info';
