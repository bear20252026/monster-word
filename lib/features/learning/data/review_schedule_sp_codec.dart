// P3-4（架构审计 2026-11-12）：复习调度旧 SP blob 编解码（从 ReviewScheduleRepository 抽出）。
//
// 降级模式专用：逐行解析，单行损坏只丢该行，不整表清空（整表清空后任意评分会用
// 近空 map 覆写 SP blob，把可救的行也葬掉）。纯 SP 读写，无状态；键单源在仓储。
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart' show ReviewScheduleRepository;

class ReviewScheduleSpCodec {
  const ReviewScheduleSpCodec();

  /// 降级路径逐行解析卡片：单行损坏只丢该行。
  Map<String, FsrsCard> readCards(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, dynamic>;
    } catch (error, stack) {
      reportSwallowedError('FSRS degraded readCards: blob corrupt', error, stack);
      return {};
    }
    final cards = <String, FsrsCard>{};
    for (final entry in decoded.entries) {
      try {
        cards[entry.key] = FsrsCard.fromJson(entry.value as Map<String, dynamic>);
      } catch (error, stack) {
        reportSwallowedError('FSRS degraded readCards: skip corrupt "${entry.key}"', error, stack);
      }
    }
    return cards;
  }

  Map<String, Map<String, int>> readDailyStats(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, dynamic>;
    } catch (error, stack) {
      reportSwallowedError('FSRS degraded readDailyStats: blob corrupt', error, stack);
      return {};
    }
    final stats = <String, Map<String, int>>{};
    for (final entry in decoded.entries) {
      try {
        final map = entry.value as Map<String, dynamic>;
        stats[entry.key] = {'learn': map['learn'] as int? ?? 0, 'review': map['review'] as int? ?? 0};
      } catch (error, stack) {
        reportSwallowedError('FSRS degraded readDailyStats: skip corrupt "${entry.key}"', error, stack);
      }
    }
    return stats;
  }

  Map<String, int> readDailyCorrect(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final entry in decoded.entries) entry.key: (entry.value as num?)?.toInt() ?? 0};
    } catch (error, stack) {
      reportSwallowedError('FSRS degraded readDailyCorrect: blob corrupt', error, stack);
      return {};
    }
  }

  /// 全量写卡片快照（forget 的 SP 降级持久化）。
  Future<void> saveCards(Map<String, FsrsCard> cards) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ReviewScheduleRepository.cardsPrefKey,
      jsonEncode(cards.map((word, card) => MapEntry(word, card.toJson()))),
    );
  }

  /// SP 降级评分的「前瞻 blob 快照」：临时并入本次评分（内存正式提交在上层），
  /// 保证旧版装回时能从旧 key 读到含本次评分的完整历史（回归契约）。
  Future<void> writeProspectiveSnapshot({
    required Map<String, FsrsCard> cards,
    required Map<String, Map<String, int>> dailyStats,
    required Map<String, int> dailyCorrect,
    required Set<String> activeDates,
    required String word,
    required FsrsCard card,
    required String date,
    required bool isLearn,
    required FsrsRating rating,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prospectiveCards = <String, FsrsCard>{};
    cards.forEach((k, v) => prospectiveCards[k] = v);
    prospectiveCards[word] = card;
    final prospectiveStats = <String, Map<String, int>>{};
    dailyStats.forEach((k, v) => prospectiveStats[k] = Map<String, int>.from(v));
    final dayCounts = prospectiveStats.putIfAbsent(date, () => {'learn': 0, 'review': 0});
    dayCounts[isLearn ? 'learn' : 'review'] = (dayCounts[isLearn ? 'learn' : 'review'] ?? 0) + 1;
    final prospectiveDates = Set<String>.from(activeDates)..add(date);
    final prospectiveCorrect = <String, int>{...dailyCorrect};
    if (rating != FsrsRating.again) {
      prospectiveCorrect[date] = (prospectiveCorrect[date] ?? 0) + 1;
    }
    await prefs.setString(
      ReviewScheduleRepository.cardsPrefKey,
      jsonEncode(prospectiveCards.map((w, c) => MapEntry(w, c.toJson()))),
    );
    await prefs.setString(ReviewScheduleRepository.dailyStatsPrefKey, jsonEncode(prospectiveStats));
    await prefs.setString(ReviewScheduleRepository.dailyCorrectPrefKey, jsonEncode(prospectiveCorrect));
    await prefs.setStringList(ReviewScheduleRepository.activeDatesPrefKey, prospectiveDates.toList());
  }
}
