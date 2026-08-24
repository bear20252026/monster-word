// 由 Claude 团队生成 | Monster Word App

// 翻译自 util/ScreenUtils.dart
// 屏幕工具 — 支持窗口变化/旋转自动更新

import 'package:flutter/widgets.dart';

/// 屏幕工具（翻译自 ScreenUtils.dart，使用 Flutter MediaQuery）
///
/// 改进：实现 [WidgetsBindingObserver]，在窗口尺寸变化（旋转/分屏）时
/// 自动更新缓存值。需在应用根部调用 [ScreenUtils.init] 注册监听。
///
/// 推荐优先使用 `context.responsive`（来自 responsive.dart），
/// 它通过 `MediaQuery.sizeOf(context)` 实时读取，无需缓存。
class ScreenUtils with WidgetsBindingObserver {
  static final ScreenUtils _instance = ScreenUtils._();
  factory ScreenUtils() => _instance;
  ScreenUtils._();

  static double _screenW = 0;
  static double _screenH = 0;
  static double _statusBarHeight = 0;
  static double _devicePixelRatio = 1.0;
  static bool _initialized = false;
  static BuildContext? _context;

  /// 初始化（在 MaterialApp builder 中调用）
  ///
  /// 注册 WidgetsBindingObserver 监听窗口变化，
  /// 当用户旋转屏幕或调整窗口大小时自动更新缓存。
  static void init(BuildContext context) {
    _context = context;
    _updateFromContext(context);

    if (!_initialized) {
      WidgetsBinding.instance.addObserver(_instance);
      _initialized = true;
    }
  }

  /// 从 MediaQuery 更新缓存值
  static void _updateFromContext(BuildContext context) {
    final mq = MediaQuery.of(context);
    _screenW = mq.size.width;
    _screenH = mq.size.height;
    _statusBarHeight = mq.padding.top;
    _devicePixelRatio = mq.devicePixelRatio;
  }

  /// 窗口尺寸变化时自动更新缓存
  ///
  /// 当用户旋转屏幕、进入/退出分屏模式、或调整窗口大小时触发。
  /// 需要通过 [_context] 重新读取 MediaQuery 数据。
  @override
  void didChangeMetrics() {
    if (_context != null && _context!.mounted) {
      // 使用 addPostFrameCallback 确保 MediaQuery 已更新
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_context != null && _context!.mounted) {
          _updateFromContext(_context!);
        }
      });
    }
  }

  /// 注销监听（应用销毁时调用）
  static void dispose() {
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(_instance);
      _initialized = false;
      _context = null;
    }
  }

  // ---------------------------------------------------------------------------
  // 属性访问器
  // ---------------------------------------------------------------------------

  /// 屏幕宽度（逻辑像素）
  static double get screenW => _screenW;

  /// 屏幕高度（逻辑像素）
  static double get screenH => _screenH;

  /// 状态栏高度
  static double get statusBarHeight => _statusBarHeight;

  /// 设备像素比
  static double get devicePixelRatio => _devicePixelRatio;

  /// 屏幕宽度（物理像素）
  static double get realWidth => _screenW * _devicePixelRatio;

  /// 屏幕高度（物理像素）
  static double get realHeight => _screenH * _devicePixelRatio;

  /// 是否横屏
  static bool get isLandscape => _screenW > _screenH;

  /// 是否竖屏
  static bool get isPortrait => _screenH >= _screenW;

  // ---------------------------------------------------------------------------
  // 工具方法
  // ---------------------------------------------------------------------------

  /// dp 转 px
  static double dp2px(double dp) => dp * _devicePixelRatio;

  /// px 转 dp
  static double px2dp(double px) => px / _devicePixelRatio;
}
