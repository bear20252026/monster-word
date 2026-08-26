// 由 Claude 团队生成 | Monster Word App
// StatsServiceImpl — 学习统计服务实现

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/user_repository.dart';
import 'stats_service.dart';

/// 学习统计服务实现
class StatsServiceImpl implements StatsService {
  final UserRepository? _userRepo;

  StatsServiceImpl({UserRepository? userRepo}) : _userRepo = userRepo;

  // ─── 内部存储键 ─────────────────────────────────────────────────────
  static const String _kLearnEventsKey = 'stats_learn_events';
  static const String _kReviewEventsKey = 'stats_review_events';
  static const String _kDailyCountKey = 'stats_daily_count';

  @override
  Future<Map<String, dynamic>> getStats() async {
    final repo = _userRepo;
    if (repo == null) return {};
    return await repo.getLearningStats();
  }

  @override
  Future<Map<String, dynamic>> getTodayStats() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final dailyCount = prefs.getInt('${_kDailyCountKey}_$today') ?? 0;
    return {
      'today': dailyCount,
      'date': today,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getWeeklyStats() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final List<Map<String, dynamic>> weekly = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = '${_kDailyCountKey}_${date.year}-${_pad(date.month)}-${_pad(date.day)}';
      final count = prefs.getInt(key) ?? 0;
      weekly.add({
        'date': '${date.year}-${_pad(date.month)}-${_pad(date.day)}',
        'count': count,
      });
    }
    return weekly;
  }

  @override
  Future<void> recordLearnEvent(String word, {bool success = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayKey();

      // 更新每日计数
      final dailyKey = '${_kDailyCountKey}_$today';
      final currentCount = prefs.getInt(dailyKey) ?? 0;
      await prefs.setInt(dailyKey, currentCount + 1);

      // 记录事件详情
      final events = await _getEvents(_kLearnEventsKey);
      events.add({
        'word': word,
        'success': success,
        'timestamp': DateTime.now().toIso8601String(),
      });
      // 只保留最近 500 条记录
      if (events.length > 500) {
        events.removeRange(0, events.length - 500);
      }
      await _saveEvents(_kLearnEventsKey, events);
    } catch (e) {
      debugPrint('[StatsService] Failed to record learn event: $e');
    }
  }

  @override
  Future<void> recordReviewEvent(String word, {required int quality}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayKey();

      // 更新每日计数
      final dailyKey = '${_kDailyCountKey}_$today';
      final currentCount = prefs.getInt(dailyKey) ?? 0;
      await prefs.setInt(dailyKey, currentCount + 1);

      // 记录事件详情
      final events = await _getEvents(_kReviewEventsKey);
      events.add({
        'word': word,
        'quality': quality,
        'timestamp': DateTime.now().toIso8601String(),
      });
      // 只保留最近 500 条记录
      if (events.length > 500) {
        events.removeRange(0, events.length - 500);
      }
      await _saveEvents(_kReviewEventsKey, events);
    } catch (e) {
      debugPrint('[StatsService] Failed to record review event: $e');
    }
  }

  // ─── 私有辅助方法 ───────────────────────────────────────────────────
  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${_pad(now.month)}-${_pad(now.day)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  Future<List<Map<String, dynamic>>> _getEvents(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(key);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveEvents(String key, List<Map<String, dynamic>> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(events));
  }
}
