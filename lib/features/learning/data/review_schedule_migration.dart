// P3-4（架构审计 2026-11-12）：复习调度 SP→SQLite 迁移（从 ReviewScheduleRepository 抽出）。
//
// 首启检测 marker 未完成时从 SP 单事务导入 cards+stats+dates；E2 清旧快照前先挪应急备份。
// 只需 prefs + store + codec，无需 engine；建索引/置标志由仓储 _load 在返回后做。
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/core/utils/debug_log.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart' show ReviewScheduleRepository;
import 'package:word_app/features/learning/data/review_schedule_sp_codec.dart';
import 'package:word_app/features/learning/data/review_schedule_store.dart';

class ReviewScheduleMigration {
  const ReviewScheduleMigration(this._codec);

  final ReviewScheduleSpCodec _codec;

  /// 首启迁移：marker 未写完时从 SP **单事务** 导入 cards+stats+dates。
  ///
  /// H1：不再以 `cardCount()>0` 提前 return——那会在 cards 成功、stats 失败后
  /// 永久跳过迁移。仅 `migratedMarkerKey==done` 视为完成；未完成则从 SP 重放
  /// （E2 清 SP 前置条件是 marker=done，故未完成时 SP 仍在）。
  Future<void> migrateFromSpIfNeeded(ReviewScheduleStore store) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(ReviewScheduleRepository.migratedMarkerKey) == 'done') return;

    final rawCards = prefs.getString(ReviewScheduleRepository.cardsPrefKey);
    if (rawCards == null || rawCards.isEmpty) {
      // 无历史数据可迁：直接写标记，避免每次启动空转检查。
      await prefs.setString(ReviewScheduleRepository.migratedMarkerKey, 'done');
      return;
    }

    // 顶层 jsonDecode 先兑一层：SP blob 整体损坏时抛出会让每次启动重复失败并永久卡在 SP 降级模式。
    // 改为：记录为空迁入并写标记，原 blob 由 E2 应急备份保留（供人工恢复）。
    Map<String, dynamic> decodedCards;
    try {
      decodedCards = jsonDecode(rawCards) as Map<String, dynamic>;
    } catch (error, stack) {
      reportSwallowedError('FSRS migration: SP cards blob corrupt; migrate as empty', error, stack);
      decodedCards = const <String, dynamic>{};
    }

    // 逐行解析，损坏行跳过（学习记录不可再生产，能救一行是一行）。
    final cards = <FsrsCard>[];
    var skipped = 0;
    for (final entry in decodedCards.entries) {
      try {
        cards.add(FsrsCard.fromJson(entry.value as Map<String, dynamic>));
      } catch (_) {
        // 吞错豁免: 逐行跳过损坏卡片，循环结束后按 skipped 聚合 reportSwallowedError
        skipped++;
        debugLog('FSRS migration: skip corrupt card "${entry.key}"');
      }
    }

    final dailyStats = <String, Map<String, int>>{};
    final rawStats = prefs.getString(ReviewScheduleRepository.dailyStatsPrefKey);
    if (rawStats != null && rawStats.isNotEmpty) {
      Map<String, dynamic> decodedStats;
      try {
        decodedStats = jsonDecode(rawStats) as Map<String, dynamic>;
      } catch (error, stack) {
        reportSwallowedError('FSRS migration: SP stats blob corrupt; skip', error, stack);
        decodedStats = const <String, dynamic>{};
      }
      for (final entry in decodedStats.entries) {
        try {
          final map = entry.value as Map<String, dynamic>;
          dailyStats[entry.key] = {'learn': map['learn'] as int? ?? 0, 'review': map['review'] as int? ?? 0};
        } catch (_) {
          // 吞错豁免: 同上——逐行跳过，循环后聚合上报
          skipped++;
          debugLog('FSRS migration: skip corrupt daily stat "${entry.key}"');
        }
      }
    }

    final activeDates = (prefs.getStringList(ReviewScheduleRepository.activeDatesPrefKey) ?? const <String>[]).toSet();

    // H1：三表单事务；失败整体回滚且不写标记 → 下次启动从 SP 重试。
    await store.migrateFromSp(
      cards: cards,
      dailyStats: dailyStats,
      dailyCorrect: _codec.readDailyCorrect(prefs.getString(ReviewScheduleRepository.dailyCorrectPrefKey)),
      activeDates: activeDates,
    );

    if (skipped > 0) {
      reportSwallowedError(
        'FSRS migration skipped corrupt rows',
        StateError('$skipped corrupt entries skipped during SP->SQLite migration'),
        StackTrace.current,
      );
    }

    await prefs.setString(ReviewScheduleRepository.migratedMarkerKey, 'done');
  }

  /// H2：E2 清 SP 前把快照挪到应急备份 key（不清除），供库损坏时人工恢复。
  Future<void> clearLegacySpSnapshotIfMigrated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(ReviewScheduleRepository.migratedMarkerKey) != 'done') return;
      // H2：若尚无应急备份且 SP 仍有数据，先打包到 emergencyBackupKey。
      final cardsRaw = prefs.getString(ReviewScheduleRepository.cardsPrefKey);
      final hasBackup = (prefs.getString(ReviewScheduleRepository.emergencyBackupKey) ?? '').isNotEmpty;
      if (!hasBackup && cardsRaw != null && cardsRaw.isNotEmpty) {
        // 写返回 false（磁盘满等）不抛错：此时绝不能删主键——唯一可恢复
        // 快照还不存在，删了学习记录就永久丢失。留原键，下次启动重试打包。
        final saved = await prefs.setString(
          ReviewScheduleRepository.emergencyBackupKey,
          jsonEncode({
            'savedAt': DateTime.now().toIso8601String(),
            ReviewScheduleRepository.cardsPrefKey: cardsRaw,
            ReviewScheduleRepository.dailyStatsPrefKey: prefs.getString(ReviewScheduleRepository.dailyStatsPrefKey),
            ReviewScheduleRepository.dailyCorrectPrefKey: prefs.getString(ReviewScheduleRepository.dailyCorrectPrefKey),
            ReviewScheduleRepository.activeDatesPrefKey: prefs.getStringList(
              ReviewScheduleRepository.activeDatesPrefKey,
            ),
          }),
        );
        if (!saved) {
          reportSwallowedError(
            'FSRS E2 emergency backup write returned false; keep legacy keys',
            StateError('setString(${ReviewScheduleRepository.emergencyBackupKey}) returned false'),
            StackTrace.current,
          );
          return;
        }
      }
      await prefs.remove(ReviewScheduleRepository.cardsPrefKey);
      await prefs.remove(ReviewScheduleRepository.dailyStatsPrefKey);
      await prefs.remove(ReviewScheduleRepository.dailyCorrectPrefKey);
      await prefs.remove(ReviewScheduleRepository.activeDatesPrefKey);
    } catch (error, stack) {
      reportSwallowedError('FSRS E2 clear legacy SP snapshot', error, stack);
    }
  }
}
