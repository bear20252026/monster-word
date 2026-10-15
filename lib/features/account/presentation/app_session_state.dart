import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:word_app/core/application/presentation_prefs.dart';
import 'package:word_app/core/auth/app_session_controller.dart';
import 'package:word_app/core/application/session_security.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/account/application/auth_session_store.dart';

/// 应用账号与首次引导的会话状态。
///
/// 该状态保留当前应用已有的本地登录占位语义：凭据校验由页面负责，通过后标记为
/// 已登录。真正的账号认证接入时应替换这里的登录实现，而不再向学习状态添加账号字段。
///
/// 审计 I8：偏好读写统一经 [PresentationPrefs] 端口（R-prefs：presentation
/// 不得直连 SharedPreferences / infrastructure）。
class AppSessionState extends ChangeNotifier implements AppSessionController {
  /// 经装配点注入（facade_direct_ctor_guard：非装配文件禁止直建门面）。
  ///
  /// [sessionStore] 可空：本机模式（未注入 AUTH_BASE_URL）下没有服务端会话可清，
  /// 测试里也常只关心本机语义。
  AppSessionState({required this.prefs, this.sessionStore});

  final PresentationPrefs prefs;
  final AuthSessionStore? sessionStore;

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

  /// 登出（MW-63：原子化——durable 清理完成后才改内存态并通知）。
  ///
  /// 原实现 void + fire-and-forget：内存立即 false 而持久化清理在途，
  /// 此刻新建 AppSessionState 调 restore() 可能读到旧的 session 标记
  /// 「刚退出又被恢复」。现在：await 持久化清理完成 → 再置内存态。
  /// 清理失败（磁盘异常）同样继续置 false——登出方向宁可少留态。
  @override
  Future<void> logout() async {
    await prefs.clearSessionData();
    clearSessionSecrets();
    // 清服务端会话（2026-10-15 审计 R3-A01）：
    // 旧实现只清 prefs 与旧 token/secret，`AuthSessionStore.clear()` 在全库**零调用**
    // ⇒ access/refresh token 永久残留在安全存储里（服务端 30 天有效、客户端从不吊销）；
    // 更直接的后果是遥测的 SessionUsageStatsIdentity 仍从该 blob 读 userId，
    // 登出后产生的上报**继续挂在已登出账号名下**，管理端「按人看」的数据被污染。
    // 清理失败必须上报（否则是静默残留），但**不能阻断登出** —— 登出方向宁可少留态。
    try {
      await sessionStore?.clear();
    } catch (e, s) {
      reportSwallowedError('登出时清除服务端会话失败（token 可能仍残留在安全存储）', e, s);
    }
    _isLoggedIn = false;
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
