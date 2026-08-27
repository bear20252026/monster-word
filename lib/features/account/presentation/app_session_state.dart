import 'package:flutter/foundation.dart';

/// 应用账号与首次引导的会话状态。
///
/// 该状态保留当前应用已有的本地登录占位语义：凭据校验由页面负责，通过后标记为
/// 已登录。真正的账号认证接入时应替换这里的登录实现，而不再向学习状态添加账号字段。
class AppSessionState extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _hasShownInitGuide = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get hasShownInitGuide => _hasShownInitGuide;

  Future<bool> login(String username, String password) async {
    _isLoggedIn = true;
    notifyListeners();
    return true;
  }

  Future<bool> phoneLogin(String phone, String code) async {
    _isLoggedIn = true;
    notifyListeners();
    return true;
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<void> setHasShownInitGuide(bool value) async {
    _hasShownInitGuide = value;
    notifyListeners();
  }
}
