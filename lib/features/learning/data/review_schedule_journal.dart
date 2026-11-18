// P3-4（架构审计 2026-11-12）：复习调度降级日志（从 ReviewScheduleRepository 抽出）。
//
// SQLite 故障降级期间的评分意图日志（SP StringList，逐条 JSON）；SQLite 恢复后
// 按序幂等回放（fsrs_rating_log 主键去重），成功后清空。回放需 engine 重算卡片。
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/learning/data/review_schedule_keys.dart';
import 'package:word_app/features/learning/data/review_schedule_store.dart';

class ReviewScheduleJournal {
  const ReviewScheduleJournal(this._engine);

  final Fsrs6Engine _engine;

  /// 把一次评分意图追加进 SP 降级日志（P1-01）。
  /// 返回 false = 日志都写不进（磁盘满/SP 不可用）——上层按硬失败处理。
  ///
  /// 第三轮 T14：[ratedAt] 是**评分计算时刻**（card.lastReview 同源），与
  /// savedAt（落日志时刻，经写闸排队可能晚数秒）区分——迁移预登记比对必须用
  /// ratedAt，否则写闸拥塞时「已含于 blob 的评分」被误判未应用而双回放。
  Future<bool> append(
    String word,
    FsrsRating rating,
    String date,
    String ratingId,
    bool isLearn, {
    required DateTime ratedAt,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final journal = prefs.getStringList(kFsrsDegradedJournalKey) ?? <String>[];
      journal.add(
        jsonEncode({
          'ratingId': ratingId,
          'word': word,
          'rating': rating.value,
          'date': date,
          'isLearn': isLearn,
          'ratedAt': ratedAt.toIso8601String(),
          'savedAt': DateTime.now().toIso8601String(),
        }),
      );
      // 容量上限：极端积压时丢最旧（上报可见），保护 SP 体积。
      var kept = journal;
      if (kept.length > kFsrsDegradedJournalCap) {
        kept = kept.sublist(kept.length - kFsrsDegradedJournalCap);
        reportSwallowedError(
          'FSRS 降级日志超上限，丢弃最旧 ${journal.length - kept.length} 条',
          StateError('degraded journal overflow'),
          StackTrace.current,
        );
      }
      return await prefs.setStringList(kFsrsDegradedJournalKey, kept);
    } catch (error, stack) {
      reportSwallowedError('FSRS 降级日志写入失败（评分硬失败）', error, stack);
      return false;
    }
  }

  /// SQLite 恢复后回放降级日志：按序重算卡片并落库，fsrs_rating_log 主键
  /// 幂等去重（重复回放不会重复计数）；任一条失败保留整个日志下次重试。
  Future<int> replay(ReviewScheduleStore store, {bool updateDailyStats = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final journal = prefs.getStringList(kFsrsDegradedJournalKey);
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
            // 用户反馈修复（2026-11-14）：仅当本次启动迁移已导入降级期统计时
            // 才跳过日报（防双计）；无迁移时回放须自计统计（P1-03 守卫）。
            updateDailyStats: updateDailyStats,
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
      await prefs.remove(kFsrsDegradedJournalKey);
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
  /// 第三轮 T14：优先 `ratedAt`（评分计算时刻，与 card.lastReview 同源）；
  /// 老条目无该键退回 `savedAt`（落日志时刻，写闸延迟下略晚于真实答题）；
  /// 再退回 `dateKey` 当日零点。解析失败也退回 dateKey，绝不抛。
  DateTime? _journalReviewedAt(Map<String, dynamic> map, String dateKey) {
    for (final key in const ['ratedAt', 'savedAt']) {
      final raw = map[key];
      if (raw is String) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
    }
    return DateTime.tryParse(dateKey);
  }
}
