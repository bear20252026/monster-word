// 「参与使用统计」开关的持久化。
//
// 默认值的取舍（**改这里必须同步改隐私披露**，见 domain/legal_documents.dart）：
//   目前默认 **off**。原因是披露里写的是「默认关闭，可在设置中开启」——
//   而「用户里有没有不满 14 周岁的人」这个问题业主还没答复，PIPL 对不满 14 周岁的
//   个人信息要求监护人单独同意，在没确认之前不该默认收集。
//   确认可以默认开启后：把 _defaultEnabled 改成 true，并同步改披露文案
//   （「默认关闭」→「默认开启」），再在发版流水线注入 USAGE_STATS_DEFAULT=on。
//
// 开关状态存 SharedPreferences 而不是 SQLite：它是一枚用户偏好，
// 且需要在不打开数据库的情况下就能读到（统计关闭时不该为了读开关去开库）。

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/features/telemetry/application/usage_stats_ports.dart';

/// 构建期默认值：`--dart-define=USAGE_STATS_DEFAULT=on` 可改成默认开启。
const String _defaultEnabledDefine = String.fromEnvironment('USAGE_STATS_DEFAULT', defaultValue: 'off');

class PrefsUsageStatsSettings implements UsageStatsSettings {
  PrefsUsageStatsSettings({SharedPreferences? prefs, bool? defaultEnabled})
    : _injected = prefs,
      _defaultEnabled = defaultEnabled ?? _defaultEnabledDefine.toLowerCase() == 'on';

  static const String _key = 'usage_stats_enabled_v1';

  final SharedPreferences? _injected;
  final bool _defaultEnabled;

  Future<SharedPreferences> _prefs() async => _injected ?? await SharedPreferences.getInstance();

  @override
  Future<bool> isEnabled() async {
    try {
      final prefs = await _prefs();
      // 用户没表过态 ⇒ 用构建期默认值（不写入，避免把默认值误当成用户选择）。
      return prefs.getBool(_key) ?? _defaultEnabled;
    } catch (_) {
      // 读不到偏好就按默认值处理，不抛。
      return _defaultEnabled;
    }
  }

  @override
  Future<void> setEnabled(bool value) async {
    try {
      final prefs = await _prefs();
      await prefs.setBool(_key, value);
    } catch (_) {
      // 写失败不抛：最坏是下次启动回到默认值，不影响任何主流程。
    }
  }
}
