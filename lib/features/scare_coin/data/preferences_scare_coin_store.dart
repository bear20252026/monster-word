import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';
import 'package:word_app/models/scare_coin_entry.dart';

/// 基于 SharedPreferences 的尖叫币账本适配器。
class PreferencesScareCoinStore implements ScareCoinStore {
  static const String balanceKey = 'scare_coin.balance';
  static const String historyKey = 'scare_coin.history';
  static const String lastCheckInKey = 'scare_coin.last_checkin';
  static const String checkinDatesKey = 'scare_coin.checkin_dates';

  /// 断签保护卡库存／已发里程碑（耗材，独立 key：勿复用 scare_coin.redeemed.*
  /// 前缀，否则 redeemedBadgeCount 虚增、装备 owned/3 错乱）。
  static const String protectionKey = 'scare_coin.protection.count';
  static const String protectionIssuedKey = 'scare_coin.protection.issued';

  /// 答对即时奖励日计数（＋1／次，每日 answerRewardCapValue 封顶）。
  static const String answerRewardDateKey = 'scare_coin.answer_reward.date';
  static const String answerRewardCountKey = 'scare_coin.answer_reward.count';
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
    } catch (e, s) {
      reportSwallowedError('金币账本解析失败', e, s);
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
    final prefs = await SharedPreferences.getInstance();
    // 断签自动续命：有卡则回填最近的缺勤日（先近后远），不断连击。
    await _autoProtect(prefs, now);
    final iso = _iso(now);
    try {
      final dates = (prefs.getStringList(checkinDatesKey) ?? const <String>[]).toSet()..add(iso);
      await prefs.setStringList(checkinDatesKey, dates.toList()..sort());
    } catch (e, s) {
      // M9：签到日历集合写失败不阻断主流程，但须上报（连签展示可能缺天）。
      reportSwallowedError('scare_coin checkin dates persist', e, s);
    }
    final newBalance = await _apply(delta: checkInReward, reason: '每日签到', lastCheckInIso: iso);
    // 连签 7 倍数自动发卡（满额跳过发放但仍标记，避免无限囤积）。
    await _maybeIssueProtection(prefs);
    return newBalance;
  }

  @override
  int get protectionCap => protectionCapValue;

  /// 保护卡持有上限（端口常量经实例暴露，presentation 层免直引 data 实现）。
  static const int protectionCapValue = 3;

  /// 答对即时奖励日上限。
  static const int answerRewardCapValue = 20;

  @override
  int get answerRewardDailyCap => answerRewardCapValue;

  @override
  Future<int> grantAnswerReward() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    var count = 0;
    if (prefs.getString(answerRewardDateKey) == today) {
      count = prefs.getInt(answerRewardCountKey) ?? 0;
    }
    if (count >= answerRewardCapValue) return 0;
    await prefs.setString(answerRewardDateKey, today);
    await prefs.setInt(answerRewardCountKey, count + 1);
    await _apply(delta: 1, reason: '答对＋1');
    return 1;
  }

  @override
  Future<int> protectionCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(protectionKey) ?? 0;
  }

  @override
  Future<int> addProtection({required int count, required String reason}) async {
    final prefs = await SharedPreferences.getInstance();
    final next = ((prefs.getInt(protectionKey) ?? 0) + count).clamp(0, protectionCapValue);
    await prefs.setInt(protectionKey, next);
    await _insertHistory(prefs, ScareCoinEntry(time: DateTime.now(), delta: 0, reason: reason));
    return next;
  }

  /// 断签自动续命：last 与 today 之间差 gap>1 天且有库存时，
  /// 从近到远回填 min(库存, 缺勤) 天并记账，streak() 自然续上。
  Future<void> _autoProtect(SharedPreferences prefs, DateTime now) async {
    final last = prefs.getString(lastCheckInKey) ?? '';
    if (last.isEmpty) return;
    final lastDay = DateTime.tryParse(last);
    if (lastDay == null) return;
    final today = DateTime(now.year, now.month, now.day);
    final base = DateTime(lastDay.year, lastDay.month, lastDay.day);
    final gap = today.difference(base).inDays;
    if (gap <= 1) return;
    var count = prefs.getInt(protectionKey) ?? 0;
    if (count <= 0) return;
    final backfill = <String>[];
    for (var i = 1; i < gap && backfill.length < count; i++) {
      backfill.add(_iso(today.subtract(Duration(days: i))));
    }
    if (backfill.isEmpty) return;
    final dates = (prefs.getStringList(checkinDatesKey) ?? const <String>[]).toSet()..addAll(backfill);
    await prefs.setStringList(checkinDatesKey, dates.toList()..sort());
    count -= backfill.length;
    await prefs.setInt(protectionKey, count);
    await _insertHistory(
      prefs,
      ScareCoinEntry(time: now, delta: 0, reason: '断签保护·自动续命×${backfill.length}'),
    );
  }

  /// 连签 7 倍数发卡（去重标记防重复领，满额只标记不发放）。
  Future<void> _maybeIssueProtection(SharedPreferences prefs) async {
    final newStreak = await streak();
    if (newStreak <= 0 || newStreak % 7 != 0) return;
    final issued = (prefs.getStringList(protectionIssuedKey) ?? const <String>[]).toSet();
    if (!issued.add('$newStreak')) return;
    await prefs.setStringList(protectionIssuedKey, issued.toList()..sort());
    final count = prefs.getInt(protectionKey) ?? 0;
    if (count >= protectionCapValue) return;
    await prefs.setInt(protectionKey, count + 1);
    await _insertHistory(
      prefs,
      ScareCoinEntry(time: DateTime.now(), delta: 0, reason: '连签$newStreak天·保护卡＋1'),
    );
  }

  /// 零币变动也记账（发卡／续命审计），复用 200 条截断口径。
  Future<void> _insertHistory(SharedPreferences prefs, ScareCoinEntry entry) async {
    List<ScareCoinEntry> entries = [];
    final raw = prefs.getString(historyKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        entries = (jsonDecode(raw) as List)
            .map((e) => ScareCoinEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    entries.insert(0, entry);
    await prefs.setString(historyKey, jsonEncode(entries.take(200).map((e) => e.toJson()).toList()));
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
