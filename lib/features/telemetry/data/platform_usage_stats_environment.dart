// 上报信封所需的运行环境信息。
//
// 设备标识的取舍（**这是本功能最关键的隐私决定**）：
//   deviceId 是**本地随机生成**的，不是 IMEI/Android ID/广告标识/序列号，也不与
//   账号 user_id 绑定。用途只有一个：在服务端把同一台设备的多次上报归并成一条
//   时间线、算日活去重。
//   为什么不用系统提供的设备标识：那些是跨应用可关联的稳定标识，一旦上报就
//   等于把「这台设备装了什么、用了多久」和别处的记录挂上了钩。随机 UUID 达到
//   同样的统计目的，代价小得多。
//   为什么不绑 user_id：本功能的目的是「使用时长 + 基本情况」，不需要知道是谁。
//   不绑 ⇒ 这批数据不可识别到个人，合规压力最小。日后若要按人看，必须同步改披露。

import 'dart:io';
import 'dart:math';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/features/telemetry/application/usage_stats_ports.dart';

class PlatformUsageStatsEnvironment implements UsageStatsEnvironment {
  PlatformUsageStatsEnvironment({SharedPreferences? prefs}) : _injected = prefs;

  static const String _deviceIdKey = 'usage_stats_device_id_v1';

  final SharedPreferences? _injected;
  String? _cachedDeviceId;
  PackageInfo? _cachedInfo;

  Future<SharedPreferences> _prefs() async => _injected ?? await SharedPreferences.getInstance();

  @override
  Future<String> deviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    try {
      final prefs = await _prefs();
      final existing = prefs.getString(_deviceIdKey);
      if (existing != null && existing.isNotEmpty) {
        _cachedDeviceId = existing;
        return existing;
      }
      final generated = _randomId();
      await prefs.setString(_deviceIdKey, generated);
      _cachedDeviceId = generated;
      return generated;
    } catch (_) {
      // 存不下就退回进程内的一次性 ID：上报仍能去重到「本次运行」，
      // 不因为偏好存储故障把整条上报链掐掉。
      return _cachedDeviceId ??= _randomId();
    }
  }

  /// 128 bit 随机十六进制。用 Random.secure()：普通 Random 在多台设备上
  /// 有碰撞风险（种子来自时间），一旦碰撞会把两台设备的数据混成一条。
  static String _randomId() {
    final rnd = Random.secure();
    return List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<PackageInfo> _info() async => _cachedInfo ??= await PackageInfo.fromPlatform();

  @override
  Future<String> appVersion() async {
    try {
      return (await _info()).version;
    } catch (_) {
      return '';
    }
  }

  @override
  Future<int> appBuild() async {
    try {
      return int.tryParse((await _info()).buildNumber) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  String platform() {
    // 用 Platform.operatingSystem 而不是 Platform.isWindows 之类的布尔：
    // 后者在未支持的新平台（如 Linux 桌面）上会全部落到「都不是」，
    // 而我们需要一个能进库、能分组的字符串。
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return 'unknown';
    }
  }

  @override
  String osVersion() {
    try {
      // 形如 "Windows 10 Pro 10.0.19045" / "android 14 ..."。
      // 截断到 120 字符：这一项是自由文本，服务端列宽有限，别让一条异常长的
      // 系统串把整批上报撑大。
      final raw = Platform.operatingSystemVersion;
      return raw.length > 120 ? raw.substring(0, 120) : raw;
    } catch (_) {
      return '';
    }
  }

  @override
  String locale() {
    try {
      return Platform.localeName;
    } catch (_) {
      return '';
    }
  }
}
