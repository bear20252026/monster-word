// 由 Claude 团队生成 | Monster Word App

// 扩展偏好存储层：翻译自 sharepreference/（v3.2 源码 1:1）
// 补全 app_preferences.dart 中未覆盖的 key 和方法
// 包含：AppPreferencesExt / UserPreferencesExt / GuidePreferenceExt
//       AuthDataPreferences / Privileges / UserInfoBeanFull
//
// 注意：由于父类使用 factory 单例，此处采用组合模式（持有实例引用）而非继承

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_preferences.dart';

// ──────────────────────────────────────────────
//  全局配置（替代原版 PublicConstants）
// ──────────────────────────────────────────────

/// 应用版本和用户 ID 配置（原版 PublicConstants 中的字段）
/// 调用方在启动时设置，供各 Preferences 类使用动态 key 后缀
class PrefConfig {
  PrefConfig._();

  /// 当前应用版本号（原版 PublicConstants.appVersion）
  static String appVersion = '1.0.0';

  /// 当前登录用户 ID（原版 PublicConstants.userId）
  static String userId = '';
}

// ──────────────────────────────────────────────
//  权限 Bean（翻译自 Privileges.java）
// ──────────────────────────────────────────────

/// 单项权限（原版 Privileges.Privilege）
class Privilege {
  int granted;
  int userType;
  int collinsUserType;
  int expireDate;

  Privilege({this.granted = 0, this.userType = 0, this.collinsUserType = 0, this.expireDate = 0});

  bool get isGranted => granted == 1;

  factory Privilege.fromJson(Map<String, dynamic> json) => Privilege(
    granted: (json['granted'] as num?)?.toInt() ?? 0,
    userType: (json['user_type'] as num?)?.toInt() ?? 0,
    collinsUserType: (json['collins_user_type'] as num?)?.toInt() ?? 0,
    expireDate: (json['expire_date'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'granted': granted,
    'user_type': userType,
    'collins_user_type': collinsUserType,
    'expire_date': expireDate,
  };
}

/// 权限集合（原版 Privileges.java）
class Privileges {
  Privilege? collins;
  Privilege? wordroot;

  Privileges({this.collins, this.wordroot});

  bool get isCollinsGranted => collins?.isGranted ?? false;
  int get collinsUserType => collins?.userType ?? 0;
  int get collinsExpireDate => collins?.expireDate ?? 0;

  bool get isWordRootGranted => wordroot?.isGranted ?? false;
  int get wordRootUserType => wordroot?.userType ?? 0;
  int get wordRootExpireDate => wordroot?.expireDate ?? 0;

  factory Privileges.fromJson(Map<String, dynamic> json) => Privileges(
    collins: json['collins'] != null ? Privilege.fromJson(json['collins'] as Map<String, dynamic>) : null,
    wordroot: json['wordroot'] != null ? Privilege.fromJson(json['wordroot'] as Map<String, dynamic>) : null,
  );

  Map<String, dynamic> toJson() => {'collins': collins?.toJson(), 'wordroot': wordroot?.toJson()};
}

// ──────────────────────────────────────────────
//  完整 UserInfoBean（翻译自 UserInfoBean.java）
// ──────────────────────────────────────────────

/// 用户信息 Bean 完整版（原版 UserInfoBean.java 所有字段）
/// 注意：原版 Java 的 id/name/photo 对应 app_preferences.dart 中的
/// userId/nickname/avatar，此处保留两套命名以兼容原版 JSON
class UserInfoBeanFull {
  int id;
  String name;
  String email;
  String phone;
  String photo;
  // password 字段已移除 — 禁止本地存储密码（安全审计 H4）
  int quota;
  int continueX; // JSON key: "continue"
  int totalDays;
  int max;
  bool isNewUser;
  Privileges? privileges;

  UserInfoBeanFull({
    this.id = 0,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.photo = '',
    this.quota = 0,
    this.continueX = 0,
    this.totalDays = 0,
    this.max = 0,
    this.isNewUser = false,
    this.privileges,
  });

  // ── 权限快捷方法 ──

  bool get isCollinsGranted => privileges?.isCollinsGranted ?? false;
  int get collinsUserType => privileges?.collinsUserType ?? 0;
  int get collinsExpireDate => privileges?.collinsExpireDate ?? 0;

  bool get isWordRootGranted => privileges?.isWordRootGranted ?? false;
  int get wordRootUserType => privileges?.wordRootUserType ?? 0;
  int get wordRootExpireDate => privileges?.wordRootExpireDate ?? 0;

  // ── JSON 序列化 ──

  factory UserInfoBeanFull.fromJson(Map<String, dynamic> json) => UserInfoBeanFull(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] ?? '',
    email: json['email'] ?? '',
    phone: json['phone'] ?? '',
    photo: json['photo'] ?? '',
    quota: (json['quota'] as num?)?.toInt() ?? 0,
    continueX: (json['continue'] as num?)?.toInt() ?? 0,
    totalDays: (json['totalDays'] as num?)?.toInt() ?? 0,
    max: (json['max'] as num?)?.toInt() ?? 0,
    isNewUser: json['isNewUser'] ?? false,
    privileges: json['privileges'] != null ? Privileges.fromJson(json['privileges'] as Map<String, dynamic>) : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'photo': photo,
    'quota': quota,
    'continue': continueX,
    'totalDays': totalDays,
    'max': max,
    'isNewUser': isNewUser,
    'privileges': privileges?.toJson(),
  };
}

// ──────────────────────────────────────────────
//  AppPreferences 扩展（补全缺失的 key 和方法）
// ──────────────────────────────────────────────

/// AppPreferences 扩展：原版 AppPreferences.java 中未在 app_preferences.dart
/// 覆盖的常量 key 和业务方法
///
/// 采用组合模式：持有 AppPreferences() 单例引用，委托基础读写操作
class AppPreferencesExt {
  static final AppPreferencesExt _instance = AppPreferencesExt._();
  factory AppPreferencesExt() => _instance;
  AppPreferencesExt._();

  /// 委托目标（原版 AppPreferences 单例）
  AppPreferences get _base => AppPreferences();

  SharedPreferences get _prefs => _base.prefs;

  // ── 便捷读写（委托 BaseSharedPreferences）──

  String _getString(String key, [String defaultValue = '']) => _prefs.getString(key) ?? defaultValue;

  Future<bool> _setString(String key, String value) => _prefs.setString(key, value);

  int _getInt(String key, [int defaultValue = 0]) => _prefs.getInt(key) ?? defaultValue;

  Future<bool> _setInt(String key, int value) => _prefs.setInt(key, value);

  bool _getBool(String key, [bool defaultValue = false]) => _prefs.getBool(key) ?? defaultValue;

  Future<bool> _setBool(String key, bool value) => _prefs.setBool(key, value);

  int _getLong(String key, [int defaultValue = 0]) => _prefs.getInt(key) ?? defaultValue;

  Future<bool> _saveLong(String key, int value) => _prefs.setInt(key, value);

  Future<bool> _remove(String key) => _prefs.remove(key);

  // ── 补充常量 key（原版 AppPreferences.java 中未在 app_preferences.dart 定义的）──

  static const String appOldWordProcessSynced = 'app_old_word_process_synced';
  static const String appUserTestMode = 'app_usre_test_mode';
  static const String calendarPermissionHasApply = 'calendar_permission_has_apply';
  static const String currentWallpaperPre = 'current_wallpater_pre';
  static const String extensivePlaying = 'extensive_playing';
  static const String keyBgPicLookedPre = 'key_bg_pic_looked_pre';
  static const String keyClickBookCount = 'KEY_CLCIK_BOOK_COUNT';
  static const String keyClickSentenceCount = 'KEY_CLCIK_SENTENCE_COUNT';
  static const String keyCloseFloatButtonPre = 'key_close_float_button_';
  static const String keyCurVersionFirstRuntimeSuffix = 'key_first_runtime_';
  static const String keyCurVersionHasShowQtSuffix = 'key_has_show_qt_suffix_';
  static const String keyHasClickCollins = 'key_has_click_collins';
  static const String keyHasHistoryLogined = 'key_has_history_logined';
  static const String keyInstalledType = 'key_install_overlay';
  static const String keyLastErrorUrl = 'key_last_error_url';
  static const String keyLastStartAppVersionCode = 'key_last_start_app_version_code';
  static const String keyLearnCardTitleClickCount = 'key_learn_card_title_click_count';
  static const String keyListListenAdvExampleChSwitch = 'key_list_listen_adv_example_ch_switch';
  static const String keyListListenAdvWordInterpretSwitch = 'key_list_listen_adv_word_interpret_switch';
  static const String keyListListenBaseSpellSwitch = 'key_list_listen_base_spell_switch';
  static const String keyListListenHasOpened = 'key_list_listen_has_opened';
  static const String keyListListenPlayCount = 'key_list_listen_play_count';
  static const String keyListListenPlayInterval = 'key_list_listen_play_interval';
  static const String keyListListenPlayNextAuto = 'key_list_listen_play_next_auto';
  static const String keyLocalMessageUnread = 'key_loacal_message_unread';
  static const String keyNewUserAbtestMap = 'key_new_user_abtest_level_map';
  static const String keyRewardFinishFirstLearn = 'key_reward_finish_first_learn';
  static const String keyRewardFinishFirstSpell = 'key_reward_finish_first_spell';
  static const String keyRewardFinishTodayReview = 'key_reward_finish_today_review';
  static const String keyUserMessageSuffix = 'key_user_message_suffix_';
  static const String keyVersionAppLaunchCountSuffix = 'key_version_app_launch_count_suffix';
  static const String keyVersionRateOptionsSuffix = 'key_version_rate_options_';
  static const String keyVersionFirstLaunchTimeSuffix = 'key_vertion_first_launch_time_suffix';
  static const String needNewWordPeriodData = 'need_new_word_period_data';
  static const String newWordPeriodData = 'new_word_period_data';
  static const String nextWallpaperPre = 'next_wallpater_pre';
  static const String yiwenHasClicked = 'yiwen_has_clicked';

  // ── UI 主题 ──

  int getUITheme() => _getInt(AppPreferences.uiTheme, 0);
  Future<bool> setUITheme(int value) => _setInt(AppPreferences.uiTheme, value);

  // ── 所有 key 集合 ──

  Set<String> getAllKeys() => _prefs.getKeys();

  // ── 登录账号信息 ──

  String getLastLoginAccountInfo() => _getString(AppPreferences.lastLoginInfo);
  Future<bool> setLastLoginAccountInfo(String value) => _setString(AppPreferences.lastLoginInfo, value);

  // ── 历史查询 ──

  String getHistoryQueryList() => _getString(AppPreferences.historyQuery);
  Future<bool> setHistoryQueryList(String value) => _setString(AppPreferences.historyQuery, value);

  // ── 书籍/句子点击计数 ──

  int getBookClickCount() => _getInt(keyClickBookCount);
  Future<bool> setBookClickCount(int value) => _setInt(keyClickBookCount, value);

  int getSentenceClickCount() => _getInt(keyClickSentenceCount);
  Future<bool> setSentenceClickCount(int value) => _setInt(keyClickSentenceCount, value);

  // ── 用户追踪 ──

  bool getUserTrackEnabled() => _getInt(AppPreferences.keyUserTrackEnable, 1) == 1;

  // ── 版本级启动计数（动态 key：后缀拼接 appVersion）──

  int getVersionAppLaunchCount() => _getInt(keyVersionAppLaunchCountSuffix + PrefConfig.appVersion, 0);

  Future<void> increaseVersionAppLaunchCount() async {
    final count = getVersionAppLaunchCount();
    if (count < 1) {
      await _saveLong(keyVersionFirstLaunchTimeSuffix + PrefConfig.appVersion, DateTime.now().millisecondsSinceEpoch);
    }
    await _setInt(keyVersionAppLaunchCountSuffix + PrefConfig.appVersion, count + 1);
  }

  String getVersionOptionResult() => _getString(keyVersionRateOptionsSuffix + PrefConfig.appVersion);

  Future<bool> saveVersionOptionResult(String value) =>
      _setString(keyVersionRateOptionsSuffix + PrefConfig.appVersion, value);

  int getVersionAppFirstLaunchTime() => _getLong(keyVersionFirstLaunchTimeSuffix + PrefConfig.appVersion);

  // ── 用户消息（动态 key：后缀拼接 userId）──

  Future<bool> saveMessageLastReviewTime(int time) => _saveLong(keyUserMessageSuffix + PrefConfig.userId, time);

  int getMessageLastReviewTime() => _getLong(keyUserMessageSuffix + PrefConfig.userId);

  Future<bool> saveLocalMessageUnread(int count) => _setInt(keyLocalMessageUnread + PrefConfig.userId, count);

  int getLocalMessageUnread() => _getInt(keyLocalMessageUnread + PrefConfig.userId);

  bool getLocalMessageHasNew() => getLocalMessageUnread() > 0;

  // ── 覆盖安装检测 ──

  bool isOverlayInstallation() => _getInt(keyInstalledType) == 2;

  // ── 壁纸管理（动态 key：后缀拼接主题类型）──

  String getCurrentLaunchImageId(int themeType) => _getString(currentWallpaperPre + themeType.toString());

  Future<bool> setCurrentLaunchImageId(String id, int themeType) =>
      _setString(currentWallpaperPre + themeType.toString(), id);

  Future<bool> removeCurrentLaunchImageId(int themeType) => _remove(currentWallpaperPre + themeType.toString());

  String getNextLaunchImageId(int themeType) => _getString(nextWallpaperPre + themeType.toString());

  Future<bool> setNextLaunchImageId(String id, int themeType) =>
      _setString(nextWallpaperPre + themeType.toString(), id);

  Future<bool> removeNextLaunchImageId(int themeType) => _remove(nextWallpaperPre + themeType.toString());

  // ── 泛在播放 ──

  bool isExtensivePlaying() => _getBool(extensivePlaying);
  Future<bool> setExtensivePlaying(bool value) => _setBool(extensivePlaying, value);

  // ── 权限提示 ──

  bool isAppPermissionGrantShow() => _getBool(AppPreferences.appPermissionGrantShow, true);
  Future<bool> setAppPermissionGrantShow(bool value) => _setBool(AppPreferences.appPermissionGrantShow, value);

  // ── 用户规则同意 ──

  bool isUserRuleAgreed() => _getBool(AppPreferences.appUserRulesAgree, true);
  Future<bool> setUserRuleAgreed(bool value) => _setBool(AppPreferences.appUserRulesAgree, value);

  // ── 听力模式开关 ──

  bool isListListenAdvPlayWordInterpret() => _getBool(keyListListenAdvWordInterpretSwitch, true);
  Future<bool> setAdvPlayWordInterpret(bool value) => _setBool(keyListListenAdvWordInterpretSwitch, value);

  bool isListListenAdvPlaySentenceCh() => _getBool(keyListListenAdvExampleChSwitch, true);
  Future<bool> setAdvPlaySentenceCh(bool value) => _setBool(keyListListenAdvExampleChSwitch, value);

  bool isListListenBasePlayWordSpell() => _getBool(keyListListenBaseSpellSwitch);
  Future<bool> setBasePlayWordSpell(bool value) => _setBool(keyListListenBaseSpellSwitch, value);

  // ── 听力播放配置 ──

  bool isListListenHasOpened() => _getBool(keyListListenHasOpened);
  Future<bool> setListListenHasOpened(bool value) => _setBool(keyListListenHasOpened, value);

  int getListListenPlayCount() => _getInt(keyListListenPlayCount);
  Future<bool> setListListenPlayCount(int value) => _setInt(keyListListenPlayCount, value);

  int getListListenPlayInterval() => _getInt(keyListListenPlayInterval);
  Future<bool> setListListenPlayInterval(int value) => _setInt(keyListListenPlayInterval, value);

  bool isListListenPlayNextAuto() => _getBool(keyListListenPlayNextAuto);
  Future<bool> setListListenPlayNextAuto(bool value) => _setBool(keyListListenPlayNextAuto, value);

  // ── Collins 点击标记 ──

  bool isHasClickCollins() => _getBool(keyHasClickCollins);
  Future<bool> setHasClickCollins(bool value) => _setBool(keyHasClickCollins, value);

  // ── 历史登录标记 ──

  bool isHasHistoryLogined() => _getBool(keyHasHistoryLogined);
  Future<bool> setHasHistoryLogined(bool value) => _setBool(keyHasHistoryLogined, value);

  // ── 旧单词进程同步标记 ──

  bool isOldWordProcessSynced() => _getBool(appOldWordProcessSynced);
  Future<bool> setOldWordProcessSynced(bool value) => _setBool(appOldWordProcessSynced, value);

  // ── 测试模式 ──

  bool isUserTestMode() => _getBool(appUserTestMode);
  Future<bool> setUserTestMode(bool value) => _setBool(appUserTestMode, value);

  // ── 日历权限 ──

  bool isCalendarPermissionHasApply() => _getBool(calendarPermissionHasApply);
  Future<bool> setCalendarPermissionHasApply(bool value) => _setBool(calendarPermissionHasApply, value);

  // ── 最后错误 URL ──

  String getLastErrorUrl() => _getString(keyLastErrorUrl);
  Future<bool> setLastErrorUrl(String value) => _setString(keyLastErrorUrl, value);

  // ── 上次启动的版本号 ──

  int getLastStartAppVersionCode() => _getInt(keyLastStartAppVersionCode);
  Future<bool> setLastStartAppVersionCode(int value) => _setInt(keyLastStartAppVersionCode, value);

  // ── 学习卡片标题点击计数 ──

  int getLearnCardTitleClickCount() => _getInt(keyLearnCardTitleClickCount);
  Future<bool> setLearnCardTitleClickCount(int value) => _setInt(keyLearnCardTitleClickCount, value);

  // ── 浮窗按钮关闭 ──

  bool isCloseFloatButton(String suffix) => _getBool(keyCloseFloatButtonPre + suffix);
  Future<bool> setCloseFloatButton(String suffix, bool value) => _setBool(keyCloseFloatButtonPre + suffix, value);

  // ── 版本首次运行时间 ──

  bool isCurVersionFirstRuntime() => _getBool(keyCurVersionFirstRuntimeSuffix + PrefConfig.appVersion);
  Future<bool> setCurVersionFirstRuntime(bool value) =>
      _setBool(keyCurVersionFirstRuntimeSuffix + PrefConfig.appVersion, value);

  // ── 版本级 QT 展示标记 ──

  bool isCurVersionHasShowQt() => _getBool(keyCurVersionHasShowQtSuffix + PrefConfig.appVersion);
  Future<bool> setCurVersionHasShowQt(bool value) =>
      _setBool(keyCurVersionHasShowQtSuffix + PrefConfig.appVersion, value);

  // ── 奖励完成标记 ──

  bool isRewardFinishFirstLearn() => _getBool(keyRewardFinishFirstLearn);
  Future<bool> setRewardFinishFirstLearn(bool value) => _setBool(keyRewardFinishFirstLearn, value);

  bool isRewardFinishFirstSpell() => _getBool(keyRewardFinishFirstSpell);
  Future<bool> setRewardFinishFirstSpell(bool value) => _setBool(keyRewardFinishFirstSpell, value);

  bool isRewardFinishTodayReview() => _getBool(keyRewardFinishTodayReview);
  Future<bool> setRewardFinishTodayReview(bool value) => _setBool(keyRewardFinishTodayReview, value);

  // ── 依文点击标记 ──

  bool isYiwenHasClicked() => _getBool(yiwenHasClicked);
  Future<bool> setYiwenHasClicked(bool value) => _setBool(yiwenHasClicked, value);

  // ── 背景图片查看标记 ──

  bool isBgPicLooked(String suffix) => _getBool(keyBgPicLookedPre + suffix);
  Future<bool> setBgPicLooked(String suffix, bool value) => _setBool(keyBgPicLookedPre + suffix, value);

  // ── 新用户 AB 测试 ──

  String getNewUserAbtestMap() => _getString(keyNewUserAbtestMap);
  Future<bool> setNewUserAbtestMap(String value) => _setString(keyNewUserAbtestMap, value);

  // ── 新词周期数据 ──

  String getNewWordPeriodData() => _getString(newWordPeriodData);
  Future<bool> setNewWordPeriodData(String value) => _setString(newWordPeriodData, value);

  bool isNeedNewWordPeriodData() => _getBool(needNewWordPeriodData);
  Future<bool> setNeedNewWordPeriodData(bool value) => _setBool(needNewWordPeriodData, value);
}

// ──────────────────────────────────────────────
//  UserPreferences 扩展（补全缺失的 key 和方法）
// ──────────────────────────────────────────────

/// UserPreferences 扩展：原版 UserPreferences.java 中未在
/// app_preferences.dart 覆盖的常量 key 和业务方法
///
/// 采用组合模式：持有 UserPreferences() 单例引用
class UserPreferencesExt {
  static final UserPreferencesExt _instance = UserPreferencesExt._();
  factory UserPreferencesExt() => _instance;
  UserPreferencesExt._();

  /// 委托目标（原版 UserPreferences 单例）
  UserPreferences get _base => UserPreferences();

  SharedPreferences get _prefs => _base.prefs;

  // ── 便捷读写 ──

  String _getString(String key, [String defaultValue = '']) => _prefs.getString(key) ?? defaultValue;

  Future<bool> _setString(String key, String value) => _prefs.setString(key, value);

  int _getInt(String key, [int defaultValue = 0]) => _prefs.getInt(key) ?? defaultValue;

  Future<bool> _setInt(String key, int value) => _prefs.setInt(key, value);

  bool _getBool(String key, [bool defaultValue = false]) => _prefs.getBool(key) ?? defaultValue;

  Future<bool> _setBool(String key, bool value) => _prefs.setBool(key, value);

  Future<bool> _remove(String key) => _prefs.remove(key);

  // ── 补充常量 key ──

  static const String collinsExpireHasShowIntro = 'collins_expire_has_show_intro';
  static const String exampleDisplayYiwen = 'example_display_yiwen';
  static const String favSentenceLastSentenceId = 'fav_sentence_last_sentence_id';
  static const String favSentenceLastWordId = 'fav_sentence_last_word_id';
  static const String learnFirstGroupCompleteData = 'learn_first_group_complete_data';
  static const String learnFirstGroupSpellCompleteData = 'learn_first_group_spell_complete_data';
  static const String listenPosPrefix = 'listen_pos_prefix_';
  static const String lockWallpaperPre = 'lock_wallpaper_';
  static const String newWordLastClickWordId = 'new_word_last_click_word_id';
  static const String noMoreLockscreenPermissionTip = 'no_more_lockscreen_permission_tip';
  // password ('userPwd') 已移除 — 禁止明文存储密码（安全审计 H4）
  static const String settingStrategyHasArtificiallyTriggered = 'setting_strategy_has_artificallytriggered_';
  static const String synTimeLexisOld = 'synTime_lexis';
  static const String synTimeNewword = 'syn_time_newword';
  static const String synTimeWordOld = 'synTime_word';
  static const String synTimeWordProcess = 'syn_time_word_process';
  static const String userConfigPre = 'user_config_';
  static const String userInfo = 'userInfo';
  static const String weekLearnSignStatus = 'week_learn_sign_status';
  static const String wordLearnCompleteCount = 'word_learn_complete_count';

  // ── 当前活跃用户 ID（用于用户级 key 前缀）──

  String _activeUserId = '';

  /// 当前活跃用户 ID
  String get activeUserId => _activeUserId;

  /// 切换到指定用户（原版 setUser）
  ///
  /// 原版 Android 用独立 SharedPreferences 文件 "User_Preference_{userId}"。
  /// Flutter 的 SharedPreferences 是单例，用 key 前缀 "{userId}." 模拟隔离。
  void switchToUser(String userId) {
    if (userId.isEmpty) return;
    _activeUserId = userId;
  }

  /// 回退到游客模式（原版 setNoUser）
  void switchToNoUser() {
    _activeUserId = '';
  }

  /// 为用户级 key 添加当前用户前缀
  String _userKey(String key) {
    if (_activeUserId.isEmpty) return key;
    return '$_activeUserId.$key';
  }

  // ── 用户级读写（自动加用户前缀）──

  String getUserString(String key, {String defaultValue = ''}) => _prefs.getString(_userKey(key)) ?? defaultValue;

  Future<bool> setUserString(String key, String value) => _prefs.setString(_userKey(key), value);

  int getUserInt(String key, {int defaultValue = 0}) => _prefs.getInt(_userKey(key)) ?? defaultValue;

  Future<bool> setUserInt(String key, int value) => _prefs.setInt(_userKey(key), value);

  bool getUserBool(String key, {bool defaultValue = false}) => _prefs.getBool(_userKey(key)) ?? defaultValue;

  Future<bool> setUserBool(String key, bool value) => _prefs.setBool(_userKey(key), value);

  Future<bool> removeUserKey(String key) => _prefs.remove(_userKey(key));

  // ── 例句显示译文 ──

  bool isExampleDisplayYiwen() => _getBool(exampleDisplayYiwen, true);
  Future<bool> setExampleDisplayYiwen(bool value) => _setBool(exampleDisplayYiwen, value);

  // ── 词根展示 ──

  bool isShowWordRoot() => _getBool(UserPreferences.defaultShowWordroot, true);
  Future<bool> setShowWordRoot(bool value) => _setBool(UserPreferences.defaultShowWordroot, value);

  // ── 锁屏壁纸（动态 key：后缀拼接主题类型）──

  bool isLockWallpaper(int themeType) => _getBool(lockWallpaperPre + themeType.toString());
  Future<bool> setLockWallpaper(bool value, int themeType) => _setBool(lockWallpaperPre + themeType.toString(), value);

  // ── Collins 过期提示 ──

  bool isCollinsExpireHasShowIntro() => _getBool(collinsExpireHasShowIntro);
  Future<bool> setCollinsExpireHasShowIntro(bool value) => _setBool(collinsExpireHasShowIntro, value);

  // ── 收藏句子位置 ──

  int getFavSentenceLastSentenceId() => _getInt(favSentenceLastSentenceId);
  Future<bool> setFavSentenceLastSentenceId(int value) => _setInt(favSentenceLastSentenceId, value);

  int getFavSentenceLastWordId() => _getInt(favSentenceLastWordId);
  Future<bool> setFavSentenceLastWordId(int value) => _setInt(favSentenceLastWordId, value);

  // ── 生词本最后点击 ──

  int getNewWordLastClickWordId() => _getInt(newWordLastClickWordId);
  Future<bool> setNewWordLastClickWordId(int value) => _setInt(newWordLastClickWordId, value);

  // ── 学习首组完成数据 ──

  String getLearnFirstGroupCompleteData() => _getString(learnFirstGroupCompleteData);
  Future<bool> setLearnFirstGroupCompleteData(String value) => _setString(learnFirstGroupCompleteData, value);

  String getLearnFirstGroupSpellCompleteData() => _getString(learnFirstGroupSpellCompleteData);
  Future<bool> setLearnFirstGroupSpellCompleteData(String value) => _setString(learnFirstGroupSpellCompleteData, value);

  // ── 听力位置记录（动态 key）──

  int getListenPos(String suffix) => _getInt(listenPosPrefix + suffix);
  Future<bool> setListenPos(String suffix, int value) => _setInt(listenPosPrefix + suffix, value);

  // ── 锁屏权限提示 ──

  bool isNoMoreLockscreenPermissionTip() => _getBool(noMoreLockscreenPermissionTip);
  Future<bool> setNoMoreLockscreenPermissionTip(bool value) => _setBool(noMoreLockscreenPermissionTip, value);

  // ── 学习策略人工触发标记（动态 key）──

  bool isSettingStrategyHasArtificiallyTriggered(String suffix) =>
      _getBool(settingStrategyHasArtificiallyTriggered + suffix);
  Future<bool> setSettingStrategyHasArtificiallyTriggered(String suffix, bool value) =>
      _setBool(settingStrategyHasArtificiallyTriggered + suffix, value);

  // ── 用户配置（动态 key）──

  String getUserConfig(String suffix) => _getString(userConfigPre + suffix);
  Future<bool> setUserConfig(String suffix, String value) => _setString(userConfigPre + suffix, value);

  // ── 周学习签到状态 ──

  String getWeekLearnSignStatus() => _getString(weekLearnSignStatus);
  Future<bool> setWeekLearnSignStatus(String value) => _setString(weekLearnSignStatus, value);

  // ── 单词学习完成计数 ──

  int getWordLearnCompleteCount() => _getInt(wordLearnCompleteCount);
  Future<bool> setWordLearnCompleteCount(int value) => _setInt(wordLearnCompleteCount, value);

  // ── 同步时间管理（原版静态方法，迁移至 DAO 层前的过渡方法）──

  String getSynTimeLexisOld() => _getString(synTimeLexisOld, '1999-01-01 01:01:01');
  Future<bool> setSynTimeLexisOld(String value) => _setString(synTimeLexisOld, value);

  String getSynTimeWordOld() => _getString(synTimeWordOld, '1999-01-01 01:01:01');
  Future<bool> setSynTimeWordOld(String value) => _setString(synTimeWordOld, value);

  String getSynTimeWordProcess() => _getString(synTimeWordProcess, '1999-01-01 01:01:01');
  Future<bool> setSynTimeWordProcess(String value) => _setString(synTimeWordProcess, value);

  String getSynTimeNewword() => _getString(synTimeNewword, '1999-01-01 01:01:01');
  Future<bool> setSynTimeNewword(String value) => _setString(synTimeNewword, value);

  /// 迁移旧版同步时间数据（原版 migrateOldSyncTimeData）
  Future<void> migrateOldSyncTimeData() async {
    final wordProcess = _getString(synTimeWordProcess);
    if (wordProcess.isNotEmpty) {
      await _remove(synTimeWordProcess);
    }
    final newword = _getString(synTimeNewword);
    if (newword.isNotEmpty) {
      await _remove(synTimeNewword);
    }
  }

  // ── 用户信息 Bean 存取（用户级 key）──

  UserInfoBeanFull? getUserInfoBeanFull() {
    final jsonStr = getUserString(userInfo);
    if (jsonStr.isEmpty) return null;
    try {
      return UserInfoBeanFull.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveUserInfoBeanFull(UserInfoBeanFull bean) => setUserString(userInfo, jsonEncode(bean.toJson()));
}

// ──────────────────────────────────────────────
//  GuidePreference 扩展（补全缺失的 key 和方法）
// ──────────────────────────────────────────────

/// GuidePreference 扩展：原版 GuidePreference.java 中未在
/// app_preferences.dart 覆盖的常量 key 和业务方法
///
/// 采用组合模式：持有 GuidePreference() 单例引用
class GuidePreferenceExt {
  static final GuidePreferenceExt _instance = GuidePreferenceExt._();
  factory GuidePreferenceExt() => _instance;
  GuidePreferenceExt._();

  /// 委托目标（原版 GuidePreference 单例）
  GuidePreference get _base => GuidePreference();

  SharedPreferences get _prefs => _base.prefs;

  // ── 便捷读写 ──

  String _getString(String key, [String defaultValue = '']) => _prefs.getString(key) ?? defaultValue;

  Future<bool> _setString(String key, String value) => _prefs.setString(key, value);

  int _getInt(String key, [int defaultValue = 0]) => _prefs.getInt(key) ?? defaultValue;

  Future<bool> _setInt(String key, int value) => _prefs.setInt(key, value);

  bool _getBool(String key, [bool defaultValue = false]) => _prefs.getBool(key) ?? defaultValue;

  Future<bool> _setBool(String key, bool value) => _prefs.setBool(key, value);

  Future<bool> _remove(String key) => _prefs.remove(key);

  // ── 补充常量 key ──

  static const int defaultSaveCount = 10;

  static const String guideAppStartCount = 'guide_app_start_count';
  static const String guideClickFixWord = 'guide_click_fix_word';
  static const String guideClickSoundSwitch = 'guide_click_sound_switch';
  static const String guideExampleClickLookExample = 'guide_example_click_look_example';
  static const String guideExampleFromClick = 'guide_example_from_click';
  static const String guideExampleGestureLookExample = 'guide_example_gesture_look_example';
  static const String guideExampleLeftSlide = 'guide_example_left_slide';
  static const String guideExampleLongPress = 'guide_example_long_press';
  static const String guideExampleSentenceClick = 'guide_example_sentence_click';
  static const String guideFinishedLearnGroupCount = 'guide_finished_learn_group_count';
  static const String guideLearnRecordMigrated = 'guide_learn_record_migrated';
  static const String guideListWordListenSettingShowed = 'guide_list_word_listen_setting_showed';
  static const String guideRecallTipClickCount = 'guide_recall_tip_click_count';
  static const String guideRootClick = 'guide_root_click';
  static const String guideRootExpandClickCount = 'guide_root_expand_clcik_count';
  static const String guideRootSoundClickCount = 'guide_root_sound_clcik_count';
  static const String guideShareAchievementMigrated = 'guide_share_achievement_migrated';
  static const String guideShowLrSetting = 'guide_show_lrsetting';
  static const String guideSwitchFromWordrootToSentence = 'guide_switch_from_wordroot_to_sentence';
  static const String guideWordRightCount = 'guide_word_right_count';
  static const String guideWordSelectChoice = 'guide_word_select_choice';
  static const String guideWrongTipHasShow = 'guide_wrong_tip_has_show';
  static const String headsetOptionIntroduce = 'headset_option_introduce';
  static const String v3FirstLaunchTime = 'v3_first_launch_time';
  static const String v3GuideAnytimeListenHasShow = 'v3_guide_anytime_listen_has_show';
  static const String v3GuideChangeLibraryHasShow = 'v3_guide_change_library_has_show';
  static const String v3GuideClickSoundSwitch = 'v3_guide_click_sound_switch';
  static const String v3GuideExtensiveModeSelect = 'v3_guide_extensive_mode_select';
  static const String v3GuideFinishedLearnGroupCount = 'v3_guide_finished_learn_group_count';
  static const String v3GuideHasShowLearnTip = 'v3_guide_has_show_learn_tip';
  static const String v3GuideLookExampleTipHasShow = 'v3_guide_look_example_tip_has_show';
  static const String v3GuideReviewTipHasShow = 'v3_guide_review_tip_has_show';
  static const String v3GuideShouldShowDictTip = 'v3_guide_should_show_dict_tip';
  static const String v3GuideWordRightCount = 'v3_guide_word_right_count';
  static const String v3GuideWordSelectChoice = 'v3_guide_word_select_choice';
  static const String v3GuideWrongTipHasShow = 'v3_guide_wrong_tip_has_show';
  static const String v3HasShowInitGuideViewPager = 'v3_has_show_init_guide_view_pager';

  // ── 通用点击计数保存（原版 saveCLickCount，上限 10）──

  Future<void> saveClickCount(String key, int count) async {
    if (count > defaultSaveCount) return;
    await _setInt(key, count);
  }

  // ── 复习提示 ──

  bool isNeedShowRecallTips() => _getInt(guideRecallTipClickCount, 0) < 2;
  Future<void> increaseRecallTipClickCount() async {
    await saveClickCount(guideRecallTipClickCount, _getInt(guideRecallTipClickCount, 0) + 1);
  }

  // ── 例句来源提示 ──

  bool isNeedShowExampleFromTip() => _getInt(guideExampleFromClick, 0) < 1;
  Future<void> increaseExampleFromClick() async {
    await saveClickCount(guideExampleFromClick, _getInt(guideExampleFromClick, 0) + 1);
  }

  // ── 例句点击提示 ──

  bool isNeedShowClickSentTip() => _getInt(guideExampleSentenceClick, 0) < 2;
  Future<void> increaseExampleSentenceClick() async {
    await saveClickCount(guideExampleSentenceClick, _getInt(guideExampleSentenceClick, 0) + 1);
  }

  // ── 例句长按提示 ──

  bool isNeedShowExampleLongPressTip() => _getInt(guideExampleLongPress, 0) < 2;
  Future<void> increaseExampleLongPress() async {
    await saveClickCount(guideExampleLongPress, _getInt(guideExampleLongPress, 0) + 1);
  }

  // ── 例句左滑提示 ──

  bool isNeedShowLeftSlideOfExample() {
    if (isNeedShowLookExampleThroughGesture()) return false;
    return !_getBool(guideExampleLeftSlide);
  }

  Future<void> setExampleLeftSlideShown(bool value) => _setBool(guideExampleLeftSlide, value);

  // ── 手势查看例句提示 ──

  bool isNeedShowLookExampleThroughGesture() {
    return !_getBool(guideExampleGestureLookExample) &&
        _getInt(guideExampleClickLookExample) >= 30 &&
        _getInt(guideAppStartCount) >= 10;
  }

  Future<void> setExampleGestureLookExampleShown(bool value) => _setBool(guideExampleGestureLookExample, value);

  int getExampleClickLookExampleCount() => _getInt(guideExampleClickLookExample);
  Future<void> increaseExampleClickLookExample() async {
    await saveClickCount(guideExampleClickLookExample, _getInt(guideExampleClickLookExample) + 1);
  }

  int getAppStartCount() => _getInt(guideAppStartCount);
  Future<void> increaseAppStartCount() async {
    await _setInt(guideAppStartCount, _getInt(guideAppStartCount) + 1);
  }

  // ── 词根点击提示 ──

  bool isNeedShowRootClickTip() => _getInt(guideRootClick, 0) < 2;
  Future<void> increaseRootClick() async {
    await saveClickCount(guideRootClick, _getInt(guideRootClick, 0) + 1);
  }

  // ── 词根发音点击提示 ──

  bool isNeedShowRootSoundClickTip() {
    return _getInt(guideRootExpandClickCount) >= 5 && _getInt(guideRootSoundClickCount, 0) < 2;
  }

  Future<void> increaseRootSoundClickCount() async {
    if (_getInt(guideRootExpandClickCount) >= 5) {
      await saveClickCount(guideRootSoundClickCount, _getInt(guideRootSoundClickCount) + 1);
    }
  }

  Future<void> increaseRootExpandClickCount() async {
    await saveClickCount(guideRootExpandClickCount, _getInt(guideRootExpandClickCount) + 1);
  }

  // ── LR 设置提示 ──

  bool isNeedShowLRSettingTip() {
    if (AppPreferencesExt().isOverlayInstallation() && _getInt(guideSwitchFromWordrootToSentence) >= 2) {
      return _getBool(guideShowLrSetting, true);
    }
    return false;
  }

  Future<void> setNeedShowLRSettingTip(bool value) => _setBool(guideShowLrSetting, value);

  // ── 词根→例句切换计数 ──

  int getSwitchFromWordRoot2SentenceCount() => _getInt(guideSwitchFromWordrootToSentence);

  Future<void> increaseSwitchFromWordRoot2Sentence() async {
    final count = _getInt(guideSwitchFromWordrootToSentence);
    if (count > 3) return;
    await _setInt(guideSwitchFromWordrootToSentence, count + 1);
  }

  bool isNeedIncreaseSwitchFromWordRoot2Sentence() => _getInt(guideSwitchFromWordrootToSentence) < 3;

  // ── 学习引导重置（原版 resetLearnGuide）──

  Future<void> resetLearnGuide() async {
    await _remove(guideRecallTipClickCount);
    await _remove(guideExampleFromClick);
    await _remove(guideExampleSentenceClick);
    await _remove(guideExampleLongPress);
    await _remove(guideRootClick);
    await _remove(guideRootSoundClickCount);
    await _remove(guideRootExpandClickCount);
    await _remove(guideExampleLeftSlide);
    await _remove(guideExampleGestureLookExample);
    await _remove(guideExampleClickLookExample);
    await _remove(guideWordSelectChoice);
    await _remove(v3GuideWordRightCount);
    await _remove(v3GuideWrongTipHasShow);
    await _remove(v3GuideFinishedLearnGroupCount);
    await _remove(v3GuideClickSoundSwitch);
    await _remove(guideClickFixWord);
    await _remove(guideShowLrSetting);
    await _remove(guideSwitchFromWordrootToSentence);
  }

  // ── v3 引导状态 ──

  bool isV3FirstLaunch() => _getBool(v3FirstLaunchTime);
  Future<void> setV3FirstLaunch(bool value) => _setBool(v3FirstLaunchTime, value);

  bool isV3GuideAnytimeListenHasShow() => _getBool(v3GuideAnytimeListenHasShow);
  Future<void> setV3GuideAnytimeListenHasShow(bool value) => _setBool(v3GuideAnytimeListenHasShow, value);

  bool isV3GuideChangeLibraryHasShow() => _getBool(v3GuideChangeLibraryHasShow);
  Future<void> setV3GuideChangeLibraryHasShow(bool value) => _setBool(v3GuideChangeLibraryHasShow, value);

  bool isV3GuideHasShowLearnTip() => _getBool(v3GuideHasShowLearnTip);
  Future<void> setV3GuideHasShowLearnTip(bool value) => _setBool(v3GuideHasShowLearnTip, value);

  bool isV3GuideLookExampleTipHasShow() => _getBool(v3GuideLookExampleTipHasShow);
  Future<void> setV3GuideLookExampleTipHasShow(bool value) => _setBool(v3GuideLookExampleTipHasShow, value);

  bool isV3GuideReviewTipHasShow() => _getBool(v3GuideReviewTipHasShow);
  Future<void> setV3GuideReviewTipHasShow(bool value) => _setBool(v3GuideReviewTipHasShow, value);

  bool isV3GuideShouldShowDictTip() => _getBool(v3GuideShouldShowDictTip, true);
  Future<void> setV3GuideShouldShowDictTip(bool value) => _setBool(v3GuideShouldShowDictTip, value);

  bool isV3GuideExtensiveModeSelect() => _getBool(v3GuideExtensiveModeSelect);
  Future<void> setV3GuideExtensiveModeSelect(bool value) => _setBool(v3GuideExtensiveModeSelect, value);

  bool isV3GuideWrongTipHasShow() => _getBool(v3GuideWrongTipHasShow);
  Future<void> setV3GuideWrongTipHasShow(bool value) => _setBool(v3GuideWrongTipHasShow, value);

  bool isV3HasShowInitGuideViewPager() => _getBool(v3HasShowInitGuideViewPager);
  Future<void> setV3HasShowInitGuideViewPager(bool value) => _setBool(v3HasShowInitGuideViewPager, value);

  int getV3GuideWordRightCount() => _getInt(v3GuideWordRightCount);
  Future<void> setV3GuideWordRightCount(int value) => _setInt(v3GuideWordRightCount, value);

  int getV3GuideFinishedLearnGroupCount() => _getInt(v3GuideFinishedLearnGroupCount);
  Future<void> setV3GuideFinishedLearnGroupCount(int value) => _setInt(v3GuideFinishedLearnGroupCount, value);

  String getV3GuideWordSelectChoice() => _getString(v3GuideWordSelectChoice);
  Future<void> setV3GuideWordSelectChoice(String value) => _setString(v3GuideWordSelectChoice, value);

  // ── 引导相关开关 ──

  bool isGuideClickSoundSwitch() => _getBool(guideClickSoundSwitch);
  Future<void> setGuideClickSoundSwitch(bool value) => _setBool(guideClickSoundSwitch, value);

  bool isGuideClickFixWord() => _getBool(guideClickFixWord);
  Future<void> setGuideClickFixWord(bool value) => _setBool(guideClickFixWord, value);

  bool isGuideLearnRecordMigrated() => _getBool(guideLearnRecordMigrated);
  Future<void> setGuideLearnRecordMigrated(bool value) => _setBool(guideLearnRecordMigrated, value);

  bool isGuideShareAchievementMigrated() => _getBool(guideShareAchievementMigrated);
  Future<void> setGuideShareAchievementMigrated(bool value) => _setBool(guideShareAchievementMigrated, value);

  bool isGuideListWordListenSettingShowed() => _getBool(guideListWordListenSettingShowed);
  Future<void> setGuideListWordListenSettingShowed(bool value) => _setBool(guideListWordListenSettingShowed, value);

  bool isHeadsetOptionIntroduce() => _getBool(headsetOptionIntroduce);
  Future<void> setHeadsetOptionIntroduce(bool value) => _setBool(headsetOptionIntroduce, value);
}

// ──────────────────────────────────────────────
//  AuthDataPreferences（翻译自 AuthDataPreferences.java）
// ──────────────────────────────────────────────

/// 第三方授权数据存储（原版 AuthDataPreferences.java，key = "auth_data"）
class AuthDataPreferences extends BaseSharedPreferences {
  static final AuthDataPreferences _instance = AuthDataPreferences._();
  factory AuthDataPreferences() => _instance;
  AuthDataPreferences._();

  // 后缀常量（原版实例字段）
  static const String _uidSuffix = '_uid';
  static const String _atSuffix = '_at';
  static const String _rtSuffix = '_rt';
  static const String _eiSuffix = '_ei';
  static const String _currentAuthPlatform = 'current_auth_platform';
  static const String _keyPlatforms = 'platforms';

  @override
  Future<void> init() async {
    await super.init();
  }

  // ── 平台集合管理 ──

  Set<String> getPlatforms() {
    return prefs.getStringList(_keyPlatforms)?.toSet() ?? <String>{};
  }

  Future<void> addAuthPlatform(String platform) async {
    final platforms = getPlatforms();
    platforms.add(platform);
    await prefs.setStringList(_keyPlatforms, platforms.toList());
  }

  Future<void> deleteAuthPlatform(String platform) async {
    final platforms = getPlatforms();
    platforms.remove(platform);
    await prefs.setStringList(_keyPlatforms, platforms.toList());
  }

  Set<String> getAuthPlatforms() => getPlatforms();

  // ── 当前授权平台 ──

  Future<void> setCurrentAuthPlatform(String platform) async {
    await setString(_currentAuthPlatform, platform);
    await addAuthPlatform(platform);
  }

  String getCurrentAuthPlatform() => getString(_currentAuthPlatform);

  Future<void> clearCurrentAuthPlatform() => remove(_currentAuthPlatform);

  // ── 平台级授权数据（动态 key：platform + 后缀）──

  Future<void> setUserId(String platform, String uid) => setString(platform + _uidSuffix, uid);

  String getUserId(String platform) => getString(platform + _uidSuffix);

  Future<void> setAccessToken(String platform, String token) => setString(platform + _atSuffix, token);

  String getAccessToken(String platform) => getString(platform + _atSuffix);

  Future<void> setRefreshToken(String platform, String token) => setString(platform + _rtSuffix, token);

  String getRefreshToken(String platform) => getString(platform + _rtSuffix);

  Future<void> setExpireIn(String platform, String expireIn) => setString(platform + _eiSuffix, expireIn);

  String getExpireIn(String platform) => getString(platform + _eiSuffix);

  /// 清除指定平台的所有授权数据（原版 clearAuthData）
  Future<void> clearAuthData(String platform) async {
    await remove(platform + _uidSuffix);
    await remove(platform + _atSuffix);
    await remove(platform + _rtSuffix);
    await remove(platform + _eiSuffix);
  }
}
