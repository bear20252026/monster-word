// 肚皮储蓄罐离线计息的 application 存储（presentation 只消费本类，不直触 SP）。
//
// 持久化口径（与 MonsterBondPrefs 同款「单键整段 JSON」）：
// - 键 `belly_interest.state_v1`，值形如 {"lastSeenMs":1731360000000,"settledDay":"2026-11-12"}；
// - lastSeenMs：最近一次「人在场」的时刻（进签到页/结算后刷新）；
// - settledDay：最近一次结算的日历日——同一天只结算一次，防「退出重进再点」刷币；
// - 值损坏整段丢弃按首次处理（宁可少发一次，不可错发）。
//
// 幂等三层：本页同日闸门（settledDay）→ 账本 grantOnce(eventKey) → 余额串行闸。
import 'dart:convert';

import 'package:word_app/core/infrastructure/app_preferences.dart';

/// 离线计息状态存储（时间可注入，测试用固定时钟）。
class BellyInterestStore {
  BellyInterestStore({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  static const String stateKey = 'belly_interest.state_v1';

  /// 最近一次「人在场」时刻；从未记录返回 null（首次进页只落标不计息）。
  DateTime? lastSeen() {
    final ms = _read().lastSeenMs;
    if (ms == null || ms <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// 今天是否已结算过。
  bool settledToday() => _read().settledDay == _dayKey(_now());

  /// 刷新「人在场」时刻（进签到页时调用；不影响当日结算闸门）。
  Future<bool> markSeen() => _write(lastSeenMs: _now().millisecondsSinceEpoch, settledDay: _read().settledDay);

  /// 结算落标：记结算日并刷新在场时刻。返回是否写入成功。
  Future<bool> markSettled() => _write(lastSeenMs: _now().millisecondsSinceEpoch, settledDay: _dayKey(_now()));

  /// 账本幂等键：同日同键，grantOnce 全局只发一次。
  String eventKeyForToday() => 'belly_interest:${_dayKey(_now())}';

  String _dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  _BellyState _read() {
    final raw = AppPreferences().getString(stateKey);
    if (raw.isEmpty) return const _BellyState();
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return const _BellyState();
      final ms = map['lastSeenMs'];
      final day = map['settledDay'];
      return _BellyState(lastSeenMs: ms is int ? ms : null, settledDay: day is String && day.isNotEmpty ? day : null);
    } catch (_) {
      // 值损坏按首次处理：少发一次可接受，错发不可接受。
      return const _BellyState();
    }
  }

  Future<bool> _write({required int lastSeenMs, required String? settledDay}) {
    final map = <String, dynamic>{'lastSeenMs': lastSeenMs};
    if (settledDay != null) map['settledDay'] = settledDay;
    return AppPreferences().setString(stateKey, jsonEncode(map));
  }
}

class _BellyState {
  const _BellyState({this.lastSeenMs, this.settledDay});

  final int? lastSeenMs;
  final String? settledDay;
}
