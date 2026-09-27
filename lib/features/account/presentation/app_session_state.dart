import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:word_app/core/application/presentation_prefs.dart';
import 'package:word_app/core/auth/app_session_controller.dart';
import 'package:word_app/core/application/session_security.dart';

/// 应用账号与首次引导的会话状态。
///
/// 该状态保留当前应用已有的本地登录占位语义：凭据校验由页面负责，通过后标记为
/// 已登录。真正的账号认证接入时应替换这里的登录实现，而不再向学习状态添加账号字段。
///
/// 审计 I8：偏好读写统一经 [PresentationPrefs] 端口（R-prefs：presentation
/// 不得直连 SharedPreferences / infrastructure）。
class AppSessionState extends ChangeNotifier implements AppSessionController {
  /// 经装配点注入（facade_direct_ctor_guard：非装配文件禁止直建门面）。
  AppSessionState({required this.prefs});

  final PresentationPrefs prefs;

  bool _isLoggedIn = false;
  bool _hasShownInitGuide = false;

  @override
  bool get isLoggedIn => _isLoggedIn;
  bool get hasShownInitGuide => _hasShownInitGuide;

  /// 构造时从偏好恢复登录态。
  Future<void> restore() async {
    await prefs.ensureReady();
    _isLoggedIn = prefs.getSessionLoggedIn();
    // 引导页展示标记必须持久化，否则每次重启都强制重看引导
    _hasShownInitGuide = prefs.getInitGuideShown();
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    await prefs.ensureReady();
    _isLoggedIn = true;
    await prefs.markSessionLoggedIn();
    notifyListeners();
    return true;
  }

  Future<bool> phoneLogin(String phone, String code) async {
    await prefs.ensureReady();
    _isLoggedIn = true;
    await prefs.markSessionLoggedIn();
    notifyListeners();
    return true;
  }

  @override
  void logout() {
    _isLoggedIn = false;
    // 安全审计 S2 + 审计 P2-5/I8：登出对称清理——会话标记、用户信息缓存、
    // 旧版明文 user_secret 残留、安全存储凭证，全部经端口一次性清理
    // （内部失败上报不阻断登出）。
    unawaited(prefs.clearSessionData());
    clearSessionSecrets();
    notifyListeners();
  }

  Future<void> setHasShownInitGuide(bool value) async {
    await prefs.ensureReady();
    _hasShownInitGuide = value;
    // 持久化：否则重启后 hasShownInitGuide 回到 false，引导页反复出现
    await prefs.setInitGuideShown(value);
    notifyListeners();
  }
}
