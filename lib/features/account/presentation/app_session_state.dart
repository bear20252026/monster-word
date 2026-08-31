import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/auth/app_session_controller.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';

/// 应用账号与首次引导的会话状态。
///
/// 该状态保留当前应用已有的本地登录占位语义：凭据校验由页面负责，通过后标记为
/// 已登录。真正的账号认证接入时应替换这里的登录实现，而不再向学习状态添加账号字段。
class AppSessionState extends ChangeNotifier implements AppSessionController {
  static const String _keyIsLoggedIn = 'session_is_logged_in';
  static const String _keyInitGuide = 'session_init_guide_shown';

  bool _isLoggedIn = false;
  bool _hasShownInitGuide = false;

  @override
  bool get isLoggedIn => _isLoggedIn;
  bool get hasShownInitGuide => _hasShownInitGuide;

  /// 构造时从 SharedPreferences 恢复登录态。
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    // 引导页展示标记必须持久化，否则每次重启都强制重看引导
    _hasShownInitGuide = prefs.getBool(_keyInitGuide) ?? false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoggedIn = true;
    await _persist();
    notifyListeners();
    return true;
  }

  Future<bool> phoneLogin(String phone, String code) async {
    _isLoggedIn = true;
    await _persist();
    notifyListeners();
    return true;
  }

  @override
  void logout() {
    _isLoggedIn = false;
    _clearPersist();
    // 安全审计 S2：登出时清除凭证（安全存储中的 token/secret + 用户信息缓存）。
    // 清理失败不阻断登出流程（测试环境/插件异常时静默）。
    SecureTokenStorage().clearAll().catchError((_) {});
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('monster_word_user_info');
      prefs.remove('user_token');
    });
    notifyListeners();
  }

  Future<void> setHasShownInitGuide(bool value) async {
    _hasShownInitGuide = value;
    // 持久化：否则重启后 hasShownInitGuide 回到 false，引导页反复出现
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyInitGuide, value);
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  void _clearPersist() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_keyIsLoggedIn);
      prefs.remove(_keyInitGuide);
    });
  }
}
