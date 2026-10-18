import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// 桌面宠物窗口开关（Windows）。
///
/// 宠物住在**独立的顶层窗口**里（`windows/runner/pet_host.cpp`），所以这里的
/// 每个方法都只是让原生开/关那个窗口，不涉及任何 Dart 侧状态 —— 状态在原生。
///
/// 非 Windows 平台一律返回 false，不碰通道（Android 上没有这个概念）。
class PetWindowService {
  const PetWindowService({bool? supported}) : _supportedOverride = supported;

  static const MethodChannel channel = MethodChannel('monster_word/pet_window');

  /// 测试注入：CI 跑在 Linux 上，`Platform.isWindows` 恒 false。
  final bool? _supportedOverride;

  bool get isSupported => _supportedOverride ?? Platform.isWindows;

  /// 开 / 关。返回操作后是否可见。
  ///
  /// [days] = 累计签到天数：宠物窗口跑在**另一个 engine** 上，读不到主应用状态，
  /// 只能靠启动参数带过去（决定形态与肚皮）。null = 不知道，宠物用默认奶泡态。
  Future<bool> toggle({int? days}) async {
    if (!isSupported) return false;
    final visible = await channel.invokeMethod<bool>('toggle', days == null ? null : <int>[days]);
    return visible ?? false;
  }

  /// 当前是否已开着（页面初始化时对齐 UI 用）。
  Future<bool> isVisible() async {
    if (!isSupported) return false;
    final visible = await channel.invokeMethod<bool>('isVisible');
    return visible ?? false;
  }
}
