// P3-4（架构审计 2026-11-12）：复习调度降级日志（从 ReviewScheduleRepository 抽出）。
//
// SQLite 故障降级期间的评分意图日志（SP StringList，逐条 JSON）；SQLite 恢复后
// 按序幂等回放（fsrs_rating_log 主键去重），成功后清空。回放需 engine 重算卡片。
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart' show ReviewScheduleRepository;
import 'package:word_app/features/learning/data/review_schedule_store.dart';

class ReviewScheduleJournal {
  const ReviewScheduleJournal(this._engine);

  final Fsrs6Engine _engine;

  /// 把一次评分意图追加进 SP 降级日志（P1-01）。
  /// 返回 false = 日志都写不进（磁盘满/SP 不可用）——上层按硬失败处理。
  Future<bool> append(String word, FsrsRating rating, String date, String ratingId, bool isLearn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final journal = prefs.getStringList(ReviewScheduleRepository.degradedJournalKey) ?? <String>[];
      journal.add(
        jsonEncode({
          'ratingId': ratingId,
          'word': word,
          'rating': rating.value,
          'date': date,
          'isLearn': isLearn,
          'savedAt': DateTime.now().toIso8601String(),
        }),
      );
      // 容量上限：极端积压时丢最旧（上报可见），保护 SP 体积。
      var kept = journal;
      if (kept.length > ReviewScheduleRepository.degradedJournalCap) {
        kept = kept.sublist(kept.length - ReviewScheduleRepository.degradedJournalCap);
        reportSwallowedError(
          'FSRS 降级日志超上限，丢弃最旧 ${journal.length - kept.length} 条',
          StateError('degraded journal overflow'),
          StackTrace.current,
        );
      }
      return await prefs.setStringList(ReviewScheduleRepository.degradedJournalKey, kept);
    } catch (error, stack) {
      reportSwallowedError('FSRS 降级日志写入失败（评分硬失败）', error, stack);
      return false;
    }
  }

  /// SQLite 恢复后回放降级日志：按序重算卡片并落库，fsrs_rating_log 主键
  /// 幂等去重（重复回放不会重复计数）；任一条失败保留整个日志下次重试。
  Future<int> replay(ReviewScheduleStore store) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final journal = prefs.getStringList(ReviewScheduleRepository.degradedJournalKey);
      if (journal == null || journal.isEmpty) return 0;
      var applied = 0;
      var duplicates = 0;
      for (final entry in journal) {
        try {
          final map = jsonDecode(entry) as Map<String, dynamic>;
          final word = map['word'] as String;
          final rating = FsrsRating.values[(map['rating'] as num).toInt() - 1];
          final dateKey = map['date'] as String;
          final ratingId = map['ratingId'] as String;
          final isLearn = (map['isLearn'] as bool?) ?? false;
          // 审计 P1-02：**必须按原答题时间重算**，不能用「回放当天」。
          final reviewedAt = _journalReviewedAt(map, dateKey);
          final prior = await store.cardForWord(word);
          final card = prior == null
              ? _engine.learn(word, rating, reviewedAt: reviewedAt)
              : _engine.review(prior, rating, reviewedAt: reviewedAt);
          final ok = await store.recordRating(
            card: card,
            dateKey: dateKey,
            isLearn: isLearn || prior == null,
            correct: rating != FsrsRating.again,
            ratingId: ratingId,
          );
          if (ok) {
            applied++;
          } else {
            duplicates++;
          }
        } catch (error, stack) {
          reportSwallowedError('FSRS 降级日志回放单条失败（保留日志下次重试）', error, stack);
          return applied;
        }
      }
      await prefs.remove(ReviewScheduleRepository.degradedJournalKey);
      reportSwallowedError(
        'FSRS 降级日志回放完成（applied=$applied duplicate=$duplicates）',
        StateError('degraded journal replayed'),
        StackTrace.current,
      );
      return applied;
    } catch (error, stack) {
      reportSwallowedError('FSRS 降级日志回放读取失败（保留日志下次重试）', error, stack);
      return 0;
    }
  }

  /// 从 journal 条目取出**原答题时刻**（审计 P1-02）。
  ///
  /// 优先 `savedAt`（评分发生的那一刻，ISO 串）；老条目没有该键时退回
  /// `dateKey` 当日零点。解析失败也退回 dateKey，绝不抛。
  DateTime? _journalReviewedAt(Map<String, dynamic> map, String dateKey) {
    final savedAt = map['savedAt'];
    if (savedAt is String) {
      final parsed = DateTime.tryParse(savedAt);
      if (parsed != null) return parsed;
    }
    return DateTime.tryParse(dateKey);
  }
}
