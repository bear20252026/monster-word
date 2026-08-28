// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 本地存储层：翻译自 sharepreference/（v3.2 源码 1:1）
// AppPreferences（应用配置）+ UserPreferences（用户配置）+ GuidePreference（引导）

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 基础 SharedPreferences 封装（原版 BaseSharedPreferences）
abstract class BaseSharedPreferences {
  SharedPreferences? _prefs;

  SharedPreferences get prefs {
    if (_prefs == null) throw StateError('SharedPreferences 未初始化');
    return _prefs!;
  }

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
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

  static const _keyToken = 'user_token';
  static const _keySecret = 'user_secret';

  /// 读取 token（安全存储 → 回退 SharedPreferences → 空字符串）
  Future<String> getToken() async {
    var value = await _storage.read(key: _keyToken);
    if (value != null && value.isNotEmpty) return value;
    // 回退：从 SharedPreferences 读取旧值并迁移
    final prefs = AppPreferences();
    value = prefs.getString(_keyToken);
    if (value.isNotEmpty) {
      await _storage.write(key: _keyToken, value: value);
      await prefs.remove(_keyToken); // 清除明文
    }
    return value;
  }

  /// 写入 token（安全存储）
  Future<void> setToken(String value) async {
    await _storage.write(key: _keyToken, value: value);
  }

  /// 读取 secret（安全存储 → 回退 SharedPreferences → 空字符串）
  Future<String> getSecret() async {
    var value = await _storage.read(key: _keySecret);
    if (value != null && value.isNotEmpty) return value;
    // 回退：从 SharedPreferences 读取旧值并迁移
    final prefs = AppPreferences();
    value = prefs.getString(_keySecret);
    if (value.isNotEmpty) {
      await _storage.write(key: _keySecret, value: value);
      await prefs.remove(_keySecret); // 清除明文
    }
    return value;
  }

  /// 写入 secret（安全存储）
  Future<void> setSecret(String value) async {
    await _storage.write(key: _keySecret, value: value);
  }

  /// 清除所有安全存储的凭证
  Future<void> clearAll() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keySecret);
  }
}

/// 应用配置（翻译自 AppPreferences.java，key = "sysData"）
class AppPreferences extends BaseSharedPreferences {
  static final AppPreferences _instance = AppPreferences._();
  factory AppPreferences() => _instance;
  AppPreferences._();

  // === 常量 key（原版 1:1）===
  static const String appConfig = 'app_config_list';
  static const String appLastRunTime = 'key_appRunLastTime';
  static const String appNeedMigrateToV3 = 'app_need_migrate_to_v3';
  static const String userToken = 'user_token';
  static const String userSecret = 'user_secret';
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

  /// 初始化（原版 getInstance 延迟初始化）
  @override
  Future<void> init() async {
    await super.init();
  }

  /// 词书分组列表
  String getBookGroupList() => getString(bookGroupList);
  Future<bool> setBookGroupList(String value) => setString(bookGroupList, value);

  /// 用户 token
  /// ⚠️ 已废弃：请使用 SecureTokenStorage().getToken() 异步版本
  @Deprecated('Use SecureTokenStorage().getToken() instead')
  String getUserToken() => getString(userToken);

  /// 用户 secret
  /// ⚠️ 已废弃：请使用 SecureTokenStorage().getSecret() 异步版本
  @Deprecated('Use SecureTokenStorage().getSecret() instead')
  String getUserSecret() => getString(userSecret);

  /// 用户 ID
  String getUserId() => getString(userId);
  Future<bool> setUserId(String value) => setString(userId, value);

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

/// 用户配置（翻译自 UserPreferences.java，key = "userData"）
class UserPreferences extends BaseSharedPreferences {
  static final UserPreferences _instance = UserPreferences._();
  factory UserPreferences() => _instance;
  UserPreferences._();

  // === 常量 key（原版 1:1）===
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

  @override
  Future<void> init() async {
    await super.init();
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

/// 引导偏好（翻译自 GuidePreference.java）
class GuidePreference extends BaseSharedPreferences {
  static final GuidePreference _instance = GuidePreference._();
  factory GuidePreference() => _instance;
  GuidePreference._();

  static const String guideLearn = 'guide_learn';
  static const String guideReview = 'guide_review';
  static const String guideMain = 'guide_main';
  static const String guideSpell = 'guide_spell';

  @override
  Future<void> init() async {
    await super.init();
  }

  bool isGuideLearnShown() => getBool(guideLearn);
  Future<bool> setGuideLearnShown(bool v) => setBool(guideLearn, v);

  bool isGuideReviewShown() => getBool(guideReview);
  Future<bool> setGuideReviewShown(bool v) => setBool(guideReview, v);

  bool isGuideMainShown() => getBool(guideMain);
  Future<bool> setGuideMainShown(bool v) => setBool(guideMain, v);

  bool isGuideSpellShown() => getBool(guideSpell);
  Future<bool> setGuideSpellShown(bool v) => setBool(guideSpell, v);
}

/// 用户信息 Bean（翻译自 UserInfoBean.java）
class UserInfoBean {
  int userId;
  String nickname;
  String avatar;
  String phone;
  String token;
  String secret;
  String displayId; // 用户自定义 ID（可自由设定）
  String wechatName; // 微信名

  UserInfoBean({
    this.userId = 0,
    this.nickname = '',
    this.avatar = '',
    this.phone = '',
    this.token = '',
    this.secret = '',
    this.displayId = '',
    this.wechatName = '',
  });

  factory UserInfoBean.fromJson(Map<String, dynamic> json) => UserInfoBean(
    userId: (json['userId'] as num?)?.toInt() ?? 0,
    nickname: json['nickname'] ?? '',
    avatar: json['avatar'] ?? '',
    phone: json['phone'] ?? '',
    token: json['token'] ?? '',
    secret: json['secret'] ?? '',
    displayId: json['displayId'] ?? '',
    wechatName: json['wechatName'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'nickname': nickname,
    'avatar': avatar,
    'phone': phone,
    'token': token,
    'secret': secret,
    'displayId': displayId,
    'wechatName': wechatName,
  };
}

// ── 用户信息存取 ──

extension UserInfoPrefs on AppPreferences {
  /// 同步获取用户信息（返回缓存，可能为空）
  UserInfoBean getUserInfoSync() {
    final jsonStr = getString(_userInfoKey);
    if (jsonStr.isEmpty) return UserInfoBean();
    try {
      return UserInfoBean.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return UserInfoBean();
    }
  }

  /// 获取用户信息
  Future<UserInfoBean> getUserInfo() async {
    final jsonStr = getString(_userInfoKey);
    if (jsonStr.isEmpty) return UserInfoBean();
    try {
      return UserInfoBean.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return UserInfoBean();
    }
  }

  /// 保存用户信息
  Future<bool> setUserInfo(UserInfoBean bean) => setString(_userInfoKey, jsonEncode(bean.toJson()));
}

const String _userInfoKey = 'monster_word_user_info';
