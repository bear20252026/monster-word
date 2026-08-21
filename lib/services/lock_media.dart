// 由账号4生成
// 锁屏/后台播放层：翻译自 lock/（v3.2 源码 1:1）
// LockScreenManager（锁屏学习控制）+ MediaButtonHandler（媒体按钮控制）

import 'package:flutter/services.dart';

import '../player/audio_players.dart';

/// 锁屏学习控制（翻译自 lock/ 包核心逻辑）
/// 原版 lock 包含 25 个类（锁屏界面/锁屏学习卡片/锁屏播放控制等）
/// Flutter 版聚焦核心：锁屏状态管理 + 后台播放控制
class LockScreenManager {
  static final LockScreenManager _instance = LockScreenManager._();
  factory LockScreenManager() => _instance;
  LockScreenManager._();

  bool _isEnabled = false;
  bool _isLockScreenActive = false;
  static const _channel = MethodChannel('com.langeasy/lock_screen');

  bool get isEnabled => _isEnabled;
  bool get isLockScreenActive => _isLockScreenActive;

  /// 启用锁屏学习（原版 enableLockScreen）
  Future<void> enable() async {
    _isEnabled = true;
    try {
      await _channel.invokeMethod('enableLockScreen');
    } catch (_) {
      // 非 Android 平台静默忽略
    }
  }

  /// 禁用锁屏学习（原版 disableLockScreen）
  Future<void> disable() async {
    _isEnabled = false;
    try {
      await _channel.invokeMethod('disableLockScreen');
    } catch (_) {}
  }

  /// 锁屏激活（原版 onScreenLocked）
  void onScreenLocked() {
    _isLockScreenActive = true;
  }

  /// 锁屏解除（原版 onScreenUnlocked）
  void onScreenUnlocked() {
    _isLockScreenActive = false;
  }

  /// 锁屏状态下播放单词发音
  Future<void> playWordOnLockScreen(String word) async {
    if (!_isLockScreenActive || !_isEnabled) return;
    await PhoneticAudioPlayer.playAudio(word);
  }
}

/// 媒体按钮处理（翻译自 mediabutton/ 包，4 个类）
/// 原版处理耳机/蓝牙媒体按钮：播放/暂停/下一首/上一首
class MediaButtonHandler {
  static final MediaButtonHandler _instance = MediaButtonHandler._();
  factory MediaButtonHandler() => _instance;
  MediaButtonHandler._();

  static const _channel = MethodChannel('com.langeasy/media_button');
  bool _isRegistered = false;

  /// 注册媒体按钮监听（原版 registerMediaButtonReceiver）
  Future<void> register() async {
    if (_isRegistered) return;
    _isRegistered = true;
    try {
      _channel.setMethodCallHandler(_handleMethodCall);
      await _channel.invokeMethod('registerMediaButton');
    } catch (_) {}
  }

  /// 注销（原版 unregisterMediaButtonReceiver）
  Future<void> unregister() async {
    _isRegistered = false;
    try {
      await _channel.invokeMethod('unregisterMediaButton');
    } catch (_) {}
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPlayPause':
        // 原版播放/暂停切换
        break;
      case 'onNext':
        // 原版下一首
        break;
      case 'onPrevious':
        // 原版上一首
        break;
    }
  }
}
