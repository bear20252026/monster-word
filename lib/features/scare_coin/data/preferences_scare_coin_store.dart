import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/scare_coin_entry.dart';
import '../application/scare_coin_store.dart';

/// 基于 SharedPreferences 的尖叫币账本适配器。
class PreferencesScareCoinStore implements ScareCoinStore {
  static const String balanceKey = 'scare_coin.balance';
  static const String historyKey = 'scare_coin.history';
  static const String lastCheckInKey = 'scare_coin.last_checkin';
  static const String checkinDatesKey = 'scare_coin.checkin_dates';
  static const int reward = 10;

  @override
  int get checkInReward => reward;

  @override
  Future<int> balance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(balanceKey) ?? 0;
  }

  @override
  Future<Set<String>> checkinDates() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(checkinDatesKey) ?? const <String>[]).toSet();
  }

  @override
  Future<int> streak() async {
    final dates = await checkinDates();
    if (dates.isEmpty) return 0;
    var day = DateTime.now();
    bool has(DateTime value) => dates.contains(_iso(value));
    if (!has(day)) day = day.subtract(const Duration(days: 1));
    var count = 0;
    while (has(day)) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  @override
  Future<List<ScareCoinEntry>> history() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(historyKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final entries = (jsonDecode(raw) as List)
          .map((entry) => ScareCoinEntry.fromJson(entry as Map<String, dynamic>))
          .toList();
      entries.sort((a, b) => b.time.compareTo(a.time));
      return entries;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<String> lastCheckInDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(lastCheckInKey) ?? '';
  }

  @override
  bool isSameDay(String isoDate, DateTime time) => isoDate == _iso(time);

  @override
  Future<int?> checkIn() async {
    final now = DateTime.now();
    final last = await lastCheckInDate();
    if (isSameDay(last, now)) return null;
    final iso = _iso(now);
    try {
      final prefs = await SharedPreferences.getInstance();
      final dates = (prefs.getStringList(checkinDatesKey) ?? const <String>[]).toSet()..add(iso);
      await prefs.setStringList(checkinDatesKey, dates.toList()..sort());
    } catch (_) {
      // 日历集合写入失败不阻断主签到流程。
    }
    return _apply(delta: checkInReward, reason: '每日签到', lastCheckInIso: iso);
  }

  @override
  Future<int> grant({required int delta, required String reason}) => _apply(delta: delta, reason: reason);

  Future<int> _apply({required int delta, required String reason, String? lastCheckInIso}) async {
    final prefs = await SharedPreferences.getInstance();
    final newBalance = (prefs.getInt(balanceKey) ?? 0) + delta;
    await prefs.setInt(balanceKey, newBalance);
    if (lastCheckInIso != null) await prefs.setString(lastCheckInKey, lastCheckInIso);
    final entries = await history();
    entries.insert(0, ScareCoinEntry(time: DateTime.now(), delta: delta, reason: reason));
    await prefs.setString(historyKey, jsonEncode(entries.take(200).map((entry) => entry.toJson()).toList()));
    return newBalance;
  }

  String _iso(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
